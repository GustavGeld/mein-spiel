--!strict
-- RebirthPanel — Rebirth-Übersicht + Hold-to-Rebirth + Divinity-Tree.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Odds = require(Shared.math.Odds)
local Rebirth = require(Shared.config.Rebirth)
local DivinityTree = require(Shared.config.DivinityTree)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local RebirthPanel = {}

local HOLD_SECONDS = 3

local function preview(snapshot)
	local rebirths = (snapshot.lifetime and snapshot.lifetime.rebirths) or 0
	local gold = (snapshot.currencies and snapshot.currencies.gold) or 0
	return {
		rebirths     = rebirths,
		gold         = gold,
		threshold    = Rebirth.threshold(rebirths),
		divinityGain = Rebirth.divinityReward(rebirths, gold),
		divinity     = (snapshot.currencies and snapshot.currencies.divinity) or 0,
	}
end

local function makeHeader(parent: Instance, snapshot): { refresh: () -> () }
	local p = preview(snapshot)

	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.color.panelLight
	box.BorderSizePixel = 0
	box.Size = UDim2.new(1, 0, 0, 110)
	box.Parent = parent
	Util.corner(box, Theme.radius.md)
	Util.padding(box, Theme.padding.md)

	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0.55, 0, 1, 0)
	left.Parent = box

	local rebirthsLabel = Instance.new("TextLabel")
	rebirthsLabel.BackgroundTransparency = 1
	rebirthsLabel.Size = UDim2.new(1, 0, 0, 26)
	rebirthsLabel.Font = Theme.font.heading
	rebirthsLabel.TextSize = 22
	rebirthsLabel.TextColor3 = Theme.color.textPrimary
	rebirthsLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthsLabel.Parent = left

	local divinityLabel = Instance.new("TextLabel")
	divinityLabel.BackgroundTransparency = 1
	divinityLabel.Position = UDim2.fromOffset(0, 32)
	divinityLabel.Size = UDim2.new(1, 0, 0, 22)
	divinityLabel.Font = Theme.font.bold
	divinityLabel.TextSize = 16
	divinityLabel.TextColor3 = Theme.color.divinity
	divinityLabel.TextXAlignment = Enum.TextXAlignment.Left
	divinityLabel.Parent = left

	local thresholdLabel = Instance.new("TextLabel")
	thresholdLabel.BackgroundTransparency = 1
	thresholdLabel.Position = UDim2.fromOffset(0, 58)
	thresholdLabel.Size = UDim2.new(1, 0, 0, 20)
	thresholdLabel.Font = Theme.font.body
	thresholdLabel.TextSize = 14
	thresholdLabel.TextColor3 = Theme.color.textSecondary
	thresholdLabel.TextXAlignment = Enum.TextXAlignment.Left
	thresholdLabel.Parent = left

	-- Progress-Bar
	local barWrap = Instance.new("Frame")
	barWrap.BackgroundColor3 = Theme.color.panel
	barWrap.BorderSizePixel = 0
	barWrap.Position = UDim2.fromOffset(0, 80)
	barWrap.Size = UDim2.new(1, 0, 0, 10)
	barWrap.Parent = left
	Util.corner(barWrap, Theme.radius.sm)

	local barFill = Instance.new("Frame")
	barFill.BackgroundColor3 = Theme.color.success
	barFill.BorderSizePixel = 0
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.Parent = barWrap
	Util.corner(barFill, Theme.radius.sm)

	local gainLabel = Instance.new("TextLabel")
	gainLabel.BackgroundTransparency = 1
	gainLabel.AnchorPoint = Vector2.new(1, 0.5)
	gainLabel.Position = UDim2.new(1, 0, 0.5, 0)
	gainLabel.Size = UDim2.fromOffset(180, 60)
	gainLabel.Font = Theme.font.heading
	gainLabel.TextSize = 22
	gainLabel.TextColor3 = Theme.color.divinity
	gainLabel.TextXAlignment = Enum.TextXAlignment.Right
	gainLabel.TextYAlignment = Enum.TextYAlignment.Center
	gainLabel.Parent = box

	local function refresh()
		p = preview(snapshot)
		rebirthsLabel.Text = string.format(Locale.t("rebirth.count"), p.rebirths)
		divinityLabel.Text = string.format(Locale.t("rebirth.divinityNow"), Odds.formatBig(p.divinity))
		if p.gold >= p.threshold then
			thresholdLabel.Text = Locale.t("rebirth.ready")
			thresholdLabel.TextColor3 = Theme.color.success
		else
			thresholdLabel.Text = string.format(Locale.t("rebirth.threshold"), Odds.formatBig(p.threshold))
			thresholdLabel.TextColor3 = Theme.color.textSecondary
		end
		gainLabel.Text = string.format(Locale.t("rebirth.divinityGain"), p.divinityGain)
		local pct = math.clamp(p.gold / math.max(1, p.threshold), 0, 1)
		barFill.Size = UDim2.new(pct, 0, 1, 0)
	end

	refresh()
	return { refresh = refresh }
end

