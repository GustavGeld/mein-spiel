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

-- Multiplier-Lookup, später erweitert von GamepassService/Divinity/Potions.
function EconomyService.getMultiplier(player: Player, currency: Currency): number
	local profile = PlayerDataService.get(player)
	if not profile then return 1 end
	local mul = 1
	-- Divinity-Tree Bonuses (Wealth/Devotion/Ascension Branches)
	if currency == "gold" then
		local lvl = profile.divinity.tree.wealth and profile.divinity.tree.wealth.goldGain or 0
		mul *= (1 + lvl * 0.02)
		if profile.unlocks.gamepasses["x2Gold"] then mul *= 2 end
	elseif currency == "faith" then
		local lvl = profile.divinity.tree.devotion and profile.divinity.tree.devotion.faithGain or 0
		mul *= (1 + lvl * 0.02)
		if profile.unlocks.gamepasses["x2Faith"] then mul *= 2 end
	elseif currency == "offerings" then
		if profile.unlocks.gamepasses["x2Offerings"] then mul *= 2 end
	end
	return mul
end

Logger.info("EconomyService online.")

return EconomyService
