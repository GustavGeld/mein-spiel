--!strict
-- VIPService — Manages VIP Area gamepass perks:
--   1. Gem Trickle: +5 Gems every 10 min for VIP owners
--   2. VIP Zone Access: TouchedPart barrier in Workspace that ejects non-VIP players
--
-- The VIP lounge model in Workspace must have a Part named "VIPBarrier"
-- inside a folder/model named "VIPArea". Non-VIP players who touch it are
-- teleported back to the spawn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("VIP")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

local VIPService = {}

local GEM_TRICKLE_AMOUNT   = 5
local GEM_TRICKLE_INTERVAL = 10 * 60  -- 10 minutes

-- ─── VIP check helper ────────────────────────────────────────────────────────

function VIPService.isVIP(player: Player): boolean
	local profile = PlayerDataService.get(player)
	return profile ~= nil and profile.unlocks.gamepasses["vipArea"] == true
end

Net:Function("CheckVIPStatus").OnServerInvoke = function(player: Player)
	return { isVIP = VIPService.isVIP(player) }
end

-- ─── Gem Trickle loop ────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(GEM_TRICKLE_INTERVAL)
		local count = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if VIPService.isVIP(player) then
				EconomyService.add(player, "gems", GEM_TRICKLE_AMOUNT)
				count += 1
			end
		end
		if count > 0 then
			Logger.info("VIP gem trickle: gave %d gems to %d VIP players.", GEM_TRICKLE_AMOUNT, count)
		end
	end
end)

-- ─── VIP Barrier (Workspace model guard) ─────────────────────────────────────
-- Looks for Workspace.VIPArea.VIPBarrier; if not present, logs a warning once.

task.spawn(function()
	local workspace = game:GetService("Workspace")
	local vipArea = workspace:FindFirstChild("VIPArea")
	if not vipArea then
		Logger.warn("VIPArea folder not found in Workspace — barrier guard inactive. Create a folder 'VIPArea' with a Part 'VIPBarrier' to enable.")
		return
	end
	local barrier = vipArea:FindFirstChild("VIPBarrier")
	if not barrier or not barrier:IsA("BasePart") then
		Logger.warn("VIPArea.VIPBarrier Part not found — barrier guard inactive.")
		return
	end
	local part = barrier :: BasePart

	local BOUNCE_DISTANCE = 12   -- studs pushed back from barrier surface
	local BOUNCE_COOLDOWN  = 1.5 -- seconds before the same player can be bounced again
	local cooldowns: { [number]: number } = {}

	part.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if not character then return end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		if VIPService.isVIP(player) then return end

		-- Cooldown so rapid Touched spam doesn't stack
		local now = os.clock()
		if (cooldowns[player.UserId] or 0) > now then return end
		cooldowns[player.UserId] = now + BOUNCE_COOLDOWN

		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then return end

		-- Direction: from barrier centre toward the player (horizontal only)
		local diff = hrp.Position - part.Position
		local horizontal = Vector3.new(diff.X, 0, diff.Z)
		local dir = if horizontal.Magnitude > 0.01
			then horizontal.Unit
			else -part.CFrame.LookVector  -- fallback: push in front-facing direction

		hrp.CFrame = CFrame.new(hrp.Position + dir * BOUNCE_DISTANCE)

		Net:Event("OnVIPEject"):FireClient(player)
		Logger.info("Bounced non-VIP player %s off VIP barrier.", player.Name)
	end)

	-- Clean up cooldown entries for players who leave
	Players.PlayerRemoving:Connect(function(p)
		cooldowns[p.UserId] = nil
	end)

	Logger.info("VIP barrier active on %s.", part:GetFullName())
end)

Logger.info("VIPService online (trickle: %d gems / %ds).", GEM_TRICKLE_AMOUNT, GEM_TRICKLE_INTERVAL)

return VIPService
