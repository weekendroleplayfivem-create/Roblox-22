--[[
	WorldFX
	Non-weapon 3D effects:
	  * movement: dash afterimages, slide sparks, double/wall-jump rings,
	    landing dust rings, jump-pad launches
	  * eliminations: neon dissolve + rising pixels + shockwave + light pillar
	  * spawns: arrival beam
	  * abilities: barrier/gravity-field/decoy dressing (via CollectionService
	    tags on the server objects), scan pulse wave, reveal highlights,
	    phase shimmer
	  * jump pads: idle particle columns
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local AbilityConfig = require(Shared.Config.AbilityConfig)

local FXUtil = require(script.Parent.FXUtil)

local WorldFX = {}

local WHITE = Color3.new(1, 1, 1)
local AFTERIMAGE_MAX_PARTS = 16

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function feetOf(character: Model): Vector3?
	local root = rootOf(character)
	if not root then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, root.Size.Y / 2 + hip - 0.1, 0)
end

--[[ Movement ]]

-- Neon "ghost" copies of the character's limbs that fade out.
function WorldFX.Afterimage(character: Model, color: Color3)
	if FXUtil.Reduced() then
		return
	end
	local count = 0
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			count += 1
			if count > AFTERIMAGE_MAX_PARTS then
				break
			end
			local ghost = FXUtil.Part("Ghost")
			ghost.Size = part.Size
			ghost.CFrame = part.CFrame
			ghost.Color = color
			ghost.Transparency = 0.45
			FXUtil.Flash(ghost, 0.35, { Transparency = 1, Size = part.Size * 0.85 })
		end
	end
end

function WorldFX.Dash(character: Model, color: Color3)
	WorldFX.Afterimage(character, color)
	task.delay(0.07, function()
		if character.Parent then
			WorldFX.Afterimage(character, color)
		end
	end)
	local root = rootOf(character)
	if root then
		FXUtil.Emit(root.Position, {
			Color = color,
			Count = 12,
			Direction = -root.AssemblyLinearVelocity.Unit,
			Spread = Vector2.new(35, 35),
			Speed = NumberRange.new(10, 20),
			Lifetime = NumberRange.new(0.2, 0.4),
			Size = 0.35,
		})
	end
end

function WorldFX.JumpRing(character: Model, color: Color3)
	local feet = feetOf(character)
	if feet then
		FXUtil.Ring(feet, Vector3.yAxis, color, 1, 5, 0.3, 0.12)
		FXUtil.Emit(feet, { Color = color, Count = 8, Direction = -Vector3.yAxis, Spread = Vector2.new(70, 70), Speed = NumberRange.new(6, 12), Size = 0.25 })
	end
end

function WorldFX.WallJump(position: Vector3, normal: Vector3, color: Color3)
	FXUtil.Ring(position, normal, color, 1, 4.5, 0.3, 0.12)
	FXUtil.Emit(position, { Color = color, Count = 10, Direction = normal, Spread = Vector2.new(50, 50), Speed = NumberRange.new(8, 16), Size = 0.25 })
end

function WorldFX.Landing(character: Model, intensity: number)
	local feet = feetOf(character)
	if not feet then
		return
	end
	local dust = Color3.fromRGB(200, 210, 255)
	FXUtil.Ring(feet, Vector3.yAxis, dust, 1.5, 4 + intensity * 6, 0.35, 0.08)
	FXUtil.Emit(feet, {
		Color = dust,
		Texture = FXUtil.Textures.Smoke,
		Count = math.floor(4 + intensity * 8),
		Direction = Vector3.yAxis,
		Spread = Vector2.new(90, 90),
		Speed = NumberRange.new(4, 9),
		Lifetime = NumberRange.new(0.3, 0.6),
		Size = NumberSequence.new(0.8, 2),
		LightEmission = 0.2,
		Transparency = NumberSequence.new(0.5, 1),
		Drag = 4,
	})
end

-- Sparks trailing from the feet while sliding. Returns a stop function.
function WorldFX.StartSlideSparks(character: Model, color: Color3): () -> ()
	local root = rootOf(character)
	if not root then
		return function() end
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SlideSparks"
	attachment.Position = Vector3.new(0, -2.6, 0.5)
	attachment.Parent = root
	local emitter = FXUtil.AttachEmitter(attachment, {
		Color = ColorSequence.new(WHITE, color),
		Rate = 60,
		Speed = NumberRange.new(6, 12),
		Lifetime = NumberRange.new(0.15, 0.3),
		Spread = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, -60, 0),
		Size = NumberSequence.new(0.2, 0),
	})
	emitter.EmissionDirection = Enum.NormalId.Back
	return function()
		emitter.Enabled = false
		task.delay(0.4, function()
			attachment:Destroy()
		end)
	end
end

