--!strict
-- Server bootstrap. Lädt Services in deterministischer Reihenfolge.
-- Echte Service-Implementierungen folgen Stage-für-Stage (siehe IMPLEMENTATION_ROADMAP.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Bootstrap")
local Net = require(Shared.remotes.Net)

Logger.info("Booting Gods of Fate server…")

-- Erzeuge Remote-Folder + Stubs früh, damit Client beim Join wartefähig ist.
Net:Function("RequestProfile")
Net:Event("OnEconomyUpdate")
Net:Event("OnInventoryUpdate")
Net:Event("OnPullResult")
Net:Event("OnBroadcast")

Logger.info("Remote skeleton ready.")

-- Stage 1: Player data persistence
local PlayerDataService = require(script.services.PlayerDataService)
Logger.info("PlayerDataService loaded.")

-- Stage 2: Economy + Packs
local EconomyService = require(script.services.EconomyService)
local PackService = require(script.services.PackService)
Logger.info("Economy + Pack services loaded.")

-- Stage 3: Inventory + Temple
local InventoryService = require(script.services.InventoryService)
local TempleService = require(script.services.TempleService)
Logger.info("Inventory + Temple services loaded.")
-- TODO Stage 3: InventoryService, TempleService
-- TODO Stage 5: RebirthService, DivinityService
-- TODO Stage 6: FusionService, BroadcastService
-- TODO Stage 7: GamepassService
-- TODO Stage 8: TradeService
-- TODO Stage 9: LeaderboardService, SeasonService
