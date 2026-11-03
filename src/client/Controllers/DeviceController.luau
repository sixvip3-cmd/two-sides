--[[
	DeviceController — интерфейс под любой экран и геймпад.

	* Всем окнам игры (ScreenGui с именем TwoSides*) добавляется UIScale:
	  на маленьких экранах (телефон) интерфейс уменьшается, на больших — чуть увеличивается.
	* Геймпад: ButtonY — сменить мир (соло-тест), ButtonB — закрыть открытое окно.
	* При открытии окна на геймпаде выделение ставится на первую кнопку.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DeviceController = {}

local player = Players.LocalPlayer

local BASE = Vector2.new(1280, 760)
local MIN_SCALE, MAX_SCALE = 0.72, 1.15

local scales: { UIScale } = {}

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local size = camera.ViewportSize
	return math.clamp(math.min(size.X / BASE.X, size.Y / BASE.Y), MIN_SCALE, MAX_SCALE)
end

local function applyAll()
	local value = computeScale()
	for _, scale in scales do
		scale.Scale = value
	end
end

local function attach(screenGui: Instance)
	if not screenGui:IsA("ScreenGui") or string.sub(screenGui.Name, 1, 8) ~= "TwoSides" then
		return
	end
	if screenGui:FindFirstChild("DeviceScale") then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Name = "DeviceScale"
	scale.Scale = computeScale()
	scale.Parent = screenGui
	table.insert(scales, scale)
end

-- Первое видимое окно с кнопками — для выделения геймпадом
local function firstButton(root: Instance): GuiButton?
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Visible and descendant.Selectable then
			return descendant
		end
	end
	return nil
end

local WINDOWS = { "Shop", "Season", "Panel", "Tutorial", "EggResult", "DailyReward" }

local function openWindows(playerGui: Instance): { GuiObject }
	local result = {}
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("Frame") and descendant.Visible and table.find(WINDOWS, descendant.Name) then
			local screen = descendant:FindFirstAncestorOfClass("ScreenGui")
			if screen and string.sub(screen.Name, 1, 8) == "TwoSides" then
				table.insert(result, descendant)
			end
		end
	end
	return result
end

function DeviceController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	for _, child in playerGui:GetChildren() do
		attach(child)
	end
	playerGui.ChildAdded:Connect(attach)

	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyAll)
		end
		applyAll()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	-- Геймпад
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Gamepad1 then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB then
			-- закрыть верхнее открытое окно
			local windows = openWindows(playerGui)
			local top = windows[#windows]
			if top then
				local close = top:FindFirstChild("Close") or top:FindFirstChild("Close", true)
				if close and close:IsA("GuiButton") then
					top.Visible = false
					GuiService.SelectedObject = nil
				end
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonSelect and not processed then
			-- выделить первую кнопку открытого окна
			local windows = openWindows(playerGui)
			local top = windows[#windows]
			if top then
				GuiService.SelectedObject = firstButton(top)
			end
		end
	end)
end

return DeviceController
