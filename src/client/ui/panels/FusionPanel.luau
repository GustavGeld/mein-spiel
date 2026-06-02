--!strict
-- FusionPanel — wähle einen Gott aus dem Inventar, der ≥2 Kopien hat.
-- Setze 2..5 Kopien ein, zeige die Erfolgschance, klicke „Fuse".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Fusion = require(Shared.math.Fusion)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local FusionPanel = {}

local function displayName(id: string): string
	return (string.gsub(id, "_", " "))
end

-- Liefert godId → liste von UIDs (nicht-locked, nicht-platzierte).
local function groupedCopies(snapshot)
	local placed: { [string]: boolean } = {}
	if snapshot.temple and snapshot.temple.slots then
		for _, slot in ipairs(snapshot.temple.slots) do
			if slot.godUid then placed[slot.godUid] = true end
		end
	end

	local groups: { [string]: { any } } = {}
	for _, entry in ipairs(snapshot.inventory.gods) do
		if not entry.locked and not placed[entry.uid] then
			groups[entry.id] = groups[entry.id] or {}
			table.insert(groups[entry.id], entry)
		end
	end
	return groups
end

function FusionPanel.create(body: Instance, snapshot)
	local groups = groupedCopies(snapshot)

	-- Sortierte Liste der gruppen mit ≥2 Kopien
	local eligible: { { godId: string, entries: { any } } } = {}
	for godId, entries in pairs(groups) do
		if #entries >= 2 then
			table.insert(eligible, { godId = godId, entries = entries })
		end
	end
	table.sort(eligible, function(a, b)
		return #a.entries > #b.entries
	end)

	if #eligible == 0 then
		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.AnchorPoint = Vector2.new(0.5, 0.5)
		empty.Position = UDim2.fromScale(0.5, 0.5)
		empty.Size = UDim2.new(0.8, 0, 0, 60)
		empty.Font = Theme.font.body
		empty.TextSize = 16
		empty.TextColor3 = Theme.color.textMuted
		empty.TextWrapped = true
		empty.Text = Locale.t("fusion.pickGod")
		empty.Parent = body
		return
	end

	-- Linke Spalte: Liste, rechte Spalte: Detail/Fuse
	local left = Instance.new("ScrollingFrame")
	left.BackgroundTransparency = 1
	left.BorderSizePixel = 0
	left.Size = UDim2.new(0.4, -8, 1, 0)
	left.CanvasSize = UDim2.new()
	left.AutomaticCanvasSize = Enum.AutomaticSize.Y
	left.ScrollBarThickness = 4
	left.Parent = body
	Util.listLayout(left, Enum.FillDirection.Vertical, 6)

	local right = Instance.new("Frame")
	right.BackgroundColor3 = Theme.color.panelLight
	right.BorderSizePixel = 0
	right.Position = UDim2.new(0.4, 8, 0, 0)
	right.Size = UDim2.new(0.6, -8, 1, 0)
	right.Parent = body
	Util.corner(right, Theme.radius.md)
	Util.padding(right, Theme.padding.md)

	local selectedGroup = eligible[1]
	local selectedCount = 2

	-- Detail-View
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.new(1, 0, 0, 28)
	nameLbl.Font = Theme.font.heading
	nameLbl.TextSize = 20
	nameLbl.TextColor3 = Theme.color.textPrimary
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = right

	local rarityLbl = Instance.new("TextLabel")
	rarityLbl.BackgroundTransparency = 1
	rarityLbl.Position = UDim2.fromOffset(0, 30)
	rarityLbl.Size = UDim2.new(1, 0, 0, 20)
	rarityLbl.Font = Theme.font.bold
	rarityLbl.TextSize = 14
	rarityLbl.TextXAlignment = Enum.TextXAlignment.Left
	rarityLbl.Parent = right

	local countLbl = Instance.new("TextLabel")
	countLbl.BackgroundTransparency = 1
	countLbl.Position = UDim2.fromOffset(0, 54)
	countLbl.Size = UDim2.new(1, 0, 0, 18)
	countLbl.Font = Theme.font.body
	countLbl.TextSize = 13
	countLbl.TextColor3 = Theme.color.textSecondary
	countLbl.TextXAlignment = Enum.TextXAlignment.Left
	countLbl.Parent = right

	-- Counter
	local counterBox = Instance.new("Frame")
	counterBox.BackgroundTransparency = 1
	counterBox.Position = UDim2.fromOffset(0, 90)
	counterBox.Size = UDim2.new(1, 0, 0, 56)
	counterBox.Parent = right

	local selectedLbl = Instance.new("TextLabel")
	selectedLbl.BackgroundTransparency = 1
	selectedLbl.Size = UDim2.new(0.6, 0, 1, 0)
	selectedLbl.Font = Theme.font.heading
	selectedLbl.TextSize = 22
	selectedLbl.TextColor3 = Theme.color.textPrimary
	selectedLbl.TextXAlignment = Enum.TextXAlignment.Left
	selectedLbl.Parent = counterBox

	local minus = Util.button("-", Theme.color.panel)
	minus.AnchorPoint = Vector2.new(1, 0.5)
	minus.Position = UDim2.new(0.85, -50, 0.5, 0)
	minus.Size = UDim2.fromOffset(44, 44)
	minus.TextSize = 22
	minus.Parent = counterBox

	local plus = Util.button("+", Theme.color.panel)
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, 0, 0.5, 0)
	plus.Size = UDim2.fromOffset(44, 44)
	plus.TextSize = 22
	plus.Parent = counterBox

	-- Chance + Risiko
	local chanceLbl = Instance.new("TextLabel")
	chanceLbl.BackgroundTransparency = 1
	chanceLbl.Position = UDim2.fromOffset(0, 156)
	chanceLbl.Size = UDim2.new(1, 0, 0, 36)
	chanceLbl.Font = Theme.font.heading
	chanceLbl.TextSize = 28
	chanceLbl.TextXAlignment = Enum.TextXAlignment.Left
	chanceLbl.Parent = right

	local riskLbl = Instance.new("TextLabel")
	riskLbl.BackgroundTransparency = 1
	riskLbl.Position = UDim2.fromOffset(0, 192)
	riskLbl.Size = UDim2.new(1, 0, 0, 18)
	riskLbl.Font = Theme.font.bold
	riskLbl.TextSize = 13
	riskLbl.TextXAlignment = Enum.TextXAlignment.Left
	riskLbl.Parent = right

	local fuseBtn = Util.button(Locale.t("fusion.fuse"), Theme.color.accent)
	fuseBtn.AnchorPoint = Vector2.new(0.5, 1)
	fuseBtn.Position = UDim2.new(0.5, 0, 1, 0)
	fuseBtn.Size = UDim2.new(1, 0, 0, 48)
	fuseBtn.TextSize = 18
	fuseBtn.Parent = right

	local resultLbl = Instance.new("TextLabel")
	resultLbl.BackgroundTransparency = 1
	resultLbl.Position = UDim2.fromOffset(0, 214)
	resultLbl.Size = UDim2.new(1, 0, 0, 24)
	resultLbl.Font = Theme.font.heading
	resultLbl.TextSize = 16
	resultLbl.TextXAlignment = Enum.TextXAlignment.Left
	resultLbl.Text = ""
	resultLbl.Parent = right

	local function refreshDetail()
		local godDef = Gods.byId[selectedGroup.godId]
		local rdef = godDef and Rarities.byId[godDef.rarityId] or nil
		nameLbl.Text = displayName(selectedGroup.godId)
		rarityLbl.Text = rdef and Locale.t(rdef.nameKey) or selectedGroup.godId
		rarityLbl.TextColor3 = rdef and rdef.color or Theme.color.textPrimary
		countLbl.Text = string.format(Locale.t("fusion.copies"), #selectedGroup.entries)

		selectedCount = math.clamp(selectedCount, 2, math.min(5, #selectedGroup.entries))
		selectedLbl.Text = string.format(Locale.t("fusion.selected"), selectedCount)

		local chance = Fusion.successChance(selectedCount)
		chanceLbl.Text = string.format(Locale.t("fusion.successColor"), math.floor(chance * 100 + 0.5))
		if chance >= 1 then
			chanceLbl.TextColor3 = Theme.color.success
			riskLbl.Text = Locale.t("fusion.guaranteed")
			riskLbl.TextColor3 = Theme.color.success
		else
			chanceLbl.TextColor3 = Theme.color.accent
			riskLbl.Text = Locale.t("fusion.risk")
			riskLbl.TextColor3 = Theme.color.danger
		end
	end

	minus.Activated:Connect(function() selectedCount -= 1; refreshDetail() end)
	plus.Activated:Connect(function() selectedCount += 1; refreshDetail() end)

	fuseBtn.Activated:Connect(function()
		resultLbl.Text = ""
		fuseBtn.Text = "..."
		local uids = {}
		for i = 1, selectedCount do
			table.insert(uids, selectedGroup.entries[i].uid)
		end
		local result = Net:Function("Fuse"):InvokeServer(uids)
		fuseBtn.Text = Locale.t("fusion.fuse")
		if not result then return end
		if result.ok then
			resultLbl.Text = string.format(Locale.t("fusion.success"), result.newRank or 0)
			resultLbl.TextColor3 = Theme.color.success
		else
			if result.reason == "rate_limited" or result.reason == "no_profile"
				or result.reason == "bad_count" or result.reason == "bad_args"
				or result.reason == "not_owned" or result.reason == "locked"
				or result.reason == "placed" or result.reason == "mismatched_god"
				or result.reason == "mismatched_rarity" then
				resultLbl.Text = "✖ " .. tostring(result.reason)
				resultLbl.TextColor3 = Theme.color.textMuted
			else
				resultLbl.Text = Locale.t("fusion.failed")
				resultLbl.TextColor3 = Theme.color.danger
			end
		end
	end)

	-- Liste links
	for _, group in ipairs(eligible) do
		local godDef = Gods.byId[group.godId]
		local rdef = godDef and Rarities.byId[godDef.rarityId] or nil
		local color = rdef and rdef.color or Theme.color.panelLight

		local row = Instance.new("TextButton")
		row.AutoButtonColor = false
		row.BackgroundColor3 = Theme.color.panel
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 48)
		row.Text = ""
		row.Parent = left
		Util.corner(row, Theme.radius.sm)
		local rs = Instance.new("UIStroke", row)
		rs.Color = color
		rs.Thickness = 2

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = color
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 5, 1, 0)
		accent.Parent = row
		Util.corner(accent, Theme.radius.sm)

		local n = Instance.new("TextLabel")
		n.BackgroundTransparency = 1
		n.Position = UDim2.fromOffset(14, 4)
		n.Size = UDim2.new(1, -50, 0, 22)
		n.Font = Theme.font.bold
		n.TextSize = 14
		n.TextColor3 = Theme.color.textPrimary
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.Text = displayName(group.godId)
		n.Parent = row

		local c = Instance.new("TextLabel")
		c.BackgroundTransparency = 1
		c.Position = UDim2.fromOffset(14, 24)
		c.Size = UDim2.new(1, -50, 0, 18)
		c.Font = Theme.font.body
		c.TextSize = 12
		c.TextColor3 = Theme.color.textSecondary
		c.TextXAlignment = Enum.TextXAlignment.Left
		c.Text = string.format("×%d", #group.entries)
		c.Parent = row

		row.Activated:Connect(function()
			selectedGroup = group
			selectedCount = math.min(2, #group.entries)
			refreshDetail()
		end)
	end

	refreshDetail()
end

return FusionPanel
