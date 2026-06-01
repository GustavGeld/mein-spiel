--!strict
-- Minimal, allocation-aware Signal. Single-threaded model, ScriptSignal-Style.
-- Bewusst klein gehalten; bei Bedarf später auf GoodSignal/Janitor wechseln.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

function Signal.new()
	return setmetatable({ _handlers = {} :: { (any...) -> () } }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local conn
	conn = {
		Connected = true,
		Disconnect = function(self)
			if not self.Connected then return end
			self.Connected = false
			for i, h in ipairs((Signal :: any)._owner(conn)._handlers) do
				if h == fn then
					table.remove((Signal :: any)._owner(conn)._handlers, i)
					break
				end
			end
		end,
	}
	-- Stash owner ref on connection for Disconnect to find the signal
	rawset(conn, "_signal", self)
	table.insert(self._handlers, fn)
	return conn :: any
end

-- helper
function Signal._owner(conn)
	return rawget(conn, "_signal")
end

function Signal:Fire(...)
	-- Snapshot to allow mutation during fire
	local snapshot = table.clone(self._handlers)
	for _, fn in ipairs(snapshot) do
		task.spawn(fn, ...)
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
