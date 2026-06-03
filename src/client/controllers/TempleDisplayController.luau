--!strict
-- TempleDisplayController — zeigt die equippten Götter des Local-Players auf
-- den Rahmen des Tempel-Modells (Slots 1-3).

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

local STATS_SIZE   = Vector3.new(6.2, 2.2, 0.3)
local STATS_BELOW  = 3.6
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
	phase: number,
	pictureFaces: { FaceLabels },
	statsFaces: { FaceLabels },
}

local snapshot = {
	templeSlots = {} :: { { godUid: string? } },
	gods = {} :: { any },
}

local slotViews: { [number]: SlotView } = {}
local heartbeatConn: RBXScriptConnection? = nil

local function findTempel(): Model?
	local modelle = Workspace:FindFirstChild("Modelle")
	if not modelle then return nil end
	local t = modelle:FindFirstChild("Tempel")
	return (t and t:IsA("Model")) and (t :: Model) or nil
end

-- FIX 1: Holt gezielt die einzelne Bildfläche aus jedem Rahmen-Modell
local function getRahmen(tempel: Model): { BasePart }
	local out: { BasePart } = {}
	
	for _, child in ipairs(tempel:GetChildren()) do
		if child.Name == "Rahmen" then
			local bildflache = child:FindFirstChild("Rahmen_Doppelseitige_Bildflache")
			if bildflache and bildflache:IsA("BasePart") then
				table.insert(out, bildflache)
			end
		end
	end

	-- Sortiert von links nach rechts nach X-Koordinate
	table.sort(out, function(a: BasePart, b: BasePart)
		return a.Position.X < b.Position.X
	end)
	return out
end

local function makeCanvasPart(name: string, parent: Instance, size: Vector3, transparent: boolean, anchored: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored = anchored
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

	local result: FaceLabels = {
		bg = bg, 
		picture = picture, 
		glow = glow,
		nameLbl = nil, 
		rarityLbl = nil, 
		lineLbl = nil,
	}
	return result
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
	list.Padding = UDim.new(0, 6)
	list.Parent = bg

	local function makeLabel(layoutOrder: number, textSize: number, font: Enum.Font): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, textSize + 6)
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
		s.Thickness = 2
		s.Transparency = 0.1
		s.Parent = lbl
		return lbl
	end

	local result: FaceLabels = {
		bg = bg, 
		picture = nil, 
		glow = nil,
		nameLbl   = makeLabel(1, 44, Enum.Font.GothamBlack) :: any,
		rarityLbl = makeLabel(2, 26, Enum.Font.GothamBold) :: any,
		lineLbl   = makeLabel(3, 24, Enum.Font.Gotham) :: any,
	}
	return result
end

