--!strict
-- GodCard — eine Karte für einen einzelnen Gott im Inventory / Index.
-- Zeigt: Rarity-Farbe, Name, "1 in X" Wahrscheinlichkeit, Gold/sec, Faith/sec, Fusion-Rank.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Locale = require(Shared.locale.Locale)
local Odds = require(Shared.math.Odds)
local Rarities = require(Shared.config.Rarities)
local Gods = require(Shared.config.Gods)
local Packs = require(Shared.config.Packs)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local GodCard = {}

export type GodCardData = {
	uid: string?,              -- nil für Index/Collection-Einträge
	godId: string,
	rarityId: string,
	packTier: number,
	fusionRank: number?,
	secret: boolean?,
	discovered: boolean,        -- false für unentdeckte Index-Einträge → Silhouette
}

local function rarityProbability(packTier: number, rarityId: string): string
	-- Versuche zuerst Pack-Tier, dann Secret-Lookup.
	if rarityId:sub(1, 7) == "Secret_" then
		return Odds.displayOdds(packTier, rarityId)
	end
	return Odds.displayOdds(packTier, rarityId)
end

function GodCard.create(parent: Instance, data: GodCardData, onClick: (() -> ())?): TextButton
	local rarityDef = Rarities.byId[data.rarityId]
	local color = rarityDef and rarityDef.color or Theme.color.panelLight
	local godDef = Gods.byId[data.godId]

	local card = Instance.new("TextButton")
	card.AutoButtonColor = false
	card.BackgroundColor3 = Theme.color.panelLight
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(160, 200)
	card.Text = ""
	card.Parent = parent
	Util.corner(card, Theme.radius.md)
	local rarityStroke = Util.stroke(card, color, 3)

	-- Rarity-Streifen oben
	local rarityStrip = Instance.new("Frame")
	rarityStrip.BackgroundColor3 = color
	rarityStrip.BorderSizePixel = 0
	rarityStrip.Size = UDim2.new(1, 0, 0, 28)
	rarityStrip.Parent = card
	Util.corner(rarityStrip, Theme.radius.md)

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Size = UDim2.fromScale(1, 1)
	rarityLabel.Font = Theme.font.bold
	rarityLabel.TextSize = 14
	rarityLabel.TextColor3 = Color3.fromRGB(20, 20, 30)
	rarityLabel.Text = rarityDef and Locale.t(rarityDef.nameKey) or data.rarityId
	rarityLabel.Parent = rarityStrip

	-- Gott-Name
	local godName = Instance.new("TextLabel")
	godName.BackgroundTransparency = 1
	godName.Position = UDim2.fromOffset(8, 36)
	godName.Size = UDim2.new(1, -16, 0, 28)
	godName.Font = Theme.font.heading
	godName.TextSize = 16
	godName.TextColor3 = Theme.color.textPrimary
	godName.TextXAlignment = Enum.TextXAlignment.Left
	godName.Text = data.discovered and data.godId or "???"
	godName.Parent = card

	-- Wahrscheinlichkeit
	local odds = Instance.new("TextLabel")
	odds.BackgroundTransparency = 1
	odds.Position = UDim2.fromOffset(8, 64)
	odds.Size = UDim2.new(1, -16, 0, 22)
	odds.Font = Theme.font.bold
	odds.TextSize = 14
	odds.TextColor3 = color
	odds.TextXAlignment = Enum.TextXAlignment.Left
	odds.Text = rarityProbability(data.packTier, data.rarityId)
	odds.Parent = card

	-- Stats
	local statBox = Instance.new("Frame")
	statBox.BackgroundTransparency = 1
	statBox.Position = UDim2.fromOffset(8, 92)
	statBox.Size = UDim2.new(1, -16, 0, 64)
	statBox.Parent = card
	Util.listLayout(statBox, Enum.FillDirection.Vertical, 2)

	local function statRow(text: string, color3: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 18)
		l.Font = Theme.font.body
		l.TextSize = 13
		l.TextColor3 = color3
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = text
		l.Parent = statBox
	end

	if data.discovered and godDef then
		statRow(string.format("💰  %s/s", Odds.formatBig(godDef.baseProduction)), Theme.color.gold)
		statRow(string.format("✨  %s/s", Odds.formatBig(godDef.baseFaith)), Theme.color.faith)
		if data.fusionRank and data.fusionRank > 0 then
			statRow(string.format("⚡  Fusion %d", data.fusionRank), Theme.color.accent)
		end
	else
		statRow("???", Theme.color.textMuted)
	end

	-- Secret-Badge
	if data.secret then
		local badge = Instance.new("TextLabel")
		badge.BackgroundColor3 = Color3.fromRGB(255, 80, 200)
		badge.BorderSizePixel = 0
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -6, 0, 32)
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
