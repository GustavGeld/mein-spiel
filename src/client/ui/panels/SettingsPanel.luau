--!strict
-- SettingsPanel — Sprache (EN/DE), Audio, VFX, Reduced Motion, Trade Invites.
-- Stage 4 wickelt Persistierung via SwitchLanguage/ChangeSetting Remote ab. Hier UI-Skelett.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Locale = require(Shared.locale.Locale)
local Net = require(Shared.remotes.Net)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local SettingsPanel = {}

local function row(parent: Instance, label: string): Frame
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
	l.Size = UDim2.new(0.55, 0, 1, 0)
	l.Font = Theme.font.bold
	l.TextSize = 16
	l.TextColor3 = Theme.color.textPrimary
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = label
	l.Parent = r
	return r
end

function SettingsPanel.create(body: Instance, snapshot)
	local settings = snapshot.settings or { language = "en", music = true, sfx = true, reducedMotion = false, tradeInvites = true }

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 1)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.Parent = body
	Util.listLayout(list, Enum.FillDirection.Vertical, 8)

	-- Language Row
	local langRow = row(list, Locale.t("settings.language"))
	local langHolder = Instance.new("Frame")
	langHolder.BackgroundTransparency = 1
	langHolder.AnchorPoint = Vector2.new(1, 0.5)
	langHolder.Position = UDim2.new(1, -14, 0.5, 0)
	langHolder.Size = UDim2.fromOffset(180, 32)
	langHolder.Parent = langRow
	Util.listLayout(langHolder, Enum.FillDirection.Horizontal, 6)

	local langButtons: { [string]: TextButton } = {}
	for _, code in ipairs({ "en", "de" }) do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(80, 32)
		b.BackgroundColor3 = (settings.language == code) and Theme.color.accent or Theme.color.panel
		b.BorderSizePixel = 0
		b.Font = Theme.font.bold
		b.TextSize = 14
		b.TextColor3 = Theme.color.textPrimary
		b.Text = code == "en" and "English" or "Deutsch"
		b.Parent = langHolder
		Util.corner(b, Theme.radius.sm)
		langButtons[code] = b
		b.Activated:Connect(function()
			Locale.setLanguage(code)
			settings.language = code
			for c, btn in pairs(langButtons) do
				btn.BackgroundColor3 = (c == code) and Theme.color.accent or Theme.color.panel
			end
			-- Persistenz (Stage 4 verdrahtet das remote-seitig)
			pcall(function()
				Net:Function("SwitchLanguage"):InvokeServer(code)
			end)
		end)
	end

	-- Toggles
	local function toggle(labelText: string, initial: boolean, onChanged: (boolean) -> ())
		local r = row(list, labelText)
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
	end

	toggle(Locale.t("settings.music"), settings.music ~= false, function(_v) end)
	toggle(Locale.t("settings.sfx"), settings.sfx ~= false, function(_v) end)
	toggle(Locale.t("settings.reducedMotion"), settings.reducedMotion == true, function(_v) end)
	toggle(Locale.t("settings.tradeInvites"), settings.tradeInvites ~= false, function(_v) end)
end

return SettingsPanel
