--[[
	SeasonConfig — сезонный пропуск, задания, серия входов, ежедневная комната.

	Новый сезон: поменять Id, Name, StartTime/EndTime, награды. Прогресс старого сезона
	сбросится сам (сервер сравнивает Season.Id в сохранении).
	Время — UNIX (UTC). Посчитать: https://www.unixtimestamp.com
]]

local DAY = 86400

local Config = {}

Config.Season = {
	Id = "S1",
	Name = "Глава 1: Две стороны",
	StartTime = 1793664000, -- 2026-11-03 00:00 UTC
	EndTime = 1793664000 + 42 * DAY, -- 6 недель
	Levels = 30,
	XPPerLevel = 1000,
	PremiumPlusBonusLevels = 10,
	-- Покупка отдельных уровней открывается за столько дней до конца сезона
	LevelPurchaseWindowDays = 14,
	PartnerPremiumBonus = 0.10, -- напарник с премиумом даёт +10% XP
}

-- Откуда берётся XP
Config.XP = {
	Room = 50,
	Anomaly = 20,
	Chapter = 150,
	DailyRoom = 200,
	Quest = 500,
}

--[[
	Награды уровней. Тип награды:
	  shards (amount) · egg (amount — бесплатные яйца) · skip (amount — пропуски комнат)
	  companion (id)
]]
local function shards(amount)
	return { type = "shards", amount = amount }
end

Config.FreeRewards = {}
Config.PremiumRewards = {}
for level = 1, 30 do
	-- Бесплатная ветка: каждые 3 уровня
	if level % 3 == 0 then
		Config.FreeRewards[level] = if level % 15 == 0 then { type = "egg", amount = 1 } else shards(150)
	end
	-- Премиум: каждый уровень
	if level == 30 then
		Config.PremiumRewards[level] = { type = "companion", id = "MoonFox" }
	elseif level % 10 == 0 then
		Config.PremiumRewards[level] = { type = "egg", amount = 3 }
	elseif level % 5 == 0 then
		Config.PremiumRewards[level] = { type = "skip", amount = 2 }
	elseif level % 2 == 0 then
		Config.PremiumRewards[level] = { type = "egg", amount = 1 }
	else
		Config.PremiumRewards[level] = shards(200)
	end
end

-- Еженедельные задания: каждую неделю выбираются 3 из списка (одинаковые для всех)
Config.QuestsPerWeek = 3
Config.QuestPool = {
	{ id = "rooms10", kind = "rooms", goal = 10, text = "Пройди 10 комнат" },
	{ id = "rooms25", kind = "rooms", goal = 25, text = "Пройди 25 комнат" },
	{ id = "partners3", kind = "partners", goal = 3, text = "Сыграй с 3 разными напарниками" },
	{ id = "anomaly3", kind = "anomalies", goal = 3, text = "Найди 3 отличия между мирами" },
	{ id = "eggs2", kind = "eggs", goal = 2, text = "Открой 2 яйца" },
	{ id = "chapter1", kind = "chapters", goal = 1, text = "Пройди главу целиком" },
	{ id = "daily3", kind = "daily", goal = 3, text = "Пройди ежедневную комнату 3 раза" },
}
Config.QuestShards = 100

-- Серия ежедневных входов: награда за 1…7-й день подряд (потом снова с 1-го)
Config.LoginStreak = { 50, 75, 100, 125, 150, 200, 500 }

-- Ежедневная комната: награда один раз в день
Config.DailyRoom = {
	Shards = 100,
	-- Комната дня выбирается из этих (индексы в Rooms.list), по номеру дня
	RoomPool = { 2, 3, 4, 5 },
}

function Config.today(): number
	return math.floor(os.time() / DAY)
end

-- Номер недели (с понедельника, UTC)
function Config.week(): number
	return math.floor((os.time() / DAY + 3) / 7)
end

function Config.isSeasonActive(): boolean
	local now = os.time()
	return now >= Config.Season.StartTime and now < Config.Season.EndTime
end

-- Задания текущей недели (детерминированно по номеру недели)
function Config.weeklyQuests(week: number)
	local pool = table.clone(Config.QuestPool)
	local random = Random.new(week * 7919)
	local chosen = {}
	for _ = 1, math.min(Config.QuestsPerWeek, #pool) do
		local index = random:NextInteger(1, #pool)
		table.insert(chosen, table.remove(pool, index))
	end
	return chosen
end

return Config
