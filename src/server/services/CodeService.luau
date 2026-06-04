--!strict
-- CodeService — validiert und löst Einlösecodes ein.
-- Codes sind server-seitig definiert (src/server/data/Codes.luau).
-- Idempotenz: profile.social.codesRedeemed[code] = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Codes")
local Net = require(Shared.remotes.Net)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimit = require(script.Parent.Parent.security.RateLimit)

local Codes = require(script.Parent.Parent.data.Codes)

Net:Function("RedeemCode").OnServerInvoke = function(player: Player, rawCode: string)
	if type(rawCode) ~= "string" then return { ok = false, reason = "invalid" } end
	if not RateLimit.consume(player, "RedeemCode", 5, 60) then
		return { ok = false, reason = "rate_limit" }
	end

	-- Case-insensitive + trim
	local code = rawCode:upper():match("^%s*(.-)%s*$") or rawCode:upper()

	local reward = Codes[code]
	if not reward then
		return { ok = false, reason = "invalid_code" }
	end

	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	if profile.social.codesRedeemed and profile.social.codesRedeemed[code] then
		return { ok = false, reason = "already_redeemed" }
	end

	-- Code als eingelöst markieren
	PlayerDataService.update(player, function(p)
		if not p.social.codesRedeemed then p.social.codesRedeemed = {} end
		p.social.codesRedeemed[code] = true
	end)

	-- Rewards verteilen
	if reward.gold and reward.gold > 0 then
		EconomyService.add(player, "gold", reward.gold)
	end
	if reward.gems and reward.gems > 0 then
		EconomyService.add(player, "gems", reward.gems)
	end
	if reward.faith and reward.faith > 0 then
		EconomyService.add(player, "faith", reward.faith)
	end

	Logger.info("%s redeemed code %s", player.Name, code)
	return { ok = true, reward = reward }
end

Logger.info("CodeService online (%d codes).", (function()
	local n = 0; for _ in pairs(Codes) do n += 1 end; return n
end)())

return {}
