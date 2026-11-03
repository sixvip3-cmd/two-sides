--[[
	Icons — иконки интерфейса из атласа assets/icons-sheet.png.

	КАК ПОДКЛЮЧИТЬ КАРТИНКИ (один раз):
	  1. В Studio: View (или Window) → Asset Manager → Bulk Import → выбрать assets/icons-sheet.png
	  2. Правый клик по загруженной картинке → Copy ID (или Copy Asset ID)
	  3. Вставить число ниже: SHEET_ID = "rbxassetid://ЧИСЛО"

	Пока SHEET_ID пустой, иконки рисуются фигурами (Ui.luau) или простыми символами (FALLBACK) —
	игра работает и без загрузки, но с атласом выглядит лучше.
]]

local IconMap = require(script.Parent.IconMap)

local Icons = {}

Icons.SHEET_ID = ""

-- Символы для иконок, которые не рисуются фигурами (см. Ui.luau → DRAWN).
-- Только латиница: в шрифтах Roblox нет значков вроде ✕ ✦ ⇄ — они превращаются в квадратики.
Icons.FALLBACK = {
	backspace = "<",
	exit = ">",
	eye = "o",
	info = "i",
	keypad = "#",
	lever = "/",
	skip = ">>",
	swap = "<>",
	warning = "!",
}

function Icons.hasImages(): boolean
	return Icons.SHEET_ID ~= ""
end

-- Применяет иконку к ImageLabel/ImageButton.
function Icons.apply(image: ImageLabel | ImageButton, name: string)
	local offset = IconMap.icons[name]
	assert(offset, "Нет иконки: " .. tostring(name))
	image.Image = Icons.SHEET_ID
	image.ImageRectOffset = offset
	image.ImageRectSize = Vector2.new(IconMap.cellSize, IconMap.cellSize)
end

return Icons
