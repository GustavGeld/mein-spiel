--!strict
-- Fusion-Math — Erfolgswahrscheinlichkeit basierend auf eingesetzten Göttern.
-- Ab 5 = garantiert. Darunter steigt die Chance nichtlinear.

local Fusion = {}

-- count = wieviele gleiche Götter werden eingesetzt (2..5).
function Fusion.successChance(count: number): number
	if count <= 1 then return 0 end
	if count >= 5 then return 1.0 end
	-- 2 → 0.10, 3 → 0.35, 4 → 0.65
	local table = { [2] = 0.10, [3] = 0.35, [4] = 0.65 }
	return table[count] or 0.10
end

-- Bei einer fehlgeschlagenen Fusion unter 5 verschwinden alle eingesetzten Götter.
function Fusion.failConsumesAll(count: number): boolean
	return count < 5
end

return Fusion
