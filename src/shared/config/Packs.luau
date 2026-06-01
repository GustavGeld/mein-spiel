--!strict
-- 10 Standard-Packs + Ascendant. Odds in Promille (out of 1_000_000) für Präzision.
-- Schlechteste Rarity ist global mindestens 60x häufiger als beste.

export type UnlockRequirement = {
	gold: number?,
	rebirths: number?,
	robux: boolean?,
	devProductId: number?,
}

export type PackDefinition = {
	id: number,
	idKey: string, -- locale key e.g. "pack.mortal.name"
	descKey: string,
	rarities: { string }, -- order: worst → best
	-- weights in PPM (parts per million), sum = 1_000_000
	weightsPPM: { number },
	basePriceGold: number,
	priceCurveMul: number, -- price = basePrice * curveMul^ownedPullsOfTier (mild)
	unlock: UnlockRequirement,
	secretPool: string, -- "T1" | "T2" | "T3"
	cinematicTier: number, -- 1..5, beeinflusst Roll-Animations-Drama
}

-- Default-Weight für Pack 1..9: [580_000, 270_000, 110_000, 36_000, 4_000]
-- Pack 10 streckt Best-Slot auf 1 in 1500.
local function defaultWeights(): { number }
	return { 580_000, 270_000, 110_000, 36_000, 4_000 }
end

local Packs: { PackDefinition } = {
	{
		id = 1,
		idKey = "pack.mortal.name",
		descKey = "pack.mortal.desc",
		rarities = { "Common", "Uncommon", "Rare", "Epic", "Unique" },
		weightsPPM = defaultWeights(),
		basePriceGold = 100,
		priceCurveMul = 1.0,
		unlock = {},
		secretPool = "T1",
		cinematicTier = 1,
	},
	{
		id = 2,
		idKey = "pack.champion.name",
		descKey = "pack.champion.desc",
		rarities = { "Elite", "Heroic", "RisingStar", "Legendary", "Mythic" },
		weightsPPM = defaultWeights(),
		basePriceGold = 2_500,
		priceCurveMul = 1.0,
		unlock = { gold = 50_000 },
		secretPool = "T1",
		cinematicTier = 1,
	},
	{
		id = 3,
		idKey = "pack.pantheon.name",
		descKey = "pack.pantheon.desc",
		rarities = { "Immortal", "DemiGod", "Valkyrie", "God", "Goddess" },
		weightsPPM = defaultWeights(),
		basePriceGold = 75_000,
		priceCurveMul = 1.0,
		unlock = { gold = 1_000_000 },
		secretPool = "T1",
		cinematicTier = 2,
	},
	{
		id = 4,
		idKey = "pack.celestial.name",
		descKey = "pack.celestial.desc",
		rarities = { "Ascended", "Ancient", "HighTier", "Cosmic", "Celestial" },
		weightsPPM = defaultWeights(),
		basePriceGold = 1_500_000,
		priceCurveMul = 1.0,
		unlock = { gold = 25_000_000, rebirths = 1 },
		secretPool = "T2",
		cinematicTier = 2,
	},
	{
		id = 5,
		idKey = "pack.astral.name",
		descKey = "pack.astral.desc",
		rarities = { "Astral", "Nebula", "Galaxy", "Universe", "Archon" },
		weightsPPM = defaultWeights(),
		basePriceGold = 60_000_000,
		priceCurveMul = 1.0,
		unlock = { gold = 1_000_000_000, rebirths = 3 },
		secretPool = "T2",
		cinematicTier = 3,
	},
	{
		id = 6,
		idKey = "pack.temporal.name",
		descKey = "pack.temporal.desc",
		rarities = { "Chrono", "Temporal", "Dimensional", "Spatial", "Divine" },
		weightsPPM = defaultWeights(),
		basePriceGold = 2_500_000_000,
		priceCurveMul = 1.0,
		unlock = { gold = 50_000_000_000, rebirths = 6 },
		secretPool = "T2",
		cinematicTier = 3,
	},
	{
		id = 7,
		idKey = "pack.radiant.name",
		descKey = "pack.radiant.desc",
		rarities = { "Luminary", "Seraphim", "Sacred", "Exalted", "Radiant" },
		weightsPPM = defaultWeights(),
		basePriceGold = 100_000_000_000,
		priceCurveMul = 1.0,
		unlock = { gold = 1_000_000_000_000, rebirths = 10 },
		secretPool = "T3",
		cinematicTier = 4,
	},
	{
		id = 8,
		idKey = "pack.eternal.name",
		descKey = "pack.eternal.desc",
		rarities = { "Timeless", "Infinite", "Boundless", "Absolute", "Eternal" },
		weightsPPM = defaultWeights(),
		basePriceGold = 4_000_000_000_000,
		priceCurveMul = 1.0,
		unlock = { gold = 25_000_000_000_000, rebirths = 15 },
		secretPool = "T3",
		cinematicTier = 4,
	},
	{
		id = 9,
		idKey = "pack.abyss.name",
		descKey = "pack.abyss.desc",
		rarities = { "Abyssal", "Void", "Eldritch", "Chaos", "Primordial" },
		weightsPPM = defaultWeights(),
		basePriceGold = 150_000_000_000_000,
		priceCurveMul = 1.0,
		unlock = { gold = 500_000_000_000_000, rebirths = 22 },
		secretPool = "T3",
		cinematicTier = 5,
	},
	{
		id = 10,
		idKey = "pack.beyond.name",
		descKey = "pack.beyond.desc",
		rarities = { "Singularity", "Transcendental", "Omnipotent", "Zenith", "Beyond" },
		-- Pack 10: best Rarity gestreckt auf 1 in 1500 (~666 PPM)
		weightsPPM = { 620_000, 280_000, 90_000, 9_334, 666 },
		basePriceGold = 5_000_000_000_000_000,
		priceCurveMul = 1.0,
		unlock = { gold = 10_000_000_000_000_000, rebirths = 30 },
		secretPool = "T3",
		cinematicTier = 5,
	},
	{
		id = 11,
		idKey = "pack.ascendant.name",
		descKey = "pack.ascendant.desc",
		rarities = { "Awakened", "Crowned", "Sovereign", "Imperial", "Throne" },
		weightsPPM = { 550_000, 280_000, 130_000, 35_000, 5_000 },
		basePriceGold = 0,
		priceCurveMul = 1.0,
		unlock = { robux = true, devProductId = 0 }, -- ID später setzen
		secretPool = "T3",
		cinematicTier = 5,
	},
}

-- Secret-Pool Konfiguration: 1-in-X Chance pro Pull, unabhängig vom Pack-Roll.
local SecretChance: { [string]: number } = {
	T1 = 1 / 500_000,
	T2 = 1 / 2_500_000,
	T3 = 1 / 50_000_000,
}

-- Pity: nach N Pulls ohne ≥ 4th-best Rarity → garantierter 4th-best.
-- Best-Rarity hat KEIN Pity (Spec).
local function pityThreshold(packTier: number): number
	return math.max(50, 220 - packTier * 15)
end

return {
	list = Packs,
	byId = (function()
		local t: { [number]: PackDefinition } = {}
		for _, p in ipairs(Packs) do
			t[p.id] = p
		end
		return t
	end)(),
	secretChance = SecretChance,
	pityThreshold = pityThreshold,
}
