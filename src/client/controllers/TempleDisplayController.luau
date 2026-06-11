--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Gods = require(Shared.config.Gods)
local Rarities = require(Shared.config.Rarities)
local Locale = require(Shared.locale.Locale)

local TempleDisplayController = {}

local MAX_SLOTS = 3

local STATS_SIZE   = Vector3.new(6.4, 2.4, 0.2)
local STATS_BELOW  = 3.8    -- Studs unter Anchor-Mittelpunkt
local STATS_ABOVE  = 3.8    -- Studs über Anchor-Mittelpunkt (Pending-Anzeige)
local FLOAT_AMPL   = 0.18
local FLOAT_FREQ   = 1.4

type FaceLabels = {
	bg: Frame,
	picture: ImageLabel?,
	glow: ImageLabel?,
	nameLbl: TextLabel?,
	rarityLbl: TextLabel?,
	lineLbl: TextLabel?,
}

type SlotView = {
	anchorPart: BasePart,
	picturePart: BasePart,
	statsPart: BasePart,
	pendingPart: BasePart,
	phase: number,
	pictureFaces: { FaceLabels },
	statsFaces: { FaceLabels },
	pendingFaces: { FaceLabels },
}

local snapshot = {
	templeSlots = {} :: { { godUid: string? } },
	gods = {} :: { any },
	pending = {} :: { [string]: { gold: number, faith: number } },
}

local slotViews: { SlotView } = {}
local heartbeatConn: RBXScriptConnection? = nil
local tempelCenterPos = Vector3.new(0, 0, 0)
local tempelLookDir = Vector3.new(0, 0, -1) -- Speichert die exakte Ausrichtung des Tempels

local function findTempel(): Model?
	local modelle = Workspace:FindFirstChild("Modelle")
	if not modelle then return nil end
	local t = modelle:FindFirstChild("Tempel")
	return (t and t:IsA("Model")) and (t :: Model) or nil
end

local function getRahmenAnchors(tempel: Model): { BasePart }
	local out: { BasePart } = {}
	for _, desc in ipairs(tempel:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "Rahmen_Doppelseitige_Bildflache" then
			table.insert(out, desc)
		end
	end
	table.sort(out, function(a: BasePart, b: BasePart)
		return a.Position.Z < b.Position.Z
	end)
	return out
end

local function makeCanvasPart(name: string, parent: Instance, size: Vector3, transparent: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparent and 1 or 0
	p.Color = Color3.fromRGB(20, 20, 28)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildPictureFace(parent: BasePart, face: Enum.NormalId): FaceLabels
	local sg = Instance.new("SurfaceGui")
	sg.Name = "PictureSurface_" .. face.Name
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 100
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.ClipsDescendants = false
	sg.Parent = parent

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = sg

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 4
	stroke.Transparency = 0.4
	stroke.Parent = bg

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = "rbxasset://textures/ui/Controls/radial.png"
	glow.ImageTransparency = 0.5
	glow.ScaleType = Enum.ScaleType.Stretch
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.2, 1.2)
	glow.Parent = bg

	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	picture.Size = UDim2.fromScale(0.94, 0.94)
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Image = ""
	picture.Parent = bg

	return {
		bg = bg, picture = picture, glow = glow,
		nameLbl = nil, rarityLbl = nil, lineLbl = nil,
	}
end

local function buildStatsFace(parent: BasePart, face: Enum.NormalId): FaceLabels
	local sg = Instance.new("SurfaceGui")
	sg.Name = "StatsSurface_" .. face.Name
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 120
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.Parent = parent

	local bg = Instance.new("Frame")
	bg.Name = "StatsBG"
	bg.BackgroundTransparency = 1
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = sg

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.Parent = bg

	local function makeLabel(layoutOrder: number, textSize: number, font: Enum.Font): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, textSize + 12)
		lbl.Font = font
		lbl.TextSize = textSize
		lbl.TextColor3 = Color3.fromRGB(255, 250, 230)
		lbl.TextStrokeTransparency = 0
		lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		lbl.LayoutOrder = layoutOrder
		lbl.Text = ""
		lbl.RichText = true
		lbl.Parent = bg
		local s = Instance.new("UIStroke")
		s.Name = "Glow"
		s.Color = Color3.fromRGB(255, 200, 60)
		s.Thickness = 3.5
		s.Transparency = 0.1
		s.Parent = lbl
		return lbl
	end

	return {
		bg = bg, picture = nil, glow = nil,
		nameLbl   = makeLabel(1, 88, Enum.Font.GothamBlack),
		rarityLbl = makeLabel(2, 52, Enum.Font.GothamBold),
		lineLbl   = makeLabel(3, 48, Enum.Font.Gotham),
	}