-- FIX 2: Erzeugt ein unanchored Hilfs-Part für die Bilder und schweißt es an das Mesh
local function buildSlot(anchor: BasePart, slotIndex: number)
	if anchor:GetAttribute("__TempleDisplayBuilt") then return end
	anchor:SetAttribute("__TempleDisplayBuilt", true)

	-- Passt sich dynamisch an die Mesh-Größe an, fügt minimale Dicke hinzu
	local pSize = Vector3.new(anchor.Size.X, anchor.Size.Y, 0.15)
	local picturePart = makeCanvasPart("PictureCanvas_" .. slotIndex, anchor, pSize, false, false)
	picturePart.CFrame = anchor.CFrame
	
	local pw = Instance.new("WeldConstraint")
	pw.Part0 = anchor
	pw.Part1 = picturePart
	pw.Parent = picturePart

	local pictureFront = buildPictureFace(picturePart, Enum.NormalId.Front)
	local pictureBack  = buildPictureFace(picturePart, Enum.NormalId.Back)

	-- Stats-Schilder (bleiben zwecks Live-Ausrichtung auf Anchored = true)
	local statsPart = makeCanvasPart("StatsCanvas_" .. slotIndex, anchor, STATS_SIZE, true, true)

	local statsFront = buildStatsFace(statsPart, Enum.NormalId.Front)
	local statsBack  = buildStatsFace(statsPart, Enum.NormalId.Back)

	slotViews[slotIndex] = {
		anchorPart    = anchor,
		picturePart   = picturePart,
		statsPart     = statsPart,
		phase         = slotIndex * 0.7,
		pictureFaces  = { pictureFront, pictureBack },
		statsFaces    = { statsFront, statsBack },
	}
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
	local rText = rarityName(rDef)
	local nameTxt = entry and prettifyName(entry.id) or ""
	local prod = (def and def.baseProduction) or 0
	local faith = (def and def.baseFaith) or 0
	local rank = (entry and entry.fusionRank) or 0
	local rankSuffix = rank > 0 and ("  ★+" .. rank) or ""

	local glowColor = Color3.new(
		math.min(rColor.R * 1.1 + 0.15, 1),
		math.min(rColor.G * 1.1 + 0.15, 1),
		math.min(rColor.B * 1.1 + 0.15, 1)
	)

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

	for _, face in ipairs(view.statsFaces) do
		if entry and face.nameLbl and face.rarityLbl and face.lineLbl then
			face.nameLbl.Text   = nameTxt .. rankSuffix
			face.rarityLbl.Text = rText
			face.lineLbl.Text   = string.format(
				"<font color=\"rgb(255,210,90)\">%d</font> Gold/s · <font color=\"rgb(170,210,255)\">%d</font> Faith/s",
				prod, faith
			)
		elseif face.nameLbl and face.rarityLbl and face.lineLbl then
			face.nameLbl.Text   = ""
			face.rarityLbl.Text = ""
			face.lineLbl.Text   = ""
		end

		if face.rarityLbl then face.rarityLbl.TextColor3 = rColor end

		local labels = { face.nameLbl, face.rarityLbl, face.lineLbl }
		for _, lbl in ipairs(labels) do
			if lbl then
				local stroke = lbl:FindFirstChild("Glow")
				if stroke and stroke:IsA("UIStroke") then
					stroke.Color = glowColor
				end
			end
		end
	end
end

local function refreshAll()
	for i = 1, MAX_SLOTS do
		refreshSlot(i)
	end
end

-- FIX 3: Hält die schwebenden Stats unter den beweglichen Rahmen immer absolut waagerecht
local function startFloat()
	if heartbeatConn then return end
	heartbeatConn = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, view in pairs(slotViews) do
			local anchor = view.anchorPart
			if anchor and view.statsPart then
				local yHalf = anchor.Size.Y * 0.5
				local anchorCF = anchor.CFrame
				
				-- Filtert unerwünschte Neigungen (Pitch/Roll) heraus
				local pos = anchorCF.Position - Vector3.new(0, yHalf + STATS_BELOW, 0)
				local look = anchorCF.LookVector
				local lookXZ = Vector3.new(look.X, 0, look.Z)
				if lookXZ.Magnitude < 0.001 then
					lookXZ = Vector3.new(0, 0, -1)
				else
					lookXZ = lookXZ.Unit
				end
				
				local uprightBaseCF = CFrame.lookAt(pos, pos + lookXZ)
				local yOffset = math.sin(t * FLOAT_FREQ + view.phase) * FLOAT_AMPL
				
				view.statsPart.CFrame = uprightBaseCF * CFrame.new(0, yOffset, 0)
			end
		end
	end)
end

local function buildViews()
	local tempel = findTempel()
	if not tempel then return end
	local bildflachen = getRahmen(tempel)
	for i = 1, math.min(MAX_SLOTS, #bildflachen) do
		buildSlot(bildflachen[i], i)
	end
	refreshAll()
	startFloat()
end

function TempleDisplayController.start()
	buildViews()

	Net:Event("OnTempleUpdate").OnClientEvent:Connect(function(temple)
		snapshot.templeSlots = (temple and temple.slots) or {}
		refreshAll()
	end)
	Net:Event("OnInventoryUpdate").OnClientEvent:Connect(function(inv)
		snapshot.gods = (inv and inv.gods) or {}
		refreshAll()
	end)
	Locale.LanguageChanged:Connect(refreshAll)

	task.spawn(function()
		local ok, profile = pcall(function()
			return Net:Function("RequestProfile"):InvokeServer()
		end)
		if ok and type(profile) == "table" then
			snapshot.templeSlots = (profile.temple and profile.temple.slots) or snapshot.templeSlots
			snapshot.gods = (profile.inventory and profile.inventory.gods) or snapshot.gods
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

	local _ = Players
end

return TempleDisplayController