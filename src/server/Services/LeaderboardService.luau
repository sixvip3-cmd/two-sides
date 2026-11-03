--[[
	LeaderboardService — рекорды пар: лучшее время прохождения главы.

	* Рекорд записывается, только если глава пройдена вдвоём (не соло) и без пропусков комнат.
	* Хранится в OrderedDataStore: ключ — «меньшийUserId_большийUserId», значение — десятые доли секунды.
	* Доска в лобби (WorldService → LeaderboardBoard) обновляется раз в 2 минуты.
	В Studio без доступа к API Services доска показывает «нет данных».
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local SeasonConfig = require(ReplicatedStorage.Shared.SeasonConfig)

local Analytics = require(script.Parent.Parent.Analytics)

local LeaderboardService = {}

local DataService
local WorldService

local REFRESH = 120
local TOP = 10

local store = nil
local nameCache: { [number]: string } = {}

local function getStore()
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore("PairChapterTimes_" .. SeasonConfig.Season.Id)
		end)
		store = if ok then result else false
	end
	return store or nil
end

local function pairKey(a: number, b: number): string
	if a > b then
		a, b = b, a
	end
	return string.format("%d_%d", a, b)
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "???"
	return nameCache[userId]
end

local function formatTime(tenths: number): string
	local seconds = tenths / 10
	return string.format("%d:%04.1f", math.floor(seconds / 60), seconds % 60)
end

-- Вызывает SessionService, когда пара прошла главу.
function LeaderboardService.onChapterCompleted(session)
	if session.solo or session.usedSkip or not session.startTime then
		return
	end
	local members = {}
	for player in session.players do
		table.insert(members, player)
	end
	if #members ~= 2 then
		return
	end

	local seconds = os.clock() - session.startTime
	local tenths = math.max(1, math.floor(seconds * 10))

	for _, player in members do
		local data = DataService.getData(player)
		if data and (data.BestChapterTime == 0 or seconds < data.BestChapterTime) then
			data.BestChapterTime = seconds
			Net.get("Notify")
				:FireClient(
					player,
					"Новый личный рекорд главы: " .. formatTime(tenths),
					"success"
				)
		end
		Analytics.custom(player, "ChapterTime", seconds)
	end

	local ordered = getStore()
	if not ordered then
		return
	end
	local key = pairKey(members[1].UserId, members[2].UserId)
	task.spawn(function()
		pcall(function()
			ordered:UpdateAsync(key, function(old)
				if old == nil or tenths < old then
					return tenths
				end
				return nil -- не перезаписывать худшим временем
			end)
		end)
	end)
end

local function refreshBoard()
	local board = WorldService.getLeaderboardBoard()
	if not board then
		return
	end
	local rows = {}
	local ordered = getStore()
	if ordered then
		local ok, pages = pcall(function()
			return ordered:GetSortedAsync(true, TOP)
		end)
		if ok and pages then
			for rank, entry in pages:GetCurrentPage() do
				local a, b = string.match(entry.key, "^(%d+)_(%d+)$")
				if a and b then
					table.insert(
						rows,
						string.format(
							"%d. %s + %s — %s",
							rank,
							nameOf(tonumber(a) :: number),
							nameOf(tonumber(b) :: number),
							formatTime(entry.value)
						)
					)
				end
			end
		end
	end
	if #rows == 0 then
		rows = {
			"Пока нет рекордов.",
			"Пройдите главу вдвоём без пропусков!",
		}
	end
	WorldService.setLeaderboardRows(rows)
end

function LeaderboardService.Init(services)
	DataService = services.DataService
	WorldService = services.WorldService
end

function LeaderboardService.Start()
	while true do
		pcall(refreshBoard)
		task.wait(REFRESH)
	end
end

return LeaderboardService
