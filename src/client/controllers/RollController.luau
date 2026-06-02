--!strict
-- RollController — Client-Side Roll-Animation + Reveal-Popup.
--
-- Flow:
--   1) Server schickt OnPullResult mit { packId, results = { … }, auto? = true }.
--   2) Bei auto-roll: kein UI, Pulls landen still im Inventar.
--   3) Sonst: EINE Roll-Animation (Preview vom besten Pull), danach ein Grid mit allen
--      gezogenen Göttern. OK schließt das Popup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)
local Odds = require(Shared.math.Odds)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local RollController = {}

local CINEMATIC_STEP_MS  = 110  -- ms pro Vorschau-Wechsel
local CINEMATIC_HOLD     = 1.2

-- Auto-Roll-Flag: wird von ShopPanel/AutoRollController gesetzt.
local autoMode = false
function RollController.setAutoMode(v: boolean) autoMode = v end
function RollController.isAutoMode(): boolean return autoMode end

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

	-- Cinematic Card (für Roll-Phase)
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

	local oddsLabel = Instance.new("TextLabel")
	oddsLabel.Name = "OddsLabel"
	oddsLabel.BackgroundTransparency = 1
	oddsLabel.AnchorPoint = Vector2.new(0.5, 1)
	oddsLabel.Position = UDim2.new(0.5, 0, 1, -16)
	oddsLabel.Size = UDim2.new(1, -32, 0, 32)
	oddsLabel.Font = Enum.Font.GothamMedium
	oddsLabel.TextScaled = true
	oddsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	oddsLabel.Text = ""
	oddsLabel.Parent = card

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
		oddsLabel.Text = Odds.displayOdds(packId, rarityId)
		oddsLabel.TextColor3 = color
	end
end

-- Wählt das wertvollste Pull-Result für die Cinematic-Phase.
local function bestResult(results: { any })
	local best, bestIdx = results[1], 0
	for _, r in ipairs(results) do
		local cur = (Rarities.byId[r.rarityId] or {}).index or 0
		if cur > bestIdx then bestIdx = cur; best = r end
	end
	return best
end

local function playCinematic(sg: ScreenGui, packId: number, result: any)
	local card = sg.Dim.Card :: Frame
	card.Visible = true
	local godLabel = card:FindFirstChild("GodLabel") :: TextLabel

	local stepDuration = CINEMATIC_STEP_MS / 1000
	for previewIndex, previewRarityId in ipairs(result.preview) do
		applyRarity(card, previewRarityId, packId)
		godLabel.Text = previewRarityId
		local remaining = #result.preview - previewIndex
		if remaining < 3 then
			stepDuration = math.max(0.18, stepDuration * 1.5)
		end
		task.wait(stepDuration)
	end
	-- Final reveal
	applyRarity(card, result.rarityId, packId)
	godLabel.Text = result.rarityId

	if result.isSecret then
		(sg.Dim :: Frame).BackgroundTransparency = 0.1
		task.wait(CINEMATIC_HOLD * 1.8)
	else
		task.wait(CINEMATIC_HOLD)
	end
end

