--!strict
-- Client bootstrap. Initialisiert Locale + UI + Roll-Animation.
-- Alte Controller (HUD/Shop/Temple Standalone) wurden durch UIController ersetzt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Client")
local Locale = require(Shared.locale.Locale)

Logger.info("Booting Gods of Fate client…")
Locale.setLanguage("en")

local UIController = require(script.controllers.UIController)
local RollController = require(script.controllers.RollController)
local AutoRollController = require(script.controllers.AutoRollController)
local BroadcastController = require(script.controllers.BroadcastController)
local WorldInteractionController = require(script.controllers.WorldInteractionController)
local TempleDisplayController = require(script.controllers.TempleDisplayController)

UIController.start()
RollController.start()
BroadcastController.start()
WorldInteractionController.start()
TempleDisplayController.start()
-- AutoRollController hat keine start()-Methode; bloßes require initialisiert das Modul.
local _ = AutoRollController

Logger.info("Client ready.")
