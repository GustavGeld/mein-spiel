--!strict
-- AuctionPanel — zwei Tabs: Browse (alle Listings) | My Listings (eigene)
-- Direktkauf (kein Bieten) mit 5% Steuer-Hinweis.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local AuctionPanel = {}
local LocalPlayer = Players.LocalPlayer

local function fmtNum(n: number): string
	if n >= 1e9 then return string.format("%.1fB", n/1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
	elseif n >= 1e3 then return string.format("%.1fk", n/1e3)
	else return tostring(math.floor(n)) end
end

local function fmtTime(secs: number): string
	secs = math.max(0, math.floor(secs))
	if secs >= 3600 then return string.format("%dh %dm", math.floor(secs/3600), math.floor((secs%3600)/60))
	else return string.format("%dm", math.max(1, math.floor(secs/60))) end
end

local function rarityColor(rarityId: string): Color3
	local r = Rarities.byId[rarityId]
	return r and r.color or Theme.color.textSecondary
end

-- ─── Listing Card ─────────────────────────────────────────────────────────────

local function makeListingCard(listing: any, onRefresh: () -> ()): Frame
	local isMine = listing.sellerId == LocalPlayer.UserId
	local rColor = rarityColor(listing.rarityId)

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.color.panelLight
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 72)
	Util.corner(card, Theme.radius.md)

	-- Seltenheits-Akzent
	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = rColor
	accent.BorderSizePixel = 0
	accent.Size = UDim2.fromOffset(6, 72)
	accent.Parent = card
	Util.corner(accent, Theme.radius.sm)

	-- Gott-Name + Rarity
	local godName = Instance.new("TextLabel")
	godName.BackgroundTransparency = 1
	godName.Position = UDim2.fromOffset(18, 8)
	godName.Size = UDim2.new(0.45, 0, 0, 22)
	godName.Font = Theme.font.bold
	godName.TextSize = 16
	godName.TextColor3 = rColor
	godName.TextXAlignment = Enum.TextXAlignment.Left
	godName.Text = listing.godId .. (listing.fusionRank > 0 and (" ✦"..listing.fusionRank) or "") .. (listing.secret and " ⚡" or "")
	godName.Parent = card

	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Position = UDim2.fromOffset(18, 30)
	rarityLbl.Size = UDim2.new(0.45, 0, 0, 18)
	rarityLbl.Font = Theme.font.body
	rarityLbl.TextSize = 12
	rarityLbl.TextColor3 = Theme.color.textSecondary
	rarityLbl.TextXAlignment = Enum.TextXAlignment.Left
	rarityLbl.Text = listing.rarityId .. " · " .. Locale.t("auction.seller") .. ": " .. listing.sellerName
	rarityLbl.Parent = card

	-- Zeit
	local timeLbl = Instance.new("TextLabel")
	timeLbl.BackgroundTransparency = 1
	timeLbl.Position = UDim2.fromOffset(18, 50)
	timeLbl.Size = UDim2.new(0.45, 0, 0, 16)
	timeLbl.Font = Theme.font.body
	timeLbl.TextSize = 11
	timeLbl.TextColor3 = Theme.color.textMuted
	timeLbl.TextXAlignment = Enum.TextXAlignment.Left
	timeLbl.Text = "⏱ " .. fmtTime(listing.expiresAt - os.time())
	timeLbl.Parent = card

	-- Preis
	local priceLbl = Instance.new("TextLabel")
	priceLbl.BackgroundTransparency = 1
	priceLbl.AnchorPoint = Vector2.new(1, 0.5)
	priceLbl.Position = UDim2.new(1, -110, 0.5, 0)
	priceLbl.Size = UDim2.fromOffset(90, 30)
	priceLbl.Font = Theme.font.heading
	priceLbl.TextSize = 16
	priceLbl.TextColor3 = Theme.color.gold
	priceLbl.TextXAlignment = Enum.TextXAlignment.Right
	priceLbl.Text = fmtNum(listing.price) .. " 🪙"
	priceLbl.Parent = card

	-- Button: Kaufen oder Stornieren
	if isMine then
		local cancelBtn = Util.button(Locale.t("auction.cancel"), Theme.color.danger)
		cancelBtn.AnchorPoint = Vector2.new(1, 0.5)
		cancelBtn.Position = UDim2.new(1, -8, 0.5, 0)
		cancelBtn.Size = UDim2.fromOffset(90, 32)
		cancelBtn.TextSize = 13
		cancelBtn.Parent = card
		cancelBtn.Activated:Connect(function()
			cancelBtn.Text = "…"
			cancelBtn.AutoButtonColor = false
			local ok, result = pcall(function()
				return Net:Function("CancelListing"):InvokeServer(listing.id)
			end)
			if ok and result and result.ok then
				onRefresh()
			else
				cancelBtn.Text = Locale.t("auction.cancel")
				cancelBtn.AutoButtonColor = true
			end
		end)
	else
		local buyBtn = Util.button(Locale.t("auction.buyout"), Theme.color.gold)
		buyBtn.AnchorPoint = Vector2.new(1, 0.5)
		buyBtn.Position = UDim2.new(1, -8, 0.5, 0)
		buyBtn.Size = UDim2.fromOffset(90, 32)
		buyBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
		buyBtn.TextSize = 13
		buyBtn.Parent = card
		buyBtn.Activated:Connect(function()
			buyBtn.Text = "…"
			buyBtn.AutoButtonColor = false
			local ok, result = pcall(function()
				return Net:Function("BidAuction"):InvokeServer(listing.id)
			end)
			if ok and result and result.ok then
				onRefresh()
			else
				buyBtn.Text = Locale.t("auction.buyout")
				buyBtn.AutoButtonColor = true
			end
		end)
	end

	return card
