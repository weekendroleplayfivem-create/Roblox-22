--[[
	MapGenerator
	Procedurally assembles the NEON DISTRICT arena (brief sections 3, 30-32,
	42, 44). Hand-placing hundreds of parts isn't practical from code, so the
	map is built from small reusable Create* functions the way the brief
	explicitly allows, arranged into an intentional, symmetric layout rather
	than randomly scattered.
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local NEON_BLUE = Color3.fromRGB(60, 140, 255)
local NEON_PURPLE = Color3.fromRGB(170, 70, 255)
local DARK_METAL = Color3.fromRGB(38, 38, 44)
local DARK_METAL_2 = Color3.fromRGB(18, 18, 22)
local ROAD_COLOR = Color3.fromRGB(28, 28, 32)

local MapGenerator = {}

--============================================================
-- Low-level helpers
--============================================================

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = DARK_METAL
	for key, value in pairs(props) do
		p[key] = value
	end
	return p
end

local function neonStrip(cframe, size, color, parentModel)
	local p = part({ CFrame = cframe, Size = size, Material = Enum.Material.Neon, Color = color, CanCollide = false, CastShadow = false })
	p.Parent = parentModel
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 2.5
	light.Parent = p
	return p
end

local function billboardSign(cframe, text, color, parentModel, size)
	local base = part({ CFrame = cframe, Size = size or Vector3.new(0.3, 6, 10), Material = Enum.Material.Neon, Color = color, CanCollide = false, CastShadow = false })
	base.Parent = parentModel

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = base

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 24
	light.Brightness = 3
	light.Parent = base

	return base
end

local function hologram(cframe, text, color, parentModel)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = cframe
	anchor.Parent = parentModel

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 90)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextTransparency = 0.15
	label.TextStrokeTransparency = 0.6
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Parent = gui

	task.spawn(function()
		while anchor.Parent do
			TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				TextTransparency = 0.6,
			}):Play()
			task.wait(2.4)
		end
	end)

	return anchor
end

local function building(cframe, size, accentColor, parentModel)
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parentModel

	local block = part({ CFrame = cframe, Size = size, Material = Enum.Material.Concrete, Color = DARK_METAL })
	block.Parent = model
	model.PrimaryPart = block

	-- Vertical neon trim on each visible corner.
	for _, dx in ipairs({ -1, 1 }) do
		local trim = neonStrip(
			cframe * CFrame.new(dx * (size.X / 2 - 0.15), 0, size.Z / 2 + 0.05),
			Vector3.new(0.3, size.Y - 1, 0.3),
			accentColor,
			model
		)
		trim.CanCollide = false
	end

	-- Window band.
	for i = 1, math.max(1, math.floor(size.Y / 8)) do
		local band = part({
			CFrame = cframe * CFrame.new(0, -size.Y / 2 + i * 8, size.Z / 2 + 0.06),
			Size = Vector3.new(size.X - 2, 0.5, 0.1),
			Material = Enum.Material.Neon,
			Color = accentColor,
			CanCollide = false,
			CastShadow = false,
			Transparency = 0.2,
		})
		band.Parent = model
	end

	return model
end

local function ramp(cframe, size, color, parentModel)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	w.Color = DARK_METAL
	w.CFrame = cframe
	w.Size = size
	w.Parent = parentModel

	neonStrip(cframe * CFrame.new(0, size.Y / 2 - 0.1, 0), Vector3.new(size.X - 0.4, 0.15, size.Z - 0.4), color, parentModel).CanCollide = false
	return w
end

local function cover(cframe, size, parentModel)
	local p = part({ CFrame = cframe, Size = size, Material = Enum.Material.Metal, Color = DARK_METAL_2 })
	p.Parent = parentModel
	neonStrip(cframe * CFrame.new(0, size.Y / 2 - 0.1, size.Z / 2 + 0.05), Vector3.new(size.X - 0.4, 0.1, 0.05), NEON_BLUE, parentModel).CanCollide = false
	return p
end

