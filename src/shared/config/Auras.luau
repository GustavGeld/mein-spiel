--!strict
-- Aura definitions, one per pack tier (1–10).
-- Unlocked when a player claims their first collection-row reward at that tier.
-- Higher tier = more impressive SelectionBox outline + PointLight glow.

export type AuraDef = {
	tier: number,
	color: Color3,
	lightBrightness: number,
	lightRange: number,
	selectionThickness: number,
	nameKey: string,
}

local function a(
	tier: number, r: number, g: number, b: number,
	brightness: number, range: number, thick: number
): AuraDef
	return {
		tier = tier,
		color = Color3.fromRGB(r, g, b),
		lightBrightness = brightness,
		lightRange = range,
		selectionThickness = thick,
		nameKey = "aura.tier" .. tostring(tier),
	}
end

local Auras: { [number]: AuraDef } = {
	[1]  = a(1,  170, 170, 170, 0.5,  8,  0.04),  -- silver
	[2]  = a(2,   80, 200,  90, 0.7, 10,  0.05),  -- green
	[3]  = a(3,   60, 130, 220, 0.9, 12,  0.05),  -- blue
	[4]  = a(4,  150,  60, 220, 1.1, 14,  0.06),  -- purple
	[5]  = a(5,  220, 170,  30, 1.3, 16,  0.06),  -- gold
	[6]  = a(6,  220,  50,  50, 1.5, 18,  0.07),  -- crimson
	[7]  = a(7,  255, 110,   0, 1.7, 20,  0.07),  -- orange
	[8]  = a(8,   30, 210, 230, 1.9, 22,  0.08),  -- cyan
	[9]  = a(9,  255,  40, 200, 2.1, 24,  0.08),  -- pink
	[10] = a(10, 255, 240,  80, 2.6, 28,  0.10),  -- divine
}

return Auras
