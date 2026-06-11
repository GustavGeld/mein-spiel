--!strict
-- AuraController — applies a cosmetic aura to the local player's character.
-- Tier is unlocked by claiming collection-row rewards.
-- Visual: SelectionBox outline + pulsing PointLight on HumanoidRootPart.

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net    = require(Shared.remotes.Net)
local Auras  = require(Shared.config.Auras)

local LocalPlayer = Players.LocalPlayer
local AuraController = {}

local currentTier    = 0
local activeLight: PointLight? = nil
local activeSelection: SelectionBox? = nil
local activeTween: Tween? = nil

local function clearAura()
	if activeTween then activeTween:Cancel(); activeTween = nil end
	if activeLight and activeLight.Parent then activeLight:Destroy() end
	if activeSelection and activeSelection.Parent then activeSelection:Destroy() end
	activeLight    = nil
	activeSelection = nil
end

local function applyAura(character: Model, tier: number)
	clearAura()
	if tier <= 0 then return end
	local def = Auras[tier]
	if not def then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	-- Pulsing point light
	local light = Instance.new("PointLight")
	light.Color      = def.color
	light.Brightness = def.lightBrightness
	light.Range      = def.lightRange
	light.Shadows    = false
	light.Parent     = hrp
	activeLight      = light

	activeTween = TweenService:Create(light,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Brightness = def.lightBrightness * 1.45 }
	)
	activeTween:Play()

	-- Selection box outline around the whole character
	local sel = Instance.new("SelectionBox")
	sel.Color3              = def.color
	sel.LineThickness       = def.selectionThickness
	sel.SurfaceTransparency = 0.93
	sel.SurfaceColor3       = def.color
	sel.Adornee             = character
	sel.Parent              = workspace
	activeSelection         = sel
end

function AuraController.getCurrentTier(): number
	return currentTier
end

function AuraController.setTier(tier: number)
	currentTier = tier
	local char = LocalPlayer.Character
	if char then applyAura(char, tier) end
end

function AuraController.start()
	-- Re-apply on every respawn
	LocalPlayer.CharacterAdded:Connect(function(char)
		if currentTier > 0 then
			task.wait(0.4)
			applyAura(char, currentTier)
		end
	end)
	LocalPlayer.CharacterRemoving:Connect(clearAura)

	-- Server pushes updates when a collection reward is claimed
	Net:Event("OnAuraUpdate").OnClientEvent:Connect(function(tier: number)
		AuraController.setTier(tier or 0)
	end)
end

return AuraController
