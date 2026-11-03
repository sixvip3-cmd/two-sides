--[[
	SeasonService — сезонный пропуск, еженедельные задания, серия входов, ежедневная комната.

	* XP за комнаты, отличия, главу, ежедневную комнату и задания → уровни пропуска.
	  Награды выдаются автоматически при достижении уровня (премиум — если куплен;
	  при покупке премиума выдаются сразу за все уже пройденные уровни).
	* Напарник с премиумом даёт +10% XP.
	* Задания: 3 в неделю, одинаковые у всех, сбрасываются в понедельник (UTC).
	* Серия входов: награда за 1…7-й день подряд; пропустил день — серия с начала.
	* Ежедневная комната: награда один раз в день.
	Новый сезон (другой Id в SeasonConfig) — прогресс пропуска сбрасывается сам.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CompanionConfig = require(ReplicatedStorage.Shared.CompanionConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local SeasonConfig = require(ReplicatedStorage.Shared.SeasonConfig)

local Analytics = require(script.Parent.Parent.Analytics)

local SeasonService = {}

local DataService
local EconomyService
local CompanionService

local Season = SeasonConfig.Season
local XP = SeasonConfig.XP

local NotifyRemote: RemoteEvent
local StateRemote: RemoteEvent

local function notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

local function levelOf(xp: number): number
	return math.min(Season.Levels, math.floor(xp / Season.XPPerLevel))
end

-- Сбросить прогресс, если сменился сезон или неделя
local function ensureCurrent(data)
	if data.Season.Id ~= Season.Id then
		data.Season = { Id = Season.Id, XP = 0, Premium = false, ClaimedFree = 0, ClaimedPremium = 0 }
	end
	local week = SeasonConfig.week()
	if data.Quests.Week ~= week then
		data.Quests = { Week = week, Progress = {}, Done = {}, Partners = {} }
	end
end

local function canBuyLevel(data): boolean
	local daysLeft = (Season.EndTime - os.time()) / 86400
	return SeasonConfig.isSeasonActive()
		and daysLeft <= Season.LevelPurchaseWindowDays
		and levelOf(data.Season.XP) < Season.Levels
end

--------------------------------------------------------------------------------
-- Состояние для клиента
--------------------------------------------------------------------------------

function SeasonService.sendState(player: Player)
	local data = DataService.getData(player)
	if not data then
		return
	end
	ensureCurrent(data)
	local season = data.Season
	local level = levelOf(season.XP)

	local quests = {}
	for _, quest in SeasonConfig.weeklyQuests(data.Quests.Week) do
		table.insert(quests, {
			id = quest.id,
			text = quest.text,
			goal = quest.goal,
			progress = math.min(data.Quests.Progress[quest.id] or 0, quest.goal),
			done = data.Quests.Done[quest.id] == true,
		})
	end

	StateRemote:FireClient(player, {
		active = SeasonConfig.isSeasonActive(),
		name = Season.Name,
		endTime = Season.EndTime,
		level = level,
		xp = season.XP,
		xpInLevel = if level >= Season.Levels then Season.XPPerLevel else season.XP % Season.XPPerLevel,
		xpPerLevel = Season.XPPerLevel,
		levels = Season.Levels,
		premium = season.Premium,
		quests = quests,
		weekEnds = (data.Quests.Week + 1) * 7 * 86400 - 3 * 86400,
		streak = data.Login.Streak,
		dailyDone = data.DailyRoomDay == SeasonConfig.today(),
		canBuyLevel = canBuyLevel(data),
	})
end

--------------------------------------------------------------------------------
-- Награды и XP
--------------------------------------------------------------------------------

local function grantReward(player: Player, reward, label: string)
	local data = DataService.getData(player)
	if not data or not reward then
		return
	end
	if reward.type == "shards" then
		EconomyService.addShards(player, reward.amount, true, "TimedReward", label)
		notify(player, string.format("Награда пропуска: +%d осколков", reward.amount), "success")
	elseif reward.type == "egg" then
		data.EggTokens += reward.amount
		notify(
			player,
			string.format(
				"Награда пропуска: бесплатное яйцо x%d (в магазине)",
				reward.amount
			),
			"success"
		)
	elseif reward.type == "skip" then
		data.SkipCredits += reward.amount
		notify(
			player,
			string.format("Награда пропуска: пропуск комнаты x%d", reward.amount),
			"success"
		)
	elseif reward.type == "companion" then
		CompanionService.grant(player, reward.id)
		local def = CompanionConfig.Companions[reward.id]
		notify(
			player,
			"Награда пропуска: питомец «" .. (def and def.name or reward.id) .. "»!",
			"success"
		)
	end
end

-- Выдать все награды до текущего уровня, которые ещё не выданы
local function claimRewards(player: Player)
	local data = DataService.getData(player)
	if not data then
		return
	end
	local season = data.Season
	local level = levelOf(season.XP)
	for lvl = season.ClaimedFree + 1, level do
		grantReward(player, SeasonConfig.FreeRewards[lvl], "PassFree" .. lvl)
	end
	season.ClaimedFree = math.max(season.ClaimedFree, level)
	if season.Premium then
		for lvl = season.ClaimedPremium + 1, level do
			grantReward(player, SeasonConfig.PremiumRewards[lvl], "PassPremium" .. lvl)
		end
		season.ClaimedPremium = math.max(season.ClaimedPremium, level)
	end
	EconomyService.sendInventory(player)
end

-- session — чтобы учесть бонус от премиума напарника (необязательно)
function SeasonService.addXP(player: Player, amount: number, session: any?)
	local data = DataService.getData(player)
	if not data or amount <= 0 or not SeasonConfig.isSeasonActive() then
		return
	end
	ensureCurrent(data)

	if session then
		local partner = session:getPartner(player)
		local partnerData = partner and DataService.getData(partner)
		if partnerData and partnerData.Season.Id == Season.Id and partnerData.Season.Premium then
			amount = math.floor(amount * (1 + Season.PartnerPremiumBonus))
		end
	end

	local before = levelOf(data.Season.XP)
	data.Season.XP = math.min(data.Season.XP + amount, Season.Levels * Season.XPPerLevel)
	local after = levelOf(data.Season.XP)
	if after > before then
		notify(player, string.format("Уровень пропуска %d!", after), "success")
		Analytics.custom(player, "PassLevel", after)
		claimRewards(player)
	end
	SeasonService.sendState(player)
end

--------------------------------------------------------------------------------
-- Задания
--------------------------------------------------------------------------------

-- kind: rooms | partners | anomalies | eggs | chapters | daily; extra — UserId напарника для partners
function SeasonService.progress(player: Player, kind: string, amount: number, extra: any?)
	local data = DataService.getData(player)
	if not data then
		return
	end
	ensureCurrent(data)
	local quests = data.Quests

	if kind == "partners" then
		if typeof(extra) ~= "number" or table.find(quests.Partners, extra) then
			return
		end
		table.insert(quests.Partners, extra)
	end

	for _, quest in SeasonConfig.weeklyQuests(quests.Week) do
		if quest.kind == kind and not quests.Done[quest.id] then
			local value = if kind == "partners" then #quests.Partners else (quests.Progress[quest.id] or 0) + amount
			quests.Progress[quest.id] = value
			if value >= quest.goal then
				quests.Done[quest.id] = true
				notify(player, "Задание выполнено: " .. quest.text, "success")
				EconomyService.addShards(player, SeasonConfig.QuestShards, true, "Gameplay", "Quest_" .. quest.id)
				SeasonService.addXP(player, XP.Quest)
			end
		end
	end
	SeasonService.sendState(player)
end

--------------------------------------------------------------------------------
-- Хуки игры (вызывает SessionService и механики)
--------------------------------------------------------------------------------

function SeasonService.onSessionStarted(session)
	if session.solo then
		return
	end
	for player in session.players do
		local partner = session:getPartner(player)
		if partner then
			SeasonService.progress(player, "partners", 1, partner.UserId)
		end
	end
end

function SeasonService.onRoomCompleted(session, skipped: boolean)
	for player in session.players do
		if not skipped then
			SeasonService.addXP(player, XP.Room, session)
		end
		SeasonService.progress(player, "rooms", 1)
	end
end

function SeasonService.onChapterCompleted(session)
	for player in session.players do
		SeasonService.addXP(player, XP.Chapter, session)
		SeasonService.progress(player, "chapters", 1)
	end
end

function SeasonService.onAnomalyFound(session)
	for player in session.players do
		SeasonService.addXP(player, XP.Anomaly, session)
		SeasonService.progress(player, "anomalies", 1)
	end
end

function SeasonService.onDailyCompleted(session)
	local today = SeasonConfig.today()
	for player in session.players do
		local data = DataService.getData(player)
		if data then
			if data.DailyRoomDay == today then
				notify(
					player,
					"Награда за ежедневную комнату сегодня уже получена",
					"info"
				)
			else
				data.DailyRoomDay = today
				EconomyService.addShards(player, SeasonConfig.DailyRoom.Shards, true, "TimedReward", "DailyRoom")
				notify(
					player,
					string.format(
						"Ежедневная комната пройдена: +%d осколков",
						SeasonConfig.DailyRoom.Shards
					),
					"success"
				)
				SeasonService.addXP(player, XP.DailyRoom, session)
				SeasonService.progress(player, "daily", 1)
			end
		end
	end
end

-- Индекс комнаты дня в Rooms.list
function SeasonService.dailyRoomIndex(): number
	local pool = SeasonConfig.DailyRoom.RoomPool
	return pool[SeasonConfig.today() % #pool + 1]
end

--------------------------------------------------------------------------------
-- Вход в игру: серия входов
--------------------------------------------------------------------------------

local function onLoaded(player: Player, data)
	ensureCurrent(data)

	local today = SeasonConfig.today()
	local login = data.Login
	if login.LastDay ~= today then
		if login.LastDay == today - 1 then
			login.Streak = login.Streak % #SeasonConfig.LoginStreak + 1
		else
			login.Streak = 1
		end
		login.LastDay = today
		local amount = SeasonConfig.LoginStreak[login.Streak]
		EconomyService.addShards(player, amount, true, "TimedReward", "LoginDay" .. login.Streak)
		Net.get("DailyReward"):FireClient(player, { streak = login.Streak, amount = amount })
	end

	-- Награды, которые могли не выдаться (например, сервер закрылся в момент повышения уровня)
	claimRewards(player)
	SeasonService.sendState(player)
end

--------------------------------------------------------------------------------
-- Покупки пропуска
--------------------------------------------------------------------------------

local function registerProducts()
	local function notPremiumCheck(player: Player): (boolean, string?)
		local data = DataService.getData(player)
		if not data then
			return false, "Данные ещё загружаются"
		end
		if not SeasonConfig.isSeasonActive() then
			return false, "Сезон сейчас не идёт"
		end
		ensureCurrent(data)
		if data.Season.Premium then
			return false, "Премиум уже куплен"
		end
		return true
	end

	EconomyService.registerGrant("SeasonPremium", function(player)
		local data = DataService.getData(player)
		ensureCurrent(data)
		data.Season.Premium = true
		notify(player, "Премиум-пропуск активирован!", "success")
		claimRewards(player)
		SeasonService.sendState(player)
	end, notPremiumCheck)

	EconomyService.registerGrant("SeasonPremiumPlus", function(player)
		local data = DataService.getData(player)
		ensureCurrent(data)
		data.Season.Premium = true
		data.Season.XP = math.min(
			data.Season.XP + Season.PremiumPlusBonusLevels * Season.XPPerLevel,
			Season.Levels * Season.XPPerLevel
		)
		notify(player, "Премиум+ активирован: +10 уровней!", "success")
		claimRewards(player)
		SeasonService.sendState(player)
	end, notPremiumCheck)

	EconomyService.registerGrant("SeasonLevel", function(player)
		local data = DataService.getData(player)
		ensureCurrent(data)
		local nextLevel = math.min(levelOf(data.Season.XP) + 1, Season.Levels)
		data.Season.XP = math.max(data.Season.XP, nextLevel * Season.XPPerLevel)
		notify(player, string.format("Уровень пропуска %d!", nextLevel), "success")
		claimRewards(player)
		SeasonService.sendState(player)
	end, function(player)
		local data = DataService.getData(player)
		if not data then
			return false, "Данные ещё загружаются"
		end
		ensureCurrent(data)
		if canBuyLevel(data) then
			return true
		end
		return false,
			"Уровни можно купить только в последние 2 недели сезона"
	end)
end

function SeasonService.Init(services)
	DataService = services.DataService
	EconomyService = services.EconomyService
	CompanionService = services.CompanionService

	NotifyRemote = Net.get("Notify")
	StateRemote = Net.get("SeasonState")

	registerProducts()
	DataService.Loaded:Connect(onLoaded)
end

function SeasonService.Start()
	Net.get("RequestSeason").OnServerEvent:Connect(function(player)
		SeasonService.sendState(player)
	end)

	-- Раз в минуту: если наступила новая неделя/сезон, обновить игрокам задания
	task.spawn(function()
		local week = SeasonConfig.week()
		while true do
			task.wait(60)
			if SeasonConfig.week() ~= week then
				week = SeasonConfig.week()
				for _, player in Players:GetPlayers() do
					SeasonService.sendState(player)
				end
			end
		end
	end)
end

return SeasonService
