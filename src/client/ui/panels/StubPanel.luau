--!strict
-- StubPanel — Platzhalter für Quests/Daily/Rewards bis Stage 4/Update 1 sie implementiert.

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local StubPanel = {}

function StubPanel.create(body: Instance, title: string, hint: string)
	local center = Instance.new("Frame")
	center.BackgroundTransparency = 1
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.new(0.8, 0, 0, 200)
	center.Parent = body

	local big = Instance.new("TextLabel")
	big.BackgroundTransparency = 1
	big.Size = UDim2.new(1, 0, 0, 80)
	big.Font = Theme.font.heading
	big.TextSize = 40
	big.TextColor3 = Theme.color.textPrimary
	big.Text = title
	big.Parent = center

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 90)
	sub.Size = UDim2.new(1, 0, 0, 60)
	sub.Font = Theme.font.body
	sub.TextSize = 16
	sub.TextColor3 = Theme.color.textSecondary
	sub.TextWrapped = true
	sub.Text = hint
	sub.Parent = center
end

return StubPanel