function WorldFX.JumpPadLaunch(position: Vector3, color: Color3)
	FXUtil.Ring(position, Vector3.yAxis, color, 2, 10, 0.4, 0.15)
	FXUtil.Emit(position, { Color = color, Count = 16, Direction = Vector3.yAxis, Spread = Vector2.new(15, 15), Speed = NumberRange.new(25, 45), Lifetime = NumberRange.new(0.3, 0.6), Size = 0.35 })
	FXUtil.Light(position, color, 20, 4, 0.3)
end

--[[ Eliminations and spawns ]]

-- Stylised elimination: the body turns to glowing pixels and floats away.
function WorldFX.Dissolve(character: Model, color: Color3, rainbow: boolean)
	if not character or not character.Parent then
		return
	end
	local root = rootOf(character)
	local position = if root then root.Position else character:GetPivot().Position
	local mainColor = if rainbow then Color3.fromHSV(math.random(), 0.7, 1) else color
	FXUtil.Sphere(position, WHITE, 1, 6, 0.25, 0)
	FXUtil.Sphere(position, mainColor, 2, 10, 0.5, 0.3)
	local feet = feetOf(character) or position
	FXUtil.Ring(feet, Vector3.yAxis, mainColor, 2, 14, 0.5, 0.2)
	FXUtil.Light(position, mainColor, 25, 6, 0.6)

	-- Light pillar.
	local pillar = FXUtil.Part("Pillar", Enum.PartType.Cylinder)
	pillar.Color = mainColor
	pillar.Transparency = 0.2
	pillar.Size = Vector3.new(30, 1.2, 1.2)
	pillar.CFrame = CFrame.new(feet + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	FXUtil.Flash(pillar, 0.6, { Transparency = 1, Size = Vector3.new(30, 0.1, 0.1) })

	FXUtil.Emit(position, {
		Color = if rainbow
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
			})
			else ColorSequence.new(mainColor),
		Count = 24,
		Speed = NumberRange.new(4, 12),
		Lifetime = NumberRange.new(0.6, 1.1),
		Acceleration = Vector3.new(0, 12, 0),
		Size = NumberSequence.new(0.5, 0),
		Essential = true,
	})

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.Neon
			part.Color = if rainbow then Color3.fromHSV(math.random(), 0.6, 1) else mainColor
			FXUtil.Tween(part, 0.6, { Transparency = 1 })
		elseif part:IsA("Decal") then
			part.Transparency = 1
		end
	end

	-- Rising pixel cubes.
	if not FXUtil.Reduced() then
		for _ = 1, 10 do
			local cube = FXUtil.Part("Pixel")
			cube.Color = if rainbow then Color3.fromHSV(math.random(), 0.7, 1) else mainColor
			cube.Size = Vector3.one * (0.3 + math.random() * 0.3)
			local start = position + Vector3.new(math.random() - 0.5, (math.random() - 0.5) * 4, math.random() - 0.5) * 2
			cube.CFrame = CFrame.new(start)
			FXUtil.Flash(cube, 0.9 + math.random() * 0.4, {
				CFrame = CFrame.new(start + Vector3.new((math.random() - 0.5) * 3, 5 + math.random() * 4, (math.random() - 0.5) * 3)) * CFrame.Angles(math.random() * 4, math.random() * 4, 0),
				Transparency = 1,
				Size = Vector3.one * 0.05,
			}, Enum.EasingStyle.Sine)
		end
	end
end

