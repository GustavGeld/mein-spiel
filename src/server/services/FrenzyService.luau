--!strict
-- FrenzyService — Random "Pack Frenzy" event: all packs cost 50% for 10 min.
-- Interval: 2–4 hours. Announces via Broadcast + OnFrenzyEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Frenzy")
local Net = require(Shared.remotes.Net)

local FRENZY_DURATION = 10 * 60     -- 10 minutes
local DISCOUNT        = 0.5         -- 50% off
local MIN_INTERVAL    = 120 * 60    -- 2 hours
local MAX_INTERVAL    = 240 * 60    -- 4 hours

local frenzyEndsAt = 0
local frenzyEvent  = Net:Event("OnFrenzyEvent")

local FrenzyService = {}

function FrenzyService.isActive(): boolean
	return os.time() < frenzyEndsAt
end

function FrenzyService.getDiscount(): number
	if os.time() < frenzyEndsAt then
		return DISCOUNT
	end
	return 0
end

function FrenzyService.getPriceMultiplier(): number
	if os.time() < frenzyEndsAt then
		return 1 - DISCOUNT
	end
	return 1
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

local function startFrenzy()
	frenzyEndsAt = os.time() + FRENZY_DURATION
	Logger.info("Pack Frenzy started! Ends at %d", frenzyEndsAt)

	frenzyEvent:FireAllClients({
		active = true,
		endsAt = frenzyEndsAt,
		discount = DISCOUNT,
	})
	broadcast("🔥 PACK FRENZY: All packs 50% OFF for 10 minutes!")

	task.spawn(function()
		task.wait(FRENZY_DURATION)
		frenzyEvent:FireAllClients({ active = false })
		broadcast("🔥 Pack Frenzy is over — prices back to normal.")
		Logger.info("Pack Frenzy ended.")
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		frenzyEvent:FireClient(player, {
			active = os.time() < frenzyEndsAt,
			endsAt = frenzyEndsAt,
			discount = DISCOUNT,
		})
	end)
end)

task.spawn(function()
	task.wait(180)
	local rng = Random.new(os.time() + 2)
	while true do
		local wait = rng:NextInteger(MIN_INTERVAL, MAX_INTERVAL)
		task.wait(wait)
		startFrenzy()
		task.wait(FRENZY_DURATION + 10)
	end
end)

Logger.info("FrenzyService online (interval=%d-%d min).", MIN_INTERVAL // 60, MAX_INTERVAL // 60)

return FrenzyService
