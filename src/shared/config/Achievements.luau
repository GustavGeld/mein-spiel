--!strict
-- Achievements — einmalige Meilensteine mit Gems-Belohnung.
-- Progress wird zur Claim-Zeit aus bestehenden Profil-Feldern berechnet.
-- Kein separater Counter nötig (außer "fusionRank" → max FusionRank im Inventar).

export type AchievementDef = {
	id: string,
	type: string,    -- "pulls" | "rebirths" | "lifetime_gold" | "collection" | "fusion_rank" | "secrets"
	target: number,
	gems: number,
	nameKey: string,
	descKey: string,
}

local function a(id: string, atype: string, target: number, gems: number, nk: string, dk: string): AchievementDef
	return { id = id, type = atype, target = target, gems = gems, nameKey = nk, descKey = dk }
end

local list: { AchievementDef } = {
	-- Pulls
	a("first_pull",    "pulls",        1,       10,  "ach.first_pull.name",    "ach.first_pull.desc"),
	a("pulls_100",     "pulls",        100,     25,  "ach.pulls_100.name",     "ach.pulls_100.desc"),
	a("pulls_1000",    "pulls",        1000,    100, "ach.pulls_1000.name",    "ach.pulls_1000.desc"),
	a("pulls_10000",   "pulls",        10000,   500, "ach.pulls_10000.name",   "ach.pulls_10000.desc"),
	-- Rebirths
	a("first_rebirth", "rebirths",     1,       50,  "ach.first_rebirth.name", "ach.first_rebirth.desc"),
	a("rebirths_5",    "rebirths",     5,       150, "ach.rebirths_5.name",    "ach.rebirths_5.desc"),
	a("rebirths_25",   "rebirths",     25,      500, "ach.rebirths_25.name",   "ach.rebirths_25.desc"),
	-- Lifetime Gold
	a("gold_1m",       "lifetime_gold", 1e6,    50,  "ach.gold_1m.name",       "ach.gold_1m.desc"),
	a("gold_100m",     "lifetime_gold", 1e8,    200, "ach.gold_100m.name",     "ach.gold_100m.desc"),
	a("gold_1b",       "lifetime_gold", 1e9,    1000,"ach.gold_1b.name",       "ach.gold_1b.desc"),
	-- Collection (Entdeckungen)
	a("collection_10", "collection",   10,      30,  "ach.collection_10.name", "ach.collection_10.desc"),
	a("collection_50", "collection",   50,      150, "ach.collection_50.name", "ach.collection_50.desc"),
	a("collection_100","collection",   100,     400, "ach.collection_100.name","ach.collection_100.desc"),
	-- Fusion Rank (höchster Rank eines Gottes im Inventar)
	a("fusion_rank1",  "fusion_rank",  1,       25,  "ach.fusion_rank1.name",  "ach.fusion_rank1.desc"),
	a("fusion_rank5",  "fusion_rank",  5,       200, "ach.fusion_rank5.name",  "ach.fusion_rank5.desc"),
	-- Secrets
	a("first_secret",  "secrets",      1,       100, "ach.first_secret.name",  "ach.first_secret.desc"),
	a("secrets_3",     "secrets",      3,       300, "ach.secrets_3.name",     "ach.secrets_3.desc"),
}

local byId: { [string]: AchievementDef } = {}
for _, a2 in ipairs(list) do
	byId[a2.id] = a2
end

return { list = list, byId = byId }
