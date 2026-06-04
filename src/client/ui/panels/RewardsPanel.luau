--!strict
-- RewardsPanel — drei Tabs: Codes | Potions | Achievements
-- Ersetzt den StubPanel für den "rewards"-NavBar-Slot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Potions = require(Shared.config.Potions)
local Achievements = require(Shared.config.Achievements)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local RewardsPanel = {}

-- ─── Helper ──────────────────────────────────────────────────────────────────

local function fmtTime(secs: number): string
	secs = math.max(0, math.floor(secs))
	if secs >= 3600 then return string.format("%dh %dm", math.floor(secs/3600), math.floor((secs%3600)/60))
	elseif secs >= 60 then return string.format("%dm %ds", math.floor(secs/60), secs%60)
	else return string.format("%ds", secs) end
end

local function fmtNum(n: number): string
	if n >= 1e9 then return string.format("%.1fB", n/1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
	elseif n >= 1e3 then return string.format("%.1fk", n/1e3)
	else return tostring(math.floor(n)) end
end

local function makeTabBtn(parent: Instance, text: string, active: boolean, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.Size = UDim2.new(1/3, -4, 1, 0)
	btn.BackgroundColor3 = active and Theme.color.accent or Theme.color.panelLight
	btn.BorderSizePixel = 0
	btn.Font = active and Theme.font.bold or Theme.font.body
	btn.TextColor3 = active and Color3.fromRGB(20,20,30) or Theme.color.textSecondary
	btn.TextSize = 15
	btn.Text = text
	btn.Parent = parent
	Util.corner(btn, Theme.radius.sm)
	btn.Activated:Connect(onClick)
	return btn
end

-- ─── Tab: Codes ──────────────────────────────────────────────────────────────

local function buildCodesTab(container: Instance)
	Util.padding(container, 16)
	local vlist = Instance.new("UIListLayout")
	vlist.FillDirection = Enum.FillDirection.Vertical
	vlist.SortOrder = Enum.SortOrder.LayoutOrder
	vlist.Padding = UDim.new(0, 12)
	vlist.Parent = container

	local header = Instance.new("TextLabel")
	header.LayoutOrder = 1
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 28)
	header.Font = Theme.font.heading
	header.TextSize = 18
	header.TextColor3 = Theme.color.textPrimary
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = Locale.t("rewards.codes.title")
	header.Parent = container

	local desc = Instance.new("TextLabel")
	desc.LayoutOrder = 2
	desc.BackgroundTransparency = 1
	desc.Size = UDim2.new(1, 0, 0, 20)
	desc.Font = Theme.font.body
	desc.TextSize = 13
	desc.TextColor3 = Theme.color.textSecondary
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Text = Locale.t("rewards.codes.desc")
	desc.Parent = container

	-- Input + Button Row
	local row = Instance.new("Frame")
	row.LayoutOrder = 3
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	row.Parent = container

	local input = Instance.new("TextBox")
	input.BackgroundColor3 = Theme.color.panel
	input.BorderSizePixel = 0
	input.PlaceholderText = Locale.t("rewards.codes.placeholder")
	input.PlaceholderColor3 = Theme.color.textMuted
	input.Font = Theme.font.body
	input.TextSize = 15
	input.TextColor3 = Theme.color.textPrimary
	input.ClearTextOnFocus = false
	input.Size = UDim2.new(1, -110, 1, 0)
	input.Text = ""
	input.Parent = row
	Util.corner(input, Theme.radius.md)

	local redeemBtn = Util.button(Locale.t("rewards.codes.redeem"), Theme.color.accent)
	redeemBtn.AnchorPoint = Vector2.new(1, 0)
	redeemBtn.Position = UDim2.new(1, 0, 0, 0)
	redeemBtn.Size = UDim2.fromOffset(100, 44)
	redeemBtn.TextSize = 14
	redeemBtn.Parent = row

	local feedback = Instance.new("TextLabel")
	feedback.LayoutOrder = 4
	feedback.BackgroundTransparency = 1
	feedback.Size = UDim2.new(1, 0, 0, 24)
	feedback.Font = Theme.font.bold
	feedback.TextSize = 14
	feedback.TextXAlignment = Enum.TextXAlignment.Left
	feedback.Text = ""
	feedback.Parent = container

	redeemBtn.Activated:Connect(function()
		local code = input.Text:upper():match("^%s*(.-)%s*$") or ""
		if code == "" then return end
		redeemBtn.Text = "…"
		redeemBtn.AutoButtonColor = false

		local ok, result = pcall(function()
			return Net:Function("RedeemCode"):InvokeServer(code)
		end)

		redeemBtn.Text = Locale.t("rewards.codes.redeem")
		redeemBtn.AutoButtonColor = true

		if ok and result then
			if result.ok then
				local rw = result.reward or {}
				local parts = {}
				if rw.gems  and rw.gems  > 0 then table.insert(parts, rw.gems  .. " 💎") end
				if rw.gold  and rw.gold  > 0 then table.insert(parts, fmtNum(rw.gold) .. " Gold") end
				if rw.faith and rw.faith > 0 then table.insert(parts, fmtNum(rw.faith) .. " Faith") end
				feedback.TextColor3 = Theme.color.success
				feedback.Text = "✓ " .. table.concat(parts, " · ")
				input.Text = ""
			elseif result.reason == "already_redeemed" then
				feedback.TextColor3 = Theme.color.textMuted
				feedback.Text = Locale.t("rewards.codes.alreadyRedeemed")
			elseif result.reason == "invalid_code" then
				feedback.TextColor3 = Theme.color.danger
				feedback.Text = Locale.t("rewards.codes.invalid")
			else
				feedback.TextColor3 = Theme.color.danger
				feedback.Text = Locale.t("rewards.codes.error")
			end
		else
			feedback.TextColor3 = Theme.color.danger
			feedback.Text = Locale.t("rewards.codes.error")
		end
	end)
end

-- ─── Tab: Potions ─────────────────────────────────────────────────────────────

local function buildPotionsTab(container: Instance, snapshot: any)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = container
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 8)
	Util.padding(scroller, 8)

	-- Aktive Potions (vom Server-Event befüllt)
	local activeData: { [string]: number } = {}
	-- Initial: leer (Server sendet OnPotionUpdate nach Login)

	local timerLabels: { [string]: TextLabel } = {}

	-- Potion-Karten
	for _, def in ipairs(Potions.list) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Theme.color.panelLight
		card.BorderSizePixel = 0
		card.Size = UDim2.new(1, 0, 0, 68)
		card.Parent = scroller
		Util.corner(card, Theme.radius.md)

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = def.color
		accent.BorderSizePixel = 0
		accent.Size = UDim2.fromOffset(6, 68)
		accent.Parent = card
		Util.corner(accent, Theme.radius.sm)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(18, 8)
		name.Size = UDim2.new(0.55, 0, 0, 22)
		name.Font = Theme.font.bold
		name.TextSize = 16
		name.TextColor3 = def.color
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = Locale.t(def.nameKey)
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.BackgroundTransparency = 1
		desc.Position = UDim2.fromOffset(18, 30)
		desc.Size = UDim2.new(0.55, 0, 0, 28)
		desc.Font = Theme.font.body
		desc.TextSize = 12
		desc.TextColor3 = Theme.color.textSecondary
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextWrapped = true
		desc.Text = Locale.t(def.descKey)
		desc.Parent = card

		local timerLbl = Instance.new("TextLabel")
		timerLbl.BackgroundTransparency = 1
		timerLbl.AnchorPoint = Vector2.new(1, 0)
		timerLbl.Position = UDim2.new(1, -110, 0, 8)
		timerLbl.Size = UDim2.fromOffset(80, 20)
		timerLbl.Font = Theme.font.bold
		timerLbl.TextSize = 13
		timerLbl.TextColor3 = Theme.color.success
		timerLbl.TextXAlignment = Enum.TextXAlignment.Right
		timerLbl.Text = ""
		timerLbl.Parent = card
		timerLabels[def.id] = timerLbl

		local buyBtn = Util.button(string.format("💎 %d", def.gemsCost), def.color)
		buyBtn.AnchorPoint = Vector2.new(1, 0.5)
		buyBtn.Position = UDim2.new(1, -10, 0.5, 0)
		buyBtn.Size = UDim2.fromOffset(90, 36)
		buyBtn.TextColor3 = Color3.fromRGB(20, 20, 30)
		buyBtn.TextSize = 14
		buyBtn.Parent = card

		local capturedId = def.id
		buyBtn.Activated:Connect(function()
			buyBtn.Text = "…"
			buyBtn.AutoButtonColor = false
			local ok, result = pcall(function()
				return Net:Function("BuyPotion"):InvokeServer(capturedId)
			end)
			task.delay(1, function()
				if buyBtn and buyBtn.Parent then
					buyBtn.Text = string.format("💎 %d", def.gemsCost)
					buyBtn.AutoButtonColor = true
				end
			end)
			if not ok or not (result and result.ok) then
				-- Fehlermeldung kurz anzeigen
				if buyBtn and buyBtn.Parent then
					buyBtn.Text = "✗"
				end
			end
		end)
	end

	-- Live-Timer Update
	local conn = game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.time()
		for id, expires in pairs(activeData) do
			local lbl = timerLabels[id]
			if lbl and lbl.Parent then
				local rem = expires - now
				if rem > 0 then
					lbl.Text = "⏱ " .. fmtTime(rem)
				else
					lbl.Text = ""
					activeData[id] = nil
				end
			end
		end
	end)

	-- OnPotionUpdate vom Server empfangen
	local evConn = Net:Event("OnPotionUpdate").OnClientEvent:Connect(function(snap: any)
		table.clear(activeData)
		if snap then
			for id, expires in pairs(snap) do
				activeData[id] = expires
			end
		end
	end)

	container.Destroying:Connect(function()
		conn:Disconnect()
		evConn:Disconnect()
	end)
