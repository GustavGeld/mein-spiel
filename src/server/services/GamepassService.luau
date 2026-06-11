--!strict
-- GamepassService — Owner-Check + Purchase Listeners + ProcessReceipt für DevProducts.
--
-- Flow:
--   Client klickt "Buy" -> Net:Function("PromptGamepass"):InvokeServer(passId)
--   Server ruft MarketplaceService:PromptGamePassPurchase(player, robloxId)
--   Roblox feuert PromptGamePassPurchaseFinished(player, id, purchased)
--   Wenn purchased=true: profile.unlocks.gamepasses[flag] = true + Replikation
--
-- DevProducts laufen über ProcessReceipt (atomar, Roblox liefert das Receipt
-- so lange wieder bis wir PurchaseGranted zurückgeben).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Gamepass")
local Net = require(Shared.remotes.Net)

local Gamepasses = require(Shared.config.Gamepasses)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

local GamepassService = {}

local gamepassEvent = Net:Event("OnGamepassUpdate")

-- ─── Ownership Check (mit kurzem Cache) ───────────────────────────────────────

local OWNER_CACHE_TTL = 30 -- Sek
type CacheEntry = { owns: boolean, at: number }
local ownsCache: { [string]: CacheEntry } = {} -- key = userId..":"..passId

local function cacheKey(userId: number, passId: number)
	return tostring(userId) .. ":" .. tostring(passId)
end

local function ownsGamepass(userId: number, passId: number): boolean
	if passId <= 0 then return false end
	local k = cacheKey(userId, passId)
	local entry = ownsCache[k]
	local now = os.clock()
	if entry and (now - entry.at) < OWNER_CACHE_TTL then
		return entry.owns
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, passId)
	if not ok then
		Logger.warn("UserOwnsGamePassAsync failed for %d/%d: %s", userId, passId, tostring(owns))
		return entry and entry.owns or false
	end
	ownsCache[k] = { owns = owns, at = now }
	return owns
end

-- Side-Effects pro Flag, sobald der Pass „neu" gegrantet wird.
-- (Wird nur ausgeführt, wenn der Flag vorher nicht gesetzt war.)
local function applyFlagSideEffect(player: Player, flag: string)
	if flag == "extraSlots" then
		PlayerDataService.update(player, function(profile)
			-- +3 zusätzliche leere Slots
			for _ = 1, 3 do
				table.insert(profile.temple.slots, { godUid = nil })
			end
		end)
		if PlayerDataService.patchTemple then
			PlayerDataService.patchTemple(player)
		end
	end
end

-- Gegenstück: wird ausgeführt, wenn ein Pass entzogen wird (DEV-Toggle).
-- Bei extraSlots schrumpft der Tempel zurück auf 3 Slots; Götter in den
-- entfernten Slots bleiben im Inventar (sie waren nur referenziert).
local function revokeFlagSideEffect(player: Player, flag: string)
	if flag == "extraSlots" then
		PlayerDataService.update(player, function(profile)
			local slots = profile.temple.slots
			while #slots > 3 do
				table.remove(slots, #slots)
			end
		end)
		if PlayerDataService.patchTemple then
			PlayerDataService.patchTemple(player)
		end
	end
end

-- Setzt einen einzelnen Flag im Profil und repliziert.
local function grantFlag(player: Player, flag: string)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local already = profile.unlocks.gamepasses[flag] == true
	if not already then
		PlayerDataService.update(player, function(p)
			p.unlocks.gamepasses[flag] = true
		end)
		applyFlagSideEffect(player, flag)
	end
	-- Snapshot der gepatchten Pass-Liste replizieren
	profile = PlayerDataService.get(player)
	if profile then
		gamepassEvent:FireClient(player, profile.unlocks.gamepasses)
	end
end

-- Replizieren ohne Profil-Mutation (nach Refresh / Join).
local function pushSnapshot(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	gamepassEvent:FireClient(player, profile.unlocks.gamepasses)
end

-- ─── Beim Join: alle Gamepasses prüfen und Profil syncen ──────────────────────

local function refreshOwnerships(player: Player)
	for _, pass in ipairs(Gamepasses.list) do
		if pass.robloxId > 0 then
			local owns = ownsGamepass(player.UserId, pass.robloxId)
			if owns then
				local profile = PlayerDataService.get(player)
				if profile and not profile.unlocks.gamepasses[pass.flag] then
					grantFlag(player, pass.flag)
				end
			end
		end
	end
	pushSnapshot(player)
end

-- ─── PromptGamepass-Remote ────────────────────────────────────────────────────

Net:Function("PromptGamepass").OnServerInvoke = function(player: Player, passId)
	if type(passId) ~= "string" then return { ok = false, reason = "bad_args" } end
	local pass = Gamepasses.byFlag[passId]
	if not pass then return { ok = false, reason = "unknown" } end
	if pass.robloxId <= 0 then
		return { ok = false, reason = "not_configured" }
	end
	local profile = PlayerDataService.get(player)
	-- Bereits im Profil vorhanden? → nichts tun.
	if profile and profile.unlocks.gamepasses[pass.flag] then
		return { ok = true, already = true }
	end

	-- ─── Studio-Modus: Kauf simulieren ────────────────────────────────────────
	-- Der Place-Creator besitzt alle eigenen Passes via MarketplaceService → ownsGamepass
	-- gibt immer true zurück → würde sofort re-granten auch nach /pass clear.
	-- Stattdessen: direkter Grant + OnGamepassUpdate damit der Client sicher "Owned" sieht.
	if RunService:IsStudio() then
		task.wait(0.5) -- kurze Pause für visuelle Kaufsimulation
		grantFlag(player, pass.flag)
		-- Nochmals explizit feuern damit Client sicher das Event bekommt
		local updProfile = PlayerDataService.get(player)
		if updProfile then
			gamepassEvent:FireClient(player, updProfile.unlocks.gamepasses)
		end
		Logger.info("[Studio] Simulated purchase of %s for %s", pass.flag, player.Name)
		return { ok = true, purchased = true }
	end

	-- ─── Live-Modus ───────────────────────────────────────────────────────────
	-- Creator-Check: falls der Spieler den Pass bereits via Roblox besitzt,
	-- direkt granten statt den "bereits besessen"-Dialog zu zeigen.
	if ownsGamepass(player.UserId, pass.robloxId) then
		grantFlag(player, pass.flag)
		return { ok = true, already = true }
	end
	pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, pass.robloxId)
	return { ok = true, prompted = true }
end

-- ─── Debug / Studio-Only Remotes ──────────────────────────────────────────────
-- Erlaubt das An/Aus-Schalten gekaufter Pässe zum Testen. Nur in Studio.
Net:Function("DebugTogglePass").OnServerInvoke = function(player: Player, passId)
	if not RunService:IsStudio() then return { ok = false, reason = "studio_only" } end
	if type(passId) ~= "string" then return { ok = false, reason = "bad_args" } end
	local pass = Gamepasses.byFlag[passId]
	if not pass then return { ok = false, reason = "unknown" } end
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	local current = profile.unlocks.gamepasses[pass.flag] == true
	PlayerDataService.update(player, function(p)
		p.unlocks.gamepasses[pass.flag] = not current
	end)
	-- Side-Effects in passende Richtung anwenden.
	if not current then
		applyFlagSideEffect(player, pass.flag)
	else
		revokeFlagSideEffect(player, pass.flag)
	end
	profile = PlayerDataService.get(player)
	if profile then
		gamepassEvent:FireClient(player, profile.unlocks.gamepasses)
	end
	Logger.info("[DEV] %s toggled %s -> %s", player.Name, pass.flag, tostring(not current))
	return { ok = true, enabled = not current }
end

Net:Function("PromptDevProduct").OnServerInvoke = function(player: Player, productId)
	if type(productId) ~= "string" then return { ok = false, reason = "bad_args" } end
	local product = Gamepasses.productById[productId]
	if not product then return { ok = false, reason = "unknown" } end
	if product.robloxId <= 0 then
		return { ok = false, reason = "not_configured" }
	end
	pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, product.robloxId)
	return { ok = true, prompted = true }
