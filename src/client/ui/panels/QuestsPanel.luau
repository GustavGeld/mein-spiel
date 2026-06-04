--!strict
-- QuestsPanel — Daily Quests mit Progress-Bar und Claim-Button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Quests = require(Shared.config.Quests)
local Odds = require(Shared.math.Odds)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local QuestsPanel = {}

local function rewardLabel(reward): string
	local sym = reward.currency == "gold" and "$"
		or reward.currency == "gems" and "💎"
		or reward.currency == "faith" and "✨" or "?"
	return string.format("%s %s", sym, Odds.formatBig(reward.amount))
end

local function rewardColor(reward): Color3
	if reward.currency == "gold" then return Theme.color.money
	elseif reward.currency == "gems" then return Theme.color.gems
	elseif reward.currency == "faith" then return Theme.color.faith
	else return Theme.color.textPrimary end
end

local function makeQuestRow(parent: Instance, questId: string, state, onClaim: () -> ()): () -> ()
	local def = Quests.byId[questId]
	if not def then
		-- Unbekannter Quest-Eintrag (z.B. veralteter Pool) → still ignorieren.
		return function() end
	end

	local row = Instance.new("Frame")
	row.BackgroundColor3 = Theme.color.panelLight
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 86)
	row.Parent = parent
	Util.corner(row, Theme.radius.md)
	Util.padding(row, Theme.padding.md)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(0.6, 0, 0, 22)
	title.Font = Theme.font.heading
	title.TextSize = 16
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t(def.nameKey)
	title.Parent = row

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(0, 22)
	desc.Size = UDim2.new(0.6, 0, 0, 20)
	desc.Font = Theme.font.body
	desc.TextSize = 12
	desc.TextColor3 = Theme.color.textSecondary
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Text = Locale.t(def.descKey)
	desc.Parent = row

	-- Progress-Bar
	local barWrap = Instance.new("Frame")
	barWrap.BackgroundColor3 = Theme.color.panel
	barWrap.BorderSizePixel = 0
	barWrap.Position = UDim2.fromOffset(0, 48)
	barWrap.Size = UDim2.new(0.6, 0, 0, 10)
	barWrap.Parent = row
	Util.corner(barWrap, Theme.radius.sm)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.color.success
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = barWrap
	Util.corner(fill, Theme.radius.sm)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.BackgroundTransparency = 1
	progressLabel.Position = UDim2.fromOffset(0, 60)
	progressLabel.Size = UDim2.new(0.6, 0, 0, 14)
	progressLabel.Font = Theme.font.body
	progressLabel.TextSize = 11
	progressLabel.TextColor3 = Theme.color.textMuted
	progressLabel.TextXAlignment = Enum.TextXAlignment.Left
	progressLabel.Parent = row

	-- Reward + Claim-Button rechts
	local rewardBox = Instance.new("Frame")
	rewardBox.BackgroundTransparency = 1
	rewardBox.AnchorPoint = Vector2.new(1, 0.5)
	rewardBox.Position = UDim2.new(1, 0, 0.5, 0)
	rewardBox.Size = UDim2.fromOffset(180, 60)
	rewardBox.Parent = row

	local rewardLbl = Instance.new("TextLabel")
	rewardLbl.BackgroundTransparency = 1
	rewardLbl.Size = UDim2.new(1, 0, 0, 22)
	rewardLbl.Font = Theme.font.heading
	rewardLbl.TextSize = 18
	rewardLbl.TextColor3 = rewardColor(def.reward)
	rewardLbl.TextXAlignment = Enum.TextXAlignment.Right
	rewardLbl.Text = rewardLabel(def.reward)
	rewardLbl.Parent = rewardBox

	local btn = Util.button(Locale.t("quest.claim"), Theme.color.success)
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, 0, 0, 26)
	btn.Size = UDim2.fromOffset(150, 32)
	btn.Parent = rewardBox

	local function refresh()
		local pct = math.clamp(state.progress / def.target, 0, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		progressLabel.Text = string.format(Locale.t("quest.progress"), math.min(state.progress, def.target), def.target)
		if state.claimed then
			btn.Text = Locale.t("quest.claimed")
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Theme.color.locked
		elseif state.progress >= def.target then
			btn.Text = Locale.t("quest.claim")
			btn.AutoButtonColor = true
			btn.BackgroundColor3 = Theme.color.success
		else
			btn.Text = Locale.t("quest.progress"):format(state.progress, def.target)
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Theme.color.panel
		end
	end

	btn.Activated:Connect(function()
		if state.claimed or state.progress < def.target then return end
		btn.Text = "..."
		local result = Net:Function("ClaimQuest"):InvokeServer(questId)
		if result and result.ok then
			state.claimed = true
			onClaim()
		end
		refresh()
	end)

	refresh()
	return refresh
end

local function buildQuestList(body: Instance, questTable: { [string]: any }, emptyMsg: string)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = body
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 8)

	local refreshers: { () -> () } = {}
	local ids = {}
	for id in pairs(questTable) do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local sa = questTable[a]; local sb = questTable[b]
		local pa = sa.claimed and 2 or (sa.progress >= (Quests.byId[a] and Quests.byId[a].target or math.huge) and 0 or 1)
		local pb = sb.claimed and 2 or (sb.progress >= (Quests.byId[b] and Quests.byId[b].target or math.huge) and 0 or 1)
		return pa < pb
	end)
	for _, id in ipairs(ids) do
		local r = makeQuestRow(scroller, id, questTable[id], function()
			for _, f in ipairs(refreshers) do f() end
		end)
		table.insert(refreshers, r)
	end
	if #ids == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.Font = Theme.font.body
		empty.TextSize = 14
		empty.TextColor3 = Theme.color.textMuted
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.Text = emptyMsg
		empty.Parent = scroller
	end
end

function QuestsPanel.create(body: Instance, snapshot)
	local activeTab = "daily"

	-- Tab-Bar
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, 0, 0, 32)
	tabBar.Parent = body
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding = UDim.new(0, 6)
	tabList.Parent = tabBar

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, 40)
	content.Size = UDim2.new(1, 0, 1, -40)
	content.Parent = body

	local function switchTab(id: string)
		activeTab = id
		for _, child in ipairs(tabBar:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for i, tab in ipairs({ "daily", "weekly" }) do
			local label = Locale.t("quest." .. tab)
			local isActive = tab == id
			local btn = Instance.new("TextButton")
			btn.AutoButtonColor = false
			btn.LayoutOrder = i
			btn.Size = UDim2.new(0, 110, 1, 0)
			btn.BackgroundColor3 = isActive and Theme.color.accent or Theme.color.panelLight
			btn.BorderSizePixel = 0
			btn.Font = isActive and Theme.font.bold or Theme.font.body
			btn.TextColor3 = isActive and Color3.fromRGB(20,20,30) or Theme.color.textSecondary
			btn.TextSize = 14
			btn.Text = label
			btn.Parent = tabBar
			Util.corner(btn, Theme.radius.sm)
			local capturedTab = tab
			btn.Activated:Connect(function()
				if activeTab ~= capturedTab then switchTab(capturedTab) end
			end)
		end
		for _, child in ipairs(content:GetChildren()) do child:Destroy() end
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.fromScale(1, 1)
		inner.Parent = content
		if id == "daily" then
			local q = (snapshot.quests and snapshot.quests.daily) or {}
			buildQuestList(inner, q, "No quests today — check back tomorrow.")
		else
			local q = (snapshot.quests and snapshot.quests.weekly) or {}
			buildQuestList(inner, q, Locale.t("quest.weeklyEmpty"))
		end
	end

	switchTab("daily")
end

return QuestsPanel