end

-- ─── Tab: Achievements ────────────────────────────────────────────────────────

local function buildAchievementsTab(container: Instance)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = container
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 6)
	Util.padding(scroller, 8)

	-- Speichert progress-State pro Achievement-ID → Refresh-Funktion
	local refreshers: { [string]: (snap: any) -> () } = {}
	local cardMap: { [string]: Frame } = {}

	for _, def in ipairs(Achievements.list) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Theme.color.panelLight
		card.BorderSizePixel = 0
		card.Size = UDim2.new(1, 0, 0, 64)
		card.Parent = scroller
		Util.corner(card, Theme.radius.md)
		cardMap[def.id] = card

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(12, 6)
		name.Size = UDim2.new(0.55, 0, 0, 22)
		name.Font = Theme.font.bold
		name.TextSize = 14
		name.TextColor3 = Theme.color.textPrimary
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = Locale.t(def.nameKey)
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.BackgroundTransparency = 1
		desc.Position = UDim2.fromOffset(12, 28)
		desc.Size = UDim2.new(0.55, 0, 0, 28)
		desc.Font = Theme.font.body
		desc.TextSize = 11
		desc.TextColor3 = Theme.color.textSecondary
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextWrapped = true
		desc.Text = Locale.t(def.descKey)
		desc.Parent = card

		-- Progress-Bar
		local barBg = Instance.new("Frame")
		barBg.BackgroundColor3 = Theme.color.panel
		barBg.BorderSizePixel = 0
		barBg.Position = UDim2.new(0, 12, 0, 48)
		barBg.Size = UDim2.new(0.55, -12, 0, 6)
		barBg.Parent = card
		Util.corner(barBg, Theme.radius.sm)

		local barFill = Instance.new("Frame")
		barFill.BackgroundColor3 = Theme.color.accent
		barFill.BorderSizePixel = 0
		barFill.Size = UDim2.new(0, 0, 1, 0)
		barFill.Parent = barBg
		Util.corner(barFill, Theme.radius.sm)

		-- Reward + Claim
		local gemLbl = Instance.new("TextLabel")
		gemLbl.BackgroundTransparency = 1
		gemLbl.AnchorPoint = Vector2.new(1, 0)
		gemLbl.Position = UDim2.new(1, -110, 0, 8)
		gemLbl.Size = UDim2.fromOffset(80, 22)
		gemLbl.Font = Theme.font.heading
		gemLbl.TextSize = 15
		gemLbl.TextColor3 = Theme.color.gems
		gemLbl.TextXAlignment = Enum.TextXAlignment.Right
		gemLbl.Text = string.format("💎 %d", def.gems)
		gemLbl.Parent = card

		local claimBtn = Util.button(Locale.t("quest.claim"), Theme.color.success)
		claimBtn.AnchorPoint = Vector2.new(1, 1)
		claimBtn.Position = UDim2.new(1, -10, 1, -6)
		claimBtn.Size = UDim2.fromOffset(90, 28)
		claimBtn.TextSize = 13
		claimBtn.Visible = false
		claimBtn.Parent = card

		local capturedId = def.id
		local capturedTarget = def.target
		claimBtn.Activated:Connect(function()
			claimBtn.Text = "…"
			claimBtn.AutoButtonColor = false
			local ok, result = pcall(function()
				return Net:Function("ClaimAchievement"):InvokeServer(capturedId)
			end)
			if ok and result and result.ok then
				claimBtn.Text = Locale.t("quest.claimed")
				claimBtn.BackgroundColor3 = Theme.color.locked
				card.BackgroundColor3 = Color3.fromRGB(28, 40, 28)
			else
				claimBtn.Text = Locale.t("quest.claim")
				claimBtn.AutoButtonColor = true
			end
		end)

		refreshers[def.id] = function(snap: any)
			local info = snap and snap[capturedId]
			if not info then return end
			local pct = math.clamp(info.progress / capturedTarget, 0, 1)
			barFill.Size = UDim2.new(pct, 0, 1, 0)
			if info.claimed then
				claimBtn.Visible = false
				claimBtn.Text = Locale.t("quest.claimed")
				card.BackgroundColor3 = Color3.fromRGB(28, 40, 28)
				local stroke = Instance.new("UIStroke")
				stroke.Color = Theme.color.success
				stroke.Thickness = 1
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = card
			elseif info.progress >= capturedTarget then
				claimBtn.Visible = true
				claimBtn.AutoButtonColor = true
				claimBtn.BackgroundColor3 = Theme.color.success
				claimBtn.Text = Locale.t("quest.claim")
			else
				claimBtn.Visible = false
			end
		end
	end

	-- OnAchievementUpdate empfangen
	local evConn = Net:Event("OnAchievementUpdate").OnClientEvent:Connect(function(snap: any)
		for id, refresh in pairs(refreshers) do
			if snap then refresh(snap) end
		end
	end)

	-- Initial anfragen
	task.spawn(function()
		-- Warte auf erstes Update (kommt automatisch nach Login)
	end)

	container.Destroying:Connect(function()
		evConn:Disconnect()
	end)
