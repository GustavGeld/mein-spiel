--!strict
-- Quest-Pool. Jeder Eintrag definiert Trigger-Type, Target und Reward.
--
-- Trigger-Types:
--   "pulls"        — N beliebige Packs ziehen
--   "rarity"       — N Götter mit min. Rarity-Index ziehen (param = minRarityIndex)
--   "secret"       — N Secrets ziehen
--   "gold_spent"   — N Gold ausgeben
--   "place"        — N Götter im Tempel platzieren
--
-- Reward: { currency: "gold"|"faith"|"gems", amount: number }

export type Reward = { currency: string, amount: number }

export type QuestDef = {
	id: string,
	type: string,
	target: number,
	param: number?,        -- für rarity: minRarityIndex
	nameKey: string,
	descKey: string,
	reward: Reward,
}

local function q(id: string, t: string, target: number, param: number?,
	nameKey: string, descKey: string, reward: Reward): QuestDef
	return {
		id = id, type = t, target = target, param = param,
		nameKey = nameKey, descKey = descKey, reward = reward,
	}
end

local Quests = {}

-- Pool aus dem täglich 3 zufällig gezogen werden.
Quests.dailyPool = {
	q("pulls_5",       "pulls",      5,   nil, "quest.pulls5.name",      "quest.pulls5.desc",
		{ currency = "gold", amount = 500 }),
	q("pulls_25",      "pulls",     25,   nil, "quest.pulls25.name",     "quest.pulls25.desc",
		{ currency = "gold", amount = 2500 }),
	q("rarity_rare",   "rarity",     3,   3,   "quest.rarityRare.name",  "quest.rarityRare.desc",
		{ currency = "gold", amount = 1000 }),
	q("rarity_epic",   "rarity",     1,   4,   "quest.rarityEpic.name",  "quest.rarityEpic.desc",
		{ currency = "gems", amount = 5 }),
	q("gold_spent_5k", "gold_spent", 5000, nil, "quest.spend5k.name",    "quest.spend5k.desc",
		{ currency = "gold", amount = 250 }),
	q("place_3",       "place",      3,   nil, "quest.place3.name",      "quest.place3.desc",
		{ currency = "faith", amount = 50 }),
	q("secret_1",      "secret",     1,   nil, "quest.secret1.name",     "quest.secret1.desc",
		{ currency = "gems", amount = 25 }),
} :: { QuestDef }

-- Wöchentlicher Pool: 3 werden am Montag deterministisch gezogen.
Quests.weeklyPool = {
	q("w_pulls_50",    "pulls",      50,  nil, "quest.wpulls50.name",   "quest.wpulls50.desc",
		{ currency = "gems",  amount = 15 }),
	q("w_pulls_200",   "pulls",     200,  nil, "quest.wpulls200.name",  "quest.wpulls200.desc",
		{ currency = "gems",  amount = 50 }),
	q("w_rarity_epic", "rarity",     5,   4,   "quest.wepic5.name",     "quest.wepic5.desc",
		{ currency = "gems",  amount = 20 }),
	q("w_gold_50k",    "gold_spent", 50000, nil,"quest.wgold50k.name",  "quest.wgold50k.desc",
		{ currency = "gold",  amount = 10000 }),
	q("w_place_10",    "place",      10,  nil, "quest.wplace10.name",   "quest.wplace10.desc",
		{ currency = "faith", amount = 500 }),
	q("w_rebirth",     "rebirths",   1,   nil, "quest.wrebirth.name",   "quest.wrebirth.desc",
		{ currency = "gems",  amount = 30 }),
} :: { QuestDef }

Quests.byId = {} :: { [string]: QuestDef }
for _, def in ipairs(Quests.dailyPool) do
	Quests.byId[def.id] = def
end
for _, def in ipairs(Quests.weeklyPool) do
	Quests.byId[def.id] = def
end

-- Login-Streak Belohnungen (Tag 1..7+, dann Loop).
Quests.loginRewards = {
	{ currency = "gold", amount = 500 },
	{ currency = "gold", amount = 1000 },
	{ currency = "gold", amount = 2000 },
	{ currency = "gems", amount = 5 },
	{ currency = "gold", amount = 5000 },
	{ currency = "gold", amount = 10000 },
	{ currency = "gems", amount = 15 },
} :: { Reward }

-- Minute-Reward (alle 60s)
Quests.minuteReward = { currency = "gems", amount = 1 } :: Reward

-- UTC-Wochennummer (Montag = Anfang, basiert auf Montag-Offset).
function Quests.utcWeek(): number
	return math.floor((os.time() + 3 * 86400) / (7 * 86400))
end

-- Pickt N zufällige Quests aus dem Pool (deterministisch via rng).
function Quests.pickDailies(rng: Random, count: number): { QuestDef }
	local pool = table.clone(Quests.dailyPool)
	local out = {}
	for i = 1, math.min(count, #pool) do
		local idx = rng:NextInteger(1, #pool)
		table.insert(out, pool[idx])
		table.remove(pool, idx)
	end
	return out
end

-- Pickt N zufällige Weekly-Quests (deterministisch via rng).
function Quests.pickWeeklies(rng: Random, count: number): { QuestDef }
	local pool = table.clone(Quests.weeklyPool)
	local out = {}
	for i = 1, math.min(count, #pool) do
		local idx = rng:NextInteger(1, #pool)
		table.insert(out, pool[idx])
		table.remove(pool, idx)
	end
	return out
end

return Quests
