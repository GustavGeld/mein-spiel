game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Warte kurz, bis das Framework den Charakter bereitgestellt hat
		task.wait(1.5) 

		local humanoid = character:WaitForChild("Humanoid", 5)
		local head = character:WaitForChild("Head", 5)

		-- Ordner im Workspace definieren
		local modelleFolder = workspace:FindFirstChild("Modelle")
		
		if not modelleFolder then 
			warn("Ordner 'workspace.Modelle' wurde nicht gefunden!")
			return 
		end

		-- Templates laden
		local tierkopfTemplate = modelleFolder:FindFirstChild("Llamahead")
		local schalTemplate = modelleFolder:FindFirstChild("Schal")

		if humanoid and head then
			
			-- 1. ALTE HAARE & HÜTE ENTFERNEN
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Accessory") and child.Name ~= "Llamahead" and child.Name ~= "Schal" then
					child:Destroy()
				end
			end

			-- 2. ORIGINALEN KOPF & GESICHT UNSICHTBAR MACHEN
			head.Transparency = 1
			if head:FindFirstChild("face") then
				head.face.Transparency = 1
			end

			-- 3. LAMA-KOPF AUFSETZEN (Falls vorhanden)
			if tierkopfTemplate then
				local geklonterKopf = tierkopfTemplate:Clone()
				
				-- Failsafe: Verankerung lösen
				for _, descendant in ipairs(geklonterKopf:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.Anchored = false
						descendant.CanCollide = false
					end
				end
				
				humanoid:AddAccessory(geklonterKopf)
			else
				warn("Llamahead konnte unter workspace.Modelle nicht gefunden werden!")
			end

			-- 4. SCHAL AUFSETZEN (Falls vorhanden)
			if schalTemplate then
				local geklonterSchal = schalTemplate:Clone()
				
				-- Failsafe: Verankerung lösen
				for _, descendant in ipairs(geklonterSchal:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.Anchored = false
						descendant.CanCollide = false
					end
				end
				
				humanoid:AddAccessory(geklonterSchal)
			else
				warn("Schal konnte unter workspace.Modelle nicht gefunden werden!")
			end

		end
	end)
end)

print("Lama-Kopf & Schal Service erfolgreich geladen!")