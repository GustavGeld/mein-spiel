--!strict
-- CompanionPanel — opens when player interacts with Aion.
-- Four tabs: Skins | Help | Abilities | Auras

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net    = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local CompanionSkins      = require(Shared.config.CompanionSkins)
local Auras               = require(Shared.config.Auras)
local CompanionAbilities  = require(Shared.config.CompanionAbilities)

local Theme = require(script.Parent.Parent.Theme)
local Util  = require(script.Parent.Parent.Util)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local CompanionPanel = {}

-- ─── Screen ───────────────────────────────────────────────────────────────────

local function ensureScreen(): ScreenGui
	local sg = PlayerGui:FindFirstChild("CompanionScreen")
	if sg then return sg :: ScreenGui end
	sg = Instance.new("ScreenGui")
	sg.Name           = "CompanionScreen"
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder   = 50
	sg.Parent         = PlayerGui
	return sg :: ScreenGui
end

local activePanel: Frame? = nil

local function closePanel()
	if not activePanel then return end
	local p = activePanel
	activePanel = nil
	TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, 0, 0.5, 20) }):Play()
	task.delay(0.2, function() if p and p.Parent then p:Destroy() end end)
end

local function makeTabBtn(bar: Frame, label: string, active: boolean, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor  = false
	btn.Size             = UDim2.new(0, 0, 1, 0)
	btn.AutomaticSize    = Enum.AutomaticSize.X
	btn.BackgroundColor3 = active and Theme.color.accent or Theme.color.panelLight
	btn.BorderSizePixel  = 0
	btn.Font             = active and Theme.font.bold or Theme.font.body
	btn.TextColor3       = active and Color3.fromRGB(15, 20, 35) or Theme.color.textSecondary
	btn.TextSize         = 14
	btn.Text             = "  " .. label .. "  "
	btn.Parent           = bar
	Util.corner(btn, Theme.radius.sm)
	btn.Activated:Connect(onClick)
	return btn
end

-- ─── Tab: Skins ───────────────────────────────────────────────────────────────

local function hasCustomModel(skinId: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("AionSkins")
	if not folder then return false end
	local m = folder:FindFirstChild(skinId)
	return m ~= nil and m:IsA("Model")
end

local function buildSkinsTab(container: Frame, activeSkinId: string, onSkinPicked: (string) -> ())
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel        = 0
	scroller.Size                   = UDim2.fromScale(1, 1)
	scroller.CanvasSize             = UDim2.new()
	scroller.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness     = 4
	scroller.Parent                 = container

	local grid = Instance.new("UIGridLayout")
	grid.CellSize    = UDim2.fromOffset(110, 114)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder   = Enum.SortOrder.LayoutOrder
	grid.Parent      = scroller
	Util.padding(scroller, 10)

	for i, skin in ipairs(CompanionSkins.list) do
		local card = Instance.new("TextButton")
		card.AutoButtonColor  = false
		card.LayoutOrder      = i
		card.BackgroundColor3 = skin.id == activeSkinId
			and Color3.fromRGB(30, 42, 65)
			or Theme.color.panelLight
		card.BorderSizePixel  = 0
		card.Text             = ""
		card.Parent           = scroller
		Util.corner(card, Theme.radius.md)

		if skin.id == activeSkinId then
			local stroke = Instance.new("UIStroke", card)
			stroke.Color     = Theme.color.accent
			stroke.Thickness = 2
		end

		local circle = Instance.new("Frame")
		circle.AnchorPoint      = Vector2.new(0.5, 0)
		circle.Position         = UDim2.new(0.5, 0, 0, 10)
		circle.Size             = UDim2.fromOffset(52, 52)
		circle.BackgroundColor3 = skin.color
		circle.BorderSizePixel  = 0
		circle.Parent           = card
		Util.corner(circle, UDim.new(1, 0))

		local glowRing = Instance.new("UIStroke", circle)
		glowRing.Color     = skin.glowColor
		glowRing.Thickness = 2

		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position  = UDim2.new(0, 0, 0, 68)
		nameLbl.Size      = UDim2.new(1, 0, 0, 18)
		nameLbl.Font      = Theme.font.bold
		nameLbl.TextSize  = 13
		nameLbl.TextColor3 = Theme.color.textPrimary
		nameLbl.Text      = skin.name
		nameLbl.Parent    = card

		local costLbl = Instance.new("TextLabel")
		costLbl.BackgroundTransparency = 1
		costLbl.Position  = UDim2.new(0, 0, 0, 88)
		costLbl.Size      = UDim2.new(1, 0, 0, 16)
		costLbl.Font      = Theme.font.body
		costLbl.TextSize  = 11
		costLbl.TextColor3 = skin.gemCost == 0 and Theme.color.success or Theme.color.gems
		costLbl.Text      = skin.gemCost == 0 and Locale.t("companion.free") or ("💎 " .. skin.gemCost)
		costLbl.Parent    = card

		-- Small "3D" badge in top-right corner when a custom model is loaded
		if hasCustomModel(skin.id) then
			local badge = Instance.new("TextLabel")
			badge.AnchorPoint       = Vector2.new(1, 0)
			badge.Position          = UDim2.new(1, -4, 0, 4)
			badge.Size              = UDim2.fromOffset(22, 14)
			badge.BackgroundColor3  = Color3.fromRGB(40, 90, 160)
			badge.BorderSizePixel   = 0
			badge.Font              = Theme.font.bold
			badge.TextSize          = 9
			badge.TextColor3        = Color3.fromRGB(200, 230, 255)
			badge.Text              = "3D"
			badge.Parent            = card
			Util.corner(badge, UDim.new(0, 3))
		end

		local capturedId = skin.id
		card.Activated:Connect(function() onSkinPicked(capturedId) end)
	end
end

-- ─── Tab: Help (Accordion) ────────────────────────────────────────────────────

local HELP_SECTIONS: { { title: string, key: string } } = {
	{ title = "🎴  " .. "Packs",         key = "help.packs"      },
	{ title = "⛩  " .. "Temple",         key = "help.temple"     },
	{ title = "⚡  " .. "Fusion",         key = "help.fusion"     },
	{ title = "🔄  " .. "Rebirth",        key = "help.rebirth"    },
	{ title = "🌟  " .. "Divinity Tree",  key = "help.divinity"   },
	{ title = "⛈  " .. "Events",         key = "help.events"     },
	{ title = "🤝  " .. "Referral",       key = "help.referral"   },
	{ title = "📖  " .. "Collection",     key = "help.collection" },
}

local function buildHelpTab(container: Frame)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel        = 0
	scroller.Size                   = UDim2.fromScale(1, 1)
	scroller.CanvasSize             = UDim2.new()
	scroller.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness     = 4
	scroller.Parent                 = container
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 4)
	Util.padding(scroller, 8)

	for _, section in ipairs(HELP_SECTIONS) do
		-- Outer wrapper (auto-grows when open)
		local wrapper = Instance.new("Frame")
		wrapper.BackgroundTransparency = 1
		wrapper.Size          = UDim2.new(1, 0, 0, 0)
		wrapper.AutomaticSize = Enum.AutomaticSize.Y
		wrapper.Parent        = scroller

		local wlist = Instance.new("UIListLayout")
		wlist.FillDirection = Enum.FillDirection.Vertical
		wlist.SortOrder     = Enum.SortOrder.LayoutOrder
		wlist.Padding       = UDim.new(0, 0)
		wlist.Parent        = wrapper

		-- Header button
		local header = Instance.new("TextButton")
		header.LayoutOrder      = 1
		header.AutoButtonColor  = false
		header.BackgroundColor3 = Theme.color.panelLight
		header.BorderSizePixel  = 0
		header.Size             = UDim2.new(1, 0, 0, 36)
		header.Font             = Theme.font.bold
		header.TextSize         = 14
		header.TextColor3       = Theme.color.textPrimary
		header.TextXAlignment   = Enum.TextXAlignment.Left
		header.Text             = "   " .. section.title .. "   ▼"
		header.Parent           = wrapper
		Util.corner(header, Theme.radius.md)

		-- Body (hidden by default)
		local body = Instance.new("Frame")
		body.LayoutOrder      = 2
		body.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
		body.BorderSizePixel  = 0
		body.Size             = UDim2.new(1, 0, 0, 0)
		body.ClipsDescendants = true
		body.Visible          = false
		body.Parent           = wrapper
		-- bottom corners only via UICorner + a covering top frame trick
		Util.corner(body, Theme.radius.md)

		local bodyText = Instance.new("TextLabel")
		bodyText.BackgroundTransparency = 1
		bodyText.Position       = UDim2.fromOffset(12, 8)
		bodyText.Size           = UDim2.new(1, -24, 1, -16)
		bodyText.Font           = Theme.font.body
		bodyText.TextSize       = 12
		bodyText.TextColor3     = Theme.color.textSecondary
		bodyText.TextXAlignment = Enum.TextXAlignment.Left
		bodyText.TextYAlignment = Enum.TextYAlignment.Top
		bodyText.TextWrapped    = true
		bodyText.Text           = Locale.t(section.key)
		bodyText.AutomaticSize  = Enum.AutomaticSize.Y
		bodyText.Parent         = body

		local isOpen = false

		header.Activated:Connect(function()
			isOpen = not isOpen
			if isOpen then
				-- Measure text height
				local textHeight = bodyText.TextBounds.Y + 24
				body.Size    = UDim2.new(1, 0, 0, textHeight)
				body.Visible = true
				header.Text  = "   " .. section.title .. "   ▲"
				header.TextColor3 = Theme.color.accent
				local stroke = header:FindFirstChildWhichIsA("UIStroke")
				if not stroke then
					stroke = Instance.new("UIStroke", header)
					stroke.Color     = Theme.color.accent
					stroke.Thickness = 1
				end
			else
				body.Size    = UDim2.new(1, 0, 0, 0)
				body.Visible = false
				header.Text  = "   " .. section.title .. "   ▼"
				header.TextColor3 = Theme.color.textPrimary
				local stroke = header:FindFirstChildWhichIsA("UIStroke")
				if stroke then stroke:Destroy() end
			end
		end)
	end
end

-- ─── Tab: Abilities ───────────────────────────────────────────────────────────

local function buildAbilitiesTab(container: Frame)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel        = 0
	scroller.Size                   = UDim2.fromScale(1, 1)
	scroller.CanvasSize             = UDim2.new()
	scroller.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness     = 4
	scroller.Parent                 = container
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 10)
	Util.padding(scroller, 10)

	-- Load owned abilities async; rebuild buttons when ready
	local ownedAbilities: { [string]: boolean } = {}
	local buyButtons: { [string]: TextButton } = {}

	local function refreshCard(abilityId: string)
		local btn = buyButtons[abilityId]
		if not btn then return end
		local def = CompanionAbilities.byId[abilityId]
		if not def then return end
		if ownedAbilities[abilityId] then
			btn.Text             = Locale.t("ability.owned")
			btn.BackgroundColor3 = Theme.color.success
			btn.TextColor3       = Color3.fromRGB(15, 25, 15)
			btn.AutoButtonColor  = false
		else
			btn.Text             = string.format(Locale.t("ability.buy"), def.gemCost)
			btn.BackgroundColor3 = Theme.color.gems or Color3.fromRGB(140, 80, 220)
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
			btn.AutoButtonColor  = true
		end
	end

	for _, def in ipairs(CompanionAbilities.list) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Theme.color.panelLight
		card.BorderSizePixel  = 0
		card.Size             = UDim2.new(1, 0, 0, 90)
		card.Parent           = scroller
		Util.corner(card, Theme.radius.md)

		-- Color stripe on left
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = def.color
		stripe.BorderSizePixel  = 0
		stripe.Size             = UDim2.new(0, 4, 1, 0)
		stripe.Parent           = card
		Util.corner(stripe, Theme.radius.sm)

		-- Icon
		local iconLbl = Instance.new("TextLabel")
		iconLbl.BackgroundTransparency = 1
		iconLbl.Position  = UDim2.fromOffset(14, 14)
		iconLbl.Size      = UDim2.fromOffset(40, 40)
		iconLbl.Font      = Theme.font.heading
		iconLbl.TextSize  = 28
		iconLbl.TextColor3 = def.color
		iconLbl.Text      = def.iconEmoji
		iconLbl.Parent    = card

		-- Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position  = UDim2.fromOffset(60, 12)
		nameLbl.Size      = UDim2.new(0.45, 0, 0, 22)
		nameLbl.Font      = Theme.font.bold
		nameLbl.TextSize  = 15
		nameLbl.TextColor3 = Theme.color.textPrimary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text      = Locale.t(def.nameKey)
		nameLbl.Parent    = card

		-- Description
		local descLbl = Instance.new("TextLabel")
		descLbl.BackgroundTransparency = 1
		descLbl.Position  = UDim2.fromOffset(60, 36)
		descLbl.Size      = UDim2.new(0.55, 0, 0, 32)
		descLbl.Font      = Theme.font.body
		descLbl.TextSize  = 12
		descLbl.TextColor3 = Theme.color.textSecondary
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextWrapped = true
		descLbl.Text      = Locale.t(def.descKey)
		descLbl.Parent    = card

		-- Buy / Owned button
		local btn = Instance.new("TextButton")
		btn.AnchorPoint      = Vector2.new(1, 0.5)
		btn.Position         = UDim2.new(1, -12, 0.5, 0)
		btn.Size             = UDim2.fromOffset(130, 32)
		btn.BorderSizePixel  = 0
		btn.Font             = Theme.font.bold
		btn.TextSize         = 13
		btn.Parent           = card
		Util.corner(btn, Theme.radius.sm)

		local capturedId = def.id
		buyButtons[def.id] = btn
		refreshCard(def.id)

		btn.Activated:Connect(function()
			if ownedAbilities[capturedId] then return end
			btn.Text = "..."
			btn.AutoButtonColor = false
			local Net2 = require(Shared.remotes.Net)
			local ok, result = pcall(function()
				return Net2:Function("BuyAbility"):InvokeServer(capturedId)
			end)
			if ok and result and result.ok then
				ownedAbilities[capturedId] = true
			end
			refreshCard(capturedId)
		end)
	end

	-- Async load profile to populate owned abilities
	task.spawn(function()
		local Net2 = require(Shared.remotes.Net)
		local ok, profile = pcall(function()
			return Net2:Function("RequestProfile"):InvokeServer()
		end)
		if ok and profile and profile.companion and profile.companion.abilities then
			for id, owned in pairs(profile.companion.abilities) do
				if owned then ownedAbilities[id] = true end
			end
			for id in pairs(CompanionAbilities.byId) do
				refreshCard(id)
			end
		end
	end)
