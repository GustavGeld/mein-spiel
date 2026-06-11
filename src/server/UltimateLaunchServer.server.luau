--!strict
print("[SERVER] UltimateLaunchServer-Skript wurde geladen und startet jetzt!")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wir nutzen ein 5-Sekunden-Zeitlimit. Fehlt der Ordner, warnt uns der Server!
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 5)
if not sharedFolder then
	warn("[SERVER] FEHLER: 'Shared'-Ordner wurde in ReplicatedStorage nicht gefunden!")
end

local configFolder = sharedFolder and sharedFolder:WaitForChild("config", 5)
if not configFolder then
	warn("[SERVER] FEHLER: 'config'-Ordner wurde in Shared nicht gefunden!")
end

local remoteEvent = configFolder and configFolder:WaitForChild("UltimateLaunchEvent", 5) :: RemoteEvent?
if not remoteEvent then
	warn("[SERVER] FEHLER: 'UltimateLaunchEvent' wurde nicht gefunden! Das Skript stoppt hier.")
else
	print("[SERVER] UltimateLaunchEvent erfolgreich gefunden! Verbinde Event-Listener...")
	
	remoteEvent.OnServerEvent:Connect(function(player, actionType, landPos)
		print("[SERVER] Event erhalten von Spieler:", player.Name, "| Aktion:", actionType)
		
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid") :: Humanoid?

		if not rootPart or not humanoid then 
			warn("[SERVER] Abbruch: Charakter-Komponenten fehlen für", player.Name)
			return 
		end

		if actionType == "Launch" then
			workspace.Gravity = 0
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			
			print("[SERVER] Sende 'OnLaunch' via FireAllClients an alle Spieler!")
			remoteEvent:FireAllClients("OnLaunch", player)

		elseif actionType == "Land" and landPos then
			local currentCFrame = rootPart.CFrame
			local flatLook = Vector3.new(currentCFrame.LookVector.X, 0, currentCFrame.LookVector.Z).Unit
			
			rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
			rootPart.CFrame = CFrame.lookAt(landPos + Vector3.new(0, 1.8, 0), landPos + Vector3.new(0, 1.8, 0) + flatLook)
			rootPart.Anchored = true
			
			print("[SERVER] Sende 'OnLand' via FireAllClients an alle Spieler!")
			remoteEvent:FireAllClients("OnLand", player, landPos)
			
			task.wait(0.18) 
			
			workspace.Gravity = 196.2 
			rootPart.Anchored = false
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
		end
	end)
end