--[[
	CollisionService — группы коллизий двух миров.

	Матрица:
	  PlayerLight  ↔ WorldLight, WorldShared, Default   (да)
	  PlayerDark   ↔ WorldDark,  WorldShared, Default   (да)
	  PlayerLight  ↔ WorldDark, PlayerDark              (нет)
	  PlayerDark   ↔ WorldLight                         (нет)
	  WorldLight   ↔ WorldDark                          (нет — ящик светлого мира проходит сквозь тёмные стены)
]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Group = Constants.CollisionGroup
local Side = Constants.Side

local CollisionService = {}

local characterConnections: { [Model]: RBXScriptConnection } = {}

local function register(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

function CollisionService.Init()
	for _, name in { Group.Light, Group.Dark, Group.Shared, Group.LightPlayer, Group.DarkPlayer } do
		register(name)
	end

	local function setCollidable(a: string, b: string, value: boolean)
		PhysicsService:CollisionGroupSetCollidable(a, b, value)
	end

	setCollidable(Group.Light, Group.Dark, false)
	setCollidable(Group.LightPlayer, Group.Dark, false)
	setCollidable(Group.DarkPlayer, Group.Light, false)
	setCollidable(Group.LightPlayer, Group.DarkPlayer, false)
end

-- Группа для детали комнаты по её стороне.
function CollisionService.groupForSide(side: string?): string
	if side == Side.Light then
		return Group.Light
	elseif side == Side.Dark then
		return Group.Dark
	end
	return Group.Shared
end

local function groupForCharacter(side: string?): string
	if side == Side.Light then
		return Group.LightPlayer
	elseif side == Side.Dark then
		return Group.DarkPlayer
	end
	return "Default"
end

-- Переводит персонажа в мир `side` (nil — обычный режим лобби).
function CollisionService.setCharacterSide(character: Model, side: string?)
	character:SetAttribute("CharacterSide", side)
	local group = groupForCharacter(side)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end

	-- Аксессуары и инструменты могут добавиться позже — следим за ними.
	if not characterConnections[character] then
		characterConnections[character] = character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = groupForCharacter(character:GetAttribute("CharacterSide"))
			end
		end)
		character.Destroying:Connect(function()
			local connection = characterConnections[character]
			if connection then
				connection:Disconnect()
				characterConnections[character] = nil
			end
		end)
	end
end

return CollisionService