end

local function buildSlot(anchor: BasePart, slotIndex: number)
	if anchor:GetAttribute("__TempleDisplayBuilt") then return end
	anchor:SetAttribute("__TempleDisplayBuilt", true)

	local pSize = Vector3.new(anchor.Size.X * 0.98, anchor.Size.Y * 0.98, 0.3)
	local picturePart = makeCanvasPart("PictureCanvas_" .. slotIndex, Workspace, pSize, false)
	local statsPart   = makeCanvasPart("StatsCanvas_" .. slotIndex, Workspace, STATS_SIZE, true)
	local pendingPart = makeCanvasPart("PendingCanvas_" .. slotIndex, Workspace, STATS_SIZE, true)

	local pictureFront = buildPictureFace(picturePart, Enum.NormalId.Front)
	local pictureBack  = buildPictureFace(picturePart, Enum.NormalId.Back)
	local statsFront   = buildStatsFace(statsPart,   Enum.NormalId.Front)
	local statsBack    = buildStatsFace(statsPart,   Enum.NormalId.Back)
	local pendingFront = buildStatsFace(pendingPart, Enum.NormalId.Front)
	local pendingBack  = buildStatsFace(pendingPart, Enum.NormalId.Back)

	table.insert(slotViews, {
		anchorPart    = anchor,
		picturePart   = picturePart,
		statsPart     = statsPart,
		pendingPart   = pendingPart,
		phase         = slotIndex * 0.7,
		pictureFaces  = { pictureFront, pictureBack },
		statsFaces    = { statsFront, statsBack },
		pendingFaces  = { pendingFront, pendingBack },
	})
end

local function findGodByUid(uid: string?): any?
	if not uid then return nil end
	for _, g in ipairs(snapshot.gods) do
		if g.uid == uid then return g end
	end
	return nil
end

local function prettifyName(id: string): string
	return (string.gsub(id, "_", " "))
end

local function rarityName(rDef: any?): string
	if not rDef then return "" end
	if rDef.nameKey then
		local ok, txt = pcall(Locale.t, rDef.nameKey)
		if ok and type(txt) == "string" and txt ~= "" then return txt end
	end
	return rDef.id or ""
end

