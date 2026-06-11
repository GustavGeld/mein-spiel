--!strict
-- Limited-time event definitions.
-- Events are activated by admin commands: /event start <id> <durationMinutes>
-- Each event highlights a specific pack tier and shows a banner in the shop.

export type EventPack = {
	tier: number,
	priceGold: number,
	pullCount: number,
	discountPct: number, -- 0 = no discount, 0.2 = 20% cheaper than normal pack price
}

export type EventDef = {
	id: string,
	nameKey: string,
	descKey: string,
	iconId: string,
	color: Color3,
	pack: EventPack,
}

local LimitedEvents: { [string]: EventDef } = {
	["summer_festival"] = {
		id       = "summer_festival",
		nameKey  = "event.summerFestival.name",
		descKey  = "event.summerFestival.desc",
		iconId   = "rbxassetid://0",
		color    = Color3.fromRGB(255, 185, 30),
		pack     = { tier = 3, priceGold = 24000, pullCount = 5, discountPct = 0.20 },
	},
	["winter_solstice"] = {
		id       = "winter_solstice",
		nameKey  = "event.winterSolstice.name",
		descKey  = "event.winterSolstice.desc",
		iconId   = "rbxassetid://0",
		color    = Color3.fromRGB(100, 180, 255),
		pack     = { tier = 5, priceGold = 60000, pullCount = 5, discountPct = 0.25 },
	},
	["divine_eclipse"] = {
		id       = "divine_eclipse",
		nameKey  = "event.divineEclipse.name",
		descKey  = "event.divineEclipse.desc",
		iconId   = "rbxassetid://0",
		color    = Color3.fromRGB(180, 60, 220),
		pack     = { tier = 8, priceGold = 140000, pullCount = 5, discountPct = 0.30 },
	},
}

return LimitedEvents
