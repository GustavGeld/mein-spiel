--!strict
-- TemplePanel — faith-funded temple upgrade shop.
-- Three upgrades: production boost, faith amplifier, slot expansion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Net    = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Odds   = require(Shared.math.Odds)

local Theme = require(script.Parent.Parent.Theme)
local Util  = require(script.Parent.Parent.Util)

local TemplePanel = {}

-- ─── Static config (mirrors server UPGRADE_COSTS) ────────────────────────────

local UPGRADE_INFO: { { id: string, icon: string, nameKey: string, descKey: string, maxLvl: number, color: Color3 } } = {
	{
		id      = "production",
		icon    = "⚡",
		nameKey = "temple.upgrade.production",
		descKey = "temple.upgrade.productionDesc",
		maxLvl  = 20,
		color   = Color3.fromRGB(255, 210, 80),
	},
	{
		id      = "faith",
		icon    = "✨",
		nameKey = "temple.upgrade.faith",
		descKey = "temple.upgrade.faithDesc",
		maxLvl  = 20,
		color   = Color3.fromRGB(120, 200, 255),
	},
	{
		id      = "slots",
		icon    = "🏛",
		nameKey = "temple.upgrade.slots",
		descKey = "temple.upgrade.slotsDesc",
		maxLvl  = 3,
		color   = Color3.fromRGB(160, 255, 160),
	},
}

local function upgradeCost(id: string, lvl: number): number
	if id == "production" then return math.floor(500  * (1.5 ^ lvl)) end
	if id == "faith"      then return math.floor(300  * (1.5 ^ lvl)) end
	if id == "slots"      then return math.floor(2000 * (3   ^ lvl)) end
	return 0
end

local function fmt(n: number): string
	return Odds.formatBig(n)
end

-- ─── Panel builder ────────────────────────────────────────────────────────────

