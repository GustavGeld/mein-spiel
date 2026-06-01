--!strict
-- Bottom-left CurrencyBar — Gold, Faith, Offerings, Gems, Divinity.
-- Wird live durch OnEconomyUpdate aktualisiert.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Locale = require(Shared.locale.Locale)
local Odds = require(Shared.math.Odds)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Util = require(script.Parent.Util)

local CurrencyBar = {}

local ORDER = { "gold", "faith", "offerings", "gems", "divinity" }
local COLORS: { [string]: Color3 } = {
	gold = Theme.color.gold,
	faith = Theme.color.faith,
	offerings = Theme.color.offerings,
	gems = Theme.color.gems,
	divinity = Theme.color.divinity,
}

function CurrencyBar.create(parent: Instance): { update: ({ [string]: number }) -> () }
	local frame = Instance.new("Frame")
	frame.Name = "CurrencyBar"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 16, 1, -16)
	frame.Size = UDim2.fromOffset(220, 200)
	frame.BackgroundColor3 = Theme.color.panel
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Util.corner(frame, Theme.radius.lg)
	Util.stroke(frame)
	Util.padding(frame, Theme.padding.md)
	local layout = Util.listLayout(frame, Enum.FillDirection.Vertical, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local rows: { [string]: TextLabel } = {}
	for _, currency in ipairs(ORDER) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 28)
		row.Parent = frame

		local iconBox = Util.icon(Icons[currency] or Icons.gold, 22)
		iconBox.Position = UDim2.new(0, 0, 0.5, 0)
		iconBox.AnchorPoint = Vector2.new(0, 0.5)
		iconBox.Parent = row

		local txt = Instance.new("TextLabel")
		txt.BackgroundTransparency = 1
		txt.AnchorPoint = Vector2.new(0, 0.5)
		txt.Position = UDim2.new(0, 30, 0.5, 0)
		txt.Size = UDim2.new(1, -30, 1, 0)
		txt.Font = Theme.font.bold
		txt.TextColor3 = COLORS[currency] or Theme.color.textPrimary
		txt.TextScaled = false
		txt.TextSize = 18
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.Text = "0"
		txt.Parent = row

		rows[currency] = txt
	end

	local function update(currencies: { [string]: number })
		if not currencies then return end
		for _, currency in ipairs(ORDER) do
			local value = currencies[currency] or 0
			if rows[currency] then
				rows[currency].Text = Odds.formatBig(value)
			end
		end
	end

	return { update = update }
end

return CurrencyBar
