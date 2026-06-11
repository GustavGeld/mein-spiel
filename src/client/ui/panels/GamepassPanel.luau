--!strict
-- GamepassPanel — Robux-Shop: Permanente Gamepasses + Dev-Product-Bundles.
-- Buttons triggern serverseitiges Prompt (Net:Function("PromptGamepass") /
-- "PromptDevProduct"); der Roblox-Dialog ploppt direkt auf.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Gamepasses = require(Shared.config.Gamepasses)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local GamepassPanel = {}

local LocalPlayer = Players.LocalPlayer

local CATEGORIES = { "boost", "convenience", "utility" }

local RIGHT_COL_WIDTH = 180

local function makeGamepassCard(pass, ownedFlags): Frame
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.color.panelLight
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 120)
	Util.corner(card, Theme.radius.md)

	-- Akzentstreifen links
	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = pass.color
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(0, 8, 1, 0)
	accent.Parent = card
	Util.corner(accent, Theme.radius.sm)

	-- Linke Spalte: Titel + Beschreibung
	local leftCol = Instance.new("Frame")
	leftCol.BackgroundTransparency = 1
	leftCol.Position = UDim2.fromOffset(22, 12)
	leftCol.Size = UDim2.new(1, -RIGHT_COL_WIDTH - 40, 1, -24)
	leftCol.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Font = Theme.font.heading
	title.TextSize = 20
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t(pass.nameKey)
	title.Parent = leftCol

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(0, 30)
	desc.Size = UDim2.new(1, 0, 1, -30)
	desc.Font = Theme.font.body
	desc.TextSize = 14
	desc.TextColor3 = Theme.color.textSecondary
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.Text = Locale.t(pass.descKey)
	desc.Parent = leftCol

	-- Rechte Spalte: vertikaler Stack (alles fließt sauber untereinander)
	local rightCol = Instance.new("Frame")
	rightCol.BackgroundTransparency = 1
	rightCol.AnchorPoint = Vector2.new(1, 0.5)
	rightCol.Position = UDim2.new(1, -14, 0.5, 0)
	rightCol.Size = UDim2.new(0, RIGHT_COL_WIDTH, 1, -16)
	rightCol.Parent = card

	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.Padding = UDim.new(0, 6)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = rightCol

	local owned = ownedFlags and ownedFlags[pass.flag] == true
	if owned then
		-- Owned-Badge
		local badge = Instance.new("TextLabel")
		badge.LayoutOrder = 1
		badge.BackgroundColor3 = Theme.color.success
		badge.BorderSizePixel = 0
		badge.Size = UDim2.fromOffset(RIGHT_COL_WIDTH, 38)
		badge.Font = Theme.font.heading
		badge.TextSize = 16
		badge.TextColor3 = Color3.fromRGB(20, 20, 30)
		badge.Text = "✓ " .. Locale.t("gamepass.owned")
		badge.Parent = rightCol
		Util.corner(badge, Theme.radius.md)

		if RunService:IsStudio() then
			local devBtn = Util.button("DEV: Disable", Theme.color.danger)
			devBtn.LayoutOrder = 2
			devBtn.Size = UDim2.fromOffset(RIGHT_COL_WIDTH, 32)
			devBtn.TextSize = 13
			devBtn.Parent = rightCol
			devBtn.Activated:Connect(function()
				devBtn.Text = "…"
				pcall(function()
					Net:Function("DebugTogglePass"):InvokeServer(pass.flag)
				end)
			end)
		end
	else
		-- Preis
		local priceLabel = Instance.new("TextLabel")
		priceLabel.LayoutOrder = 1
		priceLabel.BackgroundTransparency = 1
		priceLabel.Size = UDim2.fromOffset(RIGHT_COL_WIDTH, 22)
		priceLabel.Font = Theme.font.bold
		priceLabel.TextSize = 16
		priceLabel.TextColor3 = Theme.color.gold
		priceLabel.TextXAlignment = Enum.TextXAlignment.Right
		priceLabel.Text = string.format(Locale.t("gamepass.priceRobux"), pass.priceRobux)
		priceLabel.Parent = rightCol

		-- Buy-Button
		local buyBtn = Util.button(Locale.t("gamepass.buy"), pass.color)
		buyBtn.LayoutOrder = 2
		buyBtn.Size = UDim2.fromOffset(RIGHT_COL_WIDTH, 40)
		buyBtn.TextSize = 16
		buyBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
		buyBtn.Parent = rightCol

		buyBtn.Activated:Connect(function()
			buyBtn.Text = "…"
			buyBtn.AutoButtonColor = false
			local result = Net:Function("PromptGamepass"):InvokeServer(pass.flag)
			if not result then
				if buyBtn and buyBtn.Parent then
					buyBtn.Text = Locale.t("gamepass.buy")
					buyBtn.AutoButtonColor = true
				end
				return
			end
			if result.reason == "not_configured" then
				if buyBtn and buyBtn.Parent then
					buyBtn.Text = Locale.t("gamepass.unavailable")
					buyBtn.AutoButtonColor = true
				end
				return
			end
			if not result.ok then
				if buyBtn and buyBtn.Parent then
					buyBtn.Text = Locale.t("gamepass.buy")
					buyBtn.AutoButtonColor = true
				end
				return
			end
			-- Kauf erfolgreich: Snapshot direkt patchen + Panel forciert rebuilden.
			local ok2, UIController = pcall(require, script:FindFirstAncestor("Client").controllers.UIController)
			if ok2 and UIController and UIController.snapshot then
				UIController.snapshot.unlocks = UIController.snapshot.unlocks or { packs = {}, gamepasses = {} }
				UIController.snapshot.unlocks.gamepasses = UIController.snapshot.unlocks.gamepasses or {}
				UIController.snapshot.unlocks.gamepasses[pass.flag] = true
				if UIController.forceRebuild then
					UIController.forceRebuild()
				end
			end
		end)

		if RunService:IsStudio() then
			local devBtn = Util.button("DEV: Grant", Theme.color.success)
			devBtn.LayoutOrder = 3
			devBtn.Size = UDim2.fromOffset(RIGHT_COL_WIDTH, 28)
			devBtn.TextSize = 12
			devBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
			devBtn.Parent = rightCol
			devBtn.Activated:Connect(function()
				devBtn.Text = "…"
				pcall(function()
					Net:Function("DebugTogglePass"):InvokeServer(pass.flag)
				end)
			end)
		end
	end

	return card
