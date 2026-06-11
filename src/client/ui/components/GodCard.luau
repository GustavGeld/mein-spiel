--!strict
-- GodCard — eine Karte für einen einzelnen Gott im Inventory / Index / Reveal.
-- Layout: Rarity-Streifen oben → großes Icon → Name → "1 in X" → Stats unten.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Locale = require(Shared.locale.Locale)
local Odds = require(Shared.math.Odds)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local GodCard = {}

export type GodCardData = {
	uid: string?,
	godId: string,
	rarityId: string,
	packTier: number,
	fusionRank: number?,
	secret: boolean?,
	discovered: boolean,
	cardSize: Vector2?,   -- optional override (default 160 x 220)
}

-- Initial-Buchstabe aus z.B. "Hermes_Apprentice" → "H"
local function initialOf(id: string): string
	return string.upper(string.sub(id, 1, 1))
end

-- Hellt eine Farbe für den Card-Body auf (gemischter Pastell-Hintergrund).
local function tinted(c: Color3, mix: number): Color3
	return Color3.new(
		c.R * mix + Theme.color.panel.R * (1 - mix),
		c.G * mix + Theme.color.panel.G * (1 - mix),
		c.B * mix + Theme.color.panel.B * (1 - mix)
	)
end

local function displayName(id: string): string
	if Locale.has("god." .. id) then
		return Locale.t("god." .. id)
	end
	return (string.gsub(id, "_", " "))
end

