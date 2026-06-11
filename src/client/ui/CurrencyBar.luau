--!strict
-- CurrencyBar — Gold + Faith links-unten, großer Text mit Schatten.
-- Faith steht ÜBER Gold (zweite Zeile von unten).

local Theme = require(script.Parent.Theme)

local CurrencyBar = {}

local function formatMoney(n: number, prefix: string): string
	n = math.floor(n + 0.5)
	if n >= 1000000 then
		local suffixes = { "M", "B", "T", "Q" }
		local value = n / 1000000
		local i = 1
		while value >= 1000 and i < #suffixes do
			value /= 1000; i += 1
		end
		return string.format("%s%.1f%s", prefix, value, suffixes[i])
	end
	local s = tostring(n)
	local out, count = "", 0
	for i = #s, 1, -1 do
		out = s:sub(i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then out = "," .. out end
	end
	return prefix .. out
end

function CurrencyBar.create(parent: Instance): { update: ({ [string]: number }) -> () }
	-- Container: zwei Labels übereinander, unten-links verankert
	local container = Instance.new("Frame")
	container.Name = "CurrencyBar"
	container.AnchorPoint = Vector2.new(0, 1)
	container.Position = UDim2.new(0, 20, 1, -16)
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(300, 96)
	container.Parent = parent

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.Parent = container

	-- Faith (darüber, etwas kleiner, orange)
	local faithTxt = Instance.new("TextLabel")
	faithTxt.Name = "Faith"
	faithTxt.LayoutOrder = 1
	faithTxt.BackgroundTransparency = 1
	faithTxt.AutomaticSize = Enum.AutomaticSize.XY
	faithTxt.Size = UDim2.fromOffset(0, 0)
	faithTxt.Font = Theme.font.heading
	faithTxt.TextColor3 = Color3.fromRGB(255, 165, 60)  -- Orange
	faithTxt.TextSize = 34
	faithTxt.TextXAlignment = Enum.TextXAlignment.Left
	faithTxt.TextYAlignment = Enum.TextYAlignment.Bottom
	faithTxt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	faithTxt.TextStrokeTransparency = 0.2
	faithTxt.Text = "✨0"
	faithTxt.Parent = container

	-- Gold (unten, größer, grün)
	local goldTxt = Instance.new("TextLabel")
	goldTxt.Name = "Gold"
	goldTxt.LayoutOrder = 2
	goldTxt.BackgroundTransparency = 1
	goldTxt.AutomaticSize = Enum.AutomaticSize.XY
	goldTxt.Size = UDim2.fromOffset(0, 0)
	goldTxt.Font = Theme.font.heading
	goldTxt.TextColor3 = Theme.color.money
	goldTxt.TextSize = 48
	goldTxt.TextXAlignment = Enum.TextXAlignment.Left
	goldTxt.TextYAlignment = Enum.TextYAlignment.Bottom
	goldTxt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	goldTxt.TextStrokeTransparency = 0.2
	goldTxt.Text = "$0"
	goldTxt.Parent = container

	local function update(currencies: { [string]: number })
		if not currencies then return end
		goldTxt.Text  = formatMoney(currencies.gold  or 0, "$")
		faithTxt.Text = "✨" .. formatMoney(currencies.faith or 0, "")
	end

	return { update = update }
end

return CurrencyBar
