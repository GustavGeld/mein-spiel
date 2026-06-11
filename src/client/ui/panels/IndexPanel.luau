--!strict
-- IndexPanel — two tabs: Collection Book grid + Rarity Rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Net     = require(Shared.remotes.Net)
local Locale  = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)
local Gods    = require(Shared.config.Gods)
local Auras   = require(Shared.config.Auras)

local Theme   = require(script.Parent.Parent.Theme)
local Util    = require(script.Parent.Parent.Util)
local GodCard = require(script.Parent.Parent.components.GodCard)
local FilterBar = require(script.Parent.Parent.components.FilterBar)

local IndexPanel = {}

local function packTierFor(rarityId: string): number
	local def = Rarities.byId[rarityId]
	return def and def.packTier or 1
end

local function compareByRarity(a, b): boolean
	local ai = (Rarities.byId[a.rarityId] or {}).index or 0
	local bi = (Rarities.byId[b.rarityId] or {}).index or 0
	return ai > bi
end

local function compareByStat(field: string)
	return function(a, b)
		local av = (Gods.byId[a.id] or {})[field] or 0
		local bv = (Gods.byId[b.id] or {})[field] or 0
		return av > bv
	end
end

-- ─── Rewards tab ─────────────────────────────────────────────────────────────

local function buildRewardsTab(container: Frame, snapshot: any)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.Parent = container
	Util.listLayout(scroll, Enum.FillDirection.Vertical, 6)

	-- Loading placeholder
	local loadLbl = Instance.new("TextLabel")
	loadLbl.BackgroundTransparency = 1
	loadLbl.Size = UDim2.new(1, 0, 0, 40)
	loadLbl.Font = Theme.font.body
	loadLbl.TextSize = 14
	loadLbl.TextColor3 = Theme.color.textMuted
	loadLbl.TextXAlignment = Enum.TextXAlignment.Center
	loadLbl.Text = Locale.t("ui.loading")
	loadLbl.Parent = scroll

	task.spawn(function()
		local ok, status = pcall(function()
			return Net:Function("GetCollectionStatus"):InvokeServer()
		end)
		if not ok or not status then
			loadLbl.Text = "Error loading rewards."
			return
		end
		loadLbl:Destroy()

		-- Group rarities by pack tier, sorted ascending
		local tiers: { [number]: { { rarityId: string, data: any } } } = {}
		for rarityId, data in pairs(status) do
			local tier = packTierFor(rarityId)
			if not tiers[tier] then tiers[tier] = {} end
			table.insert(tiers[tier], { rarityId = rarityId, data = data })
		end

		local sortedTiers: { number } = {}
		for tier in pairs(tiers) do table.insert(sortedTiers, tier) end
		table.sort(sortedTiers)

		for _, tier in ipairs(sortedTiers) do
			-- Pack tier header
			local header = Instance.new("TextLabel")
			header.BackgroundColor3 = Theme.color.panelLight
			header.BorderSizePixel = 0
			header.Size = UDim2.new(1, 0, 0, 28)
			header.Font = Theme.font.heading
			header.TextSize = 13
			header.TextColor3 = Theme.color.textMuted
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Text = "  Pack " .. tier
			header.Parent = scroll
			Util.corner(header, Theme.radius.sm)

			-- Sort rarities within tier by status (incomplete first, then complete-unclaimed, then claimed)
			local rows = tiers[tier]
			table.sort(rows, function(a, b)
				local aScore = a.data.claimed and 2 or (a.data.found >= a.data.total and 1 or 0)
				local bScore = b.data.claimed and 2 or (b.data.found >= b.data.total and 1 or 0)
				return aScore < bScore
			end)

			for _, entry in ipairs(rows) do
				local rarityId = entry.rarityId
				local data = entry.data      -- { total, found, claimed }
				local rDef = Rarities.byId[rarityId]
				local rarityColor = rDef and rDef.color or Theme.color.textPrimary
				local gemReward = tier * 10
				local isComplete = data.found >= data.total
				local isClaimed  = data.claimed

				local row = Instance.new("Frame")
				row.BackgroundColor3 = Theme.color.panelLight
				row.BorderSizePixel = 0
				row.Size = UDim2.new(1, 0, 0, 66)
				row.Parent = scroll
				Util.corner(row, Theme.radius.md)

				-- Rarity color stripe
				local stripe = Instance.new("Frame")
				stripe.BackgroundColor3 = rarityColor
				stripe.BorderSizePixel = 0
				stripe.Size = UDim2.fromOffset(4, 66)
				stripe.Parent = row
				Util.corner(stripe, Theme.radius.sm)

				-- Rarity name
				local nameLbl = Instance.new("TextLabel")
				nameLbl.BackgroundTransparency = 1
				nameLbl.AnchorPoint = Vector2.new(0, 0)
				nameLbl.Position = UDim2.fromOffset(12, 6)
				nameLbl.Size = UDim2.new(0.35, -16, 0, 18)
				nameLbl.Font = Theme.font.bold
				nameLbl.TextSize = 14
				nameLbl.TextColor3 = rarityColor
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.Text = Locale.t("rarity." .. string.lower(rarityId):gsub("[%s%-]", "_"))
				nameLbl.Parent = row

				-- Aura unlock label
				local auraDef = Auras[tier]
				if auraDef then
					local auraLbl = Instance.new("TextLabel")
					auraLbl.BackgroundTransparency = 1
					auraLbl.Position = UDim2.fromOffset(12, 26)
					auraLbl.Size = UDim2.new(0.35, -16, 0, 14)
					auraLbl.Font = Theme.font.body
					auraLbl.TextSize = 11
					auraLbl.TextColor3 = auraDef.color
					auraLbl.TextXAlignment = Enum.TextXAlignment.Left
					auraLbl.Text = "✨ " .. Locale.t(auraDef.nameKey)
					auraLbl.Parent = row
				end

				-- Progress bar background
				local barBg = Instance.new("Frame")
				barBg.BackgroundColor3 = Theme.color.stroke
				barBg.BorderSizePixel = 0
				barBg.AnchorPoint = Vector2.new(0, 1)
				barBg.Position = UDim2.new(0, 12, 1, -8)
				barBg.Size = UDim2.new(0.35, -20, 0, 6)
				barBg.Parent = row
				Util.corner(barBg, Theme.radius.sm)

				local barFill = Instance.new("Frame")
				barFill.BackgroundColor3 = isClaimed and Theme.color.textMuted
					or isComplete and Theme.color.success
					or rarityColor
				barFill.BorderSizePixel = 0
				barFill.Size = UDim2.fromScale(math.min(1, data.found / math.max(1, data.total)), 1)
				barFill.Parent = barBg
				Util.corner(barFill, Theme.radius.sm)

				-- Progress text (placed below aura label, above the bar)
				local progLbl = Instance.new("TextLabel")
				progLbl.BackgroundTransparency = 1
				progLbl.AnchorPoint = Vector2.new(0, 0)
				progLbl.Position = UDim2.fromOffset(12, 42)
				progLbl.Size = UDim2.new(0.35, -20, 0, 12)
				progLbl.Font = Theme.font.body
				progLbl.TextSize = 11
				progLbl.TextColor3 = Theme.color.textMuted
				progLbl.TextXAlignment = Enum.TextXAlignment.Left
				progLbl.Text = string.format("%d / %d", data.found, data.total)
				progLbl.Parent = row

				-- Gem reward label
				local gemLbl = Instance.new("TextLabel")
				gemLbl.BackgroundTransparency = 1
				gemLbl.AnchorPoint = Vector2.new(0.5, 0.5)
				gemLbl.Position = UDim2.new(0.6, 0, 0.5, 0)
				gemLbl.Size = UDim2.fromOffset(100, 36)
				gemLbl.Font = Theme.font.bold
				gemLbl.TextSize = 15
				gemLbl.TextColor3 = Color3.fromRGB(100, 220, 255)
				gemLbl.Text = "💎 " .. tostring(gemReward)
				gemLbl.Parent = row

				-- Claim button
				local claimBtn = Instance.new("TextButton")
				claimBtn.AnchorPoint = Vector2.new(1, 0.5)
				claimBtn.Position = UDim2.new(1, -10, 0.5, 0)
				claimBtn.Size = UDim2.fromOffset(90, 32)
				claimBtn.AutoButtonColor = false
				claimBtn.BorderSizePixel = 0
				claimBtn.Font = Theme.font.bold
				claimBtn.TextSize = 13
				claimBtn.Parent = row
				Util.corner(claimBtn, Theme.radius.sm)

				if isClaimed then
					claimBtn.Text = "✓ " .. Locale.t("collection.claimed")
					claimBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 40)
					claimBtn.TextColor3 = Theme.color.success
					claimBtn.Active = false
				elseif not isComplete then
					claimBtn.Text = Locale.t("collection.locked")
					claimBtn.BackgroundColor3 = Theme.color.panel
					claimBtn.TextColor3 = Theme.color.textMuted
					claimBtn.Active = false
				else
					claimBtn.Text = Locale.t("ui.claim")
					claimBtn.BackgroundColor3 = Theme.color.success
					claimBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
					claimBtn.Active = true
					claimBtn.Activated:Connect(function()
						claimBtn.Active = false
						claimBtn.Text = "…"
						local okC, res = pcall(function()
							return Net:Function("ClaimCollectionReward"):InvokeServer(rarityId)
						end)
						if okC and res and res.ok then
							claimBtn.Text = "✓ " .. Locale.t("collection.claimed")
							claimBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 40)
							claimBtn.TextColor3 = Theme.color.success
							barFill.BackgroundColor3 = Theme.color.textMuted
						else
							claimBtn.Text = Locale.t("ui.claim")
							claimBtn.Active = true
						end
					end)
				end
			end
		end
	end)