end

-- ─── Panel ────────────────────────────────────────────────────────────────────

function AuctionPanel.create(body: Instance, snapshot: any)
	local allListings: { any } = {}
	local showMine = false
	local isLoading = false

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = body

	-- Tab-Bar
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Parent = root

	local browseBtn = Instance.new("TextButton")
	browseBtn.AutoButtonColor = false
	browseBtn.Size = UDim2.new(0.5, -4, 1, 0)
	browseBtn.Font = Theme.font.bold
	browseBtn.TextSize = 15
	browseBtn.Text = Locale.t("auction.browse")
	browseBtn.Parent = tabBar
	Util.corner(browseBtn, Theme.radius.sm)

	local mineBtn = Instance.new("TextButton")
	mineBtn.AutoButtonColor = false
	mineBtn.AnchorPoint = Vector2.new(1, 0)
	mineBtn.Position = UDim2.new(1, 0, 0, 0)
	mineBtn.Size = UDim2.new(0.5, -4, 1, 0)
	mineBtn.Font = Theme.font.body
	mineBtn.TextSize = 15
	mineBtn.Text = Locale.t("auction.myListings")
	mineBtn.Parent = tabBar
	Util.corner(mineBtn, Theme.radius.sm)

	-- List-Panel
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Position = UDim2.fromOffset(0, 44)
	scroller.Size = UDim2.new(1, 0, 1, -86)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = root
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 6)

	-- Sell-Bereich (unten, nur für "Browse"-Tab)
	local sellFrame = Instance.new("Frame")
	sellFrame.BackgroundColor3 = Theme.color.panelLight
	sellFrame.BorderSizePixel = 0
	sellFrame.AnchorPoint = Vector2.new(0, 1)
	sellFrame.Position = UDim2.new(0, 0, 1, 0)
	sellFrame.Size = UDim2.new(1, 0, 0, 40)
	sellFrame.Parent = root
	Util.corner(sellFrame, Theme.radius.md)

	local sellInput = Instance.new("TextBox")
	sellInput.BackgroundColor3 = Theme.color.panel
	sellInput.BorderSizePixel = 0
	sellInput.PlaceholderText = Locale.t("auction.enterUid")
	sellInput.PlaceholderColor3 = Theme.color.textMuted
	sellInput.Font = Theme.font.body
	sellInput.TextSize = 13
	sellInput.TextColor3 = Theme.color.textPrimary
	sellInput.Size = UDim2.new(0.35, -4, 1, -8)
	sellInput.Position = UDim2.fromOffset(4, 4)
	sellInput.Text = ""
	sellInput.Parent = sellFrame
	Util.corner(sellInput, Theme.radius.sm)

	local priceInput = Instance.new("TextBox")
	priceInput.BackgroundColor3 = Theme.color.panel
	priceInput.BorderSizePixel = 0
	priceInput.PlaceholderText = Locale.t("auction.price")
	priceInput.PlaceholderColor3 = Theme.color.textMuted
	priceInput.Font = Theme.font.body
	priceInput.TextSize = 13
	priceInput.TextColor3 = Theme.color.textPrimary
	priceInput.Size = UDim2.new(0.25, -4, 1, -8)
	priceInput.Position = UDim2.new(0.35, 4, 0, 4)
	priceInput.Text = ""
	priceInput.Parent = sellFrame
	Util.corner(priceInput, Theme.radius.sm)

	local listBtn = Util.button(Locale.t("auction.list"), Theme.color.accent)
	listBtn.AnchorPoint = Vector2.new(1, 0.5)
	listBtn.Position = UDim2.new(1, -4, 0.5, 0)
	listBtn.Size = UDim2.fromOffset(90, 32)
	listBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
	listBtn.TextSize = 14
	listBtn.Parent = sellFrame

	-- ── Render ────────────────────────────────────────────────────────────────

	local function updateTabs()
		browseBtn.BackgroundColor3 = not showMine and Theme.color.accent or Theme.color.panelLight
		browseBtn.TextColor3 = not showMine and Color3.fromRGB(20,20,30) or Theme.color.textSecondary
		browseBtn.Font = not showMine and Theme.font.bold or Theme.font.body
		mineBtn.BackgroundColor3 = showMine and Theme.color.accent or Theme.color.panelLight
		mineBtn.TextColor3 = showMine and Color3.fromRGB(20,20,30) or Theme.color.textSecondary
		mineBtn.Font = showMine and Theme.font.bold or Theme.font.body
		sellFrame.Visible = not showMine
	end

	local function refreshListings()
		isLoading = true
		task.spawn(function()
			local ok, result = pcall(function()
				return Net:Function("GetAuctions"):InvokeServer()
			end)
			isLoading = false
			if ok and result then
				allListings = result
			end
			-- Render
			for _, child in ipairs(scroller:GetChildren()) do
				if not child:IsA("UIListLayout") then child:Destroy() end
			end
			local now = os.time()
			local shown = 0
			for _, l in ipairs(allListings) do
				if l.expiresAt > now then
					if not showMine or l.sellerId == LocalPlayer.UserId then
						makeListingCard(l, refreshListings).Parent = scroller
						shown += 1
					end
				end
			end
			if shown == 0 then
				local empty = Instance.new("TextLabel")
				empty.BackgroundTransparency = 1
				empty.Size = UDim2.new(1, 0, 0, 40)
				empty.Font = Theme.font.body
				empty.TextSize = 14
				empty.TextColor3 = Theme.color.textMuted
				empty.TextXAlignment = Enum.TextXAlignment.Center
				empty.Text = showMine and Locale.t("auction.noMyListings") or Locale.t("auction.empty")
				empty.Parent = scroller
			end
		end)
	end

	browseBtn.Activated:Connect(function()
		showMine = false; updateTabs(); refreshListings()
	end)
	mineBtn.Activated:Connect(function()
		showMine = true; updateTabs(); refreshListings()
	end)

	listBtn.Activated:Connect(function()
		local uid = sellInput.Text:match("^%s*(.-)%s*$") or ""
		local price = tonumber(priceInput.Text)
		if uid == "" or not price then return end
		listBtn.Text = "…"; listBtn.AutoButtonColor = false
		local ok, result = pcall(function()
			return Net:Function("ListAuction"):InvokeServer(uid, price)
		end)
		listBtn.Text = Locale.t("auction.list"); listBtn.AutoButtonColor = true
		if ok and result and result.ok then
			sellInput.Text = ""; priceInput.Text = ""
			refreshListings()
		end
	end)

	-- OnAuctionUpdate (Server-Push)
	local evConn = Net:Event("OnAuctionUpdate").OnClientEvent:Connect(function(listings: any)
		if listings then allListings = listings end
		-- Nur neu rendern wenn Panel noch offen
		for _, child in ipairs(scroller:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
		local now = os.time()
		local shown = 0
		for _, l in ipairs(allListings) do
			if l.expiresAt > now then
				if not showMine or l.sellerId == LocalPlayer.UserId then
					makeListingCard(l, refreshListings).Parent = scroller
					shown += 1
				end
			end
		end
		if shown == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.new(1, 0, 0, 40)
			empty.Font = Theme.font.body
			empty.TextSize = 14
			empty.TextColor3 = Theme.color.textMuted
			empty.TextXAlignment = Enum.TextXAlignment.Center
			empty.Text = Locale.t("auction.empty")
			empty.Parent = scroller
		end
	end)

	root.Destroying:Connect(function() evConn:Disconnect() end)

	updateTabs()
	refreshListings()
end

return AuctionPanel
