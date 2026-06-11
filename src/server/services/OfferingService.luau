--!strict
-- OfferingService
--   - Spieler opfern Offerings für zufällige Prozent-Buffs (30 min, in-memory).
--   - Buff-Typen: luck | gold | faith | prod (Tempel-Produktion)
--   - Tier 1 (25) / 2 (50) / 3 (100) Offerings → unterschiedliche Buff-Stärke
--   - getBonus(player, buffType) → z.B. 0.05 für +5%

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Offering")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService    = require(script.Parent.EconomyService)
local RateLimit         = require(script.Parent.Parent.security.RateLimit)

-- ─── Modul-Tabelle zuerst deklarieren ────────────────────────────────────────
local OfferingService = {}

local BUFF_DURATION = 30 * 60 -- 30 Minuten

-- Tiers: { cost, pctMin, pctMax }
local TIERS = {
	{ cost = 25,  pctMin = 0.02, pctMax = 0.05 },
	{ cost = 50,  pctMin = 0.04, pctMax = 0.09 },
	{ cost = 100, pctMin = 0.07, pctMax = 0.15 },
}

local BUFF_TYPES = { "luck", "gold", "faith", "prod" }

type Buff = { buffType: string, pct: number, expiresAt: number }
local activeBuff: { [Player]: Buff } = {}

local offeringEvent = Net:Event("OnOfferingUpdate")

-- ─── Public API ──────────────────────────────────────────────────────────────

function OfferingService.getBonus(player: Player, buffType: string): number
	local b = activeBuff[player]
	if not b then return 0 end
	if b.expiresAt <= os.time() then
		activeBuff[player] = nil :: any
		return 0
	end
	if b.buffType == buffType then return b.pct end
	return 0
end

-- ─── Remote ──────────────────────────────────────────────────────────────────

Net:Function("SpendOfferings").OnServerInvoke = function(player: Player, tier: number)
	if type(tier) ~= "number" then return { ok = false, reason = "bad_args" } end
	tier = math.clamp(math.floor(tier), 1, 3)
	if not RateLimit.consume(player, "SpendOfferings", 3, 10) then
		return { ok = false, reason = "rate_limit" }
	end

	local tierDef = TIERS[tier]
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	if (profile.currencies.offerings or 0) < tierDef.cost then
		return { ok = false, reason = "not_enough_offerings" }
	end

	EconomyService.add(player, "offerings", -tierDef.cost)

	local rng = Random.new(os.clock() * 1e7 + player.UserId)
	local pct = tierDef.pctMin + rng:NextNumber() * (tierDef.pctMax - tierDef.pctMin)
	local buffType = BUFF_TYPES[rng:NextInteger(1, #BUFF_TYPES)]
	pct = math.floor(pct * 1000 + 0.5) / 1000 -- 3 Dezimalstellen

	local buff: Buff = {
		buffType = buffType,
		pct = pct,
		expiresAt = os.time() + BUFF_DURATION,
	}
	activeBuff[player] = buff

	offeringEvent:FireClient(player, {
		active    = true,
		buffType  = buffType,
		pct       = pct,
		expiresAt = buff.expiresAt,
	})

	Logger.info("%s spent %d offerings → +%.1f%% %s (30 min)",
		player.Name, tierDef.cost, pct * 100, buffType)
	return { ok = true, buffType = buffType, pct = pct }
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	offeringEvent:FireClient(player, { active = false })
end)

Players.PlayerRemoving:Connect(function(player)
	activeBuff[player] = nil :: any
end)

Logger.info("OfferingService online.")

return OfferingService
