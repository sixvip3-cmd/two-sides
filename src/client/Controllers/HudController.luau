--[[
	HudController — интерфейс во время игры.

	* Верх: название комнаты, «Комната 2/5», напарник и плашка мира (☀ / ☾).
	* Низ: подсказка для твоей стороны.
	* Справа: кнопка смены мира (только в соло-тесте, клавиша T).
	* Тосты: короткие сообщения от сервера (Notify) с иконкой.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Parent.Ui)

local Colors = Constants.SideColors

local HudController = {}

local player = Players.LocalPlayer

local INK = Color3.fromRGB(20, 20, 26)

local gui: ScreenGui
local topBar: Frame
local roomTitle: TextLabel
local roomSubtitle: TextLabel
local sideBadge: Frame
local sideIcon: GuiObject
local sideLabel: TextLabel
local hintFrame: Frame
local hintLabel: TextLabel
local toastList: Frame
local switchButton: TextButton
local isSolo = false

local KINDS = {
	info = { color = Color3.fromRGB(70, 130, 220), icon = "info" },
	success = { color = Colors.Success, icon = "check" },
	error = { color = Colors.Danger, icon = "warning" },
}

local function padding(px: number)
	return Ui.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "TwoSidesHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Верхняя панель ----------------------------------------------------------
	topBar = Ui.new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.5, 0, 0, 74),
		BackgroundColor3 = Ui.Background,
		BackgroundTransparency = 0.25,
		Visible = false,
		Corner = UDim.new(0, 12),
		Parent = gui,
	}, {
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(320, 0), MaxSize = Vector2.new(580, math.huge) }),
	})

	roomTitle = Ui.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.new(1, -170, 0, 34),
		BackgroundTransparency = 1,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = topBar,
	})

	Ui.icon("partner", {
		Position = UDim2.new(0, 14, 0, 44),
		Size = UDim2.fromOffset(20, 20),
		Color = Color3.fromRGB(190, 190, 205),
		Parent = topBar,
	})

	roomSubtitle = Ui.new("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.new(0, 40, 0, 42),
		Size = UDim2.new(1, -196, 0, 24),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 190, 205),
		Text = "",
		Parent = topBar,
	})

	sideBadge = Ui.new("Frame", {
		Name = "SideBadge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 146, 0, 54),
		BackgroundColor3 = Colors.Light,
		Corner = UDim.new(0, 10),
		Parent = topBar,
	})
	sideIcon = Ui.icon("sun", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		Color = INK,
		Parent = sideBadge,
	})
	sideLabel = Ui.new("TextLabel", {
		Name = "Text",
		Position = UDim2.new(0, 48, 0, 8),
		Size = UDim2.new(1, -56, 1, -16),
		BackgroundTransparency = 1,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = INK,
		Text = "",
		Parent = sideBadge,
	})

	-- Подсказка ----------------------------------------------------------------
	hintFrame = Ui.new("Frame", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.6, 0, 0, 52),
		BackgroundColor3 = Ui.Background,
		BackgroundTransparency = 0.3,
		Visible = false,
		Corner = UDim.new(0, 12),
		Parent = gui,
	}, {
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(720, math.huge) }),
	})
	Ui.icon("hint", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Color = Color3.fromRGB(255, 214, 110),
		Parent = hintFrame,
	})
	hintLabel = Ui.new("TextLabel", {
		Name = "Text",
		Position = UDim2.new(0, 52, 0, 6),
		Size = UDim2.new(1, -64, 1, -12),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = hintFrame,
	})

	-- Кнопка смены мира (соло-тест) ---------------------------------------------
	switchButton = Ui.new("TextButton", {
		Name = "SwitchSide",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(160, 64),
		BackgroundColor3 = Color3.fromRGB(255, 120, 200),
		Text = "",
		AutoButtonColor = true,
		Visible = false,
		Corner = UDim.new(0, 12),
		Parent = gui,
	})
	Ui.icon("swap", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		Parent = switchButton,
	})
	Ui.new("TextLabel", {
		Position = UDim2.new(0, 54, 0, 8),
		Size = UDim2.new(1, -62, 1, -16),
		BackgroundTransparency = 1,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Сменить мир\n[T]",
		Parent = switchButton,
	})
	switchButton.Activated:Connect(function()
		Net.get("SwitchSide"):FireServer()
	end)

	-- Тосты --------------------------------------------------------------------
	toastList = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(540, math.huge) }),
	})
end

local toastCounter = 0

function HudController.toast(text: string, kind: string?)
	toastCounter += 1
	local style = KINDS[kind or "info"] or KINDS.info

	local toast = Ui.new("Frame", {
		Name = "Toast",
		LayoutOrder = toastCounter,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = style.color,
		BackgroundTransparency = 0.1,
		Corner = UDim.new(0, 10),
		Parent = toastList,
	})
	local icon = Ui.icon(style.icon, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		Parent = toast,
	})
	local label = Ui.new("TextLabel", {
		Position = UDim2.new(0, 42, 0, 0),
		Size = UDim2.new(1, -52, 1, 0),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		Parent = toast,
	}, { padding(6) })

	-- Не больше 4 сообщений одновременно
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 4 do
		toasts[i]:Destroy()
	end

	task.delay(3.5, function()
		if not toast.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		if icon:IsA("ImageLabel") then
			TweenService:Create(icon, info, { ImageTransparency = 1 }):Play()
		elseif icon:IsA("TextLabel") then
			TweenService:Create(icon, info, { TextTransparency = 1 }):Play()
		end
		task.wait(0.45)
		toast:Destroy()
	end)
end

local function onState(state)
	if not state then
		topBar.Visible = false
		hintFrame.Visible = false
		switchButton.Visible = false
		isSolo = false
		return
	end

	isSolo = state.solo == true
	switchButton.Visible = isSolo

	topBar.Visible = true
	roomTitle.Text = state.roomName
	roomSubtitle.Text = if isSolo
		then string.format("Комната %d/%d · тест одному", state.roomIndex, state.roomCount)
		else string.format("Комната %d/%d · %s", state.roomIndex, state.roomCount, state.partnerName)

	local isLight = state.side == "Light"
	local ink = if isLight then INK else Color3.new(1, 1, 1)
	sideBadge.BackgroundColor3 = Colors[state.side] or Colors.Light
	sideLabel.Text = if isLight then "СВЕТЛЫЙ" else "ТЁМНЫЙ"
	sideLabel.TextColor3 = ink
	Ui.setIcon(sideIcon, if isLight then "sun" else "moon", ink)

	hintLabel.Text = state.hint or ""
	hintFrame.Visible = state.hint ~= nil and state.hint ~= ""
end

function HudController.Start()
	build()
	Net.get("SessionState").OnClientEvent:Connect(onState)
	Net.get("Notify").OnClientEvent:Connect(function(text, kind)
		HudController.toast(text, kind)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and isSolo and input.KeyCode == Enum.KeyCode.T then
			Net.get("SwitchSide"):FireServer()
		end
	end)
end

return HudController
