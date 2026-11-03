--[[
	Комната 5 — «Найди отличие» (аномалия).

	Шесть предметов на пронумерованных постаментах — в обоих мирах одинаковые,
	кроме одного: у кого-то из вас он другого цвета, больше, повёрнут, висит в воздухе
	или пропал. Опишите друг другу, что видите, и оба отметьте один и тот же номер.
	Ошибка — отличие переезжает в другое место.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Side = require(ReplicatedStorage.Shared.Constants).Side

local V = Vector3.new
local RGB = Color3.fromRGB

local ITEMS = {
	{ shape = Enum.PartType.Ball, size = V(3, 3, 3), color = RGB(230, 70, 70) },
	{ shape = Enum.PartType.Block, size = V(2.6, 2.6, 2.6), color = RGB(70, 140, 235) },
	{ shape = Enum.PartType.Wedge, size = V(2.6, 2.6, 2.6), color = RGB(90, 200, 110) },
	{ shape = Enum.PartType.Ball, size = V(2.6, 2.6, 2.6), color = RGB(240, 210, 80) },
	{ shape = Enum.PartType.Block, size = V(2, 3.4, 2), color = RGB(240, 140, 60) },
	{ shape = Enum.PartType.Cylinder, size = V(3, 2.4, 2.4), color = RGB(60, 200, 200) },
}

return {
	Id = "Room05_SpotDifference",
	Name = "Найди отличие",
	Hints = {
		Light = "Опиши напарнику предметы по номерам. Одно отличие — отметьте его оба",
		Dark = "Опиши напарнику предметы по номерам. Одно отличие — отметьте его оба",
	},
	Build = function(kit)
		kit:Shell(48, 60, 20)
		kit:CrossWall(-12, 48, 20, 8, 10)
		kit:Door(Side.Shared, V(0, 5, -12), V(8, 10, 1.6), "Found")

		for index, item in ITEMS do
			local x = -20 + (index - 1) * 8
			kit:Pedestal(V(x, 0, 4), index)
			kit:AnomalyItem("Main", index, V(x, 3, 4), item.size, item.color, item.shape, "Found")
		end

		kit:Spawn(Side.Light, V(-8, 0, 22))
		kit:Spawn(Side.Dark, V(8, 0, 22))

		kit:Exit(V(0, 0, -22), V(14, 10, 8))

		kit:Sign(
			"У одного из вас один предмет отличается.\nНайдите его вместе!",
			V(0, 11, 29.8),
			"Front",
			nil,
			24,
			6
		)
	end,
}
