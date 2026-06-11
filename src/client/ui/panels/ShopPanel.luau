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
ShopPanel.frenzyDiscount = 0 -- set by UIController when frenzy active

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
	rightHolder.Size = UDim2.fromOffset(340, 80)
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
		local displayPrice = pack.basePriceGold
		if ShopPanel.frenzyDiscount > 0 then
			displayPrice = math.floor(displayPrice * (1 - ShopPanel.frenzyDiscount))
			priceLabel.Text = string.format("🔥 💰 %s (-%d%%)", Odds.formatBig(displayPrice), ShopPanel.frenzyDiscount * 100)
			priceLabel.TextColor3 = Color3.fromRGB(255, 140, 50)
		else
			priceLabel.Text = string.format("💰 %s", Odds.formatBig(displayPrice))
		end
		priceLabel.Parent = rightHolder

		local buttons = Instance.new("Frame")
		buttons.BackgroundTransparency = 1
		buttons.Position = UDim2.fromOffset(0, 28)
		buttons.Size = UDim2.new(1, 0, 1, -28)
		buttons.Parent = rightHolder
		Util.listLayout(buttons, Enum.FillDirection.Horizontal, 6)

		local hasMultiOpen = (profileSnapshot.unlocks
			and profileSnapshot.unlocks.gamepasses
			and profileSnapshot.unlocks.gamepasses.multiOpen) == true

		-- Standardmäßig x1/x5/x10 plus mit Multi-Open Pass auch x50.
		local counts = { 1, 5, 10 }
		if hasMultiOpen then table.insert(counts, 50) end

		for _, count in ipairs(counts) do
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

		-- Wenn der Multi-Open Pass NICHT besessen wird, ein Lock-Tile zeigen, das
		-- den Spieler zum Pässe-Tab schickt.
		if not hasMultiOpen then
			local lock = Util.button("x50 🔒", Theme.color.locked)
			lock.Size = UDim2.new(0, 64, 1, 0)
			lock.Parent = buttons
			lock.Activated:Connect(function()
				lock.Text = "Buy Pass!"
				task.delay(1.5, function() if lock and lock.Parent then lock.Text = "x50 🔒" end end)
				pcall(function()
					Net:Function("PromptGamepass"):InvokeServer("multiOpen")
				end)
			end)
		end

		-- Auto-Roll-Toggle pro Pack — Gate via Gamepass.
		local autoBtn = Util.button("Auto", Theme.color.success)
		autoBtn.Size = UDim2.new(0, 64, 1, 0)
		autoBtn.Parent = buttons

		local function refreshAuto(active: number?, isEnabled: boolean?)
			local activeNow = active == pack.id
			local on = isEnabled
			if on == nil then on = AutoRollController.isEnabled() end
			if not on then
				autoBtn.Text = "🔒"
				autoBtn.BackgroundColor3 = Theme.color.locked
				return
			end
			if activeNow then
				autoBtn.Text = "Stop"
				autoBtn.BackgroundColor3 = Theme.color.danger
			else
				autoBtn.Text = "Auto"
				autoBtn.BackgroundColor3 = Theme.color.success
			end
		end
		refreshAuto(AutoRollController.activePackId(), AutoRollController.isEnabled())
		AutoRollController.onChange(refreshAuto)

		autoBtn.Activated:Connect(function()
			if not AutoRollController.isEnabled() then
				-- Pass nicht besessen: leite zum Pässe-Tab um.
				autoBtn.Text = "Buy Pass!"
				task.delay(1.5, function()
					refreshAuto(AutoRollController.activePackId(), AutoRollController.isEnabled())
				end)
				pcall(function()
					Net:Function("PromptGamepass"):InvokeServer("autoRoll")
				end)
				return
			end
			AutoRollController.toggle(pack.id)
		end)
	end

	return card
end

