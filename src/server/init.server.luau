--!strict
-- Server bootstrap. Lädt Services in deterministischer Reihenfolge.
-- Echte Service-Implementierungen folgen Stage-für-Stage (siehe IMPLEMENTATION_ROADMAP.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Bootstrap")
local Net = require(Shared.remotes.Net)

Logger.info("Booting Gods of Fate server…")

-- Erzeuge Remote-Folder + Stubs früh, damit Client beim Join wartefähig ist.
Net:Function("RequestProfile")
Net:Function("ChangeSetting")
Net:Event("OnEconomyUpdate")
Net:Event("OnInventoryUpdate")
Net:Event("OnPullResult")
Net:Event("OnBroadcast")
Net:Event("OnLeaderboardUpdate")
Net:Event("OnSeasonUpdate")
Net:Event("OnPotionUpdate")
Net:Event("OnAchievementUpdate")
Net:Event("OnAuctionUpdate")
Net:Event("OnOfferingUpdate")
Net:Event("OnLuckyHour")
Net:Event("OnStormEvent")
Net:Event("OnFrenzyEvent")
Net:Event("OnVIPEject")
Net:Event("OnAuraUpdate")
Net:Event("OnEventUpdate")
Net:Function("GetActiveEvent")
Net:Function("BuyEventPack")
Net:Function("SetActiveAura")
Net:Function("BuyAbility")
Net:Function("RerollQuest")
Net:Function("BuyTempleUpgrade")

Logger.info("Remote skeleton ready.")

-- Register event-exclusive gods into Gods.byId (must be early, before any service uses Gods)
local _EventGods = require(Shared.config.EventGods)

-- Stage 1: Player data persistence
local PlayerDataService = require(script.services.PlayerDataService)
Logger.info("PlayerDataService loaded.")

-- Generic settings saver (music, sfx, reducedMotion, tradeInvites, companionEnabled, …)
local ALLOWED_SETTINGS: { [string]: boolean } = {
	music = true, sfx = true, reducedMotion = true,
	tradeInvites = true, companionEnabled = true,
}
Net:Function("ChangeSetting").OnServerInvoke = function(player: Player, key: any, value: any)
	if type(key) ~= "string" or not ALLOWED_SETTINGS[key] then return false end
	PlayerDataService.update(player, function(p)
		p.settings[key] = value
	end)
	return true
end

-- Stage 2: Economy + Packs
local EconomyService = require(script.services.EconomyService)
local PackService = require(script.services.PackService)
Logger.info("Economy + Pack services loaded.")

-- Stage 3: Inventory + Temple
local InventoryService = require(script.services.InventoryService)
local TempleService = require(script.services.TempleService)
Logger.info("Inventory + Temple services loaded.")

-- Stage 4: Quests + Daily + Login
local QuestService = require(script.services.QuestService)
Logger.info("QuestService loaded.")

-- Stage 5: Rebirth + Divinity
local RebirthService = require(script.services.RebirthService)
local DivinityService = require(script.services.DivinityService)
Logger.info("Rebirth + Divinity services loaded.")

-- Stage 6: Fusion + Broadcast
local BroadcastService = require(script.services.BroadcastService)
local FusionService = require(script.services.FusionService)
Logger.info("Broadcast + Fusion services loaded.")

-- Stage 7: Gamepasses + Dev Products
local GamepassService = require(script.services.GamepassService)
Logger.info("GamepassService loaded.")

-- Stage 8: Trading
local TradeService = require(script.services.TradeService)
Logger.info("TradeService loaded.")

-- Stage 9: Leaderboards + Seasons
local LeaderboardService = require(script.services.LeaderboardService)
local SeasonService = require(script.services.SeasonService)
Logger.info("Leaderboard + Season services loaded.")

-- Stage 10: Potions, Achievements, Codes, Auctions
local PotionService = require(script.services.PotionService)
local AchievementService = require(script.services.AchievementService)
local _CodeService = require(script.services.CodeService)
local _AuctionService = require(script.services.AuctionService)
Logger.info("Potions + Achievements + Codes + Auctions loaded.")

-- Stage 11: Offerings, LuckyHour
local _OfferingService = require(script.services.OfferingService)
local _LuckyHourService = require(script.services.LuckyHourService)
Logger.info("Offerings + LuckyHour loaded.")

-- Stage 13: Storm, Frenzy, FriendsBoost
local _StormService = require(script.services.StormService)
local _FrenzyService = require(script.services.FrenzyService)
local _FriendsBoostService = require(script.services.FriendsBoostService)
Logger.info("Storm + Frenzy + FriendsBoost loaded.")

-- Stage 14: Referral + Collection Rewards + VIP
local _ReferralService = require(script.services.ReferralService)
local _CollectionRewardService = require(script.services.CollectionRewardService)
local _VIPService = require(script.services.VIPService)
Logger.info("Referral + CollectionReward + VIP loaded.")

-- Stage 15: Analytics + Companion
local _AnalyticsService = require(script.services.AnalyticsService)
local _CompanionService = require(script.services.CompanionService)
Logger.info("Analytics + CompanionService loaded.")

-- Stage 18: Limited Events
local _LimitedEventService = require(script.services.LimitedEventService)
Logger.info("LimitedEventService loaded.")

-- Fire active aura to each player when their profile loads
do
	if PlayerDataService.OnLoaded then
		PlayerDataService.OnLoaded:Connect(function(player: Player, profile: any)
			task.wait(0.5)
			local col = profile.collection or {}
			-- Use saved active selection; fall back to best unlocked
			local tier = col.activeAuraTier or col.bestAuraTier or 0
			Net:Event("OnAuraUpdate"):FireClient(player, tier)
		end)
	end
end

-- SetActiveAura — player picks which unlocked aura to display
Net:Function("SetActiveAura").OnServerInvoke = function(player: Player, tier: any)
	if type(tier) ~= "number" then return false end
	tier = math.floor(tier)
	local profile = PlayerDataService.get(player)
	if not profile then return false end
	-- tier 0 = no aura; positive tier must be unlocked
	if tier > 0 and tier > (profile.collection.bestAuraTier or 0) then
		return false
	end
	PlayerDataService.update(player, function(p)
		p.collection.activeAuraTier = tier
	end)
	Net:Event("OnAuraUpdate"):FireClient(player, tier)
	return true
end

-- BuyAbility — player purchases a companion ability with gems
do
	local CompanionAbilities = require(Shared.config.CompanionAbilities)
	Net:Function("BuyAbility").OnServerInvoke = function(player: Player, abilityId: any)
		if type(abilityId) ~= "string" then return { ok = false, reason = "bad_args" } end
		local def = CompanionAbilities.byId[abilityId]
		if not def then return { ok = false, reason = "unknown_ability" } end
		local profile = PlayerDataService.get(player)
		if not profile then return { ok = false, reason = "no_profile" } end
		local abilities = profile.companion and profile.companion.abilities or {}
		if abilities[abilityId] then return { ok = false, reason = "already_owned" } end
		if (profile.currencies.gems or 0) < def.gemCost then return { ok = false, reason = "not_enough_gems" } end
		PlayerDataService.update(player, function(p)
			p.currencies.gems = (p.currencies.gems or 0) - def.gemCost
			if not p.companion.abilities then p.companion.abilities = {} end
			p.companion.abilities[abilityId] = true
		end)
		PlayerDataService.patchEconomy(player)
		return { ok = true }
	end
end

-- Test-/Admin-Chatbefehle (z. B. /money zum Geld geben)
local CommandService = require(script.services.CommandService)
Logger.info("CommandService loaded.")
