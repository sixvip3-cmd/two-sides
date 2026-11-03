--[[
	ShopController — магазин, осколки и компаньоны на клиенте.

	* Слева сверху: баланс осколков 💠.
	* Слева: кнопка «Магазин».
	* Справа (в комнате): кнопка «Пропустить комнату» — кредит пропуска или покупка.
	* Окно магазина с вкладками: Яйца · Компаньоны · Осколки · Пассы.
	* Окно «Выпал компаньон!» после открытия яйца.
	Все действия — запросы к серверу; клиент ничего не решает сам.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CompanionConfig = require(ReplicatedStorage.Shared.CompanionConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Parent.Ui)

local ShopController = {}

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 172, 188)
local CARD = Color3.fromRGB(32, 33, 44)
local ACCENT = Color3.fromRGB(110, 190, 255)
local GREEN = Color3.fromRGB(90, 200, 120)
local ROBUX = Color3.fromRGB(70, 200, 110)
local SHARD = Color3.fromRGB(140, 220, 255)

local inventory = nil
local inSession = false

local gui: ScreenGui
local shardsLabel: TextLabel
local skipButton: TextButton
local skipLabel: TextLabel
local panel: Frame
local content: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Eggs"
local resultFrame: Frame

local TABS = {
	{ id = "Eggs", title = "Яйца", icon = "egg" },
	{ id = "Companions", title = "Компаньоны", icon = "sparkle" },
	{ id = "Shards", title = "Осколки", icon = "shard" },
	{ id = "Passes", title = "Пассы", icon = "lock" },
}

--------------------------------------------------------------------------------
-- Общие элементы
--------------------------------------------------------------------------------

local function textLabel(props)
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

-- Карточка товара: иконка, заголовок, подпись и кнопка.
local function makeCard(spec)
	local card = Ui.new("Frame", {
		Name = "Card",
		LayoutOrder = spec.order or 0,
		BackgroundColor3 = CARD,
		Corner = UDim.new(0, 12),
		Stroke = spec.accent,
		Parent = content,
	})

	Ui.icon(spec.icon, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.06, 0),
		Size = UDim2.fromScale(0.34, 0.3),
		Color = spec.iconColor or WHITE,
		Parent = card,
	})

	textLabel({
		Position = UDim2.fromScale(0.06, 0.38),
		Size = UDim2.fromScale(0.88, 0.14),
		Font = Ui.FontHeavy,
		Text = spec.title,
		TextColor3 = spec.titleColor or WHITE,
		Parent = card,
	})

	textLabel({
		Position = UDim2.fromScale(0.06, 0.53),
		Size = UDim2.fromScale(0.88, 0.2),
		Text = spec.subtitle or "",
		TextColor3 = MUTED,
		Parent = card,
	})

	local button = Ui.new("TextButton", {
		Name = "Action",
		Position = UDim2.fromScale(0.08, 0.77),
		Size = UDim2.fromScale(0.84, 0.17),
		BackgroundColor3 = if spec.disabled then Color3.fromRGB(60, 60, 72) else (spec.buttonColor or ACCENT),
		AutoButtonColor = not spec.disabled,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = spec.buttonText,
		Corner = UDim.new(0, 8),
		Parent = card,
	}, {
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	if spec.onClick and not spec.disabled then
		button.Activated:Connect(spec.onClick)
	end
	return card
end

local function infoText(text: string, order: number)
	textLabel({
		Name = "Info",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 40),
		Text = text,
		TextColor3 = MUTED,
		Parent = content,
	})
end

--------------------------------------------------------------------------------
-- Вкладки
--------------------------------------------------------------------------------

local function oddsText(odds): string
	local parts = {}
	for _, rarity in CompanionConfig.RarityOrder do
		if (odds[rarity] or 0) > 0 then
			table.insert(parts, string.format("%s %g%%", CompanionConfig.Rarities[rarity].name, odds[rarity]))
		end
	end
	return table.concat(parts, " · ")
end

local RENDER = {}

function RENDER.Eggs()
	for order, eggId in CompanionConfig.EggOrder do
		local egg = CompanionConfig.Eggs[eggId]
		local enough = inventory and inventory.shards >= egg.cost
		makeCard({
			order = order * 2,
			icon = "egg",
			iconColor = Color3.fromRGB(255, 236, 200),
			title = egg.name,
			subtitle = "Шансы: " .. oddsText(egg.odds),
			buttonText = string.format("Открыть · %d 💠", egg.cost),
			buttonColor = if enough then ACCENT else Color3.fromRGB(90, 90, 104),
			onClick = function()
				Net.get("OpenEgg"):FireServer(eggId, false)
			end,
		})
		if inventory and inventory.freeEgg then
			makeCard({
				order = order * 2 + 1,
				icon = "egg",
				iconColor = Color3.fromRGB(255, 214, 110),
				accent = Color3.fromRGB(255, 214, 110),
				title = egg.name .. " (VIP)",
				subtitle = "Бесплатное яйцо дня",
				buttonText = "Открыть бесплатно",
				buttonColor = GREEN,
				onClick = function()
					Net.get("OpenEgg"):FireServer(eggId, true)
				end,
			})
		end
	end
end

function RENDER.Companions()
	local owned = inventory and inventory.companions or {}
	local equipped = inventory and inventory.equipped or ""
	for order, id in CompanionConfig.CompanionOrder do
		local def = CompanionConfig.Companions[id]
		local rarity = CompanionConfig.Rarities[def.rarity]
		local count = owned[id] or 0
		if count > 0 then
			local isEquipped = equipped == id
			makeCard({
				order = order,
				icon = "sparkle",
				iconColor = def.color,
				accent = rarity.color,
				title = def.name,
				titleColor = rarity.color,
				subtitle = string.format("%s · ×%d", rarity.name, count),
				buttonText = if isEquipped then "Снять" else "Надеть",
				buttonColor = if isEquipped then Color3.fromRGB(110, 110, 128) else GREEN,
				onClick = function()
					Net.get("EquipCompanion"):FireServer(if isEquipped then "" else id)
				end,
			})
		else
			makeCard({
				order = order,
				icon = "lock",
				iconColor = Color3.fromRGB(90, 92, 108),
				title = "???",
				subtitle = rarity.name,
				buttonText = "Нет",
				disabled = true,
			})
		end
	end
end

function RENDER.Shards()
	if inventory and not inventory.shardPacksAllowed then
		infoText(
			"Наборы осколков недоступны в твоём регионе. Осколки можно заработать в комнатах!",
			0
		)
		return
	end
	for order, key in EconomyConfig.ShardPackOrder do
		local product = EconomyConfig.Products[key]
		makeCard({
			order = order,
			icon = "shard",
			iconColor = SHARD,
			title = product.title,
			subtitle = product.bonus or "",
			buttonText = string.format("R$ %d", product.price),
			buttonColor = ROBUX,
			onClick = function()
				Net.get("Purchase"):FireServer(key)
			end,
		})
	end
end

function RENDER.Passes()
	for order, key in EconomyConfig.GamePassOrder do
		local pass = EconomyConfig.GamePasses[key]
		local owned = inventory and inventory.passes and inventory.passes[key]
		makeCard({
			order = order,
			icon = if key == "VIP" then "sparkle" else "shard",
			iconColor = if key == "VIP" then Color3.fromRGB(255, 214, 110) else SHARD,
			title = pass.title,
			subtitle = pass.description,
			buttonText = if owned then "Куплено ✓" else string.format("R$ %d", pass.price),
			buttonColor = ROBUX,
			disabled = owned,
			onClick = function()
				Net.get("Purchase"):FireServer(key)
			end,
		})
	end
end

local function render()
	if not panel or not panel.Visible then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then ACCENT else CARD
	end
	RENDER[currentTab]()
end

local function openShop(tab: string?)
	currentTab = tab or currentTab
	panel.Visible = true
	render()
end

local function closeShop()
	panel.Visible = false
end

--------------------------------------------------------------------------------
-- Построение интерфейса
--------------------------------------------------------------------------------

local function buildHud()
	-- Баланс осколков
	local balance = Ui.new("Frame", {
		Name = "Balance",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = Ui.Background,
		BackgroundTransparency = 0.25,
		Corner = UDim.new(0, 12),
		Parent = gui,
	})
	Ui.icon("shard", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		Color = SHARD,
		Parent = balance,
	})
	shardsLabel = textLabel({
		Position = UDim2.new(0, 46, 0, 6),
		Size = UDim2.new(1, -56, 1, -12),
		Font = Ui.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "…",
		Parent = balance,
	})

	-- Кнопка магазина
	local shopButton = Ui.new("TextButton", {
		Name = "ShopButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(76, 76),
		BackgroundColor3 = Ui.Background,
		BackgroundTransparency = 0.15,
		Text = "",
		Corner = UDim.new(0, 16),
		Stroke = ACCENT,
		Parent = gui,
	})
	Ui.icon("egg", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(38, 38),
		Color = Color3.fromRGB(255, 236, 200),
		Parent = shopButton,
	})
	textLabel({
		Position = UDim2.new(0, 4, 1, -24),
		Size = UDim2.new(1, -8, 0, 18),
		Font = Ui.FontHeavy,
		Text = "Магазин",
		Parent = shopButton,
	})
	shopButton.Activated:Connect(function()
		if panel.Visible then
			closeShop()
		else
			openShop()
		end
	end)

	-- Пропуск комнаты (виден только в комнате)
	skipButton = Ui.new("TextButton", {
		Name = "SkipButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 84),
		Size = UDim2.fromOffset(160, 56),
		BackgroundColor3 = ROBUX,
		Text = "",
		Visible = false,
		Corner = UDim.new(0, 12),
		Parent = gui,
	})
	Ui.icon("skip", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Parent = skipButton,
	})
	skipLabel = textLabel({
		Position = UDim2.new(0, 48, 0, 6),
		Size = UDim2.new(1, -56, 1, -12),
		Font = Ui.FontHeavy,
		Text = "",
		Parent = skipButton,
	})
	skipButton.Activated:Connect(function()
		Net.get("UseSkip"):FireServer()
	end)
