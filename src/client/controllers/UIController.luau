--!strict
-- UIController — orchestriert NavBar, CurrencyBar, Panel-Wechsel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)

local Theme = require(script.Parent.Parent.ui.Theme)
local NavBar = require(script.Parent.Parent.ui.NavBar)
local CurrencyBar = require(script.Parent.Parent.ui.CurrencyBar)
local Panel = require(script.Parent.Parent.ui.Panel)
local ShopPanel = require(script.Parent.Parent.ui.panels.ShopPanel)
local InventoryPanel = require(script.Parent.Parent.ui.panels.InventoryPanel)
local IndexPanel = require(script.Parent.Parent.ui.panels.IndexPanel)
local SettingsPanel = require(script.Parent.Parent.ui.panels.SettingsPanel)
local RebirthPanel = require(script.Parent.Parent.ui.panels.RebirthPanel)
local QuestsPanel = require(script.Parent.Parent.ui.panels.QuestsPanel)
local DailyPanel = require(script.Parent.Parent.ui.panels.DailyPanel)
local FusionPanel = require(script.Parent.Parent.ui.panels.FusionPanel)
local GamepassPanel = require(script.Parent.Parent.ui.panels.GamepassPanel)
local TradePanel = require(script.Parent.Parent.ui.panels.TradePanel)
local StubPanel = require(script.Parent.Parent.ui.panels.StubPanel)
local LeaderboardPanel = require(script.Parent.Parent.ui.panels.LeaderboardPanel)
local SeasonPanel = require(script.Parent.Parent.ui.panels.SeasonPanel)
local RewardsPanel = require(script.Parent.Parent.ui.panels.RewardsPanel)
local AuctionPanel = require(script.Parent.Parent.ui.panels.AuctionPanel)
local CompanionPanel = require(script.Parent.Parent.ui.panels.CompanionPanel)
local TemplePanel    = require(script.Parent.Parent.ui.panels.TemplePanel)
local RollController = require(script.Parent.RollController)
local LeaderboardController = require(script.Parent.LeaderboardController)
local TutorialController   = require(script.Parent.TutorialController)
local AutoRollController = require(script.Parent.AutoRollController)
local TradeController = require(script.Parent.TradeController)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UIController = {}

local snapshot: any = {
	currencies = {},
	inventory = { gods = {} },
	temple = { slots = {} },
	unlocks = { packs = {}, gamepasses = {} },
	lifetime = { gold = 0, rebirths = 0 },
	divinity = { spent = 0, tree = {} },
	collection = { discovered = {} },
	quests = { daily = {}, weekly = {}, minute = { lastClaim = 0 }, login = { streak = 0, lastDay = 0, claimed = false } },
	settings = {},
}

local screen: ScreenGui
local currencyBarApi
local currentPanel: any = nil
local currentPanelId: string? = nil

local function closePanel()
	if currentPanel then
		currentPanel.destroy()
		currentPanel = nil
		currentPanelId = nil
	end
end

local PANEL_TITLES = {
	shop       = "nav.shop",
	inventory  = "nav.inventory",
	temple     = "nav.temple",
	index      = "nav.collection",
	quests     = "nav.quests",
	daily      = "nav.daily",
	rewards    = "nav.rewards",
	trade      = "nav.trade",
	fusion     = "nav.fusion",
	rebirth    = "nav.rebirth",
	gamepasses   = "nav.gamepasses",
	leaderboard  = "nav.leaderboard",
	season       = "nav.season",
	auctions     = "nav.auctions",
	settings     = "nav.settings",
}

-- Panels mit eigener Größe (größer als Standard 820×560).
local PANEL_SIZES: { [string]: UDim2 } = {
	inventory  = UDim2.fromOffset(1100, 700),
	gamepasses = UDim2.fromOffset(960, 640),
	fusion       = UDim2.fromOffset(960, 640),
	trade        = UDim2.fromOffset(960, 620),
	leaderboard  = UDim2.fromOffset(820, 620),
	season       = UDim2.fromOffset(720, 600),
}

