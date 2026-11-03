--[[
	Signal — минимальная реализация событий для модулей.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handler = { fn = fn, connected = true }
	table.insert(self._handlers, handler)
	local handlers = self._handlers
	return {
		Disconnect = function()
			handler.connected = false
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
