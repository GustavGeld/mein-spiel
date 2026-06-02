--!strict
-- BroadcastService — globale Notifications (alle Spieler im Server).
-- Cross-Server (MessagingService) ist Stage 9; hier vorerst nur server-lokal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Broadcast")
local Net = require(Shared.remotes.Net)

local BroadcastService = {}

local event = Net:Event("OnBroadcast")

-- payload schema:
--   { type = "secret"|"fusion"|"rare_pull"|"text",
--     player = string?, godId = string?, rarityId = string?, rank = number?,
--     text = string?, rarityColor = Color3? }
function BroadcastService.fire(payload: any)
	for _, p in ipairs(Players:GetPlayers()) do
		event:FireClient(p, payload)
	end
	Logger.info("broadcast type=%s", tostring(payload and payload.type))
end

Logger.info("BroadcastService online.")

return BroadcastService
