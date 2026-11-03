--[[
	Plate — нажимная плита. Проверку «кто стоит» делает RoomRuntime:_tick,
	здесь только регистрация и визуальная реакция.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr

return function(room, part: BasePart)
	local idleMaterial = part.Material
	table.insert(room.plates, {
		part = part,
		side = part:GetAttribute(Attr.Side),
		link = part:GetAttribute(Attr.Link),
		pressed = false,
		onChanged = function(pressed: boolean)
			part.Material = if pressed then Enum.Material.Neon else idleMaterial
			part.Position = part.Position + Vector3.new(0, if pressed then -0.15 else 0.15, 0)
		end,
	})
end
