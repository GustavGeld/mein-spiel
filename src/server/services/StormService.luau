--!strict
-- StormService — Random "Gold Storm" event every 1–2 hours.
-- Lasts 3 minutes. During the storm every player online gets bonus gold
-- ticks (collected automatically). Announces via Broadcast + OnStormEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Storm")
local Net = require(Shared.remotes.Net)

local STORM_DURATION = 3 * 60       -- 3 minutes
local MIN_INTERVAL   = 60 * 60      -- 1 hour minimum between storms
local MAX_INTERVAL   = 120 * 60     -- 2 hours max
local GOLD_PER_TICK  = 500          -- base gold per 5s tick during storm
local TICK_INTERVAL  = 5

local stormEndsAt = 0
local stormEvent  = Net:Event("OnStormEvent")

local StormService = {}

function StormService.isActive(): boolean
	return os.time() < stormEndsAt
end

function StormService.getRemainingTime(): number
	return math.max(0, stormEndsAt - os.time())
end

function StormService.getGoldPerTick(): number
	return GOLD_PER_TICK
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

local function startStorm()
	stormEndsAt = os.time() + STORM_DURATION
	Logger.info("Gold Storm started! Ends at %d", stormEndsAt)

	stormEvent:FireAllClients({
		active = true,
		endsAt = stormEndsAt,
		goldPerTick = GOLD_PER_TICK,
	})
	broadcast("⛈ GOLD STORM: Collect bonus gold for 3 minutes!")

	-- Storm gold distribution loop
	task.spawn(function()
		local EconomyService = require(script.Parent.EconomyService) :: any
		while os.time() < stormEndsAt do
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					local profile = nil
					local pds = script.Parent:FindFirstChild("PlayerDataService")
					if pds then
						local PDS = require(pds) :: any
						profile = PDS.get(player)
					end
					if not profile then return end
					local rebirths = profile.lifetime.rebirths or 0
					local scaledGold = math.floor(GOLD_PER_TICK * (1 + rebirths * 0.1))
					EconomyService.add(player, "gold", scaledGold)
				end)
			end
			task.wait(TICK_INTERVAL)
		end

		stormEvent:FireAllClients({ active = false })
		broadcast("⛈ The Gold Storm has passed.")
		Logger.info("Gold Storm ended.")
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		stormEvent:FireClient(player, {
			active = os.time() < stormEndsAt,
			endsAt = stormEndsAt,
			goldPerTick = GOLD_PER_TICK,
		})
	end)
end)

task.spawn(function()
	task.wait(10)
	local rng = Random.new(os.time() + 1)
	while true do
		local wait = rng:NextInteger(MIN_INTERVAL, MAX_INTERVAL)
		task.wait(wait)
		startStorm()
		task.wait(STORM_DURATION + 10)
	end
end)

Logger.info("StormService online (interval=%d-%d min).", MIN_INTERVAL // 60, MAX_INTERVAL // 60)

return StormService
