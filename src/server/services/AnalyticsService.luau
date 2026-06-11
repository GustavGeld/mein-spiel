--!strict
-- AnalyticsService — lightweight server-side telemetry.
-- Aggregates events in memory and flushes to a DataStore every 5 minutes.
-- All data is anonymous (userId never stored — only aggregated counts).
--
-- Tracked events:
--   pack_opened        { packId }
--   rarity_rolled      { rarityId }
--   secret_pulled      {}
--   rebirth            { rebirths (new count) }
--   god_placed         {}
--   fusion_attempted   { inputs }
--   fusion_success     { rank }
--   potion_bought      { potionId }
--   code_redeemed      {}
--   referral_used      {}
--   vip_eject          {}
--   session_start      {}
--   session_end        { sessionLengthSec }

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Analytics")

local AnalyticsService = {}

local FLUSH_INTERVAL = 5 * 60   -- flush every 5 minutes
local DS_NAME        = "GodsOfFate_Analytics_v1"

-- In-memory event counters: eventType -> { [key]: count }
-- e.g. eventCounts["rarity_rolled"]["Epic"] = 42
local eventCounts: { [string]: { [string]: number } } = {}
local sessionStarts: { [number]: number } = {}  -- userId -> os.clock()

local function inc(event: string, key: string)
	if not eventCounts[event] then eventCounts[event] = {} end
	eventCounts[event][key] = (eventCounts[event][key] or 0) + 1
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function AnalyticsService.track(event: string, data: { [string]: any }?)
	local d = data or {}
	if event == "pack_opened" then
		inc("pack_opened", "pack_" .. tostring(d.packId or "?"))
	elseif event == "rarity_rolled" then
		inc("rarity_rolled", tostring(d.rarityId or "?"))
	elseif event == "secret_pulled" then
		inc("special", "secret_pulled")
	elseif event == "rebirth" then
		inc("rebirth", "total")
		-- bucket into ranges
		local n = d.rebirths or 0
		local bucket = if n < 5 then "1-4" elseif n < 25 then "5-24" elseif n < 100 then "25-99" else "100+"
		inc("rebirth_range", bucket)
	elseif event == "god_placed" then
		inc("temple", "god_placed")
	elseif event == "fusion_attempted" then
		inc("fusion", "attempted")
	elseif event == "fusion_success" then
		inc("fusion", "success")
		inc("fusion_rank", "rank_" .. tostring(d.rank or "?"))
	elseif event == "potion_bought" then
		inc("potion_bought", tostring(d.potionId or "?"))
	elseif event == "code_redeemed" then
		inc("special", "code_redeemed")
	elseif event == "referral_used" then
		inc("special", "referral_used")
	elseif event == "vip_eject" then
		inc("special", "vip_eject")
	elseif event == "session_start" then
		inc("sessions", "started")
	elseif event == "session_end" then
		inc("sessions", "ended")
		local secs = d.sessionLengthSec or 0
		local bucket = if secs < 120 then "<2m" elseif secs < 600 then "2-10m" elseif secs < 1800 then "10-30m" else "30m+"
		inc("session_length", bucket)
	end
end

-- ─── Session tracking ────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	sessionStarts[player.UserId] = os.clock()
	AnalyticsService.track("session_start", {})
end)

Players.PlayerRemoving:Connect(function(player)
	local start = sessionStarts[player.UserId]
	sessionStarts[player.UserId] = nil
	local secs = if start then math.floor(os.clock() - start) else 0
	AnalyticsService.track("session_end", { sessionLengthSec = secs })
end)

-- ─── Flush to DataStore ───────────────────────────────────────────────────────

local function flush()
	if RunService:IsStudio() then return end
	if next(eventCounts) == nil then return end

	-- Snapshot and clear
	local snapshot = eventCounts
	eventCounts = {}

	task.spawn(function()
		local today = os.date("!%Y-%m-%d") :: string
		local ok, err = pcall(function()
			DataStoreService:GetDataStore(DS_NAME):UpdateAsync("daily_" .. today, function(old: any)
				local data = old or {}
				for event, keys in pairs(snapshot) do
					data[event] = data[event] or {}
					for key, count in pairs(keys) do
						data[event][key] = (data[event][key] or 0) + count
					end
				end
				return data
			end)
		end)
		if not ok then
			Logger.warn("Analytics flush failed: %s", tostring(err))
		else
			Logger.info("Analytics flushed to DataStore (key: daily_%s).", today)
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		flush()
	end
end)

-- Flush on server close
game:BindToClose(function()
	flush()
	task.wait(2)
end)

Logger.info("AnalyticsService online (flush every %ds).", FLUSH_INTERVAL)

return AnalyticsService
