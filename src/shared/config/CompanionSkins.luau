--!strict
-- Companion skin definitions for Aion.
-- Color/material skins recolor the procedural orb.
-- Model skins: place a Model named after the skin id inside
--   ReplicatedStorage.AionSkins  (create this folder in Studio).
-- The model is used as-is; color/material fields serve as fallback + card icon only.
-- New skins added here appear in CompanionPanel automatically.

export type SkinDef = {
	id: string,
	name: string,
	color: Color3,
	glowColor: Color3,
	material: Enum.Material,
	gemCost: number,   -- 0 = free / default
}

local function sk(id, name, color, glow, mat, gems): SkinDef
	return { id = id, name = name, color = color, glowColor = glow, material = mat, gemCost = gems }
end

-- All skins are free (gemCost = 0).
-- To add a custom 3D model for any skin, place a Model with the matching id
-- as its name inside ReplicatedStorage > AionSkins in Studio.
local list: { SkinDef } = {
	sk("default",  "Aion",     Color3.fromRGB(170, 205, 255), Color3.fromRGB(170, 205, 255), Enum.Material.Neon,          0),
	sk("ember",    "Ember",    Color3.fromRGB(255, 110, 40),  Color3.fromRGB(255, 110, 40),  Enum.Material.Neon,          0),
	sk("shadow",   "Shadow",   Color3.fromRGB(90,  70, 150),  Color3.fromRGB(120, 80, 200),  Enum.Material.SmoothPlastic, 0),
	sk("crystal",  "Crystal",  Color3.fromRGB(180, 240, 235), Color3.fromRGB(180, 240, 235), Enum.Material.Glass,         0),
	sk("aurum",    "Aurum",    Color3.fromRGB(255, 210, 55),  Color3.fromRGB(255, 210, 55),  Enum.Material.Neon,          0),
	sk("verdant",  "Verdant",  Color3.fromRGB(70,  200, 100), Color3.fromRGB(70,  200, 100), Enum.Material.SmoothPlastic, 0),
	sk("void",     "Void",     Color3.fromRGB(30,  20,  50),  Color3.fromRGB(100, 50, 180),  Enum.Material.Neon,          0),
	sk("divine",   "Divine",   Color3.fromRGB(255, 180, 240), Color3.fromRGB(255, 180, 240), Enum.Material.Neon,          0),
	sk("storm",    "Storm",    Color3.fromRGB(80, 140, 220),  Color3.fromRGB(100, 180, 255), Enum.Material.Neon,          0),
	sk("inferno",  "Inferno",  Color3.fromRGB(220, 50, 20),   Color3.fromRGB(255, 80, 20),   Enum.Material.Neon,          0),
	sk("frost",    "Frost",    Color3.fromRGB(180, 225, 255), Color3.fromRGB(200, 240, 255), Enum.Material.Ice,           0),
	sk("nature",   "Nature",   Color3.fromRGB(55, 160, 80),   Color3.fromRGB(80, 210, 110),  Enum.Material.Grass,         0),
	sk("celestial","Celestial",Color3.fromRGB(255, 240, 140), Color3.fromRGB(255, 255, 180), Enum.Material.Neon,          0),
	sk("abyssal",  "Abyssal",  Color3.fromRGB(15,  10,  30),  Color3.fromRGB(60,  20, 120),  Enum.Material.Neon,          0),
	sk("radiant",  "Radiant",  Color3.fromRGB(255, 255, 220), Color3.fromRGB(255, 255, 255), Enum.Material.Neon,          0),
	sk("titan",    "Titan",    Color3.fromRGB(160, 130, 90),  Color3.fromRGB(200, 170, 110), Enum.Material.Metal,         0),
}

local byId: { [string]: SkinDef } = {}
for _, s in ipairs(list) do
	byId[s.id] = s
end

return { list = list, byId = byId }
