--[[
	MapBuilder
	Builds NEURAL OUTPOST procedurally from MapData (brief sections 4-7).

	Everything is generated rather than hand-placed so the layout stays in one
	editable place, and so the waypoints the enemies walk are guaranteed to
	match the road the player can see. Part count is kept deliberately low:
	a handful of large, readable shapes plus targeted lighting, rather than
	hundreds of tiny props.
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapData = require(ReplicatedStorage.Shared.MapData)

local C = MapData.Colors

local MapBuilder = {}

--============================================================
-- Primitives
--============================================================

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.Metal
	part.Color = C.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(part :: any)[key] = value
	end
	return part
end

local function neon(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, lightRange: number?): Part
	local part = makePart({
		CFrame = cframe,
		Size = size,
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
		CastShadow = false,
	})
	part.Parent = parent
	if lightRange then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = lightRange
		light.Brightness = 2
		light.Parent = part
	end
	return part
end

local function screen(parent: Instance, cframe: CFrame, text: string, color: Color3, size: Vector3?)
	local panel = makePart({
		CFrame = cframe,
		Size = size or Vector3.new(8, 5, 0.4),
		Material = Enum.Material.SmoothPlastic,
		Color = C.DarkMetal,
		CanCollide = false,
	})
	panel.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = panel

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Parent = gui

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 1.4
	light.Parent = panel

	return panel
end

-- A slow blinking hazard light. One tween loop per lamp, no per-frame work.
local function warningLight(parent: Instance, position: Vector3, color: Color3)
	local lamp = neon(parent, CFrame.new(position), Vector3.new(1.6, 0.6, 1.6), color, 18)
	local light = lamp:FindFirstChildOfClass("PointLight")
	if light then
		TweenService:Create(
			light,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Brightness = 0.15 }
		):Play()
	end
	return lamp
end

local function pipe(parent: Instance, from: Vector3, to: Vector3, thickness: number, color: Color3?)
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	local part = makePart({
		CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to),
		Size = Vector3.new(thickness, thickness, distance),
		Color = color or C.DarkMetal,
		CanCollide = false,
		CastShadow = false,
	})
	part.Parent = parent
	return part
end

--============================================================
-- Road
--============================================================

-- Lays a road slab between each pair of waypoints, plus a glowing centre line
-- so the route reads instantly from the top-down camera.
local function buildRoadSegment(parent: Instance, from: Vector3, to: Vector3, width: number, accent: Color3)
	local delta = to - from
	local distance = delta.Magnitude
	if distance < 0.1 then
		return
	end
	local midpoint = from:Lerp(to, 0.5)
	local lookCFrame = CFrame.lookAt(midpoint + Vector3.new(0, 0.15, 0), to + Vector3.new(0, 0.15, 0))

	local slab = makePart({
		CFrame = lookCFrame,
		Size = Vector3.new(width, 0.3, distance + width * 0.5),
		Material = Enum.Material.Concrete,
		Color = C.FloorAccent,
	})
	slab.Parent = parent

	local line = makePart({
		CFrame = lookCFrame * CFrame.new(0, 0.18, 0),
		Size = Vector3.new(0.6, 0.08, distance),
		Material = Enum.Material.Neon,
		Color = accent,
		CanCollide = false,
		CastShadow = false,
		Transparency = 0.25,
	})
	line.Parent = parent

	-- Kerb strips make the path edge legible without extra lighting cost.
	for _, side in ipairs({ -1, 1 }) do
		local kerb = makePart({
			CFrame = lookCFrame * CFrame.new(side * width / 2, 0.15, 0),
			Size = Vector3.new(0.8, 0.6, distance),
			Color = C.DarkMetal,
			CastShadow = false,
		})
		kerb.Parent = parent
	end
end

local function buildPath(parent: Instance, waypoints: { any }, accent: Color3)
	for index = 2, #waypoints do
		buildRoadSegment(parent, waypoints[index - 1].Position, waypoints[index].Position, MapData.PathWidth, accent)
	end
end

--============================================================
-- Zones
--============================================================

