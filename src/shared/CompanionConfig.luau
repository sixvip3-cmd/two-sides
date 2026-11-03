--[[
	CompanionConfig — компаньоны (питомцы) и яйца.

	Компаньон — светящийся шарик/кубик с глазками, летает за игроком.
	Шансы яиц показываются в магазине (требование Roblox для случайных предметов).
]]

local RGB = Color3.fromRGB

local Config = {}

Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary" }

Config.Rarities = {
	Common = { name = "Обычный", color = RGB(190, 195, 205) },
	Rare = { name = "Редкий", color = RGB(80, 160, 255) },
	Epic = { name = "Эпический", color = RGB(185, 90, 255) },
	Legendary = { name = "Легендарный", color = RGB(255, 190, 60) },
}

-- shape: "Ball" | "Block"; glow — добавить свечение
Config.Companions = {
	Spark = { name = "Искорка", rarity = "Common", color = RGB(255, 220, 120), shape = "Ball" },
	Fluff = { name = "Пушок", rarity = "Common", color = RGB(240, 240, 245), shape = "Ball" },
	Cubie = { name = "Кубик", rarity = "Common", color = RGB(120, 200, 140), shape = "Block" },
	Drop = { name = "Капля", rarity = "Common", color = RGB(90, 170, 240), shape = "Ball" },
	Leaf = { name = "Листик", rarity = "Common", color = RGB(150, 220, 80), shape = "Block" },
	Firefly = { name = "Светлячок", rarity = "Rare", color = RGB(255, 240, 90), shape = "Ball", glow = true },
	Shade = { name = "Тень", rarity = "Rare", color = RGB(70, 60, 110), shape = "Ball" },
	Crystal = { name = "Кристалл", rarity = "Rare", color = RGB(140, 240, 255), shape = "Block", glow = true },
	Cloud = { name = "Облачко", rarity = "Rare", color = RGB(220, 230, 255), shape = "Ball" },
	Comet = { name = "Комета", rarity = "Epic", color = RGB(255, 120, 60), shape = "Ball", glow = true },
	Phantom = { name = "Фантом", rarity = "Epic", color = RGB(170, 110, 255), shape = "Ball", glow = true },
	Eclipse = {
		name = "Затмение",
		rarity = "Legendary",
		color = RGB(255, 200, 70),
		shape = "Ball",
		glow = true,
	},
}

-- Порядок в инвентаре
Config.CompanionOrder = {
	"Spark",
	"Fluff",
	"Cubie",
	"Drop",
	"Leaf",
	"Firefly",
	"Shade",
	"Crystal",
	"Cloud",
	"Comet",
	"Phantom",
	"Eclipse",
}

Config.Eggs = {
	Basic = {
		name = "Обычное яйцо",
		cost = 500,
		-- шансы редкостей в процентах (в сумме 100)
		odds = { Common = 65, Rare = 27, Epic = 7, Legendary = 1 },
	},
}

Config.EggOrder = { "Basic" }

return Config
