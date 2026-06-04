--!strict
-- LeaderboardController
--   - Empfängt OnLeaderboardUpdate (Server-Push, z.B. für spätere Live-Updates).
--   - Stellt fetchPage(category, page) für Panels bereit.
--   - Hält den eigenen Saison-Snapshot (seasonData) aktuell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Signal = require(Shared.utils.Signal)

local LeaderboardController = {}

-- Wird gefeuert, wenn seasonData sich ändert (OnSeasonUpdate Event vom Server).
LeaderboardController.SeasonChanged = Signal.new()

-- Letzter bekannter Season-Snapshot (gefüllt via OnSeasonUpdate + RequestProfile).
-- Typ: { id: string, score: number, claimed: boolean, secs: number }?
LeaderboardController.seasonData = nil

-- Aktualisiert den Season-Snapshot (aufgerufen von UIController nach RequestProfile).
function LeaderboardController.setSeasonData(data: any)
	if not data then return end
	LeaderboardController.seasonData = {
		id      = data.id or "?",
		score   = data.score or 0,
		claimed = data.claimed or false,
		secs    = data.secs or 0,
	}
	LeaderboardController.SeasonChanged:Fire(LeaderboardController.seasonData)
end

-- Leaderboard-Seite vom Server anfordern.
-- Gibt { entries, page, totalPages } zurück oder nil bei Fehler.
function LeaderboardController.fetchPage(category: string, page: number): any
	local ok, result = pcall(function()
		return Net:Function("RequestLeaderboard"):InvokeServer(category, page)
	end)
	if ok then return result end
	return nil
end

-- Saison-Belohnung einfordern.
-- Gibt { ok, rank?, gems?, reason? } zurück.
function LeaderboardController.claimSeasonReward(): any
	local ok, result = pcall(function()
		return Net:Function("ClaimSeasonReward"):InvokeServer()
	end)
	if ok then return result end
	return { ok = false, reason = "network_error" }
end

function LeaderboardController.start()
	-- Empfange Server-Push (für zukünftige Live-Updates)
	Net:Event("OnLeaderboardUpdate").OnClientEvent:Connect(function(_data: any)
		-- Reserviert; derzeit sendet der Server kein Push-Update für Leaderboards.
	end)

	Net:Event("OnSeasonUpdate").OnClientEvent:Connect(function(data: any)
		LeaderboardController.setSeasonData(data)
	end)
end

return LeaderboardController