local function garage(cframe, size, color, parentModel)
	local model = building(cframe, size, color, parentModel)
	model.Name = "Garage"

	local door = part({
		CFrame = cframe * CFrame.new(0, -size.Y / 2 + 6, size.Z / 2 - 0.3),
		Size = Vector3.new(size.X - 4, 12, 0.4),
		Material = Enum.Material.Metal,
		Color = DARK_METAL_2,
		CanCollide = true,
	})
	door.Name = "GarageDoor"
	door.Parent = model

	local openCFrame = door.CFrame * CFrame.new(0, 12, 0)
	local closedCFrame = door.CFrame
	local isOpen = false

	local trigger = part({
		CFrame = cframe * CFrame.new(0, -size.Y / 2 + 6, size.Z / 2 + 6),
		Size = Vector3.new(size.X, 12, 12),
		Transparency = 1,
		CanCollide = false,
	})
	trigger.Parent = model

	trigger.Touched:Connect(function()
		if isOpen then
			return
		end
		isOpen = true
		door.CanCollide = false
		TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = openCFrame }):Play()
		task.delay(4, function()
			if door.Parent then
				TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = closedCFrame }):Play()
				task.wait(0.6)
				door.CanCollide = true
				isOpen = false
			end
		end)
	end)

	return model
end

local function vent(cframe, parentModel)
	local p = part({ CFrame = cframe, Size = Vector3.new(2, 0.3, 2), Material = Enum.Material.DiamondPlate, Color = DARK_METAL_2, CanCollide = false })
	p.Parent = parentModel
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 160, 200))
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Rate = 4
	emitter.Speed = NumberRange.new(2, 4)
	emitter.Size = NumberSequence.new(0.6)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = p
end

local function cable(p0, p1, parentModel)
	local mid = p0:Lerp(p1, 0.5) - Vector3.new(0, 1.5, 0)
	local distance = (p1 - p0).Magnitude
	local cf = CFrame.new(p0, p1) * CFrame.new(0, 0, -distance / 2)
	local wire = part({
		CFrame = cf,
		Size = Vector3.new(0.15, 0.15, distance),
		Material = Enum.Material.Metal,
		Color = DARK_METAL_2,
		CanCollide = false,
		CastShadow = false,
	})
	wire.Parent = parentModel
	return wire
end

local function boostPad(cframe, size, parentModel)
	local pad = neonStrip(cframe, size, NEON_BLUE, parentModel)
	pad.Name = "BoostPad"
	pad.Color = NEON_PURPLE
	pad.CanCollide = false

	local debounce = {}
	pad.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model then
			return
		end
		local primary = model.PrimaryPart
		if not primary or debounce[model] then
			return
		end
		debounce[model] = true
		task.delay(0.5, function()
			debounce[model] = nil
		end)
		local look = primary.CFrame.LookVector
		primary.AssemblyLinearVelocity = Vector3.new(look.X, 0, look.Z).Unit * 110 + Vector3.new(0, primary.AssemblyLinearVelocity.Y, 0)
	end)
	return pad
end

local function jumpPad(cframe, size, parentModel)
	local pad = neonStrip(cframe, size, NEON_BLUE, parentModel)
	pad.Name = "JumpPad"
	pad.CanCollide = false

	local debounce = {}
	pad.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local rootModel = model
		local primary = rootModel and (rootModel.PrimaryPart or rootModel:FindFirstChild("HumanoidRootPart"))
		if not primary or debounce[rootModel] then
			return
		end
		debounce[rootModel] = true
		task.delay(0.5, function()
			debounce[rootModel] = nil
		end)
		primary.AssemblyLinearVelocity = Vector3.new(primary.AssemblyLinearVelocity.X, 65, primary.AssemblyLinearVelocity.Z)
	end)
	return pad
end

local function spawnZone(center, facing, color, teamName, mapModel)
	local zone = Instance.new("Model")
	zone.Name = teamName .. "Spawn"
	zone.Parent = mapModel

	local platform = part({
		CFrame = CFrame.new(center) * CFrame.Angles(0, facing, 0),
		Size = Vector3.new(46, 1, 36),
		Material = Enum.Material.Concrete,
		Color = DARK_METAL,
	})
	platform.Parent = zone

	neonStrip(platform.CFrame * CFrame.new(0, 0.55, 0), Vector3.new(44, 0.1, 34), color, zone).CanCollide = false

	-- Protective back wall + roof so spawns can't be spawn-killed from outside.
	local backWall = part({
		CFrame = platform.CFrame * CFrame.new(0, 8, -17),
		Size = Vector3.new(46, 16, 1),
		Material = Enum.Material.Metal,
		Color = DARK_METAL_2,
	})
	backWall.Parent = zone

	local roof = part({
		CFrame = platform.CFrame * CFrame.new(0, 16, -2),
		Size = Vector3.new(46, 1, 32),
		Material = Enum.Material.Metal,
		Color = DARK_METAL_2,
		Transparency = 0.3,
	})
	roof.Parent = zone

	building(platform.CFrame * CFrame.new(-18, 12, -12), Vector3.new(8, 24, 8), color, zone)
	building(platform.CFrame * CFrame.new(18, 12, -12), Vector3.new(8, 24, 8), color, zone)
	billboardSign(platform.CFrame * CFrame.new(0, 20, -16.5), teamName:upper() .. " SPAWN", color, zone)

	local spawnPointsFolder = Instance.new("Folder")
	spawnPointsFolder.Name = "SpawnPoints"
	spawnPointsFolder.Parent = zone

	-- Three staggered points so a full squad doesn't stack on one another,
	-- and three lanes open to the front of the platform (no exit is blocked).
	for _, offset in ipairs({ Vector3.new(-14, 2, 8), Vector3.new(0, 2, 8), Vector3.new(14, 2, 8) }) do
		local marker = Instance.new("Part")
		marker.Name = "SpawnPoint"
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Size = Vector3.new(4, 1, 4)
		marker.CFrame = platform.CFrame * CFrame.new(offset)
		marker.Parent = spawnPointsFolder
	end

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 40
	light.Brightness = 2
	local lightPart = Instance.new("Part")
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.Transparency = 1
	lightPart.Size = Vector3.new(1, 1, 1)
	lightPart.CFrame = platform.CFrame * CFrame.new(0, 10, 0)
	lightPart.Parent = zone
	light.Parent = lightPart

	return zone
