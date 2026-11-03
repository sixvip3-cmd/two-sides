--[[
	Точка входа сервера.
	Порядок: Net.setup → require всех сервисов → Init (связи между сервисами) → Start (циклы, события).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
Net.setup()

local ORDER = {
	"CollisionService",
	"WorldService",
	"DataService",
	"EconomyService",
	"CompanionService",
	"SessionService",
	"LobbyService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(script.Services[name])
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service.Init(services)
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[TWO SIDES] сервер запущен")