end

-- ─── Main create ─────────────────────────────────────────────────────────────

function IndexPanel.create(body: Instance, snapshot)
	-- Tab bar
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Parent = body
	Util.listLayout(tabBar, Enum.FillDirection.Horizontal, 6)

	local bookBtn = Instance.new("TextButton")
	bookBtn.AutoButtonColor = false
	bookBtn.Size = UDim2.fromOffset(110, 32)
	bookBtn.BorderSizePixel = 0
	bookBtn.Font = Theme.font.bold
	bookBtn.TextSize = 14
	bookBtn.Parent = tabBar
	Util.corner(bookBtn, Theme.radius.sm)

	local rewardsBtn = Instance.new("TextButton")
	rewardsBtn.AutoButtonColor = false
	rewardsBtn.Size = UDim2.fromOffset(110, 32)
	rewardsBtn.BorderSizePixel = 0
	rewardsBtn.Font = Theme.font.bold
	rewardsBtn.TextSize = 14
	rewardsBtn.Parent = tabBar
	Util.corner(rewardsBtn, Theme.radius.sm)

	-- Book container (filter bar + grid)
	local bookContainer = Instance.new("Frame")
	bookContainer.BackgroundTransparency = 1
	bookContainer.Position = UDim2.fromOffset(0, 44)
	bookContainer.Size = UDim2.new(1, 0, 1, -44)
	bookContainer.Parent = body

	-- Rewards container
	local rewardsContainer = Instance.new("Frame")
	rewardsContainer.BackgroundTransparency = 1
	rewardsContainer.Position = UDim2.fromOffset(0, 44)
	rewardsContainer.Size = UDim2.new(1, 0, 1, -44)
	rewardsContainer.Visible = false
	rewardsContainer.Parent = body

	local activeTab = "book"

	local function setTab(tab: string)
		activeTab = tab
		local isBook = tab == "book"
		bookContainer.Visible = isBook
		rewardsContainer.Visible = not isBook
		bookBtn.BackgroundColor3 = isBook and Theme.color.accent or Theme.color.panelLight
		bookBtn.TextColor3 = isBook and Color3.fromRGB(20, 20, 30) or Theme.color.textPrimary
		rewardsBtn.BackgroundColor3 = (not isBook) and Theme.color.accent or Theme.color.panelLight
		rewardsBtn.TextColor3 = (not isBook) and Color3.fromRGB(20, 20, 30) or Theme.color.textPrimary
	end

	bookBtn.Text = Locale.t("collection.tabBook")
	rewardsBtn.Text = Locale.t("collection.tabRewards")

	bookBtn.Activated:Connect(function() setTab("book") end)
	rewardsBtn.Activated:Connect(function() setTab("rewards") end)

	-- ── Book tab (existing grid logic) ───────────────────────────────────────

	local filterHolder = Instance.new("Frame")
	filterHolder.BackgroundTransparency = 1
	filterHolder.Size = UDim2.new(1, 0, 0, 40)
	filterHolder.Parent = bookContainer

	local statsLabel = Instance.new("TextLabel")
	statsLabel.BackgroundTransparency = 1
	statsLabel.AnchorPoint = Vector2.new(1, 0)
	statsLabel.Position = UDim2.new(1, 0, 0, 0)
	statsLabel.Size = UDim2.fromOffset(170, 30)
	statsLabel.Font = Theme.font.bold
	statsLabel.TextSize = 14
	statsLabel.TextColor3 = Theme.color.textPrimary
	statsLabel.TextXAlignment = Enum.TextXAlignment.Right
	statsLabel.Parent = filterHolder

	local gridHolder = Instance.new("ScrollingFrame")
	gridHolder.BackgroundTransparency = 1
	gridHolder.BorderSizePixel = 0
	gridHolder.Position = UDim2.fromOffset(0, 48)
	gridHolder.Size = UDim2.new(1, 0, 1, -48)
	gridHolder.CanvasSize = UDim2.new()
	gridHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridHolder.ScrollBarThickness = 4
	gridHolder.Parent = bookContainer
	Util.gridLayout(gridHolder, UDim2.fromOffset(160, 220), UDim2.fromOffset(8, 8))

	local discovered = (snapshot.collection or {}).discovered or {}
	local entries = {}
	for _, def in ipairs(Gods.list) do
		table.insert(entries, {
			id = def.id,
			rarityId = def.rarityId,
			packTier = packTierFor(def.rarityId),
			discovered = discovered[def.id] == true,
		})
	end

	local filterState
	local function render()
		gridHolder:ClearAllChildren()
		Util.gridLayout(gridHolder, UDim2.fromOffset(160, 220), UDim2.fromOffset(8, 8))

		local filtered = {}
		local foundCount = 0
		for _, entry in ipairs(entries) do
			if entry.discovered then foundCount += 1 end
			if filterState and filterState.packTier and entry.packTier ~= filterState.packTier then
				continue
			end
			table.insert(filtered, entry)
		end

		if filterState and filterState.sortBy == "gold" then
			table.sort(filtered, compareByStat("baseProduction"))
		elseif filterState and filterState.sortBy == "faith" then
			table.sort(filtered, compareByStat("baseFaith"))
		else
			table.sort(filtered, compareByRarity)
		end

		statsLabel.Text = string.format("%d / %d found", foundCount, #entries)

		for _, entry in ipairs(filtered) do
			GodCard.create(gridHolder, {
				godId = entry.id,
				rarityId = entry.rarityId,
				packTier = entry.packTier,
				discovered = entry.discovered,
			})
		end
	end

	local fb = FilterBar.create(filterHolder, function(state)
		filterState = state
		render()
	end)
	filterState = fb.state
	render()

	-- ── Rewards tab ──────────────────────────────────────────────────────────
	buildRewardsTab(rewardsContainer :: Frame, snapshot)

	setTab("book")
end

return IndexPanel
