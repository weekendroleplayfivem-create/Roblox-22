--[[
	EffectsController
	All cosmetic, client-only visual effects. Stylised and kid-friendly:
	energy tracers, neon sparks, impact rings, colour bursts, holograms.
	No blood, no gore.

	Performance:
	  * tracers/rings come from ObjectPools
	  * "Reduced Effects" setting skips secondary particles
	  * projectile visuals are simulated in one Heartbeat loop
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local ObjectPool = require(Shared.Modules.ObjectPool)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local MapConfig = require(Shared.Config.MapConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)

local ClientState = require(script.Parent.ClientState)
local SoundController = require(script.Parent.SoundController)
local CameraController = require(script.Parent.CameraController)

local EffectsController = {}

local player = Players.LocalPlayer

local TRACER_LIFETIME = 0.06
local BEAM_TRACER_LIFETIME = 0.09
local MAX_PROJECTILES = 60

local effectsFolder: Folder
local tracerPool
local ringPool

type ProjectileVisual = { Part: BasePart, Position: Vector3, Velocity: Vector3, Gravity: number, Expires: number, Offset: Vector3, OffsetTime: number, Born: number }
local projectiles: { [string]: ProjectileVisual } = {}

local function reduced(): boolean
	return ClientState.GetSetting("ReducedEffects") == true
end

local function newEffectPart(name: string): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end

function EffectsController:Tracer(from: Vector3, to: Vector3, color: Color3, isBeam: boolean?)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local tracer = tracerPool:Get()
	local width = if isBeam then 0.18 else 0.1
	tracer.Size = Vector3.new(width, width, length)
	tracer.CFrame = CFrame.lookAt((from + to) / 2, to)
	tracer.Color = color
	tracer.Transparency = 0.1
	tracerPool:ReturnAfter(tracer, if isBeam then BEAM_TRACER_LIFETIME else TRACER_LIFETIME)
end

-- Jagged arc between two points (Arc Blaster).
function EffectsController:Lightning(from: Vector3, to: Vector3, color: Color3)
	local segments = if reduced() then 2 else 4
	local previous = from
	for index = 1, segments do
		local alpha = index / segments
		local point = from:Lerp(to, alpha)
		if index < segments then
			point += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.2
		end
		EffectsController:Tracer(previous, point, color, true)
		previous = point
	end
end

function EffectsController:MuzzleFlash(position: Vector3, color: Color3)
	local flash = ringPool:Get()
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 0.5
	flash.Color = color
	flash.Transparency = 0.2
	flash.CFrame = CFrame.new(position)
	local light = flash:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = color
		light.Enabled = true
	end
	task.delay(0.04, function()
		if light then
			light.Enabled = false
		end
		ringPool:Return(flash)
	end)
end

-- Ring "pop" where a shot hits the world.
function EffectsController:Impact(position: Vector3, normal: Vector3, color: Color3)
	local ring = ringPool:Get()
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.05, 0.4, 0.4)
	ring.Color = color
	ring.Transparency = 0.1
	-- Cylinder axis is X; point it along the surface normal.
	ring.CFrame = CFrame.lookAt(position + normal * 0.05, position + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
	local tween = TweenService:Create(ring, TweenInfo.new(0.18), { Size = Vector3.new(0.05, 1.6, 1.6), Transparency = 1 })
	tween:Play()
	ringPool:ReturnAfter(ring, 0.2)
end

-- Colour sparkle when a shot connects with a target (no blood, ever).
function EffectsController:HitSpark(position: Vector3, color: Color3)
	local spark = ringPool:Get()
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.one * 0.3
	spark.Color = color:Lerp(Color3.new(1, 1, 1), 0.5)
	spark.Transparency = 0
	spark.CFrame = CFrame.new(position)
	TweenService:Create(spark, TweenInfo.new(0.15), { Size = Vector3.one * 1.4, Transparency = 1 }):Play()
	ringPool:ReturnAfter(spark, 0.16)
end

function EffectsController:Burst(position: Vector3, color: Color3, size: number, duration: number?)
	local sphere = newEffectPart("Burst")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one * 0.5
	sphere.Color = color
	sphere.Transparency = 0.2
	sphere.CFrame = CFrame.new(position)
	sphere.Parent = effectsFolder
	TweenService:Create(sphere, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
	Debris:AddItem(sphere, (duration or 0.35) + 0.05)
	if not reduced() then
		local emitterHolder = newEffectPart("Particles")
		emitterHolder.Transparency = 1
		emitterHolder.Size = Vector3.one * 0.2
		emitterHolder.CFrame = CFrame.new(position)
		emitterHolder.Parent = effectsFolder
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.4, 0)
		emitter.Speed = NumberRange.new(10, 22)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Lifetime = NumberRange.new(0.3, 0.5)
		emitter.Rate = 0
		emitter.Parent = emitterHolder
		emitter:Emit(14)
		Debris:AddItem(emitterHolder, 1)
	end
end

--[[ Projectiles ]]

function EffectsController:SpawnProjectile(key: string, origin: Vector3, visualStart: Vector3, velocity: Vector3, weapon, _isLocal: boolean)
	local count = 0
	for _ in projectiles do
		count += 1
	end
	if count >= MAX_PROJECTILES or projectiles[key] then
		return
	end
	local orb = newEffectPart("Projectile")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * (weapon.Projectile.Radius * 2 + 0.4)
	orb.Color = weapon.TracerColor
	orb.CFrame = CFrame.new(visualStart)
	local light = Instance.new("PointLight")
	light.Color = weapon.TracerColor
	light.Range = 10
	light.Brightness = 3
	light.Parent = orb
	orb.Parent = effectsFolder
	-- The visual starts at the muzzle and blends onto the true path.
	projectiles[key] = {
		Part = orb,
		Position = origin,
		Velocity = velocity,
		Gravity = weapon.Projectile.Gravity,
		Expires = os.clock() + weapon.Projectile.Lifetime + 0.5,
		Offset = visualStart - origin,
		OffsetTime = 0.15,
		Born = os.clock(),
	}
end

local function stepProjectiles(deltaTime: number)
	local now = os.clock()
	for key, projectile in projectiles do
		if now > projectile.Expires then
			projectile.Part:Destroy()
			projectiles[key] = nil
		else
			projectile.Velocity -= Vector3.new(0, projectile.Gravity * deltaTime, 0)
			projectile.Position += projectile.Velocity * deltaTime
			local blend = math.clamp(1 - (now - projectile.Born) / projectile.OffsetTime, 0, 1)
			projectile.Part.CFrame = CFrame.new(projectile.Position + projectile.Offset * blend)
		end
	end
end

local function onProjectileImpact(data)
	local projectile = projectiles[data.Key]
	if projectile then
		projectile.Part:Destroy()
		projectiles[data.Key] = nil
	end
	local weapon = WeaponConfig.Get(data.Weapon)
	local color = if weapon then weapon.TracerColor else Color3.new(1, 0.4, 0.9)
	EffectsController:Burst(data.Position, color, (data.Radius or 8) * 2, 0.4)
	SoundController:PlayAt("Explosion", data.Position, 0.05)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local distance = (root.Position - data.Position).Magnitude
		if distance < 40 then
			CameraController:Shake(0.6 * (1 - distance / 40))
		end
	end
end

--[[ Other players' shots ]]

local function onShotReplicated(data)
	local weapon = WeaponConfig.Get(data.Weapon)
	if not weapon or typeof(data.Origin) ~= "Vector3" or type(data.Directions) ~= "table" then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - data.Origin).Magnitude > 600 then
		return -- too far away to matter
	end
	local ignore: { Instance } = {}
	for _, model in RaycastUtil.GetContainer(RaycastUtil.Containers.Bots):GetChildren() do
		if model:GetAttribute("CombatantId") == data.Shooter then
			table.insert(ignore, model)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.UserId == data.Shooter and other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastUtil.CombatParams(ignore, nil, data.Shooter)
	for _, direction in data.Directions do
		if typeof(direction) == "Vector3" then
			local result = workspace:Raycast(data.Origin, direction * weapon.Range, params)
			local endPoint = if result then result.Position else data.Origin + direction * weapon.Range
			if weapon.ProjectileType == "Chain" then
				EffectsController:Lightning(data.Origin, endPoint, weapon.TracerColor)
			else
				EffectsController:Tracer(data.Origin, endPoint, weapon.TracerColor, weapon.FireMode == "Beam")
			end
			if result and not reduced() then
				EffectsController:Impact(result.Position, result.Normal, weapon.TracerColor)
			end
		end
	end
	if type(data.Chain) == "table" then
		local previous = nil
		for _, point in data.Chain do
			if typeof(point) == "Vector3" then
				if previous then
					EffectsController:Lightning(previous, point, weapon.TracerColor)
				end
				previous = point
			end
		end
	end
	SoundController:PlayAt(weapon.Sounds.Fire, data.Origin, 0.08)
end

--[[ Eliminations: stylised dissolve ]]

local function dissolve(character: Model, color: Color3, rainbow: boolean)
	if not character or not character.Parent then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local position = if root and root:IsA("BasePart") then root.Position else character:GetPivot().Position
	local burstColor = if rainbow then Color3.fromHSV(math.random(), 0.7, 1) else color
	EffectsController:Burst(position, burstColor, 8, 0.5)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = Enum.Material.Neon
			part.Color = if rainbow then Color3.fromHSV(math.random(), 0.6, 1) else color
			TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		elseif part:IsA("Decal") then
			part.Transparency = 1
		end
	end
end

--[[ Ability visuals ]]

local revealHighlights: { [Model]: Highlight } = {}

local function reveal(targets, duration: number)
	for _, character in targets do
		if typeof(character) == "Instance" and character:IsA("Model") then
			local existing = revealHighlights[character]
			if existing then
				existing:Destroy()
			end
			local highlight = Instance.new("Highlight")
			highlight.FillColor = AbilityConfig.Get("Pulse").Color
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = 0.5
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = character
			highlight.Parent = effectsFolder
			revealHighlights[character] = highlight
			task.delay(duration, function()
				if revealHighlights[character] == highlight then
					revealHighlights[character] = nil
				end
				highlight:Destroy()
			end)
		end
	end
end

local function onAbilityEffect(data)
	if data.Kind == "Reveal" then
		reveal(data.Targets or {}, data.Duration or 2)
		if typeof(data.Origin) == "Vector3" then
			EffectsController:Burst(data.Origin, AbilityConfig.Get("Pulse").Color, (data.Radius or 40) * 2, 0.7)
		end
		SoundController:Play("Pulse")
	elseif data.Kind == "DecoyPopped" and typeof(data.Position) == "Vector3" then
		EffectsController:Burst(data.Position, AbilityConfig.Get("Decoy").Color, 6, 0.35)
	end
end

-- Other players' movement effects (dash/slide trails, jump puffs).
local function onMovementFx(data)
	local character = data.Character
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if data.Kind == "Dash" or data.Kind == "Slide" then
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 0.8, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -0.8, 0)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = 0.25
		trail.LightEmission = 0.8
		trail.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255))
		trail.Transparency = NumberSequence.new(0.4, 1)
		trail.Parent = root
		Debris:AddItem(trail, 0.7)
		Debris:AddItem(top, 0.7)
		Debris:AddItem(bottom, 0.7)
		SoundController:PlayAt(if data.Kind == "Dash" then "Dash" else "Slide", root.Position, 0.05)
	elseif data.Kind == "DoubleJump" or data.Kind == "WallJump" then
		if not reduced() then
			EffectsController:Burst(root.Position - Vector3.new(0, 2.5, 0), Color3.fromRGB(200, 240, 255), 3, 0.25)
		end
	end
