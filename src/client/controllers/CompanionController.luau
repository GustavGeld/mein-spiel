--!strict
-- CompanionController — spawns and animates the personal companion "Aion".
--
-- Custom 3D skin setup:
--   1. In Studio, inside ReplicatedStorage create a Folder named "AionSkins".
--   2. Inside that folder, place any Model and name it after the skin id
--      (e.g. "ember", "void", "default", "storm" …).
--   3. Make sure the Model has a PrimaryPart set.
--   The model is used as-is; color/material are NOT applied so it looks
--   exactly as you designed it in Studio.
--   Skins without a matching model fall back to the colored orb.
--
-- Legacy: a Model named "AionTemplate" in ReplicatedStorage is still
-- supported as a generic fallback template for all orb-based skins.

local RunService      = game:GetService("RunService")
local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net    = require(Shared.remotes.Net)
local CompanionSkins = require(Shared.config.CompanionSkins)

local LocalPlayer = Players.LocalPlayer

-- ─── Wander / Animation constants ────────────────────────────────────────────
local WANDER_R_BASE = 2.2    -- base horizontal distance from player (studs)
local WANDER_R_AMP  = 0.8    -- horizontal radius varies ±this
local WANDER_Y_BASE = -0.5   -- vertical center offset from HRP
local WANDER_Y_AMP  = 1.5    -- vertical range ±this (flies up and down)
local FOLLOW_LERP   = 2.2    -- how fast Aion chases its goal (lower = dreamier lag)
local FACE_LERP     = 1.8    -- how fast the facing direction rotates

local CompanionController = {}

-- ─── State ────────────────────────────────────────────────────────────────────
local companionModel: Model? = nil
local heartbeat: RBXScriptConnection? = nil
local currentSkin = "default"
local companionEnabled = true
-- forward declaration so setEnabled (defined early) can call spawnCompanion (defined later)
local spawnCompanion: (character: Model) -> ()

-- ─── Skin application ────────────────────────────────────────────────────────

local function applySkinToModel(model: Model, skinId: string)
	local skin = CompanionSkins.byId[skinId] or CompanionSkins.byId["default"]
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color    = skin.color
			part.Material = skin.material
		end
	end
	-- Update PointLight glow color
	local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if body then
		local light = body:FindFirstChildWhichIsA("PointLight")
		if light then light.Color = skin.glowColor end
	end
	currentSkin = skinId
end

function CompanionController.setSkin(skinId: string)
	currentSkin = skinId
	if not companionEnabled then return end
	-- Always respawn so custom 3D models swap out correctly.
	-- For color-only skins this is a quick rebuild; the brief flash is acceptable.
	local char = LocalPlayer.Character
	if char then
		if companionModel then companionModel:Destroy(); companionModel = nil end
		if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
		spawnCompanion(char)
	end
end

function CompanionController.getCurrentSkin(): string
	return currentSkin
end

