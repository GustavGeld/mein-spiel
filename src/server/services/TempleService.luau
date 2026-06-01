--!strict
-- TempleService — Slot-Placement + Production-Tick.
-- Production-Formel (siehe GDD §3):
--   produced = baseProduction * rarityMult * fusionMult * (1 + templeLvl*0.05) * (1 + divinityProductionPct) * gamepass/multiplier
-- Faith analog mit baseFaith.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Temple")
local Net = require(Shared.remotes.Net)

local Gods = require(Shared.config.Gods)
local Rarities = require(Shared.config.Rarities)

local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local TempleService = {}

local TICK_INTERVAL = 5 -- Sekunden

-- Rarity-Multiplier: skaliert exponentiell mit Rarity-Index für sichtbaren Spike.
local function rarityMultiplier(rarityId: string): number
	local def = Rarities.byId[rarityId]
	if not def then return 1 end
	-- Index 1..55. Multiplier z.B. 1.18^(index-1) → Pack 10 ~ x150.
	return 1.18 ^ (def.index - 1)
end

local function templeMultiplier(profile): number
	return 1 + (profile.temple.tier - 1) * 0.05 + (profile.temple.upgrades.production or 0) * 0.02
end

local function divinityProductionMul(profile): number
	local asc = profile.divinity.tree.ascension
	local lvl = asc and asc.production or 0
	return 1 + lvl * 0.01
end

local function placedGodEntries(profile)
	local entries = {}
	for _, slot in ipairs(profile.temple.slots) do
		if slot.godUid then
			for _, entry in ipairs(profile.inventory.gods) do
				if entry.uid == slot.godUid then
					table.insert(entries, entry)
					break
				end
			end
		end
	end
	return entries
end

-- Ein Tick: berechne Gold/Faith aus allen platzierten Göttern und addiere.
local function tick(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local placed = placedGodEntries(profile)
	if #placed == 0 then return end

	local gold, faith = 0, 0
	local templeMul = templeMultiplier(profile)
	local prodMul = divinityProductionMul(profile)
	for _, entry in ipairs(placed) do
		local def = Gods.byId[entry.id]
		if def then
			local fusionMul = 1 + entry.fusionRank * 0.35
			local rarityMul = rarityMultiplier(entry.rarityId)
			local secretMul = entry.secret and 5 or 1
			gold += def.baseProduction * rarityMul * fusionMul * templeMul * prodMul * secretMul
			faith += def.baseFaith * rarityMul * fusionMul * templeMul * prodMul * secretMul
		end
	end

	local goldMul = EconomyService.getMultiplier(player, "gold")
	local faithMul = EconomyService.getMultiplier(player, "faith")

	gold = math.floor(gold * TICK_INTERVAL * goldMul)
	faith = math.floor(faith * TICK_INTERVAL * faithMul)

	if gold > 0 then EconomyService.add(player, "gold", gold) end
	if faith > 0 then EconomyService.add(player, "faith", faith) end
end

-- ─── Slot-Placement API ──────────────────────────────────────────────────────

local function placeGod(player: Player, slotIndex: number, godUid: string)
	if not RateLimit.consume(player, "PlaceGod", 5, 2) then return { error = "rate_limited" } end
	if type(slotIndex) ~= "number" or type(godUid) ~= "string" then return { error = "bad_args" } end
	local profile = PlayerDataService.get(player)
	if not profile then return { error = "no_profile" } end
	local slots = profile.temple.slots
	if slotIndex < 1 or slotIndex > #slots then return { error = "bad_slot" } end

	-- Owns the god? Not locked? Not already placed in another slot?
	local entry = InventoryService.findByUid(player, godUid)
	if not entry or entry.locked then return { error = "not_owned" } end
	for i, slot in ipairs(slots) do
		if slot.godUid == godUid then
			return { error = "already_placed" }
		end
	end

	PlayerDataService.update(player, function(p)
		p.temple.slots[slotIndex].godUid = godUid
	end)
	PlayerDataService.patchTemple(player)
	return { ok = true }
end

local function removeGod(player: Player, slotIndex: number)
	if not RateLimit.consume(player, "RemoveGod", 5, 2) then return { error = "rate_limited" } end
	local profile = PlayerDataService.get(player)
	if not profile then return { error = "no_profile" } end
	local slots = profile.temple.slots
	if slotIndex < 1 or slotIndex > #slots then return { error = "bad_slot" } end
	PlayerDataService.update(player, function(p)
		p.temple.slots[slotIndex].godUid = nil
	end)
	PlayerDataService.patchTemple(player)
	return { ok = true }
end

Net:Function("PlaceGod").OnServerInvoke = placeGod
Net:Function("RemoveGod").OnServerInvoke = removeGod

-- ─── Tick-Loop ───────────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(TICK_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(tick, player)
		end
	end
end)

TempleService.tick = tick
TempleService.placeGod = placeGod
TempleService.removeGod = removeGod

Logger.info("TempleService online (tick=%ds).", TICK_INTERVAL)

return TempleService
