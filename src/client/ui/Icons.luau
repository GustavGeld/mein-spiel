--!strict
-- Icon-Registry. Pro Slot:
--   assetId  → rbxassetid://<NUMMER>   (siehe assets/icons/nav/README.txt zum Hochladen)
--   fallback → Unicode-Symbol (rendert immer, auch ohne Asset)
--
-- So lange assetId == "rbxassetid://0" ist, wird der Emoji-Fallback genutzt.

export type Icon = { assetId: string, fallback: string }

local function icon(assetId: string, fallback: string): Icon
	return { assetId = assetId, fallback = fallback }
end

local Icons = {
	-- NavBar
	shop      = icon("rbxassetid://94339880607617", "🛒"),
	inventory = icon("rbxassetid://124654824560080", "🎒"),
	index     = icon("rbxassetid://132029669474372", "📖"),
	quests    = icon("rbxassetid://79779449589358", "✅"),
	daily     = icon("rbxassetid://71504174645040", "📅"),
	rewards   = icon("rbxassetid://72809142990849", "🎁"),
	trade     = icon("rbxassetid://98361262424095", "🔄"),
	fusion    = icon("rbxassetid://0", "⚡"),
	rebirth   = icon("rbxassetid://85540634188859", "♻"),
	gamepasses = icon("rbxassetid://0", "💎"),
	settings  = icon("rbxassetid://93700586176429", "⚙"),

	leaderboard = icon("rbxassetid://0", "🏆"),
	season      = icon("rbxassetid://0", "🌀"),
	auctions    = icon("rbxassetid://0", "🔨"),

	-- Währungen / Sonstiges
	gold      = icon("rbxassetid://0", "💵"),
	faith     = icon("rbxassetid://0", "✨"),
	offerings = icon("rbxassetid://0", "🕯"),
	gems      = icon("rbxassetid://0", "💎"),
	divinity  = icon("rbxassetid://0", "🌟"),
	lock      = icon("rbxassetid://0", "🔒"),
	filter    = icon("rbxassetid://0", "⛃"),
	sort      = icon("rbxassetid://0", "↕"),
	close     = icon("rbxassetid://84399223297180", "✕"),
}

return Icons
