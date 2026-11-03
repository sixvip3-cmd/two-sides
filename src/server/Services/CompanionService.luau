--[[
	CompanionService — компаньоны и яйца.

	* OpenEgg(eggId): списывает осколки (или бесплатное яйцо VIP), выбирает редкость по шансам,
	  затем случайного компаньона этой редкости. Результат → EggResult на клиент.
	* EquipCompanion(id | ""): надеть/снять.
	* Надетый компаньон — светящаяся фигурка с глазками, летает за плечом (AlignPosition).
	  Физику считает клиент владельца, поэтому движение плавное.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CompanionConfig = require(ReplicatedStorage.Shared.CompanionConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local PetModels = require(ReplicatedStorage.Shared.PetModels)

local CompanionService = {}

local DataService
local EconomyService

local EGG_COOLDOWN = 0.8
local FOLLOW_OFFSET = Vector3.new(2.4, 1.6, 1.8)

local lastEggOpen: { [Player]: number } = {}
local random = Random.new()

--------------------------------------------------------------------------------
-- Выпадение
--------------------------------------------------------------------------------

local byRarity: { [string]: { string } } = {}
for _, id in CompanionConfig.CompanionOrder do
	local rarity = CompanionConfig.Companions[id].rarity
	byRarity[rarity] = byRarity[rarity] or {}
	table.insert(byRarity[rarity], id)
end

local function rollRarity(odds: { [string]: number }): string
	local total = 0
	for _, rarity in CompanionConfig.RarityOrder do
		total += odds[rarity] or 0
	end
	local roll = random:NextNumber(0, total)
	local acc = 0
	for _, rarity in CompanionConfig.RarityOrder do
		acc += odds[rarity] or 0
		if roll <= acc and (odds[rarity] or 0) > 0 then
			return rarity
		end
	end
	return CompanionConfig.RarityOrder[1]
end

local function rollCompanion(egg): string
	local rarity = rollRarity(egg.odds)
	local pool = byRarity[rarity] or byRarity.Common
	return pool[random:NextInteger(1, #pool)]
end

--------------------------------------------------------------------------------
-- Внешний вид
--------------------------------------------------------------------------------

-- Масштаб питомца рядом с игроком (модели в PetSpecs примерно 2.3 studs ростом)
local PET_SCALE = 0.75

local function removeCompanion(character: Model)
	local existing = character:FindFirstChild("Companion")
	if existing then
		existing:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local target = root and root:FindFirstChild("CompanionTarget")
	if target then
		target:Destroy()
	end
end

local function attachCompanion(player: Player)
	local character = player.Character
	local data = DataService.getData(player)
	if not character or not data then
		return
	end
	removeCompanion(character)

	local def = CompanionConfig.Companions[data.Equipped]
	local root = character:FindFirstChild("HumanoidRootPart")
	if not def or not root or not root:IsA("BasePart") then
		return
	end

	local target = Instance.new("Attachment")
	target.Name = "CompanionTarget"
	target.Position = FOLLOW_OFFSET
	target.Parent = root

	local model = PetModels.build(data.Equipped, root.CFrame * CFrame.new(FOLLOW_OFFSET), PET_SCALE)
	if not model or not model.PrimaryPart then
		target:Destroy()
		return
	end
	model.Name = "Companion"
	local body = model.PrimaryPart
	local attachment = Instance.new("Attachment")
	attachment.Name = "CompanionAttachment"
	attachment.Parent = body

	local align = Instance.new("AlignPosition")
	align.Attachment0 = attachment
	align.Attachment1 = target
	align.Responsiveness = 18
	align.MaxForce = 1e6
	align.Parent = body

	local orient = Instance.new("AlignOrientation")
	orient.Attachment0 = attachment
	orient.Attachment1 = target
	orient.Responsiveness = 18
	orient.MaxTorque = 1e6
	orient.Parent = body

	model.Parent = character
	pcall(function()
		body:SetNetworkOwner(player)
	end)
end

--------------------------------------------------------------------------------
-- Запросы клиента
--------------------------------------------------------------------------------

local function onOpenEgg(player: Player, eggId: any, useFree: any)
	if typeof(eggId) ~= "string" then
		return
	end
	local egg = CompanionConfig.Eggs[eggId]
	local data = DataService.getData(player)
	if not egg or not data then
		return
	end

	local now = os.clock()
	if now - (lastEggOpen[player] or 0) < EGG_COOLDOWN then
		return
	end
	lastEggOpen[player] = now

	local paid = false
	if useFree == true then
		paid = EconomyService.useFreeEgg(player)
	end
	if not paid then
		paid = EconomyService.spendShards(player, egg.cost)
	end
	if not paid then
		Net.get("Notify"):FireClient(player, "Не хватает осколков", "error")
		return
	end

	local companionId = rollCompanion(egg)
	local isNew = (data.Companions[companionId] or 0) == 0
	data.Companions[companionId] = (data.Companions[companionId] or 0) + 1
	if data.Equipped == "" then
		data.Equipped = companionId
		attachCompanion(player)
	end

	Net.get("EggResult"):FireClient(player, { companion = companionId, isNew = isNew })
	EconomyService.sendInventory(player)
end

local function onEquip(player: Player, companionId: any)
	local data = DataService.getData(player)
	if not data or typeof(companionId) ~= "string" then
		return
	end
	if companionId ~= "" and (data.Companions[companionId] or 0) <= 0 then
		return
	end
	data.Equipped = companionId
	attachCompanion(player)
	EconomyService.sendInventory(player)
end

function CompanionService.Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService

	DataService.Loaded:Connect(function(player, data)
		-- Перенос старых id питомцев (первая версия) на новые
		for oldId, newId in CompanionConfig.Renamed do
			local count = data.Companions[oldId]
			if count then
				data.Companions[newId] = (data.Companions[newId] or 0) + count
				data.Companions[oldId] = nil
			end
			if data.Equipped == oldId then
				data.Equipped = newId
			end
		end
		if data.Equipped ~= "" and not CompanionConfig.Companions[data.Equipped] then
			data.Equipped = ""
		end
		if player.Character then
			attachCompanion(player)
		end
	end)
end

function CompanionService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.defer(attachCompanion, player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	Net.get("OpenEgg").OnServerEvent:Connect(onOpenEgg)
	Net.get("EquipCompanion").OnServerEvent:Connect(onEquip)

	Players.PlayerRemoving:Connect(function(player)
		lastEggOpen[player] = nil
	end)
end

return CompanionService
