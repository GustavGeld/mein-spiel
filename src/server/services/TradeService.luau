--!strict
-- TradeService — Spieler-zu-Spieler Trading mit Hold-Accept Flow.
--
-- Lifecycle einer Session:
--   1. Spieler A klickt auf B in der Trade-Liste → SendTradeRequest(B)
--      Server prüft: B online, B.tradeInvites=true, kein bestehender Trade von B
--      Server schickt B eine Trade-Invite (OnTradeUpdate type=invite)
--   2. B antwortet via RespondTrade(true|false)
--      Bei true: Session wird erstellt, beide sehen TradeUpdate type=open
--   3. Beide bauen ihr Angebot mit OfferItem(uid) / RemoveOffer(uid).
--      Server lockt jeden uid (entry.locked=true), repliziert Inventar an Owner.
--   4. Beide drücken HoldAccept(true). Wenn beide gleichzeitig 5s halten →
--      atomarer Swap der Inventar-Einträge. Loslassen vor Ablauf = reset.
--   5. Cancel: jederzeit ein Spieler oder Disconnect → unlock + Session-Ende.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Trade")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local TradeService = {}

local CONFIRM_WINDOW = 5.0  -- Sekunden: Confirm bleibt nach Klick aktiv

type Side = {
	player: Player,
	offer: { [string]: boolean }, -- uid -> true
	confirmed: boolean,
	confirmedAt: number,
	confirmToken: number,         -- inkrementiert, um veraltete Timeouts zu erkennen
}

type Session = {
	id: string,
	a: Side,
	b: Side,
	state: "open" | "completed" | "cancelled",
	createdAt: number,
}

-- ─── Globaler State ──────────────────────────────────────────────────────────
local invites: { [Player]: { from: Player, at: number } } = {}
local sessionsByPlayer: { [Player]: Session } = {}

local tradeEvent = Net:Event("OnTradeUpdate")

local function makeSide(player: Player): Side
	return {
		player = player,
		offer = {},
		confirmed = false,
		confirmedAt = 0,
		confirmToken = 0,
	}
end

local function otherSide(session: Session, player: Player): Side?
	if session.a.player == player then return session.b
	elseif session.b.player == player then return session.a
	else return nil end
end

local function mySide(session: Session, player: Player): Side?
	if session.a.player == player then return session.a
	elseif session.b.player == player then return session.b
	else return nil end
end

-- Liefert ein Item-Detail-Array: pro UID den God-Eintrag aus dem Profil.
-- So sieht der andere Spieler immer den echten God (id/rarity/fusionRank),
-- nicht nur einen kryptischen UID-String.
local function offerDetails(side: Side): { any }
	local profile = PlayerDataService.get(side.player)
	if not profile then return {} end
	local lookup: { [string]: any } = {}
	for _, e in ipairs(profile.inventory.gods) do
		lookup[e.uid] = e
	end
	local out = {}
	for uid in pairs(side.offer) do
		local e = lookup[uid]
		if e then
			table.insert(out, {
				uid = e.uid,
				id = e.id,
				rarityId = e.rarityId,
				packTier = e.packTier,
				fusionRank = e.fusionRank,
				secret = e.secret,
			})
		end
	end
	return out
end

local function snapshotFor(session: Session, player: Player)
	local me = mySide(session, player)
	local other = otherSide(session, player)
	if not me or not other then return nil end
	return {
		type = "session",
		sessionId = session.id,
		state = session.state,
		otherName = other.player.Name,
		otherUserId = other.player.UserId,
		myOffer = offerDetails(me),
		theirOffer = offerDetails(other),
		myConfirmed = me.confirmed,
		theirConfirmed = other.confirmed,
		confirmWindow = CONFIRM_WINDOW,
	}
end

local function pushSession(session: Session)
	for _, side in ipairs({ session.a, session.b }) do
		local snap = snapshotFor(session, side.player)
		if snap then
			tradeEvent:FireClient(side.player, snap)
		end
	end
end

-- ─── Inventar-Lock Hilfsfunktionen ────────────────────────────────────────────

local function lockGod(player: Player, uid: string, locked: boolean): boolean
	local ok = false
	PlayerDataService.update(player, function(profile)
		for _, entry in ipairs(profile.inventory.gods) do
			if entry.uid == uid then
				entry.locked = locked
				ok = true
				return
			end
		end
	end)
	if ok then PlayerDataService.patchInventory(player) end
	return ok
end

local function findGod(player: Player, uid: string)
	local profile = PlayerDataService.get(player)
	if not profile then return nil end
	for _, entry in ipairs(profile.inventory.gods) do
		if entry.uid == uid then return entry end
	end
	return nil
end

-- Hebt alle Locks eines Side-Offers wieder auf.
local function releaseOffer(side: Side)
	for uid in pairs(side.offer) do
		lockGod(side.player, uid, false)
	end
	table.clear(side.offer)
