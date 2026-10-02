--[[
	MapBuilder
	Builds PLACEHOLDER arena geometry from code. Each map module in this folder
	calls the helpers below to place blocks, ramps, jump pads, spawns and bot
	navigation nodes.

	Coordinates passed to helpers are LOCAL to the map origin (y = 0 is the
	main floor surface). `Mirrored(fn)` runs a builder function twice, the
	second time rotated 180 degrees around the map centre. This gives every
	team-mode map perfect point symmetry, and spawn sides "A"/"B" swap
	automatically in the mirrored pass.

	To replace placeholder geometry with hand-built models: build the model in
	Studio, keep Spawn/JumpPad/BotNode conventions (see README), and return it
	from the map module instead of calling these helpers.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaycastUtil = require(ReplicatedStorage:WaitForChild("Shared").Modules.RaycastUtil)

local MapBuilder = {}
MapBuilder.__index = MapBuilder

local MIRROR = CFrame.Angles(0, math.pi, 0)

export type SpawnPoint = { CFrame: CFrame, Side: string? }

function MapBuilder.new(parent: Instance, name: string, origin: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	local self = setmetatable({
		Folder = folder,
		Origin = origin,
		OriginCFrame = CFrame.new(origin),
		Spawns = {} :: { SpawnPoint },
		BotNodes = {} :: { Vector3 },
		JumpPads = {} :: { BasePart },
		_transform = CFrame.identity,
		_mirrored = false,
		_partCount = 0,
	}, MapBuilder)
	return self
end

function MapBuilder:_world(localCFrame: CFrame): CFrame
	return self.OriginCFrame * self._transform * localCFrame
end

function MapBuilder:_worldPoint(localPosition: Vector3): Vector3
	return self:_world(CFrame.new(localPosition)).Position
end

local function basePart(className: string): BasePart
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	return part
end

-- Solid, collidable geometry. Returns the part.
function MapBuilder:Block(size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, name: string?): BasePart
	return self:BlockCFrame(size, CFrame.new(position), color, material, name)
end

function MapBuilder:BlockCFrame(size: Vector3, localCFrame: CFrame, color: Color3, material: Enum.Material?, name: string?): BasePart
	local part = basePart("Part")
	part.Name = name or "Block"
	part.Size = size
	part.CFrame = self:_world(localCFrame)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = self.Folder
	self._partCount += 1
	return part
end

function MapBuilder:Cylinder(diameter: number, height: number, position: Vector3, color: Color3, material: Enum.Material?): BasePart
	local part = basePart("Part")
	part.Name = "Cylinder"
	part.Shape = Enum.PartType.Cylinder
	-- Cylinders extend along their X axis; rotate so it stands upright.
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = self:_world(CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2))
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = self.Folder
	self._partCount += 1
	return part
end

-- Decorative glowing strip. Never blocks movement or shots.
function MapBuilder:Neon(size: Vector3, position: Vector3, color: Color3): BasePart
	local part = self:Block(size, position, color, Enum.Material.Neon, "Neon")
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Invisible wall that keeps players inside the arena.
function MapBuilder:Barrier(size: Vector3, position: Vector3): BasePart
	local part = self:Block(size, position, Color3.new(1, 1, 1), Enum.Material.ForceField, "Barrier")
	part.Transparency = 1
	part.CanQuery = false
	part.CastShadow = false
	return part
end

-- Walkable slope from local point `from` up to local point `to` (both on the
-- walking surface). Built as a tilted slab, so it has no orientation pitfalls.
function MapBuilder:Ramp(from: Vector3, to: Vector3, width: number, color: Color3, material: Enum.Material?): BasePart
	local length = (to - from).Magnitude + 1
	local middle = (from + to) / 2
	local slab = CFrame.lookAt(middle, to) * CFrame.new(0, -0.5, 0)
	local part = self:BlockCFrame(Vector3.new(width, 1, length), slab, color, material, "Ramp")
	return part
end

-- Wall segments arranged in a ring (used for circular routes).
-- `skip` lists segment indices left open as doorways.
function MapBuilder:Ring(radius: number, segments: number, thickness: number, height: number, y: number, color: Color3, skip: { number }?, material: Enum.Material?)
	local segmentLength = 2 * radius * math.tan(math.pi / segments) + thickness * 0.5
	for index = 1, segments do
		if not (skip and table.find(skip, index)) then
			local angle = (index - 0.5) / segments * math.pi * 2
			local position = Vector3.new(math.cos(angle) * radius, y + height / 2, math.sin(angle) * radius)
			local look = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
			self:BlockCFrame(Vector3.new(segmentLength, height, thickness), look, color, material, "RingWall")
		end
	end
end

-- Flat ring walkway (catwalk) made of planks.
function MapBuilder:RingFloor(radius: number, segments: number, width: number, y: number, color: Color3, material: Enum.Material?)
	local segmentLength = 2 * (radius + width / 2) * math.tan(math.pi / segments) + 0.5
	for index = 1, segments do
		local angle = (index - 0.5) / segments * math.pi * 2
		local position = Vector3.new(math.cos(angle) * radius, y - 0.5, math.sin(angle) * radius)
		local look = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		self:BlockCFrame(Vector3.new(segmentLength, 1, width), look, color, material, "Catwalk")
	end
end

function MapBuilder:Light(position: Vector3, color: Color3, range: number?, brightness: number?)
	local holder = basePart("Part")
	holder.Name = "LightHolder"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = self:_world(CFrame.new(position))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 24
	light.Brightness = brightness or 2
	light.Shadows = false
	light.Parent = holder
	holder.Parent = self.Folder
	return holder
end

-- Launch pad. `velocity` is local (rotated with the map) in studs/second.
function MapBuilder:JumpPad(position: Vector3, velocity: Vector3, color: Color3): BasePart
	local pad = self:Block(Vector3.new(6, 0.6, 6), position + Vector3.new(0, 0.3, 0), color, Enum.Material.Neon, "JumpPad")
	pad.CanCollide = true
	local worldVelocity = (self.OriginCFrame * self._transform):VectorToWorldSpace(velocity)
	pad:SetAttribute("LaunchVelocity", worldVelocity)
	CollectionService:AddTag(pad, RaycastUtil.Tags.JumpPad)
	table.insert(self.JumpPads, pad)
	-- Arrow glow so players can read the launch direction.
	local ring = self:Neon(Vector3.new(7, 0.2, 7), position + Vector3.new(0, 0.05, 0), color)
	ring.Transparency = 0.5
	return pad
end

-- Spawn point. Side "A" / "B" are team sides (swapped in mirrored pass); nil = neutral.
function MapBuilder:Spawn(position: Vector3, side: string?, lookAt: Vector3?)
	local resolvedSide = side
	if side and self._mirrored then
		resolvedSide = if side == "A" then "B" else "A"
	end
	local target = lookAt or Vector3.new(0, position.Y, 0)
	if (target - position).Magnitude < 0.1 then
		target = position + Vector3.new(0, 0, 1)
	end
	local localCFrame = CFrame.lookAt(position + Vector3.new(0, 3, 0), Vector3.new(target.X, position.Y + 3, target.Z))
	table.insert(self.Spawns, { CFrame = self:_world(localCFrame), Side = resolvedSide })
	table.insert(self.BotNodes, self:_worldPoint(position + Vector3.new(0, 3, 0)))
	-- Small floor marker (visual only).
	local marker = self:Neon(Vector3.new(4, 0.1, 4), position + Vector3.new(0, 0.06, 0), Color3.fromRGB(255, 255, 255))
	marker.Transparency = 0.85
end

function MapBuilder:BotNode(position: Vector3)
	table.insert(self.BotNodes, self:_worldPoint(position + Vector3.new(0, 3, 0)))
end

-- Runs `build` normally and then rotated 180 degrees about the map centre.
function MapBuilder:Mirrored(build: (any) -> ())
	build(self)
	self._transform = MIRROR
	self._mirrored = true
	build(self)
	self._transform = CFrame.identity
	self._mirrored = false
end

-- Floating billboard text (e.g. map name signs).
function MapBuilder:Sign(text: string, size: Vector3, position: Vector3, color: Color3, facing: Vector3?)
	local localCFrame = CFrame.lookAt(position, facing or Vector3.new(0, position.Y, 0))
	local board = self:BlockCFrame(size, localCFrame, Color3.fromRGB(15, 15, 30), Enum.Material.SmoothPlastic, "Sign")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = board
	return board
end

--[[ Decoration helpers (non-gameplay detail; never blocks shots) ]]

local PARTICLE_TEXTURES = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- Decorative part: no collision, not hit by raycasts.
function MapBuilder:Deco(size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, name: string?): BasePart
	local part = self:Block(size, position, color, material or Enum.Material.Neon, name or "Deco")
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

function MapBuilder:DecoCFrame(size: Vector3, localCFrame: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	local part = self:BlockCFrame(size, localCFrame, color, material or Enum.Material.Neon, "Deco")
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Client-side animation tags (see StarterPlayerScripts/Controllers/Effects/MapAnimator).
-- Spin axis is in world space (map-local axis converted), around the part's centre.
function MapBuilder:Spin(part: BasePart, axis: Vector3, degreesPerSecond: number)
	part:SetAttribute("SpinAxis", (self.OriginCFrame * self._transform):VectorToWorldSpace(axis))
	part:SetAttribute("SpinSpeed", degreesPerSecond)
	CollectionService:AddTag(part, RaycastUtil.Tags.Spin)
	return part
end

function MapBuilder:Bob(part: BasePart, height: number, cyclesPerSecond: number)
	part:SetAttribute("BobHeight", height)
	part:SetAttribute("BobSpeed", cyclesPerSecond)
	CollectionService:AddTag(part, RaycastUtil.Tags.Bob)
	return part
end

function MapBuilder:Pulse(part: BasePart, cyclesPerSecond: number, minTransparency: number, maxTransparency: number)
	part:SetAttribute("PulseSpeed", cyclesPerSecond)
	part:SetAttribute("PulseMin", minTransparency)
	part:SetAttribute("PulseMax", maxTransparency)
	CollectionService:AddTag(part, RaycastUtil.Tags.Pulse)
	return part
end

function MapBuilder:Flicker(part: BasePart)
	CollectionService:AddTag(part, RaycastUtil.Tags.Flicker)
	return part
end

--[[
	Ambient particles on a part. Presets: "Sparkle", "Steam", "Dust", "Embers", "Cloud", "Wind"
]]
function MapBuilder:Particles(part: BasePart, preset: string, color: Color3?, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = preset
	emitter.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
	emitter.Texture = PARTICLE_TEXTURES.Sparkle
	emitter.LightEmission = 1
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	if preset == "Steam" then
		emitter.Texture = PARTICLE_TEXTURES.Smoke
		emitter.LightEmission = 0.2
		emitter.Size = NumberSequence.new(1, 4)
		emitter.Transparency = NumberSequence.new(0.5, 1)
		emitter.Speed = NumberRange.new(6, 10)
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.Rate = rate or 8
	elseif preset == "Dust" then
		emitter.Size = NumberSequence.new(0.15, 0)
		emitter.Transparency = NumberSequence.new(0.3, 1)
		emitter.Speed = NumberRange.new(0.2, 0.8)
		emitter.Lifetime = NumberRange.new(4, 7)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = rate or 6
	elseif preset == "Embers" then
		emitter.Size = NumberSequence.new(0.25, 0)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.Lifetime = NumberRange.new(1.5, 3)
		emitter.Acceleration = Vector3.new(0, 2, 0)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Rate = rate or 10
	elseif preset == "Cloud" then
		emitter.Texture = PARTICLE_TEXTURES.Smoke
		emitter.LightEmission = 0.1
		emitter.Size = NumberSequence.new(14, 22)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Lifetime = NumberRange.new(8, 12)
		emitter.SpreadAngle = Vector2.new(180, 10)
		emitter.Rate = rate or 2
	elseif preset == "Wind" then
		emitter.Size = NumberSequence.new(0.08, 0)
		emitter.Transparency = NumberSequence.new(0.4, 1)
		emitter.Speed = NumberRange.new(30, 50)
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.SpreadAngle = Vector2.new(5, 5)
		emitter.EmissionDirection = Enum.NormalId.Right
		emitter.Rate = rate or 12
	else -- Sparkle
		emitter.Size = NumberSequence.new(0.3, 0)
		emitter.Speed = NumberRange.new(0.5, 2)
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = rate or 8
	end
	emitter.Parent = part
	return emitter
end

-- Floating hologram billboard: flickers, bobs gently, readable from both sides.
function MapBuilder:Hologram(text: string, size: Vector3, position: Vector3, color: Color3, facing: Vector3?)
	local localCFrame = CFrame.lookAt(position, facing or Vector3.new(0, position.Y, 0))
	local panel = self:DecoCFrame(size, localCFrame, color, Enum.Material.Glass)
	panel.Transparency = 0.15
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeColor3 = color
		label.TextStrokeTransparency = 0
		label.Parent = gui
		gui.Parent = panel
	end
	local frame = self:DecoCFrame(size + Vector3.new(0.4, 0.4, -size.Z + 0.1), localCFrame, color, Enum.Material.Neon)
	frame.Transparency = 0.6
	self:Flicker(panel)
	self:Bob(panel, 0.3, 0.25)
	self:Bob(frame, 0.3, 0.25)
	return panel
end

-- Street lamp: thin collidable pole + glowing head + light.
function MapBuilder:Lamp(position: Vector3, height: number, color: Color3)
	self:Block(Vector3.new(0.5, height, 0.5), position + Vector3.new(0, height / 2, 0), Color3.fromRGB(40, 40, 55), Enum.Material.Metal, "LampPole")
	self:Block(Vector3.new(2.2, 0.4, 0.8), position + Vector3.new(0.8, height, 0), Color3.fromRGB(40, 40, 55), Enum.Material.Metal, "LampArm")
	local head = self:Deco(Vector3.new(1.6, 0.25, 0.6), position + Vector3.new(1.2, height - 0.3, 0), color)
	self:Pulse(head, 0.15, 0, 0.25)
	self:Light(position + Vector3.new(1.2, height - 1.5, 0), color, 22, 1.4)
end

-- Supply crate with glowing edge stripes. Collidable cover.
function MapBuilder:Crate(position: Vector3, size: Vector3, color: Color3, accent: Color3)
	self:Block(size, position + Vector3.new(0, size.Y / 2, 0), color, Enum.Material.Metal, "Crate")
	self:Deco(Vector3.new(size.X + 0.05, 0.15, size.Z + 0.05), position + Vector3.new(0, size.Y * 0.75, 0), accent)
	self:Deco(Vector3.new(size.X + 0.05, 0.15, size.Z + 0.05), position + Vector3.new(0, size.Y * 0.25, 0), accent)
end

-- Stylised neon tree in a planter (planter + trunk collide, canopy doesn't).
function MapBuilder:Tree(position: Vector3, canopyColor: Color3, height: number?)
	local treeHeight = height or 7
	self:Block(Vector3.new(4, 1.4, 4), position + Vector3.new(0, 0.7, 0), Color3.fromRGB(55, 55, 80), Enum.Material.SmoothPlastic, "Planter")
	self:Deco(Vector3.new(4.1, 0.2, 4.1), position + Vector3.new(0, 1.35, 0), canopyColor)
	self:Block(Vector3.new(0.6, treeHeight, 0.6), position + Vector3.new(0, treeHeight / 2 + 1.4, 0), Color3.fromRGB(70, 55, 60), Enum.Material.Wood, "Trunk")
	local canopy = self:DecoCFrame(Vector3.one * 4.5, CFrame.new(position + Vector3.new(0, treeHeight + 2, 0)), canopyColor, Enum.Material.Neon, Enum.PartType.Ball)
	canopy.Transparency = 0.15
	self:Pulse(canopy, 0.2, 0.05, 0.3)
	local inner = self:DecoCFrame(Vector3.one * 3, CFrame.new(position + Vector3.new(0.8, treeHeight + 1, 0.5)), canopyColor:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon, Enum.PartType.Ball)
	inner.Transparency = 0.3
	self:Particles(canopy, "Sparkle", canopyColor, 3)
end

-- Low collidable railing between two local points.
function MapBuilder:Railing(from: Vector3, to: Vector3, color: Color3, height: number?)
	local railHeight = height or 1.6
	local middle = (from + to) / 2 + Vector3.new(0, railHeight, 0)
	local length = (to - from).Magnitude
	self:BlockCFrame(Vector3.new(0.3, 0.3, length), CFrame.lookAt(middle, to + Vector3.new(0, railHeight, 0)), Color3.fromRGB(60, 65, 85), Enum.Material.Metal, "Railing")
	self:DecoCFrame(Vector3.new(0.12, 0.12, length), CFrame.lookAt(middle + Vector3.new(0, 0.2, 0), to + Vector3.new(0, railHeight + 0.2, 0)), color)
	local posts = math.max(2, math.floor(length / 6))
	for index = 0, posts do
		local point = from:Lerp(to, index / posts)
		self:Block(Vector3.new(0.25, railHeight, 0.25), point + Vector3.new(0, railHeight / 2, 0), Color3.fromRGB(60, 65, 85), Enum.Material.Metal, "RailPost")
	end
end

-- Decorative pipe between two local points.
function MapBuilder:Pipe(from: Vector3, to: Vector3, diameter: number, color: Color3, glow: Color3?)
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt(middle, to) * CFrame.Angles(0, math.rad(90), 0)
	self:DecoCFrame(Vector3.new(length, diameter, diameter), cframe, color, Enum.Material.Metal, Enum.PartType.Cylinder)
	if glow then
		local band = self:DecoCFrame(Vector3.new(length + 0.05, diameter * 0.4, diameter * 1.05), cframe, glow, Enum.Material.Neon, Enum.PartType.Cylinder)
		self:Pulse(band, 0.5, 0, 0.6)
	end
end

-- Floor vent puffing steam.
function MapBuilder:Vent(position: Vector3, color: Color3)
	self:Block(Vector3.new(3, 0.3, 3), position + Vector3.new(0, 0.15, 0), Color3.fromRGB(30, 32, 40), Enum.Material.DiamondPlate, "Vent")
	local glow = self:Deco(Vector3.new(2.4, 0.1, 2.4), position + Vector3.new(0, 0.32, 0), color)
	self:Pulse(glow, 0.6, 0.1, 0.7)
	self:Particles(glow, "Steam", Color3.fromRGB(220, 230, 255), 6)
end

-- Blocky staircase from a low local point up to a high one.
function MapBuilder:Stairs(from: Vector3, to: Vector3, width: number, steps: number, color: Color3, accent: Color3?)
	local rise = (to.Y - from.Y) / steps
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local run = flat / steps
	local direction = flat.Unit
	for index = 1, steps do
		local height = rise * index
		local center = from + run * (index - 0.5) + Vector3.new(0, height / 2, 0)
		local size = Vector3.new(width, height, run.Magnitude + 0.05)
		self:BlockCFrame(size, CFrame.lookAt(center, center + direction), color, Enum.Material.SmoothPlastic, "Step")
		if accent then
			local edgeCenter = from + run * (index - 0.5) + Vector3.new(0, height + 0.02, 0) - direction * (run.Magnitude / 2 - 0.1)
			self:DecoCFrame(Vector3.new(width, 0.05, 0.15), CFrame.lookAt(edgeCenter, edgeCenter + direction), accent)
		end
	end
end

-- Wall console with a glowing text screen.
function MapBuilder:Console(text: string, position: Vector3, facing: Vector3, color: Color3)
	local cframe = CFrame.lookAt(position, Vector3.new(facing.X, position.Y, facing.Z))
	self:BlockCFrame(Vector3.new(4, 3, 1), cframe, Color3.fromRGB(35, 38, 50), Enum.Material.Metal, "Console")
	local screen = self:DecoCFrame(Vector3.new(3.4, 2.2, 0.1), cframe * CFrame.new(0, 0.1, -0.52), Color3.fromRGB(10, 20, 30), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = screen
	self:Flicker(screen)
end

-- Little hovering drone (decoration).
function MapBuilder:Drone(position: Vector3, color: Color3)
	local body = self:DecoCFrame(Vector3.new(1.6, 0.6, 1.6), CFrame.new(position), Color3.fromRGB(50, 55, 75), Enum.Material.Metal)
	local eye = self:DecoCFrame(Vector3.one * 0.6, CFrame.new(position + Vector3.new(0, -0.3, 0)), color, Enum.Material.Neon, Enum.PartType.Ball)
	local ring = self:DecoCFrame(Vector3.new(0.1, 3, 3), CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.5
	local speed = 0.3 + math.random() * 0.3
	for _, part in { body, eye, ring } do
		self:Bob(part, 1.2, speed)
	end
	self:Spin(body, Vector3.yAxis, 40)
end

-- Spinning neon ring (hologram halo).
function MapBuilder:HaloRing(position: Vector3, diameter: number, color: Color3, speed: number, tilt: number?)
	local ring = self:DecoCFrame(
		Vector3.new(0.3, diameter, diameter),
		-- Tilted so spinning around the vertical axis makes it visibly wobble.
		CFrame.new(position) * CFrame.Angles(math.rad(tilt or 18), 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.Material.ForceField,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0
	self:Spin(ring, Vector3.yAxis, speed)
	return ring
end

function MapBuilder:GetPartCount(): number
	return self._partCount
end

return MapBuilder