end

local function buildPanel()
	panel = Ui.new("Frame", {
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.7, 0.72),
		BackgroundColor3 = Ui.Background,
		Visible = false,
		Corner = UDim.new(0, 18),
		Stroke = Color3.fromRGB(60, 62, 80),
		Parent = gui,
	}, {
		Ui.new("UISizeConstraint", { MinSize = Vector2.new(320, 300), MaxSize = Vector2.new(820, 560) }),
	})

	textLabel({
		Position = UDim2.new(0, 20, 0, 12),
		Size = UDim2.new(1, -90, 0, 34),
		Font = Ui.FontHeavy,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Магазин",
		Parent = panel,
	})

	local close = Ui.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
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
	close.Activated:Connect(closeShop)

	local tabs = Ui.new("Frame", {
		Name = "Tabs",
		Position = UDim2.new(0, 16, 0, 56),
		Size = UDim2.new(1, -32, 0, 40),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, tab in TABS do
		local button = Ui.new("TextButton", {
			Name = tab.id,
			LayoutOrder = order,
			Size = UDim2.new(0.25, -6, 1, 0),
			BackgroundColor3 = CARD,
			Text = "",
			Corner = UDim.new(0, 10),
			Parent = tabs,
		})
		Ui.icon(tab.icon, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			Parent = button,
		})
		textLabel({
			Position = UDim2.new(0, 36, 0, 8),
			Size = UDim2.new(1, -42, 1, -16),
			Font = Ui.FontHeavy,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = tab.title,
			Parent = button,
		})
		button.Activated:Connect(function()
			currentTab = tab.id
			render()
		end)
		tabButtons[tab.id] = button
	end

	content = Ui.new("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.new(0, 16, 0, 106),
		Size = UDim2.new(1, -32, 1, -122),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(170, 220),
			CellPadding = UDim2.fromOffset(12, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
end

local function buildResult()
	resultFrame = Ui.new("Frame", {
		Name = "EggResult",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 300),
		BackgroundColor3 = Ui.Background,
		Visible = false,
		Corner = UDim.new(0, 18),
		Stroke = ACCENT,
		Parent = gui,
	}, {
		Ui.new("UIScale", { Name = "Scale", Scale = 1 }),
	})
end

local function showResult(result)
	local def = CompanionConfig.Companions[result.companion]
	if not def then
		return
	end
	local rarity = CompanionConfig.Rarities[def.rarity]
	resultFrame:ClearAllChildren()
	Ui.new("UICorner", { CornerRadius = UDim.new(0, 18), Parent = resultFrame })
	Ui.new("UIStroke", { Color = rarity.color, Thickness = 3, Parent = resultFrame })
	local scale = Ui.new("UIScale", { Scale = 0.6, Parent = resultFrame })

	textLabel({
		Position = UDim2.new(0, 16, 0, 14),
		Size = UDim2.new(1, -32, 0, 30),
		Font = Ui.FontHeavy,
		Text = if result.isNew then "НОВЫЙ КОМПАНЬОН!" else "Выпал компаньон",
		TextColor3 = if result.isNew then Color3.fromRGB(255, 214, 110) else MUTED,
		Parent = resultFrame,
	})
	Ui.icon("sparkle", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(100, 100),
		Color = def.color,
		Parent = resultFrame,
	})
	textLabel({
		Position = UDim2.new(0, 16, 0, 166),
		Size = UDim2.new(1, -32, 0, 40),
		Font = Ui.FontHeavy,
		Text = def.name,
		Parent = resultFrame,
	})
	textLabel({
		Position = UDim2.new(0, 16, 0, 206),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Ui.FontHeavy,
		Text = rarity.name,
		TextColor3 = rarity.color,
		Parent = resultFrame,
	})
	local ok = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(160, 44),
		BackgroundColor3 = GREEN,
		Font = Ui.FontHeavy,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = "Круто!",
		Corner = UDim.new(0, 10),
		Parent = resultFrame,
	}, {
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
	})
	ok.Activated:Connect(function()
		resultFrame.Visible = false
	end)

	resultFrame.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

--------------------------------------------------------------------------------

local function updateSkipButton()
	skipButton.Visible = inSession
	if not inventory then
		skipLabel.Text = "Пропустить"
		return
	end
	if inventory.skipCredits > 0 then
		skipLabel.Text = string.format("Пропустить\n(есть: %d)", inventory.skipCredits)
	else
		skipLabel.Text = string.format("Пропустить\nR$ %d", EconomyConfig.Products.SkipRoom.price)
	end
end

local function onInventory(newInventory)
	inventory = newInventory
	shardsLabel.Text = tostring(newInventory.shards)
	updateSkipButton()
	render()
end

function ShopController.getInventory()
	return inventory
end

function ShopController.Start()
	gui = Ui.new("ScreenGui", {
		Name = "TwoSidesShop",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildHud()
	buildPanel()
	buildResult()

	Net.get("Inventory").OnClientEvent:Connect(onInventory)
	Net.get("EggResult").OnClientEvent:Connect(showResult)
	Net.get("SessionState").OnClientEvent:Connect(function(state)
		inSession = state ~= nil
		updateSkipButton()
		if inSession then
			closeShop()
		end
	end)

	Net.get("RequestInventory"):FireServer()
end

return ShopController
