--[[
	SessionService — жизненный цикл сессии пары.

	create({a, b}) → случайно раздаёт стороны, выделяет слот в мире, строит первую комнату,
	телепортирует игроков. Когда оба стоят в выходе — следующая комната.
	Если напарник вышел из игры — оставшийся возвращается в лобби.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local RoomRuntime = require(script.Parent.Parent.Room.RoomRuntime)
local Rooms = require(script.Parent.Parent.Rooms)

local Attr = Constants.Attr
local Side = Constants.Side

local SessionService = {}

local CollisionService
local WorldService
local EconomyService

local NotifyRemote: RemoteEvent
local StateRemote: RemoteEvent
local SubmitCodeRemote: RemoteEvent

--------------------------------------------------------------------------------
-- Session (объект одной пары)
--------------------------------------------------------------------------------

local Session = {}
Session.__index = Session

export type Session = typeof(setmetatable(
	{} :: {
		id: string,
		slot: number,
		origin: CFrame,
		folder: Folder,
		players: { [Player]: string },
		roomIndex: number,
		room: any,
		roomConnection: any,
		ended: boolean,
		solo: boolean,
	},
	Session
))

local sessions: { [string]: Session } = {}
local sessionByPlayer: { [Player]: Session } = {}
local usedSlots: { [number]: boolean } = {}

local function allocateSlot(): number
	local slot = 0
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	return slot
end

-- С StreamingEnabled клиент может ещё не загрузить пол в точке назначения:
-- сначала просим подгрузить область, потом переносим персонажа.
local function teleport(player: Player, cframe: CFrame)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(cframe.Position, 3)
		end)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(cframe)
		end
	end)
end

function Session:notify(player: Player?, text: string, kind: string?)
	if player then
		NotifyRemote:FireClient(player, text, kind or "info")
	else
		for member in self.players do
			NotifyRemote:FireClient(member, text, kind or "info")
		end
	end
end

function Session:getPartner(player: Player): Player?
	for member in self.players do
		if member ~= player then
			return member
		end
	end
	return nil
end

function Session:getPlayerOnSide(side: string): Player?
	for member, memberSide in self.players do
		if memberSide == side then
			return member
		end
	end
	return nil
end

function Session:sendState()
	local def = Rooms.list[self.roomIndex]
	for member, side in self.players do
		local partner = self:getPartner(member)
		StateRemote:FireClient(member, {
			side = side,
			partnerName = partner and partner.DisplayName or "—",
			roomIndex = self.roomIndex,
			roomCount = #Rooms.list,
			roomName = def and def.Name or "",
			hint = def and def.Hints and def.Hints[side] or "",
			solo = self.solo,
		})
	end
end

-- Ставит персонажа игрока в его мир и на точку появления текущей комнаты.
function Session:placePlayer(player: Player)
	local character = player.Character
	if not character or not self.room then
		return
	end
	CollisionService.setCharacterSide(character, self.players[player])
	teleport(player, self.room:getSpawnCFrame(self.players[player]))
end

-- Соло-режим: игрок переключается между мирами (сам играет за обоих).
function Session:switchSide(player: Player)
	if not self.solo or not self.players[player] then
		return
	end
	local newSide = if self.players[player] == Side.Light then Side.Dark else Side.Light
	self.players[player] = newSide
	player:SetAttribute(Attr.Side, newSide)
	if player.Character then
		CollisionService.setCharacterSide(player.Character, newSide)
	end
	self:sendState()
end

function Session:loadRoom(index: number)
	if self.roomConnection then
		self.roomConnection:Disconnect()
		self.roomConnection = nil
	end
	if self.room then
		self.room:Destroy()
		self.room = nil
	end

	local def = Rooms.list[index]
	self.roomIndex = index
	self.room = RoomRuntime.new(self, def)
	self.roomConnection = self.room.Completed:Connect(function()
		self:onRoomCompleted()
	end)

	for member in self.players do
		self:placePlayer(member)
	end
	self:sendState()
end

-- Пропуск комнаты (оплачен игроком `byPlayer`). true — комната пропущена.
function Session:skipRoom(byPlayer: Player): boolean
	if self.ended or not self.room then
		return false
	end
	if self.room:forceComplete() then
		self:notify(
			nil,
			byPlayer.DisplayName .. " пропустил комнату для вас обоих ⏭",
			"success"
		)
		return true
	end
	return false
end

function Session:onRoomCompleted()
	if self.ended then
		return
	end
	EconomyService.onRoomCompleted(self, self.room ~= nil and self.room.skipped == true)
	if self.roomIndex < #Rooms.list then
		self:notify(nil, "Комната пройдена! ✨", "success")
		self:loadRoom(self.roomIndex + 1)
	else
		self:notify(
			nil,
			"Глава пройдена! 🎉 Отличная командная работа",
			"success"
		)
		EconomyService.onChapterCompleted(self)
		SessionService.endSession(self, "completed")
	end
