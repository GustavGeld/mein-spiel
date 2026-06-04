--!strict
-- Potions — temporäre Boosts, gekauft mit Gems. Dauer: 10 Minuten.

export type PotionDef = {
	id: string,
	effect: string,        -- "luck" | "gold" | "faith" | "prod" | "offerings" | "autoRoll"
	multiplier: number,    -- Multiplikator (1 = nur aktivieren, z.B. autoRoll)
	gemsCost: number,
	duration: number,      -- Sekunden
	nameKey: string,
	descKey: string,
	color: Color3,
}

local function c(r: number, g: number, b: number) return Color3.fromRGB(r, g, b) end

local list: { PotionDef } = {
	{
		id = "luck",       effect = "luck",       multiplier = 1.5, gemsCost = 50,
		duration = 600,    nameKey = "potion.luck.name",       descKey = "potion.luck.desc",
		color = c(200, 255, 120),
	},
	{
		id = "gold",       effect = "gold",       multiplier = 2.0, gemsCost = 75,
		duration = 600,    nameKey = "potion.gold.name",       descKey = "potion.gold.desc",
		color = c(255, 215, 60),
	},
	{
		id = "faith",      effect = "faith",      multiplier = 2.0, gemsCost = 60,
		duration = 600,    nameKey = "potion.faith.name",      descKey = "potion.faith.desc",
		color = c(180, 220, 255),
	},
	{
		id = "prod",       effect = "prod",       multiplier = 2.0, gemsCost = 80,
		duration = 600,    nameKey = "potion.prod.name",       descKey = "potion.prod.desc",
		color = c(255, 160, 80),
	},
	{
		id = "offerings",  effect = "offerings",  multiplier = 2.0, gemsCost = 65,
		duration = 600,    nameKey = "potion.offerings.name",  descKey = "potion.offerings.desc",
		color = c(200, 140, 255),
	},
	{
		id = "autoRoll",   effect = "autoRoll",   multiplier = 1,   gemsCost = 100,
		duration = 600,    nameKey = "potion.autoRoll.name",   descKey = "potion.autoRoll.desc",
		color = c(120, 230, 200),
	},
}

local byId: { [string]: PotionDef } = {}
for _, p in ipairs(list) do
	byId[p.id] = p
end

return { list = list, byId = byId }
