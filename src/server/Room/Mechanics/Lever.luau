--[[
	Lever — рычаг-переключатель. Нажатие (E / тап) переключает связь.
	Пользоваться может только игрок той же стороны (проверяет сервер).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr
local Colors = Constants.SideColors

return function(room, part: BasePart)
	local link = part:GetAttribute(Attr.Link)
	local idleColor = part.Color
	local on = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Переключить"
	prompt.ObjectText = "Рычаг"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		if not room:canUse(player, part) then
			return
		end
		on = not on
		part.Color = if on then Colors.Success else idleColor
		part.Material = if on then Enum.Material.Neon else Enum.Material.Metal
		room:setSource(link, part, on)
		if on then
			local partner = room.session:getPartner(player)
			if partner then
				room.session:notify(
					partner,
					"Напарник что-то включил в своём мире…",
					"info"
				)
			end
		end
	end)
end
