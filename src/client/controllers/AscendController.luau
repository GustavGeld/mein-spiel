--!strict
-- AscendController — Mit erweitertem Debug-Logging für Replikationsfehler
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer :: Player
local Camera      = Workspace.CurrentCamera :: Camera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder      = ReplicatedStorage:WaitForChild("Shared")
local configFolder      = sharedFolder:WaitForChild("config")
local remoteEvent       = configFolder:WaitForChild("UltimateLaunchEvent") :: RemoteEvent

local AscendController = {}

local LAUNCH_POWER    = 185  
local HOVER_TIME      = 1.5  
local DIVE_SPEED      = 220  

local ACTIVE    = false
local cleanups: { () -> () } = {}
local shakeAmplitude = 0

local function addCleanup(fn: () -> ()) table.insert(cleanups, fn) end

local function runCleanups()
	for _, fn in ipairs(cleanups) do pcall(fn) end
	table.clear(cleanups)
	shakeAmplitude = 0
end

local function playSound(name: string, parent: Instance): Sound?
	local soundTemplate = script:FindFirstChild(name) or (script.Parent and script.Parent:FindFirstChild(name))
	if soundTemplate and soundTemplate:IsA("Sound") then
		local s = soundTemplate:Clone()
		s.Parent = parent
		s:Play()
		task.delay(5, function() if s and s.Parent then s:Destroy() end end)
		return s
	end
	return nil
end

local function makePart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.CanCollide   = false
	p.CanTouch     = false
	p.CanQuery     = false
	p.CastShadow   = false
	p.Massless     = true
	p.Anchored     = true
	p.TopSurface   = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	p.Parent = Workspace
	return p
end

local function tweenPart(part: Instance, dur: number, props: { [string]: any })
	local tween = TweenService:Create(part, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function spawnLightningBolt(startPos: Vector3, endPos: Vector3, thickness: number)
	local dist = (endPos - startPos).Magnitude
	local bolt = makePart({
		Size = Vector3.new(thickness, thickness, dist),
		Color = Color3.fromRGB(180, 230, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CFrame = CFrame.lookAt(startPos:Lerp(endPos, 0.5), endPos)
	})
	tweenPart(bolt, 0.2, { Transparency = 1, Size = Vector3.new(0, 0, dist) })
	task.delay(0.25, function() if bolt.Parent then bolt:Destroy() end end)
end

local function spawnAuraLightning(centerPos: Vector3)
	local lastPos = centerPos
	for i = 1, 3 do
		local nextPos = lastPos + Vector3.new(
			(math.random() - 0.5) * 8,
			(math.random() - 0.5) * 8,
			(math.random() - 0.5) * 8
		)
		spawnLightningBolt(lastPos, nextPos, 0.3)
		lastPos = nextPos
	end
end

local function spawnShockwave(pos: Vector3, color: Color3, startSize: number, endSize: number, dur: number)
	local ring = makePart({
		Shape        = Enum.PartType.Cylinder,
		Size         = Vector3.new(0.6, startSize, startSize),
		Color        = color,
		Material     = Enum.Material.Neon,
		Transparency = 0.2,
		CFrame       = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
	})
	tweenPart(ring, dur, { Size = Vector3.new(0.05, endSize, endSize), Transparency = 1 })
	task.delay(dur + 0.05, function() if ring.Parent then ring:Destroy() end end)
end

local function spawnLaunchExplosion(pos: Vector3)
	local blast = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Color = Color3.fromRGB(255, 110, 30),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		CFrame = CFrame.new(pos)
	})
	tweenPart(blast, 0.4, { Size = Vector3.new(35, 35, 35), Transparency = 1 })
	task.delay(0.45, function() if blast.Parent then blast:Destroy() end end)
end

local function spawnFireParticle(pos: Vector3)
	local fire = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Color = Color3.fromRGB(255, 140, 30),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CFrame = CFrame.new(pos + Vector3.new((math.random()-0.5)*3, 0, (math.random()-0.5)*3))
	})
	tweenPart(fire, 0.3, { Size = Vector3.new(0, 0, 0), Transparency = 1 })
	task.delay(0.35, function() if fire.Parent then fire:Destroy() end end)
end

