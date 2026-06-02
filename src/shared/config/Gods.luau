--!strict
-- God-Roster pro Rarity. Beim Pull wählt das System nach Rarity zufällig einen Gott aus dem Pool.
--
-- `iconAssetId` ist optional — fehlt sie, zeigen Karten ein Initial-Fallback ("H" etc.).

export type GodDef = {
	id: string,
	rarityId: string,
	baseProduction: number, -- Gold/sec (vor Multipliern)
	baseFaith: number,      -- Faith/sec
	iconAssetId: string?,   -- rbxassetid://… (optional)
}

local function g(id: string, rarityId: string, baseProduction: number, baseFaith: number, iconAssetId: string?): GodDef
	return {
		id = id, rarityId = rarityId,
		baseProduction = baseProduction, baseFaith = baseFaith,
		iconAssetId = iconAssetId,
	}
end

local Gods: { GodDef } = {
	-- Pack 1
	g("Hermes_Apprentice", "Common", 1, 0, "rbxassetid://98144075868595"),
	g("Vesta_Spark",       "Common", 1, 0, "rbxassetid://133594920253831"),
	g("Pan_Whistler",      "Common", 1, 0, "rbxassetid://79961604323478"),
	g("Hermes_Messenger",  "Uncommon", 3, 0, "rbxassetid://104218688969961"),
	g("Vesta_Flame",       "Uncommon", 3, 0, "rbxassetid://104684325360066"),
	g("Pan_Reveler",       "Uncommon", 3, 0, "rbxassetid://134751056616904"),
	g("Apollo_Lyric",      "Rare", 9, 0, "rbxassetid://100806210069088"),
	g("Diana_Hunter",      "Rare", 9, 0, "rbxassetid://128465423120884"),
	g("Mars_Recruit",      "Rare", 9, 0, "rbxassetid://127968083244338"),
	g("Athena_Scribe",     "Epic", 28, 1, "rbxassetid://119399772880381"),
	g("Poseidon_Tidewatcher", "Epic", 28, 1, "rbxassetid://90750280568887"),
	g("Hephaestus_Smith",  "Epic", 28, 1, "rbxassetid://111828652368891"),
	g("Hades_Shadekeeper", "Unique", 110, 3, "rbxassetid://103584941519150"),
	g("Persephone_Bloom",  "Unique", 110, 3, "rbxassetid://73839545299337"),
	g("Aphrodite_Charm",   "Unique", 110, 3, "rbxassetid://136473192062610"),
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