local function buildSpawnGate(parent: Instance)
	local origin = MapData.MainPath[1].Position

	local platform = makePart({
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, -12)),
		Size = Vector3.new(48, 1, 30),
		Material = Enum.Material.DiamondPlate,
		Color = C.DarkMetal,
	})
	platform.Parent = parent

	-- Reinforced gate frame.
	for _, side in ipairs({ -1, 1 }) do
		local pillar = makePart({
			CFrame = CFrame.new(origin + Vector3.new(side * 13, 9, 6)),
			Size = Vector3.new(5, 18, 5),
			Color = C.Metal,
		})
		pillar.Parent = parent
		neon(parent, CFrame.new(origin + Vector3.new(side * 10.6, 9, 6)), Vector3.new(0.4, 15, 0.4), C.WarningRed, 16)
		warningLight(parent, origin + Vector3.new(side * 13, 18.5, 6), C.WarningRed)
	end

	local lintel = makePart({
		CFrame = CFrame.new(origin + Vector3.new(0, 18, 6)),
		Size = Vector3.new(31, 3.5, 5),
		Color = C.Metal,
	})
	lintel.Parent = parent

	screen(
		parent,
		CFrame.new(origin + Vector3.new(0, 13, 3.4)),
		"CONTAINMENT BREACH\nSECTOR 7",
		C.WarningRed,
		Vector3.new(20, 6, 0.4)
	)

	-- The breach itself: a dark recessed mouth the units walk out of.
	local breach = makePart({
		CFrame = CFrame.new(origin + Vector3.new(0, 6, 8.5)),
		Size = Vector3.new(20, 12, 1),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(8, 8, 12),
		CanCollide = false,
	})
	breach.Parent = parent
	neon(parent, CFrame.new(origin + Vector3.new(0, 0.4, 8)), Vector3.new(20, 0.2, 0.6), C.WarningRed, 20)

	-- Machinery clutter around the gate.
	for _, offset in ipairs({ Vector3.new(-20, 3, -2), Vector3.new(20, 3, -2) }) do
		local machine = makePart({
			CFrame = CFrame.new(origin + offset),
			Size = Vector3.new(6, 6, 8),
			Color = C.Metal,
		})
		machine.Parent = parent
		neon(parent, CFrame.new(origin + offset + Vector3.new(0, 3.2, 0)), Vector3.new(4, 0.2, 6), C.WarningAmber, 12)
		pipe(parent, origin + offset + Vector3.new(0, 5, 0), origin + offset + Vector3.new(0, 12, 10), 0.8)
	end
end

local function buildLeftSector(parent: Instance)
	-- Ruined laboratory: observation glass, terminals, collapsed walls.
	local floor = makePart({
		CFrame = CFrame.new(-72, -0.5, -20),
		Size = Vector3.new(56, 1, 90),
		Material = Enum.Material.Concrete,
		Color = C.Floor,
	})
	floor.Parent = parent

	for index, z in ipairs({ -50, -28, -6, 16 }) do
		-- Broken lab wall, deliberately uneven so the sector reads as damaged.
		local height = 10 - (index % 2) * 3
		local wall = makePart({
			CFrame = CFrame.new(-96, height / 2, z),
			Size = Vector3.new(1.5, height, 16),
			Color = C.Metal,
		})
		wall.Parent = parent

		-- Observation glass.
		local glass = makePart({
			CFrame = CFrame.new(-96, height / 2 + 1, z),
			Size = Vector3.new(0.6, height * 0.5, 12),
			Material = Enum.Material.Glass,
			Color = C.EnergyCyan,
			Transparency = 0.65,
			CanCollide = false,
		})
		glass.Parent = parent
	end

	-- Computer terminals.
	for _, position in ipairs({ Vector3.new(-86, 0, -40), Vector3.new(-86, 0, -12), Vector3.new(-86, 0, 12) }) do
		local desk = makePart({
			CFrame = CFrame.new(position + Vector3.new(0, 2, 0)),
			Size = Vector3.new(4, 4, 7),
			Color = C.DarkMetal,
		})
		desk.Parent = parent
		screen(parent, CFrame.new(position + Vector3.new(2.3, 4.5, 0)) * CFrame.Angles(0, math.rad(90), 0), "> ANALYSING\n> SUBJECT LOST", C.EnergyCyan, Vector3.new(6, 3.5, 0.3))
	end

	-- Toppled equipment.
	for _, spec in ipairs({
		{ pos = Vector3.new(-70, 1.5, -44), rot = 0.3 },
		{ pos = Vector3.new(-76, 1.5, 4), rot = -0.5 },
		{ pos = Vector3.new(-66, 1.5, 30), rot = 0.9 },
	}) do
		local crate = makePart({
			CFrame = CFrame.new(spec.pos) * CFrame.Angles(spec.rot, spec.rot, 0),
			Size = Vector3.new(4, 3, 4),
			Color = C.Metal,
		})
		crate.Parent = parent
	end
