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
local StubPanel = require(script.Parent.Parent.ui.panels.StubPanel)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UIController = {}

local snapshot: any = {
	currencies = {},
	inventory = { gods = {} },
	temple = { slots = {} },
	unlocks = { packs = {} },
	lifetime = { gold = 0, rebirths = 0 },
	collection = { discovered = {} },
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
	shop      = "nav.shop",
	inventory = "nav.inventory",
	index     = "nav.collection",
	quests    = "nav.quests",
	daily     = "nav.daily",
	rewards   = "nav.rewards",
	settings  = "nav.settings",
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
	local handle = Panel.create(screen, title, closePanel)
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
		StubPanel.create(handle.body, "Quests", "Daily & Weekly quests arrive in Stage 4.")
	elseif id == "daily" then
		StubPanel.create(handle.body, "Daily", "Login streak, minute rewards & daily lucky roll arrive in Stage 4.")
	elseif id == "rewards" then
		StubPanel.create(handle.body, "Rewards", "Group join, codes & referral rewards arrive with Stage 10.")
	end
end

local function rebuildIfPanelOpen()
	if not currentPanel or not currentPanelId then return end
	local id = currentPanelId
	-- Force-rebuild trotz Toggle.
	currentPanelId = nil
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

	-- Initial Snapshot
	task.spawn(function()
		local profile = Net:Function("RequestProfile"):InvokeServer()
		if profile then
			snapshot.currencies = profile.currencies or {}
			snapshot.inventory = profile.inventory or { gods = {} }
			snapshot.temple = profile.temple or { slots = {} }
			snapshot.unlocks = profile.unlocks or { packs = {} }
			snapshot.collection = profile.collection or { discovered = {} }
			snapshot.settings = profile.settings or {}
			-- Lifetime ist nicht im RequestProfile-Snapshot drin — Default 0.
			snapshot.lifetime = profile.lifetime or { gold = 0, rebirths = 0 }
			currencyBarApi.update(snapshot.currencies)
			-- Sprache aus Settings setzen
			if snapshot.settings.language then
				Locale.setLanguage(snapshot.settings.language)
			end
		end
	end)
end

return UIController
