--[[
	HudController — интерфейс во время игры.

	* Верх: название комнаты, «Комната 2/3», в каком ты мире и кто напарник.
	* Низ: подсказка для твоей стороны (можно свернуть).
	* Тосты: короткие сообщения от сервера (Notify).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Parent.Ui)

local Colors = Constants.SideColors

local HudController = {}

local player = Players.LocalPlayer

local gui: ScreenGui
local topBar: Frame
local roomTitle: TextLabel
local roomSubtitle: TextLabel
local sideBadge: TextLabel
local hintFrame: Frame
local hintLabel: TextLabel
local toastList: Frame

local KIND_COLORS = {
	info = Color3.fromRGB(70, 130, 220),
	success = Colors.Success,
	error = Colors.Danger,
}

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "TwoSidesHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

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
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(560, math.huge) }),
	})

	roomTitle = Ui.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.new(1, -150, 0, 34),
		BackgroundTransparency = 1,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = topBar,
	})

	roomSubtitle = Ui.new("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.new(0, 14, 0, 42),
		Size = UDim2.new(1, -150, 0, 24),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 190, 205),
		Text = "",
		Parent = topBar,
	})

	sideBadge = Ui.new("TextLabel", {
		Name = "SideBadge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 126, 0, 54),
		BackgroundColor3 = Colors.Light,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(20, 20, 26),
		Text = "",
		Corner = UDim.new(0, 10),
		Parent = topBar,
	}, {
		Ui.new("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})

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
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(280, 0), MaxSize = Vector2.new(720, math.huge) }),
	})

	hintLabel = Ui.new("TextLabel", {
		Name = "Text",
		Position = UDim2.new(0, 14, 0, 6),
		Size = UDim2.new(1, -28, 1, -12),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Parent = hintFrame,
	})

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
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(280, 0), MaxSize = Vector2.new(520, math.huge) }),
	})
end

local toastCounter = 0

function HudController.toast(text: string, kind: string?)
	toastCounter += 1
	local toast = Ui.new("TextLabel", {
		Name = "Toast",
		LayoutOrder = toastCounter,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info,
		BackgroundTransparency = 0.1,
		Font = Ui.Font,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		Corner = UDim.new(0, 10),
		Parent = toastList,
	}, {
		Ui.new("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
	})

	-- Не больше 4 сообщений одновременно
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("TextLabel") then
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
		if toast.Parent then
			local tween = TweenService:Create(toast, TweenInfo.new(0.4), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			})
			tween:Play()
			tween.Completed:Wait()
			toast:Destroy()
		end
	end)
end

local function onState(state)
	if not state then
		topBar.Visible = false
		hintFrame.Visible = false
		return
	end
	topBar.Visible = true
	roomTitle.Text = state.roomName
	roomSubtitle.Text = string.format(
		"Комната %d/%d · напарник: %s",
		state.roomIndex,
		state.roomCount,
		state.partnerName
	)
	sideBadge.Text = if state.side == "Light" then "☀ СВЕТЛЫЙ" else "☾ ТЁМНЫЙ"
	sideBadge.BackgroundColor3 = Colors[state.side] or Colors.Light
	sideBadge.TextColor3 = if state.side == "Light" then Color3.fromRGB(20, 20, 26) else Color3.new(1, 1, 1)
	hintLabel.Text = "💡 " .. (state.hint or "")
	hintFrame.Visible = state.hint ~= nil and state.hint ~= ""
end

function HudController.Start()
	build()
	Net.get("SessionState").OnClientEvent:Connect(onState)
	Net.get("Notify").OnClientEvent:Connect(function(text, kind)
		HudController.toast(text, kind)
	end)
end

return HudController
