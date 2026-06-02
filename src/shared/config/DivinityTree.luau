--!strict
-- Divinity-Tree — permanente Upgrades, überleben Rebirths.
-- Struktur im Profil: profile.divinity.tree[branch][nodeKey] = level (number)
--
-- EconomyService und PackService lesen `wealth.goldGain`, `devotion.faithGain` etc.
-- direkt — Schlüssel hier nicht umbenennen, ohne dort mitzuziehen.

export type Node = {
	branch: string,
	key: string,
	labelKey: string,    -- Locale-Key
	descKey: string,     -- Locale-Key
	maxLevel: number,
	bonusPerLevel: number, -- als Dezimalbruch (0.02 = +2 %)
	-- Kosten: cost(level) gibt Divinity-Preis vom *nächsten* Levelup.
	cost: (level: number) -> number,
}

export type Branch = {
	id: string,
	labelKey: string,
	color: Color3,
	nodes: { Node },
}

local function quad(level: number): number
	-- 1, 4, 9, 16, 25, ...
	return (level + 1) ^ 2
end

local function tri(level: number): number
	-- 1, 3, 6, 10, 15, ...
	return ((level + 1) * (level + 2)) // 2
end

local function node(branch: string, key: string, labelKey: string, descKey: string,
	maxLevel: number, bonusPerLevel: number, costFn: (number) -> number): Node
	return {
		branch = branch, key = key,
		labelKey = labelKey, descKey = descKey,
		maxLevel = maxLevel,
		bonusPerLevel = bonusPerLevel,
		cost = costFn,
	}
end

local DivinityTree = {}

DivinityTree.branches = {
	{
		id = "fortune",
		labelKey = "divinity.fortune",
		color = Color3.fromRGB(255, 200, 80),
		nodes = {
			node("fortune", "luck", "divinity.fortune.luck", "divinity.fortune.luck.desc", 10, 0.02, quad),
		},
	},
	{
		id = "wealth",
		labelKey = "divinity.wealth",
		color = Color3.fromRGB(255, 215, 80),
		nodes = {
			node("wealth", "goldGain", "divinity.wealth.gold", "divinity.wealth.gold.desc", 10, 0.02, quad),
		},
	},
	{
		id = "devotion",
		labelKey = "divinity.devotion",
		color = Color3.fromRGB(200, 230, 255),
		nodes = {
			node("devotion", "faithGain", "divinity.devotion.faith", "divinity.devotion.faith.desc", 10, 0.02, quad),
		},
	},
	{
		id = "ascension",
		labelKey = "divinity.ascension",
		color = Color3.fromRGB(255, 130, 230),
		nodes = {
			node("ascension", "production", "divinity.ascension.production", "divinity.ascension.production.desc", 10, 0.02, quad),
		},
	},
	{
		id = "mythos",
		labelKey = "divinity.mythos",
		color = Color3.fromRGB(120, 230, 200),
		nodes = {
			node("mythos", "secret", "divinity.mythos.secret", "divinity.mythos.secret.desc", 5, 0.03, tri),
		},
	},
} :: { Branch }

-- Index nach Branch-ID
DivinityTree.byBranch = {} :: { [string]: Branch }
DivinityTree.nodeByKey = {} :: { [string]: Node } -- key = "<branch>.<node>"
for _, branch in ipairs(DivinityTree.branches) do
	DivinityTree.byBranch[branch.id] = branch
	for _, n in ipairs(branch.nodes) do
		DivinityTree.nodeByKey[branch.id .. "." .. n.key] = n
	end
end

function DivinityTree.getLevel(profile: any, branchId: string, nodeKey: string): number
	local tree = profile and profile.divinity and profile.divinity.tree
	if not tree or not tree[branchId] then return 0 end
	return tree[branchId][nodeKey] or 0
end

return DivinityTree
