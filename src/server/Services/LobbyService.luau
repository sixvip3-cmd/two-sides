--[[
	LobbyService — площадки подбора пары.

	Любая площадка работает одинаково: первые двое, кто встал на неё, через
	MATCH_COUNTDOWN секунд уходят в сессию. «Вдвоём с другом» — маленькие площадки,
	«Случайный напарник» — большая, куда встают незнакомые игроки.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Zone = require(ReplicatedStorage.Shared.Zone)

local LobbyService = {}

local SessionService
local WorldService

type PadState = {
	part: BasePart,
	title: string,
	occupants: { Player },
	countdownEnd: number?,
	countdownPair: { Player }?,
	cooldownUntil: number,
}

local pads: { PadState } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: BasePart
	end
	return nil
end

local function setLabel(pad: PadState, text: string)
	local gui = pad.part:FindFirstChild("PadLabel")
	local label = gui and gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") and label.Text ~= text then
		label.Text = text
	end
end

local function updatePad(pad: PadState, now: number)
	-- Кто сейчас стоит на площадке
	local present: { [Player]: boolean } = {}
	for _, player in Players:GetPlayers() do
		if not SessionService.isInSession(player) then
			local root = getRoot(player)
			if root and Zone.contains(pad.part, root.Position, 6) then
				present[player] = true
			end
		end
	end

	-- Сохраняем порядок прихода: кто встал раньше — тот в паре первым
	local occupants = {}
	for _, player in pad.occupants do
		if present[player] then
			table.insert(occupants, player)
			present[player] = nil
		end
	end
	for player in present do
		table.insert(occupants, player)
	end
	pad.occupants = occupants

	-- Площадка «Тест одному» (только в Studio): старт с одним игроком
	if pad.solo then
		local first = occupants[1]
		if first and now >= pad.cooldownUntil then
			if not pad.countdownEnd or not pad.countdownPair or pad.countdownPair[1] ~= first then
				pad.countdownEnd = now + Config.MATCH_COUNTDOWN
				pad.countdownPair = { first }
			end
			local left = math.ceil((pad.countdownEnd :: number) - now)
			if left <= 0 then
				pad.countdownEnd = nil
				pad.countdownPair = nil
				pad.cooldownUntil = now + Config.PAD_COOLDOWN
				SessionService.create({ first }, { solo = true })
				setLabel(pad, pad.title)
			else
				setLabel(pad, string.format("%s\nСтарт через %d…", pad.title, left))
			end
		else
			pad.countdownEnd = nil
			pad.countdownPair = nil
			setLabel(pad, pad.title .. "\nвстань сюда один")
		end
		return
	end

	if #occupants >= 2 and now >= pad.cooldownUntil then
		local first, second = occupants[1], occupants[2]
		local pair = pad.countdownPair
		if not pad.countdownEnd or not pair or pair[1] ~= first or pair[2] ~= second then
			pad.countdownEnd = now + Config.MATCH_COUNTDOWN
			pad.countdownPair = { first, second }
		end

		local left = math.ceil((pad.countdownEnd :: number) - now)
		if left <= 0 then
			pad.countdownEnd = nil
			pad.countdownPair = nil
			pad.cooldownUntil = now + Config.PAD_COOLDOWN
			SessionService.create({ first, second }, { mode = pad.mode })
			setLabel(pad, pad.title)
		else
			setLabel(
				pad,
				string.format("%s и %s\nСтарт через %d…", first.DisplayName, second.DisplayName, left)
			)
		end
	else
		pad.countdownEnd = nil
		pad.countdownPair = nil
		if #occupants == 1 then
			setLabel(pad, pad.title .. "\nЖдём второго… 1/2")
		else
			setLabel(pad, pad.title .. "\n0/2")
		end
	end
end

function LobbyService.Init(services)
	SessionService = services.SessionService
	WorldService = services.WorldService

	for _, part in WorldService.getPads() do
		table.insert(pads, {
			part = part,
			title = part:GetAttribute(Constants.Attr.PadTitle),
			solo = part:GetAttribute(Constants.Attr.PadSolo) == true,
			mode = part:GetAttribute(Constants.Attr.PadMode),
			occupants = {},
			countdownEnd = nil,
			countdownPair = nil,
			cooldownUntil = 0,
		})
	end
end

function LobbyService.Start()
	while true do
		local now = os.clock()
		for _, pad in pads do
			local ok, err = pcall(updatePad, pad, now)
			if not ok then
				warn("[LobbyService] ошибка площадки", pad.part:GetFullName(), err)
			end
		end
		task.wait(0.2)
	end
end

return LobbyService
