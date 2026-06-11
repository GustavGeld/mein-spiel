--!strict
-- TutorialController — einfacher Step-by-Step Onboarding-Flow für neue Spieler.
-- Nur aktiv wenn profile.flags.tutorialDone == false.
-- 3 Schritte:
--   1. "Buy a pack!"     → NavBar > Shop anklicken
--   2. "Open your pack!" → NavBar > Inventory anklicken
--   3. "Place a god!"    → einen Gott in den Tempel einsetzen (OnTempleUpdate)
-- Nach Schritt 3: CompleteTutorial:InvokeServer(), Overlay verschwindet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net    = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)

local TutorialController = {}

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ─── Schritt-Definitionen ─────────────────────────────────────────────────────

local STEPS = {
	{ key = "shop",      navId = "shop",      descKey = "tutorial.step1.desc" },
	{ key = "inventory", navId = "inventory", descKey = "tutorial.step2.desc" },
	{ key = "temple",    navId = nil,         descKey = "tutorial.step3.desc" },
}

-- ─── Overlay-Aufbau ───────────────────────────────────────────────────────────

local overlay: ScreenGui? = nil
local pulseConn: RBXScriptConnection? = nil

local function removeOverlay()
	if pulseConn then pulseConn:Disconnect(); pulseConn = nil end
	if overlay then overlay:Destroy(); overlay = nil end
end

local function showStep(stepIdx: number, onNavBarClick: ((id: string) -> ())?)
	removeOverlay()

	local step = STEPS[stepIdx]
	if not step then return end

	local screen = Instance.new("ScreenGui")
	screen.Name = "TutorialOverlay"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 200
	screen.IgnoreGuiInset = true
	screen.Parent = PlayerGui
	overlay = screen

	-- Semi-transparentes Hintergrund-Panel unten (bleibt weg damit Spiel sichtbar bleibt)
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -20)
	card.Size = UDim2.fromOffset(440, 88)
	card.BackgroundColor3 = Color3.fromRGB(18, 24, 36)
	card.BorderSizePixel = 0
	card.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 200, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0
	stroke.Parent = card

	-- Schritt-Nummer
	local numLbl = Instance.new("TextLabel")
	numLbl.BackgroundTransparency = 1
	numLbl.Position = UDim2.fromOffset(16, 0)
	numLbl.Size = UDim2.fromOffset(36, 88)
	numLbl.Font = Enum.Font.GothamBlack
	numLbl.TextSize = 28
	numLbl.TextColor3 = Color3.fromRGB(120, 200, 255)
	numLbl.Text = tostring(stepIdx) .. "."
	numLbl.Parent = card

	-- Beschreibungstext
	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(56, 0)
	desc.Size = UDim2.new(1, -76, 1, 0)
	desc.Font = Enum.Font.GothamBold
	desc.TextSize = 18
	desc.TextColor3 = Color3.fromRGB(240, 240, 255)
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Center
	desc.Text = Locale.t(step.descKey)
	desc.Parent = card

	-- Skip-Button
	local skipBtn = Instance.new("TextButton")
	skipBtn.AnchorPoint = Vector2.new(1, 0)
	skipBtn.Position = UDim2.new(1, -8, 0, 8)
	skipBtn.Size = UDim2.fromOffset(48, 22)
	skipBtn.BackgroundTransparency = 1
	skipBtn.Font = Enum.Font.Gotham
	skipBtn.TextSize = 11
	skipBtn.TextColor3 = Color3.fromRGB(120, 130, 150)
	skipBtn.Text = Locale.t("tutorial.skip")
	skipBtn.Parent = card
	skipBtn.Activated:Connect(function()
		removeOverlay()
		pcall(function()
			Net:Function("CompleteTutorial"):InvokeServer()
		end)
	end)

	-- Pulsierender Pfeil Richtung NavBar (links)
	if step.navId then
		local arrow = Instance.new("TextLabel")
		arrow.AnchorPoint = Vector2.new(0, 0.5)
		arrow.Position = UDim2.new(0, 24, 0.5, -44)
		arrow.Size = UDim2.fromOffset(60, 44)
		arrow.BackgroundTransparency = 1
		arrow.Font = Enum.Font.GothamBlack
		arrow.TextSize = 36
		arrow.TextColor3 = Color3.fromRGB(120, 200, 255)
		arrow.Text = "◀"
		arrow.Parent = screen

		local t0 = os.clock()
		pulseConn = game:GetService("RunService").Heartbeat:Connect(function()
			local alpha = (math.sin((os.clock() - t0) * 3) + 1) * 0.5
			arrow.TextTransparency = 0.1 + alpha * 0.7
			arrow.Position = UDim2.new(0, 24 + alpha * 8, 0.5, -44)
		end)
	end
end

-- ─── Tutorial-Flow ────────────────────────────────────────────────────────────

local currentStep = 0

local function advanceStep()
	currentStep += 1
	if currentStep > #STEPS then
		removeOverlay()
		pcall(function()
			Net:Function("CompleteTutorial"):InvokeServer()
		end)
		return
	end
	showStep(currentStep)
end

function TutorialController.start(snapshot: any)
	-- Nur starten wenn tutorial noch nicht abgeschlossen
	if not snapshot then return end
	local flags = snapshot.flags
	if flags and flags.tutorialDone then return end

	currentStep = 0
	advanceStep() -- Schritt 1 anzeigen

	-- Schritt 1 → 2: NavBar Shop wurde angeklickt (UIController sendet kein Event,
	-- aber wir beobachten OnInventoryUpdate: wenn Spieler ein Pack hat, war er im Shop)
	Net:Event("OnInventoryUpdate").OnClientEvent:Connect(function(inv)
		if currentStep == 1 then
			-- Spieler hat Packs/Götter erhalten → Schritt 2 (öffne Inventory)
			local gods = inv and inv.gods
			if gods and #gods > 0 then
				advanceStep()
			end
		end
	end)

	-- Schritt 3: Erkennt wenn ein Gott im Tempel platziert wurde
	Net:Event("OnTempleUpdate").OnClientEvent:Connect(function(temple)
		if currentStep == 3 then
			local slots = temple and temple.slots
			if slots then
				for _, slot in ipairs(slots) do
					if slot.godUid then
						advanceStep() -- → fertig
						return
					end
				end
			end
		end
	end)

	-- Schritt 2 → 3: Inventory geöffnet + Gott sichtbar (Hint nach 5s Auto-Advance
	-- damit Spieler nicht steckt wenn er Inventory schon hat)
	task.delay(8, function()
		if currentStep == 2 then
			advanceStep()
		end
	end)
end

return TutorialController
