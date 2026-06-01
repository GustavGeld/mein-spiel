--!strict
-- Icon-Registry. Pro Slot zwei Werte:
--   assetId  → Roblox-Asset-ID, IDEAL aus dem Creator Store geladen
--             (Free Pick: z.B. "Material Icons", "Roblox UI Icons", "Phosphor Icons")
--             Suchwege im Studio:  Toolbox → Creator Store → "icons free" filter
--   fallback → Unicode-Symbol, das auch ohne Asset rendert
--
-- Standard ist die fallback-Variante. Sobald du Assets aus dem Creator Store importierst,
-- ersetze die "rbxassetid://0" Platzhalter durch die echte ID.

export type Icon = { assetId: string, fallback: string }

local function icon(assetId: string, fallback: string): Icon
	return { assetId = assetId, fallback = fallback }
end

local Icons = {
	shop      = icon("rbxassetid://0", "🛒"),
	inventory = icon("rbxassetid://0", "🎒"),
	index     = icon("rbxassetid://0", "📖"),
	quests    = icon("rbxassetid://0", "✅"),
	daily     = icon("rbxassetid://0", "📅"),
	rewards   = icon("rbxassetid://0", "🎁"),
	settings  = icon("rbxassetid://0", "⚙"),
	gold      = icon("rbxassetid://0", "🪙"),
	faith     = icon("rbxassetid://0", "✨"),
	offerings = icon("rbxassetid://0", "🕯"),
	gems      = icon("rbxassetid://0", "💎"),
	divinity  = icon("rbxassetid://0", "🌟"),
	lock      = icon("rbxassetid://0", "🔒"),
	filter    = icon("rbxassetid://0", "⛃"),
	sort      = icon("rbxassetid://0", "↕"),
	close     = icon("rbxassetid://0", "✕"),
}

return Icons
