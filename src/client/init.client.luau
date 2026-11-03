--[[
	Точка входа клиента.
]]

local ORDER = {
	"DimensionController",
	"HudController",
	"KeypadController",
	"ShopController",
	"ChatTagController",
}

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(script.Controllers[name])
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Init then
		controller.Init(controllers)
	end
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		task.spawn(controller.Start)
	end
end
