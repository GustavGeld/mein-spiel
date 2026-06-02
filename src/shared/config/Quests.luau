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

Quests.byId = {} :: { [string]: QuestDef }
for _, def in ipairs(Quests.dailyPool) do
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

return Quests
