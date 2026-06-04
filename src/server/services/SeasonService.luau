--!strict
-- SeasonService
--   - Verwaltet die wöchentliche Saison.
--   - Setzt season.id zurück wenn eine neue Woche beginnt.
--   - ClaimSeasonReward: prüft ODS-Rang, vergibt Gems, setzt claimed = true.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Season")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Seasons = require(Shared.config.Seasons)

local IS_STUDIO = RunService:IsStudio()

local seasonUpdateEvent = Net:Event("OnSeasonUpdate")

-- Saison-Snapshot für Client
local function seasonSnapshot(profile: any)
	return {
		id      = profile.season.id,
		score   = profile.season.score,
		claimed = profile.season.claimed,
		secs    = Seasons.secondsRemaining(),
	}
end

-- Saison-Score aktualisieren (score = calcScore aus lifetime)
local function refreshScore(profile: any)
	profile.season.score = Seasons.calcScore(profile.lifetime)
end

-- ─── OnLoaded: Saison prüfen / ggf. zurücksetzen ─────────────────────────────

PlayerDataService.OnLoaded:Connect(function(player: Player, profile: any)
	local currentId = Seasons.currentId()
	if profile.season.id ~= currentId then
		Logger.info("Season reset for %s: %s → %s", player.Name, profile.season.id, currentId)
		PlayerDataService.update(player, function(p)
			p.season.id = currentId
			p.season.claimed = false
			refreshScore(p)
		end)
	else
		-- Score trotzdem auffrischen (z.B. nach Rebirth)
		PlayerDataService.update(player, function(p)
			refreshScore(p)
		end)
	end

	-- Sofort nach Join senden (Snapshot enthält aktuellen Score)
	local updated = PlayerDataService.get(player)
	if updated then
		seasonUpdateEvent:FireClient(player, seasonSnapshot(updated))
	end
end)

-- ─── OnSaved: Score aktuell halten ───────────────────────────────────────────

PlayerDataService.OnSaved:Connect(function(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return end
	local newScore = Seasons.calcScore(profile.lifetime)
	if profile.season.score ~= newScore then
		PlayerDataService.update(player, function(p)
			p.season.score = newScore
		end)
		seasonUpdateEvent:FireClient(player, seasonSnapshot(profile))
	end
end)

-- ─── ClaimSeasonReward ───────────────────────────────────────────────────────

Net:Function("ClaimSeasonReward").OnServerInvoke = function(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return { ok = false, reason = "no_profile" }
	end
	if profile.season.claimed then
		return { ok = false, reason = "already_claimed" }
	end

	-- Im Studio direkt Rang 1 gewähren (kein ODS)
	local rank: number
	if IS_STUDIO then
		rank = 1
	else
		-- Eigenen Score im ODS nachschlagen und Rang bestimmen
		local top = LeaderboardService.getTopEntries("season", 100)
		local myKey = tostring(player.UserId)
		rank = 101 -- default: nicht in den Top 100
		for i, entry in ipairs(top) do
			if entry.key == myKey then
				rank = i
				break
			end
		end
	end

	local tier = Seasons.tierForRank(rank)
	if not tier then
		return { ok = false, reason = "not_eligible", rank = rank }
	end

	local gemsGrant = tier.gems
	PlayerDataService.update(player, function(p)
		p.currencies.gems += gemsGrant
		p.season.claimed = true
	end)
	PlayerDataService.patchEconomy(player)

	-- Season-Update ans Client
	local updated = PlayerDataService.get(player)
	if updated then
		seasonUpdateEvent:FireClient(player, seasonSnapshot(updated))
	end

	Logger.info("%s claimed season reward (rank %d, +%d gems)", player.Name, rank, gemsGrant)
	return { ok = true, rank = rank, gems = gemsGrant }
end

Logger.info("SeasonService online (currentId=%s)", Seasons.currentId())

return {}
