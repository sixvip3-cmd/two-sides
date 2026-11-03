--[[
	Keypad — кодовая панель. Нажатие открывает у игрока экран ввода (KeypadController),
	проверка кода — в RoomRuntime:submitCode. Цифры кода разбросаны по комнате
	в мире напарника (CodeDigit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr
local Colors = Constants.SideColors

return function(room, part: BasePart)
	local idleColor = part.Color

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ввести код"
	prompt.ObjectText = "Панель"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	room.keypads[part] = {
		link = part:GetAttribute(Attr.Link),
		group = part:GetAttribute(Attr.CodeGroup),
		solved = false,
		onSolved = function()
			part.Color = Colors.Success
			-- Промпт уничтожаем, а не выключаем: Enabled локально переключает клиент (скрытие чужого мира).
			prompt:Destroy()
		end,
		onWrong = function()
			part.Color = Colors.Danger
			task.delay(0.6, function()
				if part.Parent then
					part.Color = idleColor
				end
			end)
		end,
	}

	prompt.Triggered:Connect(function(player)
		room:openKeypad(player, part)
	end)
end
