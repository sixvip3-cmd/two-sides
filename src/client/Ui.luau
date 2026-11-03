--[[
	Ui — маленький помощник для создания интерфейса кодом.

	Ui.new("Frame", { Size = ..., Parent = ... }, { children... })
	Специальные ключи: Corner = UDim (скругление), Stroke = Color3 (обводка).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Icons = require(ReplicatedStorage.Shared.Icons)
local PetModels = require(ReplicatedStorage.Shared.PetModels)

local Ui = {}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		elseif key == "Corner" then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = value
			corner.Parent = instance
		elseif key == "Stroke" then
			local stroke = Instance.new("UIStroke")
			stroke.Color = value
			stroke.Thickness = 2
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = instance
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

--------------------------------------------------------------------------------
-- Иконки
--------------------------------------------------------------------------------

-- Деталь нарисованной иконки: скруглённая полоска/фигура в долях размера иконки.
local function shape(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	rotation: number?,
	round: number?
)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.Rotation = rotation or 0
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(round or 0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- Рисунки иконок из фигур — работают без загруженного атласа и не зависят от шрифта.
local DRAWN = {
	close = function(p, c)
		shape(p, c, 0.5, 0.5, 0.95, 0.2, 45)
		shape(p, c, 0.5, 0.5, 0.95, 0.2, -45)
	end,
	check = function(p, c)
		shape(p, c, 0.3, 0.6, 0.42, 0.2, 45)
		shape(p, c, 0.6, 0.47, 0.72, 0.2, -50)
	end,
	shard = function(p, c)
		shape(p, c, 0.5, 0.5, 0.64, 0.64, 45, 0.12)
	end,
	egg = function(p, c)
		shape(p, c, 0.5, 0.52, 0.72, 0.94)
	end,
	sparkle = function(p, c)
		shape(p, c, 0.5, 0.5, 1, 0.16)
		shape(p, c, 0.5, 0.5, 0.16, 1)
		shape(p, c, 0.5, 0.5, 0.44, 0.44, 45, 0.1)
	end,
	sun = function(p, c)
		shape(p, c, 0.5, 0.5, 0.56, 0.56)
		for i = 0, 7 do
			local angle = math.rad(i * 45)
			shape(p, c, 0.5 + math.cos(angle) * 0.42, 0.5 + math.sin(angle) * 0.42, 0.13, 0.13)
		end
	end,
	moon = function(p, c, background)
		shape(p, c, 0.5, 0.5, 0.86, 0.86)
		shape(p, background or Color3.new(0, 0, 0), 0.68, 0.36, 0.7, 0.7)
	end,
	lock = function(p, c)
		local shackle = shape(p, c, 0.5, 0.36, 0.5, 0.56)
		shackle.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = c
		stroke.Thickness = 3
		stroke.Parent = shackle
		shape(p, c, 0.5, 0.7, 0.78, 0.52, 0, 0.18)
	end,
	partner = function(p, c)
		shape(p, c, 0.5, 0.28, 0.4, 0.4)
		shape(p, c, 0.5, 0.82, 0.8, 0.46)
	end,
	hint = function(p, c)
		shape(p, c, 0.5, 0.4, 0.62, 0.62)
		shape(p, c, 0.5, 0.82, 0.34, 0.12, 0, 0.3)
		shape(p, c, 0.5, 0.96, 0.24, 0.08, 0, 0.3)
	end,
}

local function drawIcon(container: Frame, name: string, color: Color3, background: Color3?)
	for _, child in container:GetChildren() do
		if not child:IsA("UIAspectRatioConstraint") then
			child:Destroy()
		end
	end
	local draw = DRAWN[name]
	if draw then
		draw(container, color, background)
		return
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = Icons.FALLBACK[name] or "?"
	label.Parent = container
end

--[[
	Иконка: ImageLabel из атласа, а если атлас ещё не загружен — рисунок из фигур
	(или простой символ). props: Size, Position, AnchorPoint, Color, Background (для луны),
	LayoutOrder, Parent, Name.
]]
function Ui.icon(name: string, props: { [string]: any }?): GuiObject
	local options = (props or {}) :: any
	local color = options.Color or Color3.new(1, 1, 1)
	local base = {
		Name = options.Name or ("Icon_" .. name),
		Size = options.Size or UDim2.fromOffset(28, 28),
		Position = options.Position,
		AnchorPoint = options.AnchorPoint,
		LayoutOrder = options.LayoutOrder,
		BackgroundTransparency = 1,
		Parent = options.Parent,
	}
	if Icons.hasImages() then
		local image = Ui.new("ImageLabel", base)
		Icons.apply(image, name)
		image.ImageColor3 = color
		image.ScaleType = Enum.ScaleType.Fit
		return image
	end
	local container = Ui.new("Frame", base, {
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
	drawIcon(container, name, color, options.Background)
	return container
end

-- Сменить иконку у уже созданного Ui.icon.
function Ui.setIcon(icon: GuiObject, name: string, color: Color3?, background: Color3?)
	if icon:IsA("ImageLabel") then
		Icons.apply(icon, name)
		if color then
			icon.ImageColor3 = color
		end
	elseif icon:IsA("Frame") then
		drawIcon(icon, name, color or Color3.new(1, 1, 1), background)
	end
end

--------------------------------------------------------------------------------
-- 3D-превью питомца (ViewportFrame)
--------------------------------------------------------------------------------

--[[
	Ui.petViewport(id, props) → ViewportFrame с моделью питомца (или яйца — id "Egg").
	props: Size, Position, AnchorPoint, Parent, Spin (крутить модель), Name.
]]
function Ui.petViewport(id: string, props: { [string]: any }?): ViewportFrame
	local options = (props or {}) :: any
	local viewport = Ui.new("ViewportFrame", {
		Name = options.Name or ("Pet_" .. id),
		Size = options.Size or UDim2.fromOffset(100, 100),
		Position = options.Position,
		AnchorPoint = options.AnchorPoint,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		Parent = options.Parent,
	}, {
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})

	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.5, -6.4), Vector3.new(0, 1.15, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model = PetModels.build(id, CFrame.Angles(0, math.rad(25), 0))
	if model then
		model.Parent = viewport
		if options.Spin and model.PrimaryPart then
			local angle = 25
			local connection
			connection = RunService.RenderStepped:Connect(function(dt)
				if not viewport.Parent then
					connection:Disconnect()
					return
				end
				angle += dt * 40
				model:PivotTo(CFrame.Angles(0, math.rad(angle), 0))
			end)
		end
	end
	return viewport
end

Ui.Font = Enum.Font.GothamBold
Ui.FontHeavy = Enum.Font.GothamBlack
Ui.Background = Color3.fromRGB(18, 18, 24)

return Ui
