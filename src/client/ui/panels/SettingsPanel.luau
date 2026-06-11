--!strict
-- SettingsPanel — Sprache, Audio, VFX, Hide GUI, etc.
-- Fix: settings.language wird VOR Locale.setLanguage gesetzt,
-- damit der Panel-Rebuild die korrekte Sprache liest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Locale = require(Shared.locale.Locale)
local Net    = require(Shared.remotes.Net)

local Theme = require(script.Parent.Parent.Theme)
local Util  = require(script.Parent.Parent.Util)

local SettingsPanel = {}

local function makeRow(parent: Instance, label: string): Frame
	local r = Instance.new("Frame")
	r.BackgroundColor3 = Theme.color.panelLight
	r.BorderSizePixel = 0
	r.Size = UDim2.new(1, 0, 0, 48)
	r.Parent = parent
	Util.corner(r, Theme.radius.md)

	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0, 0.5)
	l.Position = UDim2.new(0, 14, 0.5, 0)
	l.Size = UDim2.new(0.6, 0, 1, 0)
	l.Font = Theme.font.bold
	l.TextSize = 16
	l.TextColor3 = Theme.color.textPrimary
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = r
	return r
end

local function makeToggle(parent: Instance, labelText: string, initial: boolean, onChanged: (boolean) -> ()): TextButton
	local r = makeRow(parent, labelText)
	local state = initial
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -14, 0.5, 0)
	b.Size = UDim2.fromOffset(80, 32)
	b.BackgroundColor3 = state and Theme.color.success or Theme.color.panel
	b.BorderSizePixel = 0
	b.Font = Theme.font.bold
	b.TextSize = 14
	b.TextColor3 = Theme.color.textPrimary
	b.Text = state and "ON" or "OFF"
	b.Parent = r
	Util.corner(b, Theme.radius.sm)
	b.Activated:Connect(function()
		state = not state
		b.BackgroundColor3 = state and Theme.color.success or Theme.color.panel
		b.Text = state and "ON" or "OFF"
		onChanged(state)
	end)
	return b
end

-- Callback-Tabelle: UIController steckt hier hideGuiCallback rein.
SettingsPanel.onHideGui = nil :: ((boolean) -> ())?

function SettingsPanel.create(body: Instance, snapshot: any)
	local settings = snapshot.settings or {
		language = "en", music = true, sfx = true,
		reducedMotion = false, tradeInvites = true,
	}

	-- Lese aktuelle Sprache direkt aus Locale (immer frisch, nicht vom Snapshot)
	local currentLang = Locale.current

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 1)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.Parent = body
	Util.listLayout(list, Enum.FillDirection.Vertical, 8)

	-- ── Sprach-Auswahl ───────────────────────────────────────────────────────

	local langRow = makeRow(list, Locale.t("settings.language"))
	local langHolder = Instance.new("Frame")
	langHolder.BackgroundTransparency = 1
	langHolder.AnchorPoint = Vector2.new(1, 0.5)
	langHolder.Position = UDim2.new(1, -14, 0.5, 0)
	langHolder.Size = UDim2.fromOffset(200, 32)
	langHolder.Parent = langRow
	Util.listLayout(langHolder, Enum.FillDirection.Horizontal, 6)

	local langButtons: { [string]: TextButton } = {}
	for _, code in ipairs({ "en", "de" }) do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(90, 32)
		-- FIX: Locale.current statt settings.language für die Highlight-Logik
		b.BackgroundColor3 = (currentLang == code) and Theme.color.accent or Theme.color.panel
		b.BorderSizePixel = 0
		b.Font = Theme.font.bold
		b.TextSize = 14
		b.TextColor3 = (currentLang == code) and Color3.fromRGB(20,20,30) or Theme.color.textPrimary
		b.Text = code == "en" and "English" or "Deutsch"
		b.Parent = langHolder
		Util.corner(b, Theme.radius.sm)
		langButtons[code] = b

		b.Activated:Connect(function()
			-- FIX: Snapshot VOR Locale.setLanguage aktualisieren!
			-- Locale.setLanguage feuert LanguageChanged via task.spawn (sofort),
			-- was rebuildIfPanelOpen aufruft. Der Rebuild liest snapshot.settings.language —
			-- das muss schon den neuen Wert haben.
			settings.language = code
			-- Buttons sofort visuell aktualisieren (für den Fall, dass kein Rebuild kommt)
			for c, btn in pairs(langButtons) do
				btn.BackgroundColor3 = (c == code) and Theme.color.accent or Theme.color.panel
				btn.TextColor3 = (c == code) and Color3.fromRGB(20,20,30) or Theme.color.textPrimary
			end
			-- Sprache setzen → löst Rebuild aus
			Locale.setLanguage(code)
			-- Server persistieren
			pcall(function()
				Net:Function("SwitchLanguage"):InvokeServer(code)
			end)
		end)
	end

	-- ── Toggles ──────────────────────────────────────────────────────────────

	makeToggle(list, Locale.t("settings.music"), settings.music ~= false, function(_v) end)
	makeToggle(list, Locale.t("settings.sfx"), settings.sfx ~= false, function(_v) end)
	makeToggle(list, Locale.t("settings.reducedMotion"), settings.reducedMotion == true, function(_v) end)
	makeToggle(list, Locale.t("settings.tradeInvites"), settings.tradeInvites ~= false, function(_v) end)

	-- ── Hide GUI ─────────────────────────────────────────────────────────────
	makeToggle(list, Locale.t("settings.hideGui"), snapshot.guiHidden == true, function(v)
		if SettingsPanel.onHideGui then
			SettingsPanel.onHideGui(v)
		end
	end)

	-- Trennlinie
	local sep = Instance.new("Frame")
	sep.BackgroundColor3 = Theme.color.stroke
	sep.BorderSizePixel = 0
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.Parent = list

	-- Version-Info
	local version = Instance.new("TextLabel")
	version.BackgroundTransparency = 1
	version.Size = UDim2.new(1, 0, 0, 24)
	version.Font = Theme.font.body
	version.TextSize = 12
	version.TextColor3 = Theme.color.textMuted
	version.TextXAlignment = Enum.TextXAlignment.Center
	version.Text = "Gods of Fate — v1.0"
	version.Parent = list
end

return SettingsPanel
