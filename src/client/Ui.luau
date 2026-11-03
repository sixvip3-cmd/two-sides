--[[
	Ui — маленький помощник для создания интерфейса кодом.

	Ui.new("Frame", { Size = ..., Parent = ... }, { children... })
	Специальные ключи: Corner = UDim (скругление), Stroke = Color3 (обводка).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage.Shared.Icons)

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

--[[
	Иконка: ImageLabel из атласа, а если атлас ещё не загружен — TextLabel с символом.
	props: Size, Position, AnchorPoint, Color (Color3), LayoutOrder, Parent, Name
]]
function Ui.icon(name: string, props: { [string]: any }?): GuiObject
	props = props or {}
	local color = (props :: any).Color or Color3.new(1, 1, 1)
	local base = {
		Name = (props :: any).Name or ("Icon_" .. name),
		Size = (props :: any).Size or UDim2.fromOffset(28, 28),
		Position = (props :: any).Position,
		AnchorPoint = (props :: any).AnchorPoint,
		LayoutOrder = (props :: any).LayoutOrder,
		BackgroundTransparency = 1,
		Parent = (props :: any).Parent,
	}
	if Icons.hasImages() then
		local image = Ui.new("ImageLabel", base)
		Icons.apply(image, name)
		image.ImageColor3 = color
		image.ScaleType = Enum.ScaleType.Fit
		return image
	end
	local label = Ui.new("TextLabel", base)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = Icons.FALLBACK[name] or "?"
	return label
end

-- Сменить иконку у уже созданного Ui.icon.
function Ui.setIcon(icon: GuiObject, name: string, color: Color3?)
	if icon:IsA("ImageLabel") then
		Icons.apply(icon, name)
		if color then
			icon.ImageColor3 = color
		end
	elseif icon:IsA("TextLabel") then
		icon.Text = Icons.FALLBACK[name] or "?"
		if color then
			icon.TextColor3 = color
		end
	end
end

Ui.Font = Enum.Font.GothamBold
Ui.FontHeavy = Enum.Font.GothamBlack
Ui.Background = Color3.fromRGB(18, 18, 24)

return Ui
