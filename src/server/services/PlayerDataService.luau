--!strict
-- PlayerDataService
--   - Lädt Spielerprofile beim Join
--   - Auto-Save alle 60s + BindToClose
--   - Session-Lock gegen Multi-Server-Race
--   - Patch-basierte Client-Replikation (nicht Full-State)
--
-- Hinweis: Diese Implementierung nutzt DataStoreService direkt mit einem schlanken
-- Session-Lock. Sobald ProfileService via Wally installiert ist, lässt sich der
-- Storage-Layer (Loader/Saver/Lock) gegen ProfileService tauschen, ohne Caller anzufassen.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("PlayerData")
local Signal = require(Shared.utils.Signal)
local Net = require(Shared.remotes.Net)

local DefaultProfile = require(script.Parent.Parent.data.DefaultProfile)
local Migrations = require(script.Parent.Parent.data.Migrations)

export type Profile = DefaultProfile.Profile

local STORE_NAME = "GodsOfFate_PlayerData_v1"
local AUTO_SAVE_INTERVAL = 60
local SESSION_TIMEOUT = 30 -- Sekunden, nach denen ein verwaister Lock übernommen werden darf
local MAX_RETRIES = 5

local jobId = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)

-- Studio ohne aktivierten API-Zugriff (oder unveröffentlichter Place): bereits
-- GetDataStore() kann werfen. Daher alles in pcall — schlägt es fehl, nutzen wir
-- einen In-Memory-Mock, statt den ganzen Server-Bootstrap crashen zu lassen.
local store: DataStore? = nil
local DATASTORE_AVAILABLE = (function(): boolean
	if not RunService:IsStudio() then
		store = DataStoreService:GetDataStore(STORE_NAME)
		return true
	end
	local ok = pcall(function()
		local s = DataStoreService:GetDataStore(STORE_NAME)
		store = s
		s:GetAsync("__probe__")
	end)
	if not ok then
		Logger.warn("DataStore not available in Studio — using in-memory profiles.")
	end
	return ok
end)()

-- In-Memory Fallback für Studio
local memoryStore: { [number]: any } = {}

local PlayerDataService = {}
PlayerDataService.OnLoaded = Signal.new() -- fires (player, profile)
PlayerDataService.OnSaved = Signal.new()  -- fires (player)

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}

local function key(userId: number): string
	return "u_" .. userId
end

local function retry<T>(fn: () -> T): (boolean, any)
	local lastErr
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		task.wait(0.5 * attempt)
	end
	return false, lastErr
end

-- Storage layout in DataStore:
--   { profile = <Profile>, session = { jobId = "..", updatedAt = <epoch> } }
local IS_STUDIO = RunService:IsStudio()

local function load(userId: number): Profile?
	if not DATASTORE_AVAILABLE then
		local cached = memoryStore[userId]
		local profile = cached and cached.profile or DefaultProfile.default()
		profile = Migrations.apply(profile)
		profile.meta.lastLogin = os.time()
		if not cached then profile.meta.createdAt = os.time() end
		memoryStore[userId] = { profile = profile }
		return profile
	end
	local ok, payload = retry(function()
		return (store :: DataStore):UpdateAsync(key(userId), function(old)
			local data = old or {}
			local now = os.time()
			local session = data.session
			-- In Studio bekommt jeder Play-Klick eine neue jobId, und BindToClose
			-- gibt den Lock nicht frei → wir übernehmen Studio-Locks immer.
			if not IS_STUDIO and session and session.jobId ~= jobId and (now - (session.updatedAt or 0)) < SESSION_TIMEOUT then
				return nil -- jemand anderes hat aktive Session → Abbruch
			end
			data.session = { jobId = jobId, updatedAt = now }
			if not data.profile then
				data.profile = DefaultProfile.default()
				data.profile.meta.createdAt = now
			end
			data.profile = Migrations.apply(data.profile)
			data.profile.meta.lastLogin = now
			return data
		end)
	end)
	if not ok or not payload then return nil end
	return payload.profile
end

local function save(userId: number, profile: Profile, releaseLock: boolean)
	if not DATASTORE_AVAILABLE then
		memoryStore[userId] = { profile = profile }
		return
	end
	retry(function()
		(store :: DataStore):UpdateAsync(key(userId), function(old)
			local data = old or {}
			-- nur unsere Session darf schreiben
			if data.session and data.session.jobId ~= jobId then
				return nil
			end
			data.profile = profile
			data.session = releaseLock and nil or { jobId = jobId, updatedAt = os.time() }
			return data
		end)
	end)
end

-- ─── Replikation ─────────────────────────────────────────────────────────────

local economyEvent = Net:Event("OnEconomyUpdate")
local inventoryEvent = Net:Event("OnInventoryUpdate")
local templeEvent = Net:Event("OnTempleUpdate")
local rebirthEvent = Net:Event("OnRebirthUpdate")
local questEvent = Net:Event("OnQuestUpdate")

local function rebirthSnapshot(profile: Profile)
	return {
		lifetime = profile.lifetime,
		divinity = profile.divinity,
	}
