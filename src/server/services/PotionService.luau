--!strict
-- PotionService
--   - BuyPotion(potionId): verbraucht Gems, aktiviert Potion sofort.
--   - Aktive Potions werden in-memory gehalten (nicht persistiert — 10 min Buffs).
--   - getMultiplier(player, effect) für EconomyService/TempleService.
--   - OnPotionUpdate: { [potionId]: expiresAt oder 0 wenn abgelaufen }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Potion")
local Net = require(Shared.remotes.Net)
local Potions = require(Shared.config.Potions)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local PotionService = {}

-- { [Player]: { [potionId]: expiresAt (os.time()) } }
local active: { [Player]: { [string]: number } } = {}

local potionEvent = Net:Event("OnPotionUpdate")

local function getActive(player: Player): { [string]: number }
	if not active[player] then active[player] = {} end
	return active[player]
end

-- Bereinigt abgelaufene Potions und gibt Snapshot zurück.
local function cleanAndSnapshot(player: Player): { [string]: number }
	local map = getActive(player)
	local now = os.time()
	local snap: { [string]: number } = {}
	for id, expires in pairs(map) do
		if expires > now then
			snap[id] = expires
		else
			map[id] = nil
		end
	end
	return snap
end

-- ─── Public API ──────────────────────────────────────────────────────────────

-- Prüft ob eine Potion aktiv ist.
function PotionService.isActive(player: Player, potionId: string): boolean
	local map = getActive(player)
	return (map[potionId] or 0) > os.time()
end

-- Multiplier für einen Effect (z.B. "gold", "luck", "prod").
function PotionService.getMultiplier(player: Player, effect: string): number
	if PotionService.isActive(player, effect) then
		local def = Potions.byId[effect]
		return def and def.multiplier or 1
	end
	return 1
end

-- Direkt aktivieren (z.B. nach Dev-Product-Kauf — luckPotion).
function PotionService.activate(player: Player, potionId: string)
	local def = Potions.byId[potionId]
	if not def then return end
	local map = getActive(player)
	local now = os.time()
	-- Stapeln: verbleibende Zeit addieren.
	local remaining = math.max(0, (map[potionId] or now) - now)
	map[potionId] = now + remaining + def.duration
	potionEvent:FireClient(player, cleanAndSnapshot(player))
	Logger.info("%s activated potion %s (expires in %ds)", player.Name, potionId, map[potionId] - now)
end

-- ─── Remote ──────────────────────────────────────────────────────────────────

Net:Function("BuyPotion").OnServerInvoke = function(player: Player, potionId: string)
	if type(potionId) ~= "string" then return { ok = false, reason = "bad_id" } end
	if not RateLimit.consume(player, "BuyPotion", 5, 10) then
		return { ok = false, reason = "rate_limit" }
	end

	local def = Potions.byId[potionId]
	if not def then return { ok = false, reason = "unknown_potion" } end

	if not EconomyService.can(player, "gems", def.gemsCost) then
		return { ok = false, reason = "not_enough_gems" }
	end

	-- Gems abziehen
	EconomyService.add(player, "gems", -def.gemsCost)
	-- Potion aktivieren
	PotionService.activate(player, potionId)

	return { ok = true }
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	active[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	active[player] = nil
end)

-- Sende alle 30s aktualisierte Snapshots an alle Spieler (damit Timer-UI stimmt).
task.spawn(function()
	while true do
		task.wait(30)
		for player in pairs(active) do
			local snap = cleanAndSnapshot(player)
			potionEvent:FireClient(player, snap)
		end
	end
end)

Logger.info("PotionService online (%d potions).", #Potions.list)

return PotionService
