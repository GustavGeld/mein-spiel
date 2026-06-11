--!strict
-- Client bootstrap. Initialisiert Locale + UI + Roll-Animation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Logger = require(Shared.utils.Logger).scope("Client")
local Locale = require(Shared.locale.Locale)

-- Populate Gods.byId with event-exclusive gods so inventory/temple display works
local _EventGods = require(Shared.config.EventGods)

Logger.info("Booting Gods of Fate client…")
Locale.setLanguage("en")

-- HIER KORRIGIERT: Da 'controllers' EIN UNTERORDNER von diesem Skript ist, nutzen wir einfach 'script'
local Controllers = script:WaitForChild("controllers")

-- Alle Controller importieren
local UIController = require(Controllers:WaitForChild("UIController"))
local RollController = require(Controllers:WaitForChild("RollController"))
local AutoRollController = require(Controllers:WaitForChild("AutoRollController"))
local BroadcastController = require(Controllers:WaitForChild("BroadcastController"))
local WorldInteractionController = require(Controllers:WaitForChild("WorldInteractionController"))
local TempleDisplayController = require(Controllers:WaitForChild("TempleDisplayController"))
local TempleOrbsController = require(Controllers:WaitForChild("TempleOrbsController"))
local AscendController      = require(Controllers:WaitForChild("AscendController"))
local CompanionController   = require(Controllers:WaitForChild("CompanionController"))
local AuraController        = require(Controllers:WaitForChild("AuraController"))

-- Starte alle Controller
AscendController.start()
CompanionController.start()
AuraController.start()
UIController.start()
RollController.start()
BroadcastController.start()
WorldInteractionController.start()
TempleDisplayController.start()
TempleOrbsController.start()

-- AutoRollController benötigt keinen manuellen Start
local _ = AutoRollController

Logger.info("Client ready.")