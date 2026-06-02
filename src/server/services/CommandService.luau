--!strict
-- CommandService — Test-/Admin-Chatbefehle.
--   /money 1000          → +1000  (Shortcut für /money add 1000)
--   /money add 1000      → +1000
--   /money add -500      → -500
--   /money set 250000    → setzt absolut
--   Aliase:  /givemoney, /cash
--
-- In Studio immer aktiv. Im Live-Spiel nur für UserIds in ADMINS.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Command")

local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CommandService = {}

-- UserIds, die Chatbefehle außerhalb von Studio nutzen dürfen.
local ADMINS: { [number]: boolean } = {
	-- [123456789] = true,
}

local DEFAULT_MONEY = 1000

local function canUse(player: Player): boolean
	if RunService:IsStudio() then return true end
	return ADMINS[player.UserId] == true
end

-- Setzt Gold direkt auf einen absoluten Wert.
local function setGold(player: Player, value: number)
	value = math.max(0, math.floor(value))
	PlayerDataService.update(player, function(profile)
		profile.currencies.gold = value
	end)
	PlayerDataService.patchEconomy(player)
end

local function handleMoney(player: Player, rest: string)
	local sub, valueStr = rest:match("^(%a+)%s+(-?%d+)$")
	if sub == "set" then
		local n = tonumber(valueStr)
		if not n then return end
		setGold(player, n)
		Logger.info("%s set money = %d", player.Name, math.floor(n))
		return
	elseif sub == "add" then
		local n = tonumber(valueStr)
		if not n then return end
		EconomyService.add(player, "gold", math.floor(n))
		Logger.info("%s added %d money", player.Name, math.floor(n))
		return
	end

	-- Fallback: nackte Zahl = add
	local n = tonumber(rest) or DEFAULT_MONEY
	n = math.floor(n)
	if n == 0 then return end
	EconomyService.add(player, "gold", n)
	Logger.info("%s added %d money", player.Name, n)
end

local function handle(player: Player, message: string)
	if not canUse(player) then return end
	local cmd, rest = message:lower():match("^/(%S+)%s*(.*)$")
	if not cmd then return end

	if cmd == "money" or cmd == "givemoney" or cmd == "cash" then
		handleMoney(player, rest)
	end
end

local function onJoin(player: Player)
	player.Chatted:Connect(function(message)
		handle(player, message)
	end)
end

Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do
	onJoin(player)
end

Logger.info("CommandService online (studio=%s).", tostring(RunService:IsStudio()))

return CommandService
