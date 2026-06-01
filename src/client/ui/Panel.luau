--!strict
-- Panel-Container: dunkler Card-Hintergrund, Header mit Titel + Close-Button, Body.
-- Wird vom UIController positioniert (Center-Mitte).

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Icons = require(script.Parent.Icons)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared").locale.Locale)

local Panel = {}

export type PanelHandle = {
	root: Frame,
	body: Frame,
	setTitle: (string) -> (),
	destroy: () -> (),
}

function Panel.create(parent: Instance, titleText: string, onClose: () -> ()): PanelHandle
	local root = Instance.new("Frame")
	root.Name = "Panel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(720, 480)
	root.BackgroundColor3 = Theme.color.panel
	root.BackgroundTransparency = 0.05
	root.BorderSizePixel = 0
	root.Parent = parent
	Util.corner(root, Theme.radius.lg)
	Util.stroke(root)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 52)
	header.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0, 0.5)
	title.Position = UDim2.new(0, 20, 0.5, 0)
	title.Size = UDim2.new(1, -80, 1, 0)
	title.Font = Theme.font.heading
	title.TextSize = 24
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(36, 36)
	closeBtn.BackgroundColor3 = Theme.color.panelLight
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Theme.font.heading
	closeBtn.TextSize = 22
	closeBtn.TextColor3 = Theme.color.textPrimary
	closeBtn.Text = Icons.close.fallback
	closeBtn.Parent = header
	Util.corner(closeBtn, Theme.radius.sm)

	closeBtn.Activated:Connect(onClose)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 52)
	body.Size = UDim2.new(1, 0, 1, -52)
	body.Parent = root
	Util.padding(body, Theme.padding.md)

	return {
		root = root,
		body = body,
		setTitle = function(t: string) title.Text = t end,
		destroy = function() root:Destroy() end,
	}
end

return Panel