local function refreshSlot(i: number)
	local view = slotViews[i]
	if not view then return end

	local slotData = snapshot.templeSlots[i]
	local entry = slotData and findGodByUid(slotData.godUid) or nil
	local def = entry and Gods.byId[entry.id] or nil
	local rDef = entry and Rarities.byId[entry.rarityId] or nil

	local imageId = (def and def.iconAssetId) or ""
	local rColor = (rDef and rDef.color) or Color3.fromRGB(90, 90, 110)
	local glowColor = Color3.new(
		math.min(rColor.R * 1.1 + 0.15, 1),
		math.min(rColor.G * 1.1 + 0.15, 1),
		math.min(rColor.B * 1.1 + 0.15, 1)
	)

	-- BILDER UPDATEN
	for _, face in ipairs(view.pictureFaces) do
		face.bg.BackgroundColor3 = rColor
		if face.glow then face.glow.ImageColor3 = glowColor end

		if entry and face.picture and face.glow then
			face.picture.Image = imageId
			face.picture.ImageTransparency = 0
			face.bg.BackgroundTransparency = 0
			face.glow.ImageTransparency = 0.45
		elseif face.picture and face.glow then
			face.picture.Image = ""
			face.picture.ImageTransparency = 1
			face.bg.BackgroundTransparency = 0.4
			face.glow.ImageTransparency = 1
		end
	end

	-- STATS UPDATEN
	for _, face in ipairs(view.statsFaces) do
		if entry and def and face.nameLbl and face.rarityLbl and face.lineLbl then
			face.nameLbl.Text   = prettifyName(entry.id) .. (entry.fusionRank > 0 and ("  ★+" .. entry.fusionRank) or "")
			face.rarityLbl.Text = rarityName(rDef)
			face.lineLbl.Text   = string.format(
				"<font color=\"rgb(255,210,90)\">%d</font> Gold/s · <font color=\"rgb(170,210,255)\">%d</font> Faith/s", 
				def.baseProduction or 0, 
				def.baseFaith or 0
			)
		elseif face.nameLbl and face.rarityLbl and face.lineLbl then
			face.nameLbl.Text   = "Leerer Slot"
			face.rarityLbl.Text = "-"
			face.lineLbl.Text   = "0 Gold/s · 0 Faith/s"
		end

		if face.rarityLbl then face.rarityLbl.TextColor3 = rColor end

		local labels = { face.nameLbl, face.rarityLbl, face.lineLbl }
		for _, lbl in ipairs(labels) do
			if lbl then
				local stroke = lbl:FindFirstChild("Glow")
				if stroke and stroke:IsA("UIStroke") then stroke.Color = glowColor end
			end
		end
	end

	-- ── PENDING ÜBER DEM RAHMEN: aktuell gesammeltes Gold / Faith ─────────
	local pendingData = snapshot.pending[tostring(i)] or { gold = 0, faith = 0 }
	local pGold  = math.floor(pendingData.gold  or 0)
	local pFaith = math.floor(pendingData.faith or 0)

	local function fmtNum(n: number): string
		if n >= 1e9 then return string.format("%.1fB", n/1e9)
		elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
		elseif n >= 1e3 then return string.format("%.1fk", n/1e3)
		else return tostring(n) end
	end

	local GOLD_ORB_COLOR  = Color3.fromRGB(120, 230, 90)
	local FAITH_ORB_COLOR = Color3.fromRGB(255, 170, 70)

	for _, face in ipairs(view.pendingFaces) do
		if face.nameLbl and face.rarityLbl and face.lineLbl then
			-- Header oben
			face.nameLbl.Text = "✦ PENDING ✦"
			face.nameLbl.TextColor3 = Color3.fromRGB(245, 245, 250)
			-- Gold (grün, große Zahl)
			face.rarityLbl.Text = "🪙 " .. fmtNum(pGold)
			face.rarityLbl.TextColor3 = GOLD_ORB_COLOR
			-- Faith (orange, große Zahl)
			face.lineLbl.Text = "✨ " .. fmtNum(pFaith)
			face.lineLbl.TextColor3 = FAITH_ORB_COLOR

			-- Strokes farblich anpassen
			local goldStroke = face.rarityLbl:FindFirstChild("Glow")
			if goldStroke and goldStroke:IsA("UIStroke") then
				goldStroke.Color = GOLD_ORB_COLOR
			end
			local faithStroke = face.lineLbl:FindFirstChild("Glow")
			if faithStroke and faithStroke:IsA("UIStroke") then
				faithStroke.Color = FAITH_ORB_COLOR
			end
			local headerStroke = face.nameLbl:FindFirstChild("Glow")
			if headerStroke and headerStroke:IsA("UIStroke") then
				headerStroke.Color = Color3.fromRGB(200, 200, 220)
			end

			-- Wenn pending = 0 AND kein god platziert: alles ausblenden
			local hasGod = entry ~= nil
			local hasPending = pGold > 0 or pFaith > 0
			view.pendingPart.Transparency = (hasGod or hasPending) and 1 or 1 -- transparent immer
			-- Labels nur sichtbar wenn was zu zeigen
			face.nameLbl.TextTransparency  = (hasGod or hasPending) and 0 or 1
			face.rarityLbl.TextTransparency = (hasGod or hasPending) and 0 or 1
			face.lineLbl.TextTransparency   = (hasGod or hasPending) and 0 or 1
		end
	end