end

local function buildRightSector(parent: Instance)
	-- Power plant: generators, coils, open floor.
	local floor = makePart({
		CFrame = CFrame.new(72, -0.5, -20),
		Size = Vector3.new(56, 1, 90),
		Material = Enum.Material.Concrete,
		Color = C.Floor,
	})
	floor.Parent = parent

	for _, z in ipairs({ -46, -18, 10 }) do
		-- Generator housing.
		local housing = makePart({
			CFrame = CFrame.new(90, 6, z),
			Size = Vector3.new(12, 12, 14),
			Color = C.Metal,
		})
		housing.Parent = parent

		-- Exposed energy coil, slowly pulsing.
		local coil = neon(parent, CFrame.new(90, 13.5, z), Vector3.new(3, 3, 3), C.EnergyBlue, 24)
		coil.Shape = Enum.PartType.Ball
		TweenService:Create(
			coil,
			TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Size = Vector3.new(4.4, 4.4, 4.4), Transparency = 0.25 }
		):Play()

		pipe(parent, Vector3.new(84, 10, z), Vector3.new(66, 10, z), 1.2)
		neon(parent, CFrame.new(84, 3, z), Vector3.new(0.3, 4, 10), C.EnergyBlue, 12)
	end

	-- Damaged machinery in the open ground.
	for _, spec in ipairs({
		{ pos = Vector3.new(66, 2, -34), size = Vector3.new(6, 4, 6) },
		{ pos = Vector3.new(70, 3, 2), size = Vector3.new(5, 6, 5) },
		{ pos = Vector3.new(64, 1.5, 28), size = Vector3.new(8, 3, 5) },
	}) do
		local hulk = makePart({ CFrame = CFrame.new(spec.pos), Size = spec.size, Color = C.DarkMetal })
		hulk.Parent = parent
		neon(parent, CFrame.new(spec.pos + Vector3.new(0, spec.size.Y / 2 + 0.2, 0)), Vector3.new(spec.size.X * 0.6, 0.2, spec.size.Z * 0.6), C.WarningAmber, 10)
	end
end

local function buildCentralHub(parent: Instance)
	local center = MapData.HubCenter

	-- Circular platform, built from a cylinder so it stays one part.
	local disc = makePart({
		CFrame = CFrame.new(center + Vector3.new(0, -0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Size = Vector3.new(1.2, MapData.HubRadius * 2, MapData.HubRadius * 2),
		Material = Enum.Material.Concrete,
		Color = C.Floor,
	})
	disc.Shape = Enum.PartType.Cylinder
	disc.Parent = parent

	-- Concentric glowing rings.
	for _, radius in ipairs({ 34, 24, 14 }) do
		local ring = makePart({
			CFrame = CFrame.new(center + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Size = Vector3.new(0.2, radius * 2, radius * 2),
			Material = Enum.Material.Neon,
			Color = C.EnergyBlue,
			Transparency = 0.72,
			CanCollide = false,
			CastShadow = false,
		})
		ring.Shape = Enum.PartType.Cylinder
		ring.Parent = parent
	end

	-- Holographic projectors around the rim.
	for index = 0, 5 do
		local angle = (index / 6) * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * 36, 0, math.sin(angle) * 36)

		local base = makePart({
			CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)),
			Size = Vector3.new(3, 3, 3),
			Color = C.DarkMetal,
		})
		base.Parent = parent

		local holo = neon(parent, CFrame.new(position + Vector3.new(0, 6, 0)), Vector3.new(2.5, 5, 2.5), C.EnergyCyan, 16)
		holo.Transparency = 0.6
		TweenService:Create(
			holo,
			TweenInfo.new(2.2 + index * 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.85, Size = Vector3.new(2.5, 7, 2.5) }
		):Play()

		pipe(parent, position + Vector3.new(0, 0.5, 0), center + Vector3.new(0, 0.5, 0), 0.5, C.DarkMetal)
	end
end