end

local function makeDevProductCard(product): Frame
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.color.panelLight
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 80)
	Util.corner(card, Theme.radius.md)

	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = product.color
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(0, 6, 1, 0)
	accent.Parent = card
	Util.corner(accent, Theme.radius.sm)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 8)
	title.Size = UDim2.new(0.6, 0, 0, 22)
	title.Font = Theme.font.heading
	title.TextSize = 16
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t(product.nameKey)
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(20, 32)
	desc.Size = UDim2.new(0.6, 0, 0, 36)
	desc.Font = Theme.font.body
	desc.TextSize = 13
	desc.TextColor3 = Theme.color.textSecondary
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.Text = Locale.t(product.descKey)
	desc.Parent = card

	local buyBtn = Util.button(string.format(Locale.t("gamepass.priceRobux"), product.priceRobux), product.color)
	buyBtn.AnchorPoint = Vector2.new(1, 0.5)
	buyBtn.Position = UDim2.new(1, -16, 0.5, 0)
	buyBtn.Size = UDim2.fromOffset(120, 40)
	buyBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
	buyBtn.Parent = card

	buyBtn.Activated:Connect(function()
		buyBtn.Text = "…"
		local result = Net:Function("PromptDevProduct"):InvokeServer(product.id)
		task.delay(1.0, function()
			if buyBtn and buyBtn.Parent then
				buyBtn.Text = string.format(Locale.t("gamepass.priceRobux"), product.priceRobux)
			end
		end)
		if result and not result.ok and result.reason == "not_configured" then
			if buyBtn and buyBtn.Parent then
				buyBtn.Text = Locale.t("gamepass.unavailable")
			end
		end
	end)

	return card
end

local function makeCategoryHeader(text: string): TextLabel
	local h = Instance.new("TextLabel")
	h.BackgroundTransparency = 1
	h.Size = UDim2.new(1, 0, 0, 28)
	h.Font = Theme.font.heading
	h.TextSize = 18
	h.TextColor3 = Theme.color.accent
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Text = text
	return h
end

function GamepassPanel.create(body: Instance, snapshot)
	local ownedFlags = (snapshot and snapshot.unlocks and snapshot.unlocks.gamepasses) or {}

	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = body
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 10)

	-- Pässe nach Kategorie gruppiert
	for _, cat in ipairs(CATEGORIES) do
		local headerText = Locale.t("gamepass.category." .. cat)
		local hasAny = false
		for _, pass in ipairs(Gamepasses.list) do
			if pass.category == cat then hasAny = true; break end
		end
		if hasAny then
			local header = makeCategoryHeader(headerText)
			header.Parent = scroller
			for _, pass in ipairs(Gamepasses.list) do
				if pass.category == cat then
					local card = makeGamepassCard(pass, ownedFlags)
					card.Parent = scroller
				end
			end
		end
	end

	-- Dev Products / Bundles
	if #Gamepasses.products > 0 then
		local sep = makeCategoryHeader(Locale.t("gamepass.devProducts"))
		sep.Parent = scroller
		for _, product in ipairs(Gamepasses.products) do
			local card = makeDevProductCard(product)
			card.Parent = scroller
		end
	end
end

return GamepassPanel
