--[[
	SeasonController — сезонный пропуск, задания и серия входов.

	* Кнопка «Пропуск» слева (под магазином).
	* Окно: уровень, полоса XP, лента из 30 уровней (бесплатно сверху, премиум снизу),
	  кнопки покупки премиума; вкладка «Задания» — 3 задания недели с прогрессом.
	* Окно «Награда за вход» — серия из 7 дней.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local SeasonConfig = require(ReplicatedStorage.Shared.SeasonConfig)
local Ui = require(script.Parent.Parent.Ui)

local SeasonController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 172, 188)
local CARD = Color3.fromRGB(32, 33, 44)
local GOLD = Color3.fromRGB(255, 205, 90)
local VIOLET = Color3.fromRGB(150, 110, 255)
local GREEN = Color3.fromRGB(90, 200, 120)
local ROBUX = Color3.fromRGB(70, 200, 110)
local SHARD = Color3.fromRGB(140, 220, 255)

local state = nil
local gui: ScreenGui
local panel: Frame
local body: Frame
local currentTab = "Pass"
local tabButtons = {}

local function text(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = WHITE,
	}
	for key, value in props do
		base[key] = value
	end
	return Ui.new("TextLabel", base)
end

local function button(props, onClick)
	local base = {
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = WHITE,
		AutoButtonColor = true,
		Corner = UDim.new(0, 10),
	}
	for key, value in props do
		base[key] = value
	end
	local result = Ui.new("TextButton", base, {
		Ui.new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	if onClick then
		result.Activated:Connect(onClick)
	end
	return result
end

local function progressBar(parent, position: UDim2, size: UDim2, fraction: number, color: Color3)
	local back = Ui.new("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(14, 14, 20),
		Corner = UDim.new(1, 0),
		Parent = parent,
	})
	Ui.new("Frame", {
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		BackgroundColor3 = color,
		Corner = UDim.new(1, 0),
		Parent = back,
	})
	return back
end

local function daysLeft(endTime: number): string
	local seconds = math.max(0, endTime - os.time())
	local days = math.floor(seconds / 86400)
	if days >= 1 then
		return string.format("ещё %d дн.", days)
	end
	return string.format("ещё %d ч.", math.floor(seconds / 3600))
end

--------------------------------------------------------------------------------
-- Ячейка награды
--------------------------------------------------------------------------------

local function rewardCell(parent, reward, reached: boolean, locked: boolean, accent: Color3)
	local cell = Ui.new("Frame", {
		Size = UDim2.new(1, 0, 0.5, -4),
		BackgroundColor3 = if reached and not locked then Color3.fromRGB(40, 56, 46) else CARD,
		Corner = UDim.new(0, 10),
		Stroke = if reward then accent else nil,
		Parent = parent,
	})
	if not reward then
		cell.BackgroundTransparency = 0.6
		return cell
	end

	if reward.type == "companion" then
		Ui.petViewport(reward.id, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromScale(0.85, 0.72),
			Parent = cell,
		})
	else
		local icon = if reward.type == "shards" then "shard" elseif reward.type == "egg" then "egg" else "skip"
		Ui.icon(icon, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.12, 0),
			Size = UDim2.fromScale(0.5, 0.42),
			Color = if reward.type == "shards"
				then SHARD
				elseif reward.type == "egg" then Color3.fromRGB(255, 236, 200)
				else WHITE,
			Parent = cell,
		})
	end

	local label = if reward.type == "shards"
		then tostring(reward.amount)
		elseif reward.type == "companion" then "Питомец"
		else "x" .. tostring(reward.amount)
	text({
		Position = UDim2.new(0, 4, 0.72, 0),
		Size = UDim2.new(1, -8, 0.24, 0),
		Font = Ui.FontHeavy,
		Text = label,
		Parent = cell,
	})

	if locked then
		local veil = Ui.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			Corner = UDim.new(0, 10),
			Parent = cell,
		})
		Ui.icon("lock", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(16, 16),
			Color = GOLD,
			Parent = veil,
		})
	elseif reached then
		Ui.icon("check", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(16, 16),
			Color = GREEN,
			Parent = cell,
		})
	end
	return cell
end

--------------------------------------------------------------------------------
-- Вкладки
--------------------------------------------------------------------------------

