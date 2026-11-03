--[[
	Zone — геометрия: находится ли точка внутри детали (с учётом поворота).
	`above` — сколько studs над верхней гранью тоже считается «внутри»
	(нужно для плит: центр персонажа находится над плитой, а не в ней).
]]

local Zone = {}

function Zone.contains(part: BasePart, point: Vector3, above: number?): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Z) <= half.Z
		and localPoint.Y >= -half.Y
		and localPoint.Y <= half.Y + (above or 0)
end

return Zone
