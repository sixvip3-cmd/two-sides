--[[
	RoomKit — конструктор комнат из кода.

	Все координаты — относительно центра комнаты на уровне пола (y = 0 — верх пола).
	Каждой детали проставляются атрибуты Side (Light/Dark/Shared) и, если нужно, Mech и Link.
	По этим атрибутам RoomRuntime подключает механики, а клиент решает, что показывать.

	Позже комнаты можно собирать вручную в Studio: достаточно ставить те же атрибуты на детали.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CollisionService = require(script.Parent.Parent.Services.CollisionService)

local Side = Constants.Side
local Attr = Constants.Attr
local Colors = Constants.SideColors

local RoomKit = {}
RoomKit.__index = RoomKit

export type PartSpec = {
	Name: string?,
	Size: Vector3,
	Pos: Vector3,
	Rot: CFrame?,
	Side: string?,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Anchored: boolean?,
	Mech: string?,
	Link: string?,
	Attrs: { [string]: any }?,
}

function RoomKit.new(model: Model, origin: CFrame)
	return setmetatable({ model = model, origin = origin }, RoomKit)
end

local function addSurfaceText(part: BasePart, face: string, text: string, color: Color3?, background: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = Enum.NormalId[face]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = background and 0 or 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = label

	gui.Parent = part
	return label
end
RoomKit.addSurfaceText = addSurfaceText

-- Размер таблички для грани: на гранях Left/Right деталь тонкая по X, иначе по Z.
local function panelSize(face: string, width: number, height: number): Vector3
	if face == "Left" or face == "Right" then
		return Vector3.new(0.4, height, width)
	end
	return Vector3.new(width, height, 0.4)
end

function RoomKit:Part(spec: PartSpec): Part
	local side = spec.Side or Side.Shared
	local part = Instance.new("Part")
	part.Name = spec.Name or spec.Mech or "Part"
	part.Anchored = spec.Anchored ~= false
	part.Size = spec.Size
	part.CFrame = self.origin * CFrame.new(spec.Pos) * (spec.Rot or CFrame.identity)
	part.Color = spec.Color or Colors[side]
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.Transparency = spec.Transparency or 0
	part.CanCollide = spec.CanCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CollisionGroup = CollisionService.groupForSide(side)
	part:SetAttribute(Attr.Side, side)
	if spec.Mech then
		part:SetAttribute(Attr.Mech, spec.Mech)
	end
	if spec.Link then
		part:SetAttribute(Attr.Link, spec.Link)
	end
	if spec.Attrs then
		for key, value in spec.Attrs do
			part:SetAttribute(key, value)
		end
	end
	part.Parent = self.model
	return part
end

-- Пол и четыре стены. opts.floor = false — без пола (для комнат с ямами).
function RoomKit:Shell(width: number, depth: number, height: number, opts: { floor: boolean? }?)
	local hw, hd = width / 2, depth / 2
	if not opts or opts.floor ~= false then
		self:Part({
			Name = "Floor",
			Size = Vector3.new(width, 2, depth),
			Pos = Vector3.new(0, -1, 0),
			Color = Colors.Floor,
			Material = Enum.Material.Slate,
		})
	end
	self:Part({ Name = "WallL", Size = Vector3.new(2, height, depth + 4), Pos = Vector3.new(-hw - 1, height / 2, 0) })
	self:Part({ Name = "WallR", Size = Vector3.new(2, height, depth + 4), Pos = Vector3.new(hw + 1, height / 2, 0) })
	self:Part({ Name = "WallB", Size = Vector3.new(width + 4, height, 2), Pos = Vector3.new(0, height / 2, hd + 1) })
	self:Part({ Name = "WallF", Size = Vector3.new(width + 4, height, 2), Pos = Vector3.new(0, height / 2, -hd - 1) })
	-- Невидимый потолок, чтобы не выпрыгивать из комнаты
	self:Part({
		Name = "Ceiling",
		Size = Vector3.new(width + 4, 2, depth + 4),
		Pos = Vector3.new(0, height + 1, 0),
		Transparency = 1,
	})
end

-- Поперечная стена на координате z с проёмом посередине.
function RoomKit:CrossWall(z: number, width: number, height: number, gapWidth: number, gapHeight: number)
	local segment = (width - gapWidth) / 2
	self:Part({
		Name = "CrossWall",
		Size = Vector3.new(segment, height, 2),
		Pos = Vector3.new(-(gapWidth / 2 + segment / 2), height / 2, z),
	})
	self:Part({
		Name = "CrossWall",
		Size = Vector3.new(segment, height, 2),
		Pos = Vector3.new(gapWidth / 2 + segment / 2, height / 2, z),
	})
	self:Part({
		Name = "Lintel",
		Size = Vector3.new(gapWidth, height - gapHeight, 2),
		Pos = Vector3.new(0, gapHeight + (height - gapHeight) / 2, z),
	})
end

-- Нажимная плита: активна, пока на ней стоит игрок или ящик этой же стороны.
function RoomKit:Plate(side: string, pos: Vector3, link: string): Part
	return self:Part({
		Name = "Plate",
		Size = Vector3.new(7, 0.4, 7),
		Pos = pos + Vector3.new(0, 0.2, 0),
		Side = side,
		Mech = "Plate",
		Link = link,
	})
end

-- Дверь: открыта (проходима), пока связь активна.
function RoomKit:Door(side: string, pos: Vector3, size: Vector3, link: string): Part
	return self:Part({
		Name = "Door",
		Size = size,
		Pos = pos,
		Side = side,
		Mech = "Door",
		Link = link,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
end

-- Мост: твёрдый, пока связь активна (обратная дверь).
function RoomKit:Bridge(side: string, pos: Vector3, size: Vector3, link: string): Part
	return self:Part({
		Name = "Bridge",
		Size = size,
		Pos = pos,
		Side = side,
		Mech = "Bridge",
		Link = link,
		Material = Enum.Material.Neon,
	})
end

-- Рычаг-переключатель (ProximityPrompt).
function RoomKit:Lever(side: string, pos: Vector3, link: string): Part
	return self:Part({
		Name = "Lever",
		Size = Vector3.new(1.6, 4, 1.6),
		Pos = pos + Vector3.new(0, 2, 0),
		Side = side,
		Mech = "Lever",
		Link = link,
		Material = Enum.Material.Metal,
	})
end

-- Ящик, который двигает игрок своей стороны; в другом мире появляется его «эхо».
function RoomKit:MirrorBox(side: string, pos: Vector3): Part
	return self:Part({
		Name = "MirrorBox",
		Size = Vector3.new(5, 5, 5),
		Pos = pos + Vector3.new(0, 2.5, 0),
		Side = side,
		Mech = "MirrorBox",
		Anchored = false,
		Material = Enum.Material.WoodPlanks,
	})
end

-- Кодовая панель: вводит игрок стороны `side`, цифры видит другой.
function RoomKit:Keypad(side: string, pos: Vector3, link: string, group: string, face: string): Part
	local part = self:Part({
		Name = "Keypad",
		Size = panelSize(face, 3, 4),
		Pos = pos,
		Side = side,
		Mech = "Keypad",
		Link = link,
		Color = Color3.fromRGB(30, 32, 40),
		Attrs = { [Attr.CodeGroup] = group },
	})
	addSurfaceText(part, face, "КОД", Colors[side])
	return part
end

-- Одна цифра кода на стене. index — её позиция в коде (1, 2, 3…).
function RoomKit:CodeDigit(side: string, pos: Vector3, group: string, index: number, face: string): Part
	local part = self:Part({
		Name = "CodeDigit",
		Size = panelSize(face, 5, 5),
		Pos = pos,
		Side = side,
		Mech = "CodeDigit",
		Color = Color3.fromRGB(20, 20, 26),
		Attrs = { [Attr.CodeGroup] = group, [Attr.CodeIndex] = index },
	})
	addSurfaceText(part, face, "?", Colors[side])
	return part
end

-- Лифт / сдвижная стена: пока связь активна, деталь сдвинута на offset.
function RoomKit:Mover(side: string, pos: Vector3, size: Vector3, link: string, offset: Vector3, time: number?): Part
	return self:Part({
		Name = "Mover",
		Size = size,
		Pos = pos,
		Side = side,
		Mech = "Mover",
		Link = link,
		Material = Enum.Material.DiamondPlate,
		Attrs = { MoveOffset = offset, MoveTime = time or 2 },
	})
end

-- Постамент с номером на передней грани (+Z, к точке появления).
function RoomKit:Pedestal(pos: Vector3, number: number): Part
	local part = self:Part({
		Name = "Pedestal" .. number,
		Size = Vector3.new(4, 3, 4),
		Pos = pos + Vector3.new(0, 1.5, 0),
		Color = Color3.fromRGB(36, 38, 46),
		Material = Enum.Material.Marble,
	})
	addSurfaceText(part, "Back", "#" .. number)
	return part
end

--[[
	Предмет для «найди отличие»: создаёт ДВЕ одинаковые детали — в светлом и тёмном мире.
	pos — точка на верху постамента (низ предмета).
]]
function RoomKit:AnomalyItem(
	group: string,
	index: number,
	pos: Vector3,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType,
	link: string
)
	for _, side in { Side.Light, Side.Dark } do
		local part = self:Part({
			Name = "AnomalyItem" .. index .. side,
			Size = size,
			Pos = pos + Vector3.new(0, size.Y / 2, 0),
			Side = side,
			Mech = "AnomalyItem",
			Link = link,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Attrs = { AnomalyGroup = group, AnomalyIndex = index },
		})
		part.Shape = shape
	end
end

function RoomKit:Spawn(side: string, pos: Vector3): Part
	return self:Part({
		Name = "Spawn" .. side,
		Size = Vector3.new(4, 1, 4),
		Pos = pos + Vector3.new(0, 0.5, 0),
		Mech = "Spawn",
		Attrs = { SpawnSide = side },
		Transparency = 1,
		CanCollide = false,
	})
end

-- Зона выхода: когда в ней оба игрока — комната пройдена.
function RoomKit:Exit(pos: Vector3, size: Vector3): Part
	local part = self:Part({
		Name = "Exit",
		Size = size,
		Pos = pos + Vector3.new(0, size.Y / 2, 0),
		Mech = "Exit",
		Color = Colors.Success,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Colors.Success
	light.Range = 18
	light.Brightness = 2
	light.Parent = part
	return part
end

-- Зона, попав в которую игрок возвращается на точку появления (ямы, ловушки).
function RoomKit:KillZone(pos: Vector3, size: Vector3): Part
	return self:Part({
		Name = "KillZone",
		Size = size,
		Pos = pos,
		Mech = "KillZone",
		Transparency = 1,
		CanCollide = false,
	})
end

-- Табличка с текстом на грани `face`.
function RoomKit:Sign(text: string, pos: Vector3, face: string, side: string?, width: number?, height: number?): Part
	local part = self:Part({
		Name = "Sign",
		Size = panelSize(face, width or 14, height or 5),
		Pos = pos,
		Side = side,
		Color = Color3.fromRGB(22, 22, 28),
		CanCollide = false,
	})
	addSurfaceText(part, face, text, side and Colors[side] or Color3.new(1, 1, 1))
	return part
end

return RoomKit
