--!strict
-- AutoRollController — Client-Loop, der bei aktivem Auto-Roll regelmäßig
-- BuyPack(packId, 1) ruft. RollController überspringt das Reveal-Popup,
-- solange autoMode == true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)

local RollController = require(script.Parent.RollController)

local AutoRollController = {}

local activePackId: number? = nil
local INTERVAL = 1.2  -- Sekunden zwischen Auto-Buys (Server-RateLimit ist 6/3s).

-- Gate: Auto-Roll ist nur nutzbar, wenn der zugehörige Gamepass gekauft wurde.
local enabled = false

local listeners: { (packId: number?, enabled: boolean) -> () } = {}
local function notify()
	for _, cb in ipairs(listeners) do cb(activePackId, enabled) end
end

function AutoRollController.onChange(cb: (packId: number?, enabled: boolean) -> ())
	table.insert(listeners, cb)
end

function AutoRollController.activePackId(): number?
	return activePackId
end

function AutoRollController.isActive(): boolean
	return activePackId ~= nil
end

function AutoRollController.isEnabled(): boolean
	return enabled
end

function AutoRollController.setEnabled(v: boolean)
	if enabled == v then return end
	enabled = v
	-- Bei Deaktivierung laufenden Loop stoppen.
	if not enabled and activePackId ~= nil then
		activePackId = nil
		RollController.setAutoMode(false)
	end
	notify()
end

function AutoRollController.stop()
	if activePackId == nil then return end
	activePackId = nil
	RollController.setAutoMode(false)
	notify()
end

function AutoRollController.start(packId: number)
	if not enabled then return end
	if activePackId == packId then return end
	activePackId = packId
	RollController.setAutoMode(true)
	notify()

	-- Loop läuft, solange activePackId == packId.
	task.spawn(function()
		while activePackId == packId do
			local result
			local ok = pcall(function()
				result = Net:Function("BuyPack"):InvokeServer(packId, 1)
			end)
			-- Bei Geldmangel oder Lock automatisch stoppen.
			if not ok or not result or (result.error and result.error ~= "rate_limited") then
				AutoRollController.stop()
				break
			end
			task.wait(INTERVAL)
		end
	end)
end

function AutoRollController.toggle(packId: number): boolean
	if activePackId == packId then
		AutoRollController.stop()
		return true
	end
	if not enabled then return false end
	AutoRollController.start(packId)
	return true
end

return AutoRollController