end

local function dummy(cframe, parentModel)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"
	model.Parent = parentModel

	local torso = part({ CFrame = cframe, Size = Vector3.new(2, 3, 1), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(90, 90, 100), CanCollide = true })
	torso.Name = "HumanoidRootPart"
	torso.Parent = model
	model.PrimaryPart = torso

	local head = part({ CFrame = cframe * CFrame.new(0, 2.2, 0), Size = Vector3.new(1.4, 1.4, 1.4), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 120, 130), CanCollide = true })
	head.Name = "Head"
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = head
	weld.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model

	humanoid.Died:Connect(function()
		task.wait(3)
		humanoid.Health = humanoid.MaxHealth
		torso.Anchored = true
	end)

	return model
end

-- Exposed so DebugCommands can drop a single practice dummy on demand.
function MapGenerator.SpawnDummy(cframe)
	local map = Workspace:FindFirstChild("HyperBlastMap")
	local parentModel = map or Workspace
	return dummy(cframe, parentModel)
end

--============================================================
-- Top-level assembly
--============================================================

function MapGenerator.Build()
	if Workspace:FindFirstChild("HyperBlastMap") then
		return Workspace.HyperBlastMap
	end

	local map = Instance.new("Model")
	map.Name = "HyperBlastMap"
	map.Parent = Workspace

	-- Ground.
	local ground = part({
		CFrame = CFrame.new(0, -0.5, 0),
		Size = Vector3.new(300, 1, 320),
		Material = Enum.Material.Concrete,
		Color = ROAD_COLOR,
	})
	ground.Name = "Ground"
	ground.Parent = map

	-- Glowing road markings running the length of the district.
	for _, x in ipairs({ -1.5, 1.5 }) do
		neonStrip(CFrame.new(x, 0.05, 0), Vector3.new(0.4, 0.05, 300), NEON_BLUE, map).CanCollide = false
	end

	-- Spawns.
	local blueSpawn = spawnZone(Vector3.new(0, 0, -130), math.pi, NEON_BLUE, "Blue", map)
	local purpleSpawn = spawnZone(Vector3.new(0, 0, 130), 0, NEON_PURPLE, "Purple", map)

	-- Central Plaza / Central Combat Zone.
	local plaza = Instance.new("Model")
	plaza.Name = "CentralPlaza"
	plaza.Parent = map
	neonStrip(CFrame.new(0, 0.05, 0), Vector3.new(60, 0.05, 60), Color3.fromRGB(255, 255, 255), plaza).CanCollide = false
	for _, spec in ipairs({
		{ Vector3.new(-14, 4, -14), NEON_BLUE },
		{ Vector3.new(14, 4, -14), NEON_PURPLE },
		{ Vector3.new(-14, 4, 14), NEON_PURPLE },
		{ Vector3.new(14, 4, 14), NEON_BLUE },
	}) do
		cover(CFrame.new(spec[1]), Vector3.new(6, 8, 6), plaza)
	end
	hologram(CFrame.new(0, 22, 0), "HYPER BLAST", NEON_BLUE, plaza)
	billboardSign(CFrame.new(-30, 14, 0) * CFrame.Angles(0, math.rad(90), 0), "NEON DISTRICT", NEON_PURPLE, plaza)

	-- Rooftop area: buildings ringing the plaza with a connected rooftop deck.
	local rooftop = Instance.new("Model")
	rooftop.Name = "RooftopArea"
	rooftop.Parent = map
	local roofY = 26
	for _, x in ipairs({ -34, 34 }) do
		building(CFrame.new(x, roofY / 2, -34), Vector3.new(16, roofY, 16), NEON_BLUE, rooftop)
		building(CFrame.new(x, roofY / 2, 34), Vector3.new(16, roofY, 16), NEON_PURPLE, rooftop)
	end
	local deck = part({ CFrame = CFrame.new(0, roofY, 0), Size = Vector3.new(24, 1, 100), Material = Enum.Material.Metal, Color = DARK_METAL_2 })
	deck.Name = "RooftopDeck"
	deck.Parent = rooftop
	ramp(CFrame.new(-34, roofY / 2, -50) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1, roofY, 22), NEON_BLUE, rooftop)
	ramp(CFrame.new(34, roofY / 2, 50) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(1, roofY, 22), NEON_PURPLE, rooftop)

	-- Underpass: sunken tunnel linking the two spawns beneath the plaza.
	local underpass = Instance.new("Model")
	underpass.Name = "Underpass"
	underpass.Parent = map
	local tunnelY = -8
	local floor = part({ CFrame = CFrame.new(0, tunnelY, 0), Size = Vector3.new(14, 1, 220), Material = Enum.Material.Concrete, Color = ROAD_COLOR })
	floor.Parent = underpass
	local roofP = part({ CFrame = CFrame.new(0, tunnelY + 9, 0), Size = Vector3.new(14, 1, 220), Material = Enum.Material.Concrete, Color = DARK_METAL })
	roofP.Parent = underpass
	for _, x in ipairs({ -7, 7 }) do
		local wall = part({ CFrame = CFrame.new(x, tunnelY + 4.5, 0), Size = Vector3.new(0.5, 9, 220), Material = Enum.Material.Metal, Color = DARK_METAL_2 })
		wall.Parent = underpass
		neonStrip(CFrame.new(x * 0.96, tunnelY + 8.5, 0), Vector3.new(0.1, 0.2, 220), x < 0 and NEON_BLUE or NEON_PURPLE, underpass).CanCollide = false
	end
	ramp(CFrame.new(0, (tunnelY + 0) / 2, -100) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(12, 1, 20), NEON_BLUE, underpass)
	ramp(CFrame.new(0, (tunnelY + 0) / 2, 100) * CFrame.Angles(math.rad(14), 0, 0), Vector3.new(12, 1, 20), NEON_PURPLE, underpass)

	-- Neon Market: a row of stalls/buildings west of the plaza with holo ads.
	local market = Instance.new("Model")
	market.Name = "NeonMarket"
	market.Parent = map
	for i = -2, 2 do
		local stallCFrame = CFrame.new(-70, 5, i * 18)
		building(stallCFrame, Vector3.new(10, 10, 10), i % 2 == 0 and NEON_BLUE or NEON_PURPLE, market)
		hologram(stallCFrame * CFrame.new(0, 9, 6), "SALE\n" .. tostring(math.abs(i) * 10 + 10) .. "%", i % 2 == 0 and NEON_BLUE or NEON_PURPLE, market)
	end
	cable(Vector3.new(-70, 12, -36), Vector3.new(-70, 12, 36), market)

	-- Garage: east of the plaza, with a proximity-activated door.
	local garageModel = garage(CFrame.new(70, 9, 0), Vector3.new(30, 18, 30), NEON_PURPLE, map)
	for _, x in ipairs({ -10, 10 }) do
		vent(CFrame.new(70 + x, 0.2, 14), garageModel)
	end

	-- Alleyways: tight flanking corridors connecting market/garage to plaza.
	local alleys = Instance.new("Model")
	alleys.Name = "Alleyways"
	alleys.Parent = map
	for _, side in ipairs({ -1, 1 }) do
		local alleyWall1 = part({ CFrame = CFrame.new(side * 40, 4, 0), Size = Vector3.new(1, 8, 140), Material = Enum.Material.Metal, Color = DARK_METAL })
		alleyWall1.Parent = alleys
		neonStrip(CFrame.new(side * 39.4, 7, 0), Vector3.new(0.1, 0.15, 140), side < 0 and NEON_BLUE or NEON_PURPLE, alleys).CanCollide = false
		for z = -50, 50, 25 do
			cover(CFrame.new(side * 34, 2, z), Vector3.new(4, 4, 4), alleys)
		end
	end

	-- Boost ramps + jump areas leading into the central combat zone.
	local boostZones = Instance.new("Folder")
	boostZones.Name = "BoostZones"
	boostZones.Parent = map
	boostPad(CFrame.new(0, 0.1, -60), Vector3.new(10, 0.1, 10), boostZones)
	boostPad(CFrame.new(0, 0.1, 60), Vector3.new(10, 0.1, 10), boostZones)
	boostPad(CFrame.new(-50, 0.1, 0), Vector3.new(10, 0.1, 10), boostZones)
	boostPad(CFrame.new(50, 0.1, 0), Vector3.new(10, 0.1, 10), boostZones)

	local jumpZones = Instance.new("Folder")
	jumpZones.Name = "JumpZones"
	jumpZones.Parent = map
	jumpPad(CFrame.new(-20, 0.1, -20), Vector3.new(8, 0.1, 8), jumpZones)
	jumpPad(CFrame.new(20, 0.1, 20), Vector3.new(8, 0.1, 8), jumpZones)

	-- Ramps up to the rooftop deck from the plaza corners.
	ramp(CFrame.new(-24, 6, -24) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(10, 12, 16), NEON_BLUE, map)
	ramp(CFrame.new(24, 6, 24) * CFrame.Angles(0, math.rad(-135), 0), Vector3.new(10, 12, 16), NEON_PURPLE, map)

	-- Distant decorative "trains" gliding along the skyline (pure set dressing).
	local skyline = Instance.new("Model")
	skyline.Name = "Skyline"
	skyline.Parent = map
	for _, spec in ipairs({ { z = -160, dir = 1, y = 40 }, { z = 160, dir = -1, y = 55 } }) do
		local train = part({
			CFrame = CFrame.new(-140, spec.y, spec.z),
			Size = Vector3.new(6, 6, 30),
			Material = Enum.Material.Metal,
			Color = DARK_METAL_2,
			CanCollide = false,
		})
		train.Parent = skyline
		neonStrip(train.CFrame * CFrame.new(0, -2.5, 0), Vector3.new(6, 0.2, 30), spec.dir == 1 and NEON_BLUE or NEON_PURPLE, skyline).CanCollide = false
		task.spawn(function()
			while train.Parent do
				local goal = train.Position + Vector3.new(280 * spec.dir, 0, 0)
				local tween = TweenService:Create(train, TweenInfo.new(18, Enum.EasingStyle.Linear), { Position = goal })
				tween:Play()
				tween.Completed:Wait()
				train.Position = Vector3.new(-140 * spec.dir, spec.y, spec.z)
			end
		end)
	end

	-- Central combat zone cover / central combat marker.
	cover(CFrame.new(0, 3, -6), Vector3.new(10, 6, 3), map)
	cover(CFrame.new(0, 3, 6), Vector3.new(10, 6, 3), map)

	-- Training / test area, tucked off to the side away from the main lanes.
	MapGenerator.BuildTrainingArea(map)

	return map
