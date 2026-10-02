--[[
	EffectsController
	Front door for all cosmetic client effects. The actual effects live in
	Controllers/Effects:
	  FXUtil      shared helpers (pooled emitters, rings, spheres, lights)
	  WeaponFX    tracers per style, muzzle flashes, impacts, beams, orbs, explosions
	  WorldFX     movement, eliminations, spawns, ability dressing, jump pads
	  ScreenFX    speed lines, vignette, low health, blur, scope, confetti
	  MapAnimator spinning / bobbing / pulsing map decorations
	This module wires them to server events (other players' shots, eliminations,
	abilities, movement) and applies per-map lighting + atmosphere + ambience.
	Everything here is client-only and kid-friendly (no blood or gore).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local MapConfig = require(Shared.Config.MapConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local ClientState = require(script.Parent.ClientState)
local SoundController = require(script.Parent.SoundController)
local CameraController = require(script.Parent.CameraController)

local EffectsFolder = script.Parent:WaitForChild("Effects")
local FXUtil = require(EffectsFolder.FXUtil)
local WeaponFX = require(EffectsFolder.WeaponFX)
local WorldFX = require(EffectsFolder.WorldFX)
local ScreenFX = require(EffectsFolder.ScreenFX)
local MapAnimator = require(EffectsFolder.MapAnimator)

local EffectsController = {}

EffectsController.Screen = ScreenFX
EffectsController.World = WorldFX
EffectsController.Weapon = WeaponFX

local player = Players.LocalPlayer

local ARENA_DISTANCE = 600 -- characters this far from the lobby are in the arena
local REPLICATED_SHOT_RANGE = 600

local function teamColor(team: any): Color3
	if team and MatchConfig.Teams[team] then
		return MatchConfig.Teams[team].Color
	end
	return MatchConfig.FreeForAllColor
end

-- Colour of the local player's equipped trail cosmetic.
function EffectsController:GetTrailColor(): Color3
	local profile = ClientState.Get("Profile")
	local item = profile and CosmeticConfig.Get(profile.Equipped.Trail)
	if item and item.Rainbow then
		return Color3.fromHSV((os.clock() * 0.5) % 1, 0.7, 1)
	end
	return if item and item.Color then item.Color else Color3.fromRGB(60, 230, 255)
end

--[[ Weapon effects used by WeaponController ]]

function EffectsController:Tracer(weapon, from: Vector3, to: Vector3, intensity: number?)
	WeaponFX.Tracer(weapon.TracerStyle or "Bolt", from, to, weapon.TracerColor, intensity)
end

function EffectsController:MuzzleFlash(cframe: CFrame, weapon)
	local scale = if weapon.TracerStyle == "Rail" or weapon.Projectile then 1.5 elseif weapon.TracerStyle == "Spray" then 0.7 else 1
	WeaponFX.MuzzleFlash(cframe, weapon.TracerColor, scale)
end

function EffectsController:Impact(position: Vector3, normal: Vector3, weapon)
	WeaponFX.Impact(position, normal, weapon.TracerColor, weapon.TracerStyle == "Rail")
end

function EffectsController:HitTarget(model: Model, position: Vector3, weapon)
	local shield = (model:GetAttribute("Shield") or 0) > 0
	WeaponFX.HitSpark(position, weapon.TracerColor, shield)
	WeaponFX.HitFlash(model, shield)
end

function EffectsController:SpawnProjectile(key: string, origin: Vector3, visualStart: Vector3, velocity: Vector3, weapon)
	WeaponFX.SpawnOrb(key, origin, visualStart, velocity, weapon)
end

function EffectsController:StartBeam(color: Color3)
	return WeaponFX.StartBeam(color)
end

--[[ Remote handlers ]]

local function shooterCharacter(shooterId: number): Model?
	for _, other in Players:GetPlayers() do
		if other.UserId == shooterId then
			return other.Character
		end
	end
	for _, model in RaycastUtil.GetContainer(RaycastUtil.Containers.Bots):GetChildren() do
		if model:GetAttribute("CombatantId") == shooterId then
			return model
		end
	end
	return nil
end

local function onShotReplicated(data)
	local weapon = WeaponConfig.Get(data.Weapon)
	if not weapon or typeof(data.Origin) ~= "Vector3" or type(data.Directions) ~= "table" then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - data.Origin).Magnitude > REPLICATED_SHOT_RANGE then
		return
	end
	local ignore: { Instance } = {}
	local shooter = shooterCharacter(data.Shooter)
	if shooter then
		table.insert(ignore, shooter)
	end
	-- Start the tracer at the shooter's gun if we can see it.
	local start = data.Origin
	local worldWeapon = shooter and shooter:FindFirstChild("WorldWeapon")
	if worldWeapon and worldWeapon:IsA("Model") then
		start = worldWeapon:GetPivot().Position
	end
	local params = RaycastUtil.CombatParams(ignore, nil, data.Shooter)
	for index, direction in data.Directions do
		if typeof(direction) == "Vector3" then
			local result = workspace:Raycast(data.Origin, direction * weapon.Range, params)
			local endPoint = if result then result.Position else data.Origin + direction * weapon.Range
			WeaponFX.Tracer(weapon.TracerStyle or "Bolt", start, endPoint, weapon.TracerColor)
			if result and (index == 1 or not FXUtil.Reduced()) then
				local model = RaycastUtil.FindTargetModel(result.Instance)
				if model then
					WeaponFX.HitSpark(result.Position, weapon.TracerColor, (model:GetAttribute("Shield") or 0) > 0)
				else
					WeaponFX.Impact(result.Position, result.Normal, weapon.TracerColor, weapon.TracerStyle == "Rail")
				end
			end
		end
	end
	if type(data.Chain) == "table" then
		local previous = nil
		for _, point in data.Chain do
			if typeof(point) == "Vector3" then
				if previous then
					WeaponFX.Lightning(previous, point, weapon.TracerColor)
				end
				previous = point
			end
		end
	end
	WeaponFX.MuzzleFlash(CFrame.lookAt(start, start + data.Directions[1]), weapon.TracerColor, 0.8)
	SoundController:PlayAt(weapon.Sounds.Fire, data.Origin, 0.08)
end

local function onProjectileImpact(data)
	WeaponFX.RemoveOrb(data.Key)
	local weapon = WeaponConfig.Get(data.Weapon)
	local color = if weapon then weapon.TracerColor else Color3.new(1, 0.4, 0.9)
	WeaponFX.Explosion(data.Position, color, data.Radius or 8)
	SoundController:PlayAt("Explosion", data.Position, 0.05)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local distance = (root.Position - data.Position).Magnitude
		if distance < 45 then
			CameraController:Shake(0.7 * (1 - distance / 45))
		end
	end
end

local function onElimination(data)
	if typeof(data.Character) == "Instance" and data.Character:IsA("Model") then
		WorldFX.Dissolve(data.Character, data.EffectColor or Color3.new(1, 1, 1), data.Rainbow == true)
	end
	if data.Killer and data.Killer.Id == player.UserId then
		ScreenFX:KillPop()
		ScreenFX:Pulse(Color3.fromRGB(255, 255, 255), 0.25, 0.3)
	end
end

local function onAbilityEffect(data)
	if data.Kind == "Reveal" then
		local color = AbilityConfig.Get("Pulse").Color
		WorldFX.Reveal(data.Targets or {}, data.Duration or 2, color)
		if typeof(data.Origin) == "Vector3" then
			WorldFX.PulseWave(data.Origin, data.Radius or 40, color)
		end
		SoundController:Play("Pulse")
		if data.Targets and #data.Targets > 0 then
			task.delay(0.3, function()
				SoundController:Play("PulseReveal")
			end)
		end
	elseif data.Kind == "Revealed" then
		ScreenFX:Pulse(AbilityConfig.Get("Pulse").Color, 0.5, 0.8)
		SoundController:Play("PulseReveal")
	elseif data.Kind == "DecoyPopped" and typeof(data.Position) == "Vector3" then
		WorldFX.DecoyPop(data.Position)
		SoundController:PlayAt("DecoyPop", data.Position)
	end
end

-- Other players' movement effects.
local function onMovementFx(data)
	local character = data.Character
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local color = teamColor(character:GetAttribute("Team"))
	if data.Kind == "Dash" then
		WorldFX.Dash(character, color)
		SoundController:PlayAt("Dash", root.Position, 0.05)
	elseif data.Kind == "Slide" then
		local stop = WorldFX.StartSlideSparks(character, color)
		task.delay(0.7, stop)
		SoundController:PlayAt("Slide", root.Position, 0.05)
	elseif data.Kind == "DoubleJump" then
		WorldFX.JumpRing(character, color)
		SoundController:PlayAt("DoubleJump", root.Position, 0.05)
	elseif data.Kind == "WallJump" then
		WorldFX.JumpRing(character, color)
		SoundController:PlayAt("WallJump", root.Position, 0.05)
	end
end

--[[ Per-character dressing: phase shimmer, spawn protection, arrival beam ]]

local function watchCharacter(character: Model)
	local isLocal = character == player.Character
	local sparkles: ParticleEmitter? = nil

	local function applyPhase()
		local phased = character:GetAttribute("Phased") == true
		if isLocal then
			ScreenFX:SetPhaseTint(phased, AbilityConfig.Get("Phase").Color)
			if not phased then
				SoundController:Play("PhaseEnd")
			end
			return
		end
		local transparency = if phased then AbilityConfig.Get("Phase").Transparency else 0
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.LocalTransparencyModifier = transparency
			end
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if phased and root and not sparkles then
			sparkles = FXUtil.AttachEmitter(root, {
				Color = AbilityConfig.Get("Phase").Color,
				Rate = 25,
				Speed = NumberRange.new(0.5, 2),
				Lifetime = NumberRange.new(0.4, 0.8),
				Spread = Vector2.new(180, 180),
				Size = NumberSequence.new(0.35, 0),
			})
		elseif not phased and sparkles then
			sparkles:Destroy()
			sparkles = nil
		end
	end
	character:GetAttributeChangedSignal("Phased"):Connect(applyPhase)

	local shield: Highlight? = nil
	local function applyProtection()
		local protected = character:GetAttribute("SpawnProtected") == true
		if protected and not shield then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.fromRGB(150, 230, 255)
			highlight.FillTransparency = 0.7
			highlight.OutlineTransparency = 0.3
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Adornee = character
			highlight.Parent = character
			shield = highlight
		elseif not protected and shield then
			shield:Destroy()
			shield = nil
			if isLocal then
				SoundController:Play("ProtectionEnd")
			end
		end
	end
	character:GetAttributeChangedSignal("SpawnProtected"):Connect(applyProtection)
	applyProtection()

	-- Arrival beam when a character appears in the arena (not for decoys).
	if CollectionService:HasTag(character, RaycastUtil.Tags.Decoy) then
		return
	end
	task.defer(function()
		local root = character:WaitForChild("HumanoidRootPart", 3)
		task.wait(0.15) -- let the server move it to its spawn point
		if root and root:IsA("BasePart") and (root.Position - MapConfig.LobbyOrigin).Magnitude > ARENA_DISTANCE then
			WorldFX.SpawnArrival(character, teamColor(character:GetAttribute("Team")))
			if isLocal then
				SoundController:Play("Respawn")
			else
				SoundController:PlayAt("Respawn", root.Position)
			end
		end
	end)
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

--[[ Lighting, atmosphere and ambience per location ]]

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

local function applyProperties(instance: Instance, properties)
	for property, value in properties do
		pcall(function()
			(instance :: any)[property] = value
		end)
	end
end

function EffectsController:ApplyLighting(preset)
	if not preset then
		return
	end
	for property, value in preset do
		if type(value) ~= "table" then
			pcall(function()
				(Lighting :: any)[property] = value
			end)
		end
	end
	applyProperties(ensure("Atmosphere", "VectorRushAtmosphere"), preset.Atmosphere or { Density = 0 })
	applyProperties(ensure("ColorCorrectionEffect", "VectorRushGrade"), preset.Grade or {})
	applyProperties(ensure("BloomEffect", "VectorRushBloom"), preset.Bloom or {})
	applyProperties(ensure("SunRaysEffect", "VectorRushSunRays"), preset.SunRays or { Intensity = 0 })
end

local function updateLighting()
	local matchState = ClientState.Get("MatchState")
	if ClientState.IsInMatch() and matchState and matchState.Map then
		local map = MapConfig.Get(matchState.Map)
		EffectsController:ApplyLighting(map and map.Lighting)
		SoundController:SetAmbient(map and map.Ambient)
	else
		EffectsController:ApplyLighting(MapConfig.LobbyLighting)
		SoundController:SetAmbient("AmbientLobby")
	end
end

function EffectsController:Init()
	FXUtil:Init()
	WeaponFX:Init()
	WorldFX:Init()
	ScreenFX:Init()
	MapAnimator:Init()
	ScreenFX:SetSoundPlayer(function(key)
		SoundController:Play(key)
	end)
	local bloom = ensure("BloomEffect", "VectorRushBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 22
	bloom.Threshold = 1.3
end

function EffectsController:Start()
	WorldFX:Start()
	ScreenFX:Start()
	MapAnimator:Start()

	Net.Event("Combat", "ShotReplicated").OnClientEvent:Connect(onShotReplicated)
	Net.Event("Combat", "ProjectileSpawned").OnClientEvent:Connect(function(data)
		local weapon = WeaponConfig.Get(data.Weapon)
		if weapon and weapon.Projectile then
			WeaponFX.SpawnOrb(data.Key, data.Origin, data.Origin, data.Velocity, weapon)
			SoundController:PlayAt(weapon.Sounds.Fire, data.Origin, 0.05)
		end
	end)
	Net.Event("Combat", "ProjectileImpact").OnClientEvent:Connect(onProjectileImpact)
	Net.Event("Combat", "Elimination").OnClientEvent:Connect(onElimination)
	Net.Event("Abilities", "AbilityEffect").OnClientEvent:Connect(onAbilityEffect)
	Net.Event("Movement", "MovementFx").OnClientEvent:Connect(onMovementFx)

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
