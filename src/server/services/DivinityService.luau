--!strict
-- DivinityService — Tree-Upgrades kaufen.
--   Remote: BuyUpgrade(branchId: string, nodeKey: string)  → { ok, level, spent, divinity }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Divinity")
local Net = require(Shared.remotes.Net)
local DivinityTree = require(Shared.config.DivinityTree)

local PlayerDataService = require(script.Parent.PlayerDataService)

local DivinityService = {}

function DivinityService.getLevel(profile: any, branchId: string, nodeKey: string): number
	return DivinityTree.getLevel(profile, branchId, nodeKey)
end

function DivinityService.priceFor(level: number, nodeDef): number
	return nodeDef.cost(level)
end

Net:Function("BuyUpgrade").OnServerInvoke = function(player: Player, branchId: any, nodeKey: any)
	if type(branchId) ~= "string" or type(nodeKey) ~= "string" then
		return { ok = false, reason = "bad_args" }
	end
	local nodeDef = DivinityTree.nodeByKey[branchId .. "." .. nodeKey]
	if not nodeDef then return { ok = false, reason = "unknown_node" } end

	local profile = PlayerDataService.get(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local current = DivinityTree.getLevel(profile, branchId, nodeKey)
	if current >= nodeDef.maxLevel then
		return { ok = false, reason = "max_level", level = current }
	end

	local price = nodeDef.cost(current)
	local divinity = profile.currencies.divinity or 0
	if divinity < price then
		return { ok = false, reason = "not_enough", price = price, have = divinity }
	end

	local newLevel = current + 1
	PlayerDataService.update(player, function(p)
		p.currencies.divinity = (p.currencies.divinity or 0) - price
		p.divinity.spent = (p.divinity.spent or 0) + price
		p.divinity.tree[branchId] = p.divinity.tree[branchId] or {}
		p.divinity.tree[branchId][nodeKey] = newLevel
	end)

	PlayerDataService.patchEconomy(player)
	PlayerDataService.patchRebirth(player)

	Logger.info("%s bought %s.%s → lvl %d (-%d divinity)",
		player.Name, branchId, nodeKey, newLevel, price)

	return { ok = true, level = newLevel, spent = price }
end

Logger.info("DivinityService online.")

return DivinityService
