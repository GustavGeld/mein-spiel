--!strict
-- Bottom-left Geld-Anzeige — groß, grün, ohne Hintergrund, mit dunklem Stroke
-- für Lesbarkeit auf hellen Untergründen.

local Theme = require(script.Parent.Theme)

local CurrencyBar = {}

local MONEY_KEY = "gold"

local function formatMoney(n: number): string
	n = math.floor(n + 0.5)
	if n >= 1000000 then
		local suffixes = { "M", "B", "T", "Q" }
		local value = n / 1000000
		local i = 1
		while value >= 1000 and i < #suffixes do
			value /= 1000
			i += 1
		end
		return string.format("$%.1f%s", value, suffixes[i])
	end
	local s = tostring(n)
	local out, count = "", 0
	for i = #s, 1, -1 do
		out = s:sub(i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return "$" .. out
end

function CurrencyBar.create(parent: Instance): { update: ({ [string]: number }) -> () }
	local txt = Instance.new("TextLabel")
	txt.Name = "CurrencyBar"
	txt.AnchorPoint = Vector2.new(0, 1)
	txt.Position = UDim2.new(0, 20, 1, -16)
	txt.AutomaticSize = Enum.AutomaticSize.XY
	txt.Size = UDim2.fromOffset(0, 0)
	txt.BackgroundTransparency = 1
	txt.Font = Theme.font.heading
	txt.TextColor3 = Theme.color.money
	txt.TextSize = 48
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextYAlignment = Enum.TextYAlignment.Bottom
	txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	txt.TextStrokeTransparency = 0.2
	txt.Text = "$0"
	txt.Parent = parent

	local function update(currencies: { [string]: number })
		if not currencies then return end
		txt.Text = formatMoney(currencies[MONEY_KEY] or 0)
	end

	return { update = update }
end

return CurrencyBar
