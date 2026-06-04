--!strict
-- LeaderboardService
--   - Schreibt Spielerscores in OrderedDataStores (eine pro Kategorie).
--   - Stellt RequestLeaderboard(category, page) remote bereit (20 Einträge/Seite).
--   - Hängt sich an PlayerDataService.OnSaved + OnLoaded.
--
-- Kategorien: pulls | rebirths | gold | rarity | season

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Leaderboard")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local Seasons = require(Shared.config.Seasons)

local IS_STUDIO = RunService:IsStudio()
local ODS_PREFIX = "GodsOfFate_LB_v1_"
local PAGE_SIZE = 20
local MAX_ENTRIES = 100

local CATEGORIES = { "pulls", "rebirths", "gold", "rarity", "season" }

-- OrderedDataStore pro Kategorie (lazy-opened)
local stores: { [string]: any } = {}

local function getStore(cat: string): any
	if stores[cat] ~= nil then return stores[cat] end
	if IS_STUDIO then
		stores[cat] = false -- Sentinel: nicht verfügbar
		return false
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(ODS_PREFIX .. cat)
	end)
	if ok then
		stores[cat] = result
		return result
	end
	Logger.warn("ODS open failed (%s): %s", cat, tostring(result))
	stores[cat] = false
	return false
end

-- Score aus Profil ableiten (muss Integer sein)
local function getScore(cat: string, profile: any): number
	if cat == "pulls"    then return math.floor(profile.lifetime.pulls) end
	if cat == "rebirths" then return math.floor(profile.lifetime.rebirths) end
	if cat == "gold"     then return math.floor(math.min(profile.lifetime.gold, 2^48)) end
	if cat == "rarity"   then return math.floor(profile.lifetime.rarestRarity) end
	if cat == "season"   then return math.floor(Seasons.calcScore(profile.lifetime)) end
	return 0
end

-- Score für alle Kategorien in ODS schreiben (fire-and-forget)
local function writeScores(userId: number, profile: any)
	local key = tostring(userId)
	for _, cat in ipairs(CATEGORIES) do
		local ds = getStore(cat)
		if not ds then continue end
		local score = getScore(cat, profile)
		if score <= 0 then continue end
		local capturedDs = ds
		local capturedScore = score
		task.spawn(function()
			pcall(function()
				capturedDs:SetAsync(key, capturedScore)
			end)
		end)
	end
end

-- Hooks
PlayerDataService.OnSaved:Connect(function(player: Player)
	local profile = PlayerDataService.get(player)
	if profile then writeScores(player.UserId, profile) end
end)

PlayerDataService.OnLoaded:Connect(function(player: Player, profile: any)
	writeScores(player.UserId, profile)
end)

-- ─── Name-Cache ──────────────────────────────────────────────────────────────

local nameCache: { [number]: string } = {}

local function resolveName(userId: number): string
	if nameCache[userId] then return nameCache[userId] end
	local ok, name = pcall(function()
		return game:GetService("Players"):GetNameFromUserIdAsync(userId)
	end)
	local result: string = (ok and type(name) == "string") and name or ("User_" .. userId)
	nameCache[userId] = result
	return result
end

-- Studio-Mock: gibt plausible Fake-Daten zurück
local function mockEntries(cat: string, page: number): { any }
	local bases: { [string]: number } = {
		pulls = 5000, rebirths = 50, gold = 1000000, rarity = 40, season = 10000
	}
	local base = bases[cat] or 1000
	local entries = {}
	local startRank = (page - 1) * PAGE_SIZE + 1
	for i = 1, PAGE_SIZE do
		local rank = startRank + i - 1
		if rank > MAX_ENTRIES then break end
		table.insert(entries, {
			rank = rank,
			name = "Testplayer" .. rank,
			score = math.max(1, math.floor(base * (1 - rank / MAX_ENTRIES))),
			userId = rank,
		})
	end
	return entries
end

-- ─── Remote ──────────────────────────────────────────────────────────────────

Net:Function("RequestLeaderboard").OnServerInvoke = function(player: Player, category: string, page: number)
	if type(category) ~= "string" then return nil end
	if not table.find(CATEGORIES, category) then return nil end
	if type(page) ~= "number" then page = 1 end
	page = math.clamp(math.floor(page), 1, 5)

	-- Studio-Mock
	if IS_STUDIO then
		local entries = mockEntries(category, page)
		return { entries = entries, page = page, totalPages = 5 }
	end

	local ds = getStore(category)
	if not ds then
		return { entries = {}, page = page, totalPages = 0 }
	end

	-- Top 100 auf einmal holen (pageSize=100), dann serverseitig paginieren.
	local ok, rawPages = pcall(function()
		return ds:GetSortedAsync(false, MAX_ENTRIES, 1, 2^48)
	end)
	if not ok then
		Logger.warn("GetSortedAsync failed (%s): %s", category, tostring(rawPages))
		return { entries = {}, page = page, totalPages = 0 }
	end

	local allRaw = (rawPages :: DataStorePages):GetCurrentPage()
	local totalEntries = #allRaw
	local totalPages = math.max(1, math.ceil(totalEntries / PAGE_SIZE))
	page = math.clamp(page, 1, totalPages)

	local startIdx = (page - 1) * PAGE_SIZE + 1
	local endIdx = math.min(startIdx + PAGE_SIZE - 1, totalEntries)

	local entries = {}
	for i = startIdx, endIdx do
		local raw = allRaw[i]
		local uid = tonumber(raw.key)
		if uid then
			local name = resolveName(uid)
			table.insert(entries, {
				rank   = i,
				name   = name,
				score  = raw.value,
				userId = uid,
			})
		end
	end

	return { entries = entries, page = page, totalPages = totalPages }
end

Logger.info("LeaderboardService online (%d categories)", #CATEGORIES)

local LeaderboardService = {}
LeaderboardService.CATEGORIES = CATEGORIES

-- Gibt die Top-N Einträge für eine Kategorie zurück (server-intern, z.B. für SeasonService).
function LeaderboardService.getTopEntries(category: string, limit: number): { { key: string, value: number } }
	local ds = getStore(category)
	if not ds then return {} end
	local ok, rawPages = pcall(function()
		return ds:GetSortedAsync(false, math.clamp(limit, 1, 100), 1, 2^48)
	end)
	if not ok then return {} end
	return (rawPages :: DataStorePages):GetCurrentPage()
end

return LeaderboardService