end

-- ─── Gamepass-Purchase-Finished-Listener ──────────────────────────────────────

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then return end
	local pass = Gamepasses.byRobloxId[gamePassId]
	if not pass then
		Logger.warn("Unknown gamepass purchased: %d", gamePassId)
		return
	end
	ownsCache[cacheKey(player.UserId, gamePassId)] = { owns = true, at = os.clock() }
	grantFlag(player, pass.flag)
	Logger.info("%s purchased %s", player.Name, pass.id)
end)

-- ─── ProcessReceipt für DevProducts ───────────────────────────────────────────
-- WICHTIG: Roblox liefert ungranted Receipts erneut. Wir müssen idempotent sein.
-- Wir tracken processed receipts pro Profil-Sitzung.

local processedReceipts: { [string]: boolean } = {} -- in-memory; bei restart neue Lieferung möglich

local function applyGrant(player: Player, product)
	if product.grant.currency and product.grant.amount then
		EconomyService.add(player, product.grant.currency, product.grant.amount)
	end
	if product.grant.potion then
		PlayerDataService.update(player, function(profile)
			profile.inventory.potions[product.grant.potion] =
				(profile.inventory.potions[product.grant.potion] or 0) + 1
		end)
	end
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local key = string.format("%d:%s", receiptInfo.PlayerId, receiptInfo.PurchaseId)
	if processedReceipts[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = Gamepasses.productByRobloxId[receiptInfo.ProductId]
	if not product then
		Logger.warn("Unknown DevProduct purchased: %d", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(applyGrant, player, product)
	if not ok then
		Logger.warn("ProcessReceipt grant failed for %s/%s: %s", player.Name, product.id, tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	processedReceipts[key] = true
	-- Force-Save damit DataStore-Crash zwischen Grant + Save den Player nicht
	-- noch einmal grantet (Roblox liefert Receipt erst nach erfolgreichem Save).
	PlayerDataService.forceSave(player)
	Logger.info("%s claimed product %s", player.Name, product.id)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ─── Public API für andere Services ───────────────────────────────────────────

function GamepassService.has(player: Player, flag: string): boolean
	local profile = PlayerDataService.get(player)
	if not profile then return false end
	return profile.unlocks.gamepasses[flag] == true
end

GamepassService.refreshOwnerships = refreshOwnerships
GamepassService.pushSnapshot = pushSnapshot

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	-- Warte bis Profil geladen ist
	task.spawn(function()
		for _ = 1, 30 do
			if PlayerDataService.get(player) then break end
			task.wait(0.5)
		end
		if PlayerDataService.get(player) then
			refreshOwnerships(player)
		end
	end)
end)

-- Bereits verbundene Player (Hot-Reload)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		if PlayerDataService.get(player) then
			refreshOwnerships(player)
		end
	end)
end

Logger.info("GamepassService online (%d passes, %d products).", #Gamepasses.list, #Gamepasses.products)

return GamepassService
