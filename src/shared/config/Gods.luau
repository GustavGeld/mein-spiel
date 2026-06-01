--!strict
-- God-Roster pro Rarity. Beim Pull wählt das System nach Rarity zufällig einen Gott aus dem Pool.
-- Vorerst minimale Platzhalter-Listen (3 pro Rarity). Spätere Updates erweitern den Roster.

export type GodDef = {
	id: string,
	rarityId: string,
	baseProduction: number, -- Gold/sec (vor Multipliern)
	baseFaith: number,      -- Faith/sec
}

local function g(id: string, rarityId: string, baseProduction: number, baseFaith: number): GodDef
	return { id = id, rarityId = rarityId, baseProduction = baseProduction, baseFaith = baseFaith }
end

local Gods: { GodDef } = {
	-- Pack 1
	g("Hermes_Apprentice", "Common", 1, 0),
	g("Vesta_Spark", "Common", 1, 0),
	g("Pan_Whistler", "Common", 1, 0),
	g("Hermes_Messenger", "Uncommon", 3, 0),
	g("Vesta_Flame", "Uncommon", 3, 0),
	g("Pan_Reveler", "Uncommon", 3, 0),
	g("Apollo_Lyric", "Rare", 9, 0),
	g("Diana_Hunter", "Rare", 9, 0),
	g("Mars_Recruit", "Rare", 9, 0),
	g("Athena_Scribe", "Epic", 28, 1),
	g("Poseidon_Tidewatcher", "Epic", 28, 1),
	g("Hephaestus_Smith", "Epic", 28, 1),
	g("Hades_Shadekeeper", "Unique", 110, 3),
	g("Persephone_Bloom", "Unique", 110, 3),
	g("Aphrodite_Charm", "Unique", 110, 3),
}

local byId: { [string]: GodDef } = {}
local byRarity: { [string]: { GodDef } } = {}
for _, def in ipairs(Gods) do
	byId[def.id] = def
	byRarity[def.rarityId] = byRarity[def.rarityId] or {}
	table.insert(byRarity[def.rarityId], def)
end

-- Secret Pools (Platzhalter; spätere Pulls können hier echte Secret-Götter hinzufügen).
byRarity["Secret_T1"] = { g("Echo_Anomaly", "Secret_T1", 500, 25) }
byRarity["Secret_T2"] = { g("Mirror_Anomaly", "Secret_T2", 5000, 250) }
byRarity["Secret_T3"] = { g("Origin_Anomaly", "Secret_T3", 50000, 2500) }

return {
	list = Gods,
	byId = byId,
	byRarity = byRarity,
}
