--[[
	EconomyService — осколки, награды, покупки.

	* Осколки: addShards / spendShards; баланс виден в атрибуте Player.Shards и в leaderstats.
	* Награды: за комнату и главу; x2 с пассом; +25% с новым напарником.
	* Покупки (ProcessReceipt): начисление → запись PurchaseId в профиль → ждём сохранения →
	  только тогда PurchaseGranted. Повторный чек с тем же PurchaseId не начисляет второй раз.
	* В Studio товары с id = 0 «покупаются» бесплатно (симуляция) — для теста.
	* PolicyService: там, где платные случайные предметы запрещены, наборы осколков за Robux
	  не продаются (яйца открываются только за заработанные осколки).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local Net = require(ReplicatedStorage.Shared.Net)

local EconomyService = {}

local DataService
local SessionService

local IS_STUDIO = RunService:IsStudio()
local MAX_PURCHASE_IDS = 100
local SAVE_WAIT = 15

local Rewards = EconomyConfig.Rewards
local Products = EconomyConfig.Products
local GamePasses = EconomyConfig.GamePasses

local ownedPasses: { [Player]: { [string]: boolean } } = {}
local shardPacksAllowed: { [Player]: boolean } = {}
local productKeyById: { [number]: string } = {}
local passKeyById: { [number]: string } = {}

local NotifyRemote: RemoteEvent
local InventoryRemote: RemoteEvent

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

local function today(): number
	return math.floor(os.time() / 86400)
end

--------------------------------------------------------------------------------
-- Баланс и инвентарь
--------------------------------------------------------------------------------

local function updateBalanceDisplay(player: Player, data)
	player:SetAttribute("Shards", data.Shards)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("💠")
	if value and value:IsA("IntValue") then
		value.Value = data.Shards
	end
end

function EconomyService.hasPass(player: Player, key: string): boolean
	local owned = ownedPasses[player]
	return owned ~= nil and owned[key] == true
end

function EconomyService.isFreeEggAvailable(player: Player): boolean
	local data = DataService.getData(player)
	return data ~= nil and EconomyService.hasPass(player, "VIP") and data.LastFreeEggDay < today()
end

function EconomyService.useFreeEgg(player: Player): boolean
	if not EconomyService.isFreeEggAvailable(player) then
		return false
	end
	DataService.getData(player).LastFreeEggDay = today()
	return true
end

function EconomyService.sendInventory(player: Player)
	local data = DataService.getData(player)
	if not data then
		return
	end
	local passes = {}
	for key in GamePasses do
		passes[key] = EconomyService.hasPass(player, key)
	end
	InventoryRemote:FireClient(player, {
		shards = data.Shards,
		companions = data.Companions,
		equipped = data.Equipped,
		skipCredits = data.SkipCredits,
		passes = passes,
		shardPacksAllowed = shardPacksAllowed[player] == true,
		freeEgg = EconomyService.isFreeEggAvailable(player),
	})
end

-- earned = true — заработано в игре (идёт в статистику), false — куплено
function EconomyService.addShards(player: Player, amount: number, earned: boolean?): boolean
	local data = DataService.getData(player)
	if not data or amount <= 0 then
		return false
	end
	data.Shards += amount
	if earned then
		data.TotalShardsEarned += amount
	end
	updateBalanceDisplay(player, data)
	EconomyService.sendInventory(player)
	return true
end

function EconomyService.spendShards(player: Player, amount: number): boolean
	local data = DataService.getData(player)
	if not data or amount < 0 or data.Shards < amount then
		return false
	end
	data.Shards -= amount
	updateBalanceDisplay(player, data)
	EconomyService.sendInventory(player)
	return true
end

--------------------------------------------------------------------------------
-- Награды за игру
--------------------------------------------------------------------------------

local function rewardMultiplier(player: Player, session): number
	local multiplier = 1
	if EconomyService.hasPass(player, "DoubleShards") then
		multiplier *= 2
	end
	if session.newPartner and session.newPartner[player] then
		multiplier *= 1 + Rewards.NewPartnerBonus
	end
	return multiplier
end

-- Вызывается SessionService при старте сессии: отмечаем «новых» напарников.
function EconomyService.onSessionStarted(session)
	session.newPartner = {}
	if session.solo then
		return
	end
	for player in session.players do
		local partner = session:getPartner(player)
		local data = DataService.getData(player)
		if partner and data then
			local isNew = table.find(data.RecentPartners, partner.UserId) == nil
			session.newPartner[player] = isNew
			if isNew then
				table.insert(data.RecentPartners, partner.UserId)
				while #data.RecentPartners > Rewards.RecentPartnersLimit do
					table.remove(data.RecentPartners, 1)
				end
				notify(player, "Новый напарник: +25% осколков в этой игре!", "success")
			end
		end
	end
end

function EconomyService.onRoomCompleted(session, skipped: boolean)
	for player in session.players do
		local data = DataService.getData(player)
		if data then
			data.RoomsCompleted += 1
			if not skipped then
				local amount = math.floor(Rewards.RoomComplete * rewardMultiplier(player, session))
				if EconomyService.addShards(player, amount, true) then
					notify(player, string.format("+%d 💠 за комнату", amount), "success")
				end
			end
		end
	end
end

function EconomyService.onChapterCompleted(session)
	for player in session.players do
		local data = DataService.getData(player)
		if data then
			data.ChaptersCompleted += 1
			local amount = math.floor(Rewards.ChapterComplete * rewardMultiplier(player, session))
			if EconomyService.addShards(player, amount, true) then
				notify(player, string.format("+%d 💠 за главу!", amount), "success")
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Пропуск комнаты
--------------------------------------------------------------------------------

-- Тратит кредит пропуска, если игрок в комнате. true — комната пропущена.
function EconomyService.tryUseSkip(player: Player): boolean
	local data = DataService.getData(player)
	local session = SessionService.getSession(player)
	if not data or data.SkipCredits <= 0 or not session then
		return false
	end
	if session:skipRoom(player) then
		data.SkipCredits -= 1
		EconomyService.sendInventory(player)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Выдача товаров
--------------------------------------------------------------------------------

local GRANTS: { [string]: (Player) -> () } = {}

GRANTS.SkipRoom = function(player)
	local data = DataService.getData(player)
	data.SkipCredits += 1
	if not EconomyService.tryUseSkip(player) then
		notify(
			player,
			"Пропуск сохранён — используй его в любой комнате",
			"success"
		)
		EconomyService.sendInventory(player)
	end
end

for _, key in EconomyConfig.ShardPackOrder do
	GRANTS[key] = function(player)
		local amount = Products[key].shards
		EconomyService.addShards(player, amount, false)
		notify(player, string.format("+%d 💠 — спасибо за покупку!", amount), "success")
	end
end

local function grantPass(player: Player, key: string)
	ownedPasses[player] = ownedPasses[player] or {}
	ownedPasses[player][key] = true
	if key == "VIP" then
		player:SetAttribute("VIP", true)
	end
	EconomyService.sendInventory(player)
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not DataService.waitForData(player, 10) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.getProfile(player)
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = profile.Data
	if table.find(data.PurchaseIds, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = productKeyById[receipt.ProductId]
	local grant = key and GRANTS[key]
	if not grant then
		warn("[EconomyService] неизвестный ProductId", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(grant, player)
	if not ok then
		warn("[EconomyService] ошибка выдачи", key, err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.PurchaseIds, receipt.PurchaseId)
	while #data.PurchaseIds > MAX_PURCHASE_IDS do
		table.remove(data.PurchaseIds, 1)
	end

	-- Ждём, пока покупка реально сохранится в DataStore
	local saved = false
	local connection = profile.OnAfterSave:Connect(function(lastSaved)
		if table.find(lastSaved.PurchaseIds, receipt.PurchaseId) then
			saved = true
		end
	end)
	profile:Save()
	local deadline = os.clock() + SAVE_WAIT
	while not saved and os.clock() < deadline and profile:IsActive() do
		task.wait(0.2)
	end
	connection:Disconnect()

	if saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- Не сохранилось: Roblox повторит чек позже; на этом сервере PurchaseId уже записан,
	-- поэтому второй раз товар не выдастся.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Покупка по ключу из EconomyConfig (Products или GamePasses).
local function onPurchaseRequest(player: Player, key: any)
	if typeof(key) ~= "string" then
		return
	end

	local product = Products[key]
	if product then
		if string.sub(key, 1, 6) == "Shards" and not shardPacksAllowed[player] then
			notify(player, "Наборы осколков недоступны в твоём регионе", "error")
			return
		end
		if product.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.id)
		elseif IS_STUDIO then
			notify(player, "[Studio] Тестовая покупка: " .. product.title, "info")
			GRANTS[key](player)
		else
			notify(player, "Этот товар ещё не настроен", "error")
		end
		return
	end

	local pass = GamePasses[key]
	if pass then
		if EconomyService.hasPass(player, key) then
			notify(player, "Уже куплено!", "info")
		elseif pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		elseif IS_STUDIO then
			notify(player, "[Studio] Тестовая покупка: " .. pass.title, "info")
			grantPass(player, key)
		else
			notify(player, "Этот пасс ещё не настроен", "error")
		end
	end
end

--------------------------------------------------------------------------------

local function setupPlayer(player: Player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local shards = Instance.new("IntValue")
	shards.Name = "💠"
	shards.Value = data.Shards
	shards.Parent = leaderstats
	leaderstats.Parent = player
	updateBalanceDisplay(player, data)

	ownedPasses[player] = ownedPasses[player] or {}
	for key, pass in GamePasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end

	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if ok and policy then
		shardPacksAllowed[player] = not policy.ArePaidRandomItemsRestricted
	else
		-- Не удалось узнать правила: в Studio разрешаем, в игре — осторожно запрещаем
		shardPacksAllowed[player] = IS_STUDIO
	end

	EconomyService.sendInventory(player)
end

function EconomyService.Init(services)
	DataService = services.DataService
	SessionService = services.SessionService

	NotifyRemote = Net.get("Notify")
	InventoryRemote = Net.get("Inventory")

	for key, product in Products do
		if product.id ~= 0 then
			productKeyById[product.id] = key
		end
	end
	for key, pass in GamePasses do
		if pass.id ~= 0 then
			passKeyById[pass.id] = key
		end
	end

	DataService.Loaded:Connect(setupPlayer)
end

function EconomyService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key then
			grantPass(player, key)
			notify(player, "Пасс «" .. GamePasses[key].title .. "» активирован!", "success")
		end
	end)

	Net.get("Purchase").OnServerEvent:Connect(onPurchaseRequest)

	Net.get("UseSkip").OnServerEvent:Connect(function(player)
		local data = DataService.getData(player)
		if not data or not SessionService.getSession(player) then
			return
		end
		if data.SkipCredits > 0 then
			EconomyService.tryUseSkip(player)
		else
			onPurchaseRequest(player, "SkipRoom")
		end
	end)

	Net.get("RequestInventory").OnServerEvent:Connect(function(player)
		EconomyService.sendInventory(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
		shardPacksAllowed[player] = nil
	end)
end

return EconomyService
