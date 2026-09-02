--!nonstrict
--[[
	Signal.luau
	Minimal, allocation-light signal. Handlers are fired on fresh threads via
	task.spawn so one bad listener can't stall the emitter.
--]]

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, handler)
	return setmetatable({ _signal = signal, _handler = handler, Connected = true }, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	for index, handler in handlers do
		if handler == self._handler then
			table.remove(handlers, index)
			break
		end
	end
end

Connection.Destroy = Connection.Disconnect

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	table.insert(self._handlers, handler)
	return Connection.new(self, handler)
end

function Signal:Once(handler: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Iterate a copy: handlers may disconnect themselves mid-fire.
	local snapshot = table.clone(self._handlers)
	for _, handler in snapshot do
		task.spawn(handler, ...)
	end
end

--[[ Fires synchronously. Use for hot paths (per-frame movement events) where
	 thread churn actually shows up in the profiler. Listeners must not yield. ]]
function Signal:FireSync(...)
	local snapshot = table.clone(self._handlers)
	for _, handler in snapshot do
		local ok, err = pcall(handler, ...)
		if not ok then
			warn(`[Signal] handler error: {err}`)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
