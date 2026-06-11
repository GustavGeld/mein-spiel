--!strict
-- Default schema. Bump `version` und schreibe Migrations bei Änderung.

export type GodEntry = {
	uid: string,
	id: string,        -- god identifier (e.g. "Zeus")
	rarityId: string,
	packTier: number,
	fusionRank: number,
	secret: boolean,
	locked: boolean,   -- true während Trade-Hold
}

export type Profile = {
	version: number,
	currencies: { gold: number, faith: number, offerings: number, gems: number, divinity: number },
	lifetime:   { gold: number, pulls: number, rebirths: number, rarestRarity: number },
	inventory:  {
		gods: { GodEntry },
		potions: { [string]: number },
		cosmetics: { [string]: boolean },
		eternalGods: { GodEntry },
	},
	unlocks:    {
		packs: { [string]: boolean },
		gamepasses: { [string]: boolean },
	},
	temple:     {
		tier: number,
		slots: { { godUid: string? } },
		upgrades: { production: number, slots: number, faith: number },
		pending: { [string]: { gold: number, faith: number, offerings: number } },
	},
	divinity:   {
		spent: number,
		tree: { [string]: { [string]: number } },
		echoStacks: number,
	},
	quests:     {
		daily: { [string]: any },
		weekly: { [string]: any },
		dayStamp: number,
		minute: { lastClaim: number },
		login: { streak: number, lastDay: number, claimed: boolean },
	},
	settings:   {
		language: string,
		tradeInvites: boolean,
		vfxQuality: string,
		reducedMotion: boolean,
		music: boolean,
		sfx: boolean,
	},
	social:     {
		friendsBoost: boolean,
		referrer: string?,
		codesRedeemed: { [string]: boolean },
	},
	season:       { id: string, score: number, claimed: boolean },
	collection:   { discovered: { [string]: boolean }, claimedRows: { [string]: boolean }, bestAuraTier: number },
	companion:    { skin: string, ability: string, ownedSkins: { [string]: boolean }, abilities: { [string]: boolean } },
	achievements: { claimed: { [string]: boolean } },
	flags:        { tutorialDone: boolean, firstSecret: boolean },
	pity:         { [string]: number }, -- per packId stored as string
	meta:         { createdAt: number, lastLogin: number, playtime: number },
}

local function default(): Profile
	return {
		version = 1,
		currencies = { gold = 100, faith = 0, offerings = 0, gems = 0, divinity = 0 },
		lifetime   = { gold = 0, pulls = 0, rebirths = 0, rarestRarity = 0 },
		inventory  = { gods = {}, potions = {}, cosmetics = {}, eternalGods = {} },
		unlocks    = {
			packs = { ["1"] = true },
			gamepasses = {},
		},
		temple     = {
			tier = 1,
			slots = { { godUid = nil }, { godUid = nil }, { godUid = nil } },
			upgrades = { production = 0, slots = 0, faith = 0 },
			pending = {} :: { [string]: { gold: number, faith: number } },
		},
		divinity   = {
			spent = 0,
			tree = {
				fortune = {}, wealth = {}, devotion = {}, ascension = {}, mythos = {},
			},
			echoStacks = 0,
		},
		quests     = {
			daily = {}, weekly = {},
			dayStamp = 0, weekStamp = 0,
			minute = { lastClaim = 0 },
			login = { streak = 0, lastDay = 0, claimed = false },
			freeRoll = { lastDay = 0 },
			rerollDay = 0,
		},
		settings   = {
			language = "en",
			tradeInvites = true,
			vfxQuality = "high",
			reducedMotion = false,
			music = true,
			sfx = true,
			companionEnabled = true,
		},
		social     = { friendsBoost = true, referrer = nil, codesRedeemed = {} },
		season       = { id = "S1", score = 0, claimed = false },
		collection   = { discovered = {}, claimedRows = {}, bestAuraTier = 0, activeAuraTier = 0 },
		companion    = { skin = "default", ability = "none", ownedSkins = {}, abilities = {} },
		achievements = { claimed = {} },
		flags        = { tutorialDone = false, firstSecret = false },
		pity       = {},
		meta       = { createdAt = 0, lastLogin = 0, playtime = 0 },
	}
end

return {
	default = default,
}
