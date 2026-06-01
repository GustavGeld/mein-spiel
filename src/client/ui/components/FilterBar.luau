--!strict
-- FilterBar — Rarity-Filter (Multi-Select) + Sort-Auswahl.
-- Wird über Inventory- und Index-Panels gesetzt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared").locale.Locale)
local Rarities = require(ReplicatedStorage.Shared.config.Rarities)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

export type FilterState = {
	-- Pack-Tier-Filter (1..10), nil = alle.
	packTier: number?,
	-- Sortierung
	sortBy: string, -- "rarity" | "gold" | "faith"
}

local FilterBar = {}

local PACK_TIERS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } -- 0 = "All"
local SORTS = { "rarity", "gold", "faith" }

function FilterBar.create(parent: Instance, onChanged: (FilterState) -> ()): { state: FilterState }
	local state: FilterState = { packTier = nil, sortBy = "rarity" }

	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.Parent = parent

	-- Linke Seite: Pack-Tier-Chips
	local chipsHolder = Instance.new("ScrollingFrame")
	chipsHolder.BackgroundTransparency = 1
	chipsHolder.BorderSizePixel = 0
	chipsHolder.Size = UDim2.new(1, -180, 1, 0)
	chipsHolder.CanvasSize = UDim2.new()
	chipsHolder.AutomaticCanvasSize = Enum.AutomaticSize.X
	chipsHolder.ScrollingDirection = Enum.ScrollingDirection.X
	chipsHolder.ScrollBarThickness = 2
	chipsHolder.Parent = frame
	local chipsLayout = Util.listLayout(chipsHolder, Enum.FillDirection.Horizontal, 6)

	local chipButtons: { [number]: TextButton } = {}
	local function refreshChips()
		for tier, btn in pairs(chipButtons) do
			local active = (tier == 0 and state.packTier == nil) or state.packTier == tier
			btn.BackgroundColor3 = active and Theme.color.accent or Theme.color.panelLight
			btn.TextColor3 = active and Color3.fromRGB(20, 20, 30) or Theme.color.textPrimary
		end
	end

	for _, tier in ipairs(PACK_TIERS) do
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.Size = UDim2.fromOffset(tier == 0 and 50 or 44, 30)
		btn.BackgroundColor3 = Theme.color.panelLight
		btn.BorderSizePixel = 0
		btn.Font = Theme.font.bold
		btn.TextSize = 13
		btn.TextColor3 = Theme.color.textPrimary
		btn.Text = tier == 0 and "All" or ("P" .. tier)
		btn.Parent = chipsHolder
		Util.corner(btn, Theme.radius.sm)
		chipButtons[tier] = btn
		btn.Activated:Connect(function()
			state.packTier = (tier == 0) and nil or tier
			refreshChips()
			onChanged(state)
		end)
	end
	refreshChips()

	-- Rechte Seite: Sort-Dropdown (rotierend)
	local sortBtn = Instance.new("TextButton")
	sortBtn.AnchorPoint = Vector2.new(1, 0)
	sortBtn.Position = UDim2.new(1, 0, 0, 0)
	sortBtn.Size = UDim2.fromOffset(170, 30)
	sortBtn.BackgroundColor3 = Theme.color.panelLight
	sortBtn.BorderSizePixel = 0
	sortBtn.Font = Theme.font.bold
	sortBtn.TextSize = 13
	sortBtn.TextColor3 = Theme.color.textPrimary
	sortBtn.Text = "↕ Sort: Rarity"
	sortBtn.Parent = frame
	Util.corner(sortBtn, Theme.radius.sm)

	local sortLabels: { [string]: string } = {
		rarity = "↕ Sort: Rarity",
		gold = "💰 Sort: Gold/s",
		faith = "✨ Sort: Faith/s",
	}

	sortBtn.Activated:Connect(function()
		local i = table.find(SORTS, state.sortBy) or 1
		i = (i % #SORTS) + 1
		state.sortBy = SORTS[i]
		sortBtn.Text = sortLabels[state.sortBy]
		onChanged(state)
	end)

	return { state = state }
end

return FilterBar
