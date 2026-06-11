--!strict
-- TempleOrbsController — zeigt die in `temple.pending` aufgelaufene Produktion als
-- schwebende Kugeln um die 3 Rahmen. Wenn der Spieler in Range kommt, fliegen die
-- Orbs zum Character und werden eingesammelt (CollectTemple).
--
-- Gold = grüne Kugel · Faith = orange Kugel
-- Orb-Anzahl pro Slot = clamp(log10(value), 1, MAX_ORBS_PER_KIND)
-- Pickup-Range: ~12 Studs. Auto-Collect Gamepass: Server sammelt direkt → keine
-- Orbs werden ever angezeigt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net    = require(Shared.remotes.Net)

local TempleOrbsController = {}

local MAX_SLOTS         = 3
local PICKUP_RANGE      = 22
local ORBIT_RADIUS_BASE = 3.5
local ORBIT_SPEED       = 1.4
local FLOAT_AMPL        = 0.6
local ORB_SIZE          = Vector3.new(0.8, 0.8, 0.8)
local MAX_ORBS_PER_KIND = 6      -- max 6 grüne + 6 orange pro Rahmen
local COLLECT_COOLDOWN  = 0.5    -- s zwischen Server-Calls pro Slot

local GOLD_COLOR     = Color3.fromRGB(120, 230, 90)
local FAITH_COLOR    = Color3.fromRGB(255, 170, 70)
local OFFERING_COLOR = Color3.fromRGB(180, 120, 255)

local LocalPlayer = Players.LocalPlayer

type Orb = {
	part: BasePart,
	kind: string,
	phase: number,
	collecting: boolean,
}

type SlotOrbs = {
	anchorPart: BasePart,
	gold: { Orb },
	faith: { Orb },
	offerings: { Orb },
	pendingGold: number,
	pendingFaith: number,
	pendingOfferings: number,
	lastCollectAt: number,
}

local snapshot = {
	pending = {} :: { [string]: { gold: number, faith: number } },
}

local slots: { SlotOrbs } = {}
local heartbeatConn: RBXScriptConnection? = nil
local builtAlready = false

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function findTempel(): Model?
	local modelle = Workspace:FindFirstChild("Modelle")
	if not modelle then return nil end
	local t = modelle:FindFirstChild("Tempel")
	return (t and t:IsA("Model")) and (t :: Model) or nil
end

-- Jeden Rahmen-Anker einmal (gleiche Logik wie TempleDisplayController)
local function getRahmenAnchors(tempel: Model): { BasePart }
	local out: { BasePart } = {}
	local seenRahmen: { [Model]: boolean } = {}
	for _, child in ipairs(tempel:GetChildren()) do
		if child:IsA("Model") and child.Name == "Rahmen" and not seenRahmen[child] then
			seenRahmen[child] = true
			for _, c in ipairs(child:GetChildren()) do
				if c:IsA("BasePart") and c.Name == "Rahmen_Doppelseitige_Bildflache" then
					table.insert(out, c)
					break
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.Position.Z < b.Position.Z end)
	return out
end

local function makeOrb(parent: Instance, kind: string): BasePart
	local p = Instance.new("Part")
	p.Name = "Orb_" .. kind
	p.Shape = Enum.PartType.Ball
	p.Size = ORB_SIZE
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	local orbColor = kind == "gold" and GOLD_COLOR
		or kind == "faith" and FAITH_COLOR
		or OFFERING_COLOR
	p.Color = orbColor
	p.Parent = parent

	-- Inneres Glow-PointLight
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 6
	light.Color = p.Color
	light.Parent = p

	return p
end

local function expectedOrbCount(value: number): number
	if value <= 0 then return 0 end
	-- log10-basiert: 1-9 → 1, 10-99 → 2, 100-999 → 3, ...
	local n = math.clamp(math.floor(math.log10(value)) + 1, 1, MAX_ORBS_PER_KIND)
	return n
end

