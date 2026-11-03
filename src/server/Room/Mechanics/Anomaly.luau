--[[
	Anomaly — «найди отличие между мирами».

	В комнате набор одинаковых предметов, у каждого есть копия в светлом и в тёмном мире.
	Сервер случайно меняет ОДИН предмет в ОДНОМ мире: цвет, размер, поворот,
	поднимает в воздух или убирает совсем. Игроки описывают друг другу, что видят,
	и каждый отмечает предмет у себя (E / тап).
	  * Оба отметили один и тот же правильный предмет → связь включается (дверь открыта).
	  * Иначе отличие перекладывается в другое место — ищите заново.

	Отметки хранятся по сторонам, а не по игрокам — поэтому работает и соло-тест.
	Атрибуты детали: AnomalyGroup, AnomalyIndex, Link.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Attr = Constants.Attr
local Side = Constants.Side
local Colors = Constants.SideColors

local MODIFICATIONS = { "color", "bigger", "rotate", "lifted", "missing" }

local function restore(entry)
	local part, original = entry.part, entry.original
	part.CFrame = original.CFrame
	part.Size = original.Size
	part.Color = original.Color
	part.Transparency = original.Transparency
	part.CanCollide = original.CanCollide
end

local function applyModification(entry, kind: string)
	local part, original = entry.part, entry.original
	if kind == "color" then
		local h, s, v = original.Color:ToHSV()
		part.Color = Color3.fromHSV((h + 0.45) % 1, math.max(s, 0.6), math.max(v, 0.75))
	elseif kind == "bigger" then
		local newSize = original.Size * 1.4
		part.Size = newSize
		part.CFrame = original.CFrame + Vector3.new(0, (newSize.Y - original.Size.Y) / 2, 0)
	elseif kind == "rotate" then
		part.CFrame = original.CFrame * CFrame.Angles(0, math.rad(40), math.rad(25))
	elseif kind == "lifted" then
		part.CFrame = original.CFrame + Vector3.new(0, 2.5, 0)
	elseif kind == "missing" then
		part.Transparency = 1
		part.CanCollide = false
	end
end

local function clearMark(group, side: string)
	local box = group.boxes[side]
	if box then
		box:Destroy()
		group.boxes[side] = nil
	end
	group.marks[side] = nil
end

-- Выбрать новое отличие (старое откатывается).
local function roll(group)
	if group.current then
		restore(group.current.entry)
	end

	local indices = {}
	for index, sides in group.items do
		if sides[Side.Light] and sides[Side.Dark] then
			table.insert(indices, index)
		end
	end
	if #indices == 0 then
		return
	end

	local previous = group.current and group.current.index
	local index
	repeat
		index = indices[math.random(1, #indices)]
	until #indices == 1 or index ~= previous

	local side = if math.random() < 0.5 then Side.Light else Side.Dark
	local entry = group.items[index][side]

	local options = table.clone(MODIFICATIONS)
	if entry.part.Shape == Enum.PartType.Ball then
		-- Поворот шара не заметен
		table.remove(options, table.find(options, "rotate"))
	end
	local kind = options[math.random(1, #options)]

	applyModification(entry, kind)
	group.current = { index = index, side = side, entry = entry, kind = kind }
end

local function onMark(room, group, player: Player, index: number, side: string)
	if group.solved or group.checking then
		return
	end
	local entry = group.items[index] and group.items[index][side]
	if not entry or not room:canUse(player, entry.part) then
		return
	end

	clearMark(group, side)
	group.marks[side] = index

	local box = Instance.new("SelectionBox")
	box.Name = "AnomalyMark"
	box.Adornee = entry.part
	box.LineThickness = 0.12
	box.Color3 = Colors[side]
	box.SurfaceTransparency = 0.8
	box.SurfaceColor3 = Colors[side]
	box.Parent = entry.part
	group.boxes[side] = box

	local partner = room.session:getPartner(player)
	if partner then
		room.session:notify(partner, string.format("Напарник отметил предмет #%d", index), "info")
	end

	local light, dark = group.marks[Side.Light], group.marks[Side.Dark]
	if not light or not dark then
		room.session:notify(
			player,
			string.format("Отмечен #%d. Теперь пусть отметит напарник", index),
			"info"
		)
		return
	end

	if group.current and light == dark and light == group.current.index then
		group.solved = true
		for _, sides in group.items do
			for _, item in sides do
				if item.prompt then
					item.prompt:Destroy()
				end
			end
		end
		for _, markBox in group.boxes do
			markBox.Color3 = Colors.Success
			markBox.SurfaceColor3 = Colors.Success
		end
		room:setSource(group.link, group.token, true)
		room.session:onAnomalyFound()
		room.session:notify(nil, "Нашли отличие! Проход открыт", "success")
	else
		group.checking = true
		room.session:notify(
			nil,
			"Не то! Отличие переместилось — смотрите снова",
			"error"
		)
		task.delay(1.2, function()
			if room.destroyed then
				return
			end
			clearMark(group, Side.Light)
			clearMark(group, Side.Dark)
			roll(group)
			group.checking = false
		end)
	end
end

return function(room, part: BasePart)
	local groupId = part:GetAttribute("AnomalyGroup")
	local index = part:GetAttribute("AnomalyIndex")
	local side = part:GetAttribute(Attr.Side)

	local group = room.anomalyGroups[groupId]
	if not group then
		group = {
			token = Instance.new("BoolValue"), -- уникальный ключ источника для связи
			link = part:GetAttribute(Attr.Link),
			items = {},
			marks = {},
			boxes = {},
			current = nil,
			solved = false,
			checking = false,
		}
		room.anomalyGroups[groupId] = group
		room:onWired(function()
			roll(group)
		end)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Это отличие!"
	prompt.ObjectText = "Предмет #" .. index
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	group.items[index] = group.items[index] or {}
	group.items[index][side] = {
		part = part,
		prompt = prompt,
		original = {
			CFrame = part.CFrame,
			Size = part.Size,
			Color = part.Color,
			Transparency = part.Transparency,
			CanCollide = part.CanCollide,
		},
	}

	prompt.Triggered:Connect(function(player)
		onMark(room, group, player, index, side)
	end)
end
