--!strict
-- CompanionAbilities — Aion's purchasable passive abilities.

export type AbilityDef = {
	id: string,
	gemCost: number,
	nameKey: string,
	descKey: string,
	iconEmoji: string,
	color: Color3,
}

local list: { AbilityDef } = {
	{
		id        = "seeker",
		gemCost   = 25,
		nameKey   = "ability.seeker.name",
		descKey   = "ability.seeker.desc",
		iconEmoji = "🔍",
		color     = Color3.fromRGB(100, 200, 255),
	},
	{
		id        = "guardian",
		gemCost   = 50,
		nameKey   = "ability.guardian.name",
		descKey   = "ability.guardian.desc",
		iconEmoji = "🛡",
		color     = Color3.fromRGB(120, 220, 120),
	},
	{
		id        = "archivist",
		gemCost   = 75,
		nameKey   = "ability.archivist.name",
		descKey   = "ability.archivist.desc",
		iconEmoji = "📚",
		color     = Color3.fromRGB(255, 200, 100),
	},
}

local byId: { [string]: AbilityDef } = {}
for _, def in ipairs(list) do byId[def.id] = def end

return { list = list, byId = byId }
