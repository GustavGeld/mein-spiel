--!strict
-- NavBar — vertikale Spalte quadratischer Tiles im Cartoon-Stil.
-- Cremiger Hintergrund, dicker brauner Rand, Icon oben, Label unten.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Util = require(script.Parent.Util)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared").locale.Locale)

export type NavItem = {
	id: string,
	labelKey: string,
	icon: { assetId: string, fallback: string },
}

local NavBar = {}

NavBar.items = {
	{ id = "shop",      labelKey = "nav.shop",        icon = Icons.shop      },
	{ id = "inventory", labelKey = "nav.inventory",   icon = Icons.inventory },
	{ id = "index",     labelKey = "nav.collection",  icon = Icons.index     },
	{ id = "quests",    labelKey = "nav.quests",      icon = Icons.quests    },
	{ id = "daily",     labelKey = "nav.daily",       icon = Icons.daily     },
	{ id = "rewards",   labelKey = "nav.rewards",     icon = Icons.rewards   },
	{ id = "trade",     labelKey = "nav.trade",       icon = Icons.trade     },
	{ id = "fusion",    labelKey = "nav.fusion",      icon = Icons.fusion    },
	{ id = "rebirth",   labelKey = "nav.rebirth",     icon = Icons.rebirth   },
	{ id = "settings",  labelKey = "nav.settings",    icon = Icons.settings  },
}

local TILE        = 82
local SPACING     = 8
local ICON_SIZE   = 56
local CORNER      = UDim.new(0, 18)
local STROKE      = 3

local TILE_FILL   = Color3.fromRGB(170, 215, 255)  -- hellblau
local TILE_HOVER  = Color3.fromRGB(200, 232, 255)
local TILE_BORDER = Color3.fromRGB(35, 70, 130)    -- dunkelblau
local LABEL_COLOR = Color3.fromRGB(20, 45, 90)

function NavBar.create(parent: Instance, onTabSelected: (id: string) -> ()): Frame
	local n = #NavBar.items
	local height = n * TILE + (n - 1) * SPACING

	local frame = Instance.new("Frame")
	frame.Name = "NavBar"
	frame.AnchorPoint = Vector2.new(0, 1)
	-- Über der Geld-Anzeige (~70px hoch inkl. padding) positionieren.
	frame.Position = UDim2.new(0, 18, 1, -90)
	frame.Size = UDim2.fromOffset(TILE, height)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	Util.listLayout(frame, Enum.FillDirection.Vertical, SPACING)

	for _, item in ipairs(NavBar.items) do
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = TILE_FILL
		btn.BorderSizePixel = 0
		btn.Size = UDim2.fromOffset(TILE, TILE)
		btn.Text = ""
		btn.Parent = frame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = CORNER
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = TILE_BORDER
		stroke.Thickness = STROKE
		stroke.Transparency = 0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		-- Icon zentriert, leicht nach oben verschoben um Platz fürs Label zu lassen
		local iconBox = Util.icon(item.icon, ICON_SIZE)
		iconBox.AnchorPoint = Vector2.new(0.5, 0.5)
		iconBox.Position = UDim2.new(0.5, 0, 0.5, -6)
		iconBox.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
		iconBox.Parent = btn
		-- Asset-Icons in Originalfarbe lassen (sonst werden sie weiß getintet).
		for _, child in ipairs(iconBox:GetChildren()) do
			if child:IsA("ImageLabel") then
				child.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end
		end

		-- Label unten
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -4)
		label.Size = UDim2.new(1, -8, 0, 16)
		label.Font = Theme.font.heading
		label.TextColor3 = LABEL_COLOR
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Bottom
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = Locale.t(item.labelKey)
		label.Parent = btn

		-- Hover: leicht aufhellen + minimal vergrößern, Click: kurz "drücken".
		local baseSize = UDim2.fromOffset(TILE, TILE)
		local hoverSize = UDim2.fromOffset(TILE + 4, TILE + 4)
		local hoverTI = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, hoverTI, { BackgroundColor3 = TILE_HOVER, Size = hoverSize }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, hoverTI, { BackgroundColor3 = TILE_FILL, Size = baseSize }):Play()
		end)
		btn.MouseButton1Down:Connect(function()
			btn.Size = UDim2.fromOffset(TILE - 2, TILE - 2)
		end)
		btn.MouseButton1Up:Connect(function()
			TweenService:Create(btn, hoverTI, { Size = baseSize }):Play()
		end)
		btn.Activated:Connect(function() onTabSelected(item.id) end)
	end

	return frame
end

return NavBar
