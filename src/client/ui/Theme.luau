--!strict
-- Zentrales Theme: Farben, Schriften, Paddings.
-- Wenn du das Look-and-Feel anpassen willst, hier ändern — überall sonst nur referenzieren.

local Theme = {}

Theme.color = {
	bg = Color3.fromRGB(18, 20, 30),
	panel = Color3.fromRGB(28, 32, 46),
	panelLight = Color3.fromRGB(40, 46, 64),
	stroke = Color3.fromRGB(70, 80, 110),
	accent = Color3.fromRGB(120, 180, 255),
	accentDark = Color3.fromRGB(60, 110, 200),
	gold = Color3.fromRGB(255, 215, 80),
	faith = Color3.fromRGB(200, 230, 255),
	gems = Color3.fromRGB(120, 230, 200),
	offerings = Color3.fromRGB(255, 180, 120),
	divinity = Color3.fromRGB(255, 130, 230),
	textPrimary = Color3.fromRGB(245, 245, 250),
	textSecondary = Color3.fromRGB(180, 188, 210),
	textMuted = Color3.fromRGB(130, 138, 160),
	locked = Color3.fromRGB(120, 60, 60),
	unlocked = Color3.fromRGB(60, 120, 80),
	danger = Color3.fromRGB(220, 90, 90),
	success = Color3.fromRGB(90, 200, 120),
}

Theme.font = {
	heading = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	body = Enum.Font.Gotham,
	mono = Enum.Font.RobotoMono,
}

Theme.radius = {
	sm = UDim.new(0, 6),
	md = UDim.new(0, 10),
	lg = UDim.new(0, 16),
}

Theme.padding = {
	sm = 6,
	md = 10,
	lg = 16,
}

return Theme