end

-- ─── Session Verwaltung ──────────────────────────────────────────────────────

local function endSession(session: Session, state: "completed" | "cancelled")
	session.state = state
	if state == "cancelled" then
		releaseOffer(session.a)
		releaseOffer(session.b)
	end
	-- Final-Update mit Endzustand
	for _, side in ipairs({ session.a, session.b }) do
		tradeEvent:FireClient(side.player, {
			type = "end",
			sessionId = session.id,
			state = state,
		})
		sessionsByPlayer[side.player] = nil
	end
end

local function cancelSessionFor(player: Player)
	local session = sessionsByPlayer[player]
	if session then endSession(session, "cancelled") end
end

-- ─── Atomarer Swap ────────────────────────────────────────────────────────────
-- Entfernt die Einträge der einen Seite und fügt sie der anderen hinzu.

local function performSwap(session: Session): boolean
	-- 1) Beide Profile abrufen
	local profileA = PlayerDataService.get(session.a.player)
	local profileB = PlayerDataService.get(session.b.player)
	if not profileA or not profileB then return false end

	-- 2) Sammeln: pro Seite die zu transferierenden Entries (Deep-Copy)
	local function collect(profile, offer: { [string]: boolean }): { any }
		local out, keep = {}, {}
		for _, entry in ipairs(profile.inventory.gods) do
			if offer[entry.uid] then
				-- Lock zurücksetzen vor Transfer
				entry.locked = false
				table.insert(out, entry)
			else
				table.insert(keep, entry)
			end
		end
		profile.inventory.gods = keep
		return out
	end

	-- 3) Erst entfernen, dann hinzufügen — atomar im selben update.
	PlayerDataService.update(session.a.player, function(p)
		local taken = collect(p, session.a.offer)
		-- Nach kompletter Entfernung von A, fügen wir B's Items zu A hinzu.
		local fromB = collect(profileB, session.b.offer)
		for _, e in ipairs(fromB) do
			table.insert(p.inventory.gods, e)
			p.collection.discovered[e.id] = true
		end
		-- Speicher A's Items als „outbound" für den B-Update
		session.a._outbound = taken
	end)

	PlayerDataService.update(session.b.player, function(p)
		-- p ist hier bereits ohne B's Items (wir haben sie oben in profileB entfernt
		-- via collect(profileB, ...), das auf das gleiche Profil-Objekt zeigt).
		for _, e in ipairs(session.a._outbound or {}) do
			table.insert(p.inventory.gods, e)
			p.collection.discovered[e.id] = true
		end
	end)

	PlayerDataService.patchInventory(session.a.player)
	PlayerDataService.patchInventory(session.b.player)
	return true
end

-- Reset beide Confirms (z.B. bei Offer-Änderung).
local function resetConfirms(session: Session)
	session.a.confirmed = false; session.a.confirmToken += 1
	session.b.confirmed = false; session.b.confirmToken += 1
end

-- Prüft ob beide Seiten gerade confirmed sind → swap.
local function tryComplete(session: Session): boolean
	if session.state ~= "open" then return false end
	if not (session.a.confirmed and session.b.confirmed) then return false end
	if performSwap(session) then
		endSession(session, "completed")
		Logger.info("Trade completed: %s <-> %s", session.a.player.Name, session.b.player.Name)
		return true
	end
	endSession(session, "cancelled")
	return false
end

-- Setzt eine Seite auf confirmed=true und startet einen 5s-Timeout, der den
-- Confirm wieder zurücksetzt, falls die andere Seite nicht ebenfalls bestätigt.
local function setConfirmed(session: Session, side: Side, confirmed: boolean)
	if confirmed == side.confirmed then return end
	side.confirmed = confirmed
	side.confirmToken += 1
	local token = side.confirmToken
	if confirmed then
		side.confirmedAt = os.clock()
		task.delay(CONFIRM_WINDOW, function()
			-- Nur zurücksetzen wenn unser Confirm-Token noch dasselbe ist
			-- und Session noch offen ist.
			if session.state ~= "open" then return end
			if side.confirmToken ~= token then return end
			side.confirmed = false
			pushSession(session)
		end)
	end
end

-- ─── Remote Endpoints ────────────────────────────────────────────────────────

Net:Function("SendTradeRequest").OnServerInvoke = function(player: Player, targetUserId)
	if type(targetUserId) ~= "number" then return { ok = false, reason = "bad_args" } end
	if sessionsByPlayer[player] then return { ok = false, reason = "in_session" } end
	if not RateLimit.consume(player, "TradeReq", 3, 5) then
		return { ok = false, reason = "rate_limited" }
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then return { ok = false, reason = "no_target" } end
	if sessionsByPlayer[target] then return { ok = false, reason = "target_busy" } end
	local targetProfile = PlayerDataService.get(target)
	if not targetProfile or targetProfile.settings.tradeInvites == false then
		return { ok = false, reason = "invites_off" }
	end
	-- Bestehende Invite überschreiben (max 1 in Flight pro Empfänger).
	invites[target] = { from = player, at = os.clock() }
	tradeEvent:FireClient(target, {
		type = "invite",
		fromName = player.Name,
		fromUserId = player.UserId,
	})
	return { ok = true }
