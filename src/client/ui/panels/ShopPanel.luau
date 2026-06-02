--!strict
-- ShopPanel — Liste aller 10 Gold-Packs + Ascendant. Zeigt Lock-Status klar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Packs = require(Shared.config.Packs)
local Rarities = require(Shared.config.Rarities)
local Odds = require(Shared.math.Odds)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)
local AutoRollController = require(script.Parent.Parent.Parent.controllers.AutoRollController)

local ShopPanel = {}

local function makePackCard(pack, profileSnapshot): Frame
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.color.panelLight
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 96)
	Util.corner(card, Theme.radius.md)

	-- Linke Seite: Pack-Info
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(0.55, 0, 0, 26)
	title.Font = Theme.font.heading
	title.TextSize = 18
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t(pack.idKey)
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(16, 36)
	desc.Size = UDim2.new(0.55, 0, 0, 18)
	desc.Font = Theme.font.body
	desc.TextSize = 13
	desc.TextColor3 = Theme.color.textSecondary
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Text = Locale.t(pack.descKey)
	desc.Parent = card

	-- Rarities-Preview: kleine Farbpunkte
	local previewHolder = Instance.new("Frame")
	previewHolder.BackgroundTransparency = 1
	previewHolder.Position = UDim2.fromOffset(16, 60)
	previewHolder.Size = UDim2.new(0.55, 0, 0, 28)
	previewHolder.Parent = card
	Util.listLayout(previewHolder, Enum.FillDirection.Horizontal, 6)

	for _, rarityId in ipairs(pack.rarities) do
		local def = Rarities.byId[rarityId]
		local dot = Instance.new("TextLabel")
		dot.BackgroundColor3 = def and def.color or Theme.color.panelLight
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(60, 22)
		dot.Font = Theme.font.bold
		dot.TextSize = 11
		dot.TextColor3 = Color3.fromRGB(20, 20, 30)
		dot.Text = def and Locale.t(def.nameKey) or rarityId
		dot.Parent = previewHolder
		Util.corner(dot, Theme.radius.sm)
	end

	-- Lock-Status auswerten
	local currencies = profileSnapshot.currencies or {}
	local lifetime = profileSnapshot.lifetime or { gold = 0, rebirths = 0 }
	local unlocks = profileSnapshot.unlocks or { packs = {} }

	local unlocked = true
	local reason: string? = nil
	if pack.unlock.robux then
		unlocked = false
		reason = "robux_only"
	elseif unlocks.packs[tostring(pack.id)] then
		unlocked = true
		if pack.unlock.rebirths and lifetime.rebirths < pack.unlock.rebirths then
			unlocked = false; reason = "rebirths"
		end
	else
		if pack.unlock.gold then
			local reach = math.max(lifetime.gold or 0, currencies.gold or 0)
			if reach < pack.unlock.gold then
				unlocked = false; reason = "gold_lifetime"
			end
		end
		if pack.unlock.rebirths and lifetime.rebirths < pack.unlock.rebirths then
			unlocked = false; reason = "rebirths"
		end
	end

	-- Rechte Seite: Preis + Buy/Lock
	local rightHolder = Instance.new("Frame")
	rightHolder.BackgroundTransparency = 1
	rightHolder.AnchorPoint = Vector2.new(1, 0)
	rightHolder.Position = UDim2.new(1, -16, 0, 8)
	rightHolder.Size = UDim2.fromOffset(260, 80)
	rightHolder.Parent = card

	if not unlocked then
		local lockBox = Instance.new("Frame")
		lockBox.BackgroundColor3 = Theme.color.locked
		lockBox.BorderSizePixel = 0
		lockBox.Size = UDim2.fromScale(1, 1)
		lockBox.Parent = rightHolder
		Util.corner(lockBox, Theme.radius.md)

		local lockLabel = Instance.new("TextLabel")
		lockLabel.BackgroundTransparency = 1
		lockLabel.Size = UDim2.fromScale(1, 1)
		lockLabel.Font = Theme.font.bold
		lockLabel.TextSize = 14
		lockLabel.TextColor3 = Theme.color.textPrimary
		lockLabel.TextWrapped = true
		if reason == "gold_lifetime" then
			lockLabel.Text = string.format("🔒 %s", string.format(Locale.t("shop.requiresGold"), Odds.formatBig(pack.unlock.gold or 0)))
		elseif reason == "rebirths" then
			lockLabel.Text = string.format("🔒 %s", string.format(Locale.t("shop.requiresRebirth"), pack.unlock.rebirths or 0))
		elseif reason == "robux_only" then
			lockLabel.Text = "🔒 Robux Only"
		else
			lockLabel.Text = "🔒 Locked"
		end
		lockLabel.Parent = lockBox
	else
		local priceLabel = Instance.new("TextLabel")
		priceLabel.BackgroundTransparency = 1
		priceLabel.Size = UDim2.new(1, 0, 0, 22)
		priceLabel.Font = Theme.font.bold
		priceLabel.TextSize = 16
		priceLabel.TextColor3 = Theme.color.gold
		priceLabel.TextXAlignment = Enum.TextXAlignment.Right
		priceLabel.Text = string.format("💰 %s", Odds.formatBig(pack.basePriceGold))
		priceLabel.Parent = rightHolder

		local buttons = Instance.new("Frame")
		buttons.BackgroundTransparency = 1
		buttons.Position = UDim2.fromOffset(0, 28)
		buttons.Size = UDim2.new(1, 0, 1, -28)
		buttons.Parent = rightHolder
		Util.listLayout(buttons, Enum.FillDirection.Horizontal, 6)

		for _, count in ipairs({ 1, 5, 10 }) do
			local b = Util.button("x" .. count, Theme.color.accent)
			b.Size = UDim2.new(0, 48, 1, 0)
			b.Parent = buttons
			b.Activated:Connect(function()
				b.Text = "..."
				local result = Net:Function("BuyPack"):InvokeServer(pack.id, count)
				if result and result.ok then
					b.Text = "x" .. count
				else
					b.Text = "✖"
					task.delay(1, function() b.Text = "x" .. count end)
				end
			end)
		end

		-- Auto-Roll-Toggle pro Pack
		local autoBtn = Util.button("Auto", Theme.color.success)
		autoBtn.Size = UDim2.new(0, 64, 1, 0)
		autoBtn.Parent = buttons

		local function refreshAuto(active: number?)
			if active == pack.id then
				autoBtn.Text = "Stop"
				autoBtn.BackgroundColor3 = Theme.color.danger
			else
				autoBtn.Text = "Auto"
				autoBtn.BackgroundColor3 = Theme.color.success
			end
		end
		refreshAuto(AutoRollController.activePackId())
		AutoRollController.onChange(refreshAuto)

		autoBtn.Activated:Connect(function()
			AutoRollController.toggle(pack.id)
		end)
	end

	return card
end

function ShopPanel.create(body: Instance, snapshot)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = body
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 8)

	for _, pack in ipairs(Packs.list) do
		local card = makePackCard(pack, snapshot)
		card.Parent = scroller
	end
end

return ShopPanel
