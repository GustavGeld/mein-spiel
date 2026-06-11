--!strict
-- FriendsBoostService — +5% production per friend online in same server, max +25%.
-- Scanned every 30s. Cached per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("FriendsBoost")

local BOOST_PER_FRIEND = 0.05   -- +5% per friend
local MAX_BOOST        = 0.25   -- +25% cap
local SCAN_INTERVAL    = 30     -- seconds

local FriendsBoostService = {}

local boostCache: { [Player]: number } = {}

function FriendsBoostService.getBoost(player: Player): number
	return boostCache[player] or 0
end

local function scanFriends()
	local playerList = Players:GetPlayers()
	local userIds: { [number]: Player } = {}
	for _, p in ipairs(playerList) do
		userIds[p.UserId] = p
	end

	for _, player in ipairs(playerList) do
		task.spawn(function()
			local profile = nil
			local pds = script.Parent:FindFirstChild("PlayerDataService")
			if pds then
				local PDS = require(pds) :: any
				profile = PDS.get(player)
			end
			if profile and profile.social and profile.social.friendsBoost == false then
				boostCache[player] = 0
				return
			end

			local friendCount = 0
			for _, other in ipairs(playerList) do
				if other ~= player then
					local ok, isFriend = pcall(function()
						return player:IsFriendsWith(other.UserId)
					end)
					if ok and isFriend then
						friendCount += 1
					end
				end
			end
			boostCache[player] = math.min(friendCount * BOOST_PER_FRIEND, MAX_BOOST)
		end)
	end
end

Players.PlayerRemoving:Connect(function(p)
	boostCache[p] = nil
end)

task.spawn(function()
	task.wait(10)
	while true do
		scanFriends()
		task.wait(SCAN_INTERVAL)
	end
end)

Logger.info("FriendsBoostService online (+%d%% per friend, max +%d%%).", BOOST_PER_FRIEND * 100, MAX_BOOST * 100)

return FriendsBoostService
