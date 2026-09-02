--!nonstrict
--[[
	FxLib.luau
	Procedural neon effect primitives. The whole game ships without art assets, so
	every visual here is built from parts, beams and particles at runtime.

	Two rules every effect in this file obeys:
		1. It is NEVER anchored to gameplay - effects are cosmetic, non-collidable,
		   non-queryable, and always parented to a dedicated container.
		2. It cleans itself up. An effect that outlives its Debris budget is a
		   frame-time leak in a game that lives or dies on frame time.
--]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FxLib = {}

local CONTAINER_NAME = "HyperBlastFx"

function FxLib.container(): Folder
	local existing = workspace:FindFirstChild(CONTAINER_NAME)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = workspace
	return folder
end

--[[ A non-colliding, non-queryable neon part - the base of nearly every effect. ]]
function FxLib.neonPart(props: { [string]: any }): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = Vector3.one
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end

	part.Parent = props.Parent or FxLib.container()
	return part
end

--[[ Expanding ring. Used for wall-jump impacts, ability casts and zone captures. ]]
function FxLib.ring(cframe: CFrame, color: Color3, radius: number, life: number, thickness: number?)
	local ring = FxLib.neonPart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Size = Vector3.new(thickness or 0.35, 1.2, 1.2),
		CFrame = cframe * CFrame.Angles(0, math.rad(90), 0),
		Transparency = 0.1,
	})

	local tween = TweenService:Create(ring, TweenInfo.new(life, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(thickness or 0.35, radius * 2, radius * 2),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, life + 0.05)
	return ring
end

--[[ A ring lying flat on a surface. `ring()` aligns the cylinder's axis with the
	 given CFrame's LookVector, so a ground ring needs a CFrame that LOOKS UP -
	 which is what the X-axis rotation here produces. Wrapped in a helper because
	 getting this backwards silently produces a ring standing on its edge. ]]
function FxLib.groundRing(position: Vector3, color: Color3, radius: number, life: number, thickness: number?)
	return FxLib.ring(
		CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0),
		color,
		radius,
		life,
		thickness
	)
end

--[[ Short-lived point light. Kept tiny and brief - lights are expensive. ]]
function FxLib.flash(position: Vector3, color: Color3, brightness: number, range: number, life: number)
	local anchor = FxLib.neonPart({
		Name = "Flash",
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
		Position = position,
	})

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = anchor

	TweenService:Create(light, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()
	Debris:AddItem(anchor, life + 0.05)
	return anchor
end

--[[ A beam between two points - tracers, rail shots, core tethers. ]]
function FxLib.beam(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local part = FxLib.neonPart({
		Name = "BeamAnchor",
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
		CFrame = CFrame.new(from),
	})

	local a0 = Instance.new("Attachment")
	a0.Parent = part

	local endPart = FxLib.neonPart({
		Name = "BeamAnchorEnd",
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
		CFrame = CFrame.new(to),
	})
	local a1 = Instance.new("Attachment")
	a1.Parent = endPart

	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = width
	beam.Width1 = width
	beam.Transparency = NumberSequence.new(0.05)
	beam.Parent = part

	TweenService:Create(beam, TweenInfo.new(life, Enum.EasingStyle.Linear), {
		Width0 = 0,
		Width1 = 0,
	}):Play()

	Debris:AddItem(part, life + 0.05)
	Debris:AddItem(endPart, life + 0.05)
	return beam
end

--[[ One-shot particle burst. `shape` steers the emission so the same helper can
	 serve a muzzle flash, a dash burst and an elimination. ]]
function FxLib.burst(position: Vector3, options: { [string]: any })
	local color: Color3 = options.Color or Color3.new(1, 1, 1)
	local secondary: Color3 = options.Secondary or color
	local count: number = options.Count or 24
	local speed: number = options.Speed or 30
	local life: number = options.Life or 0.55
	local size: number = options.Size or 0.6
	local spread: number = options.Spread or 180
	local direction: Vector3 = options.Direction or Vector3.yAxis

	local anchor = FxLib.neonPart({
		Name = "Burst",
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
		CFrame = CFrame.lookAt(position, position + direction),
	})

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, secondary),
	})
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Speed = NumberRange.new(speed * 0.55, speed)
	emitter.Lifetime = NumberRange.new(life * 0.6, life)
	emitter.SpreadAngle = Vector2.new(spread, spread)
	emitter.Rate = 0
	emitter.Drag = options.Drag or 4
	emitter.Acceleration = options.Acceleration or Vector3.new(0, -40, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Parent = attachment
	emitter:Emit(count)

	Debris:AddItem(anchor, life + 0.35)
	return anchor
end

--[[ Attaches a motion trail to a part and returns a handle that fades it out.
	 Used for dash trails, slide trails and projectile streaks. ]]
function FxLib.attachTrail(part: BasePart, color: Color3, secondary: Color3, life: number, width: number)
	local a0 = Instance.new("Attachment")
	a0.Name = "HB_TrailA0"
	a0.Position = Vector3.new(0, width * 0.5, 0)
	a0.Parent = part

	local a1 = Instance.new("Attachment")
	a1.Name = "HB_TrailA1"
	a1.Position = Vector3.new(0, -width * 0.5, 0)
	a1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, secondary),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = life
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.MinLength = 0.15
	trail.FaceCamera = true
	trail.Parent = part

	return {
		Trail = trail,
		Destroy = function()
			trail.Enabled = false
			Debris:AddItem(trail, life + 0.1)
			Debris:AddItem(a0, life + 0.1)
			Debris:AddItem(a1, life + 0.1)
		end,
	}
end

--[[ Holographic afterimage of a character. Phase Step's signature. ]]
function FxLib.afterimage(character: Model, color: Color3, life: number)
	local clone = Instance.new("Model")
	clone.Name = "Afterimage"

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local ghost = FxLib.neonPart({
				Name = descendant.Name,
				Size = descendant.Size,
				CFrame = descendant.CFrame,
				Color = color,
				Transparency = 0.55,
				Shape = descendant:IsA("Part") and descendant.Shape or Enum.PartType.Block,
				Parent = clone,
			})
			TweenService:Create(ghost, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Size = descendant.Size * 1.08,
			}):Play()
		end
	end

	clone.Parent = FxLib.container()
	Debris:AddItem(clone, life + 0.1)
	return clone
end

--[[ Floor scorch/energy trail dropped behind a slide. Segments are cheap parts
	 laid down at a fixed interval rather than a continuous decal. ]]
function FxLib.groundTrailSegment(position: Vector3, normal: Vector3, direction: Vector3, color: Color3, life: number)
	local segment = FxLib.neonPart({
		Name = "SlideTrail",
		Size = Vector3.new(2.6, 0.06, 1.4),
		Color = color,
		Transparency = 0.35,
		CFrame = CFrame.lookAt(position + normal * 0.06, position + normal * 0.06 + direction, normal),
	})

	TweenService:Create(segment, TweenInfo.new(life, Enum.EasingStyle.Linear), {
		Transparency = 1,
		Size = Vector3.new(3.4, 0.02, 0.4),
	}):Play()
	Debris:AddItem(segment, life + 0.05)
	return segment
end

--[[ Runs `callback(alpha)` every frame for `duration` seconds, then once with 1.
	 The generic driver behind procedural weapon animations. ]]
function FxLib.animate(duration: number, callback: (number) -> ()): () -> ()
	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		callback(alpha)
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
	return function()
		if connection.Connected then
			connection:Disconnect()
		end
	end
end

return FxLib
