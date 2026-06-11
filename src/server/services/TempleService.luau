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

-- ─── Temple upgrade costs (must match TemplePanel.luau) ──────────────────────
local UPGRADE_COSTS: { [string]: (lvl: number) -> number } = {
	production = function(lvl) return math.floor(500  * (1.5 ^ lvl)) end,
	faith      = function(lvl) return math.floor(300  * (1.5 ^ lvl)) end,
	slots      = function(lvl) return math.floor(2000 * (3   ^ lvl)) end,
}
local UPGRADE_MAX: { [string]: number } = {
	production = 20,
	faith      = 20,
	slots      = 3,
}

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

-- Faith upgrade multiplier: temple.upgrades.faith × +2% faith/s
local function faithUpgradeMul(profile): number
	return 1 + (profile.temple.upgrades and profile.temple.upgrades.faith or 0) * 0.02
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

-- Pending-Cap: max das N-fache der Pro-Tick-Produktion pro Slot.
-- 50 × Tick-Produktion = ca. 4 Min Produktion bei TICK_INTERVAL=5s.
local PENDING_TICK_MULTIPLIER = 50
-- Offline production: max 8 hours of accumulated production on rejoin.
local OFFLINE_MAX_SECONDS = 8 * 3600

-- Ein Tick: berechne Gold/Faith pro Slot.
-- Wenn autoCollect Gamepass: direkt zu currencies (alt).
-- Sonst: in temple.pending[slotIdx] anhäufen — Spieler muss zum Rahmen laufen.
local function tick(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	if #profile.temple.slots == 0 then return end

	local templeMul = templeMultiplier(profile)
	local prodMul   = divinityProductionMul(profile)
	local echoMul   = 1 + (profile.divinity.echoStacks or 0) * 0.10
	local goldMul   = EconomyService.getMultiplier(player, "gold")
	local faithMul  = EconomyService.getMultiplier(player, "faith")

	-- Produktions-Trank + Offering-Buff
	local potionProdMul   = 1
	local offeringProdMul = 1
	local potionS   = script.Parent:FindFirstChild("PotionService")
	local offeringS = script.Parent:FindFirstChild("OfferingService")
	if potionS   then local PS = require(potionS)   :: any; if PS.getMultiplier  then potionProdMul   = PS.getMultiplier(player, "prod") end end
	if offeringS then local OS = require(offeringS) :: any; if OS.getBonus       then offeringProdMul = 1 + OS.getBonus(player, "prod") end end
	local totalProdMul = potionProdMul * offeringProdMul

	local autoCollect = profile.unlocks.gamepasses["autoCollect"] == true

	-- Pro Slot berechnen
	local anyProduced = false
	local totalGold, totalFaith = 0, 0
	local pendingChanged = false

	PlayerDataService.update(player, function(p)
		if not p.temple.pending then p.temple.pending = {} end

		for slotIdx, slot in ipairs(p.temple.slots) do
			if slot.godUid then
				-- Gott finden
				local entry: any = nil
				for _, e in ipairs(p.inventory.gods) do
					if e.uid == slot.godUid then entry = e; break end
				end
				if entry then
					local def = Gods.byId[entry.id]
					if def then
						local fusionMul = 1 + (entry.fusionRank or 0) * 0.35
						local rarityMul = rarityMultiplier(entry.rarityId)
						local secretMul = entry.secret and 5 or 1
						local faithUMul = faithUpgradeMul(p)
						local g = def.baseProduction * rarityMul * fusionMul * templeMul * prodMul * echoMul * secretMul * goldMul  * totalProdMul
						local f = def.baseFaith      * rarityMul * fusionMul * templeMul * prodMul * echoMul * faithUMul * secretMul * faithMul * totalProdMul
						g = math.floor(g * TICK_INTERVAL)
						f = math.floor(f * TICK_INTERVAL)

						if autoCollect then
							totalGold  += g
							totalFaith += f
							anyProduced = true
						else
							local capGold  = g * PENDING_TICK_MULTIPLIER
							local capFaith = f * PENDING_TICK_MULTIPLIER
							local key = tostring(slotIdx)
							local bucket = p.temple.pending[key] or { gold = 0, faith = 0 }
							local o = math.floor(g * 0.02)
							local capOff = math.max(1, o) * PENDING_TICK_MULTIPLIER
							if g > 0 then
								bucket.gold  = math.min(capGold,  bucket.gold  + g)
							end
							if f > 0 then
								bucket.faith = math.min(capFaith, bucket.faith + f)
							end
							if o > 0 then
								bucket.offerings = math.min(capOff, (bucket.offerings or 0) + o)
							end
							p.temple.pending[key] = bucket
							pendingChanged = true
						end
					end
				end
			end
		end
	end)

	if autoCollect then
		if totalGold  > 0 then EconomyService.add(player, "gold",  totalGold)  end
		if totalFaith > 0 then EconomyService.add(player, "faith", totalFaith) end
	elseif pendingChanged then
		PlayerDataService.patchTemple(player)
	end
end

-- Sammelt pending Gold/Faith eines Slots ein.
local function collectTemple(player: Player, slotIndex: number?)
	if not RateLimit.consume(player, "CollectTemple", 30, 5) then
		return { ok = false, reason = "rate_limit" }
	end
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	if not profile.temple.pending then return { ok = false, gold = 0, faith = 0 } end

	local totalGold, totalFaith = 0, 0
	PlayerDataService.update(player, function(p)
		if not p.temple.pending then p.temple.pending = {} end
		if slotIndex then
			-- Nur einen Slot abräumen
			local key = tostring(slotIndex)
			local b = p.temple.pending[key]
			if b then
				totalGold  += b.gold
				totalFaith += b.faith
				p.temple.pending[key] = nil
			end
		else
			-- Alle Slots abräumen
			for key, b in pairs(p.temple.pending) do
				totalGold  += b.gold
				totalFaith += b.faith
				p.temple.pending[key] = nil
			end
		end
	end)

	local totalOfferings = 0
	PlayerDataService.update(player, function(p)
		if not p.temple.pending then return end
		if slotIndex then
			local key = tostring(slotIndex)
			local b = p.temple.pending[key]
			if b then totalOfferings += b.offerings or 0 end
		else
			for _, b in pairs(p.temple.pending) do
				totalOfferings += b.offerings or 0
			end
		end
	end)

	if totalGold      > 0 then EconomyService.add(player, "gold",      totalGold)      end
	if totalFaith     > 0 then EconomyService.add(player, "faith",     totalFaith)     end
	if totalOfferings > 0 then EconomyService.add(player, "offerings", totalOfferings) end
	PlayerDataService.patchTemple(player)

	return { ok = true, gold = totalGold, faith = totalFaith, offerings = totalOfferings }
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
	-- Quest-Progress (lazy)
	local QS = script.Parent:FindFirstChild("QuestService")
	if QS then (require(QS) :: any).onGodPlaced(player) end
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
Net:Function("CollectTemple").OnServerInvoke = collectTemple

-- ─── Offline Production (max 8h) ─────────────────────────────────────────────

function TempleService.grantOfflineProduction(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local lastLogin = profile.meta and profile.meta.lastLogin or 0
	if lastLogin <= 0 then return end

	local now = os.time()
	-- Archivist ability extends offline cap from 8h to 12h
	local offlineCap = OFFLINE_MAX_SECONDS
	local abilities = profile.companion and profile.companion.abilities or {}
	if abilities["archivist"] then offlineCap = 12 * 3600 end
	local offlineSec = math.min(now - lastLogin, offlineCap)
	if offlineSec < 60 then return end -- less than 1 min offline, skip

	local offlineTicks = math.floor(offlineSec / TICK_INTERVAL)
	if offlineTicks <= 0 then return end

	local templeMul  = templeMultiplier(profile)
	local prodMul    = divinityProductionMul(profile)
	local echoMul    = 1 + (profile.divinity.echoStacks or 0) * 0.10
	local faithUMul  = faithUpgradeMul(profile)

	local totalGold, totalFaith = 0, 0
	local entries = placedGodEntries(profile)
	for _, entry in ipairs(entries) do
		local def = Gods.byId[entry.id]
		if def then
			local fusionMul = 1 + (entry.fusionRank or 0) * 0.35
			local rarityMul = rarityMultiplier(entry.rarityId)
			local secretMul = entry.secret and 5 or 1
			local g = def.baseProduction * rarityMul * fusionMul * templeMul * prodMul * echoMul * secretMul
			local f = def.baseFaith      * rarityMul * fusionMul * templeMul * prodMul * echoMul * faithUMul * secretMul
			totalGold  += math.floor(g * TICK_INTERVAL) * offlineTicks
			totalFaith += math.floor(f * TICK_INTERVAL) * offlineTicks
		end
	end

	if totalGold > 0 then EconomyService.add(player, "gold", totalGold) end
	if totalFaith > 0 then EconomyService.add(player, "faith", totalFaith) end

	if totalGold > 0 or totalFaith > 0 then
		local Logger2 = require(Shared.utils.Logger).scope("Temple")
		Logger2.info("Offline production for %s: %d gold, %d faith (%d min offline).",
			player.Name, totalGold, totalFaith, math.floor(offlineSec / 60))
	end
end

-- ─── Offline production on join ──────────────────────────────────────────────

PlayerDataService.OnLoaded:Connect(function(player: Player, _profile: any)
	task.defer(function()
		TempleService.grantOfflineProduction(player)
	end)
end)

-- Catch-up: players who loaded before TempleService registered the listener
for _, player in ipairs(Players:GetPlayers()) do
	if PlayerDataService.get(player) then
		task.defer(TempleService.grantOfflineProduction, player)
	end
end

-- ─── Tick-Loop ───────────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(TICK_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(tick, player)
		end
	end
end)

-- ─── Temple Upgrade Remote ───────────────────────────────────────────────────

Net:Function("BuyTempleUpgrade").OnServerInvoke = function(player: Player, upgradeType: any)
	if type(upgradeType) ~= "string" then return { ok = false, reason = "bad_args" } end
	if not UPGRADE_COSTS[upgradeType] then return { ok = false, reason = "unknown" } end
	if not RateLimit.consume(player, "BuyTempleUpgrade", 5, 2) then
		return { ok = false, reason = "rate_limited" }
	end
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local currentLevel = (profile.temple.upgrades and profile.temple.upgrades[upgradeType]) or 0
	if currentLevel >= UPGRADE_MAX[upgradeType] then
		return { ok = false, reason = "max_level" }
	end

	local cost = UPGRADE_COSTS[upgradeType](currentLevel)
	if (profile.currencies.faith or 0) < cost then
		return { ok = false, reason = "not_enough_faith", cost = cost }
	end

	PlayerDataService.update(player, function(p)
		p.currencies.faith = (p.currencies.faith or 0) - cost
		if not p.temple.upgrades then p.temple.upgrades = { production = 0, slots = 0, faith = 0 } end
		p.temple.upgrades[upgradeType] = (p.temple.upgrades[upgradeType] or 0) + 1
		-- Slot upgrade physically adds a new slot
		if upgradeType == "slots" then
			table.insert(p.temple.slots, { godUid = nil })
		end
	end)

	PlayerDataService.patchEconomy(player)
	PlayerDataService.patchTemple(player)

	Logger.info("%s bought temple upgrade '%s' level %d (cost %d faith)",
		player.Name, upgradeType, currentLevel + 1, cost)
	return { ok = true, newLevel = currentLevel + 1 }
end

TempleService.tick = tick
TempleService.placeGod = placeGod
TempleService.removeGod = removeGod
TempleService.collectTemple = collectTemple

Logger.info("TempleService online (tick=%ds).", TICK_INTERVAL)

return TempleService
