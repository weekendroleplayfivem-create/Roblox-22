--[[
	ProjectileService
	Server-simulated projectiles (Plasma Launcher). The server owns the
	simulation: position, gravity, collision and splash damage are all
	computed here. Clients only render.

	* Shooter's client renders its own projectile immediately (prediction).
	* Everyone else is told via ProjectileSpawned.
	* Impacts are broadcast via ProjectileImpact (all clients remove the
	  matching visual and show the explosion).
	Projectiles are pure data (no Instances) for performance.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local RaycastUtil = require(Shared.Modules.RaycastUtil)

local ProjectileService = {}

local Services

type Projectile = {
	Key: string,
	Owner: any,
	Weapon: any,
	Position: Vector3,
	Velocity: Vector3,
	Expires: number,
}

local active: { Projectile } = {}
local MAX_ACTIVE = 200

function ProjectileService:Init(services)
	Services = services
end

function ProjectileService:Launch(owner, weapon, origin: Vector3, direction: Vector3, shotId: number)
	if #active >= MAX_ACTIVE then
		return
	end
	local config = weapon.Projectile
	local projectile: Projectile = {
		Key = tostring(owner.Id) .. "_" .. tostring(shotId),
		Owner = owner,
		Weapon = weapon,
		Position = origin,
		Velocity = direction.Unit * config.Speed,
		Expires = os.clock() + config.Lifetime,
	}
	table.insert(active, projectile)

	local remote = Net.Event("Combat", "ProjectileSpawned")
	local payload = {
		Key = projectile.Key,
		Owner = owner.Id,
		Weapon = weapon.Id,
		Origin = origin,
		Velocity = projectile.Velocity,
	}
	for _, player in Players:GetPlayers() do
		if player ~= owner.Player then
			remote:FireClient(player, payload)
		end
	end
end

local function explode(projectile: Projectile, position: Vector3, directVictim)
	local CombatantService = Services.CombatantService
	local weapon = projectile.Weapon
	local config = weapon.Projectile
	local owner = projectile.Owner
	Net.Event("Combat", "ProjectileImpact"):FireAllClients({
		Key = projectile.Key,
		Position = position,
		Weapon = weapon.Id,
		Radius = config.SplashRadius,
	})

	-- Owner may have left; damage still requires a registered combatant.
	if not CombatantService:Get(owner.Id) then
		return
	end
	local params = RaycastUtil.WorldParams(owner.Team, owner.Id)
	for _, victim in CombatantService:GetInMatch() do
		if CombatantService:IsAlive(victim) and CombatantService:AreEnemies(owner, victim) then
			local target = victim.Root.Position
			local distance = (target - position).Magnitude
			local damage = 0
			if victim == directVictim then
				damage += weapon.Damage
			end
			if distance <= config.SplashRadius and RaycastUtil.HasLineOfSight(position, target, params, 2) then
				local alpha = distance / config.SplashRadius
				local multiplier = 1 - alpha * (1 - config.MinSplashMultiplier)
				damage += config.SplashDamage * multiplier
			end
			if damage > 0 then
				Services.CombatService:ApplyDamage(owner, victim, damage, {
					Weapon = weapon.Id,
					Headshot = false,
					Position = target,
					Origin = position,
					Explosion = true,
				})
			end
		end
	end
end

local function step(deltaTime: number)
	local now = os.clock()
	for index = #active, 1, -1 do
		local projectile = active[index]
		local config = projectile.Weapon.Projectile
		local velocity = projectile.Velocity - Vector3.new(0, config.Gravity * deltaTime, 0)
		local displacement = velocity * deltaTime
		local ignore = {}
		if projectile.Owner.Character then
			table.insert(ignore, projectile.Owner.Character)
		end
		local params = RaycastUtil.CombatParams(ignore, projectile.Owner.Team, projectile.Owner.Id)
		local result = workspace:Raycast(projectile.Position, displacement, params)
		if result then
			table.remove(active, index)
			local model = RaycastUtil.FindTargetModel(result.Instance)
			local directVictim = nil
			if model and CollectionService:HasTag(model, RaycastUtil.Tags.Decoy) then
				Services.AbilityService:HitDecoy(model, projectile.Owner)
			elseif model then
				directVictim = Services.CombatantService:GetFromInstance(model)
			end
			explode(projectile, result.Position + result.Normal * 0.5, directVictim)
		elseif now >= projectile.Expires then
			table.remove(active, index)
			explode(projectile, projectile.Position, nil)
		else
			projectile.Position += displacement
			projectile.Velocity = velocity
		end
	end
end

function ProjectileService:ClearAll()
	table.clear(active)
end

function ProjectileService:Start()
	RunService.Heartbeat:Connect(function(deltaTime)
		if #active > 0 then
			step(deltaTime)
		end
	end)
end

return ProjectileService
