--[[
	Gate — двери и мосты.
	Door:   связь активна → проход открыт (дверь становится призрачной и не мешает).
	Bridge: связь активна → мост твёрдый; иначе едва виден и проваливаешься.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr
local TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return function(room, part: BasePart)
	local isBridge = part:GetAttribute(Attr.Mech) == "Bridge"
	local solidTransparency = part.Transparency

	room:onLink(part:GetAttribute(Attr.Link), function(active: boolean)
		local passable = if isBridge then not active else active
		part.CanCollide = not passable
		TweenService:Create(part, TWEEN, {
			Transparency = if passable then 0.85 else solidTransparency,
		}):Play()
	end)
end
