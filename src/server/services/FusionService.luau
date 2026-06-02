--!strict
-- FusionService — verschmilzt 2..5 gleiche Götter.
--   Erfolg: erster Eintrag bekommt fusionRank+1, andere werden entfernt.
--   Fehlschlag (<5 eingesetzt): alle Eintrag verschwinden — bewusstes Risiko.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Fusion")
local Net = require(Shared.remotes.Net)
local Fusion = require(Shared.math.Fusion)
local Rarities = require(Shared.config.Rarities)

local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

-- Optional: BroadcastService für globale Notification bei hohen Rängen.
local function tryGetBroadcast()
	local s = script.Parent:FindFirstChild("BroadcastService")
	return s and require(s) or nil
end

local FusionService = {}

local rngs: { [Player]: Random } = {}
local function getRng(player: Player): Random
	local r = rngs[player]
	if not r then r = Random.new(os.clock() * 1e6 + player.UserId); rngs[player] = r end
	return r
end
Players.PlayerRemoving:Connect(function(p) rngs[p] = nil end)

-- Validiert, dass alle UIDs zum Spieler gehören, gleichen godId haben und nicht
-- gelockt/in Tempel-Slots sind.
local function validate(player: Player, uids: { string })
	local profile = PlayerDataService.get(player)
	if not profile then return nil, "no_profile" end
	if #uids < 2 or #uids > 5 then return nil, "bad_count" end

	-- Sammle Tempel-Slot-UIDs (eingesetzte Götter dürfen nicht fusioniert werden).
	local placed: { [string]: boolean } = {}
	for _, slot in ipairs(profile.temple.slots) do
		if slot.godUid then placed[slot.godUid] = true end
	end

	local first
	local entries: { any } = {}
	for _, uid in ipairs(uids) do
		local entry = InventoryService.findByUid(player, uid)
		if not entry then return nil, "not_owned" end
		if entry.locked then return nil, "locked" end
		if placed[uid] then return nil, "placed" end
		if not first then
			first = entry
		elseif entry.id ~= first.id then
			return nil, "mismatched_god"
		elseif entry.rarityId ~= first.rarityId then
			return nil, "mismatched_rarity"
		end
		table.insert(entries, entry)
	end
	return entries, nil
end

Net:Function("Fuse").OnServerInvoke = function(player: Player, uids: any)
	if type(uids) ~= "table" then return { ok = false, reason = "bad_args" } end
	if not RateLimit.consume(player, "Fuse", 4, 3) then return { ok = false, reason = "rate_limited" } end

	local entries, err = validate(player, uids)
	if not entries then return { ok = false, reason = err } end

	local count = #entries
	local chance = Fusion.successChance(count)
	local roll = getRng(player):NextNumber()
	local success = roll <= chance

	local survivor = entries[1]
	local survivorUid = survivor.uid

	PlayerDataService.update(player, function(p)
		-- Sammle UIDs in einem Set zum O(n)-Löschen
		local toRemove: { [string]: boolean } = {}
		for _, e in ipairs(entries) do toRemove[e.uid] = true end
		if success then
			toRemove[survivorUid] = false
		end
		-- Filter Inventar
		local keep = {}
		for _, e in ipairs(p.inventory.gods) do
			if not toRemove[e.uid] then
				if e.uid == survivorUid and success then
					e.fusionRank = (e.fusionRank or 0) + 1
				end
				table.insert(keep, e)
			end
		end
		p.inventory.gods = keep
	end)
	PlayerDataService.patchInventory(player)

	local newRank = success and (survivor.fusionRank + 1) or survivor.fusionRank
	Logger.info("%s fused %s ×%d → %s (rank %d, chance %.0f%%)",
		player.Name, survivor.id, count,
		success and "success" or "FAIL",
		newRank,
		chance * 100)

	-- Broadcast bei seltenen high-rank Fusionen
	if success and newRank >= 3 then
		local Bc = tryGetBroadcast()
		if Bc then
			local rdef = Rarities.byId[survivor.rarityId]
			Bc.fire({
				type = "fusion",
				player = player.Name,
				godId = survivor.id,
				rank = newRank,
				rarityColor = rdef and rdef.color or Color3.fromRGB(255, 255, 255),
			})
		end
	end

	return {
		ok = success,
		chance = chance,
		newRank = newRank,
		survivorUid = success and survivorUid or nil,
	}
end

Logger.info("FusionService online.")

return FusionService
