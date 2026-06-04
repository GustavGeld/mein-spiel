--!strict
-- AchievementService
--   - Berechnet Achievement-Progress zur Claim-Zeit aus Profil-Feldern.
--   - ClaimAchievement(achievementId): prüft + vergibt Gems.
--   - checkAndGrantAll(player): automatisch nach wichtigen Events (Pull, Rebirth, Fusion).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Achievement")
local Net = require(Shared.remotes.Net)
local Achievements = require(Shared.config.Achievements)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local achievementEvent = Net:Event("OnAchievementUpdate")

local AchievementService = {}

-- Progress aus Profil berechnen (ohne separate Counter).
local function getProgress(profile: any, def: any): number
	if def.type == "pulls"        then return profile.lifetime.pulls or 0
	elseif def.type == "rebirths" then return profile.lifetime.rebirths or 0
	elseif def.type == "lifetime_gold" then return profile.lifetime.gold or 0
	elseif def.type == "collection" then
		local count = 0
		for _ in pairs(profile.collection.discovered or {}) do count += 1 end
		return count
	elseif def.type == "fusion_rank" then
		-- Höchster fusionRank im aktuellen Inventar
		local maxRank = 0
		for _, god in ipairs(profile.inventory.gods or {}) do
			if (god.fusionRank or 0) > maxRank then maxRank = god.fusionRank end
		end
		return maxRank
	elseif def.type == "secrets" then
		local count = 0
		for _, god in ipairs(profile.inventory.gods or {}) do
			if god.secret then count += 1 end
		end
		-- Auch Collection berücksichtigen: zähle Secrets dort
		for id in pairs(profile.collection.discovered or {}) do
			if id:find("secret") or id:find("Secret") then count += 1 end
		end
		return count
	end
	return 0
end

-- Alle erreichbaren aber ungeforderten Achievements finden.
function AchievementService.getPending(player: Player): { string }
	local profile = PlayerDataService.get(player)
	if not profile then return {} end
	local claimed = profile.achievements and profile.achievements.claimed or {}
	local out = {}
	for _, def in ipairs(Achievements.list) do
		if not claimed[def.id] then
			local prog = getProgress(profile, def)
			if prog >= def.target then
				table.insert(out, def.id)
			end
		end
	end
	return out
end

-- Snapshot für Client: alle Achievements mit Progress + Claimed-Status.
local function makeSnapshot(profile: any): { [string]: any }
	local claimed = profile.achievements and profile.achievements.claimed or {}
	local snap: { [string]: any } = {}
	for _, def in ipairs(Achievements.list) do
		snap[def.id] = {
			progress = getProgress(profile, def),
			claimed  = claimed[def.id] == true,
			target   = def.target,
		}
	end
	return snap
end

-- Nach Ereignissen automatisch prüfen + unverzüglich patchen.
function AchievementService.checkAndNotify(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local snap = makeSnapshot(profile)
	achievementEvent:FireClient(player, snap)
end

-- ─── Remote ──────────────────────────────────────────────────────────────────

Net:Function("ClaimAchievement").OnServerInvoke = function(player: Player, achievementId: string)
	if type(achievementId) ~= "string" then return { ok = false } end
	if not RateLimit.consume(player, "ClaimAchievement", 10, 30) then
		return { ok = false, reason = "rate_limit" }
	end

	local def = Achievements.byId[achievementId]
	if not def then return { ok = false, reason = "unknown" } end

	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local claimed = profile.achievements and profile.achievements.claimed or {}
	if claimed[achievementId] then
		return { ok = false, reason = "already_claimed" }
	end

	local progress = getProgress(profile, def)
	if progress < def.target then
		return { ok = false, reason = "not_complete", progress = progress }
	end

	-- Reward gewähren
	PlayerDataService.update(player, function(p)
		if not p.achievements then p.achievements = { claimed = {} } end
		if not p.achievements.claimed then p.achievements.claimed = {} end
		p.achievements.claimed[achievementId] = true
	end)
	EconomyService.add(player, "gems", def.gems)

	-- Update ans Client
	local updatedProfile = PlayerDataService.get(player)
	if updatedProfile then
		achievementEvent:FireClient(player, makeSnapshot(updatedProfile))
	end

	Logger.info("%s claimed achievement %s (+%d gems)", player.Name, achievementId, def.gems)
	return { ok = true, gems = def.gems }
end

-- Initial senden
PlayerDataService.OnLoaded:Connect(function(player: Player, profile: any)
	task.defer(function()
		local p = PlayerDataService.get(player)
		if p then
			achievementEvent:FireClient(player, makeSnapshot(p))
		end
	end)
end)

Logger.info("AchievementService online (%d achievements).", #Achievements.list)

return AchievementService