end

local function replicateAll(player: Player, profile: Profile)
	economyEvent:FireClient(player, profile.currencies)
	inventoryEvent:FireClient(player, { gods = profile.inventory.gods })
	templeEvent:FireClient(player, profile.temple)
	rebirthEvent:FireClient(player, rebirthSnapshot(profile))
end

function PlayerDataService.patchEconomy(player: Player)
	local profile = profiles[player]
	if not profile then return end
	economyEvent:FireClient(player, profile.currencies)
	dirty[player] = true
end

function PlayerDataService.patchInventory(player: Player)
	local profile = profiles[player]
	if not profile then return end
	inventoryEvent:FireClient(player, { gods = profile.inventory.gods })
	dirty[player] = true
end

function PlayerDataService.patchTemple(player: Player)
	local profile = profiles[player]
	if not profile then return end
	templeEvent:FireClient(player, profile.temple)
	dirty[player] = true
end

function PlayerDataService.patchRebirth(player: Player)
	local profile = profiles[player]
	if not profile then return end
	rebirthEvent:FireClient(player, rebirthSnapshot(profile))
	dirty[player] = true
end

function PlayerDataService.patchQuests(player: Player)
	local profile = profiles[player]
	if not profile then return end
	questEvent:FireClient(player, profile.quests)
	dirty[player] = true
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function PlayerDataService.get(player: Player): Profile?
	return profiles[player]
end

-- Sichere Mutation. fn erhält das Profil; alle Änderungen daran werden persistiert.
function PlayerDataService.update(player: Player, fn: (Profile) -> ())
	local profile = profiles[player]
	if not profile then return end
	fn(profile)
	dirty[player] = true
end

function PlayerDataService.forceSave(player: Player)
	local profile = profiles[player]
	if not profile then return end
	save(player.UserId, profile, false)
	dirty[player] = false
	PlayerDataService.OnSaved:Fire(player)
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

local function onJoin(player: Player)
	Logger.info("Loading profile for %s (%d)", player.Name, player.UserId)
	local profile = load(player.UserId)
	if not profile then
		Logger.warn("Could not acquire profile lock for %s — kicking", player.Name)
		player:Kick("Could not load your save. Please rejoin in a moment.")
		return
	end

	profiles[player] = profile
	dirty[player] = false
	PlayerDataService.OnLoaded:Fire(player, profile)
	replicateAll(player, profile)
	Logger.info("Profile ready for %s (v%d, %d gold)", player.Name, profile.version, profile.currencies.gold)
end

local function onLeave(player: Player)
	local profile = profiles[player]
	if not profile then return end
	profile.meta.playtime += (os.time() - profile.meta.lastLogin)
	save(player.UserId, profile, true)
	profiles[player] = nil
	dirty[player] = nil
	Logger.info("Profile released for %s", player.Name)
end

-- Sprache umschalten (Stage 4 baut volles ChangeSetting drumherum)
Net:Function("SwitchLanguage").OnServerInvoke = function(player: Player, lang)
	if type(lang) ~= "string" then return false end
	if lang ~= "en" and lang ~= "de" then return false end
	PlayerDataService.update(player, function(profile)
		profile.settings.language = lang
	end)
	return true
end

-- Profile-Request vom Client (für Initial-UI)
Net:Function("RequestProfile").OnServerInvoke = function(player: Player)
	local profile = profiles[player]
	if not profile then return nil end
	-- Geben dem Client einen reduzierten Snapshot (keine sensitiven Felder).
	return {
		currencies = profile.currencies,
		lifetime = { gold = profile.lifetime.gold, rebirths = profile.lifetime.rebirths },
		inventory = { gods = profile.inventory.gods },
		temple = profile.temple,
		unlocks = { packs = profile.unlocks.packs, gamepasses = profile.unlocks.gamepasses },
		settings = profile.settings,
		quests = profile.quests,
		divinity = profile.divinity,
		season = profile.season,
		collection = profile.collection,
		flags = profile.flags,
	}
end

-- Auto-Save Loop
task.spawn(function()
	while true do
		task.wait(AUTO_SAVE_INTERVAL)
		for player, profile in pairs(profiles) do
			if dirty[player] then
				task.spawn(function()
					save(player.UserId, profile, false)
					dirty[player] = false
					PlayerDataService.OnSaved:Fire(player)
				end)
			end
		end
	end
end)

Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, player)
end

game:BindToClose(function()
	if RunService:IsStudio() then return end
	local pending = {}
	for player, profile in pairs(profiles) do
		table.insert(pending, task.spawn(function()
			save(player.UserId, profile, true)
		end))
	end
	-- Roblox gibt uns bis zu 30s — auf alle Saves warten.
	for _, thread in ipairs(pending) do
		while coroutine.status(thread) ~= "dead" do
			task.wait(0.1)
		end
	end
end)

Logger.info("PlayerDataService online (store=%s, jobId=%s)", STORE_NAME, jobId:sub(1, 8))

return PlayerDataService
