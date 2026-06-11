--!strict
-- EventGods — event-exclusive gods, only obtainable via BuyEventPack.
-- Registered into Gods.byId at load so temple production works correctly.
-- NOT added to Gods.byRarity so they never appear in regular packs.

local Gods = require(script.Parent.Gods)

export type EventGodDef = {
	id: string,
	rarityId: string,
	baseProduction: number,
	baseFaith: number,
	iconAssetId: string,
	eventId: string,
}

local list: { [string]: { EventGodDef } } = {
	summer_festival = {
		{ id = "Helios_Solari",   rarityId = "God",      baseProduction = 2500,  baseFaith = 800,   iconAssetId = "rbxassetid://0", eventId = "summer_festival" },
		{ id = "Demeter_Harvest", rarityId = "Goddess",  baseProduction = 2000,  baseFaith = 1200,  iconAssetId = "rbxassetid://0", eventId = "summer_festival" },
	},
	winter_solstice = {
		{ id = "Khione_Frost",    rarityId = "Archon",   baseProduction = 8000,  baseFaith = 3000,  iconAssetId = "rbxassetid://0", eventId = "winter_solstice" },
		{ id = "Boreas_Gale",     rarityId = "Universe", baseProduction = 6000,  baseFaith = 3500,  iconAssetId = "rbxassetid://0", eventId = "winter_solstice" },
	},
	divine_eclipse = {
		{ id = "Nyx_Shadow",      rarityId = "Eternal",  baseProduction = 30000, baseFaith = 12000, iconAssetId = "rbxassetid://0", eventId = "divine_eclipse" },
		{ id = "Erebus_Abyss",    rarityId = "Absolute", baseProduction = 25000, baseFaith = 15000, iconAssetId = "rbxassetid://0", eventId = "divine_eclipse" },
	},
}

-- Register in Gods.byId so TempleService can compute production for placed event gods.
-- Intentionally NOT added to Gods.byRarity → never pulled from regular packs.
for _, pool in pairs(list) do
	for _, def in ipairs(pool) do
		if not Gods.byId[def.id] then
			Gods.byId[def.id] = {
				id             = def.id,
				rarityId       = def.rarityId,
				baseProduction = def.baseProduction,
				baseFaith      = def.baseFaith,
				iconAssetId    = def.iconAssetId,
			}
		end
	end
end

return list