function TemplePanel.create(body: Instance, snapshot: any)
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel        = 0
	scroller.Size                   = UDim2.fromScale(1, 1)
	scroller.CanvasSize             = UDim2.new()
	scroller.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness     = 4
	scroller.Parent                 = body
	Util.listLayout(scroller, Enum.FillDirection.Vertical, 12)
	Util.padding(scroller, 14)

	-- ── Header ──────────────────────────────────────────────────────────────
	local header = Instance.new("Frame")
	header.BackgroundColor3 = Theme.color.panelLight
	header.BorderSizePixel  = 0
	header.Size             = UDim2.new(1, 0, 0, 72)
	header.Parent           = scroller
	Util.corner(header, Theme.radius.md)

	local tierLbl = Instance.new("TextLabel")
	tierLbl.BackgroundTransparency = 1
	tierLbl.Position       = UDim2.fromOffset(14, 10)
	tierLbl.Size           = UDim2.new(0.55, 0, 0, 24)
	tierLbl.Font           = Theme.font.heading
	tierLbl.TextSize       = 20
	tierLbl.TextColor3     = Color3.fromRGB(255, 220, 100)
	tierLbl.TextXAlignment = Enum.TextXAlignment.Left
	tierLbl.Parent         = header

	local faithLbl = Instance.new("TextLabel")
	faithLbl.BackgroundTransparency = 1
	faithLbl.Position       = UDim2.fromOffset(14, 38)
	faithLbl.Size           = UDim2.new(0.55, 0, 0, 22)
	faithLbl.Font           = Theme.font.body
	faithLbl.TextSize       = 14
	faithLbl.TextColor3     = Color3.fromRGB(120, 200, 255)
	faithLbl.TextXAlignment = Enum.TextXAlignment.Left
	faithLbl.Parent         = header

	local statLbl = Instance.new("TextLabel")
	statLbl.BackgroundTransparency = 1
	statLbl.AnchorPoint    = Vector2.new(1, 0.5)
	statLbl.Position       = UDim2.new(1, -14, 0.5, 0)
	statLbl.Size           = UDim2.new(0.4, 0, 0, 48)
	statLbl.Font           = Theme.font.body
	statLbl.TextSize       = 12
	statLbl.TextColor3     = Theme.color.textSecondary
	statLbl.TextXAlignment = Enum.TextXAlignment.Right
	statLbl.TextWrapped    = true
	statLbl.Parent         = header

	-- Live snapshot refs (mutated by buy callbacks)
	local templeSnap = snapshot.temple or {}
	local upgrades: { [string]: number } = (templeSnap.upgrades or { production = 0, faith = 0, slots = 0 }) :: any
	local faithBalance = (snapshot.currencies and snapshot.currencies.faith) or 0
	local tier = templeSnap.tier or 1

	local function updateHeader()
		faithBalance = (snapshot.currencies and snapshot.currencies.faith) or 0
		tier = (snapshot.temple and snapshot.temple.tier) or 1
		tierLbl.Text = string.format("🏛  %s %d", Locale.t("temple.tier"), tier)
		faithLbl.Text = string.format("✨  %s", fmt(faithBalance))
		local prodPct  = ((tier - 1) * 5) + ((upgrades.production or 0) * 2)
		local faithPct = (upgrades.faith or 0) * 2
		local slotCount = 3 + (upgrades.slots or 0)
		if snapshot.unlocks and snapshot.unlocks.gamepasses and snapshot.unlocks.gamepasses["extraSlots"] then
			slotCount += 3
		end
		statLbl.Text = string.format(
			"+%d%% Gold/s\n+%d%% Faith/s\n%d Slots",
			prodPct, faithPct, slotCount
		)
	end
	updateHeader()

	-- ── Upgrade cards ────────────────────────────────────────────────────────
	local buyBtns: { [string]: TextButton } = {}

	for _, info in ipairs(UPGRADE_INFO) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Theme.color.panelLight
		card.BorderSizePixel  = 0
		card.Size             = UDim2.new(1, 0, 0, 92)
		card.Parent           = scroller
		Util.corner(card, Theme.radius.md)

		-- Color stripe
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = info.color
		stripe.BorderSizePixel  = 0
		stripe.Size             = UDim2.new(0, 4, 1, 0)
		stripe.Parent           = card
		Util.corner(stripe, Theme.radius.sm)

		-- Icon
		local iconLbl = Instance.new("TextLabel")
		iconLbl.BackgroundTransparency = 1
		iconLbl.Position  = UDim2.fromOffset(14, 16)
		iconLbl.Size      = UDim2.fromOffset(36, 40)
		iconLbl.Font      = Theme.font.heading
		iconLbl.TextSize  = 26
		iconLbl.TextColor3 = info.color
		iconLbl.Text      = info.icon
		iconLbl.Parent    = card

		-- Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position       = UDim2.fromOffset(58, 10)
		nameLbl.Size           = UDim2.new(0.45, 0, 0, 22)
		nameLbl.Font           = Theme.font.bold
		nameLbl.TextSize       = 15
		nameLbl.TextColor3     = Theme.color.textPrimary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text           = Locale.t(info.nameKey)
		nameLbl.Parent         = card

		-- Level label (mutable)
		local lvlLbl = Instance.new("TextLabel")
		lvlLbl.BackgroundTransparency = 1
		lvlLbl.Position       = UDim2.fromOffset(58, 34)
		lvlLbl.Size           = UDim2.new(0.42, 0, 0, 18)
		lvlLbl.Font           = Theme.font.body
		lvlLbl.TextSize       = 12
		lvlLbl.TextXAlignment = Enum.TextXAlignment.Left
		lvlLbl.Parent         = card

		-- Description
		local descLbl = Instance.new("TextLabel")
		descLbl.BackgroundTransparency = 1
		descLbl.Position       = UDim2.fromOffset(58, 56)
		descLbl.Size           = UDim2.new(0.52, 0, 0, 28)
		descLbl.Font           = Theme.font.body
		descLbl.TextSize       = 11
		descLbl.TextColor3     = Theme.color.textSecondary
		descLbl.TextXAlignment = Enum.TextXAlignment.Left
		descLbl.TextWrapped    = true
		descLbl.Text           = Locale.t(info.descKey)
		descLbl.Parent         = card

		-- Buy button
		local btn = Instance.new("TextButton")
		btn.AnchorPoint     = Vector2.new(1, 0.5)
		btn.Position        = UDim2.new(1, -12, 0.5, 0)
		btn.Size            = UDim2.fromOffset(148, 38)
		btn.BorderSizePixel = 0
		btn.Font            = Theme.font.bold
		btn.TextSize        = 13
		btn.Parent          = card
		Util.corner(btn, Theme.radius.sm)
		buyBtns[info.id] = btn

		local capturedId = info.id
		local capturedMax = info.maxLvl
		local capturedLvlLbl = lvlLbl

		local function refreshCard()
			local lvl = upgrades[capturedId] or 0
			local isMax = lvl >= capturedMax
			local cost = isMax and 0 or upgradeCost(capturedId, lvl)
			local canAfford = faithBalance >= cost

			capturedLvlLbl.Text = isMax
				and string.format("MAX  (%d/%d)", lvl, capturedMax)
				or string.format("Lv %d / %d", lvl, capturedMax)
			capturedLvlLbl.TextColor3 = isMax and Theme.color.success or Theme.color.textMuted

			if isMax then
				btn.Text             = "✓ MAX"
				btn.BackgroundColor3 = Theme.color.success
				btn.TextColor3       = Color3.fromRGB(15, 25, 15)
				btn.AutoButtonColor  = false
			elseif canAfford then
				btn.Text             = string.format("✨ %s", fmt(cost))
				btn.BackgroundColor3 = Color3.fromRGB(60, 130, 220)
				btn.TextColor3       = Color3.fromRGB(220, 240, 255)
				btn.AutoButtonColor  = true
			else
				btn.Text             = string.format("✨ %s", fmt(cost))
				btn.BackgroundColor3 = Theme.color.panel
				btn.TextColor3       = Theme.color.textMuted
				btn.AutoButtonColor  = false
			end
		end

		refreshCard()

		btn.Activated:Connect(function()
			local lvl = upgrades[capturedId] or 0
			if lvl >= capturedMax then return end
			local cost = upgradeCost(capturedId, lvl)
			if faithBalance < cost then return end

			btn.Text = "..."
			btn.AutoButtonColor = false

			local result = Net:Function("BuyTempleUpgrade"):InvokeServer(capturedId)
			if result and result.ok then
				upgrades[capturedId] = lvl + 1
				faithBalance -= cost
				-- Mirror back into snapshot
				if snapshot.currencies then snapshot.currencies.faith = faithBalance end
				if snapshot.temple then snapshot.temple.upgrades = upgrades end
				updateHeader()
			end
			refreshCard()
		end)
	end

	-- ── OnTempleUpdate listener — keep in sync if panel stays open ────────────
	task.spawn(function()
		local ok, profile = pcall(function()
			return Net:Function("RequestProfile"):InvokeServer()
		end)
		if ok and profile then
			if profile.temple and profile.temple.upgrades then
				upgrades = profile.temple.upgrades
			end
			faithBalance = (profile.currencies and profile.currencies.faith) or 0
			tier = (profile.temple and profile.temple.tier) or 1
			updateHeader()
			for _, info in ipairs(UPGRADE_INFO) do
				local btn = buyBtns[info.id]
				if btn then
					local lvl = upgrades[info.id] or 0
					local isMax = lvl >= info.maxLvl
					local cost = isMax and 0 or upgradeCost(info.id, lvl)
					local canAfford = faithBalance >= cost
					if isMax then
						btn.Text             = "✓ MAX"
						btn.BackgroundColor3 = Theme.color.success
						btn.TextColor3       = Color3.fromRGB(15, 25, 15)
						btn.AutoButtonColor  = false
					elseif canAfford then
						btn.Text             = string.format("✨ %s", fmt(cost))
						btn.BackgroundColor3 = Color3.fromRGB(60, 130, 220)
						btn.TextColor3       = Color3.fromRGB(220, 240, 255)
						btn.AutoButtonColor  = true
					else
						btn.Text             = string.format("✨ %s", fmt(cost))
						btn.BackgroundColor3 = Theme.color.panel
						btn.TextColor3       = Theme.color.textMuted
						btn.AutoButtonColor  = false
					end
				end
			end
		end
	end)
end

return TemplePanel