local function makeEventCard(eventData: any, snapshot: any): Frame
	local c = eventData.color or { 1, 0.7, 0 }
	local eventColor = Color3.fromRGB(
		math.floor((c[1] or 1) * 255),
		math.floor((c[2] or 0.7) * 255),
		math.floor((c[3] or 0) * 255)
	)
	local packInfo = eventData.pack or {}
	local priceGold = packInfo.priceGold or 0
	local pullCount = packInfo.pullCount or 5

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(20, 10, 32)
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 104)
	Util.corner(card, Theme.radius.md)

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = eventColor
	stroke.Thickness = 2

	-- Animated gradient shine
	local grad = Instance.new("UIGradient", card)
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 20, 60)), ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 10, 32)) })
	grad.Rotation = 45

	-- Event badge top-left
	local badge = Instance.new("TextLabel")
	badge.BackgroundColor3 = eventColor
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(10, 8)
	badge.Size = UDim2.fromOffset(90, 20)
	badge.Font = Theme.font.bold
	badge.TextSize = 11
	badge.TextColor3 = Color3.fromRGB(20, 20, 30)
	badge.Text = "✨ " .. Locale.t("event.packLabel")
	badge.Parent = card
	Util.corner(badge, Theme.radius.sm)

	-- Event name
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Position = UDim2.fromOffset(10, 32)
	nameLbl.Size = UDim2.new(0.55, -20, 0, 22)
	nameLbl.Font = Theme.font.heading
	nameLbl.TextSize = 17
	nameLbl.TextColor3 = eventColor
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = Locale.t(eventData.nameKey or "event.active")
	nameLbl.Parent = card

	-- Description
	local descLbl = Instance.new("TextLabel")
	descLbl.BackgroundTransparency = 1
	descLbl.Position = UDim2.fromOffset(10, 55)
	descLbl.Size = UDim2.new(0.55, -20, 0, 18)
	descLbl.Font = Theme.font.body
	descLbl.TextSize = 12
	descLbl.TextColor3 = Theme.color.textSecondary
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.Text = Locale.t(eventData.descKey or "event.noEvent")
	descLbl.Parent = card

	-- Countdown label
	local countdownLbl = Instance.new("TextLabel")
	countdownLbl.BackgroundTransparency = 1
	countdownLbl.Position = UDim2.fromOffset(10, 76)
	countdownLbl.Size = UDim2.new(0.55, -20, 0, 16)
	countdownLbl.Font = Theme.font.body
	countdownLbl.TextSize = 12
	countdownLbl.TextColor3 = Theme.color.textMuted
	countdownLbl.TextXAlignment = Enum.TextXAlignment.Left
	countdownLbl.Parent = card
	local endsAt = eventData.endsAt or 0
	task.spawn(function()
		while countdownLbl.Parent do
			local secs = math.max(0, endsAt - os.time())
			local h = math.floor(secs / 3600)
			local m = math.floor((secs % 3600) / 60)
			local s = secs % 60
			countdownLbl.Text = string.format(Locale.t("event.endsIn"), string.format("%d:%02d:%02d", h, m, s))
			task.wait(1)
		end
	end)

	-- Right side: price + buy button
	local currencies = snapshot.currencies or {}
	local gold = currencies.gold or 0
	local canAfford = gold >= priceGold

	local priceLbl = Instance.new("TextLabel")
	priceLbl.BackgroundTransparency = 1
	priceLbl.AnchorPoint = Vector2.new(1, 0)
	priceLbl.Position = UDim2.new(1, -16, 0, 22)
	priceLbl.Size = UDim2.fromOffset(200, 26)
	priceLbl.Font = Theme.font.bold
	priceLbl.TextSize = 16
	priceLbl.TextColor3 = canAfford and Theme.color.textPrimary or Theme.color.danger
	priceLbl.TextXAlignment = Enum.TextXAlignment.Right
	priceLbl.Text = string.format("🪙 %s  (%dx pulls)", Odds.formatBig(priceGold), pullCount)
	priceLbl.Parent = card

	local buyBtn = Instance.new("TextButton")
	buyBtn.AnchorPoint = Vector2.new(1, 1)
	buyBtn.Position = UDim2.new(1, -16, 1, -12)
	buyBtn.Size = UDim2.fromOffset(160, 36)
	buyBtn.BackgroundColor3 = canAfford and eventColor or Theme.color.panelLight
	buyBtn.BorderSizePixel = 0
	buyBtn.AutoButtonColor = false
	buyBtn.Font = Theme.font.bold
	buyBtn.TextSize = 14
	buyBtn.TextColor3 = canAfford and Color3.fromRGB(20, 20, 30) or Theme.color.textMuted
	buyBtn.Text = Locale.t("event.buy")
	buyBtn.Parent = card
	Util.corner(buyBtn, Theme.radius.sm)

	buyBtn.Activated:Connect(function()
		buyBtn.Active = false
		buyBtn.Text = "…"
		local ok, res = pcall(function()
			return Net:Function("BuyEventPack"):InvokeServer()
		end)
		if ok and res and res.ok then
			buyBtn.Text = "✓"
		else
			buyBtn.Text = Locale.t("event.buy")
			buyBtn.Active = true
		end
	end)

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

	-- Event pack card at the top when an event is active
	if snapshot.activeEvent then
		local eventCard = makeEventCard(snapshot.activeEvent, snapshot)
		eventCard.Parent = scroller
	end

	for _, pack in ipairs(Packs.list) do
		local card = makePackCard(pack, snapshot)
		card.Parent = scroller
	end
end

return ShopPanel
