--!strict
-- ReferralService — Each player has a unique referral code (their UserId).
-- Redeeming gives BOTH the referrer and the new player 50 Gems.
-- A player can only use one referral code, and cannot refer themselves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Referral")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local REFERRAL_GEMS    = 50
local REFERRER_GEMS    = 50
local MAX_USES_PER_CODE = 3   -- Each code can be used at most 3 times total

local ReferralService = {}

-- Referral code = "REF-<UserId>"
function ReferralService.getCode(player: Player): string
	return "REF-" .. tostring(player.UserId)
end

-- Returns how many times a referrer's code has already been used (0 if Studio / error)
local function getReferralCount(referrerId: number): number
	if RunService:IsStudio() then return 0 end
	local ok, val = pcall(function()
		return DataStoreService:GetDataStore("GodsOfFate_ReferralCounts"):GetAsync("count_" .. tostring(referrerId))
	end)
	return (ok and type(val) == "number") and val or 0
end

-- Atomically increments the referral count; returns the new value (or -1 on error)
local function incrementReferralCount(referrerId: number): number
	if RunService:IsStudio() then return 1 end
	local newVal = -1
	pcall(function()
		newVal = DataStoreService:GetDataStore("GodsOfFate_ReferralCounts"):UpdateAsync(
			"count_" .. tostring(referrerId),
			function(old) return (old or 0) + 1 end
		)
	end)
	return newVal
end

Net:Function("GetReferralCode").OnServerInvoke = function(player: Player)
	local count = getReferralCount(player.UserId)
	return { ok = true, code = ReferralService.getCode(player), usesLeft = MAX_USES_PER_CODE - count }
end

Net:Function("RedeemReferral").OnServerInvoke = function(player: Player, rawCode: string)
	if type(rawCode) ~= "string" then return { ok = false, reason = "invalid" } end
	if not RateLimit.consume(player, "RedeemReferral", 3, 60) then
		return { ok = false, reason = "rate_limit" }
	end

	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	if profile.social.referrer then
		return { ok = false, reason = "already_referred" }
	end

	local code = rawCode:upper():match("^%s*(.-)%s*$") or rawCode:upper()
	local prefix = "REF-"
	if code:sub(1, #prefix) ~= prefix then
		return { ok = false, reason = "invalid_code" }
	end

	local referrerIdStr = code:sub(#prefix + 1)
	local referrerId = tonumber(referrerIdStr)
	if not referrerId then
		return { ok = false, reason = "invalid_code" }
	end

	if referrerId == player.UserId then
		return { ok = false, reason = "self_refer" }
	end

	-- Check and atomically claim one of the MAX_USES slots
	local currentCount = getReferralCount(referrerId)
	if currentCount >= MAX_USES_PER_CODE then
		return { ok = false, reason = "code_maxed" }
	end

	-- Increment first (optimistic); if it came back > cap, abort
	local newCount = incrementReferralCount(referrerId)
	if newCount > MAX_USES_PER_CODE then
		Logger.warn("Referral race: code %s exceeded cap (count=%d)", code, newCount)
		return { ok = false, reason = "code_maxed" }
	end

	-- Mark referral on the new player
	PlayerDataService.update(player, function(p)
		p.social.referrer = code
	end)

	-- Reward the new player
	EconomyService.add(player, "gems", REFERRAL_GEMS)
	Logger.info("%s redeemed referral from userId %d (use %d/%d)", player.Name, referrerId, newCount, MAX_USES_PER_CODE)

	-- Reward the referrer if online
	local referrerPlayer: Player? = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == referrerId then
			referrerPlayer = p
			break
		end
	end

	if referrerPlayer then
		EconomyService.add(referrerPlayer, "gems", REFERRER_GEMS)
		Logger.info("Referrer %s (online) got %d gems", referrerPlayer.Name, REFERRER_GEMS)
	else
		task.spawn(function()
			if RunService:IsStudio() then return end
			local ok2, err = pcall(function()
				DataStoreService:GetDataStore("GodsOfFate_ReferralRewards"):UpdateAsync(
					"pending_" .. tostring(referrerId),
					function(old) return (old or 0) + REFERRER_GEMS end
				)
			end)
			if not ok2 then
				Logger.warn("Failed to store offline referral reward: %s", tostring(err))
			end
		end)
	end

	return { ok = true, gemsEarned = REFERRAL_GEMS, usesLeft = MAX_USES_PER_CODE - newCount }
end

-- On player join: check for pending referral rewards
Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		if RunService:IsStudio() then return end
		local ok, pending = pcall(function()
			local store = DataStoreService:GetDataStore("GodsOfFate_ReferralRewards")
			return store:GetAsync("pending_" .. tostring(player.UserId))
		end)
		if ok and pending and pending > 0 then
			EconomyService.add(player, "gems", pending)
			Logger.info("Granted %d pending referral gems to %s", pending, player.Name)
			pcall(function()
				local store = DataStoreService:GetDataStore("GodsOfFate_ReferralRewards")
				store:RemoveAsync("pending_" .. tostring(player.UserId))
			end)
		end
	end)
end)

Logger.info("ReferralService online (reward=%d gems each).", REFERRAL_GEMS)

return ReferralService