-- Reveal-Grid: zeigt alle Resultate als kleine Cards, OK schließt.
local function showResultsGrid(sg: ScreenGui, packId: number, results: { any })
	local dim = sg.Dim :: Frame
	dim.BackgroundTransparency = 0.55
	local card = sg.Dim.Card :: Frame
	card.Visible = false

	-- Bereinige alte Reveal-Box, falls vorhanden.
	local oldBox = dim:FindFirstChild("Reveal")
	if oldBox then oldBox:Destroy() end

	local box = Instance.new("Frame")
	box.Name = "Reveal"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.BackgroundColor3 = Color3.fromRGB(22, 24, 36)
	box.BorderSizePixel = 0
	box.Size = UDim2.fromOffset(640, 460)
	box.Parent = dim
	local boxCorner = Instance.new("UICorner", box)
	boxCorner.CornerRadius = UDim.new(0, 18)
	local boxStroke = Instance.new("UIStroke", box)
	boxStroke.Color = Color3.fromRGB(70, 80, 110)
	boxStroke.Thickness = 1

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 14)
	title.Size = UDim2.new(1, -40, 0, 32)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(245, 245, 250)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = string.format("%s %d %s",
		Locale.t("roll.youGot"), #results,
		#results == 1 and "God" or "Gods")
	title.Parent = box

	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(20, 56)
	grid.Size = UDim2.new(1, -40, 1, -120)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 4
	grid.Parent = box

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(118, 160)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, result in ipairs(results) do
		local def = Rarities.byId[result.rarityId]
		local color = def and def.color or Color3.fromRGB(180, 180, 180)
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = Color3.fromRGB(30, 34, 48)
		cell.BorderSizePixel = 0
		cell.LayoutOrder = i
		cell.Parent = grid
		local cc = Instance.new("UICorner", cell)
		cc.CornerRadius = UDim.new(0, 10)
		local cs = Instance.new("UIStroke", cell)
		cs.Color = color
		cs.Thickness = 2

		local strip = Instance.new("Frame")
		strip.BackgroundColor3 = color
		strip.BorderSizePixel = 0
		strip.Size = UDim2.new(1, 0, 0, 22)
		strip.Parent = cell
		local sc = Instance.new("UICorner", strip)
		sc.CornerRadius = UDim.new(0, 10)

		local rarityName = Instance.new("TextLabel")
		rarityName.BackgroundTransparency = 1
		rarityName.Size = UDim2.fromScale(1, 1)
		rarityName.Font = Enum.Font.GothamBold
		rarityName.TextSize = 12
		rarityName.TextColor3 = Color3.fromRGB(20, 20, 30)
		rarityName.Text = def and Locale.t(def.nameKey) or result.rarityId
		rarityName.Parent = strip

		local big = Instance.new("TextLabel")
		big.BackgroundTransparency = 1
		big.AnchorPoint = Vector2.new(0.5, 0.5)
		big.Position = UDim2.fromScale(0.5, 0.5)
		big.Size = UDim2.fromOffset(80, 80)
		big.Font = Enum.Font.GothamBlack
		big.TextSize = 48
		big.TextColor3 = color
		big.Text = string.upper(string.sub(result.rarityId, 1, 1))
		big.Parent = cell

		local odds = Instance.new("TextLabel")
		odds.BackgroundTransparency = 1
		odds.AnchorPoint = Vector2.new(0.5, 1)
		odds.Position = UDim2.new(0.5, 0, 1, -8)
		odds.Size = UDim2.new(1, -8, 0, 18)
		odds.Font = Enum.Font.GothamMedium
		odds.TextSize = 12
		odds.TextColor3 = Color3.fromRGB(200, 200, 200)
		odds.Text = Odds.displayOdds(packId, result.rarityId)
		odds.Parent = cell

		if result.isSecret then
			local badge = Instance.new("TextLabel")
			badge.BackgroundColor3 = Color3.fromRGB(255, 80, 200)
			badge.BorderSizePixel = 0
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -4, 0, 26)
			badge.Size = UDim2.fromOffset(58, 16)
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 10
			badge.TextColor3 = Color3.fromRGB(255, 255, 255)
			badge.Text = "SECRET"
			badge.Parent = cell
			local bc = Instance.new("UICorner", badge)
			bc.CornerRadius = UDim.new(0, 4)
		end
	end

	local okBtn = Instance.new("TextButton")
	okBtn.AnchorPoint = Vector2.new(0.5, 1)
	okBtn.Position = UDim2.new(0.5, 0, 1, -16)
	okBtn.Size = UDim2.fromOffset(220, 44)
	okBtn.BackgroundColor3 = Color3.fromRGB(64, 224, 110)
	okBtn.BorderSizePixel = 0
	okBtn.Font = Enum.Font.GothamBlack
	okBtn.TextSize = 18
	okBtn.TextColor3 = Color3.fromRGB(15, 30, 20)
	okBtn.Text = "OK"
	okBtn.Parent = box
	local okC = Instance.new("UICorner", okBtn)
	okC.CornerRadius = UDim.new(0, 10)

	local closed = false
	okBtn.Activated:Connect(function()
		if closed then return end
		closed = true
		sg.Enabled = false
		box:Destroy()
		card.Visible = true
		dim.BackgroundTransparency = 0.4
	end)
end

local rolling = false
local function playRoll(packId: number, results: { any })
	if rolling then return end -- mitten in einem Pull → kein neuer Animationsstart
	rolling = true
	local sg = getOrCreateScreen()
	sg.Enabled = true
	playCinematic(sg, packId, bestResult(results))
	showResultsGrid(sg, packId, results)
	rolling = false
end

function RollController.start()
	Net:Event("OnPullResult").OnClientEvent:Connect(function(payload)
		if not payload or not payload.results then return end
		if autoMode or payload.auto then return end -- still beim Auto-Roll
		playRoll(payload.packId, payload.results)
	end)
end

return RollController