end

function MapGenerator.BuildTrainingArea(map)
	local training = Instance.new("Model")
	training.Name = "TrainingArea"
	training.Parent = map

	local origin = Vector3.new(-160, 0, -160)
	local floor = part({
		CFrame = CFrame.new(origin) + Vector3.new(0, -0.5, 0),
		Size = Vector3.new(80, 1, 100),
		Material = Enum.Material.Concrete,
		Color = DARK_METAL,
	})
	floor.Parent = training
	neonStrip(floor.CFrame * CFrame.new(0, 0.55, 0), Vector3.new(78, 0.1, 98), NEON_BLUE, training).CanCollide = false
	billboardSign(CFrame.new(origin) * CFrame.new(0, 12, -49), "TRAINING GROUNDS", NEON_BLUE, training)

	-- Shooting range dummies.
	for i = -2, 2 do
		dummy(CFrame.new(origin) * CFrame.new(i * 10, 3.5, -35), training)
	end

	-- Scooter test track: a loop with a drift corner, a jump section, and a boost tunnel.
	ramp(CFrame.new(origin) * CFrame.new(-30, 3, 10) * CFrame.Angles(math.rad(-12), 0, 0), Vector3.new(10, 1, 16), NEON_PURPLE, training)
	jumpPad(CFrame.new(origin) * CFrame.new(-30, 0.1, 25), Vector3.new(8, 0.1, 8), training)
	boostPad(CFrame.new(origin) * CFrame.new(10, 0.1, 30), Vector3.new(10, 0.1, 10), training)
	for _, offset in ipairs({ Vector3.new(20, 3, 0), Vector3.new(30, 3, 8), Vector3.new(30, 3, -8) }) do
		cover(CFrame.new(origin) * CFrame.new(offset), Vector3.new(4, 6, 4), training)
	end

	return training
end

return MapGenerator
