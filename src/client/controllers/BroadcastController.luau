--!strict
-- BroadcastController — empfängt globale OnBroadcast und zeigt 4s Banner oben.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Rarities = require(Shared.config.Rarities)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BroadcastController = {}

local SHOW_TIME = 5
local active: { Frame } = {}

local function ensureScreen(): ScreenGui
	local sg = PlayerGui:FindFirstChild("BroadcastScreen")
	if sg then return sg :: ScreenGui end
	sg = Instance.new("ScreenGui")
	sg.Name = "BroadcastScreen"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 80
	sg.Parent = PlayerGui
	return sg
end

local function bannerColor(payload): Color3
	if payload.rarityColor then return payload.rarityColor end
	if payload.type == "secret" then return Color3.fromRGB(255, 80, 200) end
	if payload.type == "fusion" then return Color3.fromRGB(160, 110, 230) end
	if payload.type == "rare_pull" then return Color3.fromRGB(255, 200, 80) end
	return Color3.fromRGB(120, 180, 255)
end

local function bannerText(payload): string
	if payload.type == "secret" then
		return string.format("✨  %s just pulled a SECRET — %s!", payload.player or "?", payload.godId or "?")
	elseif payload.type == "fusion" then
		return string.format("⚡  %s fused %s to Rank %d!", payload.player or "?", payload.godId or "?", payload.rank or 0)
	elseif payload.type == "rare_pull" then
		return string.format("🏆  %s pulled %s!", payload.player or "?", payload.godId or "?")
	elseif payload.type == "text" then
		return tostring(payload.text)
	end
	return ""
end

local function reposition()
	for i, b in ipairs(active) do
		local target = UDim2.new(0.5, 0, 0, 24 + (i - 1) * 56)
		TweenService:Create(b, TweenInfo.new(0.25), { Position = target }):Play()
	end
end

local function show(payload)
	local sg = ensureScreen()
	local color = bannerColor(payload)

	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -80)
	banner.Size = UDim2.fromOffset(540, 48)
	banner.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	banner.BorderSizePixel = 0
	banner.Parent = sg

	local corner = Instance.new("UICorner", banner)
	corner.CornerRadius = UDim.new(0, 14)
	local stroke = Instance.new("UIStroke", banner)
	stroke.Color = color
	stroke.Thickness = 2

	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(0, 6, 1, 0)
	accent.Parent = banner
	local ac = Instance.new("UICorner", accent)
	ac.CornerRadius = UDim.new(0, 14)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 16, 0.5, 0)
	label.Size = UDim2.new(1, -28, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = bannerText(payload)
	label.Parent = banner

	table.insert(active, 1, banner)
	if #active > 4 then
		local last = table.remove(active)
		if last then last:Destroy() end
	end
	reposition()

	task.delay(SHOW_TIME, function()
		for i, b in ipairs(active) do
			if b == banner then table.remove(active, i); break end
		end
		TweenService:Create(banner, TweenInfo.new(0.3),
			{ Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		task.delay(0.3, function() banner:Destroy() end)
		reposition()
	end)
end

function BroadcastController.start()
	Net:Event("OnBroadcast").OnClientEvent:Connect(function(payload)
		if not payload then return end
		show(payload)
	end)
end

return BroadcastController
