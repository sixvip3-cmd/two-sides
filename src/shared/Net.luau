--[[
	Net — создание (сервер) и получение (клиент) RemoteEvent'ов по имени.
	Все имена перечислены в Constants.Remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)

local FOLDER_NAME = "Remotes"

local Net = {}

-- Вызывается один раз сервером при старте.
function Net.setup()
	assert(RunService:IsServer(), "Net.setup() вызывается только на сервере")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
	end
	for _, name in Constants.Remotes do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
end

function Net.get(name: string): RemoteEvent
	assert(table.find(Constants.Remotes, name), "Неизвестный remote: " .. tostring(name))
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(folder, "Net.setup() ещё не вызван")
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME):WaitForChild(name) :: RemoteEvent
end

return Net
