--[[
	WorldService — лобби и папка для сессий.

	Если в Workspace уже есть папка «Lobby» (собранная художником в Studio), используется она:
	площадками считаются любые BasePart с атрибутом PadTitle.
	Если лобби нет — строится простое лобби из кода, чтобы игра запускалась на пустом baseplate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr
local Colors = Constants.SideColors

local WorldService = {}

local lobbyFolder: Folder
local sessionsFolder: Folder
local lobbySpawn: BasePart?

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function addBillboard(part: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PadLabel"
	gui.Size = UDim2.fromOffset(260, 90)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui

	gui.Parent = part
end

local function buildDefaultLobby(folder: Folder)
	local hasBaseplate = Workspace:FindFirstChild("Baseplate") ~= nil
	if not hasBaseplate then
		makePart({
			Name = "Floor",
			Size = Vector3.new(160, 2, 160),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(45, 47, 56),
			Parent = folder,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 40)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(230, 230, 240)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	-- Площадки для друзей (вставайте вдвоём)
	for index, x in { -42, -14, 14, 42 } do
		local pad = makePart({
			Name = "DuoPad" .. index,
			Size = Vector3.new(12, 0.6, 12),
			Position = Vector3.new(x, 0.3, -10),
			Color = index % 2 == 0 and Colors.Dark or Colors.Light,
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		pad:SetAttribute(Attr.PadTitle, "Вдвоём с другом")
		addBillboard(pad, "Вдвоём с другом")
	end

	-- Площадка случайного подбора
	local randomPad = makePart({
		Name = "RandomPad",
		Size = Vector3.new(24, 0.6, 14),
		Position = Vector3.new(0, 0.3, -42),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	randomPad:SetAttribute(Attr.PadTitle, "Случайный напарник")
	randomPad:SetAttribute(Attr.PadRandom, true)
	addBillboard(randomPad, "Случайный напарник")

	-- Ежедневная комната: одна комната дня, награда раз в день
	local dailyPad = makePart({
		Name = "DailyPad",
		Size = Vector3.new(12, 0.6, 12),
		Position = Vector3.new(-30, 0.3, 30),
		Color = Color3.fromRGB(255, 214, 110),
		Material = Enum.Material.Neon,
		Parent = folder,
	})
	dailyPad:SetAttribute(Attr.PadTitle, "Ежедневная комната")
	dailyPad:SetAttribute(Attr.PadMode, "daily")
	addBillboard(dailyPad, "Ежедневная комната")

	-- Доска рекордов пар
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(1, 16, 26),
		Position = Vector3.new(62, 8, 0),
		Color = Color3.fromRGB(25, 25, 32),
		Parent = folder,
	})
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "Board"
	boardGui.Face = Enum.NormalId.Left
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 30
	boardGui.LightInfluence = 0
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = list
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.LayoutOrder = 0
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBlack
	header.TextScaled = true
	header.TextColor3 = Color3.fromRGB(255, 214, 110)
	header.Text = "РЕКОРДЫ ПАР — ГЛАВА 1"
	header.Parent = list
	list.Parent = boardGui
	boardGui.Parent = board

	-- Площадка для разработчика: пройти комнаты одному, переключая миры клавишей T
	if RunService:IsStudio() then
		local soloPad = makePart({
			Name = "SoloTestPad",
			Size = Vector3.new(10, 0.6, 10),
			Position = Vector3.new(30, 0.3, 30),
			Color = Color3.fromRGB(255, 120, 200),
			Material = Enum.Material.Neon,
			Parent = folder,
		})
		soloPad:SetAttribute(Attr.PadTitle, "Тест одному (Studio)")
		soloPad:SetAttribute(Attr.PadSolo, true)
		addBillboard(soloPad, "Тест одному (Studio)")
	end

	-- Табличка с названием
	local sign = makePart({
		Name = "TitleSign",
		Size = Vector3.new(40, 12, 1),
		Position = Vector3.new(0, 10, -60),
		Color = Color3.fromRGB(25, 25, 32),
		Parent = folder,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "TWO SIDES\nвстаньте на площадку вдвоём"
	title.Parent = surface
	surface.Parent = sign
end

function WorldService.Init()
	local existing = Workspace:FindFirstChild("Lobby")
	if existing and existing:IsA("Folder") then
		lobbyFolder = existing
	else
		lobbyFolder = Instance.new("Folder")
		lobbyFolder.Name = "Lobby"
		buildDefaultLobby(lobbyFolder)
		lobbyFolder.Parent = Workspace
	end

	for _, descendant in lobbyFolder:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			lobbySpawn = descendant
			break
		end
	end

	sessionsFolder = Instance.new("Folder")
	sessionsFolder.Name = "Sessions"
	sessionsFolder.Parent = Workspace
end

function WorldService.getPads(): { BasePart }
	local pads = {}
	for _, descendant in lobbyFolder:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(Attr.PadTitle) then
			table.insert(pads, descendant)
		end
	end
	return pads
end

function WorldService.getLeaderboardBoard(): BasePart?
	local board = lobbyFolder:FindFirstChild("LeaderboardBoard", true)
	return if board and board:IsA("BasePart") then board else nil
end

-- Строки доски рекордов (заголовок остаётся)
function WorldService.setLeaderboardRows(rows: { string })
	local board = WorldService.getLeaderboardBoard()
	local list = board and board:FindFirstChild("Board") and board.Board:FindFirstChild("List")
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") and child.Name == "Row" then
			child:Destroy()
		end
	end
	for index, text in rows do
		local row = Instance.new("TextLabel")
		row.Name = "Row"
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Text = text
		row.Parent = list
	end
end

function WorldService.getSessionsFolder(): Folder
	return sessionsFolder
end

-- Точка на площадке случайного подбора (или обычное лобби, если такой площадки нет).
function WorldService.getRandomPadCFrame(): CFrame
	for _, pad in WorldService.getPads() do
		if pad:GetAttribute(Attr.PadRandom) then
			local offset =
				Vector3.new((math.random() - 0.5) * pad.Size.X * 0.6, 4, (math.random() - 0.5) * pad.Size.Z * 0.6)
			return pad.CFrame + offset
		end
	end
	return WorldService.getLobbyCFrame()
end

function WorldService.getLobbyCFrame(): CFrame
	if lobbySpawn then
		return lobbySpawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 5, 0)
end

return WorldService
