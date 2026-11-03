--[[
	TutorialController — окно «Как играть» для новичка и кнопка «Пригласить друга».

	Окно показывается, когда сервер присылает ShowTutorial (только при первом входе).
	Кнопка «Друг» (слева, под пропуском) открывает стандартное окно приглашения Roblox.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Parent.Ui)

local TutorialController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(180, 182, 198)
local Colors = Constants.SideColors

local STEPS = {
	{
		icon = "partner",
		color = Color3.fromRGB(120, 200, 255),
		title = "Найди напарника",
		text = "Встань с другом на площадку «Вдвоём» или на голубую — к случайному игроку.",
	},
	{
		icon = "sun",
		color = Colors.Light,
		title = "Два мира",
		text = "Один из вас в светлом мире, другой — в тёмном. Вы видите разное!",
	},
	{
		icon = "hint",
		color = Color3.fromRGB(255, 214, 110),
		title = "Говорите друг с другом",
		text = "Плита одного открывает дверь другому. Код видит один — вводит другой.",
	},
	{
		icon = "exit",
		color = Colors.Success,
		title = "Выход — вдвоём",
		text = "Комната пройдена, когда вы оба стоите в зелёном выходе.",
	},
}

local gui: ScreenGui

local function showTutorial()
	local popup = Ui.new("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 420),
		BackgroundColor3 = Ui.Background,
		Corner = UDim.new(0, 18),
		Stroke = Colors.Dark,
		Parent = gui,
	})
	local scale = Ui.new("UIScale", { Scale = 0.6, Parent = popup })

	Ui.new("TextLabel", {
		Position = UDim2.new(0, 20, 0, 16),
		Size = UDim2.new(1, -40, 0, 40),
		BackgroundTransparency = 1,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "Добро пожаловать в TWO SIDES!",
		Parent = popup,
	})

	for index, step in STEPS do
		local y = 68 + (index - 1) * 74
		Ui.icon(step.icon, {
			Position = UDim2.new(0, 24, 0, y + 8),
			Size = UDim2.fromOffset(44, 44),
			Color = step.color,
			Background = Ui.Background,
			Parent = popup,
		})
		Ui.new("TextLabel", {
			Position = UDim2.new(0, 84, 0, y),
			Size = UDim2.new(1, -108, 0, 26),
			BackgroundTransparency = 1,
			Font = Ui.FontHeavy,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = step.color,
			Text = step.title,
			Parent = popup,
		})
		Ui.new("TextLabel", {
			Position = UDim2.new(0, 84, 0, y + 28),
			Size = UDim2.new(1, -108, 0, 38),
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = MUTED,
			Text = step.text,
			Parent = popup,
		})
	end

	local ok = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(220, 48),
		BackgroundColor3 = Colors.Success,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "Понятно, играем!",
		Corner = UDim.new(0, 12),
		Parent = popup,
	}, {
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	ok.Activated:Connect(function()
		Net.get("TutorialDone"):FireServer()
		popup:Destroy()
	end)

	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

local function buildInviteButton()
	local invite = Ui.new("TextButton", {
		Name = "InviteButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 176),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Ui.Background,
		BackgroundTransparency = 0.15,
		Text = "",
		Corner = UDim.new(0, 16),
		Stroke = Color3.fromRGB(120, 200, 255),
		Parent = gui,
	})
	Ui.icon("partner", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(34, 34),
		Color = Color3.fromRGB(120, 200, 255),
		Parent = invite,
	})
	Ui.new("TextLabel", {
		Position = UDim2.new(0, 4, 1, -24),
		Size = UDim2.new(1, -8, 0, 18),
		BackgroundTransparency = 1,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "Друг",
		Parent = invite,
	})
	invite.Activated:Connect(function()
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if ok and canInvite then
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end
	end)

	-- Кнопка видна только в лобби
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		invite.Visible = state == nil
	end)
end

function TutorialController.Start()
	gui = Ui.new("ScreenGui", {
		Name = "TwoSidesTutorial",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildInviteButton()
	Net.get("ShowTutorial").OnClientEvent:Connect(showTutorial)
end

return TutorialController