-- Stellt sicher, dass die Anzahl an Orbs zum Wert passt.
-- WICHTIG: Orbs im "collecting" State NICHT entfernen — sie animieren noch
-- zum Spieler und werden selbst destroyed wenn sie ankommen.
local function syncOrbs(slot: SlotOrbs, kind: string, value: number)
	local list = (kind == "gold") and slot.gold or slot.faith
	local target = expectedOrbCount(value)

	-- Zähle nur nicht-collecting orbs
	local active = 0
	for _, o in ipairs(list) do
		if not o.collecting then active += 1 end
	end

	-- Entferne überschüssige (nur nicht-collecting)
	if active > target then
		for i = #list, 1, -1 do
			if active <= target then break end
			if not list[i].collecting then
				list[i].part:Destroy()
				table.remove(list, i)
				active -= 1
			end
		end
	end

	-- Fehlende hinzufügen
	while active < target do
		local part = makeOrb(Workspace, kind)
		part.CFrame = slot.anchorPart.CFrame
		table.insert(list, {
			part = part,
			kind = kind,
			phase = math.random() * math.pi * 2,
			collecting = false,
		})
		active += 1
	end
end

-- Rebuild aller Slot-Orbs basierend auf snapshot.pending
local function refreshAll()
	for i, slot in ipairs(slots) do
		local key = tostring(i)
		local pending = snapshot.pending[key] or { gold = 0, faith = 0, offerings = 0 }
		slot.pendingGold      = pending.gold      or 0
		slot.pendingFaith     = pending.faith     or 0
		slot.pendingOfferings = pending.offerings or 0
		syncOrbs(slot, "gold",      slot.pendingGold)
		syncOrbs(slot, "faith",     slot.pendingFaith)
		syncOrbs(slot, "offerings", slot.pendingOfferings)
	end
end

-- ─── Heartbeat-Animation ─────────────────────────────────────────────────────

local function getCharacterPos(): Vector3?
	local char = LocalPlayer.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp.Position end
	return nil
end

-- Schwebendes Pickup-Text Popup
local function spawnFloatingText(pos: Vector3, text: string, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = false
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.LightInfluence = 0
	bb.Adornee = nil
	bb.SizeOffset = Vector2.new(0, 0)
	bb.Parent = Workspace

	-- Positioniert über dem Sammelpunkt
	local dummyPart = Instance.new("Part")
	dummyPart.Anchored = true
	dummyPart.Transparency = 1
	dummyPart.CanCollide = false
	dummyPart.CanQuery = false
	dummyPart.Size = Vector3.new(0.1, 0.1, 0.1)
	dummyPart.CFrame = CFrame.new(pos)
	dummyPart.Parent = Workspace
	bb.Adornee = dummyPart

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = 22
	lbl.TextColor3 = color
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextStrokeTransparency = 0.3
	lbl.Text = text
	lbl.Parent = bb

	-- Float up + fade
	local start = os.clock()
	local dur = 1.6
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = math.min((os.clock() - start) / dur, 1)
		dummyPart.CFrame = CFrame.new(pos + Vector3.new(0, t * 5, 0))
		lbl.TextTransparency = t * t
		lbl.TextStrokeTransparency = 0.3 + t * 0.7
		if t >= 1 then
			conn:Disconnect()
			bb:Destroy()
			dummyPart:Destroy()
		end
	end)
end

local function fmtPickup(n: number): string
	if n >= 1e6 then return string.format("+%.1fM", n/1e6)
	elseif n >= 1e3 then return string.format("+%.1fk", n/1e3)
	else return "+" .. tostring(n) end
end

local function tryCollect(slotIdx: number, slot: SlotOrbs)
	local now = os.clock()
	if now - slot.lastCollectAt < COLLECT_COOLDOWN then return end
	slot.lastCollectAt = now

	-- Pending-Werte snapshot für floating text
	local pendingGold  = slot.pendingGold
	local pendingFaith = slot.pendingFaith

	-- Alle Orbs in "collecting" Modus versetzen
	for _, list in ipairs({ slot.gold, slot.faith }) do
		for _, orb in ipairs(list) do
			orb.collecting = true
		end
	end

	task.spawn(function()
		local charPos = getCharacterPos()
		local ok, result = pcall(function()
			return Net:Function("CollectTemple"):InvokeServer(slotIdx)
		end)
		if ok and result and result.ok and charPos then
			-- Floating text an Spieler-Position
			if (result.gold or 0) > 0 then
				spawnFloatingText(
					charPos + Vector3.new(math.random(-2, 2), 4, 0),
					fmtPickup(result.gold) .. " 🪙",
					GOLD_COLOR
				)
			end
			if (result.faith or 0) > 0 then
				spawnFloatingText(
					charPos + Vector3.new(math.random(-2, 2), 6, 0),
					fmtPickup(result.faith) .. " ✨",
					FAITH_COLOR
				)
			end
			if (result.offerings or 0) > 0 then
				spawnFloatingText(
					charPos + Vector3.new(math.random(-2, 2), 8, 0),
					fmtPickup(result.offerings) .. " 🕯",
					OFFERING_COLOR
				)
			end
		end
	end)
