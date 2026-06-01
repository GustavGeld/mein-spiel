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

UIController.start()
RollController.start()

Logger.info("Client ready.")
