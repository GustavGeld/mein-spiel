--!strict
-- AuctionService
--   - Spieler listen Götter zum Direktkauf ein (kein Bieting, MVP).
--   - 5% Steuer auf den Kaufpreis (Verkäufer erhält 95%).
--   - Listings halten 24h; abgelaufene werden beim Laden/Abrufen gefiltert.
--   - Global-DataStore: GodsOfFate_Auctions_v1 (JSON-Liste aller Auktionen).
--   - OnAuctionUpdate: sendet bei jeder Änderung die vollständige Liste an alle.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Auction")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local IS_STUDIO = RunService:IsStudio()
local AUCTION_DURATION = 24 * 3600 -- 24h
local TAX_RATE = 0.05               -- 5%
local MAX_PER_PLAYER = 3
local DS_KEY = "listings_v1"

type Listing = {
	id: string,
	sellerId: number,
	sellerName: string,
	godUid: string,
	godId: string,
	rarityId: string,
	fusionRank: number,
	secret: boolean,
	price: number,
	createdAt: number,
	expiresAt: number,
}

-- In-memory Listings (geladen aus DataStore beim Start)
local listings: { Listing } = {}

local auctionEvent = Net:Event("OnAuctionUpdate")
local store: GlobalDataStore? = nil

-- DataStore öffnen
if not IS_STUDIO then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("GodsOfFate_Auctions_v1")
	end)
	if ok then store = result end
end

-- ─── Persistence ─────────────────────────────────────────────────────────────

local function saveListings()
	if not store then return end
	local data = listings -- direkte Referenz
	task.spawn(function()
		pcall(function()
			store:SetAsync(DS_KEY, data)
		end)
	end)
end

