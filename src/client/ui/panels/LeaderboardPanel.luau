--!strict
-- LeaderboardPanel — Top-100-Bestenliste mit 5 Kategorien-Tabs und Seitenblättern.
-- Kategorien: Pulls | Rebirths | Lifetime Gold | Rarest God | Season Score

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared.locale.Locale)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)
local LeaderboardController = require(script.Parent.Parent.Parent.controllers.LeaderboardController)

local LeaderboardPanel = {}

local LocalPlayer = Players.LocalPlayer

local CATEGORIES = { "pulls", "rebirths", "gold", "rarity", "season" }

local function fmt(n: number): string
	if n >= 1e9 then return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then return string.format("%.1fk", n / 1e3)
	else return tostring(math.floor(n)) end
end

local function rankColor(rank: number): Color3
	if rank == 1 then return Color3.fromRGB(255, 215, 60)  end
	if rank == 2 then return Color3.fromRGB(200, 200, 220) end
	if rank == 3 then return Color3.fromRGB(205, 127, 50)  end
	return Theme.color.textMuted
end

local function makeTabButton(parent: Instance, text: string, active: boolean, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.Size = UDim2.new(0, 0, 1, 0)
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.BackgroundColor3 = active and Theme.color.accent or Theme.color.panelLight
	btn.BorderSizePixel = 0
	btn.Font = active and Theme.font.bold or Theme.font.body
	btn.TextColor3 = active and Color3.fromRGB(20, 20, 30) or Theme.color.textSecondary
	btn.TextSize = 14
	btn.Text = "  " .. text .. "  "
	btn.Parent = parent
	Util.corner(btn, Theme.radius.sm)
	btn.Activated:Connect(onClick)
	return btn
end

local function makeEntryRow(
	parent: Instance,
	rank: number,
	name: string,
	score: number,
	isSelf: boolean
): Frame
	local row = Instance.new("Frame")
	row.BackgroundColor3 = isSelf and Color3.fromRGB(50, 42, 20) or Theme.color.panelLight
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 38)
	row.Parent = parent
	Util.corner(row, Theme.radius.sm)

	if isSelf then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.color.gold
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = row
	end

	-- Rang-Abzeichen
	local rankLbl = Instance.new("TextLabel")
	rankLbl.BackgroundTransparency = 1
	rankLbl.Position = UDim2.fromOffset(8, 0)
	rankLbl.Size = UDim2.fromOffset(44, 38)
	rankLbl.Font = rank <= 3 and Theme.font.heading or Theme.font.bold
	rankLbl.TextSize = rank <= 3 and 18 or 15
	rankLbl.TextColor3 = rankColor(rank)
	rankLbl.TextXAlignment = Enum.TextXAlignment.Center
	rankLbl.Text = rank == 1 and "🥇" or rank == 2 and "🥈" or rank == 3 and "🥉"
		or ("#" .. rank)
	rankLbl.Parent = row

	-- Spielername
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Position = UDim2.fromOffset(58, 0)
	nameLbl.Size = UDim2.new(1, -160, 1, 0)
	nameLbl.Font = isSelf and Theme.font.bold or Theme.font.body
	nameLbl.TextSize = 15
	nameLbl.TextColor3 = isSelf and Theme.color.gold or Theme.color.textPrimary
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Text = name .. (isSelf and " ← YOU" or "")
	nameLbl.Parent = row

	-- Score rechts
	local scoreLbl = Instance.new("TextLabel")
	scoreLbl.BackgroundTransparency = 1
	scoreLbl.AnchorPoint = Vector2.new(1, 0.5)
	scoreLbl.Position = UDim2.new(1, -12, 0.5, 0)
	scoreLbl.Size = UDim2.fromOffset(90, 30)
	scoreLbl.Font = Theme.font.bold
	scoreLbl.TextSize = 15
	scoreLbl.TextColor3 = isSelf and Theme.color.gold or Theme.color.textSecondary
	scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
	scoreLbl.Text = fmt(score)
	scoreLbl.Parent = row

	return row
end

