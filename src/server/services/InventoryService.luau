--!strict
-- InventoryService — Lookups, Locking, Entfernen von Göttern aus dem Inventar.
-- Inventar selbst lebt im Profile (siehe PlayerDataService). Dieser Service ist
-- die zentrale Stelle für Mutationen, damit Locks/Replikation konsistent bleiben.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger).scope("Inventory")

local PlayerDataService = require(script.Parent.PlayerDataService)
local DefaultProfile = require(script.Parent.Parent.data.DefaultProfile)

export type GodEntry = DefaultProfile.GodEntry

local InventoryService = {}

function InventoryService.findByUid(player: Player, uid: string): GodEntry?
	local profile = PlayerDataService.get(player)
	if not profile then return nil end
	for _, entry in ipairs(profile.inventory.gods) do
		if entry.uid == uid then return entry end
	end
	return nil
end

-- Findet den Index-Slot einer UID im Inventar-Array.
local function indexOf(profile, uid: string): number?
	for i, entry in ipairs(profile.inventory.gods) do
		if entry.uid == uid then return i end
	end
	return nil
end

function InventoryService.remove(player: Player, uid: string): GodEntry?
	local profile = PlayerDataService.get(player)
	if not profile then return nil end
	local i = indexOf(profile, uid)
	if not i then return nil end
	local entry = table.remove(profile.inventory.gods, i)
	PlayerDataService.patchInventory(player)
	return entry
end

function InventoryService.setLock(player: Player, uid: string, locked: boolean): boolean
	local profile = PlayerDataService.get(player)
	if not profile then return false end
	for _, entry in ipairs(profile.inventory.gods) do
		if entry.uid == uid then
			entry.locked = locked
			PlayerDataService.patchInventory(player)
			return true
		end
	end
	return false
end

function InventoryService.countByGodId(player: Player, godId: string): number
	local profile = PlayerDataService.get(player)
	if not profile then return 0 end
	local count = 0
	for _, entry in ipairs(profile.inventory.gods) do
		if entry.id == godId and not entry.locked then count += 1 end
	end
	return count
end

Logger.info("InventoryService online.")

return InventoryService