local function buildCore(parent: Instance): Model
	local coreModel = Instance.new("Model")
	coreModel.Name = "Core"
	coreModel.Parent = parent

	local position = MapData.CorePosition

	local pedestal = makePart({
		CFrame = CFrame.new(position - Vector3.new(0, 8, 0)),
		Size = Vector3.new(26, 4, 26),
		Material = Enum.Material.DiamondPlate,
		Color = C.DarkMetal,
	})
	pedestal.Name = "Pedestal"
	pedestal.Parent = coreModel

	local shell = makePart({
		CFrame = CFrame.new(position),
		Size = Vector3.new(14, 14, 14),
		Material = Enum.Material.Neon,
		Color = C.CoreGlow,
		Transparency = 0.35,
		CanCollide = false,
	})
	shell.Shape = Enum.PartType.Ball
	shell.Name = "Shell"
	shell.Parent = coreModel
	coreModel.PrimaryPart = shell

	local light = Instance.new("PointLight")
	light.Color = C.CoreGlow
	light.Range = 60
	light.Brightness = 3
	light.Name = "CoreLight"
	light.Parent = shell

	local inner = makePart({
		CFrame = CFrame.new(position),
		Size = Vector3.new(7, 7, 7),
		Material = Enum.Material.Neon,
		Color = Color3.new(1, 1, 1),
		CanCollide = false,
	})
	inner.Shape = Enum.PartType.Ball
	inner.Name = "Inner"
	inner.Parent = coreModel

	-- Support arms.
	for index = 0, 3 do
		local angle = (index / 4) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 10, 0, math.sin(angle) * 10)
		local arm = makePart({
			CFrame = CFrame.new(position + offset - Vector3.new(0, 4, 0)),
			Size = Vector3.new(2, 10, 2),
			Color = C.Metal,
		})
		arm.Parent = coreModel
		warningLight(coreModel, position + offset + Vector3.new(0, 2, 0), C.EnergyBlue)
	end

	-- HP readout above the Core.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CoreHP"
	billboard.Size = UDim2.fromOffset(320, 110)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.Parent = shell

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.34, 0)
	title.BackgroundTransparency = 1
	title.Text = "CORE"
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = C.EnergyCyan
	title.TextScaled = true
	title.Parent = billboard

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(1, 0, 0.44, 0)
	value.Position = UDim2.new(0, 0, 0.34, 0)
	value.BackgroundTransparency = 1
	value.Text = "1000 / 1000"
	value.Font = Enum.Font.GothamBlack
	value.TextColor3 = Color3.new(1, 1, 1)
	value.TextScaled = true
	value.Parent = billboard

	local barTrack = Instance.new("Frame")
	barTrack.Name = "BarTrack"
	barTrack.Size = UDim2.new(0.86, 0, 0.13, 0)
	barTrack.Position = UDim2.new(0.07, 0, 0.8, 0)
	barTrack.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	barTrack.BorderSizePixel = 0
	barTrack.Parent = billboard

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = C.EnergyCyan
	barFill.BorderSizePixel = 0
	barFill.Parent = barTrack

	return coreModel
end

local function buildEnvironment(parent: Instance)
	-- Outer ground so the map isn't floating in void.
	local ground = makePart({
		CFrame = CFrame.new(0, -2, -30),
		Size = Vector3.new(320, 3, 400),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(26, 28, 34),
	})
	ground.Name = "Ground"
	ground.Parent = parent

	-- Perimeter walls: keeps the camera framed and the facility enclosed.
	for _, spec in ipairs({
		{ pos = Vector3.new(-158, 14, -30), size = Vector3.new(4, 32, 400) },
		{ pos = Vector3.new(158, 14, -30), size = Vector3.new(4, 32, 400) },
		{ pos = Vector3.new(0, 14, -228), size = Vector3.new(320, 32, 4) },
		{ pos = Vector3.new(0, 14, 168), size = Vector3.new(320, 32, 4) },
	}) do
		local wall = makePart({ CFrame = CFrame.new(spec.pos), Size = spec.size, Color = C.DarkMetal })
		wall.Parent = parent
	end

	-- Overhead cable runs, purely for silhouette.
	for _, z in ipairs({ -160, -110, -60, 10, 70 }) do
		pipe(parent, Vector3.new(-150, 26, z), Vector3.new(150, 26, z), 0.6, Color3.fromRGB(20, 22, 26))
	end
end

--============================================================
-- Waypoints + tower spots
--============================================================

