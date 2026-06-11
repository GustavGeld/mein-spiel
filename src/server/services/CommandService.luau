--!strict
-- CommandService — Test-/Admin-Chatbefehle.
--   /money 1000          → +1000  (Shortcut für /money add 1000)
--   /money add 1000      → +1000
--   /money add -500      → -500
--   /money set 250000    → setzt absolut
--   Aliase:  /givemoney, /cash
--
-- In Studio immer aktiv. Im Live-Spiel nur für UserIds in ADMINS.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Command")

local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CommandService = {}

-- UserIds, die Chatbefehle außerhalb von Studio nutzen dürfen.
local ADMINS: { [number]: boolean } = {
	-- [123456789] = true,
}

local DEFAULT_MONEY = 1000

local function canUse(player: Player): boolean
	if RunService:IsStudio() then return true end
	return ADMINS[player.UserId] == true
end

-- Setzt Gold direkt auf einen absoluten Wert.
local function setGold(player: Player, value: number)
	value = math.max(0, math.floor(value))
	PlayerDataService.update(player, function(profile)
		profile.currencies.gold = value
	end)
	PlayerDataService.patchEconomy(player)
end

local function handleMoney(player: Player, rest: string)
	local sub, valueStr = rest:match("^(%a+)%s+(-?%d+)$")
	if sub == "set" then
		local n = tonumber(valueStr)
		if not n then return end
		setGold(player, n)
		Logger.info("%s set money = %d", player.Name, math.floor(n))
		return
	elseif sub == "add" then
		local n = tonumber(valueStr)
		if not n then return end
		EconomyService.add(player, "gold", math.floor(n))
		Logger.info("%s added %d money", player.Name, math.floor(n))
		return
	end

	-- Fallback: nackte Zahl = add
	local n = tonumber(rest) or DEFAULT_MONEY
	n = math.floor(n)
	if n == 0 then return end
	EconomyService.add(player, "gold", n)
	Logger.info("%s added %d money", player.Name, n)
end

-- ─── Inventar-Befehle ────────────────────────────────────────────────────────
--   /inv clear              → leert alle Götter (und Temple-Slots)
--   /inv delete <rarity>    → entfernt alle Götter dieser Seltenheit
--   /inv delete all         → wie clear
--   /inv count              → zeigt aktuelle Anzahl Götter
--
-- Gamepass-Befehle (Studio-only):
--   /pass <flag>            → toggle einzelnen Pass (z.B. /pass autoRoll)
--   /pass clear             → ALLE Pässe entfernen (für Kauf-Tests)
--   /pass list              → zeigt aktive Pässe im Output
local function clearTempleSlots(profile)
	for _, slot in ipairs(profile.temple.slots) do
		slot.godUid = nil
	end
end

local function clearAllGods(player: Player)
	PlayerDataService.update(player, function(profile)
		profile.inventory.gods = {}
		clearTempleSlots(profile)
	end)
	PlayerDataService.patchInventory(player)
	PlayerDataService.patchTemple(player)
end

local function deleteByRarity(player: Player, rarityId: string)
	rarityId = rarityId:lower()
	local removedUids: { [string]: boolean } = {}
	PlayerDataService.update(player, function(profile)
		local keep = {}
		for _, entry in ipairs(profile.inventory.gods) do
			if entry.rarityId:lower() == rarityId then
				removedUids[entry.uid] = true
			else
				table.insert(keep, entry)
			end
		end
		profile.inventory.gods = keep
		-- Temple-Slots, die auf entfernte UIDs verweisen, frei machen.
		for _, slot in ipairs(profile.temple.slots) do
			if slot.godUid and removedUids[slot.godUid] then
				slot.godUid = nil
			end
		end
	end)
	PlayerDataService.patchInventory(player)
	PlayerDataService.patchTemple(player)
end

