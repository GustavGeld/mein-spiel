--!strict
-- QuestService — Daily Quests, Minute Reward, Login Streak.
--
--   beim Join (oder neuem UTC-Tag) werden 3 zufällige Daily-Quests gezogen.
--   PackService und TempleService rufen onPull/onPlace, um Progress zu bumpen.
--   ClaimQuest/ClaimMinute/ClaimLogin geben Rewards aus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Quest")
local Net = require(Shared.remotes.Net)

local Quests = require(Shared.config.Quests)
local Rarities = require(Shared.config.Rarities)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

local QuestService = {}

local MINUTE_INTERVAL = 60 -- Sekunden

local function utcDay(): number
	return math.floor(os.time() / 86400)
end

local function utcWeek(): number
	return Quests.utcWeek()
end

-- Spielereigener RNG (deterministisch pro Zeitraum+Spieler).
local function rngFor(player: Player, seed: number): Random
	return Random.new(seed * 1e6 + player.UserId)
end

-- Stellt sicher, dass für den aktuellen Tag 3 Quests im Profile stehen.
local function ensureDailies(player: Player, profile)
	local today = utcDay()
	if profile.quests.dayStamp == today and next(profile.quests.daily) then
		return false
	end
	local picks = Quests.pickDailies(rngFor(player, today), 3)
	profile.quests.daily = {}
	for _, def in ipairs(picks) do
		profile.quests.daily[def.id] = { progress = 0, claimed = false }
	end
	profile.quests.dayStamp = today
	return true
end

-- Stellt sicher, dass für die aktuelle Woche 3 Weekly-Quests stehen.
local function ensureWeeklies(player: Player, profile)
	local week = utcWeek()
	if profile.quests.weekStamp == week and next(profile.quests.weekly) then
		return false
	end
	local picks = Quests.pickWeeklies(rngFor(player, week + 9999), 3)
	profile.quests.weekly = {}
	for _, def in ipairs(picks) do
		profile.quests.weekly[def.id] = { progress = 0, claimed = false }
	end
	profile.quests.weekStamp = week
	return true
end

-- Login-Streak: bei neuem Tag inkrementieren oder zurücksetzen.
local function bumpLoginStreak(profile)
	local today = utcDay()
	local last = profile.quests.login.lastDay or 0
	if last == today then
		return false -- Spieler war heute schon hier
	end
	if last == today - 1 then
		profile.quests.login.streak = (profile.quests.login.streak or 0) + 1
	else
		profile.quests.login.streak = 1
	end
	-- claim-Flag wird via ClaimLogin gesetzt; hier nur den Tag markieren wenn nicht claimt
	profile.quests.login.lastDay = today
	profile.quests.login.claimed = false
	return true
end

local function giveReward(player: Player, reward)
	if not reward then return end
	EconomyService.add(player, reward.currency :: any, reward.amount)
end

-- Bumpt Progress eines bestimmten Quest-Typs in daily UND weekly.
local function bumpProgress(player: Player, qType: string, amount: number, param: number?)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local changed = false
	local function bump(questTable: any)
		for id, state in pairs(questTable) do
			local def = Quests.byId[id]
			if def and def.type == qType and not state.claimed then
				if def.param == nil or (param ~= nil and param >= def.param) then
					local before = state.progress
					state.progress = math.min(def.target, state.progress + amount)
					if state.progress ~= before then changed = true end
				end
			end
		end
	end
	bump(profile.quests.daily)
	bump(profile.quests.weekly or {})
	if changed then
		PlayerDataService.patchQuests(player)
	end
end

-- Public Hooks für andere Services
function QuestService.onPull(player: Player, rarityId: string, isSecret: boolean)
	bumpProgress(player, "pulls", 1)
	local rarityIndex = (Rarities.byId[rarityId] or {}).index or 0
	bumpProgress(player, "rarity", 1, rarityIndex)
	if isSecret then
		bumpProgress(player, "secret", 1)
	end
end

function QuestService.onGoldSpent(player: Player, amount: number)
	bumpProgress(player, "gold_spent", amount)
end

function QuestService.onGodPlaced(player: Player)
	bumpProgress(player, "place", 1)
end

function QuestService.onRebirth(player: Player)
	bumpProgress(player, "rebirths", 1)
end

-- ─── Remotes ─────────────────────────────────────────────────────────────────

Net:Function("ClaimQuest").OnServerInvoke = function(player: Player, questId: any)
	if type(questId) ~= "string" then return { ok = false, reason = "bad_args" } end
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	-- Suche in daily UND weekly
	local isWeekly = profile.quests.weekly and profile.quests.weekly[questId] ~= nil
	local state = isWeekly and profile.quests.weekly[questId] or profile.quests.daily[questId]
	local def = Quests.byId[questId]
	if not state or not def then return { ok = false, reason = "unknown" } end
	if state.claimed then return { ok = false, reason = "claimed" } end
	if state.progress < def.target then return { ok = false, reason = "incomplete" } end
	PlayerDataService.update(player, function(p)
		if isWeekly then
			p.quests.weekly[questId].claimed = true
		else
			p.quests.daily[questId].claimed = true
		end
	end)
	giveReward(player, def.reward)
	PlayerDataService.patchQuests(player)
	Logger.info("%s claimed quest %s (+%d %s)", player.Name, questId, def.reward.amount, def.reward.currency)
	return { ok = true, reward = def.reward }
end

Net:Function("ClaimMinute").OnServerInvoke = function(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false } end
	local now = os.time()
	local last = profile.quests.minute.lastClaim or 0
	if now - last < MINUTE_INTERVAL then
		return { ok = false, reason = "cooldown", remaining = MINUTE_INTERVAL - (now - last) }
	end
	PlayerDataService.update(player, function(p)
		p.quests.minute.lastClaim = now
	end)
	giveReward(player, Quests.minuteReward)
	PlayerDataService.patchQuests(player)
	return { ok = true, reward = Quests.minuteReward, next = now + MINUTE_INTERVAL }
end

Net:Function("ClaimLogin").OnServerInvoke = function(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false } end
	if profile.quests.login.claimed then
		return { ok = false, reason = "claimed" }
	end
	local streak = profile.quests.login.streak or 1
	local idx = ((streak - 1) % #Quests.loginRewards) + 1
	local reward = Quests.loginRewards[idx]
	PlayerDataService.update(player, function(p)
		p.quests.login.claimed = true
	end)
	giveReward(player, reward)
	PlayerDataService.patchQuests(player)
	Logger.info("%s claimed login day %d (+%d %s)", player.Name, streak, reward.amount, reward.currency)
	return { ok = true, reward = reward, streak = streak }
end

Net:Function("QuestPreview").OnServerInvoke = function(_: Player)
	-- Liefert nur die statische Pool/Login/Minute-Definition.
	return {
		pool = Quests.dailyPool,
		login = Quests.loginRewards,
		minute = Quests.minuteReward,
		minuteInterval = MINUTE_INTERVAL,
	}
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

local function onJoin(player: Player)
	-- Warten bis das Profil geladen ist.
	local tries = 0
	while not PlayerDataService.get(player) and tries < 50 do
		task.wait(0.1); tries += 1
	end
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local rolled = ensureDailies(player, profile)
	local rolledW = ensureWeeklies(player, profile)
	local newLogin = bumpLoginStreak(profile)
	if rolled or rolledW or newLogin then
		PlayerDataService.patchQuests(player)
	end
end

Players.PlayerAdded:Connect(function(p) task.spawn(onJoin, p) end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

Logger.info("QuestService online.")

return QuestService
