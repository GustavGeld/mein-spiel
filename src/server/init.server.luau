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

-- Stage 4: Quests + Daily + Login
local QuestService = require(script.services.QuestService)
Logger.info("QuestService loaded.")

-- Stage 5: Rebirth + Divinity
local RebirthService = require(script.services.RebirthService)
local DivinityService = require(script.services.DivinityService)
Logger.info("Rebirth + Divinity services loaded.")

-- Stage 6: Fusion + Broadcast
local BroadcastService = require(script.services.BroadcastService)
local FusionService = require(script.services.FusionService)
Logger.info("Broadcast + Fusion services loaded.")

-- Stage 7: Gamepasses + Dev Products
local GamepassService = require(script.services.GamepassService)
Logger.info("GamepassService loaded.")

-- Stage 8: Trading
local TradeService = require(script.services.TradeService)
Logger.info("TradeService loaded.")

-- Test-/Admin-Chatbefehle (z. B. /money zum Geld geben)
local CommandService = require(script.services.CommandService)
Logger.info("CommandService loaded.")
-- TODO Stage 9: LeaderboardService, SeasonService