end

local function refreshAll()
	for i = 1, #slotViews do refreshSlot(i) end
end

local function startHeartbeat()
	if heartbeatConn then return end
	heartbeatConn = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, view in ipairs(slotViews) do
			local anchor = view.anchorPart
			if not anchor or not anchor.Parent then continue end

			view.picturePart.CFrame = anchor.CFrame

			local yHalf = anchor.Size.Y * 0.5
			-- Stats UNTER dem Rahmen (Name + Rarity + Production)
			local belowY = anchor.Position.Y - (yHalf + STATS_BELOW)
			local belowPos = Vector3.new(anchor.Position.X, belowY, anchor.Position.Z)
			local belowOffset = math.sin(t * FLOAT_FREQ + view.phase) * FLOAT_AMPL
			view.statsPart.CFrame = CFrame.lookAt(
				belowPos + Vector3.new(0, belowOffset, 0),
				belowPos + Vector3.new(0, belowOffset, 0) + tempelLookDir
			)

			-- Pending ÜBER dem Rahmen (Gold + Faith pending, antiparallel float)
			local aboveY = anchor.Position.Y + (yHalf + STATS_ABOVE)
			local abovePos = Vector3.new(anchor.Position.X, aboveY, anchor.Position.Z)
			local aboveOffset = math.sin(t * FLOAT_FREQ + view.phase + math.pi) * FLOAT_AMPL
			view.pendingPart.CFrame = CFrame.lookAt(
				abovePos + Vector3.new(0, aboveOffset, 0),
				abovePos + Vector3.new(0, aboveOffset, 0) + tempelLookDir
			)
		end
	end)
end

local function buildViews()
	local tempel = findTempel()
	if not tempel then return end

	local anchors = getRahmenAnchors(tempel)
	local verzoegerung = 0
	while #anchors < MAX_SLOTS and verzoegerung < 10 do
		task.wait(0.5)
		anchors = getRahmenAnchors(tempel)
		verzoegerung = verzoegerung + 1
	end

	-- Ermittelt die exakte Blickrichtung & Position des Tempels
	local tempelPivot = tempel:GetPivot()
	tempelCenterPos = tempelPivot.Position
	tempelLookDir = Vector3.new(tempelPivot.LookVector.X, 0, tempelPivot.LookVector.Z).Unit

	for i = 1, math.min(MAX_SLOTS, #anchors) do
		buildSlot(anchors[i], i)
	end
	refreshAll()
	startHeartbeat()
end

function TempleDisplayController.start()
	buildViews()

	Net:Event("OnTempleUpdate").OnClientEvent:Connect(function(temple)
		snapshot.templeSlots = (temple and temple.slots) or {}
		snapshot.pending     = (temple and temple.pending) or {}
		refreshAll()
	end)
	Net:Event("OnInventoryUpdate").OnClientEvent:Connect(function(inv)
		snapshot.gods = (inv and inv.gods) or {}
		refreshAll()
	end)
	Locale.LanguageChanged:Connect(refreshAll)

	task.spawn(function()
		local ok, profile = pcall(function() return Net:Function("RequestProfile"):InvokeServer() end)
		if ok and type(profile) == "table" then
			snapshot.templeSlots = (profile.temple and profile.temple.slots) or snapshot.templeSlots
			snapshot.gods        = (profile.inventory and profile.inventory.gods) or snapshot.gods
			snapshot.pending     = (profile.temple and profile.temple.pending) or snapshot.pending
			refreshAll()
		end
	end)

	if not findTempel() then
		local conn: RBXScriptConnection
		conn = Workspace.DescendantAdded:Connect(function(desc)
			if desc:IsA("Model") and desc.Name == "Tempel" then
				conn:Disconnect()
				task.wait(0.2)
				buildViews()
				refreshAll()
			end
		end)
	end
end

task.spawn(function()
	TempleDisplayController.start()
end)

return TempleDisplayController