local function openPanel(id: string)
	-- Toggle: gleicher Tab schließt das Panel.
	if currentPanelId == id then
		closePanel()
		return
	end
	closePanel()
	currentPanelId = id
	local title = Locale.t(PANEL_TITLES[id] or "ui.loading")
	local handle = Panel.create(screen, title, closePanel, PANEL_SIZES[id])
	currentPanel = handle

	if id == "shop" then
		ShopPanel.create(handle.body, snapshot)
	elseif id == "inventory" then
		InventoryPanel.create(handle.body, snapshot)
	elseif id == "index" then
		IndexPanel.create(handle.body, snapshot)
	elseif id == "settings" then
		SettingsPanel.create(handle.body, snapshot)
	elseif id == "quests" then
		QuestsPanel.create(handle.body, snapshot)
	elseif id == "daily" then
		DailyPanel.create(handle.body, snapshot)
	elseif id == "rewards" then
		RewardsPanel.create(handle.body, snapshot)
	elseif id == "trade" then
		TradePanel.create(handle.body, snapshot)
	elseif id == "rebirth" then
		RebirthPanel.create(handle.body, snapshot)
	elseif id == "fusion" then
		FusionPanel.create(handle.body, snapshot)
	elseif id == "gamepasses" then
		GamepassPanel.create(handle.body, snapshot)
	elseif id == "leaderboard" then
		LeaderboardPanel.create(handle.body, snapshot)
	elseif id == "season" then
		SeasonPanel.create(handle.body, snapshot)
	elseif id == "auctions" then
		AuctionPanel.create(handle.body, snapshot)
	elseif id == "temple" then
		TemplePanel.create(handle.body, snapshot)
	end
end

-- Vor dem Rebuild Scroll-Positionen aller ScrollingFrames im Body indexweise
-- speichern, danach in derselben Reihenfolge wiederherstellen — so springt das
-- Panel beim Pass-Toggle nicht mehr nach ganz oben.
local function captureScrollPositions(body: Instance): { Vector2 }
	local out: { Vector2 } = {}
	for _, child in ipairs(body:GetDescendants()) do
		if child:IsA("ScrollingFrame") then
			table.insert(out, child.CanvasPosition)
		end
	end
	return out
end

local function restoreScrollPositions(body: Instance, positions: { Vector2 })
	if #positions == 0 then return end
	task.defer(function()
		-- Warten bis AutomaticCanvasSize berechnet wurde.
		task.wait()
		local i = 0
		for _, child in ipairs(body:GetDescendants()) do
			if child:IsA("ScrollingFrame") then
				i += 1
				if positions[i] then
					child.CanvasPosition = positions[i]
				end
			end
		end
	end)
end

local function rebuildIfPanelOpen()
	if not currentPanel or not currentPanelId then return end
	local id = currentPanelId
	local scrollMemory = captureScrollPositions(currentPanel.body)
	-- Force-rebuild trotz Toggle.
	currentPanelId = nil
	openPanel(id)
	if currentPanel then
		restoreScrollPositions(currentPanel.body, scrollMemory)
	end
end

UIController.snapshot = snapshot

function UIController.openPanel(id: string)
	openPanel(id)
end

-- Erzwingt Rebuild des aktuell offenen Panels (kein Toggle, kein No-op).
function UIController.forceRebuild()
	rebuildIfPanelOpen()
end

local guiHidden = false
local navBarFrame: Frame? = nil
local currencyBarFrame: Frame? = nil
local aionBtnRef: ImageButton? = nil

local function setGuiHidden(hide: boolean)
	guiHidden = hide
	snapshot.guiHidden = hide  -- persists across panel rebuilds so toggle re-reads correct state
	if navBarFrame then navBarFrame.Visible = not hide end
	if currencyBarFrame then currencyBarFrame.Visible = not hide end
	if aionBtnRef then aionBtnRef.Visible = not hide end
end

