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

function MapBuilder:GetPartCount(): number
	return self._partCount
end

return MapBuilder
