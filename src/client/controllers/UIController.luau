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
local RollController = require(script.Parent.RollController)
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
	index      = "nav.collection",
	quests     = "nav.quests",
	daily      = "nav.daily",
	rewards    = "nav.rewards",
	trade      = "nav.trade",
	fusion     = "nav.fusion",
	rebirth    = "nav.rebirth",
	gamepasses = "nav.gamepasses",
	settings   = "nav.settings",
}

-- Panels mit eigener Größe (größer als Standard 820×560).
local PANEL_SIZES: { [string]: UDim2 } = {
	inventory  = UDim2.fromOffset(1100, 700),
	gamepasses = UDim2.fromOffset(960, 640),
	fusion     = UDim2.fromOffset(960, 640),
	trade      = UDim2.fromOffset(960, 620),
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
		StubPanel.create(handle.body, "Rewards", "Group join, codes & referral rewards arrive with Stage 10.")
	elseif id == "trade" then
		TradePanel.create(handle.body, snapshot)
	elseif id == "rebirth" then
		RebirthPanel.create(handle.body, snapshot)
	elseif id == "fusion" then
		FusionPanel.create(handle.body, snapshot)
	elseif id == "gamepasses" then
		GamepassPanel.create(handle.body, snapshot)
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

function UIController.start()
	screen = Instance.new("ScreenGui")
	screen.Name = "MainUI"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 50
	screen.Parent = PlayerGui

	currencyBarApi = CurrencyBar.create(screen)
	NavBar.create(screen, openPanel)

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
			currencyBarApi.update(snapshot.currencies)
			-- Sprache aus Settings setzen
			if snapshot.settings.language then
				Locale.setLanguage(snapshot.settings.language)
			end
		end
	end)
end

return UIController
