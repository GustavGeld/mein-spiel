--!strict
-- DailyPanel — Login-Streak (7 Day Calendar) + Minute Reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Quests = require(Shared.config.Quests)
local Odds = require(Shared.math.Odds)

local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

local DailyPanel = {}

local MINUTE_INTERVAL = 60

local function rewardSymbol(reward): (string, Color3)
	if reward.currency == "gold" then return "$" .. Odds.formatBig(reward.amount), Theme.color.money
	elseif reward.currency == "gems" then return "💎 " .. Odds.formatBig(reward.amount), Theme.color.gems
	elseif reward.currency == "faith" then return "✨ " .. Odds.formatBig(reward.amount), Theme.color.faith
	else return tostring(reward.amount), Theme.color.textPrimary end
end

local function loginCalendar(parent: Instance, snapshot, onClaim: () -> ()): () -> ()
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.color.panelLight
	box.BorderSizePixel = 0
	box.Size = UDim2.new(1, 0, 0, 500)
	box.Parent = parent
	Util.corner(box, Theme.radius.md)
	Util.padding(box, Theme.padding.md)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Font = Theme.font.heading
	title.TextSize = 18
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = box

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 34)
	grid.Size = UDim2.new(1, 0, 0, 362)
	grid.Parent = box
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1/5, -5, 0, 56)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local claimBtn = Util.button(Locale.t("daily.loginClaim"), Theme.color.success)
	claimBtn.AnchorPoint = Vector2.new(0.5, 1)
	claimBtn.Position = UDim2.new(0.5, 0, 1, 0)
	claimBtn.Size = UDim2.fromOffset(220, 38)
	claimBtn.Parent = box

	local function getLoginState()
		local q = snapshot.quests or {}
		return {
			streak = (q.login and q.login.streak) or 0,
			claimed = (q.login and q.login.claimed) or false,
		}
	end

	local cells: { Frame } = {}
	for i = 1, #Quests.loginRewards do
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = Theme.color.panel
		cell.BorderSizePixel = 0
		cell.LayoutOrder = i
		cell.Parent = grid
		Util.corner(cell, Theme.radius.sm)

		local dayLbl = Instance.new("TextLabel")
		dayLbl.BackgroundTransparency = 1
		dayLbl.Size = UDim2.new(1, 0, 0, 14)
		dayLbl.Font = Theme.font.bold
		dayLbl.TextSize = 10
		dayLbl.TextColor3 = Theme.color.textSecondary
		dayLbl.Text = string.format(Locale.t("daily.next"), i)
		dayLbl.Parent = cell

		local symLbl = Instance.new("TextLabel")
		symLbl.BackgroundTransparency = 1
		symLbl.AnchorPoint = Vector2.new(0.5, 0.5)
		symLbl.Position = UDim2.fromScale(0.5, 0.60)
		symLbl.Size = UDim2.new(1, -4, 0, 28)
		symLbl.Font = Theme.font.heading
		symLbl.TextSize = 13
		local sym, col = rewardSymbol(Quests.loginRewards[i])
		symLbl.Text = sym
		symLbl.TextColor3 = col
		symLbl.TextScaled = false
		symLbl.TextWrapped = true
		symLbl.Parent = cell
		cells[i] = cell
	end

	local function refresh()
		local st = getLoginState()
		title.Text = string.format(Locale.t("daily.streak"), st.streak)
		for i, cell in ipairs(cells) do
			local streakDay = ((st.streak - 1) % #Quests.loginRewards) + 1
			if i == streakDay then
				cell.BackgroundColor3 = st.claimed and Theme.color.success or Theme.color.accent
			elseif i < streakDay then
				cell.BackgroundColor3 = Theme.color.panelLight
			else
				cell.BackgroundColor3 = Theme.color.panel
			end
		end
		if st.claimed then
			claimBtn.Text = Locale.t("daily.loginClaimed")
			claimBtn.AutoButtonColor = false
			claimBtn.BackgroundColor3 = Theme.color.locked
		else
			claimBtn.Text = Locale.t("daily.loginClaim")
			claimBtn.AutoButtonColor = true
			claimBtn.BackgroundColor3 = Theme.color.success
		end
	end

	claimBtn.Activated:Connect(function()
		if getLoginState().claimed then return end
		claimBtn.Text = "..."
		local result = Net:Function("ClaimLogin"):InvokeServer()
		if result and result.ok then
			snapshot.quests.login.claimed = true
			onClaim()
		end
		refresh()
	end)

	refresh()
	return refresh
end

local function minuteCard(parent: Instance, snapshot, onClaim: () -> ()): () -> ()
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.color.panelLight
	box.BorderSizePixel = 0
	box.Size = UDim2.new(1, 0, 0, 120)
	box.Parent = parent
	Util.corner(box, Theme.radius.md)
	Util.padding(box, Theme.padding.md)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Font = Theme.font.heading
	title.TextSize = 18
	title.TextColor3 = Theme.color.textPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Locale.t("daily.minuteTitle")
	title.Parent = box

	local rewardLbl = Instance.new("TextLabel")
	rewardLbl.BackgroundTransparency = 1
	rewardLbl.Position = UDim2.fromOffset(0, 30)
	rewardLbl.Size = UDim2.new(1, 0, 0, 30)
	rewardLbl.Font = Theme.font.bold
	rewardLbl.TextSize = 22
	local sym, col = rewardSymbol(Quests.minuteReward)
	rewardLbl.TextColor3 = col
	rewardLbl.Text = sym .. " per minute"
	rewardLbl.TextXAlignment = Enum.TextXAlignment.Left
	rewardLbl.Parent = box

	local btn = Util.button("...", Theme.color.success)
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, 0, 0.6, 0)
	btn.Size = UDim2.fromOffset(180, 42)
	btn.Parent = box

	local function getLastClaim(): number
		local q = snapshot.quests
		return (q and q.minute and q.minute.lastClaim) or 0
	end

	local function refresh()
		local remaining = math.max(0, MINUTE_INTERVAL - (os.time() - getLastClaim()))
		if remaining <= 0 then
			btn.Text = Locale.t("daily.minuteReady")
			btn.AutoButtonColor = true
			btn.BackgroundColor3 = Theme.color.success
		else
			btn.Text = string.format(Locale.t("daily.minuteCooldown"), remaining)
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Theme.color.panel
		end
	end

	btn.Activated:Connect(function()
		local remaining = math.max(0, MINUTE_INTERVAL - (os.time() - getLastClaim()))
		if remaining > 0 then return end
		btn.Text = "..."
		local result = Net:Function("ClaimMinute"):InvokeServer()
		if result and result.ok then
			snapshot.quests.minute.lastClaim = os.time()
			onClaim()
		end
		refresh()
	end)

	-- Auto-Refresh jede Sekunde (Cooldown-Anzeige)
	task.spawn(function()
		while box.Parent do
			task.wait(1)
			if not box.Parent then break end
			refresh()
		end
	end)

	refresh()
	return refresh