local function renderPass()
	if not state.active then
		text({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Сезон сейчас не идёт. Следите за обновлениями!",
			TextColor3 = MUTED,
			Parent = body,
		})
		return
	end

	-- Лента уровней
	local track = Ui.new("ScrollingFrame", {
		Name = "Track",
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for level = 1, state.levels do
		local reached = level <= state.level
		local column = Ui.new("Frame", {
			Name = "Level" .. level,
			LayoutOrder = level,
			Size = UDim2.new(0, 86, 1, -10),
			BackgroundTransparency = 1,
			Parent = track,
		})
		text({
			Size = UDim2.new(1, 0, 0, 22),
			Font = Ui.FontHeavy,
			Text = tostring(level),
			TextColor3 = if reached then GOLD else MUTED,
			Parent = column,
		})
		local cells = Ui.new("Frame", {
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 1, -26),
			BackgroundTransparency = 1,
			Parent = column,
		}, {
			Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		rewardCell(cells, SeasonConfig.FreeRewards[level], reached, false, Color3.fromRGB(90, 160, 255)).LayoutOrder = 1
		rewardCell(cells, SeasonConfig.PremiumRewards[level], reached, not state.premium, GOLD).LayoutOrder = 2
	end
	-- Прокрутить к текущему уровню
	task.defer(function()
		track.CanvasPosition = Vector2.new(math.max(0, (state.level - 2) * 94), 0)
	end)

	-- Кнопки покупки
	local actions = Ui.new("Frame", {
		Position = UDim2.new(0, 0, 1, -54),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	if state.premium then
		text({
			Size = UDim2.new(0.5, 0, 1, 0),
			Font = Ui.FontHeavy,
			Text = "Премиум активен",
			TextColor3 = GOLD,
			Parent = actions,
		})
	else
		button({
			Size = UDim2.new(0.32, 0, 1, 0),
			BackgroundColor3 = GOLD,
			TextColor3 = Color3.fromRGB(30, 24, 10),
			Text = string.format("Премиум · R$ %d", EconomyConfig.Products.SeasonPremium.price),
			Parent = actions,
		}, function()
			Net.get("Purchase"):FireServer("SeasonPremium")
		end)
		button({
			Size = UDim2.new(0.36, 0, 1, 0),
			BackgroundColor3 = VIOLET,
			Text = string.format(
				"Премиум+ (+10 ур.) · R$ %d",
				EconomyConfig.Products.SeasonPremiumPlus.price
			),
			Parent = actions,
		}, function()
			Net.get("Purchase"):FireServer("SeasonPremiumPlus")
		end)
	end
	if state.canBuyLevel then
		button({
			Size = UDim2.new(0.24, 0, 1, 0),
			BackgroundColor3 = ROBUX,
			Text = string.format("+1 уровень · R$ %d", EconomyConfig.Products.SeasonLevel.price),
			Parent = actions,
		}, function()
			Net.get("Purchase"):FireServer("SeasonLevel")
		end)
	end
end

local function renderQuests()
	local list = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	text({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Задания недели · обновятся " .. daysLeft(state.weekEnds),
		TextColor3 = MUTED,
		Parent = list,
	})

	for order, quest in state.quests do
		local row = Ui.new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = if quest.done then Color3.fromRGB(40, 56, 46) else CARD,
			Corner = UDim.new(0, 12),
			Parent = list,
		})
		Ui.icon(if quest.done then "check" else "sparkle", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Color = if quest.done then GREEN else GOLD,
			Parent = row,
		})
		text({
			Position = UDim2.new(0, 60, 0, 8),
			Size = UDim2.new(0.6, -60, 0, 26),
			Font = Ui.FontHeavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = quest.text,
			Parent = row,
		})
		progressBar(row, UDim2.new(0, 60, 0, 42), UDim2.new(0.6, -60, 0, 14), quest.progress / quest.goal, GOLD)
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 10),
			Size = UDim2.new(0.38, -14, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = string.format("%d / %d", quest.progress, quest.goal),
			Parent = row,
		})
		text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 38),
			Size = UDim2.new(0.38, -14, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = string.format("+%d XP · +%d осколков", SeasonConfig.XP.Quest, SeasonConfig.QuestShards),
			TextColor3 = MUTED,
			Parent = row,
		})
	end

	text({
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format(
			"Серия входов: день %d из %d · Ежедневная комната: %s",
			state.streak,
			#SeasonConfig.LoginStreak,
			if state.dailyDone then "пройдена" else "ждёт тебя (жёлтая площадка)"
		),
		TextColor3 = MUTED,
		Parent = list,
	})
end

local header: Frame

local function renderHeader()
	header:ClearAllChildren()
	text({
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0.6, 0, 0, 30),
		Font = Ui.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = state.name,
		Parent = header,
	})
	text({
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(0.6, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if state.active then "Сезон: " .. daysLeft(state.endTime) else "",
		TextColor3 = MUTED,
		Parent = header,
	})
	local badge = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 0),
		Size = UDim2.new(0.36, 0, 0, 52),
		BackgroundColor3 = CARD,
		Corner = UDim.new(0, 12),
		Parent = header,
	})
	text({
		Position = UDim2.new(0, 10, 0, 4),
		Size = UDim2.new(1, -20, 0, 24),
		Font = Ui.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("Уровень %d / %d", state.level, state.levels),
		TextColor3 = GOLD,
		Parent = badge,
	})
	local fraction = if state.level >= state.levels then 1 else state.xpInLevel / state.xpPerLevel
	progressBar(badge, UDim2.new(0, 10, 0, 32), UDim2.new(1, -20, 0, 12), fraction, GOLD)
end

local function render()
	if not panel or not panel.Visible or not state then
		return
	end
	renderHeader()
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	for id, tab in tabButtons do
		tab.BackgroundColor3 = if id == currentTab then GOLD else CARD
		tab.TextColor3 = if id == currentTab then Color3.fromRGB(30, 24, 10) else WHITE
	end
	if currentTab == "Pass" then
		renderPass()
	else
		renderQuests()
	end