end

local function startHeartbeat()
	if heartbeatConn then return end
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		local charPos = getCharacterPos()

		for slotIdx, slot in ipairs(slots) do
			if not slot.anchorPart or not slot.anchorPart.Parent then continue end
			local center = slot.anchorPart.Position
			local totalOrbs = #slot.gold + #slot.faith + #(slot.offerings or {})
			if totalOrbs == 0 then continue end

			-- Pickup-Range-Check
			local inRange = false
			if charPos then
				local distSq = (charPos - center).Magnitude
				if distSq < PICKUP_RANGE and (slot.pendingGold > 0 or slot.pendingFaith > 0) then
					inRange = true
					-- Sobald in range → Collection-Anim starten
					if not slot.gold[1] or not slot.gold[1].collecting then
						if not slot.faith[1] or not slot.faith[1].collecting then
							tryCollect(slotIdx, slot)
						end
					end
				end
			end

			-- Orb-Positionen aktualisieren
			local idx = 0
			for _, list in ipairs({ slot.gold, slot.faith, slot.offerings }) do
				for _, orb in ipairs(list) do
					idx += 1
					if orb.collecting and charPos then
						-- Zum Charakter fliegen
						local curr = orb.part.Position
						local dir = charPos - curr
						local mag = dir.Magnitude
						if mag < 2 then
							-- Erreicht → destroy
							orb.part:Destroy()
						else
							-- Lerp zum Spieler (schnell)
							local step = math.min(mag, 35 * dt)
							orb.part.CFrame = CFrame.new(curr + dir.Unit * step)
						end
					else
						-- Schweben in Umlaufbahn um center
						local angle = t * ORBIT_SPEED + orb.phase + (idx * 0.5)
						local radius = ORBIT_RADIUS_BASE + math.sin(t * 1.5 + orb.phase) * 0.4
						local xz = Vector3.new(
							math.cos(angle) * radius,
							math.sin(t * 2 + orb.phase) * FLOAT_AMPL,
							math.sin(angle) * radius
						)
						orb.part.CFrame = CFrame.new(center + xz)
					end
				end
			end

			-- Aufräumen: collecting Orbs entfernen die schon destroyed sind
			for _, list in ipairs({ slot.gold, slot.faith, slot.offerings }) do
				for i = #list, 1, -1 do
					if not list[i].part.Parent then table.remove(list, i) end
				end
			end
		end
	end)
end

-- ─── Build / Start ───────────────────────────────────────────────────────────

local function buildViews()
	if builtAlready then return end
	local tempel = findTempel()
	if not tempel then return end
	local anchors = getRahmenAnchors(tempel)
	for i = 1, math.min(MAX_SLOTS, #anchors) do
		slots[i] = {
			anchorPart        = anchors[i],
			gold              = {},
			faith             = {},
			offerings         = {},
			pendingGold       = 0,
			pendingFaith      = 0,
			pendingOfferings  = 0,
			lastCollectAt     = 0,
		}
	end
	builtAlready = #slots > 0
	if builtAlready then
		refreshAll()
		startHeartbeat()
	end
end

function TempleOrbsController.start()
	buildViews()

	Net:Event("OnTempleUpdate").OnClientEvent:Connect(function(temple)
		snapshot.pending = (temple and temple.pending) or {}
		refreshAll()
	end)

	-- Beim Start initial den aktuellen Stand holen (zeigt orbs sofort wenn
	-- noch was vom letzten Login übrig war).
	task.spawn(function()
		local ok, profile = pcall(function()
			return Net:Function("RequestProfile"):InvokeServer()
		end)
		if ok and type(profile) == "table" and profile.temple then
			snapshot.pending = profile.temple.pending or {}
			refreshAll()
		end
	end)

	-- Streaming-Fallback wenn der Tempel später kommt
	if not findTempel() then
		local conn: RBXScriptConnection
		conn = Workspace.DescendantAdded:Connect(function(desc)
			if desc:IsA("Model") and desc.Name == "Tempel" then
				conn:Disconnect()
				task.wait(0.2)
				buildViews()
			end
		end)
	end
end

return TempleOrbsController