-- Hides/shows the 3D model without destroying it (used by Hide GUI toggle)
function CompanionController.setVisible(visible: boolean)
	if not companionModel then return end
	for _, desc in ipairs(companionModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Transparency = visible and (desc:GetAttribute("origTransp") or 0) or 1
		elseif desc:IsA("BillboardGui") or desc:IsA("PointLight") then
			desc.Enabled = visible
		end
	end
end

function CompanionController.isEnabled(): boolean
	return companionEnabled
end

function CompanionController.setEnabled(enabled: boolean)
	companionEnabled = enabled
	if not enabled then
		if companionModel then
			companionModel:Destroy()
			companionModel = nil
		end
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	else
		local char = LocalPlayer.Character
		if char then spawnCompanion(char) end
	end
end

-- ─── Build companion model ────────────────────────────────────────────────────
-- Returns (model, isCustom).  isCustom=true means the model came from the
-- AionSkins folder and should NOT have its colors overwritten.

local function buildModel(skinId: string): (Model, boolean)
	-- 1. Check ReplicatedStorage > AionSkins > <skinId>
	local skinsFolder = ReplicatedStorage:FindFirstChild("AionSkins")
	if skinsFolder then
		local template = skinsFolder:FindFirstChild(skinId)
		if template and template:IsA("Model") then
			local clone = template:Clone()
			clone.Name = "Aion"
			return clone, true
		end
	end

	-- 2. Legacy generic template (color will still be applied on top)
	local template = ReplicatedStorage:FindFirstChild("AionTemplate")
	if template and template:IsA("Model") then
		local clone = template:Clone()
		clone.Name = "Aion"
		return clone, false
	end

	-- 3. Procedural fallback orb
	local model = Instance.new("Model")
	model.Name = "Aion"

	local body = Instance.new("Part")
	body.Name        = "Body"
	body.Shape       = Enum.PartType.Ball
	body.Size        = Vector3.new(0.85, 0.85, 0.85)
	body.Anchored    = true
	body.CanCollide  = false
	body.CastShadow  = false
	body.Color       = Color3.fromRGB(170, 205, 255)
	body.Material    = Enum.Material.Neon
	body.Parent      = model
	model.PrimaryPart = body

	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range      = 7
	light.Color      = Color3.fromRGB(170, 205, 255)
	light.Parent     = body

	-- Small halo ring
	local ring = Instance.new("Part")
	ring.Name       = "Ring"
	ring.Shape      = Enum.PartType.Cylinder
	ring.Size       = Vector3.new(0.08, 1.3, 1.3)
	ring.Anchored   = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Color      = Color3.fromRGB(200, 225, 255)
	ring.Material   = Enum.Material.Neon
	ring.Transparency = 0.35
	ring:SetAttribute("origTransp", 0.35)
	ring.Parent     = model

	-- Name tag
	local bb = Instance.new("BillboardGui")
	bb.Size         = UDim2.fromOffset(70, 18)
	bb.StudsOffset  = Vector3.new(0, 0.9, 0)
	bb.AlwaysOnTop  = false
	bb.LightInfluence = 0
	bb.Parent       = body

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size      = UDim2.fromScale(1, 1)
	lbl.Font      = Enum.Font.GothamBold
	lbl.TextSize  = 11
	lbl.TextColor3 = Color3.fromRGB(220, 235, 255)
	lbl.Text      = "Aion"
	lbl.Parent    = bb

	return model, false
end

-- ─── Spawn / attach ───────────────────────────────────────────────────────────

spawnCompanion = function(character: Model)
	-- Clean up old instance
	if companionModel then companionModel:Destroy() end
	if heartbeat then heartbeat:Disconnect() end

	local hrp = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not hrp then return end

	local model, isCustomModel = buildModel(currentSkin)
	if not isCustomModel then
		applySkinToModel(model, currentSkin)
	end

	-- Disable all collisions so the player never gets pushed by Aion
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch   = false
			part.CanQuery   = false
		end
	end

	model.Parent = workspace
	companionModel = model

	-- ── Per-spawn animation state ─────────────────────────────────────────────
	-- Start at a random phase so multiple respawns feel fresh
	local t       = math.random() * 100
	local smoothFacing = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	local smoothVel    = Vector3.zero          -- tracked velocity for facing
	local lastPos      = nil :: Vector3?

	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not companionModel or not companionModel.Parent then return end
		if not hrp or not hrp.Parent then return end

		t += dt

		-- ── Wander goal (in player-local space) ──────────────────────────────
		-- Angle drifts with irrational-ratio perturbations → never repeats.
		local wanderAngle = t * 0.22
			+ math.sin(t * 0.13 + 1.7) * 1.6
			+ math.cos(t * 0.31 + 0.9) * 0.9

		-- Radius breathes in and out
		local wanderR = WANDER_R_BASE
			+ math.sin(t * 0.19 + 2.3) * WANDER_R_AMP * 0.6
			+ math.sin(t * 0.43 + 0.4) * WANDER_R_AMP * 0.4

		-- Height: two slow waves → organic up/down drift
		local wanderY = WANDER_Y_BASE
			+ math.sin(t * 0.16 + 1.1) * WANDER_Y_AMP * 0.55
			+ math.sin(t * 0.37 + 2.8) * WANDER_Y_AMP * 0.45

		-- Side-to-side in player's right/left axis — full range
		local localX = math.cos(wanderAngle) * wanderR

		-- Depth: always behind/beside the player.
		-- sin term oscillates ±0.35 around a +0.75 base → range [0.40 … 1.10] × wanderR.
		-- This means Aion is NEVER directly in front, always somewhere behind or to the side.
		local localZ = (math.sin(t * 0.17 + 2.1) * 0.35 + 0.75) * wanderR

		-- Project into world space using the player's actual facing direction
		local hrpCF = hrp.CFrame
		local right = hrpCF.RightVector
		local back  = -hrpCF.LookVector   -- "behind the player"

		local goal = hrp.Position
			+ right * localX
			+ back  * localZ
			+ Vector3.new(0, wanderY, 0)

		-- ── Position: lazy follow with organic lag ────────────────────────────
		local body = companionModel.PrimaryPart
		if not body then return end

		local posAlpha = math.min(1, dt * FOLLOW_LERP)
		local newPos   = body.Position:Lerp(goal, posAlpha)

		-- ── Facing: track actual velocity, ignore vertical component ─────────
		if lastPos then
			local vel = (newPos - lastPos) * (1 / dt)
			smoothVel  = smoothVel:Lerp(vel, math.min(1, dt * 5))
		end
		lastPos = newPos

		local flatVel = Vector3.new(smoothVel.X, 0, smoothVel.Z)
		if flatVel.Magnitude > 0.08 then
			smoothFacing = smoothFacing:Lerp(flatVel.Unit, math.min(1, dt * FACE_LERP))
			if smoothFacing.Magnitude > 0 then
				smoothFacing = smoothFacing.Unit
			end
		end

		companionModel:PivotTo(CFrame.lookAt(newPos, newPos + smoothFacing))

		-- ── Ring: lazy wobble spin ────────────────────────────────────────────
		local ring = companionModel:FindFirstChild("Ring") :: BasePart?
		if ring then
			ring.CFrame = CFrame.new(newPos)
				* CFrame.Angles(math.sin(t * 0.7) * 0.4, t * 1.1, math.cos(t * 0.5) * 0.3)
		end
	end)
end

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

function CompanionController.start()
	-- Fetch saved skin from server
	task.spawn(function()
		local ok, data = pcall(function()
			return Net:Function("GetCompanionData"):InvokeServer()
		end)
		if ok and data then
			currentSkin = data.skin or "default"
		end
		-- Check if companion is enabled in settings (read from profile via RequestProfile)
		local okP, profile = pcall(function()
			return Net:Function("RequestProfile"):InvokeServer()
		end)
		if okP and profile and profile.settings then
			companionEnabled = profile.settings.companionEnabled ~= false
		end
		if not companionEnabled then return end
		local char = LocalPlayer.Character
		if char then spawnCompanion(char) end
	end)

	LocalPlayer.CharacterAdded:Connect(function(char)
		if not companionEnabled then return end
		task.wait(0.5)
		spawnCompanion(char)
	end)

	LocalPlayer.CharacterRemoving:Connect(function()
		if companionModel then
			companionModel:Destroy()
			companionModel = nil
		end
		if heartbeat then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end)
end

return CompanionController
