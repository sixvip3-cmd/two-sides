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
	addBillboard(randomPad, "Случайный напарник")

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

function WorldService.getSessionsFolder(): Folder
	return sessionsFolder
end

function WorldService.getLobbyCFrame(): CFrame
	if lobbySpawn then
		return lobbySpawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 5, 0)
end

return WorldService
