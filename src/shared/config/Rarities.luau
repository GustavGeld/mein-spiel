--!strict
-- Rarity-Definitionen aller 10 Packs + Secret-Pools.
-- index ist global und steigt mit Stärke. Display-Name via Locale-Key.

export type Rarity = {
	id: string,
	index: number,
	packTier: number, -- 1..10, 0 = Secret, 11 = Ascendant (Robux)
	color: Color3,
	gradient: boolean?, -- animierter Rainbow für Top-Tiers
	nameKey: string, -- locale key, z.B. "rarity.common"
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function r(id: string, packTier: number, color: Color3, gradient: boolean?): Rarity
	return {
		id = id,
		index = 0, -- wird unten gesetzt
		packTier = packTier,
		color = color,
		gradient = gradient,
		nameKey = "rarity." .. string.lower(id):gsub("[%s%-]", "_"),
	}
end

local Rarities: { Rarity } = {
	-- Pack 1
	r("Common", 1, c(184, 184, 184)),
	r("Uncommon", 1, c(45, 211, 111)),
	r("Rare", 1, c(45, 135, 224)),
	r("Epic", 1, c(162, 61, 224)),
	r("Unique", 1, c(255, 170, 0)),
	-- Pack 2
	r("Elite", 2, c(120, 200, 255)),
	r("Heroic", 2, c(255, 120, 80)),
	r("RisingStar", 2, c(255, 200, 80)),
	r("Legendary", 2, c(255, 160, 30)),
	r("Mythic", 2, c(224, 53, 61)),
	-- Pack 3
	r("Immortal", 3, c(150, 220, 220)),
	r("DemiGod", 3, c(220, 180, 100)),
	r("Valkyrie", 3, c(180, 230, 255)),
	r("God", 3, c(255, 220, 100)),
	r("Goddess", 3, c(255, 102, 204)),
	-- Pack 4
	r("Ascended", 4, c(180, 180, 255)),
	r("Ancient", 4, c(120, 90, 60)),
	r("HighTier", 4, c(200, 150, 255)),
	r("Cosmic", 4, c(120, 80, 255)),
	r("Celestial", 4, c(255, 240, 200), true),
	-- Pack 5
	r("Astral", 5, c(140, 200, 255)),
	r("Nebula", 5, c(200, 120, 255)),
	r("Galaxy", 5, c(80, 80, 200)),
	r("Universe", 5, c(60, 60, 160)),
	r("Archon", 5, c(255, 100, 255), true),
	-- Pack 6
	r("Chrono", 6, c(180, 255, 230)),
	r("Temporal", 6, c(150, 255, 200)),
	r("Dimensional", 6, c(100, 220, 220)),
	r("Spatial", 6, c(80, 200, 255)),
	r("Divine", 6, c(255, 255, 180), true),
	-- Pack 7
	r("Luminary", 7, c(255, 240, 150)),
	r("Seraphim", 7, c(255, 220, 200)),
	r("Sacred", 7, c(255, 200, 220)),
	r("Exalted", 7, c(255, 180, 80)),
	r("Radiant", 7, c(255, 255, 255), true),
	-- Pack 8
	r("Timeless", 8, c(180, 220, 255)),
	r("Infinite", 8, c(120, 200, 255)),
	r("Boundless", 8, c(100, 180, 255)),
	r("Absolute", 8, c(255, 255, 255)),
	r("Eternal", 8, c(255, 230, 100), true),
	-- Pack 9
	r("Abyssal", 9, c(40, 40, 80)),
	r("Void", 9, c(20, 20, 40)),
	r("Eldritch", 9, c(80, 40, 120)),
	r("Chaos", 9, c(160, 30, 30)),
	r("Primordial", 9, c(255, 80, 80), true),
	-- Pack 10
	r("Singularity", 10, c(255, 255, 255), true),
	r("Transcendental", 10, c(220, 180, 255), true),
	r("Omnipotent", 10, c(255, 215, 0), true),
	r("Zenith", 10, c(255, 100, 200), true),
	r("Beyond", 10, c(0, 0, 0), true),
	-- Ascendant (Robux-only)
	r("Awakened", 11, c(255, 200, 100), true),
	r("Crowned", 11, c(255, 180, 80), true),
	r("Sovereign", 11, c(255, 140, 60), true),
	r("Imperial", 11, c(200, 50, 50), true),
	r("Throne", 11, c(255, 255, 255), true),
	-- Secret Pools
	r("Secret_T1", 0, c(255, 100, 255), true),
	r("Secret_T2", 0, c(0, 255, 200), true),
	r("Secret_T3", 0, c(255, 255, 255), true),
}

for i, rarity in ipairs(Rarities) do
	rarity.index = i
end

local byId: { [string]: Rarity } = {}
for _, rarity in ipairs(Rarities) do
	byId[rarity.id] = rarity
end

return {
	list = Rarities,
	byId = byId,
}
