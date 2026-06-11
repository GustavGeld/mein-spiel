--!strict
-- LimitedEventService — manages limited-time seasonal events.
-- Activated via admin command: /event start <id> <durationMinutes>
-- When active: fires OnEventUpdate to all clients, applies pack discount in priceFor().
-- BuyEventPack remote: deducts gold at event price, opens packs from the event tier.

local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared        = ReplicatedStorage:WaitForChild("Shared")
local Logger        = require(Shared.utils.Logger).scope("LimitedEvent")
local Net           = require(Shared.remotes.Net)
local LimitedEvents = require(Shared.config.LimitedEvents)
local EventGods     = require(Shared.config.EventGods)
local RateLimit     = require(script.Parent.Parent.security.RateLimit)

local PlayerDataService = require(script.Parent.PlayerDataService)

local LimitedEventService = {}

local activeEvent: string? = nil
local eventEndsAt: number  = 0

local eventStore: DataStore? = nil
pcall(function()
	eventStore = DataStoreService:GetDataStore("GodsOfFate_Events")
end)

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function eventPayload(id: string, endsAt: number): any
	local def = LimitedEvents[id]
	if not def then return nil end
	return {
		id      = def.id,
		nameKey = def.nameKey,
		descKey = def.descKey,
		color   = { def.color.R, def.color.G, def.color.B },
		pack    = def.pack,
		endsAt  = endsAt,
	}
end

local function broadcastAll()
	local id, endsAt = LimitedEventService.getActive()
	local data = id and eventPayload(id, endsAt) or nil
	Net:Event("OnEventUpdate"):FireAllClients(data)
end

local function persist()
	if not eventStore then return end
	pcall(function()
		if activeEvent then
			eventStore:SetAsync("active_event_v1", { id = activeEvent, endsAt = eventEndsAt })
		else
			eventStore:RemoveAsync("active_event_v1")
		end
	end)
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function LimitedEventService.getActive(): (string?, number)
	if activeEvent and os.time() >= eventEndsAt then
		activeEvent = nil
		eventEndsAt = 0
	end
	return activeEvent, eventEndsAt
end

function LimitedEventService.startEvent(eventId: string, durationSeconds: number): boolean
	if not LimitedEvents[eventId] then
		Logger.warn("Unknown event: %s", eventId)
		return false
	end
	activeEvent = eventId
	eventEndsAt = os.time() + durationSeconds
	Logger.info("Event started: %s for %ds", eventId, durationSeconds)
	persist()
	broadcastAll()
	return true
end

function LimitedEventService.stopEvent()
	activeEvent = nil
	eventEndsAt = 0
	persist()
	broadcastAll()
	Logger.info("Event stopped.")
end

-- Price multiplier for event pack (used to show discounted price in ShopPanel)
function LimitedEventService.getEventDiscount(): number
	local id = LimitedEventService.getActive()
	if not id then return 1 end
	local def = LimitedEvents[id]
	return def and (1 - def.pack.discountPct) or 1
end

-- ─── Remotes ─────────────────────────────────────────────────────────────────

Net:Function("GetActiveEvent").OnServerInvoke = function(_player: Player)
	local id, endsAt = LimitedEventService.getActive()
	return id and eventPayload(id, endsAt) or nil
end

Net:Function("BuyEventPack").OnServerInvoke = function(player: Player)
	if not RateLimit.consume(player, "BuyEventPack", 5, 10) then
		return { ok = false, reason = "rate_limit" }
	end
	local id = LimitedEventService.getActive()
	if not id then return { ok = false, reason = "no_event" } end
	local def = LimitedEvents[id]
	if not def then return { ok = false, reason = "invalid" } end

	local EconomyService = require(script.Parent.EconomyService)
	local packPrice = def.pack.priceGold
	if not EconomyService.transact(player, "gold", packPrice) then
		return { ok = false, reason = "not_enough_gold" }
	end

	local PackService = require(script.Parent.PackService)
	local results = PackService.openPacks(player, def.pack.tier, def.pack.pullCount)
	if not results then
		-- Refund on failure
		EconomyService.add(player, "gold", packPrice)
		return { ok = false, reason = "internal" }
	end

	-- Event-exclusive god bonus (35% chance per event pack purchase)
	local eventPool = EventGods[id]
	if eventPool and #eventPool > 0 then
		local rng = Random.new(os.clock() * 1e6 + player.UserId)
		if rng:NextNumber() <= 0.35 then
			local picked = eventPool[rng:NextInteger(1, #eventPool)]
			local uid = tostring(os.time()) .. tostring(player.UserId) .. "evt"
			local eEntry = {
				uid        = uid,
				id         = picked.id,
				rarityId   = picked.rarityId,
				packTier   = def.pack.tier,
				fusionRank = 0,
				secret     = false,
				locked     = false,
			}
			PlayerDataService.update(player, function(p)
				table.insert(p.inventory.gods, eEntry)
			end)
			PlayerDataService.patchInventory(player)
			table.insert(results, {
				uid        = uid,
				id         = picked.id,
				rarityId   = picked.rarityId,
				packTier   = def.pack.tier,
				fusionRank = 0,
				secret     = false,
				isEventGod = true,
			})
		end
	end

	Net:Event("OnPullResult"):FireClient(player, { packId = def.pack.tier, results = results })
	return { ok = true, count = #results }
end

-- ─── Send event to newly joined players ──────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	task.wait(1.5)
	local id, endsAt = LimitedEventService.getActive()
	Net:Event("OnEventUpdate"):FireClient(player, id and eventPayload(id, endsAt) or nil)
end)

-- ─── Periodic expiry check ───────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(60)
		if activeEvent and os.time() >= eventEndsAt then
			Logger.info("Event expired: %s", tostring(activeEvent))
			LimitedEventService.stopEvent()
		end
	end
end)

-- ─── Restore persisted event on startup ──────────────────────────────────────

task.spawn(function()
	if not eventStore then return end
	local ok, data = pcall(function() return eventStore:GetAsync("active_event_v1") end)
	if ok and type(data) == "table" and data.id and os.time() < (data.endsAt or 0) then
		activeEvent = data.id
		eventEndsAt = data.endsAt
		Logger.info("Resumed event: %s (ends in %ds)", data.id, eventEndsAt - os.time())
		task.wait(2) -- let clients connect first
		broadcastAll()
	end
end)

Logger.info("LimitedEventService online.")
return LimitedEventService
