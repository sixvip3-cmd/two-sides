--[[
	Комната 2 — «Ящик и мост».

	Посередине яма. Над ней два невидимых моста: светлый и тёмный.
	1) Светлый толкает ящик. В тёмном мире его «эхо» должно встать на тёмную плиту —
	   а видит эту плиту только тёмный, он и подсказывает, куда толкать.
	2) Плита держит тёмный мост → тёмный переходит яму.
	3) На той стороне тёмный дёргает рычаг → появляется светлый мост.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Side = require(ReplicatedStorage.Shared.Constants).Side

local V = Vector3.new

return {
	Id = "Room02_BoxBridge",
	Name = "Ящик и мост",
	Hints = {
		Light = "Толкай ящик туда, куда скажет напарник: он видит плиту, а ты нет",
		Dark = "Твоя плита примет «эхо» ящика. Направляй напарника! За ямой — рычаг",
	},
	Build = function(kit)
		kit:Shell(48, 72, 22, { floor = false })

		-- Пол до ямы и после
		kit:Part({ Name = "FloorNear", Size = V(48, 2, 28), Pos = V(0, -1, 22), Color = Color3.fromRGB(58, 60, 70) })
		kit:Part({ Name = "FloorFar", Size = V(48, 2, 28), Pos = V(0, -1, -22), Color = Color3.fromRGB(58, 60, 70) })

		-- Яма
		kit:Part({ Name = "PitBottom", Size = V(48, 2, 16), Pos = V(0, -31, 0), Color = Color3.fromRGB(20, 20, 26) })
		kit:KillZone(V(0, -20, 0), V(48, 12, 16))

		-- Мосты
		kit:Bridge(Side.Light, V(-12, -0.5, 0), V(8, 1, 16), "BridgeLight")
		kit:Bridge(Side.Dark, V(12, -0.5, 0), V(8, 1, 16), "BridgeDark")

		kit:Spawn(Side.Light, V(-10, 0, 30))
		kit:Spawn(Side.Dark, V(10, 0, 30))

		kit:MirrorBox(Side.Light, V(-14, 0, 20))
		kit:Plate(Side.Dark, V(10, 0, 14), "BridgeDark")

		kit:Lever(Side.Dark, V(16, 0, -20), "BridgeLight")

		kit:Exit(V(0, 0, -30), V(14, 10, 8))

		kit:Sign(
			"Этот ящик есть\nи в мире напарника",
			V(-23.8, 6, 20),
			"Right",
			Side.Light,
			10,
			4
		)
	end,
}