end

--------------------------------------------------------------------------------
-- Публичное API сервиса
--------------------------------------------------------------------------------

function SessionService.isInSession(player: Player): boolean
	return sessionByPlayer[player] ~= nil
end

function SessionService.getSession(player: Player): Session?
	return sessionByPlayer[player]
end

-- pair — два игрока; с opts.solo = true — один (тест в Studio, позже соло-режим).
function SessionService.create(pair: { Player }, opts: { solo: boolean? }?): Session?
	local solo = opts ~= nil and opts.solo == true
	local needed = if solo then 1 else 2
	if #pair < needed then
		return nil
	end
	for i = 1, needed do
		local player = pair[i]
		if not player or player.Parent ~= Players or sessionByPlayer[player] then
			return nil
		end
	end

	local players = {}
	if solo then
		players[pair[1]] = Side.Light
	else
		local a, b = pair[1], pair[2]
		if math.random() < 0.5 then
			a, b = b, a
		end
		players[a] = Side.Light
		players[b] = Side.Dark
	end

	local slot = allocateSlot()
	local folder = Instance.new("Folder")
	folder.Name = "Session_" .. slot
	folder.Parent = WorldService.getSessionsFolder()

	local session = setmetatable({
		id = HttpService:GenerateGUID(false),
		slot = slot,
		origin = CFrame.new(Config.SESSION_BASE + Vector3.new(slot * Config.SESSION_SPACING, 0, 0)),
		folder = folder,
		players = players,
		solo = solo,
		roomIndex = 0,
		room = nil,
		roomConnection = nil,
		ended = false,
	}, Session)

	sessions[session.id] = session
	for member, side in session.players do
		sessionByPlayer[member] = session
		member:SetAttribute(Attr.Side, side)
		member:SetAttribute(Attr.SessionId, session.id)
	end

	EconomyService.onSessionStarted(session)
	session:loadRoom(1)
	for member, side in session.players do
		local text = if solo
			then "Тест одному: нажми T (или кнопку справа), чтобы сменить мир"
			else "Ты в " .. Constants.SideNames[side] .. ". Напарник видит другую сторону!"
		session:notify(member, text, "info")
	end
	return session
end

function SessionService.endSession(session: Session, reason: string)
	if session.ended then
		return
	end
	session.ended = true

	if session.roomConnection then
		session.roomConnection:Disconnect()
	end
	if session.room then
		session.room:Destroy()
		session.room = nil
	end
	session.folder:Destroy()
	usedSlots[session.slot] = nil
	sessions[session.id] = nil

	for member in session.players do
		sessionByPlayer[member] = nil
		if member.Parent == Players then
			member:SetAttribute(Attr.Side, nil)
			member:SetAttribute(Attr.SessionId, nil)
			if member.Character then
				CollisionService.setCharacterSide(member.Character, nil)
			end
			StateRemote:FireClient(member, nil)
			if reason == "partner_left" then
				-- Сразу ставим на площадку случайного подбора — ждать нового напарника
				teleport(member, WorldService.getRandomPadCFrame())
				NotifyRemote:FireClient(
					member,
					"Напарник вышел. Ищем тебе нового напарника…",
					"error"
				)
			else
				teleport(member, WorldService.getLobbyCFrame())
			end
		end
	end
end

function SessionService.Init(services)
	CollisionService = services.CollisionService
	WorldService = services.WorldService
	EconomyService = services.EconomyService

	NotifyRemote = Net.get("Notify")
	StateRemote = Net.get("SessionState")
	SubmitCodeRemote = Net.get("SubmitCode")
end

function SessionService.Start()
	local function onCharacterAdded(player: Player, character: Model)
		local session = sessionByPlayer[player]
		if not session then
			CollisionService.setCharacterSide(character, nil)
			return
		end
		-- Ждём, пока персонаж появится в мире, затем ставим в комнату.
		character:WaitForChild("HumanoidRootPart", 10)
		task.defer(function()
			if sessionByPlayer[player] == session and player.Character == character then
				session:placePlayer(player)
			end
		end)
	end

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local session = sessionByPlayer[player]
		if session then
			SessionService.endSession(session, "partner_left")
		end
	end)

	Net.get("SwitchSide").OnServerEvent:Connect(function(player)
		local session = sessionByPlayer[player]
		if session then
			session:switchSide(player)
		end
	end)

	SubmitCodeRemote.OnServerEvent:Connect(function(player, keypad, code)
		local session = sessionByPlayer[player]
		if not session or not session.room then
			return
		end
		if typeof(keypad) ~= "Instance" or not keypad:IsA("BasePart") then
			return
		end
		if typeof(code) ~= "string" or #code == 0 or #code > Config.CODE_MAX_LENGTH or not code:match("^%d+$") then
			return
		end
		session.room:submitCode(player, keypad, code)
	end)
end

return SessionService