local function spawnGroundDebris(landPos: Vector3)
	local boulderCount = 12
	local radius = 4

	for i = 1, boulderCount do
		local angle = (i / boulderCount) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
		local spawnPos = landPos + offset

		local sizeX = math.random(3, 6)
		local sizeY = math.random(3, 5)
		local sizeZ = math.random(3, 6)

		local rock = makePart({
			Size = Vector3.new(sizeX, sizeY, sizeZ),
			Color = Color3.fromRGB(90, 85, 80), 
			Material = Enum.Material.Slate,     
			Transparency = 0,
			Anchored = false, 
			CanCollide = false
		})
		
		rock.CFrame = CFrame.new(spawnPos) * CFrame.Angles(math.random(), math.random(), math.random())
		
		local forceDirection = (offset.Unit + Vector3.new(0, math.random(15, 25) / 10, 0)).Unit
		local velocity = forceDirection * math.random(40, 75)
		rock.AssemblyLinearVelocity = velocity
		rock.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))

		task.delay(0.35, function()
			if rock and rock.Parent then
				rock.Anchored = true
				local targetCFrame = rock.CFrame - Vector3.new(0, 8, 0) 
				local tween = TweenService:Create(rock, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = targetCFrame,
					Transparency = 1
				})
				tween:Play()
				task.delay(0.45, function() if rock.Parent then rock:Destroy() end end)
			end
		end)
	end
end

local function spawnAuraRing(hrp: BasePart, radius: number, baseTiltX: number, baseTiltZ: number, invert: number): Model
	local model = Instance.new("Model")
	model.Name = "AuraRingModel"
	
	local core = makePart({
		Size = Vector3.new(0.05, 0.05, 0.05),
		Transparency = 1,
	})
	core.CFrame = CFrame.new(hrp.Position)
	core.Parent = model
	model.PrimaryPart = core

	local thickness = 0.15 
	local segments = 24 
	local angleStep = (math.pi * 2) / segments
	local segmentLength = (math.tan(math.pi / segments) * radius * 2) + 0.1

	for i = 1, segments do
		local segment = makePart({
			Size = Vector3.new(thickness, thickness, segmentLength),
			Color = Color3.fromRGB(255, 170, 30),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
		
		local angle = i * angleStep
		segment.CFrame = core.CFrame * CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0, 0)
		segment.Parent = model
	end
	
	model.Parent = Workspace

	local ringConn: RBXScriptConnection? = nil
	local rotationAngle = 0
	local waveTime = 0
	
	ringConn = RunService.Heartbeat:Connect(function(dt)
		if hrp and hrp.Parent and model and model.Parent then
			rotationAngle = rotationAngle + (dt * math.rad(240)) 
			waveTime = waveTime + dt
			
			local waveOffset = math.sin(waveTime * 4) * math.rad(15) * invert
			local positionCFrame = CFrame.new(hrp.Position)
			
			local rotationCFrame = CFrame.Angles(baseTiltX + waveOffset, 0, baseTiltZ + waveOffset) 
				* CFrame.Angles(0, rotationAngle, 0)
			
			model:PivotTo(positionCFrame * rotationCFrame)
		else
			if ringConn then ringConn:Disconnect() end
			if model.Parent then model:Destroy() end
		end
	end)
	
	task.delay(10, function() 
		if ringConn then ringConn:Disconnect() end
		if model.Parent then model:Destroy() end
	end)
	
	return model
end

local function cleanupAuraRings(char: Model)
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "AuraRingModel" then
			for _, part in ipairs(child:GetChildren()) do
				if part:IsA("Part") and part.Name ~= "Core" then
					tweenPart(part, 0.2, { Size = Vector3.new(0, 0, 0), Transparency = 1 })
				end
			end
			task.delay(0.25, function() child:Destroy() end)
		end
	end
end

local function startCameraShake()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if shakeAmplitude <= 0 then return end
		Camera.CFrame = Camera.CFrame * CFrame.new(
			(math.random()-0.5)*shakeAmplitude, 
			(math.random()-0.5)*shakeAmplitude,
			(math.random()-0.5)*shakeAmplitude
		)
	end)
	addCleanup(function() if conn then conn:Disconnect() end end)
end

-- ─── EFFEKT-STEUERUNG MIT LOGGING ───────────────────────────────────────────

