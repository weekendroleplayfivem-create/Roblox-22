--[[
	WeaponFX
	All weapon visuals. Each weapon picks a TracerStyle in WeaponConfig:
	  Bolt   - glowing slug that streaks to the target + faint trail line
	  Spray  - thinner, faster bolts (rapid fire)
	  Pellet - many short streaks with end sparks (scatter)
	  Rail   - thick energy line that collapses, with rings along its path
	  Arc    - flickering jagged lightning
	  Beam   - continuous beam while the trigger is held (BeamSession)
	  Orb    - plasma projectile with a glowing particle wake
	Plus muzzle flashes, impacts (ring + sparks + glowing mark), enemy hit
	flashes, and stylised explosions. No blood, no gore.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectPool = require(Shared.Modules.ObjectPool)

local FXUtil = require(script.Parent.FXUtil)

local WeaponFX = {}

local BOLT_SPEED = 900 -- studs/second for travelling bolts
local MAX_MARKS = 40
local HIT_FLASH_POOL = 4

local linePool
local marks: { BasePart } = {}

--[[ Glow beams (Beam instances between Terrain attachments) ]]

type GlowBeam = { Beam: Beam, A: Attachment, B: Attachment, Born: number, Duration: number, Width: number, Busy: boolean }
local beamPool: { GlowBeam } = {}
local activeBeams: { GlowBeam } = {}
local MAX_BEAMS = 90

local function acquireBeam(): GlowBeam?
	for _, entry in beamPool do
		if not entry.Busy then
			return entry
		end
	end
	if #beamPool >= MAX_BEAMS then
		return nil
	end
	local terrain = workspace.Terrain
	local a = Instance.new("Attachment")
	a.Name = "VR_BeamA"
	a.Parent = terrain
	local b = Instance.new("Attachment")
	b.Name = "VR_BeamB"
	b.Parent = terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = a
	beam.Attachment1 = b
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 12
	beam.Texture = FXUtil.Textures.Sparkle
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.TextureSpeed = 2
	beam.Enabled = false
	beam.Parent = terrain
	local entry = { Beam = beam, A = a, B = b, Born = 0, Duration = 0, Width = 0, Busy = false }
	table.insert(beamPool, entry)
	return entry
end

-- Soft glowing beam from `from` to `to` that fades and thins over `duration`.
function WeaponFX.GlowBeam(from: Vector3, to: Vector3, color: Color3, width: number, duration: number, curve: number?)
	local entry = acquireBeam()
	if not entry then
		return
	end
	entry.Busy = true
	entry.A.WorldPosition = from
	entry.B.WorldPosition = to
	local beam = entry.Beam
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	beam.Width0 = width
	beam.Width1 = width * 0.7
	beam.CurveSize0 = curve or 0
	beam.CurveSize1 = -(curve or 0)
	beam.Transparency = NumberSequence.new(0)
	beam.Enabled = true
	entry.Born = os.clock()
	entry.Duration = duration
	entry.Width = width
	table.insert(activeBeams, entry)
end

local function stepBeams()
	local now = os.clock()
	for index = #activeBeams, 1, -1 do
		local entry = activeBeams[index]
		local alpha = (now - entry.Born) / entry.Duration
		if alpha >= 1 then
			entry.Beam.Enabled = false
			entry.Busy = false
			table.remove(activeBeams, index)
		else
			entry.Beam.Transparency = NumberSequence.new(alpha * alpha)
			local width = entry.Width * (1 - alpha * 0.8)
			entry.Beam.Width0 = width
			entry.Beam.Width1 = width * 0.7
		end
	end
end

--[[ Physical debris: small client-only parts that bounce and fade ]]

local MAX_DEBRIS = 40
local debrisCount = 0

function WeaponFX.Debris(position: Vector3, normal: Vector3, color: Color3, count: number, speed: number?, glow: boolean?)
	if FXUtil.Reduced() then
		return
	end
	for _ = 1, count do
		if debrisCount >= MAX_DEBRIS then
			return
		end
		debrisCount += 1
		local chip = Instance.new("Part")
		chip.Name = "Chip"
		chip.Size = Vector3.one * (0.1 + math.random() * 0.15)
		chip.Color = color
		chip.Material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		chip.CanQuery = false
		chip.CanTouch = false
		chip.CastShadow = false
		chip.CollisionGroup = "Default"
		chip.CFrame = CFrame.new(position + normal * 0.2) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		chip.AssemblyLinearVelocity = (normal + spread * 1.2).Unit * (speed or 18) * (0.5 + math.random())
		chip.AssemblyAngularVelocity = spread * 30
		chip.Parent = FXUtil.Folder()
		FXUtil.Tween(chip, 1.1, { Transparency = 1, Size = chip.Size * 0.4 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(1.15, function()
			debrisCount -= 1
			chip:Destroy()
		end)
	end
end

-- Spent energy casing flicked out of the ejection port.
function WeaponFX.Casing(eject: CFrame, color: Color3, big: boolean?)
	if FXUtil.Reduced() or debrisCount >= MAX_DEBRIS then
		return
	end
	debrisCount += 1
	local casing = Instance.new("Part")
	casing.Name = "Casing"
	casing.Size = if big then Vector3.new(0.12, 0.12, 0.3) else Vector3.new(0.06, 0.06, 0.16)
	casing.Color = Color3.fromRGB(200, 170, 90)
	casing.Material = Enum.Material.Metal
	casing.CanQuery = false
	casing.CanTouch = false
	casing.CastShadow = false
	casing.CFrame = eject
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Size = casing.Size * Vector3.new(1.1, 1.1, 0.3)
	band.Color = color
	band.Material = Enum.Material.Neon
	band.CanCollide = false
	band.CanQuery = false
	band.CanTouch = false
	band.Massless = true
	band.CFrame = eject
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = casing
	weld.Part1 = band
	weld.Parent = band
	band.Parent = casing
	local camera = workspace.CurrentCamera
	local up = if camera then camera.CFrame.UpVector else Vector3.yAxis
	casing.AssemblyLinearVelocity = eject.LookVector * (8 + math.random() * 4) + up * (6 + math.random() * 3)
	casing.AssemblyAngularVelocity = Vector3.new(math.random() * 20, math.random() * 20, math.random() * 20)
	casing.Parent = FXUtil.Folder()
	task.delay(1.4, function()
		debrisCount -= 1
		casing:Destroy()
	end)
end

-- Cyan shards when a shield breaks.
function WeaponFX.ShieldShatter(position: Vector3)
	local color = Color3.fromRGB(120, 230, 255)
	FXUtil.Sphere(position, color, 1, 5, 0.25, 0.3)
	FXUtil.Emit(position, { Color = color, Count = 20, Speed = NumberRange.new(10, 22), Lifetime = NumberRange.new(0.3, 0.6), Acceleration = Vector3.new(0, -40, 0), Size = 0.3, Essential = true })
	if not FXUtil.Reduced() then
		for _ = 1, 8 do
			local shard = Instance.new("WedgePart")
			shard.Size = Vector3.new(0.05, 0.4 + math.random() * 0.3, 0.3)
			shard.Color = color
			shard.Material = Enum.Material.Glass
			shard.Transparency = 0.3
			shard.Anchored = true
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CastShadow = false
			shard.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			local offset = Vector3.new(math.random() - 0.5, math.random() - 0.2, math.random() - 0.5).Unit * (3 + math.random() * 3)
			FXUtil.Flash(shard, 0.5, { CFrame = CFrame.new(position + offset) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Transparency = 1 })
		end
	end
end
local hitHighlights: { Highlight } = {}
local hitHighlightIndex = 0

local function line(from: Vector3, to: Vector3, color: Color3, width: number, transparency: number)
	local length = (to - from).Magnitude
	local part = linePool:Get()
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Color = color
	part.Transparency = transparency
	return part
end

local function fadeLine(part: BasePart, duration: number, endWidth: number?)
	local size = part.Size
	FXUtil.Tween(part, duration, {
		Transparency = 1,
		Size = Vector3.new(endWidth or size.X, endWidth or size.Y, size.Z),
	})
	linePool:ReturnAfter(part, duration + 0.02)
end

-- Glowing slug travelling from `from` to `to`.
local function travellingBolt(from: Vector3, to: Vector3, color: Color3, width: number, length: number)
	local distance = (to - from).Magnitude
	if distance < 1 then
		return
	end
	local direction = (to - from).Unit
	local boltLength = math.min(length, distance)
	local slug = linePool:Get()
	slug.Shape = Enum.PartType.Block
	slug.Size = Vector3.new(width, width, boltLength)
	slug.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
	slug.Transparency = 0
	local startCFrame = CFrame.lookAt(from + direction * boltLength / 2, to)
	slug.CFrame = startCFrame
	local duration = math.clamp(distance / BOLT_SPEED, 0.03, 0.35)
	FXUtil.Tween(slug, duration, { CFrame = CFrame.lookAt(to - direction * boltLength / 2, to + direction) }, Enum.EasingStyle.Linear)
	linePool:ReturnAfter(slug, duration + 0.01)
end

function WeaponFX.Tracer(style: string, from: Vector3, to: Vector3, color: Color3, intensity: number?)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local power = intensity or 1
	if not FXUtil.Reduced() then
		local glowWidth = if style == "Rail" then 0.6 + 0.6 * power
			elseif style == "Beam" then 0.5
			elseif style == "Pellet" or style == "Spray" then 0.12
			else 0.22
		local glowTime = if style == "Rail" then 0.4 elseif style == "Pellet" or style == "Spray" then 0.08 else 0.14
		WeaponFX.GlowBeam(from, to, color, glowWidth, glowTime)
	end
	if style == "Rail" then
		local width = 0.12 + 0.22 * power
		fadeLine(line(from, to, color, width, 0.05), 0.35, 0.01)
		fadeLine(line(from, to, Color3.new(1, 1, 1), width * 0.35, 0), 0.18, 0.01)
		if not FXUtil.Reduced() then
			local direction = (to - from).Unit
			local count = math.clamp(math.floor(distance / 25), 2, 6)
			for index = 1, count do
				local point = from + direction * (distance * index / (count + 1))
				FXUtil.Ring(point, direction, color, 0.3, 1.2 + power, 0.3, 0.05)
			end
		end
	elseif style == "Pellet" then
		fadeLine(line(from, to, color, 0.05, 0.4), 0.07)
		travellingBolt(from, to, color, 0.07, 1.5)
	elseif style == "Spray" then
		fadeLine(line(from, to, color, 0.04, 0.6), 0.05)
		travellingBolt(from, to, color, 0.08, 2.5)
	elseif style == "Arc" then
		WeaponFX.Lightning(from, to, color)
	elseif style == "Beam" then
		fadeLine(line(from, to, color, 0.18, 0.1), 0.08)
	else -- Bolt
		fadeLine(line(from, to, color, 0.05, 0.55), 0.07)
		travellingBolt(from, to, color, 0.13, 4)
	end
end

-- Jagged arc that flickers a few times.
function WeaponFX.Lightning(from: Vector3, to: Vector3, color: Color3)
	if not FXUtil.Reduced() then
		local distance = (to - from).Magnitude
		for strand = 1, 3 do
			task.delay((strand - 1) * 0.03, function()
				WeaponFX.GlowBeam(from, to, color, 0.18 + strand * 0.05, 0.12, (math.random() - 0.5) * distance * 0.25)
			end)
		end
		FXUtil.Emit(to, { Color = color, Count = 6, Speed = NumberRange.new(8, 18), Lifetime = NumberRange.new(0.1, 0.25), Size = 0.2 })
	end
	local flickers = if FXUtil.Reduced() then 1 else 3
	for flicker = 0, flickers - 1 do
		task.delay(flicker * 0.035, function()
			local segments = 5
			local previous = from
			for index = 1, segments do
				local point = from:Lerp(to, index / segments)
				if index < segments then
					point += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6
				end
				fadeLine(line(previous, point, if flicker == 0 then Color3.new(1, 1, 1) else color, 0.12, 0), 0.06)
				previous = point
			end
		end)
	end
end

function WeaponFX.MuzzleFlash(cframe: CFrame, color: Color3, scale: number?, style: string?)
	local size = scale or 1
	local position = cframe.Position
	if style == "Rail" then
		FXUtil.Ring(position, cframe.LookVector, color, 0.3, 2.2 * size, 0.18, 0.06)
		FXUtil.Ring(position + cframe.LookVector * 0.6, cframe.LookVector, Color3.new(1, 1, 1), 0.2, 1.4 * size, 0.14, 0.04)
	elseif style == "Pellet" then
		FXUtil.Emit(position, { Color = color, Count = 10, Direction = cframe.LookVector, Spread = Vector2.new(30, 30), Speed = NumberRange.new(20, 40), Lifetime = NumberRange.new(0.06, 0.14), Size = 0.25 })
	elseif style == "Arc" then
		for _ = 1, 3 do
			local tip = position + (cframe.LookVector + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.8).Unit * 1.2
			WeaponFX.GlowBeam(position, tip, color, 0.08, 0.06, (math.random() - 0.5) * 0.6)
		end
	end
	if style == "Rail" or style == "Pellet" or style == "Orb" then
		-- Lingering smoke wisp from heavy shots.
		FXUtil.Emit(position, {
			Color = Color3.fromRGB(200, 200, 215),
			Texture = FXUtil.Textures.Smoke,
			Count = 2,
			Direction = Vector3.yAxis,
			Spread = Vector2.new(20, 20),
			Speed = NumberRange.new(1, 2.5),
			Lifetime = NumberRange.new(0.6, 1),
			Size = NumberSequence.new(0.3, 1.2),
			LightEmission = 0,
			Transparency = NumberSequence.new(0.6, 1),
		})
	end
	FXUtil.Sphere(position, color:Lerp(Color3.new(1, 1, 1), 0.4), 0.35 * size, 0.9 * size, 0.06, 0)
	-- Star "petals" facing forward.
	for index = 0, 1 do
		local petal = FXUtil.Part("Petal")
		petal.Color = color
		petal.Transparency = 0.1
		petal.Size = Vector3.new(0.05, 0.9 * size, 0.05)
		petal.CFrame = cframe * CFrame.Angles(0, 0, math.rad(45 + index * 90))
		FXUtil.Flash(petal, 0.05, { Transparency = 1, Size = Vector3.new(0.02, 1.4 * size, 0.02) })
	end
	FXUtil.Light(position, color, 12 * size, 5, 0.08)
	FXUtil.Emit(position, {
		Color = color,
		Count = 4,
		Direction = cframe.LookVector,
		Spread = Vector2.new(25, 25),
		Speed = NumberRange.new(14, 28),
		Lifetime = NumberRange.new(0.08, 0.18),
		Size = 0.18,
	})
end

-- Glowing mark left on surfaces (pooled, oldest reused).
local function surfaceMark(position: Vector3, normal: Vector3, color: Color3)
	if FXUtil.Reduced() then
		return
	end
	local mark
	if #marks >= MAX_MARKS then
		mark = table.remove(marks, 1)
	else
		mark = FXUtil.Part("Mark", Enum.PartType.Cylinder)
		mark.Parent = FXUtil.Folder()
	end
	table.insert(marks, mark)
	mark.Size = Vector3.new(0.03, 0.35, 0.35)
	mark.Color = color
	mark.Transparency = 0.2
	mark.CFrame = CFrame.lookAt(position + normal * 0.03, position + normal) * CFrame.Angles(0, math.rad(90), 0)
	FXUtil.Tween(mark, 1.6, { Transparency = 1, Color = Color3.new(0.2, 0.2, 0.25) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

function WeaponFX.Impact(position: Vector3, normal: Vector3, color: Color3, heavy: boolean?, surfaceColor: Color3?)
	FXUtil.Ring(position + normal * 0.05, normal, color, 0.3, if heavy then 3 else 1.6, 0.2)
	FXUtil.Light(position + normal * 0.5, color, if heavy then 10 else 6, 2, 0.08)
	if surfaceColor then
		WeaponFX.Debris(position, normal, surfaceColor, if heavy then 4 else 2, 14)
	end
	FXUtil.Emit(position, {
		Color = surfaceColor or Color3.fromRGB(180, 180, 200),
		Texture = FXUtil.Textures.Smoke,
		Count = if heavy then 3 else 1,
		Direction = normal,
		Spread = Vector2.new(25, 25),
		Speed = NumberRange.new(2, 5),
		Lifetime = NumberRange.new(0.3, 0.6),
		Size = NumberSequence.new(0.4, 1.4),
		LightEmission = 0,
		Transparency = NumberSequence.new(0.5, 1),
		Drag = 4,
	})
	FXUtil.Emit(position, {
		Color = color,
		Count = if heavy then 14 else 6,
		Direction = normal,
		Spread = Vector2.new(60, 60),
		Speed = NumberRange.new(8, 20),
		Lifetime = NumberRange.new(0.15, 0.35),
		Acceleration = Vector3.new(0, -40, 0),
		Size = 0.22,
	})
	surfaceMark(position, normal, color)
end

-- Sparkle where a shot connects with a player (stylised, no gore).
function WeaponFX.HitSpark(position: Vector3, color: Color3, shield: boolean?)
	local burstColor = if shield then Color3.fromRGB(120, 230, 255) else color:Lerp(Color3.new(1, 1, 1), 0.5)
	FXUtil.Sphere(position, burstColor, 0.3, 1.5, 0.14, 0)
	FXUtil.Emit(position, {
		Color = burstColor,
		Count = 8,
		Speed = NumberRange.new(10, 22),
		Lifetime = NumberRange.new(0.15, 0.3),
		Size = 0.25,
	})
end

-- Brief full-body flash on a character you hit (white = health, cyan = shield).
function WeaponFX.HitFlash(model: Model, shield: boolean?)
	hitHighlightIndex = hitHighlightIndex % HIT_FLASH_POOL + 1
	local highlight = hitHighlights[hitHighlightIndex]
	highlight.Adornee = model
	highlight.FillColor = if shield then Color3.fromRGB(110, 220, 255) else Color3.new(1, 1, 1)
	highlight.OutlineColor = highlight.FillColor
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0.2
	highlight.Enabled = true
	FXUtil.Tween(highlight, 0.14, { FillTransparency = 1, OutlineTransparency = 1 })
end

-- Big colourful explosion (plasma impacts).
function WeaponFX.Explosion(position: Vector3, color: Color3, radius: number)
	-- Distortion-like shockwave shell.
	local shell = FXUtil.Part("Shockwave", Enum.PartType.Ball)
	shell.Material = Enum.Material.ForceField
	shell.Color = color
	shell.Size = Vector3.one * 2
	shell.CFrame = CFrame.new(position)
	FXUtil.Flash(shell, 0.4, { Size = Vector3.one * radius * 3, Transparency = 1 })
	-- Scorch ring that lingers on the ground.
	local scorch = FXUtil.Ring(position - Vector3.new(0, 0.5, 0), Vector3.yAxis, Color3.fromRGB(30, 25, 35), radius * 0.8, radius * 1.4, 2.5, 0.06)
	scorch.Transparency = 0.3
	WeaponFX.Debris(position, Vector3.yAxis, color, 8, 30, true)
	FXUtil.Emit(position, {
		Color = Color3.fromRGB(90, 80, 110),
		Texture = FXUtil.Textures.Smoke,
		Count = 6,
		Direction = Vector3.yAxis,
		Spread = Vector2.new(30, 30),
		Speed = NumberRange.new(6, 12),
		Lifetime = NumberRange.new(1.2, 1.8),
		Size = NumberSequence.new(3, 7),
		LightEmission = 0,
		Transparency = NumberSequence.new(0.5, 1),
		Drag = 2,
	})
	FXUtil.Sphere(position, Color3.new(1, 1, 1), 1, radius * 0.9, 0.18, 0)
	FXUtil.Sphere(position, color, 1.5, radius * 2, 0.45, 0.25)
	FXUtil.Ring(position, Vector3.yAxis, color, 1, radius * 2.6, 0.45, 0.3)
	FXUtil.Light(position, color, radius * 3, 8, 0.4)
	FXUtil.Emit(position, {
		Color = color,
		Count = 26,
		Speed = NumberRange.new(20, 45),
		Lifetime = NumberRange.new(0.3, 0.6),
		Acceleration = Vector3.new(0, -30, 0),
		Size = 0.4,
		Essential = true,
	})
	FXUtil.Emit(position, {
		Color = color:Lerp(Color3.new(1, 1, 1), 0.5),
		Texture = FXUtil.Textures.Smoke,
		Count = 8,
		Speed = NumberRange.new(4, 10),
		Lifetime = NumberRange.new(0.6, 1.1),
		Size = NumberSequence.new(2, 5),
		LightEmission = 0.3,
		Transparency = NumberSequence.new(0.4, 1),
		Drag = 3,
	})
	-- Pixel debris.
	if not FXUtil.Reduced() then
		for _ = 1, 6 do
			local cube = FXUtil.Part("Pixel")
			cube.Color = color
			cube.Size = Vector3.one * 0.5
			cube.CFrame = CFrame.new(position)
			local offset = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * radius * 1.1
			FXUtil.Flash(cube, 0.5, { CFrame = CFrame.new(position + offset) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Size = Vector3.one * 0.1, Transparency = 1 })
		end
	end
end

--[[ Continuous beam while firing a Beam weapon ]]

local BeamSession = {}
BeamSession.__index = BeamSession

function WeaponFX.StartBeam(color: Color3)
	local self = setmetatable({}, BeamSession)
	self.Outer = FXUtil.Part("BeamOuter")
	self.Outer.Color = color
	self.Outer.Transparency = 0.35
	self.Outer.Parent = FXUtil.Folder()
	self.Core = FXUtil.Part("BeamCore")
	self.Core.Color = Color3.new(1, 1, 1)
	self.Core.Transparency = 0
	self.Core.Parent = FXUtil.Folder()
	self.Glow = FXUtil.Part("BeamGlow", Enum.PartType.Ball)
	self.Glow.Color = color
	self.Glow.Transparency = 0.2
	self.Glow.Size = Vector3.one * 0.9
	self.Glow.Parent = FXUtil.Folder()
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 3
	light.Parent = self.Glow
	self.Color = color
	self.LastSpark = 0
	return self
end

function BeamSession:Update(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local pulse = 1 + math.sin(os.clock() * 40) * 0.15
	local cframe = CFrame.lookAt((from + to) / 2, to)
	self.Outer.Size = Vector3.new(0.32 * pulse, 0.32 * pulse, length)
	self.Outer.CFrame = cframe
	self.Core.Size = Vector3.new(0.1, 0.1, length)
	self.Core.CFrame = cframe
	self.Glow.CFrame = CFrame.new(to)
	local now = os.clock()
	if now - self.LastSpark > 0.08 then
		self.LastSpark = now
		FXUtil.Emit(to, { Color = self.Color, Count = 3, Speed = NumberRange.new(6, 14), Lifetime = NumberRange.new(0.1, 0.25), Size = 0.2 })
	end
end

function BeamSession:Stop()
	for _, part in { self.Outer, self.Core, self.Glow } do
		FXUtil.Tween(part, 0.1, { Transparency = 1 })
		task.delay(0.12, function()
			part:Destroy()
		end)
	end
end

--[[ Plasma orb projectiles ]]

type Orb = { Part: BasePart, Position: Vector3, Velocity: Vector3, Gravity: number, Expires: number, Offset: Vector3, Born: number }
local orbs: { [string]: Orb } = {}
local MAX_ORBS = 60
local OFFSET_BLEND = 0.15

function WeaponFX.SpawnOrb(key: string, origin: Vector3, visualStart: Vector3, velocity: Vector3, weapon)
	if orbs[key] then
		return
	end
	local count = 0
	for _ in orbs do
		count += 1
	end
	if count >= MAX_ORBS then
		return
	end
	local orb = FXUtil.Part("PlasmaOrb", Enum.PartType.Ball)
	orb.Size = Vector3.one * (weapon.Projectile.Radius * 2 + 0.5)
	orb.Color = weapon.TracerColor
	orb.CFrame = CFrame.new(visualStart)
	local core = FXUtil.Part("Core", Enum.PartType.Ball)
	core.Size = orb.Size * 0.55
	core.Color = Color3.new(1, 1, 1)
	core.CFrame = orb.CFrame
	core.Anchored = false -- follows the anchored orb through the weld
	core.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = orb
	weld.Part1 = core
	weld.Parent = core
	core.Parent = orb
	local light = Instance.new("PointLight")
	light.Color = weapon.TracerColor
	light.Range = 14
	light.Brightness = 3
	light.Parent = orb
	local wake = FXUtil.AttachEmitter(orb, {
		Color = weapon.TracerColor,
		Rate = 60,
		Speed = NumberRange.new(0.5, 2),
		Lifetime = NumberRange.new(0.2, 0.4),
		Size = NumberSequence.new(0.6, 0),
		Spread = Vector2.new(180, 180),
	})
	wake.LockedToPart = false
	orb.Parent = FXUtil.Folder()
	orbs[key] = {
		Part = orb,
		Position = origin,
		Velocity = velocity,
		Gravity = weapon.Projectile.Gravity,
		Expires = os.clock() + weapon.Projectile.Lifetime + 0.5,
		Offset = visualStart - origin,
		Born = os.clock(),
	}
end

function WeaponFX.RemoveOrb(key: string)
	local orb = orbs[key]
	if orb then
		orb.Part:Destroy()
		orbs[key] = nil
	end
end

local function stepOrbs(deltaTime: number)
	local now = os.clock()
	for key, orb in orbs do
		if now > orb.Expires then
			orb.Part:Destroy()
			orbs[key] = nil
		else
			orb.Velocity -= Vector3.new(0, orb.Gravity * deltaTime, 0)
			orb.Position += orb.Velocity * deltaTime
			local blend = math.clamp(1 - (now - orb.Born) / OFFSET_BLEND, 0, 1)
			local spin = CFrame.Angles(now * 6, now * 4, 0)
			orb.Part.CFrame = CFrame.new(orb.Position + orb.Offset * blend) * spin
		end
	end
end

function WeaponFX:Init()
	linePool = ObjectPool.new(function()
		return FXUtil.Part("Tracer")
	end, FXUtil.Folder(), 160)
	for index = 1, HIT_FLASH_POOL do
		local highlight = Instance.new("Highlight")
		highlight.Name = "HitFlash" .. index
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 1
		highlight.Parent = FXUtil.Folder()
		hitHighlights[index] = highlight
	end
	RunService.Heartbeat:Connect(function(deltaTime)
		if next(orbs) then
			stepOrbs(deltaTime)
		end
		if #activeBeams > 0 then
			stepBeams()
		end
	end)
end

return WeaponFX
