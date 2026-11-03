--[[
	CodeDigit — одна цифра кода на стене: «#2» сверху и сама цифра.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr

return function(room, part: BasePart)
	local group = part:GetAttribute(Attr.CodeGroup)
	local index = part:GetAttribute(Attr.CodeIndex)
	local code = room:getCode(group)
	local digit = string.sub(code, index, index)

	local gui = part:FindFirstChild("Text")
	local label = gui and gui:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.RichText = true
		label.Text = string.format('<font size="30">#%d</font>\n%s', index, digit)
		label.TextScaled = false
		label.TextSize = 120
	end
end
