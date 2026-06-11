--!strict
-- CompanionService — persists companion skin + ability for each player.
-- Client calls GetCompanionData on join, SetCompanionSkin / SetCompanionAbility on change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Companion")
local Net = require(Shared.remotes.Net)
local CompanionSkins = require(Shared.config.CompanionSkins)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local CompanionService = {}

Net:Function("GetCompanionData").OnServerInvoke = function(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return { skin = "default", ability = "none" } end
	local c = profile.companion or {}
	return { skin = c.skin or "default", ability = c.ability or "none" }
end

Net:Function("SetCompanionSkin").OnServerInvoke = function(player: Player, skinId: string)
	if type(skinId) ~= "string" then return { ok = false, reason = "invalid" } end
	if not RateLimit.consume(player, "SetCompanionSkin", 10, 5) then
		return { ok = false, reason = "rate_limit" }
	end

	local skin = CompanionSkins.byId[skinId]
	if not skin then return { ok = false, reason = "unknown_skin" } end

	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local currentSkin = (profile.companion and profile.companion.skin) or "default"
	if currentSkin == skinId then return { ok = true } end

	-- Charge gems unless it's the free default
	if skin.gemCost > 0 then
		local owned = (profile.companion and profile.companion.ownedSkins) or {}
		if not owned[skinId] then
			if (profile.currencies.gems or 0) < skin.gemCost then
				return { ok = false, reason = "not_enough_gems", cost = skin.gemCost }
			end
			EconomyService.add(player, "gems", -skin.gemCost)
			PlayerDataService.update(player, function(p)
				if not p.companion then p.companion = { skin = "default", ability = "none", ownedSkins = {} } end
				if not p.companion.ownedSkins then p.companion.ownedSkins = {} end
				p.companion.ownedSkins[skinId] = true
				p.companion.skin = skinId
			end)
			Logger.info("%s bought skin '%s' for %d gems", player.Name, skinId, skin.gemCost)
			return { ok = true, bought = true }
		end
	end

	PlayerDataService.update(player, function(p)
		if not p.companion then p.companion = { skin = "default", ability = "none", ownedSkins = {} } end
		p.companion.skin = skinId
	end)
	Logger.info("%s switched to companion skin '%s'", player.Name, skinId)
	return { ok = true }
end

Net:Function("SetCompanionAbility").OnServerInvoke = function(player: Player, abilityId: string)
	if type(abilityId) ~= "string" then return { ok = false, reason = "invalid" } end
	if not RateLimit.consume(player, "SetCompanionAbility", 5, 5) then
		return { ok = false, reason = "rate_limit" }
	end
	PlayerDataService.update(player, function(p)
		if not p.companion then p.companion = { skin = "default", ability = "none", ownedSkins = {} } end
		p.companion.ability = abilityId
	end)
	return { ok = true }
end

Logger.info("CompanionService online.")
return CompanionService