function UIController.start()
	screen = Instance.new("ScreenGui")
	screen.Name = "MainUI"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 50
	screen.Parent = PlayerGui

	currencyBarApi = CurrencyBar.create(screen)
	-- Referenz auf CurrencyBar-Container speichern (für Hide GUI)
	currencyBarFrame = screen:FindFirstChild("CurrencyBar") :: Frame?

	navBarFrame = NavBar.create(screen, openPanel)

	-- ── Settings-Button rechts oben (immer sichtbar) ─────────────────────────
	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "SettingsBtn"
	settingsBtn.AnchorPoint = Vector2.new(1, 0)
	settingsBtn.Position = UDim2.new(1, -16, 0, 16)
	settingsBtn.Size = UDim2.fromOffset(52, 52)
	settingsBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 64)
	settingsBtn.BorderSizePixel = 0
	settingsBtn.AutoButtonColor = false
	settingsBtn.Font = Enum.Font.GothamBlack
	settingsBtn.TextSize = 24
	settingsBtn.TextColor3 = Color3.fromRGB(180, 188, 210)
	settingsBtn.Text = "⚙"
	settingsBtn.ZIndex = 100
	settingsBtn.Parent = screen
	local sc = Instance.new("UICorner", settingsBtn); sc.CornerRadius = UDim.new(0, 14)
	local ss = Instance.new("UIStroke", settingsBtn); ss.Color = Color3.fromRGB(70, 80, 110); ss.Thickness = 2

	game:GetService("TweenService"):Create(settingsBtn,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad), { }
	)
	settingsBtn.MouseEnter:Connect(function()
		settingsBtn.BackgroundColor3 = Color3.fromRGB(60, 68, 90)
	end)
	settingsBtn.MouseLeave:Connect(function()
		settingsBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 64)
	end)
	settingsBtn.Activated:Connect(function()
		openPanel("settings")
	end)

	-- ── Aion companion button (rechte Seite, vertikal zentriert) ────────────────
	local aionBtn = Instance.new("ImageButton")
	aionBtn.Name            = "AionBtn"
	aionBtn.AnchorPoint     = Vector2.new(1, 0.5)
	aionBtn.Position        = UDim2.new(1, -12, 0.5, 0)
	aionBtn.Size            = UDim2.fromOffset(52, 52)
	aionBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 200)
	aionBtn.BorderSizePixel = 0
	aionBtn.AutoButtonColor = false
	aionBtn.Image           = "rbxassetid://94345125174828"
	aionBtn.ImageColor3     = Color3.fromRGB(255, 255, 255)
	aionBtn.ScaleType       = Enum.ScaleType.Fit
	aionBtn.ZIndex          = 100
	aionBtn.Parent          = screen
	do
		local c = Instance.new("UICorner", aionBtn); c.CornerRadius = UDim.new(0, 14)
		local s = Instance.new("UIStroke", aionBtn);  s.Color = Color3.fromRGB(100, 150, 255); s.Thickness = 2
	end
	aionBtnRef = aionBtn  -- store for setGuiHidden
	aionBtn.MouseEnter:Connect(function()  aionBtn.BackgroundColor3 = Color3.fromRGB(60, 110, 230) end)
	aionBtn.MouseLeave:Connect(function()  aionBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 200)  end)
	aionBtn.Activated:Connect(function()
		local CC = require(script.Parent.CompanionController)
		local AC = require(script.Parent.AuraController)
		CompanionPanel.open(CC.getCurrentSkin(), AC.getCurrentTier())
	end)

	-- Hide GUI Callback für SettingsPanel
	SettingsPanel.onHideGui = setGuiHidden

	-- Leaderboard-Controller starten (OnSeasonUpdate Listener etc.)
	LeaderboardController.start()

	-- Trade-Controller starten + Invite-Popup + automatischer Trade-Panel-Open
	TradeController.start()
	TradeController.InviteChanged:Connect(function(invite)
		if not invite then
			local existing = screen:FindFirstChild("TradeInvitePopup")
			if existing then existing:Destroy() end
			return
		end
		local existing = screen:FindFirstChild("TradeInvitePopup")
		if existing then existing:Destroy() end
		local box = Instance.new("Frame")
		box.Name = "TradeInvitePopup"
		box.AnchorPoint = Vector2.new(0.5, 0)
		box.Position = UDim2.new(0.5, 0, 0, 24)
		box.Size = UDim2.fromOffset(420, 80)
		box.BackgroundColor3 = Theme.color.panel
		box.BorderSizePixel = 0
		box.Parent = screen
		local c = Instance.new("UICorner", box); c.CornerRadius = UDim.new(0, 12)
		local s = Instance.new("UIStroke", box); s.Color = Theme.color.accent; s.Thickness = 2

		local txt = Instance.new("TextLabel")
		txt.BackgroundTransparency = 1
		txt.Position = UDim2.fromOffset(14, 8)
		txt.Size = UDim2.new(1, -28, 0, 28)
		txt.Font = Theme.font.heading
		txt.TextSize = 16
		txt.TextColor3 = Theme.color.textPrimary
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.Text = string.format(Locale.t("trade.incoming"), invite.fromName or "?")
		txt.Parent = box

		local accept = Instance.new("TextButton")
		accept.AnchorPoint = Vector2.new(1, 1)
		accept.Position = UDim2.new(0.5, -4, 1, -10)
		accept.Size = UDim2.fromOffset(170, 32)
		accept.BackgroundColor3 = Theme.color.success
		accept.BorderSizePixel = 0
		accept.Font = Theme.font.bold
		accept.TextSize = 14
		accept.TextColor3 = Color3.fromRGB(20, 20, 30)
		accept.Text = Locale.t("trade.accept")
		accept.Parent = box
		local ac = Instance.new("UICorner", accept); ac.CornerRadius = UDim.new(0, 8)
		accept.Activated:Connect(function()
			TradeController.respond(true)
			if box and box.Parent then box:Destroy() end
		end)

		local decline = Instance.new("TextButton")
		decline.AnchorPoint = Vector2.new(0, 1)
		decline.Position = UDim2.new(0.5, 4, 1, -10)
		decline.Size = UDim2.fromOffset(170, 32)
		decline.BackgroundColor3 = Theme.color.danger
		decline.BorderSizePixel = 0
		decline.Font = Theme.font.bold
		decline.TextSize = 14
		decline.TextColor3 = Color3.fromRGB(255, 255, 255)
		decline.Text = Locale.t("trade.decline")
		decline.Parent = box
		local dc = Instance.new("UICorner", decline); dc.CornerRadius = UDim.new(0, 8)
		decline.Activated:Connect(function()
			TradeController.respond(false)
			if box and box.Parent then box:Destroy() end
		end)
	end)

	-- Wenn Session startet/updated/endet: NICHT openPanel verwenden (toggelt!),
	-- sondern entweder direkt öffnen oder das offene Panel rebuilden.
	TradeController.SessionChanged:Connect(function(session)
		if session then
			if currentPanelId == "trade" then
				rebuildIfPanelOpen()
			else
				openPanel("trade")  -- nur wenn nicht bereits offen
			end
		else
			if currentPanelId == "trade" then
				rebuildIfPanelOpen()  -- zurück zur Lobby
			end
		end
	end)

	-- Einfacher Toast für Trade-Statusmeldungen
	TradeController.Toast:Connect(function(message)
		local toast = Instance.new("TextLabel")
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0.5, 0, 0, 120)
		toast.Size = UDim2.fromOffset(360, 36)
		toast.BackgroundColor3 = Theme.color.panel
		toast.BorderSizePixel = 0
		toast.Font = Theme.font.bold
		toast.TextSize = 14
		toast.TextColor3 = Theme.color.textPrimary
		toast.Text = message
		toast.Parent = screen
		local tc = Instance.new("UICorner", toast); tc.CornerRadius = UDim.new(0, 8)
		task.delay(3.0, function() if toast and toast.Parent then toast:Destroy() end end)
	end)

	-- Live-Updates
	Net:Event("OnEconomyUpdate").OnClientEvent:Connect(function(currencies)
		snapshot.currencies = currencies or {}
		currencyBarApi.update(snapshot.currencies)
	end)
	Net:Event("OnInventoryUpdate").OnClientEvent:Connect(function(inv)
		snapshot.inventory = inv or { gods = {} }
		rebuildIfPanelOpen()
	end)
	Net:Event("OnTempleUpdate").OnClientEvent:Connect(function(temple)
		snapshot.temple = temple or { slots = {} }
		rebuildIfPanelOpen()
	end)
	Net:Event("OnRebirthUpdate").OnClientEvent:Connect(function(data)
		if not data then return end
		snapshot.lifetime = data.lifetime or snapshot.lifetime
		snapshot.divinity = data.divinity or snapshot.divinity
		rebuildIfPanelOpen()
	end)
	Net:Event("OnQuestUpdate").OnClientEvent:Connect(function(quests)
		if not quests then return end
		snapshot.quests = quests
		rebuildIfPanelOpen()
	end)
	Net:Event("OnGamepassUpdate").OnClientEvent:Connect(function(gamepasses)
		if not gamepasses then return end
		snapshot.unlocks = snapshot.unlocks or { packs = {}, gamepasses = {} }
		snapshot.unlocks.gamepasses = gamepasses
		-- Skip-Fast Gamepass auf RollController spiegeln
		if RollController.setSkipFast then
			RollController.setSkipFast(gamepasses.skipFast == true)
		end
		-- Auto-Roll Gamepass aktiviert den Auto-Loop
		if AutoRollController.setEnabled then
			AutoRollController.setEnabled(gamepasses.autoRoll == true)
		end
		rebuildIfPanelOpen()
	end)
	-- Live-Rebuild bei Sprachwechsel
	Locale.LanguageChanged:Connect(function()
		rebuildIfPanelOpen()
	end)

	-- ─── Event Timer Banners ─────────────────────────────────────────────────
	local TweenService = game:GetService("TweenService")
	local RunService   = game:GetService("RunService")

	type BannerTheme = {
		name: string,
		ySlot: number,
		bgColor: Color3,
		strokeColor: Color3,
		fillColorL: Color3,
		fillColorR: Color3,
		textColor: Color3,
		icon: string,
		label: string,
	}

	local function makeEventBanner(parent: Instance, theme: BannerTheme, totalDuration: number, onExpire: (() -> ())?): Frame
		local banner = Instance.new("Frame")
		banner.Name = theme.name
		banner.AnchorPoint = Vector2.new(0.5, 0)
		-- start off-screen above
		banner.Position = UDim2.new(0.5, 0, 0, -60)
		banner.Size = UDim2.fromOffset(500, 48)
		banner.BackgroundColor3 = theme.bgColor
		banner.BackgroundTransparency = 0.05
		banner.BorderSizePixel = 0
		banner.ClipsDescendants = true
		banner.Parent = parent
		Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)
		local stroke = Instance.new("UIStroke", banner)
		stroke.Color = theme.strokeColor
		stroke.Thickness = 2
		stroke.Transparency = 0.1

		-- fill bar
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = theme.fillColorL
		fill.BackgroundTransparency = 0.05
		fill.Parent = banner
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 12)
		local grad = Instance.new("UIGradient", fill)
		grad.Color = ColorSequence.new(theme.fillColorL, theme.fillColorR)
		grad.Transparency = NumberSequence.new(0.1, 0.45)

		-- icon circle left side
		local iconCircle = Instance.new("Frame")
		iconCircle.AnchorPoint = Vector2.new(0, 0.5)
		iconCircle.Position = UDim2.new(0, 8, 0.5, 0)
		iconCircle.Size = UDim2.fromOffset(32, 32)
		iconCircle.BackgroundColor3 = theme.strokeColor
		iconCircle.BackgroundTransparency = 0.3
		iconCircle.BorderSizePixel = 0
		iconCircle.ZIndex = 3
		iconCircle.Parent = banner
		Instance.new("UICorner", iconCircle).CornerRadius = UDim.new(1, 0)

		local iconLbl = Instance.new("TextLabel")
		iconLbl.BackgroundTransparency = 1
		iconLbl.Size = UDim2.fromScale(1, 1)
		iconLbl.Font = Enum.Font.GothamBold
		iconLbl.TextSize = 18
		iconLbl.TextColor3 = Color3.new(1, 1, 1)
		iconLbl.Text = theme.icon
		iconLbl.ZIndex = 4
		iconLbl.Parent = iconCircle

		-- event title (left of timer)
		local titleLbl = Instance.new("TextLabel")
		titleLbl.BackgroundTransparency = 1
		titleLbl.AnchorPoint = Vector2.new(0, 0.5)
		titleLbl.Position = UDim2.new(0, 48, 0.5, 0)
		titleLbl.Size = UDim2.new(0.55, 0, 1, 0)
		titleLbl.Font = Enum.Font.GothamBlack
		titleLbl.TextSize = 15
		titleLbl.TextColor3 = theme.textColor
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.Text = theme.label
		titleLbl.ZIndex = 3
		titleLbl.Parent = banner

		-- countdown right side
		local timerLbl = Instance.new("TextLabel")
		timerLbl.BackgroundTransparency = 1
		timerLbl.AnchorPoint = Vector2.new(1, 0.5)
		timerLbl.Position = UDim2.new(1, -14, 0.5, 0)
		timerLbl.Size = UDim2.fromOffset(70, 30)
		timerLbl.Font = Enum.Font.Code
		timerLbl.TextSize = 18
		timerLbl.TextColor3 = Color3.new(1, 1, 1)
		timerLbl.TextXAlignment = Enum.TextXAlignment.Right
		timerLbl.ZIndex = 3
		timerLbl.Parent = banner

		-- slide-in + slight scale punch
		local targetY = 8 + theme.ySlot * 56
		banner.Size = UDim2.fromOffset(460, 40)
		TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, targetY),
			Size = UDim2.fromOffset(500, 48),
		}):Play()
		stroke.Transparency = 0.6
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 0.1 }):Play()

		-- heartbeat timer
		local startTime = os.clock()
		local conn: RBXScriptConnection? = nil
		conn = RunService.Heartbeat:Connect(function()
			if not banner or not banner.Parent then
				if conn then conn:Disconnect() end
				return
			end
			local elapsed = os.clock() - startTime
			local frac = math.clamp(1 - elapsed / totalDuration, 0, 1)
			fill.Size = UDim2.new(frac, 0, 1, 0)
			local secsLeft = math.max(0, math.ceil(totalDuration - elapsed))
			local m = math.floor(secsLeft / 60)
			local s = secsLeft % 60
			timerLbl.Text = string.format("%d:%02d", m, s)

			-- pulse stroke when < 30s
			if secsLeft <= 30 then
				local pulse = 0.1 + math.abs(math.sin(elapsed * 4)) * 0.4
				stroke.Transparency = pulse
			end

			if frac <= 0 then
				if conn then conn:Disconnect() end
				-- slide out
				TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, 0, 0, -60),
					Size = UDim2.fromOffset(460, 40),
				}):Play()
				task.delay(0.35, function()
					if banner and banner.Parent then banner:Destroy() end
					if onExpire then onExpire() end
				end)
			end
		end)

		return banner
	end

	-- Lucky Hour
	Net:Event("OnLuckyHour").OnClientEvent:Connect(function(data: any)
		local existing = screen:FindFirstChild("LuckyHourBanner")
		if existing then existing:Destroy() end
		if not data or not data.active then return end
		local dur = math.max(1, (data.endsAt or 0) - os.time())
		makeEventBanner(screen, {
			name = "LuckyHourBanner",
			ySlot = 0,
			bgColor     = Color3.fromRGB(10, 32, 10),
			strokeColor = Color3.fromRGB(60, 220, 60),
			fillColorL  = Color3.fromRGB(20, 70, 20),
			fillColorR  = Color3.fromRGB(60, 190, 60),
			textColor   = Color3.fromRGB(130, 255, 130),
			icon = "🍀",
			label = "LUCKY HOUR · +25% Luck",
		}, dur, nil)
	end)

	-- Gold Storm
	Net:Event("OnStormEvent").OnClientEvent:Connect(function(data: any)
		local existing = screen:FindFirstChild("StormBanner")
		if existing then existing:Destroy() end
		if not data or not data.active then return end
		local dur = math.max(1, (data.endsAt or 0) - os.time())
		makeEventBanner(screen, {
			name = "StormBanner",
			ySlot = 1,
			bgColor     = Color3.fromRGB(12, 20, 45),
			strokeColor = Color3.fromRGB(70, 150, 255),
			fillColorL  = Color3.fromRGB(25, 55, 120),
			fillColorR  = Color3.fromRGB(70, 150, 255),
			textColor   = Color3.fromRGB(160, 210, 255),
			icon = "⛈",
			label = "GOLD STORM · Bonus Gold",
		}, dur, nil)
	end)

	-- Pack Frenzy
	Net:Event("OnFrenzyEvent").OnClientEvent:Connect(function(data: any)
		local existing = screen:FindFirstChild("FrenzyBanner")
		if existing then existing:Destroy() end
		if not data or not data.active then
			ShopPanel.frenzyDiscount = 0
			rebuildIfPanelOpen()
			return
		end
		ShopPanel.frenzyDiscount = data.discount or 0.5
		rebuildIfPanelOpen()
		local dur = math.max(1, (data.endsAt or 0) - os.time())
		makeEventBanner(screen, {
			name = "FrenzyBanner",
			ySlot = 2,
			bgColor     = Color3.fromRGB(40, 14, 5),
			strokeColor = Color3.fromRGB(255, 120, 30),
			fillColorL  = Color3.fromRGB(100, 40, 10),
			fillColorR  = Color3.fromRGB(255, 130, 30),
			textColor   = Color3.fromRGB(255, 200, 120),
			icon = "🔥",
			label = "PACK FRENZY · 50% OFF",
		}, dur, function()
			ShopPanel.frenzyDiscount = 0
			rebuildIfPanelOpen()
		end)
	end)

	-- ─── Limited-Time Event Banner ───────────────────────────────────────────
	local activeEventData: any = nil

	local function applyEventBanner(data: any)
		activeEventData = data
		snapshot.activeEvent = data  -- ShopPanel reads this
		local existing = screen:FindFirstChild("EventBanner")
		if existing then existing:Destroy() end
		if not data then return end

		local c = data.color or { 1, 1, 0 }
		local eventColor = Color3.fromRGB(
			math.floor((c[1] or 1) * 255),
			math.floor((c[2] or 1) * 255),
			math.floor((c[3] or 0) * 255)
		)

		local dur = math.max(1, (data.endsAt or 0) - os.time())
		makeEventBanner(screen, {
			name        = "EventBanner",
			ySlot       = 3,
			bgColor     = Color3.fromRGB(20, 10, 30),
			strokeColor = eventColor,
			fillColorL  = Color3.fromRGB(40, 20, 60),
			fillColorR  = eventColor,
			textColor   = eventColor,
			icon        = "✨",
			label       = Locale.t(data.nameKey or "event.active"),
		}, dur, function() activeEventData = nil end)

		-- Rebuild shop to show event pack
		if currentPanelId == "shop" then rebuildIfPanelOpen() end
	end

	-- Fetch event on start
	task.spawn(function()
		local ok, data = pcall(function()
			return Net:Function("GetActiveEvent"):InvokeServer()
		end)
		if ok and data then applyEventBanner(data) end
	end)

	Net:Event("OnEventUpdate").OnClientEvent:Connect(function(data: any)
		applyEventBanner(data)
	end)

	-- Expose active event for ShopPanel
	function UIController.getActiveEvent(): any
		return activeEventData
	end

	-- VIP Eject notification
	Net:Event("OnVIPEject").OnClientEvent:Connect(function()
		local toast = Instance.new("TextLabel")
		toast.AnchorPoint = Vector2.new(0.5, 1)
		toast.Position = UDim2.new(0.5, 0, 1, -80)
		toast.Size = UDim2.fromOffset(380, 44)
		toast.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
		toast.BorderSizePixel = 0
		toast.Font = Enum.Font.GothamBold
		toast.TextSize = 15
		toast.TextColor3 = Color3.fromRGB(255, 220, 220)
		toast.Text = Locale.t("vip.noAccess")
		toast.Parent = screen
		local TweenService = game:GetService("TweenService")
		local corner = Instance.new("UICorner", toast)
		corner.CornerRadius = UDim.new(0, 12)
		TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 1, -100) }):Play()
		task.delay(3, function()
			TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 1, 60) }):Play()
			task.delay(0.3, function() toast:Destroy() end)
		end)
	end)

	-- Initial Snapshot
	task.spawn(function()
		local profile = Net:Function("RequestProfile"):InvokeServer()
		if profile then
			snapshot.currencies = profile.currencies or {}
			snapshot.inventory = profile.inventory or { gods = {} }
			snapshot.temple = profile.temple or { slots = {} }
			snapshot.unlocks = profile.unlocks or { packs = {}, gamepasses = {} }
			snapshot.unlocks.gamepasses = snapshot.unlocks.gamepasses or {}
			if RollController.setSkipFast then
				RollController.setSkipFast(snapshot.unlocks.gamepasses.skipFast == true)
			end
			if AutoRollController.setEnabled then
				AutoRollController.setEnabled(snapshot.unlocks.gamepasses.autoRoll == true)
			end
			snapshot.collection = profile.collection or { discovered = {} }
			snapshot.settings = profile.settings or {}
			-- Lifetime ist nicht im RequestProfile-Snapshot drin — Default 0.
			snapshot.lifetime = profile.lifetime or { gold = 0, rebirths = 0 }
			snapshot.divinity = profile.divinity or { spent = 0, tree = {} }
			snapshot.quests = profile.quests or snapshot.quests
			snapshot.season = profile.season or snapshot.season
			-- Season-Snapshot an LeaderboardController weitergeben
			if profile.season then
				LeaderboardController.setSeasonData(profile.season)
			end
			currencyBarApi.update(snapshot.currencies)
			-- Sprache aus Settings setzen
			if snapshot.settings.language then
				Locale.setLanguage(snapshot.settings.language)
			end
			-- Tutorial für neue Spieler
			TutorialController.start(snapshot)
		end
	end)
end

return UIController