end

--------------------------------------------------------------------------------
-- Построение
--------------------------------------------------------------------------------

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "TwoSidesSeason",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local openButton = Ui.new("TextButton", {
		Name = "PassButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 88),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Ui.Background,
		BackgroundTransparency = 0.15,
		Text = "",
		Corner = UDim.new(0, 16),
		Stroke = GOLD,
		Parent = gui,
	})
	Ui.icon("sparkle", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(36, 36),
		Color = GOLD,
		Parent = openButton,
	})
	text({
		Position = UDim2.new(0, 4, 1, -24),
		Size = UDim2.new(1, -8, 0, 18),
		Font = Ui.FontHeavy,
		Text = "Пропуск",
		Parent = openButton,
	})

	panel = Ui.new("Frame", {
		Name = "Season",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.74, 0.74),
		BackgroundColor3 = Ui.Background,
		Visible = false,
		Corner = UDim.new(0, 18),
		Stroke = GOLD,
		Parent = gui,
	}, {
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(340, 320), MaxSize = Vector2.new(900, 560) }),
	})

	header = Ui.new("Frame", {
		Position = UDim2.new(0, 18, 0, 14),
		Size = UDim2.new(1, -36, 0, 56),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local close = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(235, 80, 80),
		Text = "",
		Corner = UDim.new(1, 0),
		Parent = panel,
	})
	Ui.icon("close", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		Parent = close,
	})
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local tabs = Ui.new("Frame", {
		Position = UDim2.new(0, 18, 0, 78),
		Size = UDim2.new(1, -36, 0, 36),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	for order, tab in { { id = "Pass", title = "Награды" }, { id = "Quests", title = "Задания" } } do
		tabButtons[tab.id] = button({
			LayoutOrder = order,
			Size = UDim2.new(0, 150, 1, 0),
			BackgroundColor3 = CARD,
			Text = tab.title,
			Parent = tabs,
		}, function()
			currentTab = tab.id
			render()
		end)
	end

	body = Ui.new("Frame", {
		Position = UDim2.new(0, 18, 0, 124),
		Size = UDim2.new(1, -36, 1, -140),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	openButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			Net.get("RequestSeason"):FireServer()
			render()
		end
	end)
end

local function showDailyReward(reward)
	local popup = Ui.new("Frame", {
		Name = "DailyReward",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 250),
		BackgroundColor3 = Ui.Background,
		Corner = UDim.new(0, 18),
		Stroke = GOLD,
		Parent = gui,
	})
	local scale = Ui.new("UIScale", { Scale = 0.6, Parent = popup })
	text({
		Position = UDim2.new(0, 16, 0, 14),
		Size = UDim2.new(1, -32, 0, 32),
		Font = Ui.FontHeavy,
		Text = "Награда за вход!",
		TextColor3 = GOLD,
		Parent = popup,
	})
	local row = Ui.new("Frame", {
		Position = UDim2.new(0, 16, 0, 58),
		Size = UDim2.new(1, -32, 0, 110),
		BackgroundTransparency = 1,
		Parent = popup,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	for day, amount in SeasonConfig.LoginStreak do
		local isToday = day == reward.streak
		local cell = Ui.new("Frame", {
			LayoutOrder = day,
			Size = UDim2.new(1 / 7, -6, 1, 0),
			BackgroundColor3 = if isToday
				then Color3.fromRGB(70, 60, 24)
				elseif day < reward.streak then Color3.fromRGB(40, 56, 46)
				else CARD,
			Corner = UDim.new(0, 10),
			Stroke = if isToday then GOLD else nil,
			Parent = row,
		})
		text({
			Position = UDim2.new(0, 2, 0, 4),
			Size = UDim2.new(1, -4, 0, 18),
			Text = "День " .. day,
			TextColor3 = MUTED,
			Parent = cell,
		})
		Ui.icon(if day == #SeasonConfig.LoginStreak then "egg" else "shard", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 26),
			Size = UDim2.fromOffset(34, 34),
			Color = if day == #SeasonConfig.LoginStreak then GOLD else SHARD,
			Parent = cell,
		})
		text({
			Position = UDim2.new(0, 2, 1, -30),
			Size = UDim2.new(1, -4, 0, 24),
			Font = Ui.FontHeavy,
			Text = tostring(amount),
			Parent = cell,
		})
	end
	local ok = button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(220, 46),
		BackgroundColor3 = GREEN,
		Text = string.format("Забрать +%d", reward.amount),
		Parent = popup,
	})
	ok.Activated:Connect(function()
		popup:Destroy()
	end)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function SeasonController.Start()
	build()
	Net.get("SeasonState").OnClientEvent:Connect(function(newState)
		state = newState
		render()
	end)
	Net.get("DailyReward").OnClientEvent:Connect(showDailyReward)
	Net.get("SessionState").OnClientEvent:Connect(function(sessionState)
		if sessionState then
			panel.Visible = false
		end
	end)
	Net.get("RequestSeason"):FireServer()
end

return SeasonController