end

-- Phase (others look see-through) and spawn protection shimmer.
local function watchCharacter(character: Model)
	local function applyPhase()
		if character == player.Character then
			return
		end
		local phased = character:GetAttribute("Phased") == true
		local transparency = if phased then AbilityConfig.Get("Phase").Transparency else 0
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.LocalTransparencyModifier = transparency
			end
		end
	end
	character:GetAttributeChangedSignal("Phased"):Connect(applyPhase)

	local shield: Highlight? = nil
	local function applyProtection()
		local protected = character:GetAttribute("SpawnProtected") == true
		if protected and not shield then
			shield = Instance.new("Highlight")
			shield.FillColor = Color3.fromRGB(150, 230, 255)
			shield.FillTransparency = 0.7
			shield.OutlineTransparency = 0.3
			shield.DepthMode = Enum.HighlightDepthMode.Occluded
			shield.Adornee = character
			shield.Parent = character
		elseif not protected and shield then
			shield:Destroy()
			shield = nil
		end
	end
	character:GetAttributeChangedSignal("SpawnProtected"):Connect(applyProtection)
	applyProtection()
end

local function watchContainer(container: Instance)
	container.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			watchCharacter(child)
		end
	end)
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			watchCharacter(child)
		end
	end
end

--[[ Lighting per location ]]

