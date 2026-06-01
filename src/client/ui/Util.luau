--!strict
-- UI-Helper: kleine Convenience-Wrapper, damit Panels nicht alle gleichen Boilerplate haben.

local Theme = require(script.Parent.Theme)

local Util = {}

function Util.corner(parent: Instance, radius: UDim?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or Theme.radius.md
	c.Parent = parent
	return c
end

function Util.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.color.stroke
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Util.padding(parent: Instance, p: number?): UIPadding
	local pad = Instance.new("UIPadding")
	local off = UDim.new(0, p or Theme.padding.md)
	pad.PaddingTop = off
	pad.PaddingBottom = off
	pad.PaddingLeft = off
	pad.PaddingRight = off
	pad.Parent = parent
	return pad
end

function Util.listLayout(parent: Instance, direction: Enum.FillDirection?, padding: number?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, padding or Theme.padding.sm)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function Util.gridLayout(parent: Instance, cellSize: UDim2, cellPadding: UDim2?): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = cellSize
	g.CellPadding = cellPadding or UDim2.fromOffset(8, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = parent
	return g
end

function Util.label(text: string, font: Enum.Font?, color: Color3?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = font or Theme.font.body
	t.TextColor3 = color or Theme.color.textPrimary
	t.TextScaled = false
	t.TextSize = 16
	t.Text = text
	t.TextXAlignment = Enum.TextXAlignment.Left
	return t
end

function Util.button(text: string, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color or Theme.color.accent
	b.BorderSizePixel = 0
	b.Font = Theme.font.bold
	b.TextSize = 16
	b.TextColor3 = Theme.color.textPrimary
	b.Text = text
	Util.corner(b, Theme.radius.md)
	return b
end

-- Zeigt entweder ein Image-Asset oder fällt auf Unicode-Text zurück.
-- Verwendet die Icon-Struktur aus Icons.luau.
function Util.icon(iconDef: { assetId: string, fallback: string }, size: number?): Frame
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(size or 24, size or 24)

	local hasAsset = iconDef.assetId ~= "" and iconDef.assetId ~= "rbxassetid://0"
	if hasAsset then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = iconDef.assetId
		img.ImageColor3 = Theme.color.textPrimary
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = container
	else
		local txt = Instance.new("TextLabel")
		txt.BackgroundTransparency = 1
		txt.Size = UDim2.fromScale(1, 1)
		txt.Font = Theme.font.bold
		txt.TextScaled = true
		txt.TextColor3 = Theme.color.textPrimary
		txt.Text = iconDef.fallback
		txt.Parent = container
	end
	return container
end

return Util
