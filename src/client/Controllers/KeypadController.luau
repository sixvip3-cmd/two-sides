--[[
	KeypadController — экран ввода кода.
	Открывается по команде сервера (OpenKeypad), отправляет SubmitCode.
	Закрывается, если отойти от панели или нажать ✕.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Parent.Ui)

local Colors = Constants.SideColors

local KeypadController = {}

local player = Players.LocalPlayer

local panel: Frame
local display: TextLabel
local currentKeypad: BasePart? = nil
local codeLength = 4
local entered = ""

local function render()
	local shown = entered .. string.rep("_", math.max(0, codeLength - #entered))
	display.Text = shown:gsub(".", "%0 "):sub(1, -2)
end

local function close()
	currentKeypad = nil
	entered = ""
	panel.Visible = false
end

local function submit()
	if currentKeypad and #entered == codeLength then
		Net.get("SubmitCode"):FireServer(currentKeypad, entered)
		close()
	end
end

local function press(key: string)
	if not currentKeypad then
		return
	end
	if key == "⌫" then
		entered = entered:sub(1, -2)
	elseif key == "OK" then
		submit()
		return
	elseif #entered < codeLength then
		entered ..= key
	end
	render()
end

local function build()
	local gui = Ui.new("ScreenGui", {
		Name = "TwoSidesKeypad",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})

	panel = Ui.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.62),
		BackgroundColor3 = Ui.Background,
		Visible = false,
		Corner = UDim.new(0, 16),
		Stroke = Colors.Dark,
		Parent = gui,
	}, {
		Ui.new("UIAspectRatioConstraint", { AspectRatio = 0.72 }),
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(230, 320), MaxSize = Vector2.new(380, 530) }),
	})

	display = Ui.new("TextLabel", {
		Name = "Display",
		Position = UDim2.fromScale(0.08, 0.05),
		Size = UDim2.fromScale(0.84, 0.15),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		Font = Enum.Font.Code,
		TextScaled = true,
		TextColor3 = Colors.Success,
		Text = "",
		Corner = UDim.new(0, 10),
		Parent = panel,
	})

	local grid = Ui.new("Frame", {
		Name = "Keys",
		Position = UDim2.fromScale(0.08, 0.24),
		Size = UDim2.fromScale(0.84, 0.72),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -8, 0.25, -8),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK" }
	for order, key in keys do
		local button = Ui.new("TextButton", {
			Name = "Key_" .. key,
			LayoutOrder = order,
			BackgroundColor3 = if key == "OK"
				then Colors.Success
				elseif key == "⌫" then Color3.fromRGB(70, 70, 84)
				else Color3.fromRGB(40, 40, 52),
			Font = Ui.FontHeavy,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = if key == "⌫" or key == "OK" then "" else key,
			AutoButtonColor = true,
			Corner = UDim.new(0, 10),
			Parent = grid,
		})
		if key == "⌫" or key == "OK" then
			Ui.icon(if key == "OK" then "check" else "backspace", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 0.7),
				Parent = button,
			})
		end
		button.Activated:Connect(function()
			press(key)
		end)
	end

	local closeButton = Ui.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Colors.Danger,
		Text = "",
		Corner = UDim.new(1, 0),
		Parent = panel,
	})
	Ui.icon("close", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		Parent = closeButton,
	})
	closeButton.Activated:Connect(close)
end

function KeypadController.Start()
	build()

	Net.get("OpenKeypad").OnClientEvent:Connect(function(keypad, length)
		if typeof(keypad) ~= "Instance" or not keypad:IsA("BasePart") then
			return
		end
		currentKeypad = keypad
		codeLength = math.clamp(tonumber(length) or 4, 1, Config.CODE_MAX_LENGTH)
		entered = ""
		render()
		panel.Visible = true
	end)

	-- Ввод с клавиатуры: цифры, Backspace, Enter, Escape
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not currentKeypad then
			return
		end
		local keyCode = input.KeyCode
		local digit = keyCode.Value - Enum.KeyCode.Zero.Value
		local numpadDigit = keyCode.Value - Enum.KeyCode.KeypadZero.Value
		if digit >= 0 and digit <= 9 then
			press(tostring(digit))
		elseif numpadDigit >= 0 and numpadDigit <= 9 then
			press(tostring(numpadDigit))
		elseif keyCode == Enum.KeyCode.Backspace then
			press("⌫")
		elseif keyCode == Enum.KeyCode.Return or keyCode == Enum.KeyCode.KeypadEnter then
			submit()
		elseif keyCode == Enum.KeyCode.Escape then
			close()
		end
	end)

	-- Закрываем, если игрок отошёл или панель исчезла (комната сменилась)
	task.spawn(function()
		while true do
			task.wait(0.3)
			if currentKeypad then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if
					not currentKeypad.Parent
					or not root
					or (root.Position - currentKeypad.Position).Magnitude > Config.KEYPAD_MAX_DISTANCE
				then
					close()
				end
			end
		end
	end)
end

return KeypadController