local function buildWaypoints(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Waypoints"
	folder.Parent = parent

	local function addGroup(groupName: string, list: { any })
		local group = Instance.new("Folder")
		group.Name = groupName
		group.Parent = folder
		for _, waypoint in ipairs(list) do
			local marker = makePart({
				CFrame = CFrame.new(waypoint.Position + Vector3.new(0, 1, 0)),
				Size = Vector3.new(2, 2, 2),
				Transparency = 1,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
			})
			marker.Name = waypoint.Name
			marker.Parent = group
		end
	end

	addGroup("Main", MapData.MainPath)
	addGroup("Left", MapData.LeftPath)
	addGroup("Right", MapData.RightPath)
	addGroup("Hub", MapData.HubPath)

	return folder
end

local function buildTowerSpots(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "TowerSpots"
	folder.Parent = parent

	for index, spec in ipairs(MapData.TowerSpots) do
		local pad = makePart({
			CFrame = CFrame.new(spec.Position + Vector3.new(0, 0.5, 0)),
			Size = MapData.SpotSize,
			Material = Enum.Material.DiamondPlate,
			Color = C.Metal,
		})
		pad.Name = string.format("Spot_%02d", index)
		-- Attributes are what TowerManager and AdaptiveAI read; the side is
		-- authoritative here so a client can never claim a tower is elsewhere.
		pad:SetAttribute("SpotId", index)
		pad:SetAttribute("Side", spec.Side)
		pad:SetAttribute("Occupied", false)
		pad.Parent = folder

		CollectionService:AddTag(pad, "TowerSpot")

		local trim = neon(folder, pad.CFrame * CFrame.new(0, 0.55, 0), Vector3.new(MapData.SpotSize.X - 1, 0.12, MapData.SpotSize.Z - 1), C.EnergyBlue)
		trim.Transparency = 0.5
		trim.Name = pad.Name .. "_Trim"
	end

	return folder
end

--============================================================
-- Assembly
--============================================================

function MapBuilder.Build(): Model
	local existing = Workspace:FindFirstChild("MIND_TD_Map")
	if existing then
		return existing :: Model
	end

	local map = Instance.new("Model")
	map.Name = "MIND_TD_Map"
	map.Parent = Workspace

	local environment = Instance.new("Folder")
	environment.Name = "Environment"
	environment.Parent = map
	buildEnvironment(environment)

	local decorations = Instance.new("Folder")
	decorations.Name = "Decorations"
	decorations.Parent = map

	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = map

	-- Main road, then both branches, then the shared run to the Core. The
	-- branch roads are tinted differently so players can tell the two routes
	-- apart at a glance when the AI starts favouring one.
	buildPath(roads, MapData.MainPath, C.EnergyBlue)

	local leftRoute = { MapData.MainPath[#MapData.MainPath] }
	for _, waypoint in ipairs(MapData.LeftPath) do
		table.insert(leftRoute, waypoint)
	end
	table.insert(leftRoute, MapData.HubPath[1])
	buildPath(roads, leftRoute, C.EnergyCyan)

	local rightRoute = { MapData.MainPath[#MapData.MainPath] }
	for _, waypoint in ipairs(MapData.RightPath) do
		table.insert(rightRoute, waypoint)
	end
	table.insert(rightRoute, MapData.HubPath[1])
	buildPath(roads, rightRoute, C.WarningAmber)

	buildPath(roads, MapData.HubPath, C.EnergyBlue)

	buildSpawnGate(decorations)
	buildLeftSector(decorations)
	buildRightSector(decorations)
	buildCentralHub(decorations)

	local spawnMarker = makePart({
		CFrame = CFrame.new(MapData.MainPath[1].Position),
		Size = Vector3.new(4, 4, 4),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	spawnMarker.Name = "Spawn"
	spawnMarker.Parent = map

	buildWaypoints(map)
	buildTowerSpots(map)
	buildCore(map)

	return map
end

-- Sector signage is added after the Core exists so it can point at it.
function MapBuilder.AddSignage(map: Model)
	local decorations = map:FindFirstChild("Decorations")
	if not decorations then
		return
	end
	screen(decorations, CFrame.new(-96, 14, -20) * CFrame.Angles(0, math.rad(90), 0), "LEFT SECTOR\nLABORATORY", C.EnergyCyan, Vector3.new(16, 6, 0.4))
	screen(decorations, CFrame.new(96, 14, -20) * CFrame.Angles(0, math.rad(-90), 0), "RIGHT SECTOR\nPOWER PLANT", C.WarningAmber, Vector3.new(16, 6, 0.4))
end

return MapBuilder
