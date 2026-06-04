--!strict
-- NavBar — 2 Reihen x 6 Spalten quadratischer Tiles im Cartoon-Stil.
-- Hellblauer Hintergrund, dunkelblauer Rand, Icon oben, Label unten.

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
	{ id = "gamepasses",labelKey = "nav.gamepasses",  icon = Icons.gamepasses},
	{ id = "leaderboard", labelKey = "nav.leaderboard", icon = Icons.leaderboard },
	{ id = "season",      labelKey = "nav.season",      icon = Icons.season      },
	{ id = "auctions",    labelKey = "nav.auctions",    icon = Icons.auctions    },
	{ id = "settings",    labelKey = "nav.settings",    icon = Icons.settings    },
}

local TILE        = 82
local SPACING     = 8
local ICON_SIZE   = 56
local CORNER      = UDim.new(0, 18)
local STROKE      = 3
local COLUMNS     = 2   -- 2 Spalten -> Tiles wachsen vertikal in zwei Bahnen

local TILE_FILL   = Color3.fromRGB(170, 215, 255)  -- hellblau
local TILE_HOVER  = Color3.fromRGB(200, 232, 255)
local TILE_BORDER = Color3.fromRGB(35, 70, 130)    -- dunkelblau
local LABEL_COLOR = Color3.fromRGB(20, 45, 90)

function NavBar.create(parent: Instance, onTabSelected: (id: string) -> ()): Frame
	local n = #NavBar.items
	local rows = math.ceil(n / COLUMNS)
	local width  = COLUMNS * TILE + (COLUMNS - 1) * SPACING
	local height = rows    * TILE + (rows    - 1) * SPACING

	local frame = Instance.new("Frame")
	frame.Name = "NavBar"
	-- Vertikal mittig auf der linken Seite — fühlt sich balancierter an als ganz unten.
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 18, 0.5, 0)
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	-- Grid-Layout statt vertikaler Spalte
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(TILE, TILE)
	grid.CellPadding = UDim2.fromOffset(SPACING, SPACING)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = COLUMNS
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = frame

	for index, item in ipairs(NavBar.items) do
		local btn = Instance.new("TextButton")
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = TILE_FILL
		btn.BorderSizePixel = 0
		btn.LayoutOrder = index
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

		-- Hover: nur Farb-Tween (UIGridLayout würde Size-Tweens überschreiben).
		local hoverTI = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, hoverTI, { BackgroundColor3 = TILE_HOVER }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, hoverTI, { BackgroundColor3 = TILE_FILL }):Play()
		end)
		btn.Activated:Connect(function() onTabSelected(item.id) end)
	end

	return frame
end

return NavBar
