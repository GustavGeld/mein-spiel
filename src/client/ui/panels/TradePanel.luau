--!strict
-- TradePanel — zeigt entweder die Liste anderer Spieler (Invite-Modus) oder
-- eine aktive Trade-Session (Offer + Hold-Accept).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)
local TradeController = require(script.Parent.Parent.Parent.controllers.TradeController)

local TradePanel = {}

local LocalPlayer = Players.LocalPlayer

local function findEntry(inventory, uid: string)
	for _, e in ipairs(inventory.gods) do
		if e.uid == uid then return e end
	end
	return nil
end

local function displayName(id: string): string
	return (string.gsub(id, "_", " "))
end

-- ─── Lobby-Liste ──────────────────────────────────────────────────────────────
local function makeLobbyView(body: Instance)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 28)
	title.Font = Theme.font.heading
	title.TextSize = 18
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t("trade.playersInServer")
	title.Parent = body

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 34)
	list.Size = UDim2.new(1, 0, 1, -34)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.Parent = body
	Util.listLayout(list, Enum.FillDirection.Vertical, 6)

	local players = TradeController.otherPlayers()
	if #players == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.Font = Theme.font.body
		empty.TextSize = 14
		empty.TextColor3 = Theme.color.textMuted
		empty.Text = Locale.t("trade.empty")
		empty.Parent = list
		return
	end

	for _, p in ipairs(players) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.color.panelLight
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 52)
		row.Parent = list
		Util.corner(row, Theme.radius.md)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(14, 0)
		name.Size = UDim2.new(0.6, 0, 1, 0)
		name.Font = Theme.font.bold
		name.TextSize = 15
		name.TextColor3 = Theme.color.textPrimary
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = p.DisplayName .. " (@" .. p.Name .. ")"
		name.Parent = row

		local btn = Util.button(Locale.t("trade.send"), Theme.color.accent)
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
		btn.Size = UDim2.fromOffset(110, 36)
		btn.Parent = row

		btn.Activated:Connect(function()
			btn.Text = "…"
			local result = TradeController.sendInvite(p.UserId)
			if result and result.ok then
				btn.Text = Locale.t("trade.inviteSent")
				task.delay(2, function()
					if btn and btn.Parent then btn.Text = Locale.t("trade.send") end
				end)
			else
				local reason = result and result.reason or "err"
				btn.Text = reason
				task.delay(2, function()
					if btn and btn.Parent then btn.Text = Locale.t("trade.send") end
				end)
			end
		end)
	end
end

-- ─── Mini-Karte für Offer ─────────────────────────────────────────────────────
local function makeOfferCard(entry: any?, godId: string?, rarityId: string?, onClick: (() -> ())?): Frame
	local card = Instance.new("TextButton")
	card.AutoButtonColor = true
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(96, 110)
	card.Text = ""
	Util.corner(card, Theme.radius.md)

	local rDef = rarityId and Rarities.byId[rarityId] or nil
	local color = (rDef and rDef.color) or Theme.color.panelLight
	card.BackgroundColor3 = Color3.new(
		color.R * 0.2 + Theme.color.panel.R * 0.8,
		color.G * 0.2 + Theme.color.panel.G * 0.8,
		color.B * 0.2 + Theme.color.panel.B * 0.8
	)
	Util.stroke(card, color, 2)

	local strip = Instance.new("Frame")
	strip.BackgroundColor3 = color
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, 0, 0, 16)
	strip.Parent = card
	Util.corner(strip, Theme.radius.sm)

	local stripLbl = Instance.new("TextLabel")
	stripLbl.BackgroundTransparency = 1
	stripLbl.Size = UDim2.fromScale(1, 1)
	stripLbl.Font = Theme.font.bold
	stripLbl.TextSize = 10
	stripLbl.TextColor3 = Color3.fromRGB(20, 20, 30)
	stripLbl.Text = rDef and Locale.t(rDef.nameKey) or ""
	stripLbl.Parent = strip

	-- Icon
	local def = godId and Gods.byId[godId] or nil
	local hasIcon = def and def.iconAssetId and def.iconAssetId ~= ""
	if hasIcon then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.new(0.5, 0, 0, 22)
		img.Size = UDim2.fromOffset(56, 56)
		img.Image = def.iconAssetId :: string
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = card
	else
		local fb = Instance.new("TextLabel")
		fb.BackgroundTransparency = 1
		fb.AnchorPoint = Vector2.new(0.5, 0)
		fb.Position = UDim2.new(0.5, 0, 0, 22)
		fb.Size = UDim2.fromOffset(56, 56)
		fb.Font = Theme.font.heading
		fb.TextSize = 36
		fb.TextColor3 = color
		fb.Text = godId and string.upper(string.sub(godId, 1, 1)) or "?"
		fb.Parent = card
	end

	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Position = UDim2.fromOffset(4, 82)
	nameLbl.Size = UDim2.new(1, -8, 0, 22)
	nameLbl.Font = Theme.font.bold
	nameLbl.TextSize = 11
	nameLbl.TextColor3 = Theme.color.textPrimary
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Text = godId and displayName(godId) or "?"
	nameLbl.Parent = card

	if onClick then card.Activated:Connect(onClick) end
	return card
