--!strict
-- Procedurally builds the city of Neon Bay: road grid, skyscrapers, the safehouse,
-- a park, covered hiding spots, pursuit breakers, speed cameras and ramps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local Architecture = require(script.Parent.Architecture)

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
	nightToggles: { Architecture.Toggle },
	blackMarket: Vector3,
	collectibles: { { id: string, position: Vector3 } },
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

-- The outer ring road is the Neon Bay Beltway: extra lane lines, guard rails and sign gantries.
local EXITS = { "DOWNTOWN", "HARBOR / DOCKS", "SUBURBS", "AIRPORT", "BEACH", "MIDTOWN" }
local function freeway(mid: Vector3, alongX: boolean, segLen: number, outward: number, index: number, folder: Folder)
	local function offset(o: number): Vector3
		return if alongX then Vector3.new(0, 0, o) else Vector3.new(o, 0, 0)
	end
	local function size(len: number, h: number, w: number): Vector3
		return if alongX then Vector3.new(len, h, w) else Vector3.new(w, h, len)
	end
	for _, o in { -15, 15 } do
		local p = mid + offset(o)
		anchored({ Name = "LaneLine", Size = size(segLen - 6, 0.04, 0.45), CFrame = CFrame.new(p.X, SURFACE + 0.02, p.Z), Color = Color3.fromRGB(225, 225, 225), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false }, folder)
	end
	local railPos = mid + offset(outward * (ROAD / 2 - 1))
	for _, h in { 1.6, 2.6 } do
		anchored({ Name = "GuardRail", Size = size(segLen, 0.45, 0.3), CFrame = CFrame.new(railPos.X, SURFACE + h, railPos.Z), Color = Color3.fromRGB(190, 192, 196), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }, folder)
	end
	if index % 3 == 1 then
		local metal = Color3.fromRGB(120, 124, 130)
		for _, o in { -ROAD / 2 + 1, ROAD / 2 - 1 } do
			local p = mid + offset(o)
			anchored({ Name = "GantryPost", Size = Vector3.new(1.2, 26, 1.2), CFrame = CFrame.new(p.X, SURFACE + 13, p.Z), Color = metal, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }, folder)
		end
		anchored({ Name = "GantryBeam", Size = size(1.2, 1.4, ROAD), CFrame = CFrame.new(mid.X, SURFACE + 25, mid.Z), Color = metal, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }, folder)
		for _, facing in { 1, -1 } do
			local dir = if alongX then Vector3.new(facing, 0, 0) else Vector3.new(0, 0, facing)
			local signPos = Vector3.new(mid.X, SURFACE + 21, mid.Z) - dir * 0.8
			local sign = anchored({ Name = "HighwaySign", Size = Vector3.new(22, 7, 0.4), CFrame = CFrame.lookAt(signPos, signPos - dir), Color = Color3.fromRGB(20, 110, 55), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false }, folder)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.LightInfluence = 0.4
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = "BELTWAY  -  EXIT " .. (index + 1) .. "\n" .. EXITS[(index % #EXITS) + 1]
			t.TextScaled = true
			t.Font = Enum.Font.GothamBold
			t.TextColor3 = Color3.fromRGB(245, 245, 245)
			t.Parent = gui
			gui.Parent = sign
		end
	end
end

local function buildRoads(folder: Folder)
	local N = Grid.Size
	local asphalt = Color3.fromRGB(58, 58, 61)
	local segLen = Grid.Cell - ROAD
	for i = 0, N do
		task.wait()
		for j = 0, N do
			local c = Grid.Intersection(i, j)
			Architecture.Intersection(c, ROAD, Config.IntersectionMode(i, j))
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
				if j == 0 or j == N then
					freeway(mid, true, segLen, if j == 0 then -1 else 1, i, folder)
				end
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
				if i == 0 or i == N then
					freeway(mid, false, segLen, if i == 0 then -1 else 1, j, folder)
				end
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
	light.Range = 52
	light.Angle = 120
	light.Brightness = 3.2
	light.Color = Color3.fromRGB(255, 196, 130)
	light.Parent = lamp
	table.insert(nightLights, light)
	table.insert(nightNeon, lamp)
end

local DISTRICT_FLOOR = {
	downtown = { color = Color3.fromRGB(118, 116, 112), material = Enum.Material.Concrete },
	midtown = { color = Color3.fromRGB(118, 116, 112), material = Enum.Material.Concrete },
	suburb = { color = Color3.fromRGB(78, 118, 62), material = Enum.Material.Grass },
	industrial = { color = Color3.fromRGB(96, 96, 98), material = Enum.Material.Concrete },
}

local function cityBlock(bx: number, bz: number, ground: Folder, props: Folder)
	local c = Grid.BlockCenter(bx, bz)
	local district = Config.District(bx, bz)
	local floor = DISTRICT_FLOOR[district]
	anchored({
		Name = "Block",
		Size = Vector3.new(BLOCK, 1, BLOCK),
		CFrame = CFrame.new(c.X, SURFACE - 0.5, c.Z),
		Color = floor.color,
		Material = floor.material,
	}, ground)
	local edge = BLOCK / 2 - 3
	if district == "suburb" then
		Architecture.Suburb(c, BLOCK)
		Architecture.Sidewalks(c, BLOCK, false, "suburb")
		streetLight(c + Vector3.new(0, 0, if bx % 2 == 0 then -edge else edge), if bx % 2 == 0 then -Vector3.zAxis else Vector3.zAxis, props)
		return
	elseif district == "industrial" then
		Architecture.Industrial(c, BLOCK, bx == Grid.Size - 1)
		Architecture.Sidewalks(c, BLOCK, false, "industrial")
		streetLight(c + Vector3.new(edge, 0, 0), Vector3.xAxis, props)
		return
	end
	-- downtown gets towers (taller towards the centre), midtown mostly brick, offices and shops
	local d = Vector3.new(c.X, 0, c.Z).Magnitude / Grid.Half
	local downtown = if district == "downtown" then 0.6 + (1 - math.clamp(d / 0.3, 0, 1)) * 0.4 else 0.3
	for _, ox in { -1, 1 } do
		for _, oz in { -1, 1 } do
			Architecture.Lot(c + Vector3.new(ox * 57, 0, oz * 57), { Vector3.new(ox, 0, 0), Vector3.new(0, 0, oz) }, downtown)
		end
	end
	Architecture.Sidewalks(c, BLOCK, rng:NextNumber() < 0.3)
	-- two lamps per block (on opposite sides) keeps every street lit without hundreds of lights
	if (bx + bz) % 2 == 0 then
		streetLight(c + Vector3.new(0, 0, -edge), -Vector3.zAxis, props)
		streetLight(c + Vector3.new(0, 0, edge), Vector3.zAxis, props)
	else
		streetLight(c + Vector3.new(-edge, 0, 0), -Vector3.xAxis, props)
		streetLight(c + Vector3.new(edge, 0, 0), Vector3.xAxis, props)
	end
end

-- Terrain around the city: ocean and beaches to the east and south, hills and mountains to the
-- north and west.
local function buildTerrain()
	local terrain = workspace.Terrain
	local H = Grid.Half
	local wall = H + ROAD / 2 + 8
	local far = 1400
	terrain.WaterColor = Color3.fromRGB(18, 70, 90)
	terrain.WaterTransparency = 0.25
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.35
	terrain.WaterWaveSpeed = 8
	local function fill(minV: Vector3, maxV: Vector3, material: Enum.Material)
		local size = maxV - minV
		terrain:FillBlock(CFrame.new((minV + maxV) / 2), size, material)
	end
	-- land ring (north + west) with grass
	fill(Vector3.new(-wall - far, -12, -wall - far), Vector3.new(wall + 170, 0, -wall), Enum.Material.Grass)
	fill(Vector3.new(-wall - far, -12, -wall), Vector3.new(-wall, 0, wall + 170), Enum.Material.Grass)
	-- beaches
	fill(Vector3.new(wall, -12, -wall - far), Vector3.new(wall + 170, 0, wall + 170), Enum.Material.Sand)
	fill(Vector3.new(-wall - far, -12, wall), Vector3.new(wall + 170, 0, wall + 170), Enum.Material.Sand)
	-- sea bed and water
	fill(Vector3.new(wall + 170, -44, -wall - far), Vector3.new(wall + far + 400, -30, wall + far + 400), Enum.Material.Sand)
	fill(Vector3.new(-wall - far, -44, wall + 170), Vector3.new(wall + 170, -30, wall + far + 400), Enum.Material.Sand)
	fill(Vector3.new(wall + 170, -30, -wall - far), Vector3.new(wall + far + 400, -2, wall + far + 400), Enum.Material.Water)
	fill(Vector3.new(-wall - far, -30, wall + 170), Vector3.new(wall + 170, -2, wall + far + 400), Enum.Material.Water)
	-- hills close by, mountains further out
	local trng = Random.new(5)
	for _ = 1, 26 do
		local side = trng:NextNumber()
		local along = trng:NextNumber(-wall - far, wall)
		local dist = trng:NextNumber(260, far - 200)
		local pos = if side < 0.5 then Vector3.new(along, 0, -wall - dist) else Vector3.new(-wall - dist, 0, along)
		local mountain = dist > 700
		local r = if mountain then trng:NextNumber(260, 480) else trng:NextNumber(90, 200)
		local y = if mountain then -r * 0.35 else -r * 0.6
		terrain:FillBall(pos + Vector3.new(0, y, 0), r, if mountain then Enum.Material.Rock else Enum.Material.Grass)
		if mountain then
			terrain:FillBall(pos + Vector3.new(0, y + r * 0.55, 0), r * 0.45, Enum.Material.Snow)
		end
	end
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
		Color = Color3.fromRGB(96, 58, 46),
		Material = Enum.Material.Brick,
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

-- The Black Market: a graffiti-covered garage behind a fence at the docks. Weapons for sale.
local function blackMarket(bx: number, bz: number, buildings: Folder, props: Folder, ground: Folder): Vector3
	local c = Grid.BlockCenter(bx, bz)
	anchored({ Name = "BlackMarketLot", Size = Vector3.new(BLOCK, 1, BLOCK), CFrame = CFrame.new(c.X, SURFACE - 0.5, c.Z), Color = Color3.fromRGB(34, 34, 38), Material = Enum.Material.Asphalt }, ground)
	anchored({ Name = "BlackMarketShed", Size = Vector3.new(150, 34, 56), CFrame = CFrame.new(c.X, SURFACE + 17, c.Z + 80), Color = Color3.fromRGB(70, 40, 36), Material = Enum.Material.Brick }, buildings)
	-- half-open roll-up door glowing red inside
	anchored({ Name = "Door", Size = Vector3.new(44, 12, 0.6), CFrame = CFrame.new(c.X, SURFACE + 20, c.Z + 51.8), Color = Color3.fromRGB(90, 92, 96), Material = Enum.Material.CorrodedMetal, CanCollide = false }, props)
	local glow = anchored({ Name = "InsideGlow", Size = Vector3.new(44, 14, 0.4), CFrame = CFrame.new(c.X, SURFACE + 7, c.Z + 52.2), Color = Color3.fromRGB(255, 30, 40), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false }, props)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Range = 40
	light.Brightness = 3
	light.Parent = glow
	glow.CFrame = CFrame.lookAt(glow.Position, glow.Position - Vector3.zAxis)
	local sign = anchored({ Name = "Sign", Size = Vector3.new(70, 9, 0.6), CFrame = CFrame.new(c.X, SURFACE + 29, c.Z + 51.6), Color = Color3.fromRGB(10, 10, 12), CanCollide = false }, props)
	sign.CFrame = CFrame.lookAt(sign.Position, sign.Position - Vector3.zAxis)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 3
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "BLACK MARKET AUTO"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.fromRGB(255, 40, 50)
	t.Parent = gui
	gui.Parent = sign
	-- graffiti tags on the walls
	for k, tag in { "NO COPS", "RVLT", "BURN IT" } do
		local wall = anchored({ Name = "Graffiti", Size = Vector3.new(24, 8, 0.2), CFrame = CFrame.new(c.X - 60 + (k - 1) * 40, SURFACE + 8 + (k % 2) * 3, c.Z + 51.7), Color = Color3.fromRGB(70, 40, 36), Transparency = 1, CanCollide = false, CanQuery = false }, props)
		wall.CFrame = CFrame.lookAt(wall.Position, wall.Position - Vector3.zAxis)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = tag
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = ({ Color3.fromRGB(120, 255, 60), Color3.fromRGB(255, 80, 200), Color3.fromRGB(60, 200, 255) })[k]
		l.Rotation = -6 + k * 4
		l.Parent = g
		g.Parent = wall
	end
	-- chain-link fence with a gap at the front, burning barrels
	for _, side in { -1, 1 } do
		anchored({ Name = "Fence", Size = Vector3.new(0.3, 10, BLOCK - 40), CFrame = CFrame.new(c.X + side * (BLOCK / 2 - 20), SURFACE + 5, c.Z + 10), Color = Color3.fromRGB(150, 155, 160), Material = Enum.Material.ForceField, Transparency = 0.3, CanCollide = false, CanQuery = false }, props)
	end
	for _, o in { Vector3.new(-40, 0, 30), Vector3.new(40, 0, 30), Vector3.new(-60, 0, -40) } do
		local barrel = anchored({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 3, 3), CFrame = CFrame.new(c + o + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 55, 50), Material = Enum.Material.CorrodedMetal }, props)
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 8
		fire.Parent = barrel
		local fl = Instance.new("PointLight")
		fl.Color = Color3.fromRGB(255, 140, 50)
		fl.Range = 20
		fl.Brightness = 2
		fl.Parent = barrel
	end
	local pad = anchored({ Name = "BlackMarketPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 70, 70), CFrame = CFrame.new(c.X, SURFACE + 0.05, c.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 30, 40), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, CanQuery = false }, props)
	billboard(pad, "BLACK MARKET - roof weapons", Color3.fromRGB(255, 60, 60), 16, 500)
	return Vector3.new(c.X, SURFACE, c.Z)
end

local TAGS = { "NEO", "RVLT", "DRFT", "WNTD", "ZERO", "GHST", "KAIJU", "BURN", "FAST", "LOW", "NITRO", "BAY" }
local TAG_COLORS = { Color3.fromRGB(255, 60, 170), Color3.fromRGB(60, 220, 255), Color3.fromRGB(140, 255, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(190, 90, 255) }

-- Street art collectibles: bright tagged panels on sidewalks all over the city.
local function placeCollectibles(info: MapInfo, isSpecial: (number, number) -> string?, map: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "Collectibles"
	folder.Parent = map
	local crng = Random.new(99)
	local used: { [string]: boolean } = {}
	local placed = 0
	while placed < Config.CollectibleCount do
		local bx, bz = crng:NextInteger(0, Grid.Size - 1), crng:NextInteger(0, Grid.Size - 1)
		local key = bx .. "," .. bz
		if used[key] or isSpecial(bx, bz) then
			continue
		end
		used[key] = true
		placed += 1
		local c = Grid.BlockCenter(bx, bz)
		local dirs = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }
		local n = dirs[crng:NextInteger(1, 4)]
		local across = n:Cross(Vector3.yAxis)
		local pos = c + n * (BLOCK / 2 - 9) + across * crng:NextNumber(-70, 70)
		local id = "art_" .. placed
		local panel = anchored({
			Name = id,
			Size = Vector3.new(9, 6, 0.4),
			CFrame = CFrame.lookAt(pos + Vector3.new(0, 4.5, 0), pos + Vector3.new(0, 4.5, 0) + n),
			Color = Color3.fromRGB(20, 20, 24),
			CanCollide = false,
			CanQuery = false,
		}, folder)
		local color = TAG_COLORS[crng:NextInteger(1, #TAG_COLORS)]
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.LightInfluence = 0
		g.Brightness = 2
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = TAGS[crng:NextInteger(1, #TAGS)]
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = color
		l.Rotation = crng:NextNumber(-8, 8)
		l.Parent = g
		g.Parent = panel
		table.insert(info.collectibles, { id = id, position = pos })
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
	local signalsFolder = Instance.new("Folder")
	signalsFolder.Name = "Signals"
	signalsFolder.Parent = map
	Architecture.Init(buildings, props, signalsFolder, SURFACE)
	local breakersFolder = Instance.new("Folder")
	breakersFolder.Name = "PursuitBreakers"
	breakersFolder.Parent = map

	local H = Grid.Half
	anchored({
		Name = "Base",
		Size = Vector3.new(H * 2 + 120, 2, H * 2 + 120),
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
			Name = "JerseyBarrier",
			Size = if alongZ then Vector3.new(2.4, 3, info[2].Z) else Vector3.new(info[2].X, 3, 2.4),
			CFrame = CFrame.new(info[1] + Vector3.new(0, SURFACE + 1.5, 0)),
			Color = Color3.fromRGB(175, 172, 165),
			Material = Enum.Material.Concrete,
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
		nightToggles = Architecture.Toggles(),
		blackMarket = Vector3.zero,
		collectibles = {},
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
		local bm = Config.Blocks.BlackMarket
		if bx == bm[1] and bz == bm[2] then
			return "blackmarket"
		end
		return nil
	end

	buildTerrain()
	for bx = 0, Grid.Size - 1 do
		task.wait() -- building ~50k parts: yield between rows so the server never times out
		for bz = 0, Grid.Size - 1 do
			local kind = isSpecial(bx, bz)
			if kind == "safehouse" then
				info.safehouse, info.safehouseSpawns = safehouse(bx, bz, buildings, props, ground)
				Architecture.Sidewalks(Grid.BlockCenter(bx, bz), BLOCK, false)
			elseif kind == "park" then
				park(bx, bz, props, ground)
				Architecture.Sidewalks(Grid.BlockCenter(bx, bz), BLOCK, true)
			elseif kind == "blackmarket" then
				info.blackMarket = blackMarket(bx, bz, buildings, props, ground)
				Architecture.Sidewalks(Grid.BlockCenter(bx, bz), BLOCK, false, "industrial")
			elseif kind == "hide" then
				hidingSpot(bx, bz, buildings, props, ground)
				Architecture.Sidewalks(Grid.BlockCenter(bx, bz), BLOCK, false)
				table.insert(info.hidingZones, { center = Grid.BlockCenter(bx, bz), size = Vector3.new(BLOCK - 30, 40, BLOCK - 30) })
			else
				cityBlock(bx, bz, ground, props)
			end
		end
	end

	placeCollectibles(info, isSpecial, map)
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
