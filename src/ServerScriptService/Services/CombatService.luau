--[[
	CombatService
	Server-authoritative combat.

	Clients send RequestFire with: weapon id, shot sequence number, origin,
	aim direction, pellet directions and *claimed* hits. The server:
	  1. validates payload types
	  2. checks the shooter is alive, in an active match and owns the weapon
	  3. consumes ammo + checks fire rate via WeaponService
	  4. checks the origin is near the shooter's head
	  5. checks pellet directions are inside the weapon's max spread cone
	  6. for each claimed hit: target is a live enemy, the hit point lies on
	     the claimed ray, within range, near where the target actually was
	     recently (lag compensation history), and not behind world geometry
	  7. computes damage itself from WeaponConfig (falloff, headshot, charge)

	Damage is never accepted from a client. Shields absorb damage first and
	regenerate after a delay; health regenerates after a longer delay.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local MathUtil = require(Shared.Modules.MathUtil)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local CombatService = {}

CombatService.CombatantDied = Signal.new() -- (victim, killer?, info, assists)
CombatService.DamageDealt = Signal.new() -- (attacker?, victim, amount, info)
CombatService.ShotFired = Signal.new() -- (combatant, origin, direction)

local Services

-- Validation tuning.
local HISTORY_INTERVAL = 0.05
local HISTORY_DURATION = 1
local MAX_REWIND = 0.6 -- never rewind more than this (seconds)
local BASE_REWIND = 0.15
local HIT_POSITION_TOLERANCE = 5.5 -- studs between claimed hit and recorded root
local ORIGIN_TOLERANCE = 5
local ORIGIN_MAX_TOLERANCE = 18 -- covers dashing at high ping
local RAY_ANGLE_TOLERANCE = math.rad(3)
local RANGE_TOLERANCE = 5
local LOS_TOLERANCE = 1.5
local KNOCKOFF_CREDIT_WINDOW = 5 -- falls within this time of damage credit the attacker
local REGEN_INTERVAL = 0.2

type Snapshot = { Time: number, Position: Vector3 }
local history: { [number]: { Snapshot } } = {}

local function getPing(player: Player?): number
	if not player then
		return 0
	end
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and type(ping) == "number" then
		return math.clamp(ping, 0, 1)
	end
	return 0.1
end
CombatService.GetPing = getPing

local function recordHistory()
	local now = os.clock()
	for _, combatant in Services.CombatantService:GetInMatch() do
		if Services.CombatantService:IsAlive(combatant) then
			local list = history[combatant.Id]
			if not list then
				list = {}
				history[combatant.Id] = list
			end
			table.insert(list, { Time = now, Position = combatant.Root.Position })
			while list[1] and now - list[1].Time > HISTORY_DURATION do
				table.remove(list, 1)
			end
		else
			history[combatant.Id] = nil
		end
	end
end

-- True if `position` is within tolerance of where the target was during the
-- last `window` seconds (or is now).
function CombatService:WasNear(target, position: Vector3, window: number, tolerance: number): boolean
	if target.Root and (target.Root.Position - position).Magnitude <= tolerance then
		return true
	end
	local list = history[target.Id]
	if not list then
		return false
	end
	local cutoff = os.clock() - window
	for index = #list, 1, -1 do
		local snapshot = list[index]
		if snapshot.Time < cutoff then
			break
		end
		if (snapshot.Position - position).Magnitude <= tolerance then
			return true
		end
	end
	return false
end

local function damageFor(weapon, distance: number, headshot: boolean, chargeMultiplier: number): number
	local falloff = MathUtil.Falloff(distance, weapon.Falloff.Start, weapon.Falloff.End, weapon.Falloff.MinMultiplier)
	local damage = weapon.Damage * falloff * chargeMultiplier
	if headshot then
		damage *= weapon.HeadshotMultiplier
	end
	return damage
end
CombatService.DamageFor = damageFor

local function isVector(value: any): boolean
	return typeof(value) == "Vector3" and MathUtil.IsFiniteVector(value)
end

local function eliminationColor(killer)
	if killer and killer.Player then
		local data = Services.DataService:Get(killer.Player)
		if data then
			local item = CosmeticConfig.Get(data.Equipped.EliminationEffect)
			if item then
				return item.Color, item.Rainbow == true
			end
		end
	end
	return Color3.new(1, 1, 1), false
end

local function describe(combatant)
	if not combatant then
		return nil
	end
	return { Id = combatant.Id, Name = combatant.Name, Team = combatant.Team }
end

--[[ Damage & eliminations ]]

function CombatService:SetShield(combatant, value: number)
	combatant.Shield = math.clamp(value, 0, PlayerConfig.Health.MaxShield)
	if combatant.Character then
		combatant.Character:SetAttribute("Shield", math.floor(combatant.Shield + 0.5))
	end
end

-- Applies validated damage. Returns the damage actually dealt.
function CombatService:ApplyDamage(attacker, victim, amount: number, info)
	local CombatantService = Services.CombatantService
	if not CombatantService:IsAlive(victim) or not victim.InMatch then
		return 0
	end
	if attacker and attacker ~= victim and not CombatantService:AreEnemies(attacker, victim) then
		return 0
	end
	if not Services.MatchService:IsCombatActive() then
		return 0
	end
	local now = os.clock()
	if now < victim.SpawnProtectedUntil then
		if attacker and attacker.Player then
			Net.Event("Combat", "HitConfirm"):FireClient(attacker.Player, { Blocked = true, Position = info.Position })
		end
		return 0
	end

	amount = math.max(0, math.floor(amount + 0.5))
	if amount <= 0 then
		return 0
	end
	local humanoid = victim.Humanoid
	local shieldBefore = victim.Shield
	local absorbed = math.min(shieldBefore, amount)
	CombatService:SetShield(victim, shieldBefore - absorbed)
	local remaining = amount - absorbed
	if remaining > 0 then
		humanoid.Health = math.max(0, humanoid.Health - remaining)
	end
	victim.LastDamagedAt = now

	if attacker and attacker ~= victim then
		local entry = victim.DamageLog[attacker.Id]
		if entry then
			entry.Amount += amount
			entry.Time = now
		else
			victim.DamageLog[attacker.Id] = { Amount = amount, Time = now }
		end
		attacker.Stats.DamageDealt += amount
	end
	if victim.Root then
		Services.SpawnService:RecordCombat(victim.Root.Position)
	end

	local killed = humanoid.Health <= 0
	local shieldBroken = shieldBefore > 0 and victim.Shield <= 0
	if attacker and attacker.Player and attacker ~= victim then
		Net.Event("Combat", "HitConfirm"):FireClient(attacker.Player, {
			Damage = amount,
			Headshot = info.Headshot == true,
			Killed = killed,
			ShieldHit = absorbed > 0,
			ShieldBroken = shieldBroken,
			Position = info.Position,
		})
	end
	if victim.Player then
		local from = info.Origin
		if not from and attacker and attacker.Root then
			from = attacker.Root.Position
		end
		Net.Event("Combat", "DamageTaken"):FireClient(victim.Player, {
			From = from,
			Amount = amount,
			ShieldBroken = shieldBroken,
			Explosion = info.Explosion == true,
		})
	end
	CombatService.DamageDealt:Fire(attacker, victim, amount, info)

	if killed then
		CombatService:Eliminate(victim, attacker, info)
	end
	return amount
end

function CombatService:Eliminate(victim, killer, info)
	if not victim.Alive then
		return
	end
	victim.Alive = false
	local humanoid = victim.Humanoid
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
	local position = if victim.Root then victim.Root.Position else nil
	if killer == victim then
		killer = nil
	end

	victim.Stats.Deaths += 1
	victim.Stats.Streak = 0

	-- Assists: anyone else who damaged the victim recently.
	local assists = {}
	local now = os.clock()
	for attackerId, entry in victim.DamageLog do
		if (not killer or attackerId ~= killer.Id) and now - entry.Time <= MatchConfig.Score.AssistWindow then
			local helper = Services.CombatantService:Get(attackerId)
			if helper and helper.InMatch and Services.CombatantService:AreEnemies(helper, victim) then
				table.insert(assists, helper)
			end
		end
	end
	victim.DamageLog = {}

	if killer then
		killer.Stats.Kills += 1
		killer.Stats.Streak += 1
		killer.Stats.BestStreak = math.max(killer.Stats.BestStreak, killer.Stats.Streak)
		if info.Headshot then
			killer.Stats.Headshots += 1
		end
	end
	for _, helper in assists do
		helper.Stats.Assists += 1
	end
	if position then
		Services.SpawnService:RecordDeath(position)
	end

	local color, rainbow = eliminationColor(killer)
	local assistNames = {}
	for _, helper in assists do
		table.insert(assistNames, helper.Name)
	end
	-- Lobby deaths (reset button) don't belong in the kill feed.
	if victim.InMatch then
		Net.Event("Combat", "Elimination"):FireAllClients({
			Killer = describe(killer),
			Victim = describe(victim),
			Weapon = info.Weapon,
			Headshot = info.Headshot == true,
			Reason = info.Reason,
			Assists = assistNames,
			Streak = if killer then killer.Stats.Streak else 0,
			EffectColor = color,
			Rainbow = rainbow,
			Character = victim.Character,
		})
	end

	CombatService.CombatantDied:Fire(victim, killer, info, assists)
	if victim.InMatch then
		Services.MatchService:OnElimination(victim, killer, assists, info)
	end
end

-- Deaths not caused by a weapon (reset, falling). If an enemy damaged the
-- victim moments ago they get the credit ("knocked out of bounds").
function CombatService:HandleUnscoredDeath(victim, reason: string)
	if not victim.Alive then
		return
	end
	local killer = nil
	local latest = 0
	local now = os.clock()
	for attackerId, entry in victim.DamageLog do
		if now - entry.Time <= KNOCKOFF_CREDIT_WINDOW and entry.Time > latest then
			local attacker = Services.CombatantService:Get(attackerId)
			if attacker and attacker.InMatch then
				killer = attacker
				latest = entry.Time
			end
		end
	end
	CombatService:Eliminate(victim, killer, { Reason = reason, Weapon = nil, Headshot = false })
end

--[[ Shot processing ]]

local function replicateShot(shooter, weaponId: string, origin: Vector3, directions: { Vector3 }, chainTargets: { Vector3 }?)
	local remote = Net.Event("Combat", "ShotReplicated")
	local payload = {
		Shooter = shooter.Id,
		Weapon = weaponId,
		Origin = origin,
		Directions = directions,
		Chain = chainTargets,
	}
	for _, player in Players:GetPlayers() do
		if player ~= shooter.Player then
			remote:FireClient(player, payload)
		end
	end
	CombatService.ShotFired:Fire(shooter, origin, directions[1])
end

-- Arc weapons jump from the primary victim to nearby enemies (server decides).
local function applyChain(shooter, weapon, primaryVictim, baseDamage: number): { Vector3 }
	local chainPoints = {}
	local chain = weapon.Chain
	if not chain or not primaryVictim.Root then
		return chainPoints
	end
	local CombatantService = Services.CombatantService
	local from = primaryVictim.Root.Position
	local hitIds = { [primaryVictim.Id] = true }
	local params = RaycastUtil.WorldParams(shooter.Team, shooter.Id)
	for _ = 1, chain.MaxJumps do
		local best, bestDistance = nil, chain.Radius
		for _, other in CombatantService:GetInMatch() do
			if not hitIds[other.Id] and CombatantService:IsAlive(other) and CombatantService:AreEnemies(shooter, other) then
				local distance = (other.Root.Position - from).Magnitude
				if distance <= bestDistance and RaycastUtil.HasLineOfSight(from, other.Root.Position, params, LOS_TOLERANCE) then
					best, bestDistance = other, distance
				end
			end
		end
		if not best then
			break
		end
		hitIds[best.Id] = true
		table.insert(chainPoints, best.Root.Position)
		CombatService:ApplyDamage(shooter, best, baseDamage * chain.DamageMultiplier, {
			Weapon = weapon.Id,
			Headshot = false,
			Position = best.Root.Position,
			Origin = from,
		})
		from = best.Root.Position
	end
	return chainPoints
end

type HitResult = { Victim: any, Damage: number, Headshot: boolean, Position: Vector3 }

-- Validates one claimed hit. Returns (victim, headshot, distance) or nil.
local function validateHit(shooter, weapon, origin: Vector3, rayDirection: Vector3, claim, rewindWindow: number)
	local CombatantService = Services.CombatantService
	if type(claim) ~= "table" then
		return nil
	end
	local target, part, position = claim.Target, claim.Part, claim.Position
	if typeof(target) ~= "Instance" or typeof(part) ~= "Instance" or not isVector(position) then
		return nil
	end
	if not target:IsA("Model") or not part:IsA("BasePart") or not part:IsDescendantOf(target) then
		return nil
	end
	local toHit = position - origin
	local distance = toHit.Magnitude
	if distance > weapon.Range + RANGE_TOLERANCE then
		return nil, "Range"
	end
	-- The claimed point must lie on the ray the client says it fired.
	local allowedAngle = RAY_ANGLE_TOLERANCE + math.atan(3 / math.max(distance, 1))
	if MathUtil.AngleBetween(rayDirection, toHit) > allowedAngle then
		return nil, "Angle"
	end
	-- Shots through walls are rejected (could be latency, so not flagged).
	if not RaycastUtil.HasLineOfSight(origin, position, RaycastUtil.WorldParams(shooter.Team, shooter.Id), LOS_TOLERANCE) then
		return nil
	end

	if CollectionService:HasTag(target, RaycastUtil.Tags.Decoy) then
		return { Decoy = target }
	end

	local victim = CombatantService:GetFromInstance(target)
	if not victim or not CombatantService:IsAlive(victim) or not victim.InMatch then
		return nil
	end
	if not CombatantService:AreEnemies(shooter, victim) then
		return nil
	end
	if not CombatService:WasNear(victim, position, rewindWindow, HIT_POSITION_TOLERANCE) then
		return nil, "Position"
	end
	return { Victim = victim, Headshot = part.Name == "Head", Distance = distance, Position = position }
end

function CombatService:HandleFireRequest(player: Player, payload)
	local AntiCheat = Services.AntiCheatService
	if type(payload) ~= "table" then
		AntiCheat:Flag(player, "InvalidPayload", "fire payload")
		return
	end
	local weaponId, shot, origin, direction = payload.Weapon, payload.Shot, payload.Origin, payload.Direction
	if type(weaponId) ~= "string" or type(shot) ~= "number" or not isVector(origin) or not isVector(direction) then
		AntiCheat:Flag(player, "InvalidPayload", "fire fields")
		return
	end
	if direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit

	local combatant = Services.CombatantService:GetByPlayer(player)
	if not combatant or not Services.CombatantService:IsAlive(combatant) or not combatant.InMatch then
		return
	end
	if not Services.MatchService:IsCombatActive() then
		return
	end
	local weapon = WeaponConfig.Get(weaponId)
	if not weapon then
		AntiCheat:Flag(player, "InvalidWeapon", weaponId)
		return
	end

	local ok, reason = Services.WeaponService:TryConsumeShot(combatant, weaponId)
	if not ok then
		if reason == "FireRate" then
			AntiCheat:Flag(player, "FireRate", weaponId)
		elseif reason == "NotEquipped" then
			AntiCheat:Flag(player, "InvalidWeapon", "not equipped " .. weaponId)
		elseif reason == "NoAmmo" then
			AntiCheat:Flag(player, "InvalidAmmo", weaponId)
		end
		Services.WeaponService:SendState(combatant)
		return
	end

	-- Origin must be near the shooter's head (allowing for movement + ping).
	local ping = getPing(player)
	local head = Services.CombatantService:GetHeadPosition(combatant)
	local speed = combatant.Root.AssemblyLinearVelocity.Magnitude
	local originTolerance = math.min(ORIGIN_TOLERANCE + speed * (ping + 0.1), ORIGIN_MAX_TOLERANCE)
	if not head or (head - origin).Magnitude > originTolerance then
		AntiCheat:Flag(player, "InvalidOrigin", string.format("%.1f", head and (head - origin).Magnitude or -1))
		return
	end

	-- Firing ends spawn protection.
	if combatant.SpawnProtectedUntil > 0 then
		combatant.SpawnProtectedUntil = 0
		if combatant.Character then
			combatant.Character:SetAttribute("SpawnProtected", false)
		end
	end

	local chargeMultiplier = 1
	if weapon.FireMode == "Charge" then
		local charge = Services.WeaponService:ConsumeCharge(combatant, weapon)
		chargeMultiplier = WeaponConfig.GetChargeMultiplier(weapon, charge)
	end

	if weapon.ProjectileType == "Projectile" then
		Services.ProjectileService:Launch(combatant, weapon, origin, direction, shot)
		CombatService.ShotFired:Fire(combatant, origin, direction)
		return
	end

	-- Pellet directions must sit inside the weapon's maximum spread cone.
	local pellets = { direction }
	if weapon.Pellets > 1 then
		local claimed = payload.Pellets
		if type(claimed) ~= "table" or #claimed ~= weapon.Pellets then
			AntiCheat:Flag(player, "InvalidPayload", "pellet count")
			return
		end
		pellets = {}
		for index = 1, weapon.Pellets do
			local pellet = claimed[index]
			if not isVector(pellet) or pellet.Magnitude < 0.5 then
				AntiCheat:Flag(player, "InvalidPayload", "pellet")
				return
			end
			pellets[index] = pellet.Unit
		end
	end
	local maxSpread = math.rad(WeaponConfig.GetMaxSpreadDegrees(weapon))
	for _, pellet in pellets do
		if MathUtil.AngleBetween(pellet, direction) > maxSpread then
			AntiCheat:Flag(player, "InvalidHit", "spread")
			return
		end
	end

	-- Validate claimed hits; at most one hit per pellet.
	local rewindWindow = math.min(MAX_REWIND, BASE_REWIND + ping)
	local totals: { [any]: HitResult } = {}
	local usedPellets = {}
	local primaryVictim = nil
	local hits = payload.Hits
	if type(hits) == "table" then
		for index, claim in hits do
			if index > #pellets then
				break
			end
			local pelletIndex = if type(claim) == "table" and type(claim.Pellet) == "number" then math.floor(claim.Pellet) else 1
			if pellets[pelletIndex] and not usedPellets[pelletIndex] then
				usedPellets[pelletIndex] = true
				local result, failure = validateHit(combatant, weapon, origin, pellets[pelletIndex], claim, rewindWindow)
				if result and result.Decoy then
					Services.AbilityService:HitDecoy(result.Decoy, combatant)
				elseif result then
					local damage = damageFor(weapon, result.Distance, result.Headshot, chargeMultiplier)
					local total = totals[result.Victim]
					if total then
						total.Damage += damage
						total.Headshot = total.Headshot or result.Headshot
					else
						totals[result.Victim] = {
							Victim = result.Victim,
							Damage = damage,
							Headshot = result.Headshot,
							Position = result.Position,
						}
					end
					primaryVictim = primaryVictim or result.Victim
				elseif failure == "Angle" or failure == "Range" then
					AntiCheat:Flag(player, "InvalidHit", failure)
				end
			end
		end
	end

	local chainPoints = nil
	for victim, total in totals do
		CombatService:ApplyDamage(combatant, victim, total.Damage, {
			Weapon = weapon.Id,
			Headshot = total.Headshot,
			Position = total.Position,
			Origin = origin,
		})
	end
	if weapon.ProjectileType == "Chain" and primaryVictim then
		chainPoints = applyChain(combatant, weapon, primaryVictim, weapon.Damage)
	end
	replicateShot(combatant, weapon.Id, origin, pellets, chainPoints)
end

-- Server-side hitscan for bots: same ammo/fire-rate rules, server raycasts.
function CombatService:FireBotShot(bot, weaponId: string, origin: Vector3, direction: Vector3, rng: Random)
	if not Services.MatchService:IsCombatActive() then
		return false
	end
	local ok = Services.WeaponService:TryConsumeShot(bot, weaponId)
	if not ok then
		return false
	end
	local weapon = WeaponConfig.Get(weaponId)
	if weapon.ProjectileType == "Projectile" then
		Services.ProjectileService:Launch(bot, weapon, origin, direction, 0)
		CombatService.ShotFired:Fire(bot, origin, direction)
		return true
	end
	local chargeMultiplier = if weapon.Charge then weapon.Charge.MaxMultiplier * 0.8 else 1
	local params = RaycastUtil.CombatParams({ bot.Character }, bot.Team, bot.Id)
	local pellets = {}
	local totals = {}
	local primaryVictim = nil
	for index = 1, weapon.Pellets do
		local pellet = MathUtil.RandomInCone(direction, math.rad(weapon.Spread.Hip), rng)
		pellets[index] = pellet
		local result = workspace:Raycast(origin, pellet * weapon.Range, params)
		if result then
			local model = RaycastUtil.FindTargetModel(result.Instance)
			if model and CollectionService:HasTag(model, RaycastUtil.Tags.Decoy) then
				Services.AbilityService:HitDecoy(model, bot)
			elseif model then
				local victim = Services.CombatantService:GetFromInstance(model)
				if victim and Services.CombatantService:AreEnemies(bot, victim) then
					local headshot = result.Instance.Name == "Head"
					local damage = damageFor(weapon, result.Distance, headshot, chargeMultiplier)
					local total = totals[victim]
					if total then
						total.Damage += damage
					else
						totals[victim] = { Damage = damage, Headshot = headshot, Position = result.Position }
					end
					primaryVictim = primaryVictim or victim
				end
			end
		end
	end
	for victim, total in totals do
		CombatService:ApplyDamage(bot, victim, total.Damage, {
			Weapon = weapon.Id,
			Headshot = total.Headshot,
			Position = total.Position,
			Origin = origin,
		})
	end
	local chainPoints = nil
	if weapon.ProjectileType == "Chain" and primaryVictim then
		chainPoints = applyChain(bot, weapon, primaryVictim, weapon.Damage)
	end
	replicateShot(bot, weapon.Id, origin, pellets, chainPoints)
	return true
end

-- Shield + health regeneration.
local function regenTick(deltaTime: number)
	local now = os.clock()
	local health = PlayerConfig.Health
	for _, combatant in Services.CombatantService:GetAll() do
		if combatant.Alive and combatant.Humanoid then
			local idle = now - combatant.LastDamagedAt
			if idle >= health.ShieldRegenDelay and combatant.Shield < health.MaxShield then
				CombatService:SetShield(combatant, combatant.Shield + health.ShieldRegenRate * deltaTime)
			end
			local humanoid = combatant.Humanoid
			if idle >= health.HealthRegenDelay and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + health.HealthRegenRate * deltaTime)
			end
		end
	end
end

function CombatService:Init(services)
	Services = services
	Net.OnServerEvent("Combat", "RequestFire", function(player, payload)
		CombatService:HandleFireRequest(player, payload)
	end, { Rate = 30, Burst = 40 })
end

function CombatService:Start()
	local historyElapsed, regenElapsed = 0, 0
	RunService.Heartbeat:Connect(function(deltaTime)
		historyElapsed += deltaTime
		regenElapsed += deltaTime
		if historyElapsed >= HISTORY_INTERVAL then
			historyElapsed = 0
			recordHistory()
		end
		if regenElapsed >= REGEN_INTERVAL then
			regenTick(regenElapsed)
			regenElapsed = 0
		end
	end)
	Services.CombatantService.Removed:Connect(function(combatant)
		history[combatant.Id] = nil
	end)
end

return CombatService
