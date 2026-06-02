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

function QuestsPanel.create(body: Instance, snapshot)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = body
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 8)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Font = Theme.font.heading
	title.TextSize = 18
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t("quest.daily")
	title.Parent = scroller

	local quests = (snapshot.quests and snapshot.quests.daily) or {}
	local refreshers: { () -> () } = {}

	-- Sortiert nach: zuerst nicht-eingelöste & abgeschlossene, dann offene, dann eingelöste.
	local ids = {}
	for id in pairs(quests) do table.insert(ids, id) end
	table.sort(ids, function(a, b)
		local sa = quests[a]
		local sb = quests[b]
		local pa = sa.claimed and 2 or (sa.progress >= (Quests.byId[a] and Quests.byId[a].target or math.huge) and 0 or 1)
		local pb = sb.claimed and 2 or (sb.progress >= (Quests.byId[b] and Quests.byId[b].target or math.huge) and 0 or 1)
		return pa < pb
	end)

	for _, id in ipairs(ids) do
		local r = makeQuestRow(scroller, id, quests[id], function()
			-- Nach Claim Liste neu sortieren wäre möglich; wir refreshen einfach alle.
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
		empty.Text = "No quests today — check back tomorrow."
		empty.Parent = scroller
	end
end

return QuestsPanel
