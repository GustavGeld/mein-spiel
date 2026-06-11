--!strict
-- Rebirth-Schwellen & Divinity-Reward-Formel.
--
-- Schwelle steigt quadratisch, Divinity-Reward linear → frühe Rebirths fühlen sich
-- billig an, späte Rebirths brauchen länger, aber die Divinity-Belohnung skaliert mit.

local Rebirth = {}

-- Mindest-Gold um den n-ten Rebirth (n = aktuelle Anzahl bereits gemachter Rebirths) zu zünden.
-- Beispiele:  n=0 → 1.0M,  n=1 → 2.25M,  n=2 → 4.0M,  n=3 → 6.25M,  n=5 → 12.25M
function Rebirth.threshold(currentRebirths: number): number
	local n = math.max(0, currentRebirths)
	return 1000000 * (1 + n * 0.5) ^ 2
end

-- Wie viel Divinity bekommt der Spieler beim Rebirth?
-- Mindestens 1 + Rebirth-Stufe. Extra +1 pro 25 % Überschreitung der Schwelle (max +4).
function Rebirth.divinityReward(currentRebirths: number, currentGold: number): number
	local threshold = Rebirth.threshold(currentRebirths)
	if currentGold < threshold then return 0 end
	local base = 1 + currentRebirths
	local over = math.floor((currentGold - threshold) / threshold * 4)
	return base + math.clamp(over, 0, 4)
end

-- Diese Top-Level-Felder werden beim Rebirth zurückgesetzt (Default-Werte aus DefaultProfile).
-- Alles andere bleibt — insbesondere divinity, gems, cosmetics, gamepasses, collection.
Rebirth.RESET = {
	-- Spieler startet nach Rebirth mit 500 Gold, damit er sofort ein Pack kaufen kann.
	currencies = function(c) c.gold = 500; c.faith = 0; c.offerings = 0 end,
	inventory  = function(i) i.gods = {} end,
	temple     = function(t)
		t.tier = 1
		t.slots = { { godUid = nil }, { godUid = nil }, { godUid = nil } }
		t.upgrades = { production = 0, slots = 0, faith = 0 }
	end,
	unlocks    = function(u) u.packs = { ["1"] = true } end,
	pity       = function() return {} end, -- ersetzen statt mutieren
}

return Rebirth
