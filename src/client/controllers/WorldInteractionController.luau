--!strict
-- WorldInteractionController — bindet die ProximityPrompts an Fusion-Altar und
-- Rebirth-Portal so, dass beim Triggern das passende UI-Panel geöffnet wird.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UIController = require(script.Parent.UIController)

local LocalPlayer = Players.LocalPlayer

local WorldInteractionController = {}

-- Welcher Panel-Schlüssel zu welchem Modell gehört.
local PANEL_FOR_MODEL: { [string]: string } = {
	fusionaltar  = "fusion",
	rebirthportal = "rebirth",
}

local function findOwningModel(prompt: ProximityPrompt): Model?
	local node: Instance? = prompt
	while node do
		if node:IsA("Model") then
			local parent = node.Parent
			if parent and parent.Name == "Modelle" then
				return node
			end
		end
		node = node.Parent
	end
	return nil
end

local function bindPrompt(prompt: ProximityPrompt)
	local model = findOwningModel(prompt)
	if not model then return end
	local panelId = PANEL_FOR_MODEL[model.Name]
	if not panelId then return end

	prompt.Triggered:Connect(function(player)
		if player ~= LocalPlayer then return end
		UIController.openPanel(panelId)
	end)
end

function WorldInteractionController.start()
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			bindPrompt(desc)
		end
	end
	Workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") then
			bindPrompt(desc)
		end
	end)
end

return WorldInteractionController
