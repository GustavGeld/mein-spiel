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

	PlayerDataService.update(player, function(p)
		applyReset(p)
		p.lifetime.rebirths = (p.lifetime.rebirths or 0) + 1
		p.currencies.divinity = (p.currencies.divinity or 0) + gain
		-- Gamepass-Side-Effects nach dem Reset wiederherstellen
		if p.unlocks.gamepasses["extraSlots"] then
			for _ = 1, 3 do
				table.insert(p.temple.slots, { godUid = nil })
			end
		end
	end)

	-- replikiere alle betroffenen Bereiche
	PlayerDataService.patchEconomy(player)
	PlayerDataService.patchInventory(player)
	PlayerDataService.patchTemple(player)
	PlayerDataService.patchRebirth(player)

	Logger.info("%s rebirthed (+%d divinity, total %d rebirths)",
		player.Name, gain, profile.lifetime.rebirths)

	return { ok = true, gain = gain, rebirths = profile.lifetime.rebirths }
end

Logger.info("RebirthService online.")

return RebirthService
