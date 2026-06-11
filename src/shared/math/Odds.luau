--!strict
-- Reine, deterministische Roll-Funktionen.
-- Bewusst server-only nutzbar — Client darf importieren, aber kein Pull triggern.

local Packs = require(script.Parent.Parent.config.Packs)

export type RollResult = {
	rarityId: string,
	isSecret: boolean,
	secretPool: string?,
	-- Animation Preview: server-generierte Liste von Vorschau-Rarities, durch die
	-- die Roll-UI scrollt, endet mit dem echten Ergebnis.
	preview: { string },
}

local function weightedPick(weights: { number }, rng: Random): number
	local total = 0
	for _, w in ipairs(weights) do
		total += w
	end
	local r = rng:NextNumber() * total
	local acc = 0
	for i, w in ipairs(weights) do
		acc += w
		if r <= acc then
			return i
		end
	end
	return #weights
end

local function buildPreview(rng: Random, finalRarityId: string, packRarities: { string }, cinematicTier: number): { string }
	-- 12–18 Items, je nach Cinematic-Tier mehr.
	local count = 10 + cinematicTier * 2
	local preview = table.create(count)
	for i = 1, count - 1 do
		preview[i] = packRarities[rng:NextInteger(1, #packRarities)]
	end
	preview[count] = finalRarityId
	return preview
end

local Odds = {}

-- pityState[packId] = Pulls ohne 4th-best+ in Folge.
-- pityState["rare_"..packId] = Pulls ohne 3rd-best+ (Rare Pity).
export type PityState = { [any]: number }

-- Rollt einmal aus Pack `packId`.
function Odds.roll(packId: number, rng: Random, pity: PityState, luckMul: number?, secretMul: number?): RollResult
	local pack = Packs.byId[packId]
	if not pack then
		error("Unknown packId: " .. tostring(packId))
	end

	luckMul = luckMul or 1
	secretMul = secretMul or 1

	-- 1) Secret-Check first
	local secretChance = (Packs.secretChance[pack.secretPool] or 0) * secretMul
	if rng:NextNumber() < secretChance then
		local secretId = "Secret_" .. pack.secretPool
		return {
			rarityId = secretId,
			isSecret = true,
			secretPool = pack.secretPool,
			preview = buildPreview(rng, secretId, pack.rarities, pack.cinematicTier),
		}
	end

	-- 2) Pity-Check: nach Threshold garantiere ≥ 4th-best (Epic Pity)
	local pityCount = pity[packId] or 0
	local threshold = Packs.pityThreshold(pack.id)
	local forcePity = pityCount >= threshold

	-- 2b) Rare Pity: nach 50 Pulls ohne ≥ 3rd-best → garantiere Slot 3+
	local rarePityKey = "rare_" .. tostring(packId)
	local rarePityCount = pity[rarePityKey] or 0
	local RARE_PITY_THRESHOLD = 50
	local forceRarePity = rarePityCount >= RARE_PITY_THRESHOLD

	-- 3) Apply luck: erhöht Gewicht der besseren 3 Slots leicht
	local weights = table.clone(pack.weightsPPM)
	if luckMul ~= 1 then
		local shift = math.floor(weights[1] * math.min(0.15, (luckMul - 1) * 0.5))
		weights[1] -= shift
		weights[4] += math.floor(shift * 0.75)
		weights[5] += shift - math.floor(shift * 0.75)
	end

	local idx
	if forcePity then
		idx = weightedPick({ weights[4], weights[5] }, rng) + 3
		pity[packId] = 0
		pity[rarePityKey] = 0
	elseif forceRarePity then
		idx = weightedPick({ weights[3], weights[4], weights[5] }, rng) + 2
		pity[rarePityKey] = 0
		if idx >= 4 then pity[packId] = 0 else pity[packId] = pityCount + 1 end
	else
		idx = weightedPick(weights, rng)
		if idx >= 4 then
			pity[packId] = 0
			pity[rarePityKey] = 0
		elseif idx >= 3 then
			pity[rarePityKey] = 0
			pity[packId] = pityCount + 1
		else
			pity[packId] = pityCount + 1
			pity[rarePityKey] = rarePityCount + 1
		end
	end

	local rarityId = pack.rarities[idx]
	return {
		rarityId = rarityId,
		isSecret = false,
		preview = buildPreview(rng, rarityId, pack.rarities, pack.cinematicTier),
	}
end

-- Liefert "1 in X" String für UI.
function Odds.displayOdds(packId: number, rarityId: string): string
	local pack = Packs.byId[packId]
	if not pack then
		return "—"
	end
	-- Secret?
	if rarityId:sub(1, 7) == "Secret_" then
		local pool = rarityId:sub(8)
		local chance = Packs.secretChance[pool] or 0
		if chance <= 0 then return "—" end
		return string.format("1 in %s", Odds.formatBig(1 / chance))
	end
	for i, rid in ipairs(pack.rarities) do
		if rid == rarityId then
			local total = 0
			for _, w in ipairs(pack.weightsPPM) do total += w end
			local chance = pack.weightsPPM[i] / total
			if chance <= 0 then return "—" end
			return string.format("1 in %s", Odds.formatBig(1 / chance))
		end
	end
	return "—"
end

-- Kompakte Zahlformatierung für UI (1.5K, 2.3M, 1.2B …)
local suffixes = { "", "K", "M", "B", "T", "Q", "Qi", "Sx", "Sp", "Oc" }
function Odds.formatBig(n: number): string
	if n < 1000 then
		return tostring(math.floor(n + 0.5))
	end
	local i = 1
	while n >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	return string.format("%.1f%s", n, suffixes[i])
end

return Odds
