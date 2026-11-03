--[[
	DataService — сохранение данных игрока (ProfileStore).

	* профиль загружается при входе, сохраняется автоматически и при выходе;
	* сессионная блокировка: один профиль не может быть открыт на двух серверах (защита от дюпа);
	* в Studio без доступа к API ProfileStore сам переключается на временное (mock) хранилище —
	  данные живут до конца теста. Чтобы сохранялось и в Studio:
	  Game Settings → Security → Enable Studio Access to API Services (нужна опубликованная игра).

	Наружу: getData(player), waitForData(player), onLoaded(callback), getProfile(player).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = {}

-- Меняешь структуру — просто добавь поле сюда: Reconcile допишет его старым профилям.
local TEMPLATE = {
	Shards = 0,
	TotalShardsEarned = 0,
	RoomsCompleted = 0,
	ChaptersCompleted = 0,
	SkipCredits = 0,
	Companions = {}, -- [companionId] = количество
	Equipped = "", -- id надетого компаньона
	RecentPartners = {}, -- массив UserId последних напарников
	PurchaseIds = {}, -- массив PurchaseId обработанных покупок (защита от двойного начисления)
	LastFreeEggDay = 0, -- для VIP: номер дня последнего бесплатного яйца
}

local STORE_NAME = "PlayerData_v1"

local store = ProfileStore.New(STORE_NAME, TEMPLATE)
local profiles: { [Player]: any } = {}

DataService.Loaded = Signal.new() -- (player, data)

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick(
			"Не удалось загрузить сохранение. Попробуй зайти ещё раз."
		)
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick(
			"Сохранение открыто на другом сервере. Перезайди в игру."
		)
	end)

	if player.Parent == Players then
		profiles[player] = profile
		DataService.Loaded:Fire(player, profile.Data)
	else
		profile:EndSession()
	end
end

function DataService.getProfile(player: Player)
	return profiles[player]
end

-- Данные игрока или nil, если профиль ещё не загружен.
function DataService.getData(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Ждёт загрузки профиля (до timeout секунд).
function DataService.waitForData(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < deadline do
		local data = DataService.getData(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
