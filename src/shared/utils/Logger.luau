--!strict
-- Lightweight scoped logger. `Logger.scope("PackService").info("rolled %s", id)`

local Logger = {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local CURRENT = LEVELS.debug -- per Build überschreibbar

local function format(prefix: string, fmt: string, ...): string
	if select("#", ...) == 0 then return prefix .. fmt end
	local ok, s = pcall(string.format, fmt, ...)
	return prefix .. (ok and s or fmt)
end

function Logger.scope(name: string)
	local prefix = string.format("[%s] ", name)
	return {
		debug = function(fmt, ...) if CURRENT <= LEVELS.debug then print(format(prefix, fmt, ...)) end end,
		info  = function(fmt, ...) if CURRENT <= LEVELS.info  then print(format(prefix, fmt, ...)) end end,
		warn  = function(fmt, ...) if CURRENT <= LEVELS.warn  then warn(format(prefix, fmt, ...))  end end,
		error = function(fmt, ...) error(format(prefix, fmt, ...), 2) end,
	}
end

function Logger.setLevel(level: string)
	local n = LEVELS[level]
	if n then CURRENT = n end
end

return Logger
