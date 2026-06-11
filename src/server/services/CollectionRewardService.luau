--!strict
-- CollectionRewardService — Rewards for completing rarity sets in the Collection Book.
-- When a player discovers all gods of a rarity, they can claim a gem reward.
-- Claimed rows are stored in profile.collection.claimedRows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("CollectionReward")
local Net = require(Shared.remotes.Net)
local Gods = require(Shared.config.Gods)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local CollectionRewardService = {}

-- Build rarity → god count map
local godCountByRarity: { [string]: number } = {}
for _, def in ipairs(Gods.list) do
	godCountByRarity[def.rarityId] = (godCountByRarity[def.rarityId] or 0) + 1
end

-- Rewards per rarity tier (based on how many rarities deep)
-- Pack 1 rarities: 10 gems each, Pack 2: 25 each, etc.
local RARITY_REWARD_GEMS: { [string]: number } = {}
local packRarities = {
	{ "Common", "Uncommon", "Rare", "Epic", "Unique" },
	{ "Elite", "Heroic", "RisingStar", "Legendary", "Mythic" },
	{ "Immortal", "DemiGod", "Valkyrie", "God", "Goddess" },
	{ "Ascended", "Ancient", "HighTier", "Cosmic", "Celestial" },
	{ "Astral", "Nebula", "Galaxy", "Universe", "Archon" },
	{ "Chrono", "Temporal", "Dimensional", "Spatial", "Divine" },
	{ "Luminary", "Seraphim", "Sacred", "Exalted", "Radiant" },
	{ "Timeless", "Infinite", "Boundless", "Absolute", "Eternal" },
	{ "Abyssal", "Void", "Eldritch", "Chaos", "Primordial" },
	{ "Singularity", "Transcendental", "Omnipotent", "Zenith", "Beyond" },
}

for tier, rarities in ipairs(packRarities) do
	local reward = 10 * tier
	for _, rarity in ipairs(rarities) do
		RARITY_REWARD_GEMS[rarity] = reward
	end
end

function CollectionRewardService.getCompletionStatus(player: Player): { [string]: { total: number, found: number, claimed: boolean } }
	local profile = PlayerDataService.get(player)
	if not profile then return {} end
	local discovered = profile.collection.discovered or {}
	local claimedRows = profile.collection.claimedRows or {}
	local result: { [string]: { total: number, found: number, claimed: boolean } } = {}

	for rarityId, total in pairs(godCountByRarity) do
		local found = 0
		for _, def in ipairs(Gods.list) do
			if def.rarityId == rarityId and discovered[def.id] then
				found += 1
			end
		end
		result[rarityId] = {
			total = total,
			found = found,
			claimed = claimedRows[rarityId] == true,
		}
	end
	return result
end

Net:Function("ClaimCollectionReward").OnServerInvoke = function(player: Player, rarityId: string)
	if type(rarityId) ~= "string" then return { ok = false, reason = "invalid" } end
	if not RateLimit.consume(player, "ClaimCollectionReward", 5, 10) then
		return { ok = false, reason = "rate_limit" }
	end

	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local totalNeeded = godCountByRarity[rarityId]
	if not totalNeeded or totalNeeded <= 0 then
		return { ok = false, reason = "invalid_rarity" }
	end

	if not profile.collection.claimedRows then profile.collection.claimedRows = {} end
	if profile.collection.claimedRows[rarityId] then
		return { ok = false, reason = "already_claimed" }
	end

	local discovered = profile.collection.discovered or {}
	local found = 0
	for _, def in ipairs(Gods.list) do
		if def.rarityId == rarityId and discovered[def.id] then
			found += 1
		end
	end

	if found < totalNeeded then
		return { ok = false, reason = "incomplete", found = found, total = totalNeeded }
	end

	local reward = RARITY_REWARD_GEMS[rarityId] or 10
	local rdef = require(Shared.config.Rarities).byId[rarityId]
	local newTier = rdef and rdef.packTier or 0
	PlayerDataService.update(player, function(p)
		if not p.collection.claimedRows then p.collection.claimedRows = {} end
		p.collection.claimedRows[rarityId] = true
		-- Track best aura tier
		if newTier > (p.collection.bestAuraTier or 0) then
			p.collection.bestAuraTier = newTier
		end
	end)
	EconomyService.add(player, "gems", reward)

	-- Push aura update to client
	local updatedProfile = PlayerDataService.get(player)
	if updatedProfile then
		Net:Event("OnAuraUpdate"):FireClient(player, updatedProfile.collection.bestAuraTier or 0)
	end

	Logger.info("%s claimed collection reward for %s (%d gems, aura tier %d)", player.Name, rarityId, reward, newTier)
	return { ok = true, gems = reward }
end

Net:Function("GetCollectionStatus").OnServerInvoke = function(player: Player)
	return CollectionRewardService.getCompletionStatus(player)
end

Logger.info("CollectionRewardService online (%d rarity groups).", (function()
	local n = 0; for _ in pairs(godCountByRarity) do n += 1 end; return n
end)())

return CollectionRewardService
