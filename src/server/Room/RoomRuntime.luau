--[[
	RoomRuntime — одна построенная комната внутри сессии.

	* строит комнату по определению (def.Build(kit))
	* подключает механики по атрибуту Mech
	* хранит «связи» (Link): источник (плита, рычаг, панель) → получатели (двери, мосты).
	  Связь активна, если активен хотя бы один её источник.
	* раз в ZONE_TICK проверяет плиты, ямы и выход
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Zone = require(ReplicatedStorage.Shared.Zone)

local RoomKit = require(script.Parent.RoomKit)

local Attr = Constants.Attr
local Side = Constants.Side

local Mechanics = script.Parent.Mechanics
local HANDLERS = {
	Door = require(Mechanics.Gate),
	Bridge = require(Mechanics.Gate),
	Plate = require(Mechanics.Plate),
	Lever = require(Mechanics.Lever),
	MirrorBox = require(Mechanics.MirrorBox),
	Keypad = require(Mechanics.Keypad),
	CodeDigit = require(Mechanics.CodeDigit),
	Mover = require(Mechanics.Mover),
	AnomalyItem = require(Mechanics.Anomaly),
}

local RoomRuntime = {}
RoomRuntime.__index = RoomRuntime

-- Насколько далеко от центра (по X/Z) игрок считается «в комнате».
local ROOM_REACH = 150

-- Соло-тест: сколько секунд плита остаётся нажатой после того, как с неё сошли.
local SOLO_PLATE_HOLD = 6

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end
RoomRuntime.getRoot = getRoot

-- Подходит ли объект стороны `side` к зоне стороны `zoneSide`.
local function sideMatches(zoneSide: string?, side: string?): boolean
	return zoneSide == nil or zoneSide == Side.Shared or zoneSide == side
end
RoomRuntime.sideMatches = sideMatches

function RoomRuntime.new(session, def)
	local self = setmetatable({}, RoomRuntime)
	self.session = session
	self.def = def
	self.origin = session.origin
	self.Completed = Signal.new()
	self.completed = false
	self.destroyed = false

	self.links = {}
	self.plates = {}
	self.boxes = {} -- все ящики и их эхо (BasePart)
	self.keypads = {}
	self.codes = {}
	self.codeLengths = {}
	self.exits = {}
	self.killZones = {}
	self.spawns = {}
	self.inExit = {}
	self.lastRespawnNotify = {}
	self.lastCodeSubmit = {}
	self.heartbeatCallbacks = {}
	self.wiredCallbacks = {}
	self.anomalyGroups = {}
	self.connections = {}

	local model = Instance.new("Model")
	model.Name = def.Id
	self.model = model
	def.Build(RoomKit.new(model, self.origin))
	-- Сначала в мир, потом механики: SetNetworkOwner работает только для деталей в Workspace.
	model.Parent = session.folder

	self:_wire()

	local accumulator = 0
	table.insert(
		self.connections,
		RunService.Heartbeat:Connect(function(dt)
			for _, callback in self.heartbeatCallbacks do
				callback(dt)
			end
			accumulator += dt
			if accumulator >= Config.ZONE_TICK then
				accumulator = 0
				self:_tick()
			end
		end)
	)

	return self
end

function RoomRuntime:_wire()
	local parts = {}
	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(Attr.Mech) then
			table.insert(parts, descendant)
		end
	end

	-- Длины кодов считаем заранее: CodeDigit нужен весь код сразу.
	for _, part in parts do
		if part:GetAttribute(Attr.Mech) == "CodeDigit" then
			local group = part:GetAttribute(Attr.CodeGroup)
			self.codeLengths[group] = (self.codeLengths[group] or 0) + 1
		end
	end

	for _, part in parts do
		local mech = part:GetAttribute(Attr.Mech)
		if mech == "Spawn" then
			self.spawns[part:GetAttribute("SpawnSide")] = part
		elseif mech == "Exit" then
			table.insert(self.exits, part)
		elseif mech == "KillZone" then
			table.insert(self.killZones, part)
		else
			local handler = HANDLERS[mech]
			if handler then
				handler(self, part)
			else
				warn("[RoomRuntime] неизвестная механика", mech, part:GetFullName())
			end
		end
	end

	for _, callback in self.wiredCallbacks do
		callback()
	end
end

-- Колбэк после подключения всех механик комнаты (нужен механикам из нескольких деталей).
function RoomRuntime:onWired(callback: () -> ())
	table.insert(self.wiredCallbacks, callback)
end

--------------------------------------------------------------------------------
-- Связи
--------------------------------------------------------------------------------

function RoomRuntime:_link(id: string)
	local link = self.links[id]
	if not link then
		link = { sources = {}, active = false, listeners = {} }
		self.links[id] = link
	end
	return link
end

-- Источник `source` включает/выключает связь `id`.
function RoomRuntime:setSource(id: string, source: Instance, value: boolean)
	local link = self:_link(id)
	link.sources[source] = value or nil
	local active = next(link.sources) ~= nil
	if active ~= link.active then
		link.active = active
		for _, listener in link.listeners do
			task.spawn(listener, active)
		end
	end
end

-- Подписка на изменение связи. Колбэк вызывается сразу с текущим значением.
function RoomRuntime:onLink(id: string, listener: (boolean) -> ())
	local link = self:_link(id)
	table.insert(link.listeners, listener)
	listener(link.active)
end

function RoomRuntime:onHeartbeat(callback: (number) -> ())
	table.insert(self.heartbeatCallbacks, callback)
end

--------------------------------------------------------------------------------
-- Игроки
--------------------------------------------------------------------------------

function RoomRuntime:canUse(player: Player, part: BasePart): boolean
	local side = self.session.players[player]
	if not side or not part:IsDescendantOf(self.model) then
		return false
	end
	return sideMatches(part:GetAttribute(Attr.Side), side)
end

function RoomRuntime:getSpawnCFrame(side: string): CFrame
	local spawn = self.spawns[side]
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return self.origin + Vector3.new(0, 5, 0)
end

function RoomRuntime:respawnPlayer(player: Player)
	local character = player.Character
	local root = getRoot(player)
	if not character or not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(self:getSpawnCFrame(self.session.players[player]))

	local now = os.clock()
	if now - (self.lastRespawnNotify[player] or 0) > Config.RESPAWN_NOTIFY_COOLDOWN then
		self.lastRespawnNotify[player] = now
		self.session:notify(player, "Осторожно! Попробуй ещё раз", "error")
	end
end

function RoomRuntime:isInKillZone(position: Vector3): boolean
	if position.Y < self.origin.Y - Config.FALL_LIMIT then
		return true
	end
	for _, zone in self.killZones do
		if Zone.contains(zone, position, 0) then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Кодовые панели
--------------------------------------------------------------------------------

function RoomRuntime:getCode(group: string): string
	local code = self.codes[group]
	if not code then
		local digits = {}
		for i = 1, self.codeLengths[group] or 4 do
			digits[i] = tostring(math.random(0, 9))
		end
		code = table.concat(digits)
		self.codes[group] = code
	end
	return code
end

function RoomRuntime:openKeypad(player: Player, keypad: BasePart)
	local state = self.keypads[keypad]
	if not state or state.solved or not self:canUse(player, keypad) then
		return
	end
	Net.get("OpenKeypad"):FireClient(player, keypad, #self:getCode(state.group))
end

function RoomRuntime:submitCode(player: Player, keypad: BasePart, code: string)
	local state = self.keypads[keypad]
	if not state or state.solved or not self:canUse(player, keypad) then
		return
	end

	local root = getRoot(player)
	if not root or (root.Position - keypad.Position).Magnitude > Config.KEYPAD_MAX_DISTANCE then
		return
	end

	local now = os.clock()
	if now - (self.lastCodeSubmit[player] or 0) < Config.CODE_SUBMIT_COOLDOWN then
		return
	end
	self.lastCodeSubmit[player] = now

	if code == self:getCode(state.group) then
		state.solved = true
		state.onSolved()
		self:setSource(state.link, keypad, true)
		self.session:notify(nil, "Код принят! Дверь открыта", "success")
	else
		state.onWrong()
		self.session:notify(player, "Неверный код. Спроси напарника ещё раз!", "error")
	end
end

--------------------------------------------------------------------------------
-- Тик зон
--------------------------------------------------------------------------------

function RoomRuntime:_tick()
	if self.destroyed then
		return
	end
	local players = self.session.players

	local roots = {}
	for player, side in players do
		local root = getRoot(player)
		if root then
			roots[player] = { root = root, side = side }
		end
	end

	-- Падения и ловушки (только для тех, кто уже долетел до комнаты — телепорт асинхронный)
	for player, info in roots do
		local offset = info.root.Position - self.origin.Position
		local nearRoom = math.abs(offset.X) < ROOM_REACH and math.abs(offset.Z) < ROOM_REACH
		if nearRoom and self:isInKillZone(info.root.Position) then
			self:respawnPlayer(player)
		end
	end

	-- Плиты
	for _, plate in self.plates do
		local pressed = false
		for _, info in roots do
			if sideMatches(plate.side, info.side) and Zone.contains(plate.part, info.root.Position, 6) then
				pressed = true
				break
			end
		end
		if not pressed then
			for _, box in self.boxes do
				if
					box.Parent
					and sideMatches(plate.side, box:GetAttribute(Attr.Side))
					and Zone.contains(plate.part, box.Position, 5)
				then
					pressed = true
					break
				end
			end
		end
		-- Соло-тест: плита держится SOLO_PLATE_HOLD секунд после того, как с неё сошли,
		-- чтобы успеть сменить мир и пройти в открытую дверь.
		if self.session.solo then
			local now = os.clock()
			if pressed then
				plate.releasedAt = nil
			elseif plate.pressed then
				if not plate.releasedAt then
					plate.releasedAt = now
					self.session:notify(
						nil,
						"Плита держится " .. SOLO_PLATE_HOLD .. " сек — жми T и проходи!",
						"info"
					)
				end
				if now - plate.releasedAt < SOLO_PLATE_HOLD then
					pressed = true
				else
					plate.releasedAt = nil
				end
			end
		end

		if pressed ~= plate.pressed then
			plate.pressed = pressed
			plate.onChanged(pressed)
			self:setSource(plate.link, plate.part, pressed)
		end
	end

	-- Выход
	if self.completed or #self.exits == 0 then
		return
	end
	local total, inside = 0, 0
	for player in players do
		total += 1
		local info = roots[player]
		local isInside = false
		if info then
			for _, exit in self.exits do
				if Zone.contains(exit, info.root.Position, 0) then
					isInside = true
					break
				end
			end
		end
		if isInside then
			inside += 1
		end
		if isInside and not self.inExit[player] then
			self.inExit[player] = true
			self.session:notify(player, "Ты у выхода. Ждём напарника…", "info")
		elseif not isInside then
			self.inExit[player] = nil
		end
	end

	local needed = if self.session.solo then 1 else 2
	if total >= needed and inside == total then
		self.completed = true
		self.Completed:Fire()
	end
end

function RoomRuntime:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.heartbeatCallbacks)
	self.Completed:Destroy()
	self.model:Destroy()
end

return RoomRuntime
