--!strict
-- RebirthService — verarbeitet RebirthConfirm.
--   - prüft Schwelle (Lifetime-Gold-Mechanik in unserer Variante: aktuelles Gold).
--   - errechnet Divinity-Reward.
--   - setzt selektive Felder zurück, behält Divinity/Gems/Cosmetics/Collection.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Rebirth")
local Net = require(Shared.remotes.Net)
local Rebirth = require(Shared.config.Rebirth)

local PlayerDataService = require(script.Parent.PlayerDataService)

local RebirthService = {}

local ECHO_MILESTONES: { [number]: boolean } = {
	[2]=true, [5]=true, [10]=true, [25]=true, [50]=true,
	[100]=true, [250]=true, [500]=true, [1000]=true,
}

function RebirthService.canRebirth(profile: any): boolean
	local gold = profile.currencies.gold or 0
	return gold >= Rebirth.threshold(profile.lifetime.rebirths or 0)
end

function RebirthService.preview(profile: any)
	local n = profile.lifetime.rebirths or 0
	local gold = profile.currencies.gold or 0
	return {
		rebirths     = n,
		gold         = gold,
		threshold    = Rebirth.threshold(n),
		divinityGain = Rebirth.divinityReward(n, gold),
	}
end

local function applyReset(profile: any)
	Rebirth.RESET.currencies(profile.currencies)
	Rebirth.RESET.inventory(profile.inventory)
	Rebirth.RESET.temple(profile.temple)
	Rebirth.RESET.unlocks(profile.unlocks)
	profile.pity = {}
end

Net:Function("RebirthConfirm").OnServerInvoke = function(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	if not RebirthService.canRebirth(profile) then
		return {
			ok = false,
			reason = "threshold",
			threshold = Rebirth.threshold(profile.lifetime.rebirths or 0),
		}
	end

	local gain = Rebirth.divinityReward(profile.lifetime.rebirths or 0, profile.currencies.gold or 0)
	local newRebirths = (profile.lifetime.rebirths or 0) + 1

	-- Eternal Gift: every 10th rebirth, save one random non-placed god
	local eternalGod: any = nil
	if newRebirths % 10 == 0 and #profile.inventory.gods > 0 then
		local placed: { [string]: boolean } = {}
		for _, slot in ipairs(profile.temple.slots) do
			if slot.godUid then placed[slot.godUid] = true end
		end
		local candidates: { any } = {}
		for _, entry in ipairs(profile.inventory.gods) do
			if not placed[entry.uid] then table.insert(candidates, entry) end
		end
		if #candidates > 0 then
			local rng = Random.new(os.clock() * 1e6 + player.UserId)
			eternalGod = candidates[rng:NextInteger(1, #candidates)]
		end
	end

	-- Echo of Faith: check if this rebirth hits a milestone
	local isEchoMilestone = ECHO_MILESTONES[newRebirths] == true

	PlayerDataService.update(player, function(p)
		applyReset(p)
		p.lifetime.rebirths = newRebirths
		p.currencies.divinity = (p.currencies.divinity or 0) + gain
		-- Gamepass-Side-Effects nach dem Reset wiederherstellen
		if p.unlocks.gamepasses["extraSlots"] then
			for _ = 1, 3 do
				table.insert(p.temple.slots, { godUid = nil })
			end
		end
		-- Temple tier: grows with total rebirths (every 3 rebirths = +1 tier, max 10)
		-- This is set AFTER applyReset so it overwrites the reset's tier=1
		p.temple.tier = math.min(10, 1 + math.floor(newRebirths / 3))

		-- Restore eternal god after reset
		if eternalGod then
			if not p.inventory.eternalGods then p.inventory.eternalGods = {} end
			table.insert(p.inventory.eternalGods, eternalGod)
			table.insert(p.inventory.gods, eternalGod)
		end
		-- Echo of Faith milestone
		if isEchoMilestone then
			if not p.divinity.echoStacks then p.divinity.echoStacks = 0 end
			p.divinity.echoStacks = p.divinity.echoStacks + 1
		end
	end)

	-- replikiere alle betroffenen Bereiche
	PlayerDataService.patchEconomy(player)
	PlayerDataService.patchInventory(player)
	PlayerDataService.patchTemple(player)
	PlayerDataService.patchRebirth(player)

	Logger.info("%s rebirthed (+%d divinity, total %d rebirths%s%s)",
		player.Name, gain, newRebirths,
		eternalGod and (", eternal=" .. eternalGod.id) or "",
		isEchoMilestone and ", echo+1" or "")

	-- Weekly Quest-Hook + Analytics
	task.defer(function()
		local s = script.Parent:FindFirstChild("QuestService")
		if s then
			local QS = require(s)
			if QS and QS.onRebirth then QS.onRebirth(player) end
		end
		local a = script.Parent:FindFirstChild("AnalyticsService")
		if a then
			local AS = require(a)
			if AS then AS.track("rebirth", { rebirths = profile.lifetime.rebirths }) end
		end
	end)

	return {
		ok = true,
		gain = gain,
		rebirths = newRebirths,
		eternalGodId = eternalGod and eternalGod.id or nil,
		echoUnlocked = isEchoMilestone,
		echoStacks = isEchoMilestone and ((profile.divinity.echoStacks or 0) + 1) or (profile.divinity.echoStacks or 0),
	}
end

Logger.info("RebirthService online.")

return RebirthService
