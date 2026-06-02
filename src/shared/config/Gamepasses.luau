--!strict
-- Gamepass + Dev Product Registry.
--
-- WICHTIG: Die `robloxId`-Werte sind initial 0 (Platzhalter).
-- Im Creator Dashboard pro Asset eine echte ID erstellen und hier eintragen.
-- Sobald `robloxId > 0` ist, kann der Pass / das Produkt im Shop gekauft werden.
--
-- Die `flag`-Werte landen in `profile.unlocks.gamepasses[flag] = true`
-- und werden von EconomyService.getMultiplier / PackService / TempleService gelesen.

export type Gamepass = {
	id: string,            -- intern eindeutig (Snake_case)
	robloxId: number,      -- Roblox Asset ID (0 = noch nicht angelegt)
	flag: string,          -- Schlüssel in profile.unlocks.gamepasses
	nameKey: string,
	descKey: string,
	priceRobux: number,    -- nur Anzeige; echter Preis kommt von Roblox
	color: Color3,         -- Card-Akzent
	category: "boost" | "convenience" | "utility",
}

export type DevProduct = {
	id: string,
	robloxId: number,
	nameKey: string,
	descKey: string,
	priceRobux: number,
	-- Was gibt das Produkt? Wird in GamepassService.processReceipt ausgewertet.
	grant: { currency: string?, amount: number?, potion: string? },
	color: Color3,
}

local function gp(id, flag, robloxId, robux, nameKey, descKey, color, category): Gamepass
	return {
		id = id, flag = flag, robloxId = robloxId, priceRobux = robux,
		nameKey = nameKey, descKey = descKey, color = color, category = category,
	}
end

local function dp(id, robloxId, robux, nameKey, descKey, grant, color): DevProduct
	return {
		id = id, robloxId = robloxId, priceRobux = robux,
		nameKey = nameKey, descKey = descKey, grant = grant, color = color,
	}
end

local Gamepasses = {
	-- ─── Permanent Gameplay Boosts ──────────────────────────────────────────
	gp("x2Gold",       "x2Gold",       1861826121, 199, "gamepass.x2Gold.name",       "gamepass.x2Gold.desc",       Color3.fromRGB(255, 215, 80),  "boost"),
	gp("x2Faith",      "x2Faith",      1861826122, 199, "gamepass.x2Faith.name",      "gamepass.x2Faith.desc",      Color3.fromRGB(200, 230, 255), "boost"),
	gp("x2Offerings",  "x2Offerings",  1865694694, 249, "gamepass.x2Offerings.name",  "gamepass.x2Offerings.desc",  Color3.fromRGB(255, 180, 120), "boost"),
	gp("x2Luck",       "x2Luck",       1866648632, 349, "gamepass.x2Luck.name",       "gamepass.x2Luck.desc",       Color3.fromRGB(180, 240, 140), "boost"),
	-- ─── Convenience ────────────────────────────────────────────────────────
	gp("autoRoll",     "autoRoll",     1862489614, 299, "gamepass.autoRoll.name",     "gamepass.autoRoll.desc",     Color3.fromRGB(120, 200, 255), "convenience"),
	gp("skipFast",     "skipFast",     1866878620, 199, "gamepass.skipFast.name",     "gamepass.skipFast.desc",     Color3.fromRGB(255, 130, 230), "convenience"),
	gp("multiOpen",    "multiOpen",    1862084009, 499, "gamepass.multiOpen.name",    "gamepass.multiOpen.desc",    Color3.fromRGB(150, 110, 230), "convenience"),
	gp("autoCollect",  "autoCollect",  1866630602, 249, "gamepass.autoCollect.name",  "gamepass.autoCollect.desc",  Color3.fromRGB(90, 200, 120),  "convenience"),
	gp("extraSlots",   "extraSlots",   1862449790, 399, "gamepass.extraSlots.name",   "gamepass.extraSlots.desc",   Color3.fromRGB(160, 110, 70),  "utility"),
	gp("vipArea",      "vipArea",      1865880698, 599, "gamepass.vipArea.name",      "gamepass.vipArea.desc",      Color3.fromRGB(255, 130, 230), "utility"),
}

local DevProducts = {
	dp("gems_100",    3602112217,  79, "product.gems100.name",    "product.gems100.desc",    { currency = "gems", amount = 100 },    Color3.fromRGB(120, 230, 200)),
	dp("gems_550",    3602112304, 399, "product.gems550.name",    "product.gems550.desc",    { currency = "gems", amount = 550 },    Color3.fromRGB(120, 230, 200)),
	dp("gems_1200",   3602114223, 799, "product.gems1200.name",   "product.gems1200.desc",   { currency = "gems", amount = 1200 },   Color3.fromRGB(120, 230, 200)),
	dp("gold_50k",    3602112365,  79, "product.gold50k.name",    "product.gold50k.desc",    { currency = "gold", amount = 50000 },  Color3.fromRGB(255, 215, 80)),
	dp("gold_500k",   3602112407, 399, "product.gold500k.name",   "product.gold500k.desc",   { currency = "gold", amount = 500000 }, Color3.fromRGB(255, 215, 80)),
	dp("luckPotion",  3602112494,  99, "product.luckPotion.name", "product.luckPotion.desc", { potion = "luck10m" },                  Color3.fromRGB(180, 240, 140)),
}

-- Indizes für schnellen Zugriff in Services
local byFlag: { [string]: Gamepass } = {}
local byRobloxId: { [number]: Gamepass } = {}
for _, p in ipairs(Gamepasses) do
	byFlag[p.flag] = p
	if p.robloxId > 0 then byRobloxId[p.robloxId] = p end
end

local productByRobloxId: { [number]: DevProduct } = {}
local productById: { [string]: DevProduct } = {}
for _, p in ipairs(DevProducts) do
	productById[p.id] = p
	if p.robloxId > 0 then productByRobloxId[p.robloxId] = p end
end

return {
	list = Gamepasses,
	products = DevProducts,
	byFlag = byFlag,
	byRobloxId = byRobloxId,
	productById = productById,
	productByRobloxId = productByRobloxId,
}
