--!strict
-- EconomyService — single source of truth für Gold/Faith/Offerings/Gems/Divinity.
-- Caller fragen NIE Werte vom Client. Server validiert alles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Economy")

local PlayerDataService = require(script.Parent.PlayerDataService)

export type Currency = "gold" | "faith" | "offerings" | "gems" | "divinity"

local EconomyService = {}

local VALID: { [string]: boolean } = {
	gold = true, faith = true, offerings = true, gems = true, divinity = true,
}

local function assertCurrency(currency: string)
	assert(VALID[currency], "Invalid currency: " .. tostring(currency))
end

function EconomyService.get(player: Player, currency: Currency): number
	local profile = PlayerDataService.get(player)
	if not profile then return 0 end
	return profile.currencies[currency] or 0
end

function EconomyService.can(player: Player, currency: Currency, amount: number): boolean
	assertCurrency(currency)
	if amount <= 0 then return true end
	return EconomyService.get(player, currency) >= amount
end

function EconomyService.add(player: Player, currency: Currency, amount: number)
	assertCurrency(currency)
	if amount == 0 then return end
	PlayerDataService.update(player, function(profile)
		profile.currencies[currency] = math.max(0, (profile.currencies[currency] or 0) + amount)
		if currency == "gold" and amount > 0 then
			profile.lifetime.gold += amount
		end
	end)
	PlayerDataService.patchEconomy(player)
end

-- Atomic: nimmt `cost`, gibt nur dann `reward` (falls gesetzt). Liefert true/false.
function EconomyService.transact(player: Player, costCurrency: Currency, costAmount: number, rewardCurrency: Currency?, rewardAmount: number?): boolean
	assertCurrency(costCurrency)
	if rewardCurrency then assertCurrency(rewardCurrency) end
	if not EconomyService.can(player, costCurrency, costAmount) then
		return false
	end
	PlayerDataService.update(player, function(profile)
		profile.currencies[costCurrency] -= costAmount
		if rewardCurrency and rewardAmount and rewardAmount > 0 then
			profile.currencies[rewardCurrency] = (profile.currencies[rewardCurrency] or 0) + rewardAmount
			if rewardCurrency == "gold" then
				profile.lifetime.gold += rewardAmount
			end
		end
	end)
	PlayerDataService.patchEconomy(player)
	return true
end

-- Multiplier-Lookup: Divinity-Tree + Gamepasses + aktive Potions.
function EconomyService.getMultiplier(player: Player, currency: Currency): number
	local profile = PlayerDataService.get(player)
	if not profile then return 1 end
	local mul = 1
	local gp = profile.unlocks.gamepasses
	-- Divinity-Tree Bonuses
	if currency == "gold" then
		local lvl = profile.divinity.tree.wealth and profile.divinity.tree.wealth.goldGain or 0
		mul *= (1 + lvl * 0.02)
		if gp["x2Gold"] then mul *= 2 end
	elseif currency == "faith" then
		local lvl = profile.divinity.tree.devotion and profile.divinity.tree.devotion.faithGain or 0
		mul *= (1 + lvl * 0.02)
		if gp["x2Faith"] then mul *= 2 end
	elseif currency == "offerings" then
		if gp["x2Offerings"] then mul *= 2 end
	end
	-- Potion-Multiplikatoren
	local potionS = script.Parent:FindFirstChild("PotionService")
	if potionS then
		local PS = require(potionS) :: any
		if PS and PS.getMultiplier then
			mul *= PS.getMultiplier(player, tostring(currency))
		end
	end
	-- Offering-Buffs
	local offeringS = script.Parent:FindFirstChild("OfferingService")
	if offeringS then
		local OS = require(offeringS) :: any
		if OS and OS.getBonus then
			mul *= (1 + OS.getBonus(player, tostring(currency)))
		end
	end
	-- Friends Boost (+5% per friend online, max +25%)
	local friendsS = script.Parent:FindFirstChild("FriendsBoostService")
	if friendsS then
		local FS = require(friendsS) :: any
		if FS and FS.getBoost then
			mul *= (1 + FS.getBoost(player))
		end
	end
	return mul
end

-- Luck-Multiplier: Divinity + Gamepasses + Potions + Offerings + LuckyHour.
function EconomyService.getLuckMultiplier(player: Player): number
	local profile = PlayerDataService.get(player)
	if not profile then return 1 end
	local mul = 1
	local lvl = profile.divinity.tree.fortune and profile.divinity.tree.fortune.luck or 0
	mul *= (1 + lvl * 0.03)
	if profile.unlocks.gamepasses["x2Luck"] then mul *= 2 end
	-- Login-Streak Bonus: +2% Luck pro Streak-Tag (max +20% bei Streak 10+)
	local streak = profile.quests and profile.quests.login and profile.quests.login.streak or 0
	if streak > 0 then mul *= (1 + math.min(streak, 10) * 0.02) end
	-- Potion
	local potionS = script.Parent:FindFirstChild("PotionService")
	if potionS then
		local PS = require(potionS) :: any
		if PS.getMultiplier then mul *= PS.getMultiplier(player, "luck") end
	end
	-- Offering Buff
	local offeringS = script.Parent:FindFirstChild("OfferingService")
	if offeringS then
		local OS = require(offeringS) :: any
		if OS.getBonus then mul *= (1 + OS.getBonus(player, "luck")) end
	end
	-- Lucky Hour (global server event)
	local luckyS = script.Parent:FindFirstChild("LuckyHourService")
	if luckyS then
		local LS = require(luckyS) :: any
		if LS.getLuckBonus then mul *= (1 + LS.getLuckBonus()) end
	end
	-- Seeker companion ability: +5% luck
	if profile.companion and profile.companion.abilities and profile.companion.abilities["seeker"] then
		mul *= 1.05
	end
	return mul
end

Logger.info("EconomyService online.")

return EconomyService