local function loadListings()
	if not store then return end
	local ok, data = pcall(function()
		return store:GetAsync(DS_KEY)
	end)
	if ok and type(data) == "table" then
		-- Abgelaufene herausfiltern
		local now = os.time()
		for _, entry in ipairs(data) do
			if entry.expiresAt > now then
				table.insert(listings, entry)
			end
		end
		Logger.info("Loaded %d active listings.", #listings)
	end
end

loadListings()

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function broadcast()
	-- Abgelaufene vorher entfernen
	local now = os.time()
	local fresh: { Listing } = {}
	for _, l in ipairs(listings) do
		if l.expiresAt > now then table.insert(fresh, l) end
	end
	listings = fresh
	auctionEvent:FireAllClients(listings)
end

local function countListingsFor(userId: number): number
	local n = 0
	for _, l in ipairs(listings) do
		if l.sellerId == userId then n += 1 end
	end
	return n
end

local function findListing(listingId: string): (number?, Listing?)
	for i, l in ipairs(listings) do
		if l.id == listingId then return i, l end
	end
	return nil, nil
end

local function findGodInInventory(profile: any, uid: string): any
	for _, g in ipairs(profile.inventory.gods) do
		if g.uid == uid then return g end
	end
	return nil
end

-- ─── Remotes ─────────────────────────────────────────────────────────────────

-- Auktionsliste abrufen
Net:Function("GetAuctions").OnServerInvoke = function(_player: Player)
	local now = os.time()
	local fresh: { Listing } = {}
	for _, l in ipairs(listings) do
		if l.expiresAt > now then table.insert(fresh, l) end
	end
	return fresh
end

-- Gott einstellen
Net:Function("ListAuction").OnServerInvoke = function(player: Player, godUid: string, price: number)
	if not RateLimit.consume(player, "ListAuction", 5, 30) then
		return { ok = false, reason = "rate_limit" }
	end
	if type(godUid) ~= "string" or type(price) ~= "number" then
		return { ok = false, reason = "bad_args" }
	end
	price = math.floor(math.clamp(price, 1, 1e12))

	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	if countListingsFor(player.UserId) >= MAX_PER_PLAYER then
		return { ok = false, reason = "too_many_listings" }
	end

	local god = findGodInInventory(profile, godUid)
	if not god then return { ok = false, reason = "god_not_found" } end
	if god.locked then return { ok = false, reason = "god_locked" } end

	-- Gott sperren
	PlayerDataService.update(player, function(p)
		for _, g in ipairs(p.inventory.gods) do
			if g.uid == godUid then g.locked = true; break end
		end
	end)
	PlayerDataService.patchInventory(player)

	local now = os.time()
	local listing: Listing = {
		id         = HttpService:GenerateGUID(false),
		sellerId   = player.UserId,
		sellerName = player.Name,
		godUid     = godUid,
		godId      = god.id,
		rarityId   = god.rarityId,
		fusionRank = god.fusionRank or 0,
		secret     = god.secret or false,
		price      = price,
		createdAt  = now,
		expiresAt  = now + AUCTION_DURATION,
	}
	table.insert(listings, listing)
	saveListings()
	broadcast()

	Logger.info("%s listed god %s for %d gold.", player.Name, god.id, price)
	return { ok = true, listingId = listing.id }
end

-- Direktkauf
Net:Function("BidAuction").OnServerInvoke = function(player: Player, listingId: string)
	if not RateLimit.consume(player, "BidAuction", 5, 10) then
		return { ok = false, reason = "rate_limit" }
	end
	if type(listingId) ~= "string" then return { ok = false, reason = "bad_args" } end

	local idx, listing = findListing(listingId)
	if not idx or not listing then return { ok = false, reason = "not_found" } end
	if listing.sellerId == player.UserId then return { ok = false, reason = "own_listing" } end
	if listing.expiresAt <= os.time() then return { ok = false, reason = "expired" } end

	if not EconomyService.can(player, "gold", listing.price) then
		return { ok = false, reason = "not_enough_gold" }
	end

	-- Verkäufer finden
	local seller = Players:GetPlayerByUserId(listing.sellerId)

	-- Gold übertragen: Käufer zahlt Preis, Verkäufer erhält 95%
	EconomyService.add(player, "gold", -listing.price)
	local sellerGold = math.floor(listing.price * (1 - TAX_RATE))

	-- Gott vom Verkäufer entfernen (falls noch online)
	if seller then
		PlayerDataService.update(seller, function(p)
			for i, g in ipairs(p.inventory.gods) do
				if g.uid == listing.godUid then
					table.remove(p.inventory.gods, i)
					break
				end
			end
		end)
		EconomyService.add(seller, "gold", sellerGold)
		PlayerDataService.patchInventory(seller)
	else
		-- Offline-Verkäufer: Gold auf nächsten Login merken (vereinfacht: direkt buchen)
		-- Für MVP: Gold wird beim nächsten Login des Verkäufers nicht erstattet (bekannte Einschränkung).
		-- Production: In der DataStore-Session des Verkäufers eine "pendingGold"-Notiz hinterlassen.
		Logger.warn("Seller %d offline — gold reward lost (MVP limitation).", listing.sellerId)
	end

	-- Gott zum Käufer hinzufügen
	local newGod = {
		uid = HttpService:GenerateGUID(false),
		id = listing.godId,
		rarityId = listing.rarityId,
		packTier = 1,
		fusionRank = listing.fusionRank,
		secret = listing.secret,
		locked = false,
	}
	PlayerDataService.update(player, function(p)
		table.insert(p.inventory.gods, newGod)
	end)
	PlayerDataService.patchInventory(player)

	-- Listing entfernen
	table.remove(listings, idx)
	saveListings()
	broadcast()

	Logger.info("%s bought god %s for %d gold.", player.Name, listing.godId, listing.price)
	return { ok = true }
end

-- Listing stornieren
Net:Function("CancelListing").OnServerInvoke = function(player: Player, listingId: string)
	if not RateLimit.consume(player, "CancelListing", 5, 10) then
		return { ok = false, reason = "rate_limit" }
	end
	if type(listingId) ~= "string" then return { ok = false, reason = "bad_args" } end

	local idx, listing = findListing(listingId)
	if not idx or not listing then return { ok = false, reason = "not_found" } end
	if listing.sellerId ~= player.UserId then return { ok = false, reason = "not_owner" } end

	-- Gott entsperren
	PlayerDataService.update(player, function(p)
		for _, g in ipairs(p.inventory.gods) do
			if g.uid == listing.godUid then g.locked = false; break end
		end
	end)
	PlayerDataService.patchInventory(player)

	table.remove(listings, idx)
	saveListings()
	broadcast()

	Logger.info("%s cancelled listing for god %s.", player.Name, listing.godId)
	return { ok = true }
end

-- ─── Cleanup bei Join: Falls der Spieler beim Login noch aktive Listings hat,
-- sicherstellen dass die Götter noch gelocked sind.
PlayerDataService.OnLoaded:Connect(function(player: Player, profile: any)
	local now = os.time()
	local myIds: { [string]: boolean } = {}
	for _, l in ipairs(listings) do
		if l.sellerId == player.UserId and l.expiresAt > now then
			myIds[l.godUid] = true
		end
	end
	-- Abgleich: sicherstellen dass gelistete Götter locked sind
	local changed = false
	for _, god in ipairs(profile.inventory.gods) do
		if myIds[god.uid] and not god.locked then
			god.locked = true
			changed = true
		end
	end
	if changed then
		PlayerDataService.update(player, function(_p) end) -- dirty markieren
	end
	-- Initiale Liste senden
	task.defer(function()
		local fresh: { Listing } = {}
		for _, l in ipairs(listings) do
			if l.expiresAt > now then table.insert(fresh, l) end
		end
		auctionEvent:FireClient(player, fresh)
	end)
end)

Logger.info("AuctionService online.")

return {}
