--[[
	Комната 3 — «Шифр».

	Две общие двери с кодовыми панелями.
	1) Цифры кода A видит только светлый (разбросаны по стенам, у каждой номер).
	   Панель A стоит в тёмном мире — светлый диктует, тёмный вводит.
	2) За первой дверью наоборот: цифры кода B видит тёмный, панель B — у светлого.
	Код каждый раз новый.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Side = require(ReplicatedStorage.Shared.Constants).Side

local V = Vector3.new

return {
	Id = "Room03_Cipher",
	Name = "Шифр",
	Hints = {
		Light = "Найди цифры первого кода и продиктуй их по номерам. Второй код вводишь ты",
		Dark = "Вводи код, который диктует напарник. За дверью — твоя очередь диктовать",
	},
	Build = function(kit)
		kit:Shell(48, 76, 20)
		kit:CrossWall(8, 48, 20, 8, 10)
		kit:CrossWall(-14, 48, 20, 8, 10)

		kit:Door(Side.Shared, V(0, 5, 8), V(8, 10, 1.6), "DoorA")
		kit:Door(Side.Shared, V(0, 5, -14), V(8, 10, 1.6), "DoorB")

		kit:Spawn(Side.Light, V(-8, 0, 30))
		kit:Spawn(Side.Dark, V(8, 0, 30))

		-- Код A: панель у тёмного, цифры у светлого
		kit:Keypad(Side.Dark, V(9, 4, 9.2), "DoorA", "A", "Back")
		kit:CodeDigit(Side.Light, V(23.8, 6, 14), "A", 1, "Left")
		kit:CodeDigit(Side.Light, V(-23.8, 6, 30), "A", 2, "Right")
		kit:CodeDigit(Side.Light, V(23.8, 6, 26), "A", 3, "Left")
		kit:CodeDigit(Side.Light, V(-23.8, 6, 18), "A", 4, "Right")

		-- Код B: панель у светлого, цифры у тёмного
		kit:Keypad(Side.Light, V(-9, 4, -12.8), "DoorB", "B", "Back")
		kit:CodeDigit(Side.Dark, V(23.8, 6, -6), "B", 1, "Left")
		kit:CodeDigit(Side.Dark, V(-12, 12, 6.8), "B", 2, "Front")
		kit:CodeDigit(Side.Dark, V(-23.8, 6, 0), "B", 3, "Right")
		kit:CodeDigit(Side.Dark, V(23.8, 6, 4), "B", 4, "Left")

		kit:Exit(V(0, 0, -28), V(14, 10, 8))
	end,
}