function LeaderboardPanel.create(body: Instance, _snapshot: any)
	local activeCat  = "pulls"
	local activePage = 1
	local isLoading  = false
	local currentTotalPages = 1

	-- ── Layout ────────────────────────────────────────────────────────────────

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = body

	local vlist = Instance.new("UIListLayout")
	vlist.FillDirection = Enum.FillDirection.Vertical
	vlist.SortOrder = Enum.SortOrder.LayoutOrder
	vlist.Padding = UDim.new(0, 8)
	vlist.Parent = root

	-- Tab-Leiste
	local tabBar = Instance.new("Frame")
	tabBar.LayoutOrder = 1
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, 0, 0, 32)
	tabBar.Parent = root

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding = UDim.new(0, 6)
	tabList.VerticalAlignment = Enum.VerticalAlignment.Center
	tabList.Parent = tabBar

	-- Trennlinie
	local sep = Instance.new("Frame")
	sep.LayoutOrder = 2
	sep.BackgroundColor3 = Theme.color.stroke
	sep.BorderSizePixel = 0
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.Parent = root

	-- Eintrags-Scroller
	local listFrame = Instance.new("Frame")
	listFrame.LayoutOrder = 3
	listFrame.BackgroundTransparency = 1
	listFrame.Size = UDim2.new(1, 0, 1, -88)
	listFrame.ClipsDescendants = true
	listFrame.Parent = root

	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = listFrame
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 4)

	-- Pagination-Leiste
	local pagebar = Instance.new("Frame")
	pagebar.LayoutOrder = 4
	pagebar.BackgroundTransparency = 1
	pagebar.Size = UDim2.new(1, 0, 0, 36)
	pagebar.Parent = root

	local prevBtn = Util.button("◀", Theme.color.panelLight)
	prevBtn.AnchorPoint = Vector2.new(0, 0.5)
	prevBtn.Position = UDim2.new(0.5, -70, 0.5, 0)
	prevBtn.Size = UDim2.fromOffset(50, 28)
	prevBtn.TextSize = 18
	prevBtn.Parent = pagebar

	local pageLbl = Instance.new("TextLabel")
	pageLbl.BackgroundTransparency = 1
	pageLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	pageLbl.Position = UDim2.new(0.5, 0, 0.5, 0)
	pageLbl.Size = UDim2.fromOffset(100, 28)
	pageLbl.Font = Theme.font.body
	pageLbl.TextSize = 14
	pageLbl.TextColor3 = Theme.color.textSecondary
	pageLbl.TextXAlignment = Enum.TextXAlignment.Center
	pageLbl.Text = "1 / 1"
	pageLbl.Parent = pagebar

	local nextBtn = Util.button("▶", Theme.color.panelLight)
	nextBtn.AnchorPoint = Vector2.new(1, 0.5)
	nextBtn.Position = UDim2.new(0.5, 70, 0.5, 0)
	nextBtn.Size = UDim2.fromOffset(50, 28)
	nextBtn.TextSize = 18
	nextBtn.Parent = pagebar

	-- ── Laden / Rendern ───────────────────────────────────────────────────────
	-- WICHTIG: loadPage MUSS vor rebuildTabs definiert sein (Luau upvalue order).

	local function loadPage()
		if isLoading then return end
		isLoading = true

		-- Platzhalter anzeigen
		for _, child in ipairs(scroller:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
		local loading = Instance.new("TextLabel")
		loading.BackgroundTransparency = 1
		loading.Size = UDim2.new(1, 0, 0, 40)
		loading.Font = Theme.font.body
		loading.TextSize = 14
		loading.TextColor3 = Theme.color.textMuted
		loading.TextXAlignment = Enum.TextXAlignment.Center
		loading.Text = Locale.t("leaderboard.loading")
		loading.Parent = scroller

		local capturedCat  = activeCat
		local capturedPage = activePage

		task.spawn(function()
			local result = LeaderboardController.fetchPage(capturedCat, capturedPage)
			isLoading = false

			-- Abbrechen wenn Kategorie/Seite sich zwischenzeitlich geändert hat
			if capturedCat ~= activeCat or capturedPage ~= activePage then return end

			for _, child in ipairs(scroller:GetChildren()) do
				if not child:IsA("UIListLayout") then child:Destroy() end
			end

			if not result or not result.entries then
				local err = Instance.new("TextLabel")
				err.BackgroundTransparency = 1
				err.Size = UDim2.new(1, 0, 0, 40)
				err.Font = Theme.font.body
				err.TextSize = 14
				err.TextColor3 = Theme.color.textMuted
				err.TextXAlignment = Enum.TextXAlignment.Center
				err.Text = Locale.t("leaderboard.noData")
				err.Parent = scroller
				return
			end

			currentTotalPages = math.max(1, result.totalPages or 1)
			pageLbl.Text = string.format(Locale.t("leaderboard.page"), activePage, currentTotalPages)
			prevBtn.BackgroundColor3 = activePage > 1 and Theme.color.accent or Theme.color.panelLight
			nextBtn.BackgroundColor3 = activePage < currentTotalPages and Theme.color.accent or Theme.color.panelLight

			local myUserId = LocalPlayer.UserId
			for _, entry in ipairs(result.entries) do
				makeEntryRow(scroller, entry.rank, entry.name, entry.score, entry.userId == myUserId)
			end

			if #result.entries == 0 then
				local empty = Instance.new("TextLabel")
				empty.BackgroundTransparency = 1
				empty.Size = UDim2.new(1, 0, 0, 40)
				empty.Font = Theme.font.body
				empty.TextSize = 14
				empty.TextColor3 = Theme.color.textMuted
				empty.TextXAlignment = Enum.TextXAlignment.Center
				empty.Text = Locale.t("leaderboard.noData")
				empty.Parent = scroller
			end
		end)
	end

	-- rebuildTabs NACH loadPage definiert → kann loadPage als Upvalue nutzen
	local function rebuildTabs()
		for _, child in ipairs(tabBar:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, cat in ipairs(CATEGORIES) do
			local label = Locale.t("leaderboard.category." .. cat)
			local isActive = cat == activeCat
			local capturedCat = cat
			local btn = makeTabButton(tabBar, label, isActive, function()
				if activeCat == capturedCat or isLoading then return end
				activeCat = capturedCat
				activePage = 1
				rebuildTabs()
				loadPage()
			end)
			btn.LayoutOrder = i
		end
	end

	prevBtn.Activated:Connect(function()
		if activePage <= 1 or isLoading then return end
		activePage -= 1
		loadPage()
	end)
	nextBtn.Activated:Connect(function()
		if activePage >= currentTotalPages or isLoading then return end
		activePage += 1
		loadPage()
	end)

	-- Start
	rebuildTabs()
	loadPage()
end

return LeaderboardPanel