end

-- ─── Tab: Auras ──────────────────────────────────────────────────────────────

local function buildAurasTab(container: Frame, activeAuraTier: number, onAuraPicked: (number) -> ())
	-- "No Aura" option + tiers 1-10 = 11 cards total; use 3-column UIGridLayout
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel        = 0
	scroller.Size                   = UDim2.fromScale(1, 1)
	scroller.CanvasSize             = UDim2.new()
	scroller.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness     = 4
	scroller.Parent                 = container

	local grid = Instance.new("UIGridLayout")
	grid.CellSize    = UDim2.fromOffset(126, 100)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder   = Enum.SortOrder.LayoutOrder
	grid.Parent      = scroller
	Util.padding(scroller, 8)

	-- bestAuraTier loaded async so we track it in a mutable ref and rebuild cards
	local bestTier = 0
	local cardButtons: { { tier: number, btn: TextButton, updateFn: () -> () } } = {}

	local function makeCard(tier: number, layout: number)
		local def = tier > 0 and Auras[tier] or nil
		local isActive = tier == activeAuraTier
		local color = def and def.color or Color3.fromRGB(90, 90, 90)
		local isUnlocked = tier == 0 or tier <= bestTier

		local card = Instance.new("TextButton")
		card.AutoButtonColor  = false
		card.LayoutOrder      = layout
		card.BackgroundColor3 = isActive and Color3.fromRGB(30, 42, 65) or Theme.color.panelLight
		card.BorderSizePixel  = 0
		card.Text             = ""
		card.Parent           = scroller
		Util.corner(card, Theme.radius.md)

		if isActive then
			local st = Instance.new("UIStroke", card)
			st.Color     = color
			st.Thickness = 2
		end

		-- Color circle
		local circle = Instance.new("Frame")
		circle.AnchorPoint      = Vector2.new(0.5, 0)
		circle.Position         = UDim2.new(0.5, 0, 0, 8)
		circle.Size             = UDim2.fromOffset(36, 36)
		circle.BackgroundColor3 = isUnlocked and color or Color3.fromRGB(50, 50, 60)
		circle.BorderSizePixel  = 0
		circle.Parent           = card
		Util.corner(circle, UDim.new(1, 0))
		if isUnlocked and def then
			local glowRing = Instance.new("UIStroke", circle)
			glowRing.Color     = def.color
			glowRing.Thickness = 2
		end

		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position  = UDim2.new(0, 0, 0, 50)
		nameLbl.Size      = UDim2.new(1, 0, 0, 16)
		nameLbl.Font      = Theme.font.bold
		nameLbl.TextSize  = 11
		nameLbl.TextColor3 = isUnlocked and Theme.color.textPrimary or Theme.color.textMuted
		nameLbl.Text      = tier == 0 and Locale.t("aura.none") or Locale.t("aura.tier" .. tier)
		nameLbl.Parent    = card

		local stateLbl = Instance.new("TextLabel")
		stateLbl.BackgroundTransparency = 1
		stateLbl.Position  = UDim2.new(0, 0, 0, 68)
		stateLbl.Size      = UDim2.new(1, 0, 0, 16)
		stateLbl.Font      = Theme.font.body
		stateLbl.TextSize  = 10
		stateLbl.TextColor3 = isActive and color
			or isUnlocked and Theme.color.textMuted
			or Color3.fromRGB(100, 70, 70)
		stateLbl.Text = isActive and Locale.t("aura.active")
			or not isUnlocked and Locale.t("aura.locked")
			or Locale.t("aura.select")
		stateLbl.Parent = card

		-- Lock overlay
		if not isUnlocked then
			local overlay = Instance.new("Frame")
			overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
			overlay.BackgroundTransparency = 0.45
			overlay.BorderSizePixel = 0
			overlay.Size = UDim2.fromScale(1, 1)
			overlay.ZIndex = 5
			overlay.Parent = card
			Util.corner(overlay, Theme.radius.md)
			local lockLbl = Instance.new("TextLabel")
			lockLbl.BackgroundTransparency = 1
			lockLbl.Size = UDim2.fromScale(1, 1)
			lockLbl.Font = Theme.font.bold
			lockLbl.TextSize = 20
			lockLbl.TextColor3 = Color3.fromRGB(130, 100, 100)
			lockLbl.Text = "🔒"
			lockLbl.ZIndex = 6
			lockLbl.Parent = overlay
		end

		if isUnlocked then
			local captured = tier
			card.Activated:Connect(function()
				onAuraPicked(captured)
			end)
		end

		return card
	end

	-- First fetch bestAuraTier, then build cards
	task.spawn(function()
		local ok, profile = pcall(function()
			return Net:Function("RequestProfile"):InvokeServer()
		end)
		if ok and profile and profile.collection then
			bestTier = profile.collection.bestAuraTier or 0
		end
		-- Build "No Aura" card then tier 1-10
		makeCard(0, 0)
		for t = 1, 10 do
			makeCard(t, t)
		end
	end)
