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

-- Pack-Preis: linear, Pack-spezifisch. Bei Bedarf später `priceCurveMul` einbeziehen.
local function priceFor(packId: number): number
	local pack = Packs.byId[packId]
	return pack and pack.basePriceGold or math.huge
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
local function applyPull(player: Player, packId: number, rarityId: string, isSecret: boolean): string
	local godPool = Gods.byRarity[rarityId]
	local godDef = godPool and godPool[getRng(player):NextInteger(1, #godPool)] or nil
	local uid = HttpService:GenerateGUID(false)
	PlayerDataService.update(player, function(profile)
		local entry = {
			uid = uid,
			id = godDef and godDef.id or rarityId,
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
	return uid
end

-- Öffnet `count` Packs. Liefert Liste von Pull-Resultaten (mit Preview für UI).
local function openPacks(player: Player, packId: number, count: number)
	local profile = PlayerDataService.get(player)
	if not profile then return nil end
	local rng = getRng(player)
	local results = table.create(count)
	for i = 1, count do
		local result = Odds.roll(packId, rng, profile.pity, 1, 1)
		local uid = applyPull(player, packId, result.rarityId, result.isSecret)
		results[i] = {
			uid = uid,
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
	if count < 1 or count > 50 then return nil end
	if not RateLimit.consume(player, "BuyPack", 6, 3) then
		return { error = "rate_limited" }
	end

	local profile = PlayerDataService.get(player)
	if not profile then return nil end

	local unlocked, reason = checkUnlock(profile, packId)
	if not unlocked then
		return { error = "locked", reason = reason }
	end

	local unitPrice = priceFor(packId)
	local totalCost = unitPrice * count
	if not EconomyService.transact(player, "gold", totalCost) then
		return { error = "not_enough_gold" }
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

Logger.info("PackService online.")

return PackService
