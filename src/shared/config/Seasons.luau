--!strict
-- Seasons — Konfiguration für wöchentliche Saisons.
-- Saisons laufen Montag 00:00 UTC bis Sonntag 23:59 UTC.
-- Score = lifetime.pulls + lifetime.rebirths * 500

local Seasons = {}

-- End-of-Season Reward-Tiers (Platzierung → Gems)
-- Typ: { { minRank, maxRank, gems, labelKey } }
Seasons.rewardTiers = {
	{ minRank = 1,  maxRank = 1,   gems = 1000, labelKey = "season.tier.champion" },
	{ minRank = 2,  maxRank = 3,   gems = 500,  labelKey = "season.tier.legend"   },
	{ minRank = 4,  maxRank = 10,  gems = 200,  labelKey = "season.tier.elite"    },
	{ minRank = 11, maxRank = 50,  gems = 100,  labelKey = "season.tier.veteran"  },
	{ minRank = 51, maxRank = 100, gems = 25,   labelKey = "season.tier.rival"    },
}

-- Saison-Score aus Profil-Lifetime berechnen.
-- Rebirths sind 500× gewichtet, da sie viel schwerer zu erreichen sind.
function Seasons.calcScore(lifetime: { pulls: number, rebirths: number }): number
	-- nil-safe: Snapshot kann pulls fehlen wenn RequestProfile noch nicht abgeschlossen
	return (lifetime.pulls or 0) + (lifetime.rebirths or 0) * 500
end

-- Aktuelle Saison-ID (wochenbasiert, Montag UTC).
-- Woche 0 = Unix-Epoche Donnerstag; wir verschieben um 3 Tage, damit Mo = Wochenanfang.
function Seasons.currentId(): string
	local week = math.floor((os.time() + 3 * 86400) / (7 * 86400))
	return "W" .. week
end

-- Sekunden bis zum Ende der aktuellen Saison (nächster Montag UTC 00:00).
function Seasons.secondsRemaining(): number
	local t = os.time() + 3 * 86400 -- Montag-Offset
	local weekSec = 7 * 86400
	return weekSec - (t % weekSec)
end

-- Reward-Tier für einen Rang (nil wenn nicht qualifiziert).
function Seasons.tierForRank(rank: number): { gems: number, labelKey: string }?
	for _, tier in ipairs(Seasons.rewardTiers) do
		if rank >= tier.minRank and rank <= tier.maxRank then
			return tier
		end
	end
	return nil
end

-- Lesbare Zeit-Darstellung: "3d 14h" oder "2h 30m" usw.
function Seasons.formatTime(secs: number): string
	secs = math.max(0, math.floor(secs))
	local days  = math.floor(secs / 86400)
	local hours = math.floor((secs % 86400) / 3600)
	local mins  = math.floor((secs % 3600) / 60)
	if days >= 1 then
		return string.format("%dd %dh", days, hours)
	elseif hours >= 1 then
		return string.format("%dh %dm", hours, mins)
	else
		return string.format("%dm", math.max(1, mins))
	end
end

return Seasons
