--!strict
-- InventoryPanel — alle besessenen Götter. Filter + Sort. Klick auf Karte zeigt Place/Remove.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)

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

function InventoryPanel.create(body: Instance, snapshot)
	-- Container für Filter oben + Grid unten
	local filterHolder = Instance.new("Frame")
	filterHolder.BackgroundTransparency = 1
	filterHolder.Size = UDim2.new(1, 0, 0, 40)
	filterHolder.Parent = body

	local gridHolder = Instance.new("ScrollingFrame")
	gridHolder.BackgroundTransparency = 1
	gridHolder.BorderSizePixel = 0
	gridHolder.Position = UDim2.fromOffset(0, 48)
	gridHolder.Size = UDim2.new(1, 0, 1, -48)
	gridHolder.CanvasSize = UDim2.new()
	gridHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridHolder.ScrollBarThickness = 4
	gridHolder.Parent = body
	Util.gridLayout(gridHolder, UDim2.fromOffset(160, 200), UDim2.fromOffset(8, 8))

	local inventory = snapshot.inventory or { gods = {} }
	local temple = snapshot.temple or { slots = {} }
	local placedUids: { [string]: boolean } = {}
	for _, slot in ipairs(temple.slots) do
		if slot.godUid then placedUids[slot.godUid] = true end
	end

	local filterState

	local function render()
		gridHolder:ClearAllChildren()
		Util.gridLayout(gridHolder, UDim2.fromOffset(160, 200), UDim2.fromOffset(8, 8))

		local filtered = {}
		for _, entry in ipairs(inventory.gods) do
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

		for _, entry in ipairs(filtered) do
			local card = GodCard.create(gridHolder, {
				uid = entry.uid,
				godId = entry.id,
				rarityId = entry.rarityId,
				packTier = entry.packTier,
				fusionRank = entry.fusionRank,
				secret = entry.secret,
				discovered = true,
			}, function()
				-- Klick: platzieren in ersten freien Slot oder entfernen wenn schon platziert.
				if placedUids[entry.uid] then
					for i, slot in ipairs(temple.slots) do
						if slot.godUid == entry.uid then
							Net:Function("RemoveGod"):InvokeServer(i)
							break
						end
					end
				else
					for i, slot in ipairs(temple.slots) do
						if not slot.godUid then
							Net:Function("PlaceGod"):InvokeServer(i, entry.uid)
							break
						end
					end
				end
			end)
			-- "Placed" Badge
			if placedUids[entry.uid] then
				local placed = Instance.new("TextLabel")
				placed.BackgroundColor3 = Theme.color.success
				placed.BorderSizePixel = 0
				placed.AnchorPoint = Vector2.new(1, 1)
				placed.Position = UDim2.new(1, -6, 1, -6)
				placed.Size = UDim2.fromOffset(70, 22)
				placed.Font = Theme.font.bold
				placed.TextSize = 12
				placed.TextColor3 = Color3.fromRGB(20, 20, 30)
				placed.Text = "✓ Placed"
				placed.Parent = card
				Util.corner(placed, Theme.radius.sm)
			end
		end

		if #filtered == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.Size = UDim2.new(1, 0, 0, 40)
			empty.Font = Theme.font.body
			empty.TextSize = 14
			empty.TextColor3 = Theme.color.textMuted
			empty.Text = "No gods yet — open a pack!"
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