local function handleInv(player: Player, rest: string)
	local sub, arg = rest:match("^(%S+)%s*(.*)$")
	sub = sub and sub:lower() or ""
	if sub == "clear" or (sub == "delete" and (arg == "all" or arg == "")) then
		clearAllGods(player)
		Logger.info("%s cleared inventory", player.Name)
	elseif sub == "delete" then
		deleteByRarity(player, arg)
		Logger.info("%s deleted rarity '%s'", player.Name, arg)
	elseif sub == "count" then
		local profile = PlayerDataService.get(player)
		if profile then
			Logger.info("%s has %d gods", player.Name, #profile.inventory.gods)
		end
	end
end

-- ─── Gamepass-Befehle (Studio-only via canUse) ───────────────────────────────
--   /pass <flag>            → toggle einzelnen Pass an/aus
--   /pass clear             → ALLE Pässe entfernen (für Kauf-Tests)
--   /pass list              → zeigt aktive Pässe im Output
local function handlePass(player: Player, rest: string)
	local typed = rest:match("^(%S+)") or ""
	if typed == "" then return end
	local Net = require(Shared.remotes.Net)

	-- /pass clear → alle Pässe zurücksetzen
	if typed == "clear" then
		PlayerDataService.update(player, function(p)
			p.unlocks.gamepasses = {}
			-- extraSlots-Effekt rückgängig: Tempel auf 3 Slots trimmen
			while #p.temple.slots > 3 do table.remove(p.temple.slots, #p.temple.slots) end
		end)
		PlayerDataService.patchTemple(player)
		pcall(function()
			local profile = PlayerDataService.get(player)
			if profile then
				Net:Event("OnGamepassUpdate"):FireClient(player, profile.unlocks.gamepasses)
			end
		end)
		Logger.info("%s [/pass clear] all gamepasses removed", player.Name)
		return
	end

	-- /pass list → aktive Pässe loggen
	if typed == "list" then
		local profile = PlayerDataService.get(player)
		if profile then
			local active = {}
			for k, v in pairs(profile.unlocks.gamepasses) do
				if v then table.insert(active, k) end
			end
			Logger.info("%s active passes: %s", player.Name,
				#active > 0 and table.concat(active, ", ") or "(none)")
		end
		return
	end

	-- /pass <flag> → einzelnen Pass togglen
	local Gamepasses = require(Shared.config.Gamepasses)
	local flag: string? = nil
	for f in pairs(Gamepasses.byFlag) do
		if f:lower() == typed then flag = f; break end
	end
	if not flag then
		Logger.info("%s [/pass] unknown flag '%s'", player.Name, typed)
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local current = profile.unlocks.gamepasses[flag] == true
	PlayerDataService.update(player, function(p)
		p.unlocks.gamepasses[flag] = not current
	end)
	-- extraSlots: Tempel-Größe anpassen
	if flag == "extraSlots" then
		PlayerDataService.update(player, function(p)
			if not current then
				for _ = 1, 3 do table.insert(p.temple.slots, { godUid = nil }) end
			else
				while #p.temple.slots > 3 do table.remove(p.temple.slots, #p.temple.slots) end
			end
		end)
		PlayerDataService.patchTemple(player)
	end
	pcall(function()
		profile = PlayerDataService.get(player)
		if profile then
			Net:Event("OnGamepassUpdate"):FireClient(player, profile.unlocks.gamepasses)
		end
	end)
	Logger.info("%s [/pass] %s → %s", player.Name, flag, tostring(not current))
end

-- ─── Event-Befehle ──────────────────────────────────────────────────────────
--   /event start <id> <minutes>   → startet ein Event
--   /event stop                   → beendet aktives Event
--   /event list                   → zeigt verfügbare Event-IDs
local function handleEvent(player: Player, rest: string)
	local LimitedEvents = require(Shared.config.LimitedEvents)
	local LimitedEventService = require(script.Parent.LimitedEventService)
	local sub, arg1, arg2 = rest:match("^(%S+)%s*(%S*)%s*(%S*)$")
	sub = sub and sub:lower() or ""

	if sub == "list" then
		local ids = {}
		for id in pairs(LimitedEvents) do table.insert(ids, id) end
		Logger.info("Available events: %s", table.concat(ids, ", "))
	elseif sub == "start" then
		local eventId = arg1 or ""
		local minutes = tonumber(arg2) or 60
		if LimitedEventService.startEvent(eventId, minutes * 60) then
			Logger.info("%s started event '%s' for %d min", player.Name, eventId, minutes)
		else
			Logger.warn("Unknown event id: '%s'", eventId)
		end
	elseif sub == "stop" then
		LimitedEventService.stopEvent()
		Logger.info("%s stopped event", player.Name)
	end
end

local function handle(player: Player, message: string)
	if not canUse(player) then return end
	local cmd, rest = message:lower():match("^/(%S+)%s*(.*)$")
	if not cmd then return end

	if cmd == "money" or cmd == "givemoney" or cmd == "cash" then
		handleMoney(player, rest)
	elseif cmd == "inv" or cmd == "inventory" then
		handleInv(player, rest)
	elseif cmd == "pass" or cmd == "gp" then
		handlePass(player, rest)
	elseif cmd == "event" then
		handleEvent(player, rest)
	end
end

local function onJoin(player: Player)
	player.Chatted:Connect(function(message)
		handle(player, message)
	end)
end

Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do
	onJoin(player)
end

Logger.info("CommandService online (studio=%s).", tostring(RunService:IsStudio()))

return CommandService
