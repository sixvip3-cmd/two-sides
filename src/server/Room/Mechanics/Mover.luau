--[[
	Mover — платформа или стена, которая плавно сдвигается на MoveOffset,
	пока связь активна, и возвращается, когда связь выключена.
	Лучше всего подходит для лифтов (вверх-вниз) и сдвижных стен.

	Атрибуты: Link, MoveOffset (Vector3), MoveTime (сек, по умолчанию 2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr

return function(room, part: BasePart)
	local offset = part:GetAttribute("MoveOffset") or Vector3.new(0, 10, 0)
	local duration = part:GetAttribute("MoveTime") or 2
	local startCFrame = part.CFrame
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	room:onLink(part:GetAttribute(Attr.Link), function(active: boolean)
		TweenService:Create(part, info, {
			CFrame = if active then startCFrame + offset else startCFrame,
		}):Play()
	end)
end
