--[[
	Комната 1 — «Две стороны» (обучение плитам).

	Стена с одним проёмом. В проёме две двери: светлая (мешает только светлому)
	и тёмная (мешает только тёмному).
	1) Светлый встаёт на свою плиту → открывается тёмная дверь → тёмный проходит.
	2) Тёмный за стеной встаёт на свою плиту → открывается светлая дверь → светлый проходит.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Side = require(ReplicatedStorage.Shared.Constants).Side

local V = Vector3.new

return {
	Id = "Room01_TwoSides",
	Name = "Две стороны",
	Hints = {
		Light = "Встань на светлую плиту — откроешь проход напарнику",
		Dark = "Напарник откроет тебе дверь. За стеной найди свою плиту",
	},
	Build = function(kit)
		kit:Shell(48, 60, 20)
		kit:CrossWall(0, 48, 20, 8, 10)

		kit:Door(Side.Light, V(0, 5, 0), V(8, 10, 1.6), "OpenLight")
		kit:Door(Side.Dark, V(0, 5, 0), V(8, 10, 1.6), "OpenDark")

		kit:Spawn(Side.Light, V(-8, 0, 24))
		kit:Spawn(Side.Dark, V(8, 0, 24))

		kit:Plate(Side.Light, V(-12, 0, 10), "OpenDark")
		kit:Plate(Side.Dark, V(12, 0, -12), "OpenLight")

		kit:Exit(V(0, 0, -24), V(14, 10, 8))

		kit:Sign(
			"Ты видишь только свой мир.\nГоворите друг с другом!",
			V(0, 11, 29.8),
			"Front",
			nil,
			20,
			6
		)
	end,
}