end

-- ─── Free Daily Roll Card ────────────────────────────────────────────────────

local function freeRollCard(parent: Instance, snapshot, onClaim: () -> ())
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Color3.fromRGB(20, 40, 28)
	box.BorderSizePixel = 0
	box.Size = UDim2.new(1, 0, 0, 72)
	box.Parent = parent
	Util.corner(box, Theme.radius.md)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 220, 90)
	stroke.Thickness = 2
	stroke.Parent = box

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(16, 0)
	lbl.Size = UDim2.new(0.6, 0, 1, 0)
	lbl.Font = Theme.font.bold
	lbl.TextSize = 16
	lbl.TextColor3 = Theme.color.textPrimary
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = Locale.t("daily.freeRoll")
	lbl.Parent = box

	local subLbl = Instance.new("TextLabel")
	subLbl.BackgroundTransparency = 1
	subLbl.Position = UDim2.fromOffset(16, 30)
	subLbl.Size = UDim2.new(0.6, 0, 0, 22)
	subLbl.Font = Theme.font.body
	subLbl.TextSize = 12
	subLbl.TextColor3 = Theme.color.textSecondary
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.Text = Locale.t("daily.freeRollDesc")
	subLbl.Parent = box

	local btn = Util.button(Locale.t("daily.freeRollBtn"), Color3.fromRGB(80, 200, 100))
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -12, 0.5, 0)
	btn.Size = UDim2.fromOffset(120, 36)
	btn.TextColor3 = Color3.fromRGB(20, 20, 30)
	btn.Parent = box

	-- Prüfe ob heute schon geclaimed
	local function refresh()
		local today = math.floor(os.time() / 86400)
		local freeRoll = snapshot.quests and snapshot.quests.freeRoll
		local lastDay = freeRoll and freeRoll.lastDay or 0
		if lastDay == today then
			btn.Text = Locale.t("daily.freeRollClaimed")
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = Theme.color.locked
		else
			btn.Text = Locale.t("daily.freeRollBtn")
			btn.AutoButtonColor = true
			btn.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
		end
	end

	btn.Activated:Connect(function()
		local today = math.floor(os.time() / 86400)
		local freeRoll = snapshot.quests and snapshot.quests.freeRoll
		if freeRoll and freeRoll.lastDay == today then return end

		btn.Text = "…"
		btn.AutoButtonColor = false
		local ok, result = pcall(function()
			return Net:Function("ClaimFreeRoll"):InvokeServer()
		end)
		if ok and result and result.ok then
			-- Snapshot updaten
			if snapshot.quests then
				snapshot.quests.freeRoll = snapshot.quests.freeRoll or { lastDay = 0 }
				snapshot.quests.freeRoll.lastDay = today
			end
			-- Pull-Ergebnis direkt triggern (gleich wie OpenPack)
			if result.results and #result.results > 0 then
				local pullEvt = Net:Event("OnPullResult")
				-- Client-seitig → wir feuern das Event simuliert (via RemoteEvent vom Server)
				-- Der Server hat bereits OnInventoryUpdate gesendet; kurze Toast-Meldung zeigen
				btn.Text = "✓ " .. (result.results[1] and result.results[1].rarityId or "?")
				btn.BackgroundColor3 = Theme.color.success
			else
				btn.Text = Locale.t("daily.freeRollClaimed")
				btn.BackgroundColor3 = Theme.color.locked
			end
			onClaim()
		else
			refresh()
		end
	end)

	refresh()
end

function DailyPanel.create(body: Instance, snapshot)
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.Parent = body
	Util.listLayout(list, Enum.FillDirection.Vertical, 12)

	local refreshLogin
	local refreshMinute

	refreshLogin = loginCalendar(list, snapshot, function() refreshLogin() end)
	refreshMinute = minuteCard(list, snapshot, function() refreshMinute() end)
	freeRollCard(list, snapshot, function() end)
end

return DailyPanel