end

-- ─── Session-View ─────────────────────────────────────────────────────────────
local function makeSessionView(body: Instance, session: any, snapshot: any)
	local inventory = snapshot.inventory or { gods = {} }

	-- Header mit Cancel-Button
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 34)
	header.Parent = body

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -130, 1, 0)
	title.Font = Theme.font.heading
	title.TextSize = 18
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = string.format(Locale.t("trade.tradeWith"), session.otherName or "?")
	title.Parent = header

	local cancelBtn = Util.button(Locale.t("trade.cancel"), Theme.color.danger)
	cancelBtn.AnchorPoint = Vector2.new(1, 0.5)
	cancelBtn.Position = UDim2.new(1, 0, 0.5, 0)
	cancelBtn.Size = UDim2.fromOffset(120, 30)
	cancelBtn.Parent = header
	cancelBtn.Activated:Connect(function()
		TradeController.cancel()
	end)

	-- Zwei Spalten
	local cols = Instance.new("Frame")
	cols.BackgroundTransparency = 1
	cols.Position = UDim2.fromOffset(0, 42)
	cols.Size = UDim2.new(1, 0, 1, -120)
	cols.Parent = body

	local function makeColumn(labelText: string, side: "left" | "right"): (Frame, ScrollingFrame)
		local col = Instance.new("Frame")
		col.BackgroundColor3 = Theme.color.panelLight
		col.BorderSizePixel = 0
		col.Size = UDim2.new(0.5, -6, 1, 0)
		col.Position = side == "left" and UDim2.fromOffset(0, 0) or UDim2.new(0.5, 6, 0, 0)
		col.Parent = cols
		Util.corner(col, Theme.radius.md)

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Position = UDim2.fromOffset(12, 6)
		lbl.Size = UDim2.new(1, -24, 0, 20)
		lbl.Font = Theme.font.bold
		lbl.TextSize = 13
		lbl.TextColor3 = Theme.color.textSecondary
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Text = labelText
		lbl.Parent = col

		local grid = Instance.new("ScrollingFrame")
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Position = UDim2.fromOffset(8, 30)
		grid.Size = UDim2.new(1, -16, 1, -38)
		grid.CanvasSize = UDim2.new()
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.ScrollBarThickness = 4
		grid.Parent = col
		Util.gridLayout(grid, UDim2.fromOffset(96, 110), UDim2.fromOffset(6, 6))

		return col, grid
	end

	local _, myGrid = makeColumn(Locale.t("trade.myOffer"), "left")
	local _, theirGrid = makeColumn(Locale.t("trade.theirOffer"), "right")

	-- Mein Offer
	for _, uid in ipairs(session.myOffer or {}) do
		local entry = findEntry(inventory, uid)
		if entry then
			local c = makeOfferCard(entry, entry.id, entry.rarityId, function()
				TradeController.removeOffer(uid)
			end)
			c.Parent = myGrid
		end
	end

	-- + Add God Karte
	local addCard = Instance.new("TextButton")
	addCard.AutoButtonColor = true
	addCard.BackgroundColor3 = Theme.color.panel
	addCard.BorderSizePixel = 0
	addCard.Size = UDim2.fromOffset(96, 110)
	addCard.Font = Theme.font.heading
	addCard.TextSize = 14
	addCard.TextColor3 = Theme.color.textPrimary
	addCard.Text = Locale.t("trade.addGod")
	addCard.LayoutOrder = 999
	addCard.Parent = myGrid
	Util.corner(addCard, Theme.radius.md)
	Util.stroke(addCard, Theme.color.accent, 2)
	addCard.Activated:Connect(function()
		TradePanel.openPicker(body.Parent :: Instance, inventory, function(uid)
			TradeController.offer(uid)
		end)
	end)

	-- Their Offer
	for _, uid in ipairs(session.theirOffer or {}) do
		-- Wir kennen den God nicht aus unserem Inventar; minimaler Render mit "?".
		local c = makeOfferCard(nil, "Locked_" .. uid:sub(1, 4), nil)
		c.Active = false
		c.AutoButtonColor = false
		c.Parent = theirGrid
	end

	-- Hold-Bar unten
	local holdBar = Instance.new("Frame")
	holdBar.BackgroundColor3 = Theme.color.panelLight
	holdBar.BorderSizePixel = 0
	holdBar.AnchorPoint = Vector2.new(0, 1)
	holdBar.Position = UDim2.new(0, 0, 1, 0)
	holdBar.Size = UDim2.new(1, 0, 0, 68)
	holdBar.Parent = body
	Util.corner(holdBar, Theme.radius.md)

	local holdInfo = Instance.new("TextLabel")
	holdInfo.BackgroundTransparency = 1
	holdInfo.Position = UDim2.fromOffset(14, 4)
	holdInfo.Size = UDim2.new(0.5, 0, 0, 18)
	holdInfo.Font = Theme.font.bold
	holdInfo.TextSize = 12
	holdInfo.TextColor3 = Theme.color.textSecondary
	holdInfo.TextXAlignment = Enum.TextXAlignment.Left
	holdInfo.Text = string.format(Locale.t("trade.holdInstruction"), session.holdDuration or 5)
	holdInfo.Parent = holdBar

	local progress = Instance.new("TextLabel")
	progress.BackgroundTransparency = 1
	progress.Position = UDim2.fromOffset(14, 24)
	progress.Size = UDim2.new(0.6, 0, 0, 16)
	progress.Font = Theme.font.body
	progress.TextSize = 12
	progress.TextColor3 = Theme.color.textPrimary
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.Text = ""
	progress.Parent = holdBar

	local holdBtn = Instance.new("TextButton")
	holdBtn.AutoButtonColor = false
	holdBtn.AnchorPoint = Vector2.new(1, 0.5)
	holdBtn.Position = UDim2.new(1, -14, 0.5, 0)
	holdBtn.Size = UDim2.fromOffset(200, 50)
	holdBtn.BackgroundColor3 = Theme.color.success
	holdBtn.BorderSizePixel = 0
	holdBtn.Font = Theme.font.heading
	holdBtn.TextSize = 16
	holdBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
	holdBtn.Text = Locale.t("trade.holdAccept")
	holdBtn.Parent = holdBar
	Util.corner(holdBtn, Theme.radius.md)

	local function setHolding(v: boolean)
		holdBtn.BackgroundColor3 = v and Theme.color.gold or Theme.color.success
		TradeController.setHolding(v)
	end

	holdBtn.MouseButton1Down:Connect(function() setHolding(true) end)
	holdBtn.MouseButton1Up:Connect(function() setHolding(false) end)
	holdBtn.MouseLeave:Connect(function() setHolding(false) end)
	-- Touch
	holdBtn.TouchTap:Connect(function() end)  -- noop; gestures use mouse events

	-- Hold-Progress refreshen
	local conn
	conn = TradeController.HoldChanged:Connect(function(p)
		if not holdBar.Parent then if conn then conn:Disconnect() end; return end
		progress.Text = string.format(
			Locale.t("trade.holdMe") .. "  " .. Locale.t("trade.holdThem"),
			p.mine or 0, p.theirs or 0
		)
	end)