local function triggerLaunchEffects(targetPlayer: Player)
	print("[CLIENT] triggerLaunchEffects gestartet für Spieler:", targetPlayer.Name)
	local char = targetPlayer.Character
	if not char then 
		warn("[CLIENT] Abbruch: Charakter von", targetPlayer.Name, "existiert lokal (noch) nicht!")
		return 
	end
	
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then 
		warn("[CLIENT] Abbruch: HumanoidRootPart von", targetPlayer.Name, "nicht gefunden!")
		return 
	end

	print("[CLIENT] Erzeuge Start-Effekte auf Position:", hrp.Position)
	spawnLaunchExplosion(hrp.Position - Vector3.new(0, 3, 0))
	spawnShockwave(hrp.Position, Color3.fromRGB(255, 110, 30), 4, 50, 0.5)
	playSound("launch", hrp)

	spawnAuraRing(hrp, 7, math.rad(20), math.rad(15), 1)
	spawnAuraRing(hrp, 9.5, math.rad(-20), math.rad(-15), -1)

	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		if hrp and hrp.Parent then
			spawnFireParticle(hrp.Position - Vector3.new(0, 3, 0))
			if math.random() < 0.4 then spawnAuraLightning(hrp.Position) end
		else
			if connection then connection:Disconnect() end
		end
	end)
	task.delay(0.4, function() if connection then connection:Disconnect() end end)
end

local function triggerLandEffects(targetPlayer: Player, landPos: Vector3)
	print("[CLIENT] triggerLandEffects gestartet für Spieler:", targetPlayer.Name)
	local char = targetPlayer.Character
	if not char then 
		warn("[CLIENT] Abbruch bei Landung: Charakter von", targetPlayer.Name, "existiert lokal nicht!")
		return 
	end
	
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then 
		warn("[CLIENT] Abbruch bei Landung: HumanoidRootPart von", targetPlayer.Name, "nicht gefunden!")
		return 
	end

	print("[CLIENT] Erzeuge Lande-Effekte auf Position:", landPos)
	spawnShockwave(landPos, Color3.fromRGB(255, 160, 30), 5, 90, 0.5)
	spawnShockwave(landPos, Color3.fromRGB(255, 255, 255), 2, 100, 0.6)
	spawnGroundDebris(landPos)

	for i = 1, 4 do
		spawnLightningBolt(landPos + Vector3.new((math.random()-0.5)*15, 100, (math.random()-0.5)*15), landPos, 1.0)
	end

	playSound("land", hrp)
	playSound("thunder", hrp)
	
	if LocalPlayer ~= targetPlayer and LocalPlayer.Character then
		local clientChar = LocalPlayer.Character
		local myHrp = clientChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if myHrp then
			local dist = (myHrp.Position - landPos).Magnitude
			if dist < 120 then
				shakeAmplitude = math.clamp(1.2 - (dist / 100), 0, 1.0)
				task.delay(0.4, function() shakeAmplitude = 0 end)
			end
		end
	end
end

-- ─── PHASEN ──────────────────────────────────────────────────────────────────

local function phase3(char: Model, hrp: BasePart)
	shakeAmplitude = 0.03
	TweenService:Create(Camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { FieldOfView = 65 }):Play()

	local attachment = Instance.new("Attachment", hrp)
	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = 9999999
	lv.VectorVelocity = Vector3.new(0, 0, 0)
	lv.Attachment0 = attachment
	lv.Parent = hrp
	addCleanup(function() lv:Destroy(); attachment:Destroy() end)

	local hoverLightning = RunService.Heartbeat:Connect(function()
		if math.random() < 0.3 and hrp.Parent then
			spawnAuraLightning(hrp.Position)
		end
	end)
	addCleanup(function() hoverLightning:Disconnect() end)

	playSound("hover", hrp)
	task.wait(HOVER_TIME)
end

