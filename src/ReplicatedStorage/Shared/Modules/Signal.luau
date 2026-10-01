--[[
	Signal
	Lightweight event object used for module-to-module communication.
	Handlers run in their own thread (task.spawn) so a yielding or erroring
	handler can never block the firer.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection.new(signal, handler)
	return setmetatable({
		Connected = true,
		_signal = signal,
		_handler = handler,
	}, Connection)
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	local connection = Connection.new(self, handler)
	table.insert(self._handlers, connection)
	return connection
end

function Signal:Once(handler: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	-- Copy so handlers can disconnect while iterating.
	local snapshot = table.clone(self._handlers)
	for _, connection in snapshot do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in table.clone(self._handlers) do
		connection:Disconnect()
	end
end

Signal.Destroy = Signal.DisconnectAll

return Signal
