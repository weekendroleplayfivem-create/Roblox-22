--!strict
-- Procedurally builds the city of Neon Bay: road grid, skyscrapers, the safehouse,
-- a park, covered hiding spots, pursuit breakers, speed cameras and ramps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))

local MapBuilder = {}

export type Breaker = {
	model: Model,
	position: Vector3, -- trigger centre
	parts: { { part: BasePart, cframe: CFrame } },
	armed: boolean,
}

export type MapInfo = {
	safehouse: Vector3,
	safehouseSpawns: { CFrame },
	hidingZones: { { center: Vector3, size: Vector3 } },
	breakers: { Breaker },
	speedCams: { Vector3 },
	buildings: Folder,
	nightLights: { Light },
	nightNeon: { BasePart },
}

local rng = Random.new(22)
local G = Config.Grid
local SURFACE = Grid.RoadY
local ROAD = G.RoadWidth
local BLOCK = G.BlockSize

local function anchored(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function billboard(parent: BasePart, text: string, color: Color3, height: number, maxDist: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDist or 400
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	bb.Parent = parent
end

local BUILDING_COLORS = {
	Color3.fromRGB(35, 38, 50),
	Color3.fromRGB(50, 45, 60),
	Color3.fromRGB(28, 40, 48),
	Color3.fromRGB(60, 55, 52),
	Color3.fromRGB(40, 40, 42),
	Color3.fromRGB(72, 62, 80),
}
local NEON_COLORS = {
	Color3.fromRGB(255, 40, 160),
	Color3.fromRGB(0, 240, 255),
	Color3.fromRGB(255, 190, 30),
	Color3.fromRGB(150, 60, 255),
	Color3.fromRGB(60, 255, 120),
}
local SIGN_TEXTS = { "WANTED", "UNBOUND", "NEON BAY", "NITRO", "24/7", "MOTEL", "GARAGE", "HOTEL", "CLUB", "RAMEN" }

-- Painted road markings: double yellow centre line and white edge lines.
local function markings(mid: Vector3, alongX: boolean, segLen: number, folder: Folder)
	local function line(offset: number, width: number, color: Color3)
		local size = if alongX then Vector3.new(segLen - 6, 0.04, width) else Vector3.new(width, 0.04, segLen - 6)
		local off = if alongX then Vector3.new(0, 0, offset) else Vector3.new(offset, 0, 0)
		anchored({
			Name = "Line",
			Size = size,
			CFrame = CFrame.new(mid.X + off.X, SURFACE + 0.02, mid.Z + off.Z),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
		}, folder)
	end
	local yellow = Color3.fromRGB(235, 190, 40)
	local white = Color3.fromRGB(225, 225, 225)
	line(-0.55, 0.45, yellow)
	line(0.55, 0.45, yellow)
	line(-(ROAD / 2 - 2.5), 0.5, white)
	line(ROAD / 2 - 2.5, 0.5, white)
end

local function buildRoads(folder: Folder)
	local N = Grid.Size
	local asphalt = Color3.fromRGB(34, 34, 37)
	local segLen = Grid.Cell - ROAD
	for i = 0, N do
		for j = 0, N do
			local c = Grid.Intersection(i, j)
			anchored({
				Name = "Intersection",
				Size = Vector3.new(ROAD, 1, ROAD),
				CFrame = CFrame.new(c.X, SURFACE - 0.5, c.Z),
				Color = asphalt,
				Material = Enum.Material.Asphalt,
			}, folder)
			if i < N then
				local mid = Grid.SegmentMid(i, j, "x")
				anchored({
					Name = "Road",
					Size = Vector3.new(segLen, 1, ROAD),
					CFrame = CFrame.new(mid.X, SURFACE - 0.5, mid.Z),
					Color = asphalt,
					Material = Enum.Material.Asphalt,
				}, folder)
				markings(mid, true, segLen, folder)
			end
			if j < N then
				local mid = Grid.SegmentMid(i, j, "z")
				anchored({
					Name = "Road",
					Size = Vector3.new(ROAD, 1, segLen),
					CFrame = CFrame.new(mid.X, SURFACE - 0.5, mid.Z),
					Color = asphalt,
					Material = Enum.Material.Asphalt,
				}, folder)
				markings(mid, false, segLen, folder)
			end
		end
	end
end

-- Night-time lights the day/night cycle switches on and off
local nightLights: { Light } = {}
local nightNeon: { BasePart } = {}

-- Street lamp with an arm reaching over the road (`toRoad` is a unit direction).
local function streetLight(pos: Vector3, toRoad: Vector3, props: Folder)
	local metal = Color3.fromRGB(55, 58, 62)
	anchored({
		Name = "Pole",
		Size = Vector3.new(0.7, 24, 0.7),
		CFrame = CFrame.new(pos + Vector3.new(0, 12, 0)),
		Color = metal,
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, props)
	local armCenter = pos + toRoad * 3 + Vector3.new(0, 24, 0)
	anchored({
		Name = "Arm",
		Size = Vector3.new(0.5, 0.5, 6.5),
		CFrame = CFrame.lookAt(armCenter, armCenter + toRoad),
		Color = metal,
		Material = Enum.Material.Metal,
		CanCollide = false,
	}, props)
	local headPos = pos + toRoad * 6 + Vector3.new(0, 23.6, 0)
	local lamp = anchored({
		Name = "Lamp",
		Size = Vector3.new(1.6, 0.35, 3),
		CFrame = CFrame.lookAt(headPos, headPos + toRoad),
		Color = Color3.fromRGB(255, 214, 150),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	}, props)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 58
	light.Angle = 120
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 196, 130)
	light.Parent = lamp
	table.insert(nightLights, light)
	table.insert(nightNeon, lamp)
end

local function building(center: Vector3, footprint: Vector3, height: number, buildings: Folder, props: Folder)
	local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
	local neon = NEON_COLORS[rng:NextInteger(1, #NEON_COLORS)]
	local b = anchored({
		Name = "Building",
		Size = Vector3.new(footprint.X, height, footprint.Z),
		CFrame = CFrame.new(center.X, SURFACE + height / 2, center.Z),
		Color = color,
		Material = if rng:NextNumber() < 0.5 then Enum.Material.Concrete else Enum.Material.Glass,
		Reflectance = 0.05,
	}, buildings)
	-- neon roof trim
	anchored({
		Name = "Trim",
		Size = Vector3.new(footprint.X + 1, 1.2, footprint.Z + 1),
		CFrame = CFrame.new(center.X, SURFACE + height + 0.6, center.Z),
		Color = neon,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, props)
	-- window bands
	local bands = math.floor(height / 24)
	for k = 1, bands do
		if rng:NextNumber() < 0.55 then
			local win = anchored({
				Name = "Windows",
				Size = Vector3.new(footprint.X + 0.4, 2, footprint.Z + 0.4),
				CFrame = CFrame.new(center.X, SURFACE + k * 24 - 6, center.Z),
				Color = if rng:NextNumber() < 0.7 then Color3.fromRGB(255, 230, 170) else neon,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				CanCollide = false,
				CanQuery = false,
			}, props)
			table.insert(nightNeon, win)
		end
	end
	-- occasional rooftop sign
	if height > 90 and rng:NextNumber() < 0.35 then
		local sign = anchored({
			Name = "Sign",
			Size = Vector3.new(footprint.X * 0.8, 14, 1),
			CFrame = CFrame.new(center.X, SURFACE + height + 9, center.Z),
			Color = Color3.fromRGB(10, 10, 14),
			CanCollide = false,
		}, props)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.LightInfluence = 0
			gui.Brightness = 3
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = SIGN_TEXTS[rng:NextInteger(1, #SIGN_TEXTS)]
			t.TextScaled = true
			t.Font = Enum.Font.GothamBlack
			t.TextColor3 = neon
			t.Parent = gui
			gui.Parent = sign
		end
	end
	return b
end

local function cityBlock(bx: number, bz: number, buildings: Folder, props: Folder, ground: Folder)
	local c = Grid.BlockCenter(bx, bz)
	anchored({
		Name = "Sidewalk",
		Size = Vector3.new(BLOCK, 1, BLOCK),
		CFrame = CFrame.new(c.X, SURFACE - 0.5, c.Z),
		Color = Color3.fromRGB(95, 95, 100),
		Material = Enum.Material.Concrete,
	}, ground)
	-- distance from centre makes downtown taller
	local d = (Vector3.new(c.X, 0, c.Z)).Magnitude / Grid.Half
	for _, ox in { -1, 1 } do
		for _, oz in { -1, 1 } do
			if rng:NextNumber() < 0.9 then
				local fx = rng:NextNumber(70, 98)
				local fz = rng:NextNumber(70, 98)
				local h = rng:NextNumber(35, 80) + (1 - math.clamp(d, 0, 1)) * rng:NextNumber(40, 170)
				building(c + Vector3.new(ox * 57, 0, oz * 57), Vector3.new(fx, 0, fz), h, buildings, props)
			end
		end
	end
	local edge = BLOCK / 2 - 3
	streetLight(c + Vector3.new(0, 0, -edge), -Vector3.zAxis, props)
	streetLight(c + Vector3.new(0, 0, edge), Vector3.zAxis, props)
	streetLight(c + Vector3.new(-edge, 0, 0), -Vector3.xAxis, props)
	streetLight(c + Vector3.new(edge, 0, 0), Vector3.xAxis, props)
end

local function safehouse(bx: number, bz: number, buildings: Folder, props: Folder, ground: Folder): (Vector3, { CFrame })
	local c = Grid.BlockCenter(bx, bz)
	anchored({
		Name = "SafehouseLot",
		Size = Vector3.new(BLOCK, 1, BLOCK),
		CFrame = CFrame.new(c.X, SURFACE - 0.5, c.Z),
		Color = Color3.fromRGB(30, 30, 36),
		Material = Enum.Material.Asphalt,
	}, ground)
	-- garage building at the back (+Z)
	local garage = anchored({
		Name = "Garage",
		Size = Vector3.new(180, 40, 60),
		CFrame = CFrame.new(c.X, SURFACE + 20, c.Z + 85),
		Color = Color3.fromRGB(25, 25, 30),
		Material = Enum.Material.Concrete,
	}, buildings)
	local sign = anchored({
		Name = "GarageSign",
		Size = Vector3.new(120, 12, 1),
		CFrame = CFrame.new(c.X, SURFACE + 34, c.Z + 54.4),
		Color = Color3.fromRGB(10, 10, 12),
		CanCollide = false,
	}, props)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 4
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "SAFEHOUSE"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.fromRGB(0, 255, 200)
	t.Parent = gui
	gui.Parent = sign
	sign.CFrame = CFrame.lookAt(sign.Position, sign.Position - Vector3.zAxis)
	local door = anchored({
		Name = "GarageDoor",
		Size = Vector3.new(60, 24, 1),
		CFrame = CFrame.new(c.X, SURFACE + 12, c.Z + 54.6),
		Color = Color3.fromRGB(0, 255, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	}, props)
	local _ = garage
	local _ = door

	local pad = anchored({
		Name = "SafehousePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 80, 80),
		CFrame = CFrame.new(c.X, SURFACE + 0.05, c.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(0, 255, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
	}, props)
	billboard(pad, "SAFEHOUSE - bank cash / garage", Color3.fromRGB(0, 255, 200), 18, 600)

	local spawns = {}
	for k = -3, 3 do
		local pos = Vector3.new(c.X + k * 22, SURFACE, c.Z + 20)
		table.insert(spawns, CFrame.lookAt(pos, pos - Vector3.zAxis))
	end
	return Vector3.new(c.X, SURFACE, c.Z), spawns
end

local function park(bx: number, bz: number, props: Folder, ground: Folder)
	local c = Grid.BlockCenter(bx, bz)
	anchored({
		Name = "Park",
		Size = Vector3.new(BLOCK, 1, BLOCK),
		CFrame = CFrame.new(c.X, SURFACE - 0.5, c.Z),
		Color = Color3.fromRGB(50, 110, 55),
		Material = Enum.Material.Grass,
	}, ground)
	for _ = 1, 14 do
		local p = c + Vector3.new(rng:NextNumber(-110, 110), 0, rng:NextNumber(-110, 110))
		if math.abs(p.X - c.X) > 50 or math.abs(p.Z - c.Z) > 50 then
			anchored({
				Name = "Trunk",
				Size = Vector3.new(2, 10, 2),
				CFrame = CFrame.new(p + Vector3.new(0, 5, 0)),
				Color = Color3.fromRGB(90, 60, 40),
				Material = Enum.Material.Wood,
			}, props)
			anchored({
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(12, 12, 12),
				CFrame = CFrame.new(p + Vector3.new(0, 13, 0)),
				Color = Color3.fromRGB(40, 140, 60),
				Material = Enum.Material.Grass,
				CanCollide = false,
			}, props)
		end
	end
	-- centre kicker ramps
	for _, dir in { Vector3.xAxis, -Vector3.xAxis } do
		local pos = c + dir * 25 + Vector3.new(0, 3, 0)
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(20, 6, 26)
		w.CFrame = CFrame.lookAt(pos, pos + dir)
		w.Color = Color3.fromRGB(255, 140, 0)
		w.Material = Enum.Material.DiamondPlate
		w.Parent = props
	end
end

local function hidingSpot(bx: number, bz: number, buildings: Folder, props: Folder, ground: Folder)
	local c = Grid.BlockCenter(bx, bz)
	anchored({
		Name = "GarageFloor",
		Size = Vector3.new(BLOCK, 1, BLOCK),
		CFrame = CFrame.new(c.X, SURFACE - 0.5, c.Z),
		Color = Color3.fromRGB(55, 55, 60),
		Material = Enum.Material.Concrete,
	}, ground)
	local size = BLOCK - 30
	anchored({
		Name = "GarageRoof",
		Size = Vector3.new(size, 3, size),
		CFrame = CFrame.new(c.X, SURFACE + 22, c.Z),
		Color = Color3.fromRGB(70, 70, 75),
		Material = Enum.Material.Concrete,
	}, buildings)
	for x = -2, 2 do
		for z = -2, 2 do
			if (x + z) % 2 == 0 then
				anchored({
					Name = "Pillar",
					Size = Vector3.new(3, 21, 3),
					CFrame = CFrame.new(c.X + x * 45, SURFACE + 10.5, c.Z + z * 45),
					Color = Color3.fromRGB(90, 90, 95),
					Material = Enum.Material.Concrete,
				}, buildings)
			end
		end
	end
	local marker = anchored({
		Name = "HideMarker",
		Size = Vector3.new(size, 0.2, 2),
		CFrame = CFrame.new(c.X, SURFACE + 20, c.Z - size / 2),
		Color = Color3.fromRGB(80, 255, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	}, props)
	billboard(marker, "HIDING SPOT", Color3.fromRGB(80, 255, 120), 6, 350)
end

local function pursuitBreaker(i: number, j: number, folder: Folder): Breaker
	local c = Grid.Intersection(i, j)
	local base = c + Vector3.new(36, 0, 36)
	local model = Instance.new("Model")
	model.Name = "PursuitBreaker"
	local partsList = {}
	local function add(p: BasePart)
		p.Parent = model
		table.insert(partsList, { part = p, cframe = p.CFrame })
	end
	for _, off in { Vector3.new(-6, 0, 0), Vector3.new(6, 0, 0) } do
		local leg = Instance.new("Part")
		leg.Anchored = true
		leg.Size = Vector3.new(2, 38, 2)
		leg.CFrame = CFrame.new(base + off + Vector3.new(0, 19 + SURFACE, 0))
		leg.Color = Color3.fromRGB(120, 120, 125)
		leg.Material = Enum.Material.Metal
		add(leg)
	end
	local panel = Instance.new("Part")
	panel.Anchored = true
	panel.Size = Vector3.new(30, 14, 2)
	panel.CFrame = CFrame.lookAt(base + Vector3.new(0, 44 + SURFACE, 0), c + Vector3.new(0, 44 + SURFACE, 0))
	panel.Color = Color3.fromRGB(255, 60, 60)
	panel.Material = Enum.Material.Neon
	add(panel)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "MEGA BURGER"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = gui
	gui.Parent = panel

	local ring = Instance.new("Part")
	ring.Name = "BreakerRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 24, 24)
	ring.CFrame = CFrame.new(base.X, SURFACE + 0.06, base.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 60, 60)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.5
	ring.Parent = model

	model.Parent = folder
	return { model = model, position = Vector3.new(base.X, SURFACE, base.Z), parts = partsList, armed = true }
end

local function speedCamera(pos: Vector3, axis: string, props: Folder)
	local side = if axis == "x" then Vector3.new(0, 0, ROAD / 2 + 3) else Vector3.new(ROAD / 2 + 3, 0, 0)
	local base = pos + side
	anchored({
		Name = "CamPole",
		Size = Vector3.new(1, 16, 1),
		CFrame = CFrame.new(base + Vector3.new(0, 8, 0)),
		Color = Color3.fromRGB(200, 200, 60),
		CanCollide = false,
	}, props)
	local cam = anchored({
		Name = "SpeedCam",
		Size = Vector3.new(3, 2.5, 3),
		CFrame = CFrame.new(base + Vector3.new(0, 16, 0)),
		Color = Color3.fromRGB(30, 30, 30),
		CanCollide = false,
	}, props)
	billboard(cam, "SPEED CAMERA", Color3.fromRGB(255, 230, 60), 5, 300)
end

local function ramp(pos: Vector3, axis: string, props: Folder)
	local dir = if axis == "x" then Vector3.xAxis else Vector3.zAxis
	for _, s in { 1, -1 } do
		local travel = dir * s
		local right = travel:Cross(Vector3.yAxis)
		local p = pos + right * 14 + Vector3.new(0, 3 + SURFACE, 0)
		local w = Instance.new("WedgePart")
		w.Name = "Ramp"
		w.Anchored = true
		w.Size = Vector3.new(22, 6, 34)
		w.CFrame = CFrame.lookAt(p, p - travel)
		w.Color = Color3.fromRGB(255, 150, 0)
		w.Material = Enum.Material.DiamondPlate
		w.Parent = props
	end
end

function MapBuilder.Build(): MapInfo
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = map
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = map
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = map
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = map
	local breakersFolder = Instance.new("Folder")
	breakersFolder.Name = "PursuitBreakers"
	breakersFolder.Parent = map

	local H = Grid.Half
	anchored({
		Name = "Base",
		Size = Vector3.new(H * 2 + 600, 2, H * 2 + 600),
		CFrame = CFrame.new(0, SURFACE - 1.1, 0),
		Color = Color3.fromRGB(30, 45, 35),
		Material = Enum.Material.Grass,
	}, ground)
	-- invisible boundary walls
	local wallDist = H + ROAD / 2 + 8
	for _, info in { { Vector3.new(wallDist, 0, 0), Vector3.new(4, 120, wallDist * 2) }, { Vector3.new(-wallDist, 0, 0), Vector3.new(4, 120, wallDist * 2) }, { Vector3.new(0, 0, wallDist), Vector3.new(wallDist * 2, 120, 4) }, { Vector3.new(0, 0, -wallDist), Vector3.new(wallDist * 2, 120, 4) } } do
		anchored({
			Name = "Boundary",
			Size = info[2],
			CFrame = CFrame.new(info[1] + Vector3.new(0, 60, 0)),
			Transparency = 1,
		}, buildings)
		local alongZ = info[2].Z > info[2].X
		anchored({
			Name = "BarrierGlow",
			Size = if alongZ then Vector3.new(2, 1.5, info[2].Z) else Vector3.new(info[2].X, 1.5, 2),
			CFrame = CFrame.new(info[1] + Vector3.new(0, SURFACE + 0.75, 0)),
			Color = Color3.fromRGB(255, 40, 160),
			Material = Enum.Material.Neon,
		}, props)
	end

	buildRoads(roads)

	local info: MapInfo = {
		safehouse = Vector3.zero,
		safehouseSpawns = {},
		hidingZones = {},
		breakers = {},
		speedCams = {},
		buildings = buildings,
		nightLights = nightLights,
		nightNeon = nightNeon,
	}

	local function isSpecial(bx: number, bz: number): string?
		local s = Config.Blocks.Safehouse
		if bx == s[1] and bz == s[2] then
			return "safehouse"
		end
		local p = Config.Blocks.Park
		if bx == p[1] and bz == p[2] then
			return "park"
		end
		for _, h in Config.Blocks.HidingSpots do
			if bx == h[1] and bz == h[2] then
				return "hide"
			end
		end
		return nil
	end

	for bx = 0, Grid.Size - 1 do
		for bz = 0, Grid.Size - 1 do
			local kind = isSpecial(bx, bz)
			if kind == "safehouse" then
				info.safehouse, info.safehouseSpawns = safehouse(bx, bz, buildings, props, ground)
			elseif kind == "park" then
				park(bx, bz, props, ground)
			elseif kind == "hide" then
				hidingSpot(bx, bz, buildings, props, ground)
				table.insert(info.hidingZones, { center = Grid.BlockCenter(bx, bz), size = Vector3.new(BLOCK - 30, 40, BLOCK - 30) })
			else
				cityBlock(bx, bz, buildings, props, ground)
			end
		end
	end

	for _, b in Config.PursuitBreakers do
		table.insert(info.breakers, pursuitBreaker(b[1], b[2], breakersFolder))
	end
	for _, cam in Config.SpeedCameras do
		local pos = Grid.SegmentMid(cam.i, cam.j, cam.axis)
		speedCamera(pos, cam.axis, props)
		table.insert(info.speedCams, pos)
	end
	for _, r in Config.Ramps do
		ramp(Grid.SegmentMid(r.i, r.j, r.axis), r.axis, props)
	end

	-- race start markers
	local markers = Instance.new("Folder")
	markers.Name = "RaceMarkers"
	markers.Parent = map
	for _, race in Config.Races do
		local p = race.route[1]
		local pos = Grid.Intersection(p[1], p[2])
		local m = anchored({
			Name = race.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 36, 36),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if race.kind == "drift" then Color3.fromRGB(255, 120, 0) else Color3.fromRGB(255, 40, 160),
			Material = Enum.Material.Neon,
			Transparency = 0.45,
			CanCollide = false,
			CanQuery = false,
		}, markers)
		billboard(m, string.upper(race.kind) .. ": " .. race.name .. "  ($" .. race.buyIn .. " buy-in)", Color3.new(1, 1, 1), 12, 500)
	end

	map.Parent = workspace
	return info
end

-- Resets a pursuit breaker after it collapsed.
function MapBuilder.ResetBreaker(b: Breaker)
	for _, entry in b.parts do
		entry.part.Anchored = true
		entry.part.AssemblyLinearVelocity = Vector3.zero
		entry.part.AssemblyAngularVelocity = Vector3.zero
		entry.part.CFrame = entry.cframe
		entry.part.CanCollide = true
	end
	b.armed = true
	local ring = b.model:FindFirstChild("BreakerRing") :: BasePart?
	if ring then
		ring.Transparency = 0.5
	end
end

-- Collapse a pursuit breaker onto the road.
function MapBuilder.CollapseBreaker(b: Breaker, towards: Vector3)
	b.armed = false
	local ring = b.model:FindFirstChild("BreakerRing") :: BasePart?
	if ring then
		ring.Transparency = 1
	end
	local dir = towards - b.position
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 1 then
		dir = Vector3.xAxis
	end
	dir = dir.Unit
	for _, entry in b.parts do
		entry.part.Anchored = false
		entry.part.CanCollide = true
		entry.part.AssemblyLinearVelocity = dir * 40 + Vector3.new(0, 10, 0)
		entry.part.AssemblyAngularVelocity = dir:Cross(Vector3.yAxis) * -2
	end
end

return MapBuilder