end

-- ─── Panel Builder ────────────────────────────────────────────────────────────

function RewardsPanel.create(body: Instance, snapshot: any)
	local TABS = {
		{ id = "codes",        label = Locale.t("rewards.tab.codes") },
		{ id = "potions",      label = Locale.t("rewards.tab.potions") },
		{ id = "achievements", label = Locale.t("rewards.tab.achievements") },
	}
	local activeTab = "codes"

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = body

	-- Tab-Bar
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Parent = root
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding = UDim.new(0, 6)
	tabList.Parent = tabBar

	-- Content-Frame
	local contentFrame = Instance.new("Frame")
	contentFrame.BackgroundTransparency = 1
	contentFrame.Position = UDim2.fromOffset(0, 44)
	contentFrame.Size = UDim2.new(1, 0, 1, -44)
	contentFrame.Parent = root

	local function switchTab(id: string)
		activeTab = id
		-- Tab-Buttons rebuilden
		for _, child in ipairs(tabBar:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, tab in ipairs(TABS) do
			local btn = makeTabBtn(tabBar, tab.label, tab.id == id, function()
				if activeTab == tab.id then return end
				switchTab(tab.id)
			end)
			btn.LayoutOrder = i
		end
		-- Content neu bauen
		for _, child in ipairs(contentFrame:GetChildren()) do child:Destroy() end
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.fromScale(1, 1)
		inner.Parent = contentFrame
		if id == "codes" then
			buildCodesTab(inner)
		elseif id == "potions" then
			buildPotionsTab(inner, snapshot)
		elseif id == "achievements" then
			buildAchievementsTab(inner)
		end
	end

	switchTab("codes")
end

return RewardsPanel
