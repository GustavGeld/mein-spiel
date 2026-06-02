--!strict
-- InventoryPanel — Equipped-Reihe oben (alle Tempel-Slots), darunter Grid.
-- Platzierte Götter erscheinen NICHT mehr im Grid — nur noch in der Equipped-Reihe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)
local Odds = require(Shared.math.Odds)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)
local GodCard = require(script.Parent.Parent.components.GodCard)
local FilterBar = require(script.Parent.Parent.components.FilterBar)

local InventoryPanel = {}

local function compareByRarity(a, b): boolean
	local ai = (Rarities.byId[a.rarityId] or {}).index or 0
	local bi = (Rarities.byId[b.rarityId] or {}).index or 0
	if ai ~= bi then return ai > bi end
	return (a.fusionRank or 0) > (b.fusionRank or 0)
end

local function compareByStat(field: string)
	return function(a, b)
		local av = (Gods.byId[a.id] or {})[field] or 0
		local bv = (Gods.byId[b.id] or {})[field] or 0
		return av > bv
	end
end

local function displayName(id: string): string
	return (string.gsub(id, "_", " "))
end

-- Größere Equipped-Slot-Karte mit kräftigem PNG.
local SLOT_W, SLOT_H = 150, 180
local function makeSlotCard(slotIndex: number, entry: any?, onAction: () -> ()): TextButton
	local card = Instance.new("TextButton")
	card.AutoButtonColor = true
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(SLOT_W, SLOT_H)
	card.Text = ""
	Util.corner(card, Theme.radius.md)

	if entry then
		local def = Gods.byId[entry.id]
		local rDef = Rarities.byId[entry.rarityId]
		local color = (rDef and rDef.color) or Theme.color.panelLight
		card.BackgroundColor3 = Color3.new(
			color.R * 0.22 + Theme.color.panel.R * 0.78,
			color.G * 0.22 + Theme.color.panel.G * 0.78,
			color.B * 0.22 + Theme.color.panel.B * 0.78
		)
		Util.stroke(card, color, 3)

		-- Rarity-Streifen oben
		local strip = Instance.new("Frame")
		strip.BackgroundColor3 = color
		strip.BorderSizePixel = 0
		strip.Size = UDim2.new(1, 0, 0, 22)
		strip.Parent = card
		Util.corner(strip, Theme.radius.md)

		local stripName = Instance.new("TextLabel")
		stripName.BackgroundTransparency = 1
		stripName.Size = UDim2.fromScale(1, 1)
		stripName.Font = Theme.font.bold
		stripName.TextSize = 12
		stripName.TextColor3 = Color3.fromRGB(20, 20, 30)
		stripName.Text = "#" .. slotIndex .. "  " .. (rDef and Locale.t(rDef.nameKey) or "")
		stripName.Parent = strip

		-- Icon — deutlich größer
		local iconWell = Instance.new("Frame")
		iconWell.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		iconWell.BackgroundTransparency = 0.85
		iconWell.BorderSizePixel = 0
		iconWell.AnchorPoint = Vector2.new(0.5, 0)
		iconWell.Position = UDim2.new(0.5, 0, 0, 28)
		iconWell.Size = UDim2.fromOffset(96, 96)
		iconWell.Parent = card
		Util.corner(iconWell, UDim.new(0.18, 0))

		local hasIcon = def and def.iconAssetId and def.iconAssetId ~= ""
		if hasIcon then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(0.92, 0.92)
			img.Image = def.iconAssetId :: string
			img.ScaleType = Enum.ScaleType.Fit
			img.Parent = iconWell
		else
			local letter = Instance.new("TextLabel")
			letter.BackgroundTransparency = 1
			letter.Size = UDim2.fromScale(1, 1)
			letter.Font = Theme.font.heading
			letter.TextSize = 56
			letter.TextColor3 = color
			letter.Text = string.upper(string.sub(entry.id, 1, 1))
			letter.Parent = iconWell
		end

		-- Name unten
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(4, 130)
		name.Size = UDim2.new(1, -8, 0, 16)
		name.Font = Theme.font.bold
		name.TextSize = 13
		name.TextColor3 = Theme.color.textPrimary
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = displayName(entry.id)
		name.Parent = card

		-- $/s + ✨/s
		if def then
			local stats = Instance.new("TextLabel")
			stats.BackgroundTransparency = 1
			stats.Position = UDim2.fromOffset(4, 148)
			stats.Size = UDim2.new(1, -8, 0, 26)
			stats.Font = Theme.font.body
			stats.TextSize = 11
			stats.TextColor3 = Theme.color.money
			stats.Text = string.format("$%s/s", Odds.formatBig(def.baseProduction))
			if def.baseFaith > 0 then
				stats.Text ..= string.format("   ✨%s/s", Odds.formatBig(def.baseFaith))
			end
			stats.Parent = card
		end

		-- Klick = Entfernen
		card.Activated:Connect(onAction)
	else
		card.BackgroundColor3 = Theme.color.panelLight
		Util.stroke(card, Theme.color.stroke, 2)

		local idx = Instance.new("TextLabel")
		idx.BackgroundTransparency = 1
		idx.Position = UDim2.fromOffset(0, 8)
		idx.Size = UDim2.new(1, 0, 0, 16)
		idx.Font = Theme.font.bold
		idx.TextSize = 12
		idx.TextColor3 = Theme.color.textMuted
		idx.Text = "Slot " .. slotIndex
		idx.Parent = card

		local empty = Instance.new("TextLabel")
		empty.BackgroundTransparency = 1
		empty.AnchorPoint = Vector2.new(0.5, 0.5)
		empty.Position = UDim2.fromScale(0.5, 0.5)
		empty.Size = UDim2.fromOffset(60, 60)
		empty.Font = Theme.font.heading
		empty.TextSize = 56
		empty.TextColor3 = Theme.color.textMuted
		empty.Text = "+"
		empty.Parent = card

		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.new(0.5, 0, 1, -8)
		hint.Size = UDim2.new(1, -8, 0, 14)
		hint.Font = Theme.font.body
		hint.TextSize = 11
		hint.TextColor3 = Theme.color.textMuted
		hint.Text = "Empty"
		hint.Parent = card
	end
	return card
