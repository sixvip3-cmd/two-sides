--[[
	MirrorBox — ящик, связывающий миры.

	Сам ящик физический и живёт в мире своей стороны: его толкает игрок этой стороны.
	В другом мире создаётся «эхо» — закреплённая копия, которая каждый кадр повторяет
	положение ящика. На эхо можно встать, им можно нажать плиту другой стороны.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CollisionService = require(script.Parent.Parent.Parent.Services.CollisionService)

local Attr = Constants.Attr
local Side = Constants.Side
local Colors = Constants.SideColors

return function(room, part: BasePart)
	local side = part:GetAttribute(Attr.Side)
	local otherSide = if side == Side.Light then Side.Dark else Side.Light
	local startCFrame = part.CFrame

	part.Anchored = false
	part.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.4, 0, 1, 1)

	local echo = part:Clone()
	echo.Name = "MirrorBoxEcho"
	echo.Anchored = true
	echo.Color = Colors[otherSide]
	echo.Material = Enum.Material.Glass
	echo.Transparency = 0.2
	echo.CollisionGroup = CollisionService.groupForSide(otherSide)
	echo:SetAttribute(Attr.Side, otherSide)
	echo:SetAttribute(Attr.Mech, nil)
	echo.Parent = part.Parent

	table.insert(room.boxes, part)
	table.insert(room.boxes, echo)

	-- Физику ящика считает клиент толкающего игрока — так толкать плавно, без задержки.
	local owner = room.session:getPlayerOnSide(side)
	if owner then
		pcall(function()
			part:SetNetworkOwner(owner)
		end)
	end

	room:onHeartbeat(function()
		if not part.Parent then
			return
		end
		if room:isInKillZone(part.Position) then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.CFrame = startCFrame
		end
		echo.CFrame = part.CFrame
	end)
end
