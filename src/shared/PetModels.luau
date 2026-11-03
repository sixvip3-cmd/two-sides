--[[
	PetModels — строит модели питомцев из PetSpecs.json (генерирует tools/pets.py).

	PetModels.build(id, cframe?, scale?) → Model
	  * id — ключ питомца из CompanionConfig или "Egg";
	  * все детали приварены к корневой (PrimaryPart = первая деталь);
	  * у деталей нет коллизий — питомец не мешает игроку.
	Используется и сервером (питомец за игроком), и клиентом (превью в магазине).
]]

local PetSpecs = require(script.Parent.PetSpecs)

local PetModels = {}

local function specFor(id: string)
	if id == "Egg" then
		return PetSpecs.egg
	end
	return PetSpecs.pets[id]
end

function PetModels.exists(id: string): boolean
	return specFor(id) ~= nil
end

local function makePart(spec, scale: number): BasePart
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = Vector3.new(spec.z[1], spec.z[2], spec.z[3]) * scale
	part.Color = Color3.fromHex(spec.c)
	part.Material = if spec.m then (Enum.Material :: any)[spec.m] else Enum.Material.SmoothPlastic
	part.Transparency = spec.t or 0

	if spec.s == "ell" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif spec.s == "wedge" then
		part.Shape = Enum.PartType.Wedge
	elseif spec.s == "cyl" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

local function localCFrame(spec, scale: number): CFrame
	local p = spec.p
	local r = spec.r
	if r then
		return CFrame.new(
			p[1] * scale,
			p[2] * scale,
			p[3] * scale,
			r[1],
			r[2],
			r[3],
			r[4],
			r[5],
			r[6],
			r[7],
			r[8],
			r[9]
		)
	end
	return CFrame.new(p[1] * scale, p[2] * scale, p[3] * scale)
end

function PetModels.build(id: string, cframe: CFrame?, scale: number?): Model?
	local spec = specFor(id)
	if not spec then
		return nil
	end
	local s = scale or 1
	local origin = cframe or CFrame.identity

	local model = Instance.new("Model")
	model.Name = id

	local root: BasePart? = nil
	local rootLocal = CFrame.identity
	for index, partSpec in spec.parts do
		local part = makePart(partSpec, s)
		local cf = localCFrame(partSpec, s)
		part.CFrame = origin * cf
		if index == 1 then
			part.Name = "Body"
			root = part
			rootLocal = cf
		else
			part.Name = "Part" .. index
			part.Massless = true
			-- Weld с явным C0: детали держатся на месте и в мире, и во ViewportFrame
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = part
			weld.C0 = rootLocal:Inverse() * cf
			weld.Parent = part
		end
		part.Parent = model
	end
	model.PrimaryPart = root

	if root and spec.glow then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex(spec.glow)
		light.Range = 9
		light.Brightness = 1.4
		light.Parent = root
	end
	if root and spec.sparkles then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Rate = 4
		sparkles.Lifetime = NumberRange.new(0.8, 1.4)
		sparkles.Speed = NumberRange.new(0.4, 1)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25 * s),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.LightEmission = 1
		sparkles.Color = ColorSequence.new(Color3.fromHex(spec.glow or "#FFFFFF"))
		sparkles.Parent = root
	end
	if root and spec.fire then
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "Flames"
		fire.Rate = 14
		fire.Lifetime = NumberRange.new(0.4, 0.7)
		fire.Speed = NumberRange.new(1, 2)
		fire.Acceleration = Vector3.new(0, 3, 0)
		fire.SpreadAngle = Vector2.new(25, 25)
		fire.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4 * s),
			NumberSequenceKeypoint.new(1, 0),
		})
		fire.Transparency = NumberSequence.new(0.2, 1)
		fire.LightEmission = 1
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 40))
		fire.Parent = root
	end

	return model
end

return PetModels
