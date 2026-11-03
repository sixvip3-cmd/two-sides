--[[
	Ui — маленький помощник для создания интерфейса кодом.

	Ui.new("Frame", { Size = ..., Parent = ... }, { children... })
	Специальные ключи: Corner = UDim (скругление), Stroke = Color3 (обводка).
]]

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

Ui.Font = Enum.Font.GothamBold
Ui.FontHeavy = Enum.Font.GothamBlack
Ui.Background = Color3.fromRGB(18, 18, 24)

return Ui