end

local function findEntry(inventory, uid: string): any?
	for _, e in ipairs(inventory.gods) do
		if e.uid == uid then return e end
	end
	return nil
end

-- Größere God-Card-Größe für das Hauptraster.
local CARD_W, CARD_H = 200, 280

function InventoryPanel.create(body: Instance, snapshot)
	local inventory = snapshot.inventory or { gods = {} }
	local temple = snapshot.temple or { slots = {} }
	local placedUids: { [string]: boolean } = {}
	for _, slot in ipairs(temple.slots) do
		if slot.godUid then placedUids[slot.godUid] = true end
	end

	-- ─── Top-Bereich: Equipped Slots (passt sich der Slot-Anzahl an) ─────────
	local equippedRow = Instance.new("Frame")
	equippedRow.BackgroundColor3 = Theme.color.panelLight
	equippedRow.BorderSizePixel = 0
	equippedRow.Size = UDim2.new(1, 0, 0, SLOT_H + 36)
	equippedRow.Parent = body
	Util.corner(equippedRow, Theme.radius.md)

	local equippedTitle = Instance.new("TextLabel")
	equippedTitle.BackgroundTransparency = 1
	equippedTitle.Position = UDim2.fromOffset(14, 6)
	equippedTitle.Size = UDim2.new(0.5, 0, 0, 20)
	equippedTitle.Font = Theme.font.bold
	equippedTitle.TextSize = 13
	equippedTitle.TextColor3 = Theme.color.textSecondary
	equippedTitle.TextXAlignment = Enum.TextXAlignment.Left
	equippedTitle.Text = string.format("EQUIPPED  (%d slot%s)",
		#temple.slots, #temple.slots == 1 and "" or "s")
	equippedTitle.Parent = equippedRow

	local slotScroller = Instance.new("ScrollingFrame")
	slotScroller.BackgroundTransparency = 1
	slotScroller.BorderSizePixel = 0
	slotScroller.Position = UDim2.fromOffset(10, 28)
	slotScroller.Size = UDim2.new(1, -20, 1, -34)
	slotScroller.CanvasSize = UDim2.new()
	slotScroller.AutomaticCanvasSize = Enum.AutomaticSize.X
	slotScroller.ScrollBarThickness = 6
	slotScroller.ScrollingDirection = Enum.ScrollingDirection.X
	slotScroller.Parent = equippedRow
	Util.listLayout(slotScroller, Enum.FillDirection.Horizontal, 10)

	for i, slot in ipairs(temple.slots) do
		local entry = slot.godUid and findEntry(inventory, slot.godUid) or nil
		local sc = makeSlotCard(i, entry, function()
			if entry then
				Net:Function("RemoveGod"):InvokeServer(i)
			end
		end)
		sc.LayoutOrder = i
		sc.Parent = slotScroller
	end

	-- ─── Filter-Leiste ───────────────────────────────────────────────────────
	local filterHolder = Instance.new("Frame")
	filterHolder.BackgroundTransparency = 1
	filterHolder.Position = UDim2.fromOffset(0, SLOT_H + 44)
	filterHolder.Size = UDim2.new(1, 0, 0, 40)
	filterHolder.Parent = body

	-- ─── Grid (unter Filter) ─────────────────────────────────────────────────
	local gridTop = SLOT_H + 90
	local gridHolder = Instance.new("ScrollingFrame")
	gridHolder.BackgroundTransparency = 1
	gridHolder.BorderSizePixel = 0
	gridHolder.Position = UDim2.fromOffset(0, gridTop)
	gridHolder.Size = UDim2.new(1, 0, 1, -gridTop)
	gridHolder.CanvasSize = UDim2.new()
	gridHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridHolder.ScrollBarThickness = 6
	gridHolder.Parent = body
	Util.gridLayout(gridHolder, UDim2.fromOffset(CARD_W, CARD_H), UDim2.fromOffset(12, 12))

	local filterState

	local function render()
		gridHolder:ClearAllChildren()
		Util.gridLayout(gridHolder, UDim2.fromOffset(CARD_W, CARD_H), UDim2.fromOffset(12, 12))

		local filtered = {}
		for _, entry in ipairs(inventory.gods) do
			-- Equipped-Götter NICHT mehr im Grid anzeigen.
			if placedUids[entry.uid] then continue end
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

		for i, entry in ipairs(filtered) do
			local card = GodCard.create(gridHolder, {
				uid = entry.uid,
				godId = entry.id,
				rarityId = entry.rarityId,
				packTier = entry.packTier,
				fusionRank = entry.fusionRank,
				secret = entry.secret,
				discovered = true,
				cardSize = Vector2.new(CARD_W, CARD_H),
			}, function()
				-- In ersten freien Slot platzieren
				for si, slot in ipairs(temple.slots) do
					if not slot.godUid then
						Net:Function("PlaceGod"):InvokeServer(si, entry.uid)
						break
					end
				end
			end)
			card.LayoutOrder = i
		end

		if #filtered == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.new(1, 0, 0, 60)
			empty.Font = Theme.font.body
			empty.TextSize = 16
			empty.TextColor3 = Theme.color.textMuted
			if #inventory.gods > 0 then
				empty.Text = "All your gods are equipped — see the slots above."
			else
				empty.Text = "No gods yet — open a pack!"
			end
			empty.Parent = gridHolder
		end
	end

	local fb = FilterBar.create(filterHolder, function(state)
		filterState = state
		render()
	end)
	filterState = fb.state
	render()
end

return InventoryPanel
