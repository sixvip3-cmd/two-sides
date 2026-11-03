--[[
	TutorialService — обучение новичка.

	При первом входе клиент получает ShowTutorial и показывает окно «Как играть».
	Когда игрок его закрывает (TutorialDone) — флаг сохраняется, окно больше не появляется.
	Заодно пишет первые шаги воронки новичка (Analytics → Onboarding).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Analytics = require(script.Parent.Parent.Analytics)

local TutorialService = {}

local DataService

function TutorialService.Init(services)
	DataService = services.DataService
	DataService.Loaded:Connect(function(player, data)
		if not data.TutorialDone then
			Analytics.onboarding(player, 1, "Joined")
			Net.get("ShowTutorial"):FireClient(player)
		end
	end)
end

function TutorialService.Start()
	Net.get("TutorialDone").OnServerEvent:Connect(function(player)
		local data = DataService.getData(player)
		if data and not data.TutorialDone then
			data.TutorialDone = true
			Analytics.onboarding(player, 2, "TutorialClosed")
		end
	end)
end

return TutorialService
