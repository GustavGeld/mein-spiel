--!strict
-- IndexPanel (Collection Book) — alle möglichen Götter. Discovered = farbig, sonst Silhouette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Locale = require(Shared.locale.Locale)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)
local GodCard = require(script.Parent.Parent.components.GodCard)
local FilterBar = require(script.Parent.Parent.components.FilterBar)

local IndexPanel = {}

-- Index berechnet Pack-Tier aus der Rarity-Definition.
local function packTierFor(rarityId: string): number
	local def = Rarities.byId[rarityId]
	return def and def.packTier or 1
end

local function compareByRarity(a, b): boolean
	local ai = (Rarities.byId[a.rarityId] or {}).index or 0
	local bi = (Rarities.byId[b.rarityId] or {}).index or 0
	return ai > bi
end

local function compareByStat(field: string)
	return function(a, b)
		local av = (Gods.byId[a.id] or {})[field] or 0
		local bv = (Gods.byId[b.id] or {})[field] or 0
		return av > bv
	end
end

function IndexPanel.create(body: Instance, snapshot)
	local filterHolder = Instance.new("Frame")
	filterHolder.BackgroundTransparency = 1
	filterHolder.Size = UDim2.new(1, 0, 0, 40)
	filterHolder.Parent = body

	-- Statistik-Anzeige rechts oben
	local statsLabel = Instance.new("TextLabel")
	statsLabel.BackgroundTransparency = 1
	statsLabel.AnchorPoint = Vector2.new(1, 0)
	statsLabel.Position = UDim2.new(1, 0, 0, 0)
	statsLabel.Size = UDim2.fromOffset(170, 30)
	statsLabel.Font = Theme.font.bold
	statsLabel.TextSize = 14
	statsLabel.TextColor3 = Theme.color.textPrimary
	statsLabel.TextXAlignment = Enum.TextXAlignment.Right
	statsLabel.Parent = filterHolder

	local gridHolder = Instance.new("ScrollingFrame")
	gridHolder.BackgroundTransparency = 1
	gridHolder.BorderSizePixel = 0
	gridHolder.Position = UDim2.fromOffset(0, 48)
	gridHolder.Size = UDim2.new(1, 0, 1, -48)
	gridHolder.CanvasSize = UDim2.new()
	gridHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridHolder.ScrollBarThickness = 4
	gridHolder.Parent = body
	Util.gridLayout(gridHolder, UDim2.fromOffset(160, 220), UDim2.fromOffset(8, 8))

	local discovered = (snapshot.collection or {}).discovered or {}
	local entries = {}
	for _, def in ipairs(Gods.list) do
		table.insert(entries, {
			id = def.id,
			rarityId = def.rarityId,
			packTier = packTierFor(def.rarityId),
			discovered = discovered[def.id] == true,
		})
	end

	local filterState

	local function render()
		gridHolder:ClearAllChildren()
		Util.gridLayout(gridHolder, UDim2.fromOffset(160, 220), UDim2.fromOffset(8, 8))

		local filtered = {}
		local foundCount = 0
		for _, entry in ipairs(entries) do
			if entry.discovered then foundCount += 1 end
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

		statsLabel.Text = string.format("%d / %d found", foundCount, #entries)

		for _, entry in ipairs(filtered) do
			GodCard.create(gridHolder, {
				godId = entry.id,
				rarityId = entry.rarityId,
				packTier = entry.packTier,
				discovered = entry.discovered,
			})
		end
	end

	local fb = FilterBar.create(filterHolder, function(state)
		filterState = state
		render()
	end)
	filterState = fb.state
	render()
end

return IndexPanel