function GodCard.create(parent: Instance, data: GodCardData, onClick: (() -> ())?): TextButton
	local rarityDef = Rarities.byId[data.rarityId]
	local color = rarityDef and rarityDef.color or Theme.color.panelLight
	local godDef = Gods.byId[data.godId]

	local cardSize = data.cardSize or Vector2.new(160, 220)
	local W, H = cardSize.X, cardSize.Y

	-- Proportionale Layout-Größen, damit größere Karten auch ein größeres PNG bekommen.
	local STRIP_H   = math.floor(H * 0.11)
	local ICON_TOP  = STRIP_H + math.floor(H * 0.04)
	local ICON_SIZE = math.floor(math.min(W * 0.78, H * 0.52))
	local NAME_Y    = ICON_TOP + ICON_SIZE + math.floor(H * 0.025)
	local NAME_H    = math.floor(H * 0.10)
	local ODDS_Y    = NAME_Y + NAME_H
	local ODDS_H    = math.floor(H * 0.08)
	local STATS_Y   = ODDS_Y + ODDS_H + 2
	local STATS_H   = H - STATS_Y - 6

	local card = Instance.new("TextButton")
	card.AutoButtonColor = false
	card.BackgroundColor3 = tinted(color, 0.15)
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(W, H)
	card.Text = ""
	card.AutoLocalize = false
	card.Parent = parent
	Util.corner(card, Theme.radius.md)
	Util.stroke(card, color, 3)

	-- Rarity-Streifen oben
	local rarityStrip = Instance.new("Frame")
	rarityStrip.BackgroundColor3 = color
	rarityStrip.BorderSizePixel = 0
	rarityStrip.Size = UDim2.new(1, 0, 0, STRIP_H)
	rarityStrip.Parent = card
	Util.corner(rarityStrip, Theme.radius.md)

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Size = UDim2.fromScale(1, 1)
	rarityLabel.Font = Theme.font.bold
	rarityLabel.TextSize = math.floor(STRIP_H * 0.62)
	rarityLabel.TextColor3 = Color3.fromRGB(20, 20, 30)
	rarityLabel.Text = rarityDef and Locale.t(rarityDef.nameKey) or data.rarityId
	rarityLabel.Parent = rarityStrip

	-- Icon-Bühne — füllt jetzt deutlich mehr von der Karte aus.
	local iconWell = Instance.new("Frame")
	iconWell.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	iconWell.BackgroundTransparency = 0.85
	iconWell.BorderSizePixel = 0
	iconWell.AnchorPoint = Vector2.new(0.5, 0)
	iconWell.Position = UDim2.new(0.5, 0, 0, ICON_TOP)
	iconWell.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	iconWell.Parent = card
	Util.corner(iconWell, UDim.new(0.18, 0))

	local hasIcon = data.discovered and godDef and godDef.iconAssetId and godDef.iconAssetId ~= ""
	if hasIcon then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.94, 0.94)
		img.Image = godDef.iconAssetId :: string
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = iconWell
	else
		local fallback = Instance.new("TextLabel")
		fallback.BackgroundTransparency = 1
		fallback.Size = UDim2.fromScale(1, 1)
		fallback.Font = Theme.font.heading
		fallback.TextSize = math.floor(ICON_SIZE * 0.6)
		fallback.TextColor3 = data.discovered and color or Theme.color.textMuted
		fallback.Text = data.discovered and initialOf(data.godId) or "?"
		fallback.Parent = iconWell
	end

	-- Gott-Name
	local godName = Instance.new("TextLabel")
	godName.BackgroundTransparency = 1
	godName.Position = UDim2.fromOffset(8, NAME_Y)
	godName.Size = UDim2.new(1, -16, 0, NAME_H)
	godName.Font = Theme.font.heading
	godName.TextSize = math.floor(NAME_H * 0.72)
	godName.TextColor3 = Theme.color.textPrimary
	godName.TextTruncate = Enum.TextTruncate.AtEnd
	godName.TextXAlignment = Enum.TextXAlignment.Center
	godName.Text = data.discovered and displayName(data.godId) or "???"
	godName.Parent = card

	-- Wahrscheinlichkeit
	local odds = Instance.new("TextLabel")
	odds.BackgroundTransparency = 1
	odds.Position = UDim2.fromOffset(8, ODDS_Y)
	odds.Size = UDim2.new(1, -16, 0, ODDS_H)
	odds.Font = Theme.font.bold
	odds.TextSize = math.floor(ODDS_H * 0.7)
	odds.TextColor3 = color
	odds.TextXAlignment = Enum.TextXAlignment.Center
	odds.Text = Odds.displayOdds(data.packTier, data.rarityId)
	odds.Parent = card

	-- Stats
	local statBox = Instance.new("Frame")
	statBox.BackgroundTransparency = 1
	statBox.Position = UDim2.fromOffset(8, STATS_Y)
	statBox.Size = UDim2.new(1, -16, 0, STATS_H)
	statBox.Parent = card

	local STAT_LINE = math.floor(STATS_H / 2)
	local function statRow(text: string, color3: Color3, y: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, STAT_LINE)
		l.Font = Theme.font.bold
		l.TextSize = math.floor(STAT_LINE * 0.78)
		l.TextColor3 = color3
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.Text = text
		l.Parent = statBox
	end

	if data.discovered and godDef then
		statRow(string.format("$%s/s", Odds.formatBig(godDef.baseProduction)), Theme.color.money, 0)
		if godDef.baseFaith > 0 then
			statRow(string.format("✨ %s/s", Odds.formatBig(godDef.baseFaith)), Theme.color.faith, STAT_LINE)
		end
		if data.fusionRank and data.fusionRank > 0 then
			statRow(string.format("⚡ Fusion %d", data.fusionRank), Theme.color.accent, STAT_LINE)
		end
	else
		statRow("???", Theme.color.textMuted, 0)
	end

	-- Secret-Badge
	if data.secret then
		local badge = Instance.new("TextLabel")
		badge.BackgroundColor3 = Color3.fromRGB(255, 80, 200)
		badge.BorderSizePixel = 0
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -6, 0, 28)
		badge.Size = UDim2.fromOffset(60, 18)
		badge.Font = Theme.font.bold
		badge.TextSize = 11
		badge.TextColor3 = Color3.fromRGB(255, 255, 255)
		badge.Text = "SECRET"
		badge.Parent = card
		Util.corner(badge, Theme.radius.sm)
	end

	if onClick then
		card.Activated:Connect(onClick)
	end

	return card
end

return GodCard
