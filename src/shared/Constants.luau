--[[
	Constants — общие для сервера и клиента значения.
	Здесь ничего не вычисляется, только справочник имён.
]]

local Constants = {}

-- Стороны (миры). Shared — объекты, существующие в обоих мирах.
Constants.Side = {
	Light = "Light",
	Dark = "Dark",
	Shared = "Shared",
}

-- Группы коллизий. Игрок «светлого» мира сталкивается только со светлыми и общими объектами.
Constants.CollisionGroup = {
	Light = "WorldLight",
	Dark = "WorldDark",
	Shared = "WorldShared",
	LightPlayer = "PlayerLight",
	DarkPlayer = "PlayerDark",
}

-- Имена атрибутов, которые читают и сервер, и клиент.
Constants.Attr = {
	Side = "Side", -- у деталей комнаты и у Player в сессии
	Mech = "Mech", -- тип механики детали
	Link = "Link", -- id связи «источник → получатель»
	SessionId = "SessionId", -- у Player, пока он в сессии
	CodeGroup = "CodeGroup",
	CodeIndex = "CodeIndex",
	PadTitle = "PadTitle",
	PadSolo = "PadSolo", -- площадка «Тест одному» (только в Studio)
}

-- Цвета миров (используются конструктором комнат и интерфейсом).
Constants.SideColors = {
	Light = Color3.fromRGB(255, 205, 110),
	Dark = Color3.fromRGB(140, 95, 235),
	Shared = Color3.fromRGB(78, 80, 92),
	Floor = Color3.fromRGB(58, 60, 70),
	Success = Color3.fromRGB(90, 220, 130),
	Danger = Color3.fromRGB(235, 80, 80),
}

Constants.SideNames = {
	Light = "СВЕТЛЫЙ мир",
	Dark = "ТЁМНЫЙ мир",
}

-- Список RemoteEvent'ов. Создаются сервером в ReplicatedStorage.Remotes.
Constants.Remotes = {
	"Notify", -- server → client: (text: string, kind: "info" | "success" | "error")
	"SessionState", -- server → client: (state: table?) — nil означает «в лобби»
	"OpenKeypad", -- server → client: (keypad: BasePart, length: number)
	"SubmitCode", -- client → server: (keypad: BasePart, code: string)
	"SwitchSide", -- client → server: () — сменить мир (только в соло-режиме)
}

return Constants
