--!strict
-- SeasonPanel — Aktuelle Saison: Rang, Score, Reward-Tiers, Claim-Button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared.locale.Locale)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)
local Seasons = require(Shared.config.Seasons)
local LeaderboardController = require(script.Parent.Parent.Parent.controllers.LeaderboardController)

local SeasonPanel = {}

local TIER_COLORS = {
	["season.tier.champion"] = Color3.fromRGB(255, 215, 60),
	["season.tier.legend"]   = Color3.fromRGB(200, 200, 220),
	["season.tier.elite"]    = Color3.fromRGB(205, 127, 50),
	["season.tier.veteran"]  = Color3.fromRGB(120, 200, 150),
	["season.tier.rival"]    = Color3.fromRGB(120, 160, 220),
}

local function fmtTime(secs: number): string
	return Seasons.formatTime(secs)
end

local function fmtScore(n: number): string
	if n >= 1e6 then return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then return string.format("%.1fk", n / 1e3)
	else return tostring(math.floor(n)) end
end

function SeasonPanel.create(body: Instance, snapshot: any)
	local root = Instance.new("ScrollingFrame")
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.CanvasSize = UDim2.new()
	root.AutomaticCanvasSize = Enum.AutomaticSize.Y
	root.ScrollBarThickness = 4
	root.Parent = body
	Util.listLayout(root, Enum.FillDirection.Vertical, 12)
	Util.padding(root, 12)

	-- ── Saison-Header ─────────────────────────────────────────────────────────

	local headerCard = Instance.new("Frame")
	headerCard.BackgroundColor3 = Theme.color.panelLight
	headerCard.BorderSizePixel = 0
	headerCard.Size = UDim2.new(1, 0, 0, 80)
	headerCard.Parent = root
	Util.corner(headerCard, Theme.radius.md)
	Util.stroke(headerCard, Theme.color.accent, 2)

	local seasonData = LeaderboardController.seasonData
	local currentId = (seasonData and seasonData.id) or Seasons.currentId()
	local secsLeft = (seasonData and seasonData.secs) or Seasons.secondsRemaining()

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Position = UDim2.fromOffset(16, 12)
	titleLbl.Size = UDim2.new(1, -32, 0, 28)
	titleLbl.Font = Theme.font.heading
	titleLbl.TextSize = 22
	titleLbl.TextColor3 = Theme.color.accent
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = string.format(Locale.t("season.current"), currentId)
	titleLbl.Parent = headerCard

	local timeLbl = Instance.new("TextLabel")
	timeLbl.BackgroundTransparency = 1
	timeLbl.Position = UDim2.fromOffset(16, 42)
	timeLbl.Size = UDim2.new(1, -32, 0, 22)
	timeLbl.Font = Theme.font.body
	timeLbl.TextSize = 14
	timeLbl.TextColor3 = Theme.color.textSecondary
	timeLbl.TextXAlignment = Enum.TextXAlignment.Left
	timeLbl.Text = string.format(Locale.t("season.ends"), fmtTime(secsLeft))
	timeLbl.Parent = headerCard

	-- ── Eigener Rang & Score ──────────────────────────────────────────────────

	local myCard = Instance.new("Frame")
	myCard.BackgroundColor3 = Color3.fromRGB(30, 40, 28)
	myCard.BorderSizePixel = 0
	myCard.Size = UDim2.new(1, 0, 0, 64)
	myCard.Parent = root
	Util.corner(myCard, Theme.radius.md)
	Util.stroke(myCard, Theme.color.gold, 1.5)

	local myRankLbl = Instance.new("TextLabel")
	myRankLbl.BackgroundTransparency = 1
	myRankLbl.Position = UDim2.fromOffset(16, 8)
	myRankLbl.Size = UDim2.new(0.5, -16, 0, 24)
	myRankLbl.Font = Theme.font.heading
	myRankLbl.TextSize = 18
	myRankLbl.TextColor3 = Theme.color.gold
	myRankLbl.TextXAlignment = Enum.TextXAlignment.Left
	myRankLbl.Text = Locale.t("season.loading")
	myRankLbl.Parent = myCard

	local myScoreLbl = Instance.new("TextLabel")
	myScoreLbl.BackgroundTransparency = 1
	myScoreLbl.AnchorPoint = Vector2.new(1, 0)
	myScoreLbl.Position = UDim2.new(1, -16, 0, 8)
	myScoreLbl.Size = UDim2.fromOffset(160, 24)
	myScoreLbl.Font = Theme.font.bold
	myScoreLbl.TextSize = 16
	myScoreLbl.TextColor3 = Theme.color.textPrimary
	myScoreLbl.TextXAlignment = Enum.TextXAlignment.Right
	myScoreLbl.Text = ""
	myScoreLbl.Parent = myCard

	local mySubLbl = Instance.new("TextLabel")
	mySubLbl.BackgroundTransparency = 1
	mySubLbl.Position = UDim2.fromOffset(16, 36)
	mySubLbl.Size = UDim2.new(1, -32, 0, 20)
	mySubLbl.Font = Theme.font.body
	mySubLbl.TextSize = 13
	mySubLbl.TextColor3 = Theme.color.textMuted
	mySubLbl.TextXAlignment = Enum.TextXAlignment.Left
	mySubLbl.Text = Locale.t("season.yourRank") .. " · " .. Locale.t("season.yourScore")
	mySubLbl.Parent = myCard

	-- Rang asynchron ermitteln (Server-Abfrage)
	task.spawn(function()
		local result = LeaderboardController.fetchPage("season", 1)
		-- Rang via eigene UserId suchen
		local myId = game:GetService("Players").LocalPlayer.UserId
		local myRank: number? = nil
		-- Nicht `score or calcScore` verwenden — 0 ist falsy in Lua!
		local myScore: number
		if seasonData and seasonData.score ~= nil then
			myScore = seasonData.score
		else
			local lt = (snapshot and snapshot.lifetime) or {}
			myScore = Seasons.calcScore({ pulls = lt.pulls or 0, rebirths = lt.rebirths or 0 })
		end

		if result and result.entries then
			-- Suche eigenen Eintrag in Seite 1; falls nicht dort, rank bleibt nil
			for _, entry in ipairs(result.entries) do
				if entry.userId == myId then
					myRank = entry.rank
					myScore = entry.score
					break
				end
			end
		end

		if myRankLbl and myRankLbl.Parent then
			if myRank then
				myRankLbl.Text = string.format(Locale.t("season.rankN"), myRank)
			else
				myRankLbl.Text = Locale.t("season.notEligible")
			end
		end
		if myScoreLbl and myScoreLbl.Parent then
			myScoreLbl.Text = string.format(Locale.t("season.score"), fmtScore(myScore))
		end
	end)

	-- ── Reward-Tiers Tabelle ──────────────────────────────────────────────────

	local tierHeader = Instance.new("TextLabel")
	tierHeader.BackgroundTransparency = 1
	tierHeader.Size = UDim2.new(1, 0, 0, 24)
	tierHeader.Font = Theme.font.heading
	tierHeader.TextSize = 16
	tierHeader.TextColor3 = Theme.color.accent
	tierHeader.TextXAlignment = Enum.TextXAlignment.Left
	tierHeader.Text = Locale.t("season.rewards")
	tierHeader.Parent = root

	for _, tier in ipairs(Seasons.rewardTiers) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.color.panelLight
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 44)
		row.Parent = root
		Util.corner(row, Theme.radius.sm)

		local accent = Instance.new("Frame")
		accent.BackgroundColor3 = TIER_COLORS[tier.labelKey] or Theme.color.accent
		accent.BorderSizePixel = 0
		accent.Size = UDim2.fromOffset(6, 44)
		accent.Parent = row
		Util.corner(accent, Theme.radius.sm)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position = UDim2.fromOffset(20, 0)
		nameLbl.Size = UDim2.new(0.6, -20, 1, 0)
		nameLbl.Font = Theme.font.bold
		nameLbl.TextSize = 15
		nameLbl.TextColor3 = TIER_COLORS[tier.labelKey] or Theme.color.textPrimary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Text = Locale.t(tier.labelKey)
		nameLbl.Parent = row

		local rewardLbl = Instance.new("TextLabel")
		rewardLbl.BackgroundTransparency = 1
		rewardLbl.AnchorPoint = Vector2.new(1, 0.5)
		rewardLbl.Position = UDim2.new(1, -14, 0.5, 0)
		rewardLbl.Size = UDim2.fromOffset(120, 30)
		rewardLbl.Font = Theme.font.heading
		rewardLbl.TextSize = 16
		rewardLbl.TextColor3 = Theme.color.gems
		rewardLbl.TextXAlignment = Enum.TextXAlignment.Right
		rewardLbl.Text = string.format("💎 %d Gems", tier.gems)
		rewardLbl.Parent = row
	end

	-- ── Claim-Button ──────────────────────────────────────────────────────────

	local claimed = (seasonData and seasonData.claimed) or
		(snapshot and snapshot.season and snapshot.season.claimed) or false

	local claimBtn = Util.button(
		claimed and Locale.t("season.claimed") or Locale.t("season.claim"),
		claimed and Theme.color.locked or Theme.color.gold
	)
	claimBtn.Size = UDim2.new(1, 0, 0, 48)
	claimBtn.Font = Theme.font.heading
	claimBtn.TextSize = 18
	claimBtn.TextColor3 = claimed and Theme.color.textMuted or Color3.fromRGB(20, 20, 30)
	claimBtn.AutoButtonColor = not claimed
	claimBtn.Parent = root

	if not claimed then
		claimBtn.Activated:Connect(function()
			claimBtn.Text = "…"
			claimBtn.AutoButtonColor = false

			local result = LeaderboardController.claimSeasonReward()
			if result and result.ok then
				claimBtn.Text = string.format("✓ " .. Locale.t("season.claimed") .. "  (+%d 💎)", result.gems or 0)
				claimBtn.BackgroundColor3 = Theme.color.locked
				claimBtn.TextColor3 = Theme.color.textMuted
			elseif result and result.reason == "not_eligible" then
				claimBtn.Text = Locale.t("season.notEligible")
				claimBtn.BackgroundColor3 = Theme.color.locked
			elseif result and result.reason == "already_claimed" then
				claimBtn.Text = Locale.t("season.claimed")
				claimBtn.BackgroundColor3 = Theme.color.locked
			else
				-- Fehler → kurz anzeigen, dann zurücksetzen
				claimBtn.Text = "⚠ Error"
				task.delay(2, function()
					if claimBtn and claimBtn.Parent then
						claimBtn.Text = Locale.t("season.claim")
						claimBtn.AutoButtonColor = true
					end
				end)
			end
		end)
	end

	-- SeasonData Live-Update (wenn sich Saison ändert während Panel offen)
	local conn = LeaderboardController.SeasonChanged:Connect(function(data)
		if titleLbl and titleLbl.Parent then
			titleLbl.Text = string.format(Locale.t("season.current"), data.id)
		end
		if timeLbl and timeLbl.Parent then
			timeLbl.Text = string.format(Locale.t("season.ends"), fmtTime(data.secs))
		end
	end)

	-- Verbindung beim Schließen trennen (root Destroyed)
	root.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

return SeasonPanel