local function makeHoldButton(parent: Instance, snapshot, onRebirth: () -> ()): { refresh: () -> () }
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Theme.color.divinity
	btn.BorderSizePixel = 0
	btn.Size = UDim2.new(1, 0, 0, 56)
	btn.Font = Theme.font.heading
	btn.TextSize = 20
	btn.TextColor3 = Theme.color.textPrimary
	btn.Text = Locale.t("rebirth.holdToRebirth")
	btn.Parent = parent
	Util.corner(btn, Theme.radius.md)

	local progress = Instance.new("Frame")
	progress.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progress.BackgroundTransparency = 0.7
	progress.BorderSizePixel = 0
	progress.Size = UDim2.new(0, 0, 1, 0)
	progress.Parent = btn
	progress.ZIndex = 0
	Util.corner(progress, Theme.radius.md)

	local holding = false
	local heldFor = 0
	local conn: RBXScriptConnection? = nil

	local function setEnabled(enabled: boolean)
		btn.Active = enabled
		btn.BackgroundColor3 = enabled and Theme.color.divinity or Theme.color.locked
		btn.AutoButtonColor = enabled
	end

	local function reset()
		holding = false
		heldFor = 0
		progress.Size = UDim2.new(0, 0, 1, 0)
		if conn then conn:Disconnect(); conn = nil end
	end

	local function refresh()
		local p = preview(snapshot)
		setEnabled(p.gold >= p.threshold)
		if p.gold < p.threshold then
			btn.Text = string.format(Locale.t("rebirth.notReady"), Odds.formatBig(p.threshold - p.gold))
		else
			btn.Text = Locale.t("rebirth.holdToRebirth")
		end
	end

	btn.MouseButton1Down:Connect(function()
		local p = preview(snapshot)
		if p.gold < p.threshold then return end
		holding = true
		heldFor = 0
		conn = RunService.RenderStepped:Connect(function(dt)
			if not holding then return end
			heldFor += dt
			progress.Size = UDim2.new(math.clamp(heldFor / HOLD_SECONDS, 0, 1), 0, 1, 0)
			if heldFor >= HOLD_SECONDS then
				reset()
				onRebirth()
			end
		end)
	end)

	local function cancel()
		if holding then reset(); refresh() end
	end
	btn.MouseButton1Up:Connect(cancel)
	btn.MouseLeave:Connect(cancel)

	refresh()
	return { refresh = refresh }
end

local function makeNodeRow(parent: Instance, branch, nodeDef, snapshot, onRefresh: () -> ()): () -> ()
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Theme.color.panel
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 56)
	row.Parent = parent
	Util.corner(row, Theme.radius.sm)
	Util.padding(row, Theme.padding.sm)

	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = branch.color
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.Parent = row
	Util.corner(accent, Theme.radius.sm)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 0)
	title.Size = UDim2.new(0.55, 0, 0, 22)
	title.Font = Theme.font.bold
	title.TextSize = 15
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(14, 22)
	desc.Size = UDim2.new(0.55, 0, 0, 18)
	desc.Font = Theme.font.body
	desc.TextSize = 12
	desc.TextColor3 = Theme.color.textSecondary
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = row

	local btn = Util.button("", branch.color)
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, 0, 0.5, 0)
	btn.Size = UDim2.fromOffset(150, 36)
	btn.TextSize = 13
	btn.Parent = row

	local function refresh()
		local level = DivinityTree.getLevel(snapshot, branch.id, nodeDef.key)
		title.Text = string.format("%s  •  Lv %d/%d", Locale.t(nodeDef.labelKey), level, nodeDef.maxLevel)
		local totalBonus = math.floor(level * nodeDef.bonusPerLevel * 100 + 0.5)
		desc.Text = string.format(Locale.t(nodeDef.descKey), totalBonus)
		if level >= nodeDef.maxLevel then
			btn.Text = Locale.t("divinity.maxLevel")
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Theme.color.locked
		else
			local price = nodeDef.cost(level)
			local have = (snapshot.currencies and snapshot.currencies.divinity) or 0
			btn.Text = string.format(Locale.t("divinity.upgrade"), price)
			if have >= price then
				btn.AutoButtonColor = true
				btn.BackgroundColor3 = branch.color
			else
				btn.AutoButtonColor = false
				btn.BackgroundColor3 = Theme.color.locked
			end
		end
	end

	btn.Activated:Connect(function()
		btn.Text = "..."
		local result = Net:Function("BuyUpgrade"):InvokeServer(branch.id, nodeDef.key)
		if not result or not result.ok then
			btn.Text = "✖"
			task.delay(0.8, refresh)
		else
			refresh()
			onRefresh()
		end
	end)

	refresh()
	return refresh
end

function RebirthPanel.create(body: Instance, snapshot)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.Parent = body
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 10)

	local header = makeHeader(scroller, snapshot)
	local rowRefreshers: { () -> () } = {}
	local hold

	local function refreshAll()
		header.refresh()
		if hold then hold.refresh() end
		for _, f in ipairs(rowRefreshers) do f() end
	end

	hold = makeHoldButton(scroller, snapshot, function()
		local result = Net:Function("RebirthConfirm"):InvokeServer()
		if result and result.ok then
			refreshAll()
		end
	end)

	-- Tree-Header
	local treeTitle = Instance.new("TextLabel")
	treeTitle.BackgroundTransparency = 1
	treeTitle.Size = UDim2.new(1, 0, 0, 28)
	treeTitle.Font = Theme.font.heading
	treeTitle.TextSize = 20
	treeTitle.TextColor3 = Theme.color.textPrimary
	treeTitle.TextXAlignment = Enum.TextXAlignment.Left
	treeTitle.Text = Locale.t("rebirth.tree")
	treeTitle.Parent = scroller

	for _, branch in ipairs(DivinityTree.branches) do
		for _, nodeDef in ipairs(branch.nodes) do
			local r = makeNodeRow(scroller, branch, nodeDef, snapshot, refreshAll)
			table.insert(rowRefreshers, r)
		end
	end

	return { refresh = refreshAll }
end

return RebirthPanel
