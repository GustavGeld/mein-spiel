--!strict
-- Codes — server-seitig definiert, niemals an den Client gesendet.
-- Reward: { gold?, gems?, faith? }

type CodeReward = { gold: number?, gems: number?, faith: number? }

local Codes: { [string]: CodeReward } = {
	["GODSOFFATE"]   = { gems = 50, gold = 10000 },
	["WELCOME"]      = { gems = 25 },
	["LAUNCHDAY"]    = { gems = 100, gold = 50000 },
	["DIVINEPOWER"]  = { gems = 75, gold = 25000 },
	["FAITHBOOST"]   = { gems = 30, faith = 500 },
	["100KREBIRTHS"] = { gems = 200 },
}

return Codes
