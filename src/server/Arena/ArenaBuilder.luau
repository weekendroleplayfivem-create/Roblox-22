--!nonstrict
--[[
	ArenaBuilder.luau
	Builds a HYPER BLAST arena from ArenaConfig at runtime.

	Why procedural instead of a saved place file: the arena's shape IS balance
	data. Keeping it in a config table means a sightline can be shortened, a
	jump pad moved, or a flank route added in a diff that a reviewer can read -
	instead of in a binary blob nobody can review.

	Everything the movement system can touch is TAGGED, not name-matched, so
	hand-built geometry dropped into the same arena behaves identically.
--]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Palette = require(Root.Config.Palette)
local ArenaConfig = require(Root.Config.ArenaConfig)
local Tags = require(Root.Shared.Tags)

local ArenaBuilder = {}

local function part(props): BasePart
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.Material = Enum.Material.SmoothPlastic
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Size = Vector3.one
	for key, value in props do
		if key ~= "Parent" and key ~= "Tags" then
			(instance :: any)[key] = value
		end
	end
	if props.Tags then
		for _, tag in props.Tags do
			CollectionService:AddTag(instance, tag)
		end
	end
	instance.Parent = props.Parent
	return instance
end

--[[ A thin neon strip. Used everywhere for readability: every ledge you can
	 stand on, every wall you can jump off, and every route boundary gets one,
	 so the arena teaches its own movement rules without a tutorial. ]]
local function trim(cframe: CFrame, size: Vector3, color: Color3, parent: Instance, tags)
	local strip = part({
		Name = "Trim",
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = parent,
		Tags = tags,
	})
	CollectionService:AddTag(strip, Tags.NoShoot) -- decoration never eats a bullet
	return strip
end

----------------------------------------------------------------------
-- Sections
----------------------------------------------------------------------

local function buildFloorAndWalls(config, parent: Instance)
	local size = config.Size

	part({
		Name = "Floor",
		Size = Vector3.new(size.X, 4, size.Z),
		CFrame = CFrame.new(0, config.FloorY - 2, 0),
		Color = Palette.Environment.FloorBase,
		Parent = parent,
		Tags = { Tags.MinimapGeometry },
	})

	-- A subtle grid of inlaid neon lines. Beyond looking right, the grid gives
	-- the eye a speed reference: you can feel how fast you're moving over it.
	local step = 40
	for offset = -size.X / 2 + step, size.X / 2 - step, step do
		trim(
			CFrame.new(offset, config.FloorY + 0.05, 0),
			Vector3.new(0.35, 0.1, size.Z - 8),
			Palette.NeonPurple,
			parent
		)
		trim(
			CFrame.new(0, config.FloorY + 0.05, offset),
			Vector3.new(size.X - 8, 0.1, 0.35),
			Palette.NeonBlue,
			parent
		)
	end

	local halfX, halfZ = size.X / 2, size.Z / 2
	local walls = {
		{ cframe = CFrame.new(0, config.WallHeight / 2, -halfZ), size = Vector3.new(size.X, config.WallHeight, 6) },
		{ cframe = CFrame.new(0, config.WallHeight / 2, halfZ), size = Vector3.new(size.X, config.WallHeight, 6) },
		{ cframe = CFrame.new(-halfX, config.WallHeight / 2, 0), size = Vector3.new(6, config.WallHeight, size.Z) },
		{ cframe = CFrame.new(halfX, config.WallHeight / 2, 0), size = Vector3.new(6, config.WallHeight, size.Z) },
	}

	for index, wall in walls do
		part({
			Name = `Boundary{index}`,
			Size = wall.size,
			CFrame = wall.cframe,
			Color = Palette.Environment.Wall,
			Parent = parent,
		})
		trim(
			wall.cframe * CFrame.new(0, -config.WallHeight / 2 + 1.5, 0),
			Vector3.new(
				wall.size.X > wall.size.Z and wall.size.X or 0.4,
				0.4,
				wall.size.Z > wall.size.X and wall.size.Z or 0.4
			),
			Palette.NeonPurple,
			parent
		)
	end

	-- Out-of-bounds volume well below the floor, in case anything escapes.
	part({
		Name = "KillPlane",
		Size = Vector3.new(size.X * 3, 4, size.Z * 3),
		CFrame = CFrame.new(0, config.FloorY - 90, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
		Tags = { Tags.KillPlane },
	})
end

--[[ The spire: contested high ground with FOUR readable ways up (ramps) and
	 four movement-only ways up (wall-jump faces). Every strong position in this
	 arena follows that rule - see ArenaConfig's design notes. ]]
local function buildSpire(config, parent: Instance)
	local spire = config.Spire
	if not spire then
		return
	end

	local base = part({
		Name = "SpireBase",
		Size = spire.BaseSize,
		CFrame = CFrame.new(spire.Position + Vector3.new(0, spire.BaseSize.Y / 2, 0)),
		Color = Palette.Environment.Platform,
		Parent = parent,
		Tags = { Tags.MinimapGeometry },
	})

	local top = part({
		Name = "SpireTop",
		Size = spire.TopSize,
		CFrame = CFrame.new(spire.Position + Vector3.new(0, spire.TopY, 0)),
		Color = Palette.Environment.Platform,
		Parent = parent,
		Tags = { Tags.MinimapGeometry },
	})

	trim(
		top.CFrame * CFrame.new(0, top.Size.Y / 2 + 0.1, 0),
		Vector3.new(spire.TopSize.X, 0.2, spire.TopSize.Z),
		Palette.NeonPurple,
		parent
	)

	-- Ramps: the readable route. Slide-friendly, so the "slow" way up is still
	-- fast if you carry momentum into it.
	local rampLength = 46
	for index = 1, spire.RampCount do
		local angle = (index - 1) * (math.pi * 2 / spire.RampCount)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local rise = spire.TopY - spire.BaseSize.Y * 0.5
		local ramp = part({
			Name = `SpireRamp{index}`,
			Size = Vector3.new(16, 1.5, rampLength),
			CFrame = CFrame.new(spire.Position + direction * (spire.BaseSize.X * 0.5 + rampLength * 0.42))
				* CFrame.Angles(0, -angle + math.pi / 2, 0)
				* CFrame.Angles(math.rad(math.deg(math.atan2(rise, rampLength))), 0, 0)
				+ Vector3.new(0, rise * 0.5, 0),
			Color = Palette.Environment.Platform,
			Parent = parent,
			Tags = { Tags.SlideBoost, Tags.MinimapGeometry },
		})
		trim(
			ramp.CFrame * CFrame.new(8, 1, 0),
			Vector3.new(0.3, 0.3, rampLength),
			Palette.NeonCyan,
			parent
		)
		trim(
			ramp.CFrame * CFrame.new(-8, 1, 0),
			Vector3.new(0.3, 0.3, rampLength),
			Palette.NeonCyan,
			parent
		)
	end

	-- Wall-jump faces on the base: the movement-only route up. Cyan trim marks
	-- them, and the tag is what the movement system actually reads.
	for index = 1, spire.WallJumpFaces do
		local angle = (index - 1) * (math.pi * 2 / spire.WallJumpFaces) + math.pi / spire.WallJumpFaces
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local face = part({
			Name = `SpireWallJump{index}`,
			Size = Vector3.new(18, spire.TopY - 2, 1.2),
			CFrame = CFrame.lookAt(
				spire.Position + direction * (spire.BaseSize.X * 0.5 + 0.6) + Vector3.new(0, (spire.TopY - 2) / 2, 0),
				spire.Position + Vector3.new(0, (spire.TopY - 2) / 2, 0)
			),
			Color = Palette.Environment.WallTrim,
			Parent = parent,
			Tags = { Tags.WallJump },
		})
		trim(face.CFrame * CFrame.new(0, 0, -0.8), Vector3.new(16, 0.35, 0.2), Palette.NeonCyan, parent)
		trim(face.CFrame * CFrame.new(0, 6, -0.8), Vector3.new(16, 0.35, 0.2), Palette.NeonCyan, parent)
		trim(face.CFrame * CFrame.new(0, -6, -0.8), Vector3.new(16, 0.35, 0.2), Palette.NeonCyan, parent)
	end

	local _ = base
end

local function buildTowers(config, parent: Instance)
	for index, tower in config.Towers or {} do
		local position = Vector3.new(tower.offset.X, tower.height / 2, tower.offset.Y)
		part({
			Name = `Tower{index}`,
			Size = Vector3.new(tower.size.X, tower.height, tower.size.Z),
			CFrame = CFrame.new(position),
			Color = Palette.Environment.Wall,
			Parent = parent,
			Tags = { Tags.MinimapGeometry },
		})

		-- Rooftop lip: cover on top so a rooftop isn't a free kill from below.
		local roofY = tower.height
		for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			part({
				Name = "TowerLip",
				Size = Vector3.new(
					side.X ~= 0 and 2 or tower.size.X,
					4,
					side.Z ~= 0 and 2 or tower.size.Z
				),
				CFrame = CFrame.new(
					Vector3.new(tower.offset.X, roofY + 2, tower.offset.Y)
						+ side * (tower.size.X / 2 - 1)
				),
				Color = Palette.Environment.Cover,
				Parent = parent,
			})
		end

		-- Two wall-jump faces per tower: a mobile player can always contest a
		-- rooftop without walking the long way round.
		for _, side in { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) } do
			local face = part({
				Name = "TowerWallJump",
				Size = Vector3.new(
					side.X ~= 0 and 1.2 or tower.size.X * 0.7,
					tower.height - 6,
					side.Z ~= 0 and 1.2 or tower.size.Z * 0.7
				),
				CFrame = CFrame.new(
					Vector3.new(tower.offset.X, (tower.height - 6) / 2, tower.offset.Y)
						+ side * (tower.size.X / 2 + 0.6)
				),
				Color = Palette.Environment.WallTrim,
				Parent = parent,
				Tags = { Tags.WallJump },
			})
			trim(
				face.CFrame * CFrame.new(0, 0, 0) + side * 0.8,
				Vector3.new(
					side.X ~= 0 and 0.2 or tower.size.X * 0.6,
					0.35,
					side.Z ~= 0 and 0.2 or tower.size.Z * 0.6
				),
				Palette.NeonCyan,
				parent
			)
		end
	end
end

local function buildPlatforms(config, parent: Instance)
	for index, platform in config.Platforms or {} do
		local instance = part({
			Name = `Platform{index}`,
			Size = platform.size,
			CFrame = CFrame.new(platform.position),
			Color = Palette.Environment.Platform,
			Parent = parent,
			Tags = { Tags.MinimapGeometry },
		})
		trim(
			instance.CFrame * CFrame.new(0, platform.size.Y / 2 + 0.1, 0),
			Vector3.new(platform.size.X, 0.15, platform.size.Z),
			Palette.NeonBlue,
			parent
		)
	end
end

--[[ Slide tunnels. A low ceiling means only a sliding player fits, which turns
	 them into a pure movement-skill shortcut: fast, but you arrive unable to
	 shoot for a beat. ]]
local function buildSlideTunnels(config, parent: Instance)
	for index, tunnel in config.SlideTunnels or {} do
		local from, to = tunnel.from, tunnel.to
		local delta = to - from
		local length = delta.Magnitude
		local center = from:Lerp(to, 0.5)
		local lookCFrame = CFrame.lookAt(center, center + delta.Unit)

		part({
			Name = `SlideTunnelFloor{index}`,
			Size = Vector3.new(tunnel.width, 1, length),
			CFrame = lookCFrame * CFrame.new(0, 0.5, 0),
			Color = Palette.Environment.FloorAccent,
			Parent = parent,
			Tags = { Tags.SlideBoost, Tags.MinimapGeometry },
		})

		part({
			Name = `SlideTunnelCeiling{index}`,
			Size = Vector3.new(tunnel.width + 4, 2, length),
			CFrame = lookCFrame * CFrame.new(0, tunnel.ceiling + 1, 0),
			Color = Palette.Environment.Wall,
			Parent = parent,
			Tags = { Tags.NoMantle }, -- never let a player vault onto the tunnel roof mid-run
		})

		for _, side in { -1, 1 } do
			part({
				Name = `SlideTunnelWall{index}`,
				Size = Vector3.new(1.5, tunnel.ceiling + 2, length),
				CFrame = lookCFrame * CFrame.new(side * (tunnel.width / 2 + 0.75), (tunnel.ceiling + 2) / 2, 0),
				Color = Palette.Environment.Wall,
				Parent = parent,
			})
			trim(
				lookCFrame * CFrame.new(side * (tunnel.width / 2 - 0.2), 0.6, 0),
				Vector3.new(0.25, 0.25, length),
				Palette.NeonCyan,
				parent
			)
		end
	end
end

local function buildJumpPads(config, parent: Instance)
	for index, pad in config.JumpPads or {} do
		local instance = part({
			Name = `JumpPad{index}`,
			Size = Vector3.new(12, 1, 12),
			CFrame = CFrame.new(pad.position),
			Color = Palette.NeonPurple,
			Material = Enum.Material.Neon,
			Parent = parent,
			Tags = { Tags.JumpPad, Tags.MinimapGeometry },
		})
		instance:SetAttribute("Power", pad.power)
		instance:SetAttribute("ForwardKeep", pad.forwardKeep)

		-- A vertical light column so pads are visible from across the arena. You
		-- should be able to plan a route the moment you see one.
		trim(
			CFrame.new(pad.position + Vector3.new(0, 14, 0)),
			Vector3.new(1.2, 28, 1.2),
			Palette.NeonPurple,
			parent
		)
	end
end

local function buildWallRoutes(config, parent: Instance)
	for index, route in config.WallRoutes or {} do
		local panel = part({
			Name = `WallRoute{index}`,
			Size = route.size,
			CFrame = CFrame.new(route.position) * CFrame.Angles(0, math.rad(route.rotation or 0), 0),
			Color = Palette.Environment.WallTrim,
			Parent = parent,
			Tags = { Tags.WallJump, Tags.MinimapGeometry },
		})

		-- Chevron trim pointing up the route: readable direction of travel.
		local thin = route.size.X < route.size.Z
		for step = 1, 4 do
			trim(
				panel.CFrame * CFrame.new(0, -route.size.Y / 2 + step * (route.size.Y / 5), thin and 0.8 or 0),
				thin and Vector3.new(0.2, 0.4, route.size.Z * 0.7)
					or Vector3.new(route.size.X * 0.7, 0.4, 0.2),
				Palette.NeonCyan,
				parent
			)
		end
	end
end

--[[ Cover. Low blocks are mantleable (they're a movement option, not just a
	 wall), high blocks break sightlines. Jittered so the arena never reads as a
	 grid, excluded from the spire approach so ramps stay clean. ]]
local function buildCover(config, parent: Instance)
	local grid = config.CoverGrid
	if not grid then
		return
	end

	local random = Random.new(20260902) -- fixed seed: the arena is identical every match
	local half = (grid.Rows - 1) / 2

	for row = -half, half do
		for column = -half, half do
			local base = Vector3.new(column * grid.Spacing, 0, row * grid.Spacing)
			local jitter = Vector3.new(
				random:NextNumber(-grid.Jitter, grid.Jitter),
				0,
				random:NextNumber(-grid.Jitter, grid.Jitter)
			)
			local position = base + jitter

			if position.Magnitude > grid.ExclusionRadius then
				local low = random:NextNumber() < grid.LowChance
				local size = low and grid.LowSize or grid.HighSize
				local block = part({
					Name = low and "CoverLow" or "CoverHigh",
					Size = size,
					CFrame = CFrame.new(position + Vector3.new(0, size.Y / 2, 0))
						* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0),
					Color = Palette.Environment.Cover,
					Parent = parent,
					Tags = { Tags.MinimapGeometry },
				})
				trim(
					block.CFrame * CFrame.new(0, size.Y / 2 + 0.08, 0),
					Vector3.new(size.X, 0.12, size.Z),
					low and Palette.NeonCyan or Palette.NeonMagenta,
					parent
				)

				-- High cover doubles as a wall-jump surface, so a chase can go
				-- vertical anywhere on the open floor.
				if not low then
					CollectionService:AddTag(block, Tags.WallJump)
				end
			end
		end
	end
end

local function buildSpawns(config, parent: Instance)
	local spawns = {}
	for teamKey, spawn in config.Spawns do
		local teamData = Palette.Teams[teamKey]
		local pad = part({
			Name = `Spawn_{teamKey}`,
			Size = Vector3.new(spawn.spread + 20, 1, 22),
			CFrame = CFrame.new(spawn.center - Vector3.new(0, 1.5, 0)),
			Color = teamData.Color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = parent,
			Tags = { Tags.TeamSpawn },
		})
		pad:SetAttribute("Team", teamKey)
		spawns[teamKey] = spawn
	end
	return spawns
end

local function buildObjectives(config, parent: Instance)
	local zones = {}
	for _, zone in config.ControlZones or {} do
		local marker = part({
			Name = `Zone_{zone.id}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.5, zone.radius * 2, zone.radius * 2),
			CFrame = CFrame.new(zone.position) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Palette.State.Objective,
			Material = Enum.Material.Neon,
			Transparency = 0.65,
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
			Tags = { Tags.ControlZone },
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("Radius", zone.radius)
		table.insert(zones, { id = zone.id, position = zone.position, radius = zone.radius, marker = marker })
	end

	local coreSpawn = part({
		Name = "CoreSpawn",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(config.CoreSpawn),
		Color = Palette.NeonPurple,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
		Tags = { Tags.CoreSpawn },
	})

	local objectives = {}
	for teamKey, position in config.CoreObjectives or {} do
		local pad = part({
			Name = `CoreObjective_{teamKey}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.5, 18, 18),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Palette.Teams[teamKey].Color,
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
			Tags = { Tags.CoreObjective },
		})
		pad:SetAttribute("Team", teamKey)
		objectives[teamKey] = { position = position, marker = pad }
	end

	return zones, coreSpawn, objectives
end

local function applyLighting(config)
	local settings = config.Lighting or {}

	Lighting.Ambient = Color3.fromRGB(16, 14, 30)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 16, 38)
	Lighting.Brightness = 1.1
	Lighting.ClockTime = 0
	Lighting.FogColor = Palette.Environment.Fog
	Lighting.FogStart = settings.FogStart or 90
	Lighting.FogEnd = settings.FogEnd or 480

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Haze = 1.4
	atmosphere.Glare = 0.15
	atmosphere.Color = Color3.fromRGB(60, 50, 100)
	atmosphere.Decay = Color3.fromRGB(80, 60, 140)
	atmosphere.Parent = Lighting
end

----------------------------------------------------------------------
-- Entry point
----------------------------------------------------------------------

function ArenaBuilder.build(arenaId: string)
	local config = ArenaConfig.get(arenaId)

	local existing = workspace:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Arena"

	buildFloorAndWalls(config, model)
	buildSpire(config, model)
	buildTowers(config, model)
	buildPlatforms(config, model)
	buildSlideTunnels(config, model)
	buildWallRoutes(config, model)
	buildJumpPads(config, model)
	buildCover(config, model)

	local spawns = buildSpawns(config, model)
	local zones, coreSpawn, objectives = buildObjectives(config, model)

	model.Parent = workspace
	applyLighting(config)

	return {
		id = config.Id,
		config = config,
		model = model,
		spawns = spawns,
		zones = zones,
		coreSpawn = coreSpawn,
		coreObjectives = objectives,
	}
end

return ArenaBuilder
