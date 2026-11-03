--[[
	DimensionController — что видит игрок.

	* Детали чужого мира (атрибут Side ≠ мой) скрываются локально через
	  LocalTransparencyModifier; их надписи, свет и подсказки (ProximityPrompt) — выключаются.
	  Сервер ничего не скрывает: каждый клиент сам прячет «чужое».
	* Напарник показывается полупрозрачным «призраком» с подсветкой.
	* Цвет картинки зависит от мира (ColorCorrection).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr
local Side = Constants.Side
local Colors = Constants.SideColors

local DimensionController = {}

local player = Players.LocalPlayer
local mySide: string? = nil
local mySession: string? = nil

local GHOST_TRANSPARENCY = 0.55

local tint: ColorCorrectionEffect

local function isVisible(side: string?): boolean
	return mySide == nil or side == nil or side == Side.Shared or side == mySide
end

-- Ближайший предок-деталь с атрибутом Side (для SurfaceGui, света, промптов).
local function owningPart(instance: Instance): BasePart?
	local current = instance.Parent
	while current and current ~= Workspace do
		if current:IsA("BasePart") and current:GetAttribute(Attr.Side) ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function applyDecoration(instance: Instance, visible: boolean)
	if instance:IsA("Decal") then -- Texture тоже Decal
		pcall(function()
			(instance :: any).LocalTransparencyModifier = if visible then 0 else 1
		end)
	elseif
		instance:IsA("SurfaceGui")
		or instance:IsA("BillboardGui")
		or instance:IsA("Light")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("ProximityPrompt")
	then
		(instance :: any).Enabled = visible
	end
end

local function applyPart(part: BasePart)
	local visible = isVisible(part:GetAttribute(Attr.Side))
	part.LocalTransparencyModifier = if visible then 0 else 1
	for _, child in part:GetChildren() do
		applyDecoration(child, visible)
	end
end

local function applyInstance(instance: Instance)
	if instance:IsA("BasePart") then
		if instance:GetAttribute(Attr.Side) ~= nil then
			applyPart(instance)
		end
	else
		local part = owningPart(instance)
		if part then
			applyDecoration(instance, isVisible(part:GetAttribute(Attr.Side)))
		end
	end
end

local function applyAll()
	local sessions = Workspace:FindFirstChild("Sessions")
	if not sessions then
		return
	end
	for _, descendant in sessions:GetDescendants() do
		applyInstance(descendant)
	end
end

--------------------------------------------------------------------------------
-- Призрак напарника
--------------------------------------------------------------------------------

local function setGhost(character: Model, ghostSide: string?)
	local isGhost = ghostSide ~= nil
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.LocalTransparencyModifier = if isGhost then GHOST_TRANSPARENCY else 0
		elseif descendant:IsA("Decal") then
			pcall(function()
				(descendant :: any).LocalTransparencyModifier = if isGhost then GHOST_TRANSPARENCY else 0
			end)
		end
	end

	local highlight = character:FindFirstChild("GhostHighlight")
	if isGhost then
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "GhostHighlight"
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillTransparency = 0.85
			highlight.OutlineTransparency = 0.2
			highlight.Parent = character
		end
		local color = Colors[ghostSide :: string] or Color3.new(1, 1, 1)
		highlight.FillColor = color
		highlight.OutlineColor = color
	elseif highlight then
		highlight:Destroy()
	end
end

local function refreshPlayer(other: Player)
	if other == player then
		return
	end
	local character = other.Character
	if not character then
		return
	end
	local otherSide = other:GetAttribute(Attr.Side)
	local sameSession = mySession ~= nil and other:GetAttribute(Attr.SessionId) == mySession
	local ghostSide = if sameSession and otherSide ~= mySide then otherSide else nil
	setGhost(character, ghostSide)
end

local function refreshAllPlayers()
	for _, other in Players:GetPlayers() do
		refreshPlayer(other)
	end
end

local function watchPlayer(other: Player)
	if other == player then
		return
	end
	local function onCharacter(character: Model)
		refreshPlayer(other)
		-- Аксессуары подгружаются после появления персонажа
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") or descendant:IsA("Decal") then
				task.defer(refreshPlayer, other)
			end
		end)
	end
	other.CharacterAdded:Connect(onCharacter)
	if other.Character then
		onCharacter(other.Character)
	end
	other:GetAttributeChangedSignal(Attr.SessionId):Connect(function()
		refreshPlayer(other)
	end)
	other:GetAttributeChangedSignal(Attr.Side):Connect(function()
		refreshPlayer(other)
	end)
end

--------------------------------------------------------------------------------
-- Цвет мира
--------------------------------------------------------------------------------

local TINTS = {
	Light = { TintColor = Color3.fromRGB(255, 244, 225), Brightness = 0.04, Contrast = 0.05, Saturation = 0.15 },
	Dark = { TintColor = Color3.fromRGB(196, 186, 255), Brightness = -0.08, Contrast = 0.18, Saturation = -0.25 },
	None = { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 },
}

local function applyTint()
	local goal = TINTS[mySide or "None"] or TINTS.None
	TweenService:Create(tint, TweenInfo.new(0.8), goal):Play()
end

--------------------------------------------------------------------------------

local function onMyStateChanged()
	mySide = player:GetAttribute(Attr.Side)
	mySession = player:GetAttribute(Attr.SessionId)
	applyAll()
	refreshAllPlayers()
	applyTint()
end

function DimensionController.getSide(): string?
	return mySide
end

function DimensionController.Start()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "TwoSidesTint"
	tint.Parent = Lighting

	local sessions = Workspace:WaitForChild("Sessions")
	sessions.DescendantAdded:Connect(function(descendant)
		applyInstance(descendant)
		if descendant:IsA("BasePart") then
			descendant:GetAttributeChangedSignal(Attr.Side):Connect(function()
				applyPart(descendant)
			end)
		end
	end)
	for _, descendant in sessions:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant:GetAttributeChangedSignal(Attr.Side):Connect(function()
				applyPart(descendant)
			end)
		end
	end

	player:GetAttributeChangedSignal(Attr.Side):Connect(onMyStateChanged)
	player:GetAttributeChangedSignal(Attr.SessionId):Connect(onMyStateChanged)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end

	onMyStateChanged()
end

return DimensionController
