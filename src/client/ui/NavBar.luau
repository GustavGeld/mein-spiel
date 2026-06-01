--!strict
-- NavBar — vertikale Spalte mit großen Buttons.
-- Position: links unten, direkt ÜBER der CurrencyBar.

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Util = require(script.Parent.Util)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared").locale.Locale)

export type NavItem = { id: string, labelKey: string, icon: { assetId: string, fallback: string } }

local NavBar = {}

NavBar.items = {
	{ id = "shop",      labelKey = "nav.shop",        icon = Icons.shop },
	{ id = "inventory", labelKey = "nav.inventory",   icon = Icons.inventory },
	{ id = "index",     labelKey = "nav.collection",  icon = Icons.index },
	{ id = "quests",    labelKey = "nav.quests",      icon = Icons.quests },
	{ id = "daily",     labelKey = "nav.daily",       icon = Icons.daily },
	{ id = "rewards",   labelKey = "nav.rewards",     icon = Icons.rewards },
	{ id = "settings",  labelKey = "nav.settings",    icon = Icons.settings },
}

function NavBar.create(parent: Instance, onTabSelected: (id: string) -> ()): Frame
	local frame = Instance.new("Frame")
	frame.Name = "NavBar"
	frame.AnchorPoint = Vector2.new(0, 1)
	-- Position so dass NavBar direkt über CurrencyBar sitzt (CurrencyBar ist 200 hoch, 16 padding).
	frame.Position = UDim2.new(0, 16, 1, -16 - 200 - 12)
	frame.Size = UDim2.fromOffset(220, 360)
	frame.BackgroundColor3 = Theme.color.panel
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Util.corner(frame, Theme.radius.lg)
	Util.stroke(frame)
	Util.padding(frame, Theme.padding.md)
	local layout = Util.listLayout(frame, Enum.FillDirection.Vertical, 6)

	for _, item in ipairs(NavBar.items) do
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Theme.color.panelLight
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(1, 0, 0, 42)
		btn.Text = ""
		btn.Parent = frame
		Util.corner(btn, Theme.radius.md)

		local iconBox = Util.icon(item.icon, 24)
		iconBox.AnchorPoint = Vector2.new(0, 0.5)
		iconBox.Position = UDim2.new(0, 10, 0.5, 0)
		iconBox.Parent = btn

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = UDim2.new(0, 44, 0.5, 0)
		label.Size = UDim2.new(1, -50, 1, 0)
		label.Font = Theme.font.bold
		label.TextColor3 = Theme.color.textPrimary
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = Locale.t(item.labelKey)
		label.Parent = btn

		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Theme.color.accentDark
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Theme.color.panelLight
		end)
		btn.Activated:Connect(function()
			onTabSelected(item.id)
		end)
	end

	return frame
end

return NavBar