end

-- ─── Picker für Götter (Inventar-Auswahl) ─────────────────────────────────────
function TradePanel.openPicker(screenContainer: Instance, inventory, onPick: (uid: string) -> ())
	-- Dim background
	local existing = screenContainer:FindFirstChild("TradePicker")
	if existing then existing:Destroy() end

	local dim = Instance.new("Frame")
	dim.Name = "TradePicker"
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.Size = UDim2.fromScale(1, 1)
	dim.BorderSizePixel = 0
	dim.ZIndex = 50
	dim.Parent = screenContainer

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(600, 480)
	box.BackgroundColor3 = Theme.color.panel
	box.BorderSizePixel = 0
	box.ZIndex = 51
	box.Parent = dim
	Util.corner(box, Theme.radius.lg)
	Util.stroke(box, Theme.color.accent, 2)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 12)
	title.Size = UDim2.new(1, -100, 0, 28)
	title.Font = Theme.font.heading
	title.TextSize = 16
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t("trade.pickToOffer")
	title.ZIndex = 52
	title.Parent = box

	local closeBtn = Util.button("✕", Theme.color.panelLight)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -10, 0, 10)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.ZIndex = 52
	closeBtn.Parent = box
	closeBtn.Activated:Connect(function() dim:Destroy() end)

	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(20, 50)
	grid.Size = UDim2.new(1, -40, 1, -70)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollBarThickness = 6
	grid.ZIndex = 52
	grid.Parent = box
	Util.gridLayout(grid, UDim2.fromOffset(96, 110), UDim2.fromOffset(8, 8))

	for _, entry in ipairs(inventory.gods) do
		if entry.locked then continue end
		local c = makeOfferCard(entry, entry.id, entry.rarityId, function()
			onPick(entry.uid)
			dim:Destroy()
		end)
		c.ZIndex = 52
		for _, child in ipairs(c:GetDescendants()) do
			if child:IsA("GuiObject") then child.ZIndex = 52 end
		end
		c.Parent = grid
	end
end

-- ─── Entry-Point ──────────────────────────────────────────────────────────────
function TradePanel.create(body: Instance, snapshot)
	if TradeController.session then
		makeSessionView(body, TradeController.session, snapshot)
	else
		makeLobbyView(body)
	end
end

return TradePanel