function EffectsController:ApplyLighting(preset)
	if not preset then
		return
	end
	for property, value in preset do
		pcall(function()
			(Lighting :: any)[property] = value
		end)
	end
end

local function updateLighting()
	local matchState = ClientState.Get("MatchState")
	if ClientState.IsInMatch() and matchState and matchState.Map then
		local map = MapConfig.Get(matchState.Map)
		EffectsController:ApplyLighting(map and map.Lighting)
		SoundController:SetAmbient(map and map.Ambient)
	else
		EffectsController:ApplyLighting(MapConfig.LobbyLighting)
		SoundController:SetAmbient(nil)
	end
end

function EffectsController:Init()
	effectsFolder = RaycastUtil.GetContainer(RaycastUtil.Containers.Effects)
	tracerPool = ObjectPool.new(function()
		return newEffectPart("Tracer")
	end, effectsFolder, 96)
	ringPool = ObjectPool.new(function()
		local part = newEffectPart("Ring")
		local light = Instance.new("PointLight")
		light.Range = 8
		light.Brightness = 4
		light.Enabled = false
		light.Parent = part
		return part
	end, effectsFolder, 64)

	-- Bloom + colour grading for the neon look (cheap post effects).
	if not Lighting:FindFirstChild("VectorRushBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "VectorRushBloom"
		bloom.Intensity = 0.6
		bloom.Size = 20
		bloom.Threshold = 1.4
		bloom.Parent = Lighting
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "VectorRushGrade"
		grade.Saturation = 0.15
		grade.Contrast = 0.05
		grade.Parent = Lighting
	end
end

function EffectsController:Start()
	Net.Event("Combat", "ShotReplicated").OnClientEvent:Connect(onShotReplicated)
	Net.Event("Combat", "ProjectileSpawned").OnClientEvent:Connect(function(data)
		local weapon = WeaponConfig.Get(data.Weapon)
		if weapon and weapon.Projectile then
			EffectsController:SpawnProjectile(data.Key, data.Origin, data.Origin, data.Velocity, weapon, false)
			SoundController:PlayAt(weapon.Sounds.Fire, data.Origin, 0.05)
		end
	end)
	Net.Event("Combat", "ProjectileImpact").OnClientEvent:Connect(onProjectileImpact)
	Net.Event("Combat", "Elimination").OnClientEvent:Connect(function(data)
		if typeof(data.Character) == "Instance" and data.Character:IsA("Model") then
			dissolve(data.Character, data.EffectColor or Color3.new(1, 1, 1), data.Rainbow == true)
		end
	end)
	Net.Event("Abilities", "AbilityEffect").OnClientEvent:Connect(onAbilityEffect)
	Net.Event("Movement", "MovementFx").OnClientEvent:Connect(onMovementFx)

	RunService.Heartbeat:Connect(function(deltaTime)
		if next(projectiles) then
			stepProjectiles(deltaTime)
		end
	end)

	local function watchPlayer(other: Player)
		other.CharacterAdded:Connect(watchCharacter)
		if other.Character then
			watchCharacter(other.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	watchContainer(RaycastUtil.GetContainer(RaycastUtil.Containers.Bots))
	watchContainer(RaycastUtil.GetContainer(RaycastUtil.Containers.AbilityObjects))

	ClientState.Observe("Location", updateLighting)
	ClientState.Observe("MatchState", updateLighting)
end

return EffectsController
