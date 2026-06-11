--!strict
-- PackService — Kauft Packs (verbraucht Gold), öffnet sie und liefert Pull-Ergebnis.
-- Komplett server-authoritativ. Client schickt nur Intents.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Pack")
local Net = require(Shared.remotes.Net)

local Packs = require(Shared.config.Packs)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)
local Odds = require(Shared.math.Odds)

local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

-- Lazy-Require: QuestService kann sein, dass es noch nicht geladen ist beim
-- ersten require. Wir fragen jedes Mal frisch ab.
local function tryGetQuestService()
	local sib = script.Parent:FindFirstChild("QuestService")
	return sib and require(sib) or nil
end

local function tryGetBroadcast()
	local sib = script.Parent:FindFirstChild("BroadcastService")
	return sib and require(sib) or nil
end

local function tryGetAnalytics()
	local sib = script.Parent:FindFirstChild("AnalyticsService")
	return sib and require(sib) or nil
end

local PackService = {}

-- Pro Spieler eigener kryptographisch initialisierter RNG.
local rngs: { [Player]: Random } = {}
local function getRng(player: Player): Random
	local r = rngs[player]
	if not r then
		r = Random.new(os.clock() * 1e6 + player.UserId)
		rngs[player] = r
	end
	return r
end

Players.PlayerRemoving:Connect(function(p) rngs[p] = nil end)

-- Pack-Preis: linear, Pack-spezifisch. FrenzyService discount applied if active.
local function priceFor(packId: number): number
	local pack = Packs.byId[packId]
	if not pack then return math.huge end
	local base = pack.basePriceGold
	local frenzyS = script.Parent:FindFirstChild("FrenzyService")
	if frenzyS then
		local FS = require(frenzyS) :: any
		if FS and FS.getPriceMultiplier then
			base = math.floor(base * FS.getPriceMultiplier())
		end
	end
	return base
end

-- Pack unlock check.
-- Gold-Unlock ist lenient: sobald aktuelles ODER jemals erreichtes Gold die Schwelle
-- erreicht, ist der Pack permanent freigeschaltet (Profile-Flag wird beim Kauf gesetzt).
local function checkUnlock(profile, packId: number): (boolean, string?)
	local pack = Packs.byId[packId]
	if not pack then return false, "Unknown pack" end
	if pack.unlock.robux then
		return false, "robux_only"
	end
	-- Bereits einmal gekauft → bleibt offen.
	if profile.unlocks.packs[tostring(packId)] then
		if pack.unlock.rebirths and profile.lifetime.rebirths < pack.unlock.rebirths then
			return false, "rebirths"
		end
		return true
	end
	if pack.unlock.gold then
		local reach = math.max(profile.lifetime.gold, profile.currencies.gold)
		if reach < pack.unlock.gold then
			return false, "gold_lifetime"
		end
	end
	if pack.unlock.rebirths and profile.lifetime.rebirths < pack.unlock.rebirths then
		return false, "rebirths"
	end
	return true
end

