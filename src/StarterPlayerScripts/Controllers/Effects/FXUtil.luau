--[[
	FXUtil
	Shared building blocks for client visual effects: effect parts, pooled
	particle emitters, tweens and the "Reduced Effects" check.
	Everything lives in workspace.Effects (never raycast, never replicated).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectPool = require(Shared.Modules.ObjectPool)
local RaycastUtil = require(Shared.Modules.RaycastUtil)

local ClientState = require(script.Parent.Parent.ClientState)

local FXUtil = {}

-- Built-in particle textures that ship with the Roblox client.
FXUtil.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local folder: Folder
local emitterPool = nil

function FXUtil.Folder(): Folder
	if not folder then
		folder = RaycastUtil.GetContainer(RaycastUtil.Containers.Effects)
	end
	return folder
end

function FXUtil.Reduced(): boolean
	return ClientState.GetSetting("ReducedEffects") == true
end

-- Anchored, non-interactive neon part.
function FXUtil.Part(name: string, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	if shape then
		part.Shape = shape
	end
	return part
end

function FXUtil.Tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

-- Temporary part that fades/grows then is destroyed.
function FXUtil.Flash(part: BasePart, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	part.Parent = FXUtil.Folder()
	FXUtil.Tween(part, duration, goals, style)
	task.delay(duration + 0.02, function()
		part:Destroy()
	end)
end

-- Flat ring (cylinder disc) lying on the plane with the given normal.
function FXUtil.Ring(position: Vector3, normal: Vector3, color: Color3, startSize: number, endSize: number, duration: number, thickness: number?)
	local ring = FXUtil.Part("Ring", Enum.PartType.Cylinder)
	ring.Color = color
	ring.Transparency = 0.15
	ring.Size = Vector3.new(thickness or 0.08, startSize, startSize)
	-- Cylinder axis is X: point X along the normal.
	ring.CFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(0, math.rad(90), 0)
	FXUtil.Flash(ring, duration, { Size = Vector3.new(thickness or 0.08, endSize, endSize), Transparency = 1 })
	return ring
end

-- Expanding glowing sphere.
function FXUtil.Sphere(position: Vector3, color: Color3, startSize: number, endSize: number, duration: number, startTransparency: number?)
	local sphere = FXUtil.Part("Sphere", Enum.PartType.Ball)
	sphere.Color = color
	sphere.Transparency = startTransparency or 0.2
	sphere.Size = Vector3.one * startSize
	sphere.CFrame = CFrame.new(position)
	FXUtil.Flash(sphere, duration, { Size = Vector3.one * endSize, Transparency = 1 })
	return sphere
end

function FXUtil.Light(position: Vector3, color: Color3, range: number, brightness: number, duration: number)
	local holder = FXUtil.Part("Light")
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.CFrame = CFrame.new(position)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = holder
	holder.Parent = FXUtil.Folder()
	FXUtil.Tween(light, duration, { Brightness = 0 })
	task.delay(duration + 0.02, function()
		holder:Destroy()
	end)
end

--[[
	One-shot particle burst at a position.
	options: Color (Color3 | ColorSequence), Count, Speed (NumberRange), Size (NumberSequence | number),
	         Lifetime (NumberRange), Spread (Vector2 degrees), Texture, LightEmission,
	         Acceleration, Drag, Direction (Vector3 normal for emission), Transparency
]]
function FXUtil.Emit(position: Vector3, options)
	if FXUtil.Reduced() and not options.Essential then
		return
	end
	local holder = emitterPool:Get()
	local emitter = holder:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
	local direction = options.Direction or Vector3.yAxis
	-- Emitters shoot along the part's top face (+Y).
	holder.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.rad(90), 0, 0)
	local color = options.Color or Color3.new(1, 1, 1)
	emitter.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
	local size = options.Size or 0.4
	emitter.Size = if typeof(size) == "NumberSequence" then size else NumberSequence.new(size, 0)
	emitter.Transparency = options.Transparency or NumberSequence.new(0, 1)
	emitter.Speed = options.Speed or NumberRange.new(8, 18)
	emitter.Lifetime = options.Lifetime or NumberRange.new(0.25, 0.45)
	emitter.SpreadAngle = options.Spread or Vector2.new(180, 180)
	emitter.Texture = options.Texture or FXUtil.Textures.Sparkle
	emitter.LightEmission = options.LightEmission or 1
	emitter.Acceleration = options.Acceleration or Vector3.zero
	emitter.Drag = options.Drag or 2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = options.RotSpeed or NumberRange.new(-90, 90)
	emitter:Emit(options.Count or 10)
	local maxLifetime = (options.Lifetime and options.Lifetime.Max) or 0.45
	emitterPool:ReturnAfter(holder, maxLifetime + 0.1)
end

-- Persistent emitter attached to an instance (returns the emitter; caller destroys).
function FXUtil.AttachEmitter(parent: Instance, options): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	local color = options.Color or Color3.new(1, 1, 1)
	emitter.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
	local size = options.Size or 0.3
	emitter.Size = if typeof(size) == "NumberSequence" then size else NumberSequence.new(size, 0)
	emitter.Transparency = options.Transparency or NumberSequence.new(0.2, 1)
	emitter.Speed = options.Speed or NumberRange.new(2, 4)
	emitter.Lifetime = options.Lifetime or NumberRange.new(0.5, 1)
	emitter.SpreadAngle = options.Spread or Vector2.new(30, 30)
	emitter.Texture = options.Texture or FXUtil.Textures.Sparkle
	emitter.LightEmission = options.LightEmission or 1
	emitter.Acceleration = options.Acceleration or Vector3.zero
	emitter.Rate = if FXUtil.Reduced() then (options.Rate or 10) * 0.3 else (options.Rate or 10)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	emitter.Parent = parent
	return emitter
end

function FXUtil:Init()
	emitterPool = ObjectPool.new(function()
		local holder = FXUtil.Part("Emitter")
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.2
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 0
		emitter.Enabled = true
		emitter.Parent = holder
		return holder
	end, FXUtil.Folder(), 48)
end

return FXUtil
