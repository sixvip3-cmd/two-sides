--[[
	Комната 4 — «Лифты».

	Выход на высоком уступе. У каждого свой лифт, но едет он по команде напарника.
	1) Тёмный встаёт на плиту → светлый лифт едет наверх, пока плита нажата.
	2) Наверху светлый дёргает рычаг → тёмный лифт поднимается (тёмный должен
	   заранее на нём стоять — договаривайтесь!).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Side = require(ReplicatedStorage.Shared.Constants).Side

local V = Vector3.new

return {
	Id = "Room04_Lifts",
	Name = "Лифты",
	Hints = {
		Light = "Напарник встанет на плиту — твой лифт поедет. Наверху дёрни рычаг",
		Dark = "Встань на плиту, чтобы поднять напарника. Потом встань на свой лифт",
	},
	Build = function(kit)
		kit:Shell(48, 64, 36)

		-- Уступ с выходом (верх на высоте 16)
		kit:Part({ Name = "Ledge", Size = V(48, 2, 18), Pos = V(0, 15, -23), Color = Color3.fromRGB(58, 60, 70) })
		kit:Part({ Name = "LedgeFace", Size = V(48, 14, 2), Pos = V(0, 7, -15), Color = Color3.fromRGB(48, 50, 60) })

		-- Лифты перед уступом: поднимаются на 16 studs
		kit:Mover(Side.Light, V(-12, 0.5, -9), V(8, 1, 8), "LiftLight", V(0, 16, 0), 2.5)
		kit:Mover(Side.Dark, V(12, 0.5, -9), V(8, 1, 8), "LiftDark", V(0, 16, 0), 2.5)

		kit:Spawn(Side.Light, V(-8, 0, 26))
		kit:Spawn(Side.Dark, V(8, 0, 26))

		kit:Plate(Side.Dark, V(-2, 0, 4), "LiftLight")
		kit:Lever(Side.Light, V(-16, 16, -26), "LiftDark")

		kit:Exit(V(8, 16, -26), V(12, 8, 8))
	end,
}
