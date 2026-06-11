--!strict
-- God-Roster pro Rarity. Beim Pull wählt das System nach Rarity zufällig einen Gott aus dem Pool.
--
-- `iconAssetId` ist optional — fehlt sie, zeigen Karten ein Initial-Fallback ("H" etc.).

export type GodDef = {
	id: string,
	rarityId: string,
	baseProduction: number, -- Gold/sec (vor Multipliern)
	baseFaith: number,      -- Faith/sec
	iconAssetId: string?,   -- rbxassetid://… (optional)
}

local function g(id: string, rarityId: string, baseProduction: number, baseFaith: number, iconAssetId: string?): GodDef
	return {
		id = id, rarityId = rarityId,
		baseProduction = baseProduction, baseFaith = baseFaith,
		iconAssetId = iconAssetId,
	}
end

local Gods: { GodDef } = {
	-- ── Pack 1 — Greek Apprentices (Common → Unique) ──────────────────────────
	g("Hermes_Apprentice",  "Common",    1,      0,   "rbxassetid://98144075868595"),
	g("Vesta_Spark",        "Common",    1,      0,   "rbxassetid://133594920253831"),
	g("Pan_Whistler",       "Common",    1,      0,   "rbxassetid://79961604323478"),
	g("Hermes_Messenger",   "Uncommon",  3,      0,   "rbxassetid://104218688969961"),
	g("Vesta_Flame",        "Uncommon",  3,      0,   "rbxassetid://104684325360066"),
	g("Pan_Reveler",        "Uncommon",  3,      0,   "rbxassetid://134751056616904"),
	g("Apollo_Lyric",       "Rare",      9,      0,   "rbxassetid://100806210069088"),
	g("Diana_Hunter",       "Rare",      9,      0,   "rbxassetid://128465423120884"),
	g("Mars_Recruit",       "Rare",      9,      0,   "rbxassetid://127968083244338"),
	g("Athena_Scribe",      "Epic",      28,     1,   "rbxassetid://119399772880381"),
	g("Poseidon_Tidewatcher","Epic",     28,     1,   "rbxassetid://90750280568887"),
	g("Hephaestus_Smith",   "Epic",      28,     1,   "rbxassetid://111828652368891"),
	g("Hades_Shadekeeper",  "Unique",    110,    3,   "rbxassetid://103584941519150"),
	g("Persephone_Bloom",   "Unique",    110,    3,   "rbxassetid://73839545299337"),
	g("Aphrodite_Charm",    "Unique",    110,    3,   "rbxassetid://136473192062610"),

	-- ── Pack 2 — Greek Olympians (Elite → Mythic) ────────────────────────────
	g("Zeus_Storm",         "Elite",     300,    3,   nil),
	g("Ares_Fury",          "Elite",     300,    3,   nil),
	g("Hera_Crown",         "Elite",     300,    3,   nil),
	g("Poseidon_Depths",    "Heroic",    800,    8,   nil),
	g("Artemis_Moonbow",    "Heroic",    800,    8,   nil),
	g("Demeter_Fields",     "Heroic",    800,    8,   nil),
	g("Apollo_Sunflare",    "RisingStar",2000,   20,  nil),
	g("Athena_Aegis",       "RisingStar",2000,   20,  nil),
	g("Hermes_Windwalker",  "RisingStar",2000,   20,  nil),
	g("Zeus_Olympian",      "Legendary", 5000,   50,  nil),
	g("Ares_Warmaster",     "Legendary", 5000,   50,  nil),
	g("Hera_Sovereign",     "Legendary", 5000,   50,  nil),
	g("Kronos_Ancient",     "Mythic",    13000,  130, nil),
	g("Gaia_Primordial",    "Mythic",    13000,  130, nil),
	g("Prometheus_Titan",   "Mythic",    13000,  130, nil),

	-- ── Pack 3 — Egyptian Pantheon (Immortal → Goddess) ──────────────────────
	g("Ra_Sundisk",         "Immortal",  40000,  400,   nil),
	g("Osiris_Risen",       "Immortal",  40000,  400,   nil),
	g("Isis_Winged",        "Immortal",  40000,  400,   nil),
	g("Anubis_Judge",       "DemiGod",   100000, 1000,  nil),
	g("Thoth_Scribe",       "DemiGod",   100000, 1000,  nil),
	g("Bastet_Claws",       "DemiGod",   100000, 1000,  nil),
	g("Horus_Golden",       "Valkyrie",  260000, 2600,  nil),
	g("Seth_Sandstorm",     "Valkyrie",  260000, 2600,  nil),
	g("Sobek_Jaws",         "Valkyrie",  260000, 2600,  nil),
	g("Ra_Eternal",         "God",       650000, 6500,  nil),
	g("Osiris_Undying",     "God",       650000, 6500,  nil),
	g("Isis_Divine",        "God",       650000, 6500,  nil),
	g("Sekhmet_Blaze",      "Goddess",   1700000,17000, nil),
	g("Hathor_Radiant",     "Goddess",   1700000,17000, nil),
	g("Nut_Starfield",      "Goddess",   1700000,17000, nil),

	-- ── Pack 4 — Hindu Pantheon (Ascended → Celestial) ───────────────────────
	g("Brahma_Maker",       "Ascended",  5000000,   50000,   nil),
	g("Vishnu_Keeper",      "Ascended",  5000000,   50000,   nil),
	g("Shiva_Dancer",       "Ascended",  5000000,   50000,   nil),
	g("Indra_Thunder",      "Ancient",   12500000,  125000,  nil),
	g("Surya_Shining",      "Ancient",   12500000,  125000,  nil),
	g("Agni_Flames",        "Ancient",   12500000,  125000,  nil),
	g("Durga_Fierce",       "HighTier",  32000000,  320000,  nil),
	g("Kali_Wrath",         "HighTier",  32000000,  320000,  nil),
	g("Saraswati_Verse",    "HighTier",  32000000,  320000,  nil),
	g("Vishnu_Cosmic",      "Cosmic",    80000000,  800000,  nil),
	g("Shiva_Cosmic",       "Cosmic",    80000000,  800000,  nil),
	g("Brahma_Cosmic",      "Cosmic",    80000000,  800000,  nil),
	g("Mahavishnu_Prime",   "Celestial", 200000000, 2000000, nil),
	g("Mahashiva_Prime",    "Celestial", 200000000, 2000000, nil),
	g("Parashakti_Prime",   "Celestial", 200000000, 2000000, nil),

	-- ── Pack 5 — East Asian Pantheon (Astral → Archon) ───────────────────────
	g("Amaterasu_Dawn",     "Astral",    6e8,  6e6,  nil),
	g("Susanoo_Tempest",    "Astral",    6e8,  6e6,  nil),
	g("Tsukuyomi_Night",    "Astral",    6e8,  6e6,  nil),
	g("Izanagi_Creator",    "Nebula",    1.5e9,1.5e7,nil),
	g("Izanami_Keeper",     "Nebula",    1.5e9,1.5e7,nil),
	g("Fujin_Gale",         "Nebula",    1.5e9,1.5e7,nil),
	g("Raijin_Boom",        "Galaxy",    3.8e9,3.8e7,nil),
	g("Benzaiten_Grace",    "Galaxy",    3.8e9,3.8e7,nil),
	g("Bishamonten_War",    "Galaxy",    3.8e9,3.8e7,nil),
	g("JadeEmperor_High",   "Universe",  9.5e9,9.5e7,nil),
	g("Nvwa_Sculptor",      "Universe",  9.5e9,9.5e7,nil),
	g("Erlang_Shen",        "Universe",  9.5e9,9.5e7,nil),
	g("Amaterasu_Prime",    "Archon",    2.4e10,2.4e8,nil),
	g("Izanagi_Prime",      "Archon",    2.4e10,2.4e8,nil),
	g("JadeEmperor_Eternal","Archon",    2.4e10,2.4e8,nil),

	-- ── Pack 6 — Mesopotamian Pantheon (Chrono → Divine) ─────────────────────
	g("Marduk_Sovereign",   "Chrono",    7.2e10,7.2e8, nil),
	g("Ishtar_Celestial",   "Chrono",    7.2e10,7.2e8, nil),
	g("Enlil_Storm",        "Chrono",    7.2e10,7.2e8, nil),
	g("Anu_Heaven",         "Temporal",  1.8e11,1.8e9, nil),
	g("Nanna_Moonlord",     "Temporal",  1.8e11,1.8e9, nil),
	g("Utu_Sundisk",        "Temporal",  1.8e11,1.8e9, nil),
	g("Enki_Deepwaters",    "Dimensional",4.5e11,4.5e9,nil),
	g("Ninhursag_Earth",    "Dimensional",4.5e11,4.5e9,nil),
	g("Inanna_Gates",       "Dimensional",4.5e11,4.5e9,nil),
	g("Marduk_Dragon",      "Spatial",   1.1e12,1.1e10,nil),
	g("Tiamat_Chaos",       "Spatial",   1.1e12,1.1e10,nil),
	g("Kingu_War",          "Spatial",   1.1e12,1.1e10,nil),
	g("Enlil_Absolute",     "Divine",    2.8e12,2.8e10,nil),
	g("Anu_Infinite",       "Divine",    2.8e12,2.8e10,nil),
	g("Enki_Primordial",    "Divine",    2.8e12,2.8e10,nil),

	-- ── Pack 7 — Celtic & Slavic Pantheon (Luminary → Radiant) ──────────────
	g("Lugh_Bright",        "Luminary",  8.4e12, 8.4e10, nil),
	g("Dagda_Great",        "Luminary",  8.4e12, 8.4e10, nil),
	g("Morrigan_War",       "Luminary",  8.4e12, 8.4e10, nil),
	g("Cernunnos_Wild",     "Seraphim",  2.1e13, 2.1e11, nil),
	g("Brigid_Flame",       "Seraphim",  2.1e13, 2.1e11, nil),
	g("Danu_Origin",        "Seraphim",  2.1e13, 2.1e11, nil),
	g("Perun_Thunder",      "Sacred",    5.2e13, 5.2e11, nil),
	g("Veles_Underworld",   "Sacred",    5.2e13, 5.2e11, nil),
	g("Rod_Creator",        "Sacred",    5.2e13, 5.2e11, nil),
	g("Svarog_Forge",       "Exalted",   1.3e14, 1.3e12, nil),
	g("Mokosh_Fate",        "Exalted",   1.3e14, 1.3e12, nil),
	g("Khors_Solar",        "Exalted",   1.3e14, 1.3e12, nil),
	g("Lugh_Absolute",      "Radiant",   3.3e14, 3.3e12, nil),
	g("Danu_Eternal",       "Radiant",   3.3e14, 3.3e12, nil),
	g("Morrigan_Eternal",   "Radiant",   3.3e14, 3.3e12, nil),

	-- ── Pack 8 — Aztec Pantheon (Timeless → Eternal) ─────────────────────────
	g("Huitzil_Sun",        "Timeless",  1e15,   1e13,   nil),
	g("Quetzal_Wind",       "Timeless",  1e15,   1e13,   nil),
	g("Tlaloc_Rain",        "Timeless",  1e15,   1e13,   nil),
	g("Xipe_Renewal",       "Infinite",  2.5e15, 2.5e13, nil),
	g("Coatli_Earth",       "Infinite",  2.5e15, 2.5e13, nil),
	g("Xochi_Beauty",       "Infinite",  2.5e15, 2.5e13, nil),
	g("Tezca_Night",        "Boundless", 6.2e15, 6.2e13, nil),
	g("Mixcoatl_Hunt",      "Boundless", 6.2e15, 6.2e13, nil),
	g("Chalchiu_Water",     "Boundless", 6.2e15, 6.2e13, nil),
	g("Quetzal_Feathered",  "Absolute",  1.55e16,1.55e14,nil),
	g("Huitzil_War",        "Absolute",  1.55e16,1.55e14,nil),
	g("Tezca_Mirror",       "Absolute",  1.55e16,1.55e14,nil),
	g("Ometeotl_Dual",      "Eternal",   3.9e16, 3.9e14, nil),
	g("Tonatiuh_Blaze",     "Eternal",   3.9e16, 3.9e14, nil),
	g("Tlatec_Sovereign",   "Eternal",   3.9e16, 3.9e14, nil),

	-- ── Pack 9 — Norse End-Times (Abyssal → Primordial) ──────────────────────
	g("Surtur_Flames",      "Abyssal",   1.2e17, 1.2e15, nil),
	g("Nidhogg_Gnaw",       "Abyssal",   1.2e17, 1.2e15, nil),
	g("Jormungandr_Coil",   "Abyssal",   1.2e17, 1.2e15, nil),
	g("Fenrir_Unbound",     "Void",      3e17,   3e15,   nil),
	g("Hel_Mistress",       "Void",      3e17,   3e15,   nil),
	g("Loki_Chaos",         "Void",      3e17,   3e15,   nil),
	g("Ymir_Primeval",      "Eldritch",  7.5e17, 7.5e15, nil),
	g("Audhumla_Ancient",   "Eldritch",  7.5e17, 7.5e15, nil),
	g("Odin_Allfather",     "Eldritch",  7.5e17, 7.5e15, nil),
	g("Thor_Ragnarok",      "Chaos",     1.9e18, 1.9e16, nil),
	g("Freya_Valkyrie",     "Chaos",     1.9e18, 1.9e16, nil),
	g("Nornir_Weavers",     "Chaos",     1.9e18, 1.9e16, nil),
	g("Yggdrasil_Root",     "Primordial",4.7e18, 4.7e16, nil),
	g("Ragnarok_End",       "Primordial",4.7e18, 4.7e16, nil),
	g("Asgard_Fall",        "Primordial",4.7e18, 4.7e16, nil),

	-- ── Pack 10 — Beyond (Singularity → Beyond) ──────────────────────────────
	g("Axiom_Zero",         "Singularity",    1.4e19, 1.4e17, nil),
	g("Cipher_First",       "Singularity",    1.4e19, 1.4e17, nil),
	g("Nexus_Core",         "Singularity",    1.4e19, 1.4e17, nil),
	g("Luminos_Weave",      "Transcendental", 3.5e19, 3.5e17, nil),
	g("Aether_Veil",        "Transcendental", 3.5e19, 3.5e17, nil),
	g("Prism_Gate",         "Transcendental", 3.5e19, 3.5e17, nil),
	g("Excelsia_All",       "Omnipotent",     8.8e19, 8.8e17, nil),
	g("Omniveil_Dark",      "Omnipotent",     8.8e19, 8.8e17, nil),
	g("Allseer_Void",       "Omnipotent",     8.8e19, 8.8e17, nil),
	g("Zenith_Final",       "Zenith",         2.2e20, 2.2e18, nil),
	g("Summit_End",         "Zenith",         2.2e20, 2.2e18, nil),
	g("Apex_Boundless",     "Zenith",         2.2e20, 2.2e18, nil),
	g("Terminus_All",       "Beyond",         5.5e20, 5.5e18, nil),
	g("Origin_Zero",        "Beyond",         5.5e20, 5.5e18, nil),
	g("Absolute_One",       "Beyond",         5.5e20, 5.5e18, nil),
}

local byId: { [string]: GodDef } = {}
local byRarity: { [string]: { GodDef } } = {}
for _, def in ipairs(Gods) do
	byId[def.id] = def
	byRarity[def.rarityId] = byRarity[def.rarityId] or {}
	table.insert(byRarity[def.rarityId], def)
end

-- Secret Pools
byRarity["Secret_T1"] = { g("Echo_Anomaly",   "Secret_T1", 500,   25) }
byRarity["Secret_T2"] = { g("Mirror_Anomaly",  "Secret_T2", 5000,  250) }
byRarity["Secret_T3"] = { g("Origin_Anomaly",  "Secret_T3", 50000, 2500) }

return {
	list = Gods,
	byId = byId,
	byRarity = byRarity,
}