end

-- RespondTrade dient drei Use-Cases:
--   1) In aktiver Session + accept=false  → Session canceln
--   2) Offene Invite vorhanden + accept=true  → neue Session erstellen
--   3) Offene Invite vorhanden + accept=false → Invite verwerfen
Net:Function("RespondTrade").OnServerInvoke = function(player: Player, accept)
	-- Case 1: bereits in Session → false = Cancel
	if sessionsByPlayer[player] then
		if not accept then
			cancelSessionFor(player)
			return { ok = true, cancelled = true }
		end
		return { ok = false, reason = "already_in_session" }
	end
	local invite = invites[player]
	if not invite then return { ok = false, reason = "no_invite" } end
	invites[player] = nil
	if not accept then
		tradeEvent:FireClient(invite.from, { type = "invite_declined", byName = player.Name })
		return { ok = true, accepted = false }
	end
	local other = invite.from
	if not other.Parent or sessionsByPlayer[other] then
		return { ok = false, reason = "stale" }
	end
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		a = makeSide(other),
		b = makeSide(player),
		state = "open",
		createdAt = os.clock(),
	}
	sessionsByPlayer[other] = session
	sessionsByPlayer[player] = session
	pushSession(session)
	startHoldWatcher(session)
	return { ok = true, accepted = true, sessionId = session.id }
end

Net:Function("OfferItem").OnServerInvoke = function(player: Player, uid)
	if type(uid) ~= "string" then return { ok = false, reason = "bad_args" } end
	local session = sessionsByPlayer[player]
	if not session or session.state ~= "open" then return { ok = false, reason = "no_session" } end
	local me = mySide(session, player)
	if not me then return { ok = false, reason = "not_in_session" } end
	-- Max 10 items pro Angebot.
	local n = 0; for _ in pairs(me.offer) do n += 1 end
	if n >= 10 then return { ok = false, reason = "max_items" } end
	-- Eintrag muss existieren und nicht locked sein.
	local entry = findGod(player, uid)
	if not entry then return { ok = false, reason = "not_owned" } end
	if entry.locked and not me.offer[uid] then return { ok = false, reason = "locked" } end
	-- Bei jeder Offer-Änderung beide Confirms verwerfen.
	resetConfirms(session)
	me.offer[uid] = true
	lockGod(player, uid, true)
	pushSession(session)
	return { ok = true }
end

Net:Function("RemoveOffer").OnServerInvoke = function(player: Player, uid)
	if type(uid) ~= "string" then return { ok = false, reason = "bad_args" } end
	local session = sessionsByPlayer[player]
	if not session or session.state ~= "open" then return { ok = false, reason = "no_session" } end
	local me = mySide(session, player)
	if not me then return { ok = false, reason = "not_in_session" } end
	if me.offer[uid] then
		me.offer[uid] = nil
		lockGod(player, uid, false)
	end
	resetConfirms(session)
	pushSession(session)
	return { ok = true }
end

-- Neuer Confirm-Endpoint: Click-once-and-stay-for-5s.
-- HoldAccept bleibt als Alias erhalten, falls Altclients noch im Spiel sind.
local function handleConfirm(player: Player, confirm)
	local session = sessionsByPlayer[player]
	if not session or session.state ~= "open" then return { ok = false, reason = "no_session" } end
	local me = mySide(session, player)
	if not me then return { ok = false, reason = "not_in_session" } end
	-- mind. 1 Item insgesamt — sonst wäre Confirm sinnlos
	local total = 0
	for _ in pairs(session.a.offer) do total += 1 end
	for _ in pairs(session.b.offer) do total += 1 end
	if total == 0 and confirm then return { ok = false, reason = "empty_offer" } end
	setConfirmed(session, me, confirm == true)
	pushSession(session)
	if tryComplete(session) then return { ok = true, completed = true } end
	return { ok = true, confirmed = me.confirmed }
end
Net:Function("HoldAccept").OnServerInvoke = handleConfirm

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

Players.PlayerRemoving:Connect(function(player)
	invites[player] = nil
	-- alle ausgehenden Invites zu diesem Spieler zurücksetzen
	for target, inv in pairs(invites) do
		if inv.from == player then invites[target] = nil end
	end
	cancelSessionFor(player)
end)

TradeService.HOLD_DURATION = HOLD_DURATION
Logger.info("TradeService online (hold=%.1fs).", HOLD_DURATION)

return TradeService