-- Wendet Pull-Ergebnis ans Profil an: Inventory-Eintrag + Collection-Book + Lifetime-Stat.
-- Liefert (uid, godId) zurück, damit der Caller die Icon-Asset-ID im Result mitschicken kann.
local function applyPull(player: Player, packId: number, rarityId: string, isSecret: boolean): (string, string)
	-- Quest-Progress (lazy gelöst, kein Hard-Dependency)
	local QuestService = tryGetQuestService()
	if QuestService then
		QuestService.onPull(player, rarityId, isSecret)
	end

	-- Analytics
	do
		local Analytics = tryGetAnalytics()
		if Analytics then
			Analytics.track("pack_opened", { packId = packId })
			Analytics.track("rarity_rolled", { rarityId = rarityId })
			if isSecret then Analytics.track("secret_pulled", {}) end
		end
	end

	-- Broadcast bei Secret oder bestem Pack-Tier
	do
		local Bc = tryGetBroadcast()
		if Bc then
			local pack = Packs.byId[packId]
			local bestRarityInPack = pack and pack.rarities[#pack.rarities]
			local rdef = Rarities.byId[rarityId]
			if isSecret then
				Bc.fire({
					type = "secret", player = player.Name, godId = rarityId,
					rarityId = rarityId, rarityColor = rdef and rdef.color or Color3.fromRGB(255, 255, 255),
				})
			elseif rarityId == bestRarityInPack then
				Bc.fire({
					type = "rare_pull", player = player.Name, godId = rarityId,
					rarityId = rarityId, rarityColor = rdef and rdef.color or Color3.fromRGB(255, 255, 255),
				})
			end
		end
	end
	local godPool = Gods.byRarity[rarityId]
	local godDef = godPool and godPool[getRng(player):NextInteger(1, #godPool)] or nil
	local godId = godDef and godDef.id or rarityId
	local uid = HttpService:GenerateGUID(false)
	PlayerDataService.update(player, function(profile)
		local entry = {
			uid = uid,
			id = godId,
			rarityId = rarityId,
			packTier = Packs.byId[packId].id,
			fusionRank = 0,
			secret = isSecret,
			locked = false,
		}
		table.insert(profile.inventory.gods, entry)
		profile.collection.discovered[entry.id] = true
		profile.lifetime.pulls += 1
		-- Rarest tracked anhand des globalen Rarity-Index.
		local def = Rarities.byId[rarityId]
		if def and def.index > profile.lifetime.rarestRarity then
			profile.lifetime.rarestRarity = def.index
		end
	end)
	PlayerDataService.patchInventory(player)
	return uid, godId
end

-- Öffnet `count` Packs. Liefert Liste von Pull-Resultaten (mit Preview für UI).
local function openPacks(player: Player, packId: number, count: number)
	local profile = PlayerDataService.get(player)
	if not profile then return nil end
	local rng = getRng(player)
	local luckMul = EconomyService.getLuckMultiplier and EconomyService.getLuckMultiplier(player) or 1
	local results = table.create(count)
	for i = 1, count do
		local result = Odds.roll(packId, rng, profile.pity, luckMul, 1)
		local uid, godId = applyPull(player, packId, result.rarityId, result.isSecret)
		results[i] = {
			uid = uid,
			godId = godId,
			rarityId = result.rarityId,
			isSecret = result.isSecret,
			preview = result.preview,
			packId = packId,
		}
	end
	return results
end

local pullEvent = Net:Event("OnPullResult")

-- Public: Kauf + Open in einem Schritt (häufigster Flow).
local function buyAndOpen(player: Player, packId: number, count: number)
	if type(packId) ~= "number" or type(count) ~= "number" then return nil end
	if count < 1 then return nil end
	if not RateLimit.consume(player, "BuyPack", 6, 3) then
		return { error = "rate_limited" }
	end

	local profile = PlayerDataService.get(player)
	if not profile then return nil end

	-- Multi-Open Gamepass erlaubt bis 50 Packs auf einmal, sonst max 10.
	local maxBatch = profile.unlocks.gamepasses["multiOpen"] and 50 or 10
	if count > maxBatch then
		return { error = "batch_too_large", max = maxBatch }
	end

	local unlocked, reason = checkUnlock(profile, packId)
	if not unlocked then
		return { error = "locked", reason = reason }
	end

	local unitPrice = priceFor(packId)
	local totalCost = unitPrice * count
	if not EconomyService.transact(player, "gold", totalCost) then
		return { error = "not_enough_gold" }
	end
	do
		local QuestService = tryGetQuestService()
		if QuestService then QuestService.onGoldSpent(player, totalCost) end
	end

	-- Unlock-Flag setzen sobald Pack einmal gekauft wurde
	PlayerDataService.update(player, function(p)
		p.unlocks.packs[tostring(packId)] = true
	end)

	local results = openPacks(player, packId, count)
	if not results then
		return { error = "internal" }
	end

	-- Replikation: einzelnes Result-Event mit Preview-Liste, Client baut Animation.
	pullEvent:FireClient(player, { packId = packId, results = results })

	return { ok = true, count = #results }
end

Net:Function("BuyPack").OnServerInvoke = buyAndOpen
Net:Function("OpenPack").OnServerInvoke = buyAndOpen

PackService.buyAndOpen = buyAndOpen
PackService.priceFor = priceFor
PackService.openPacks = openPacks  -- für ClaimFreeRoll

Logger.info("PackService online.")

return PackService
