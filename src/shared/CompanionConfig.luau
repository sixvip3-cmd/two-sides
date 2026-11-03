--[[
	CompanionConfig — питомцы и яйца.

	Модели питомцев — в PetSpecs.json (генерирует tools/pets.py, превью: assets/pets-preview.png).
	color — цвет акцента в интерфейсе. Шансы яиц показываются в магазине
	(требование Roblox для случайных предметов).
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

Config.Companions = {
	Kitten = { name = "Котёнок", rarity = "Common", color = RGB(246, 162, 76) },
	Puppy = { name = "Щенок", rarity = "Common", color = RGB(233, 200, 153) },
	Bunny = { name = "Зайчик", rarity = "Common", color = RGB(255, 182, 204) },
	Frog = { name = "Лягушонок", rarity = "Common", color = RGB(108, 203, 95) },
	Penguin = { name = "Пингвинёнок", rarity = "Common", color = RGB(120, 130, 190) },
	Fox = { name = "Лисёнок", rarity = "Rare", color = RGB(240, 122, 42) },
	Owl = { name = "Совёнок", rarity = "Rare", color = RGB(245, 197, 66) },
	Panda = { name = "Панда", rarity = "Rare", color = RGB(235, 235, 240) },
	Axolotl = { name = "Аксолотль", rarity = "Rare", color = RGB(247, 168, 200) },
	Unicorn = { name = "Единорог", rarity = "Epic", color = RGB(199, 164, 255) },
	Dragon = { name = "Дракончик", rarity = "Epic", color = RGB(123, 92, 255) },
	Phoenix = { name = "Феникс", rarity = "Legendary", color = RGB(255, 138, 42) },
}

-- Порядок в инвентаре
Config.CompanionOrder = {
	"Kitten",
	"Puppy",
	"Bunny",
	"Frog",
	"Penguin",
	"Fox",
	"Owl",
	"Panda",
	"Axolotl",
	"Unicorn",
	"Dragon",
	"Phoenix",
}

-- Старые id из первой версии → новые (переносятся при загрузке сохранения)
Config.Renamed = {
	Spark = "Kitten",
	Leaf = "Puppy",
	Fluff = "Bunny",
	Cubie = "Frog",
	Drop = "Penguin",
	Firefly = "Fox",
	Cloud = "Owl",
	Shade = "Panda",
	Crystal = "Axolotl",
	Phantom = "Unicorn",
	Comet = "Dragon",
	Eclipse = "Phoenix",
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