function WorldFX.SpawnArrival(character: Model, color: Color3)
	local root = rootOf(character)
	if not root then
		return
	end
	local feet = feetOf(character) or root.Position
	local beam = FXUtil.Part("SpawnBeam", Enum.PartType.Cylinder)
	beam.Color = color
	beam.Transparency = 0.3
	beam.Size = Vector3.new(40, 4, 4)
	beam.CFrame = CFrame.new(feet + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
	FXUtil.Flash(beam, 0.7, { Transparency = 1, Size = Vector3.new(40, 0.2, 0.2) })
	FXUtil.Ring(feet, Vector3.yAxis, color, 6, 1, 0.5, 0.15)
	FXUtil.Emit(root.Position, { Color = color, Count = 14, Speed = NumberRange.new(2, 6), Lifetime = NumberRange.new(0.5, 0.9), Acceleration = Vector3.new(0, 10, 0), Size = 0.35 })
end

--[[ Abilities ]]

function WorldFX.PulseWave(origin: Vector3, radius: number, color: Color3)
	FXUtil.Sphere(origin, color, 2, radius * 2, 0.8, 0.6)
	FXUtil.Ring(origin - Vector3.new(0, 2.5, 0), Vector3.yAxis, color, 2, radius * 2, 0.8, 0.25)
	FXUtil.Ring(origin, Vector3.yAxis, WHITE, 1, radius * 1.2, 0.5, 0.1)
end

function WorldFX.DecoyPop(position: Vector3)
	local color = AbilityConfig.Get("Decoy").Color
	FXUtil.Sphere(position, color, 1, 7, 0.35, 0.1)
	FXUtil.Emit(position, { Color = color, Count = 18, Speed = NumberRange.new(8, 16), Lifetime = NumberRange.new(0.3, 0.6), Size = 0.4 })
end

local revealHighlights: { [Model]: Highlight } = {}

function WorldFX.Reveal(targets, duration: number, color: Color3)
	for _, character in targets do
		if typeof(character) == "Instance" and character:IsA("Model") then
			local existing = revealHighlights[character]
			if existing then
				existing:Destroy()
			end
			local highlight = Instance.new("Highlight")
			highlight.FillColor = color
			highlight.OutlineColor = WHITE
			highlight.FillTransparency = 0.45
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = character
			highlight.Parent = FXUtil.Folder()
			revealHighlights[character] = highlight
			-- Blink at the start so the reveal is noticeable.
			task.spawn(function()
				for _ = 1, 3 do
					highlight.FillTransparency = 0.1
					task.wait(0.08)
					highlight.FillTransparency = 0.45
					task.wait(0.08)
				end
			end)
			task.delay(duration, function()
				if revealHighlights[character] == highlight then
					revealHighlights[character] = nil
				end
				highlight:Destroy()
			end)
		end
	end
end

-- Server-created ability objects get extra client-side dressing.
local function dressBarrier(barrier: Instance)
	if not barrier:IsA("BasePart") then
		return
	end
	local fullSize = barrier.Size
	barrier.Size = Vector3.new(fullSize.X, 0.2, fullSize.Z)
	FXUtil.Tween(barrier, 0.25, { Size = fullSize }, Enum.EasingStyle.Back)
	FXUtil.AttachEmitter(barrier, {
		Color = barrier.Color,
		Rate = 14,
		Speed = NumberRange.new(0.5, 1.5),
		Lifetime = NumberRange.new(0.6, 1.2),
		Spread = Vector2.new(180, 180),
		Size = NumberSequence.new(0.35, 0),
	}).Shape = Enum.ParticleEmitterShape.Box
	FXUtil.Emit(barrier.Position, { Color = barrier.Color, Count = 16, Speed = NumberRange.new(6, 14), Size = 0.35 })
end

local function dressGravityField(field: Instance)
	if not field:IsA("BasePart") then
		return
	end
	local fullSize = field.Size
	field.Size = Vector3.one
	FXUtil.Tween(field, 0.4, { Size = fullSize }, Enum.EasingStyle.Back)
	local emitter = FXUtil.AttachEmitter(field, {
		Color = field.Color,
		Rate = 30,
		Speed = NumberRange.new(1, 3),
		Lifetime = NumberRange.new(1.5, 2.5),
		Spread = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 3, 0),
		Size = NumberSequence.new(0.4, 0),
	})
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	FXUtil.Ring(field.Position, Vector3.yAxis, field.Color, 2, fullSize.X, 0.5, 0.2)
end

local function dressDecoy(decoy: Instance)
	if decoy:IsA("Model") then
		local root = rootOf(decoy)
		if root then
			WorldFX.DecoyPop(root.Position)
			local emitter = FXUtil.AttachEmitter(root, {
				Color = AbilityConfig.Get("Decoy").Color,
				Rate = 12,
				Speed = NumberRange.new(0.5, 1),
				Lifetime = NumberRange.new(0.4, 0.8),
				Spread = Vector2.new(180, 180),
				Size = NumberSequence.new(0.3, 0),
			})
			emitter.Shape = Enum.ParticleEmitterShape.Box
		end
	end
end

-- Idle effects on jump pads (rising sparkles).
local function dressJumpPad(pad: Instance)
	if not pad:IsA("BasePart") or pad:FindFirstChild("PadSparkles") then
		return
	end
	local emitter = FXUtil.AttachEmitter(pad, {
		Color = pad.Color,
		Rate = 8,
		Speed = NumberRange.new(4, 8),
		Lifetime = NumberRange.new(0.6, 1),
		Spread = Vector2.new(5, 5),
		Size = NumberSequence.new(0.3, 0),
	})
	emitter.Name = "PadSparkles"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Top
end

local function watchTag(tag: string, callback: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(callback)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(callback, instance)
	end
end

function WorldFX:Init() end

function WorldFX:Start()
	watchTag(RaycastUtil.Tags.ShotBlocker, dressBarrier)
	watchTag(RaycastUtil.Tags.GravityField, dressGravityField)
	watchTag(RaycastUtil.Tags.Decoy, dressDecoy)
	watchTag(RaycastUtil.Tags.JumpPad, dressJumpPad)
end

return WorldFX
