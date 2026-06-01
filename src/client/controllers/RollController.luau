--!strict
-- RollController — Client-Side Roll-Animation.
-- Server schickt Results inkl. Preview-Liste; Client scrollt durch Preview und
-- zeigt das finale Ergebnis. Live-Wahrscheinlichkeit unter dem aktuellen Gott.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)
local Odds = require(Shared.math.Odds)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RollController = {}

local CINEMATIC_MS = { 250, 200, 160, 130, 100 } -- ms pro Vorschau-Wechsel, langsamer bei höherem Tier
local CINEMATIC_FINAL_HOLD = 1.8

local function getOrCreateScreen(): ScreenGui
	local existing = PlayerGui:FindFirstChild("RollScreen")
	if existing then return existing :: ScreenGui end
	local sg = Instance.new("ScreenGui")
	sg.Name = "RollScreen"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 100
	sg.Enabled = false
	sg.Parent = PlayerGui

	-- Dim-Background
	local bg = Instance.new("Frame")
	bg.Name = "Dim"
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.Parent = sg

	-- Card in der Mitte
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 280)
	card.Parent = bg

	local corner = Instance.new("UICorner", card)
	corner.CornerRadius = UDim.new(0, 18)

	local stroke = Instance.new("UIStroke", card)
	stroke.Name = "RarityStroke"
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(255, 255, 255)

	-- Rarity-Name
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.AnchorPoint = Vector2.new(0.5, 0)
	rarityLabel.Position = UDim2.new(0.5, 0, 0, 22)
	rarityLabel.Size = UDim2.new(1, -32, 0, 56)
	rarityLabel.Font = Enum.Font.GothamBlack
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityLabel.Text = "—"
	rarityLabel.Parent = card

	-- God-Id (Platzhalter — später durch ViewportFrame ersetzt)
	local godLabel = Instance.new("TextLabel")
	godLabel.Name = "GodLabel"
	godLabel.BackgroundTransparency = 1
	godLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	godLabel.Position = UDim2.fromScale(0.5, 0.5)
	godLabel.Size = UDim2.new(1, -32, 0, 80)
	godLabel.Font = Enum.Font.GothamBold
	godLabel.TextScaled = true
	godLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	godLabel.Text = ""
	godLabel.Parent = card

	-- Odds-Anzeige unter dem Gott (Rarity-Farbe)
	local oddsLabel = Instance.new("TextLabel")
	oddsLabel.Name = "OddsLabel"
	oddsLabel.BackgroundTransparency = 1
	oddsLabel.AnchorPoint = Vector2.new(0.5, 1)
	oddsLabel.Position = UDim2.new(0.5, 0, 1, -56)
	oddsLabel.Size = UDim2.new(1, -32, 0, 32)
	oddsLabel.Font = Enum.Font.GothamMedium
	oddsLabel.TextScaled = true
	oddsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	oddsLabel.Text = ""
	oddsLabel.Parent = card

	-- Continue-Button
	local continueBtn = Instance.new("TextButton")
	continueBtn.Name = "ContinueBtn"
	continueBtn.AnchorPoint = Vector2.new(0.5, 1)
	continueBtn.Position = UDim2.new(0.5, 0, 1, -12)
	continueBtn.Size = UDim2.fromOffset(180, 40)
	continueBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
	continueBtn.Font = Enum.Font.GothamBold
	continueBtn.TextScaled = true
	continueBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	continueBtn.Text = Locale.t("ui.continue")
	continueBtn.Visible = false
	continueBtn.Parent = card

	local cbCorner = Instance.new("UICorner", continueBtn)
	cbCorner.CornerRadius = UDim.new(0, 10)

	return sg
end

local function applyRarity(card: Frame, rarityId: string, packId: number)
	local def = Rarities.byId[rarityId]
	local color = def and def.color or Color3.fromRGB(180, 180, 180)
	local stroke = card:FindFirstChild("RarityStroke") :: UIStroke
	if stroke then stroke.Color = color end
	local rarityLabel = card:FindFirstChild("RarityLabel") :: TextLabel
	if rarityLabel then
		rarityLabel.Text = Locale.t(def and def.nameKey or "rarity.common")
		rarityLabel.TextColor3 = color
	end
	local oddsLabel = card:FindFirstChild("OddsLabel") :: TextLabel
	if oddsLabel then
		local odds = Odds.displayOdds(packId, rarityId)
		oddsLabel.Text = odds
		oddsLabel.TextColor3 = color
	end
end

local function playRoll(packId: number, results: { any })
	local sg = getOrCreateScreen()
	sg.Enabled = true
	local card = sg.Dim.Card :: Frame
	local continueBtn = card:FindFirstChild("ContinueBtn") :: TextButton

	local i = 1
	while i <= #results do
		local result = results[i]
		local stepDuration = CINEMATIC_MS[1] / 1000
		continueBtn.Visible = false
		-- Scroll durch Vorschau
		for previewIndex, previewRarityId in ipairs(result.preview) do
			applyRarity(card, previewRarityId, packId)
			local godLabel = card:FindFirstChild("GodLabel") :: TextLabel
			godLabel.Text = previewRarityId
			-- Letzte 3 dramatisch verlangsamen
			local remaining = #result.preview - previewIndex
			if remaining < 3 then
				stepDuration = math.max(0.18, stepDuration * 1.5)
			end
			task.wait(stepDuration)
		end
		-- Final Reveal
		applyRarity(card, result.rarityId, packId)
		local finalLabel = card:FindFirstChild("GodLabel") :: TextLabel
		finalLabel.Text = result.rarityId
		if result.isSecret then
			-- Screen-Flash + Continue erst nach längerem Hold
			local dim = sg.Dim :: Frame
			dim.BackgroundTransparency = 0.1
			task.wait(CINEMATIC_FINAL_HOLD * 1.8)
		else
			task.wait(CINEMATIC_FINAL_HOLD)
		end
		continueBtn.Visible = true
		-- Auf Continue warten oder auto-skip nach 6s
		local clicked = false
		local conn
		conn = continueBtn.Activated:Connect(function() clicked = true; conn:Disconnect() end)
		local start = os.clock()
		while not clicked and os.clock() - start < 6 do
			RunService.Heartbeat:Wait()
		end
		if conn.Connected then conn:Disconnect() end
		i += 1
	end
	sg.Enabled = false
end

function RollController.start()
	Net:Event("OnPullResult").OnClientEvent:Connect(function(payload)
		if not payload or not payload.results then return end
		playRoll(payload.packId, payload.results)
	end)
end

return RollController
