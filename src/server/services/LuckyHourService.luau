--!strict
-- LuckyHourService
--   - Triggert zufällige "Lucky Hour" Events (15 min, +25% Luck für alle).
--   - Intervall: 30–90 Minuten zwischen den Events.
--   - Feuert Broadcast + OnLuckyHour Event an alle Clients.
--   - getLuckBonus() → 0.25 wenn aktiv, sonst 0.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("LuckyHour")
local Net = require(Shared.remotes.Net)

local LUCKY_DURATION  = 15 * 60  -- 15 Minuten
local LUCK_BONUS      = 0.25     -- +25% Luck
local MIN_INTERVAL    = 30 * 60  -- Frühestens alle 30 min
local MAX_INTERVAL    = 90 * 60  -- Spätestens alle 90 min

local luckyHourEndsAt = 0
local luckyHourEvent  = Net:Event("OnLuckyHour")

local LuckyHourService = {}

function LuckyHourService.getLuckBonus(): number
	if os.time() < luckyHourEndsAt then
		return LUCK_BONUS
	end
	return 0
end

function LuckyHourService.isActive(): boolean
	return os.time() < luckyHourEndsAt
end

local function broadcast(msg: string)
	local bs = script.Parent:FindFirstChild("BroadcastService")
	if bs then
		local svc = require(bs) :: any
		if svc and svc.fire then
			svc.fire({ type = "system", message = msg })
		end
	end
end

local function startLuckyHour()
	luckyHourEndsAt = os.time() + LUCKY_DURATION
	Logger.info("Lucky Hour started! Ends at %d", luckyHourEndsAt)

	-- Alle Clients informieren
	luckyHourEvent:FireAllClients({
		active = true,
		endsAt = luckyHourEndsAt,
		bonus  = LUCK_BONUS,
	})
	broadcast("🍀 LUCKY HOUR: +25% Luck for 15 minutes!")
end

-- Sende beim Join den aktuellen State
Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		luckyHourEvent:FireClient(player, {
			active = os.time() < luckyHourEndsAt,
			endsAt = luckyHourEndsAt,
			bonus  = LUCK_BONUS,
		})
	end)
end)

-- Zufälliger Trigger-Loop
task.spawn(function()
	-- Kurze initiale Verzögerung damit Server vollständig gestartet ist
	task.wait(60)
	local rng = Random.new(os.time())
	while true do
		local wait = rng:NextInteger(MIN_INTERVAL, MAX_INTERVAL)
		task.wait(wait)
		startLuckyHour()
		task.wait(LUCKY_DURATION + 10) -- Puffer nach Ende
	end
end)

Logger.info("LuckyHourService online (interval=%d-%d min).", MIN_INTERVAL // 60, MAX_INTERVAL // 60)

return LuckyHourService