end

-- ─── Panel builder ────────────────────────────────────────────────────────────

function CompanionPanel.open(activeSkinId: string, activeAuraTier: number?)
	closePanel()

	local screen = ensureScreen()

	local panel = Instance.new("Frame")
	panel.Name              = "CompanionPanel"
	panel.AnchorPoint       = Vector2.new(0.5, 0.5)
	panel.Position          = UDim2.new(0.5, 0, 0.5, 20)
	panel.Size              = UDim2.fromOffset(500, 360)
	panel.BackgroundColor3  = Theme.color.panel
	panel.BorderSizePixel   = 0
	panel.Parent            = screen
	Util.corner(panel, Theme.radius.lg)

	local stroke = Instance.new("UIStroke", panel)
	stroke.Color     = Color3.fromRGB(140, 180, 255)
	stroke.Thickness = 1.5

	-- Header
	local header = Instance.new("Frame")
	header.BackgroundColor3 = Color3.fromRGB(22, 28, 50)
	header.BorderSizePixel  = 0
	header.Size             = UDim2.new(1, 0, 0, 44)
	header.Parent           = panel
	Util.corner(header, Theme.radius.lg)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Position  = UDim2.fromOffset(16, 0)
	titleLbl.Size      = UDim2.new(1, -60, 1, 0)
	titleLbl.Font      = Theme.font.heading
	titleLbl.TextSize  = 17
	titleLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text      = "   " .. Locale.t("companion.title")
	titleLbl.Parent    = header

	-- Close button — plain ASCII "X" to avoid font issues
	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint      = Vector2.new(1, 0.5)
	closeBtn.Position         = UDim2.new(1, -8, 0.5, 0)
	closeBtn.Size             = UDim2.fromOffset(30, 30)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
	closeBtn.BorderSizePixel  = 0
	closeBtn.Font             = Theme.font.bold
	closeBtn.TextColor3       = Color3.fromRGB(220, 160, 160)
	closeBtn.TextSize         = 16
	closeBtn.Text             = "X"
	closeBtn.Parent           = header
	Util.corner(closeBtn, Theme.radius.sm)
	closeBtn.Activated:Connect(closePanel)

	-- Tab bar
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(10, 50)
	tabBar.Size     = UDim2.new(1, -20, 0, 30)
	tabBar.Parent   = panel

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder     = Enum.SortOrder.LayoutOrder
	tabList.Padding       = UDim.new(0, 6)
	tabList.Parent        = tabBar

	-- Content (shrunk by 44 to make room for footer)
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, 86)
	content.Size     = UDim2.new(1, 0, 1, -130)
	content.Parent   = panel

	-- Footer: "Show Aion" toggle
	local footer = Instance.new("Frame")
	footer.BackgroundColor3 = Color3.fromRGB(22, 28, 50)
	footer.BorderSizePixel  = 0
	footer.AnchorPoint      = Vector2.new(0, 1)
	footer.Position         = UDim2.new(0, 0, 1, 0)
	footer.Size             = UDim2.new(1, 0, 0, 40)
	footer.Parent           = panel
	Util.corner(footer, Theme.radius.lg)

	local footerLbl = Instance.new("TextLabel")
	footerLbl.BackgroundTransparency = 1
	footerLbl.AnchorPoint   = Vector2.new(0, 0.5)
	footerLbl.Position      = UDim2.new(0, 14, 0.5, 0)
	footerLbl.Size          = UDim2.new(0.6, 0, 1, 0)
	footerLbl.Font          = Theme.font.bold
	footerLbl.TextSize      = 14
	footerLbl.TextColor3    = Theme.color.textSecondary
	footerLbl.TextXAlignment = Enum.TextXAlignment.Left
	footerLbl.Text          = Locale.t("companion.showToggle")
	footerLbl.Parent        = footer

	-- Read toggle state directly from the live controller — no async needed.
	-- This avoids the bug where a stale saved setting overwrites the display.
	local CC_live = require(script.Parent.Parent.Parent.controllers.CompanionController)
	local toggleEnabled = CC_live.isEnabled()

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.AnchorPoint      = Vector2.new(1, 0.5)
	toggleBtn.Position         = UDim2.new(1, -12, 0.5, 0)
	toggleBtn.Size             = UDim2.fromOffset(70, 26)
	toggleBtn.BorderSizePixel  = 0
	toggleBtn.Font             = Theme.font.bold
	toggleBtn.TextSize         = 13
	toggleBtn.Parent           = footer
	Util.corner(toggleBtn, Theme.radius.sm)

	local function applyToggleVisual()
		toggleBtn.BackgroundColor3 = toggleEnabled and Theme.color.success or Theme.color.panel
		toggleBtn.TextColor3       = toggleEnabled and Color3.fromRGB(15, 25, 15) or Theme.color.textPrimary
		toggleBtn.Text             = toggleEnabled and "ON" or "OFF"
	end
	applyToggleVisual()

	local Net2 = require(Shared.remotes.Net)
	toggleBtn.Activated:Connect(function()
		toggleEnabled = not toggleEnabled
		applyToggleVisual()
		CC_live.setEnabled(toggleEnabled)
		task.spawn(function()
			pcall(function()
				Net2:Function("ChangeSetting"):InvokeServer("companionEnabled", toggleEnabled)
			end)
		end)
	end)

	local TABS = {
		{ id = "skins",     label = Locale.t("companion.tab.skins") },
		{ id = "help",      label = Locale.t("companion.tab.help") },
		{ id = "abilities", label = Locale.t("companion.tab.abilities") },
		{ id = "auras",     label = Locale.t("companion.tab.auras") },
	}
	local activeTab = "skins"
	local skinInPanel = activeSkinId
	local auraInPanel = activeAuraTier or 0

	local function switchTab(id: string)
		activeTab = id
		for _, c in ipairs(tabBar:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for i, tab in ipairs(TABS) do
			local btn = makeTabBtn(tabBar, tab.label, tab.id == id, function()
				if activeTab ~= tab.id then switchTab(tab.id) end
			end)
			btn.LayoutOrder = i
		end
		for _, c in ipairs(content:GetChildren()) do c:Destroy() end

		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size   = UDim2.fromScale(1, 1)
		inner.Parent = content

		if id == "skins" then
			buildSkinsTab(inner, skinInPanel, function(skinId)
				skinInPanel = skinId
				local CompanionController = require(script.Parent.Parent.Parent.controllers.CompanionController)
				CompanionController.setSkin(skinId)
				task.spawn(function()
					pcall(function()
						Net:Function("SetCompanionSkin"):InvokeServer(skinId)
					end)
				end)
				switchTab("skins")
			end)
		elseif id == "help" then
			buildHelpTab(inner)
		elseif id == "abilities" then
			buildAbilitiesTab(inner)
		elseif id == "auras" then
			buildAurasTab(inner, auraInPanel, function(tier: number)
				auraInPanel = tier
				-- Apply immediately on client
				local AC = require(script.Parent.Parent.Parent.controllers.AuraController)
				AC.setTier(tier)
				-- Persist to server
				task.spawn(function()
					pcall(function()
						Net:Function("SetActiveAura"):InvokeServer(tier)
					end)
				end)
				-- Rebuild tab so highlight updates
				switchTab("auras")
			end)
		end
	end

	activePanel = panel
	switchTab("skins")

	-- Entrance animation
	panel.Position = UDim2.new(0.5, 0, 0.5, 24)
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
end

function CompanionPanel.close()
	closePanel()
end

return CompanionPanel