local function phase4(char: Model, hrp: BasePart, hum: Humanoid): Vector3
	shakeAmplitude = 0.3
	playSound("fall", hrp)
	
	spawnShockwave(hrp.Position, Color3.fromRGB(255, 90, 20), 4, 75, 0.4)
	spawnShockwave(hrp.Position, Color3.fromRGB(255, 255, 255), 2, 50, 0.5)
	playSound("launch", hrp) 
	
	cleanupAuraRings(char)
	
	hum.PlatformStand = true

	local attachment = Instance.new("Attachment", hrp)
	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = 99999999
	lv.Attachment0 = attachment
	lv.Parent = hrp

	local ao = Instance.new("AlignOrientation")
	ao.MaxTorque = 99999999
	ao.Responsiveness = 50
	ao.Attachment0 = attachment
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Parent = hrp

	addCleanup(function() 
		lv:Destroy() 
		ao:Destroy() 
		attachment:Destroy() 
		hum.PlatformStand = false 
		cleanupAuraRings(char) 
	end)

	local rcParams = RaycastParams.new()
	rcParams.FilterType = Enum.RaycastFilterType.Exclude
	rcParams.FilterDescendantsInstances = {char}

	local flightConn = RunService.Heartbeat:Connect(function()
		if not hrp.Parent then return end
		local camDir = Camera.CFrame.LookVector
		local moveDir = Vector3.new(camDir.X, math.clamp(camDir.Y, -1, -0.1), camDir.Z).Unit
		lv.VectorVelocity = moveDir * DIVE_SPEED

		ao.CFrame = CFrame.lookAt(Vector3.zero, moveDir) * CFrame.Angles(math.rad(-90), 0, 0)
		spawnAuraLightning(hrp.Position)
	end)

	local landed = false
	local actualLandPos = hrp.Position

	while not landed do
		if not hrp.Parent then break end
		local raycastResult = Workspace:Raycast(hrp.Position, lv.VectorVelocity.Unit * 5, rcParams)
		if raycastResult then
			actualLandPos = raycastResult.Position
			landed = true
		end
		task.wait(0.005)
	end

	flightConn:Disconnect()
	return actualLandPos
end

local function function_phase5(char: Model, hrp: BasePart, landPos: Vector3, hum: Humanoid)
	shakeAmplitude = 1.0 
	
	hrp.Anchored = true
	hrp.AssemblyLinearVelocity = Vector3.zero
	
	local camLook = Camera.CFrame.LookVector
	local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
	hrp.CFrame = CFrame.lookAt(landPos + Vector3.new(0, 1.8, 0), landPos + Vector3.new(0, 1.8, 0) + flatLook)
	hum:ChangeState(Enum.HumanoidStateType.Landed)

	TweenService:Create(Camera, TweenInfo.new(0.05, Enum.EasingStyle.Quad), { FieldOfView = 96 }):Play()
	task.delay(0.08, function()
		TweenService:Create(Camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { FieldOfView = 70 }):Play()
	end)

	task.wait(0.18)

	hrp.Anchored = false
end

-- ─── MAIN FLOW ────────────────────────────────────────────────────────────────

local function activate()
	if ACTIVE then return end
	local char = LocalPlayer.Character
	if not char then return end
	
	local hrp  = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum  = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not hrp or not hum then return end

	ACTIVE = true
	startCameraShake()

	print("[CLIENT] E gedrückt! Sende 'Launch' an den Server...")
	remoteEvent:FireServer("Launch")

	shakeAmplitude = 0.4
	local attachment = Instance.new("Attachment", hrp)
	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = 9999999
	lv.VectorVelocity = Vector3.new(0, LAUNCH_POWER, 0)
	lv.Attachment0 = attachment
	lv.Parent = hrp
	task.delay(0.38, function() lv:Destroy(); attachment:Destroy() end)

	task.wait(0.4) 

	phase3(char, hrp)
	local landPos = phase4(char, hrp, hum)

	print("[CLIENT] Gelandet! Sende 'Land' an den Server...")
	remoteEvent:FireServer("Land", landPos) 
	
	function_phase5(char, hrp, landPos, hum)

	runCleanups()
	ACTIVE = false
end

function AscendController.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.E then activate() end
	end)
end

-- Globaler Listener für replizierte Effekte
remoteEvent.OnClientEvent:Connect(function(action: string, targetPlayer: Player, data: any)
	print("[CLIENT GLOBAL LISTENER] Signal empfangen! Aktion:", action, "für Spieler:", targetPlayer.Name)
	if action == "OnLaunch" then
		triggerLaunchEffects(targetPlayer)
	elseif action == "OnLand" then
		triggerLandEffects(targetPlayer, data)
	end
end)

print("[CLIENT] AscendController wurde erfolgreich geladen!")
return AscendController