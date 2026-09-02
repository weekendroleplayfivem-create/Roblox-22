--!nonstrict
--[[
	CombatService.luau
	Server authority for damage.

	The client reports a shot; this service decides whether it happened. Checks,
	in the order they run (cheapest and most decisive first):

		1. Is the shooter alive, and is the weapon actually in their loadout?
		2. Rate limit + fire-rate audit - you cannot out-shoot your own RPM.
		3. Ammo - the server keeps its own magazine count.
		4. Origin sanity - the reported muzzle must be near the shooter's head.
		5. Per-hit: the victim must be alive, on the other team, and have actually
		   been near the reported hit point WITHIN the rewind window.
		6. Line of sight from origin to the rewound hit position.

	Anything that fails is dropped silently for that shot (never kicks: a
	misprediction on a bad connection is not cheating, and false-positive
	punishment is worse than a rare bad hit).

	Damage itself comes from the SHARED DamageMath module, so the number the
	client predicted and the number the server applies come from one formula.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local WeaponConfig = require(Root.Config.WeaponConfig)
local CombatConfig = require(Root.Config.CombatConfig)
local AbilityConfig = require(Root.Config.AbilityConfig)
local DamageMath = require(Root.Shared.DamageMath)
local Signal = require(Root.Util.Signal)
local Net = require(Root.Util.Net)

local CombatService = {}
CombatService.__index = CombatService

local HISTORY_INTERVAL = 0.05

function CombatService.new(services)
	local self = setmetatable({}, CombatService)

	self.services = services
	self.history = {} :: { [Player]: { { t: number, position: Vector3, head: Vector3 } } }
	self.fireTimes = {} :: { [Player]: { last: number, count: number, windowStart: number } }

	self.PlayerKilled = Signal.new()
	self.DamageDealt = Signal.new()

	self._fireLimiter = Net.RateLimiter.new(40, 1)
	self._reloadLimiter = Net.RateLimiter.new(8, 1)

	return self
end

function CombatService:Start()
	Net.onServer("FireWeapon", function(player, payload)
		if not self._fireLimiter:Check(player) then
			return
		end
		local ok, err = pcall(self._handleFire, self, player, payload)
		if not ok then
			warn(`[Combat] fire error: {err}`)
		end
	end)

	Net.onServer("MeleeSwing", function(player, payload)
		if not self._fireLimiter:Check(player) then
			return
		end
		pcall(self._handleMelee, self, player, payload)
	end)

	Net.onServer("RequestReload", function(player, slot)
		if self._reloadLimiter:Check(player) then
			self:_handleReload(player, slot)
		end
	end)

	Net.onServer("CancelReload", function(player)
		local state = self.services.Player:GetState(player)
		if state then
			state.reloadingSlot = nil
			state.reloadEndsAt = nil
			state.reloadToken = (state.reloadToken or 0) + 1
		end
	end)

	Net.onServer("SwitchWeapon", function(player, slot)
		local state = self.services.Player:GetState(player)
		if state and state.ammo[slot] then
			state.currentSlot = slot
			state.reloadingSlot = nil
		end
	end)

	-- Position history for lag compensation, plus health regen.
	task.spawn(function()
		while true do
			self:_recordHistory()
			task.wait(HISTORY_INTERVAL)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		self:_updateRegen(dt)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.history[player] = nil
		self.fireTimes[player] = nil
		self._fireLimiter:Clear(player)
		self._reloadLimiter:Clear(player)
	end)

	return self
end

----------------------------------------------------------------------
-- Lag compensation
----------------------------------------------------------------------

function CombatService:_recordHistory()
	local now = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local head = character and character:FindFirstChild("Head")
		if root then
			local list = self.history[player]
			if not list then
				list = {}
				self.history[player] = list
			end
			table.insert(list, {
				t = now,
				position = root.Position,
				head = head and head.Position or root.Position + Vector3.new(0, 1.5, 0),
			})

			-- Trim anything older than the rewind window; memory is bounded by
			-- (window / interval) samples per player, ~5 entries.
			local cutoff = now - CombatConfig.HitRegistration.MaxRewindTime
			while #list > 1 and list[1].t < cutoff do
				table.remove(list, 1)
			end
		end
	end
end

--[[ Where the victim was at `atTime`, interpolated between samples. ]]
function CombatService:_rewind(player: Player, atTime: number): Vector3?
	local list = self.history[player]
	if not list or #list == 0 then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root and root.Position or nil
	end

	if atTime >= list[#list].t then
		return list[#list].position
	end
	if atTime <= list[1].t then
		return list[1].position
	end

	for index = 1, #list - 1 do
		local a, b = list[index], list[index + 1]
		if atTime >= a.t and atTime <= b.t then
			local alpha = (atTime - a.t) / math.max(b.t - a.t, 1e-4)
			return a.position:Lerp(b.position, alpha)
		end
	end
	return list[#list].position
end

----------------------------------------------------------------------
-- Firing
----------------------------------------------------------------------

function CombatService:_validateShooter(player: Player, payload)
	local playerService = self.services.Player
	if not playerService:IsAlive(player) then
		return nil
	end
	if type(payload) ~= "table" or type(payload.hits) ~= "table" then
		return nil
	end

	local state = playerService:GetState(player)
	local slot = payload.slot
	local weaponId = state.loadout[slot]
	if not weaponId or weaponId ~= payload.weapon then
		return nil -- the client is claiming a weapon it does not have equipped
	end

	local definition = WeaponConfig.get(weaponId)
	if not definition then
		return nil
	end

	if state.restrictedTo and not table.find(state.restrictedTo, weaponId) then
		return nil -- mode restriction (e.g. carrying the core)
	end

	-- Fire-rate audit. We allow a small overshoot for jitter, then simply stop
	-- accepting shots: no punishment, no false positives, no free damage.
	local now = os.clock()
	local timing = self.fireTimes[player]
	if not timing then
		timing = { last = 0, count = 0, windowStart = now }
		self.fireTimes[player] = timing
	end

	local interval = WeaponConfig.fireInterval(definition)
	local minimum = interval / CombatConfig.HitRegistration.MaxShotsPerSecondFactor
	if now - timing.last < minimum then
		return nil
	end
	timing.last = now

	local ammo = state.ammo[slot]
	if definition.FireMode ~= "Melee" then
		if not ammo or ammo.mag <= 0 then
			return nil
		end
		ammo.mag -= 1
	end

	-- Origin sanity: the muzzle must be roughly where the shooter's head is.
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and payload.origin then
		local distance = (payload.origin - head.Position).Magnitude
		if distance > CombatConfig.HitRegistration.MuzzleOriginTolerance then
			return nil
		end
	end

	return definition, state, ammo
end

function CombatService:_handleFire(player: Player, payload)
	local definition, state, ammo = self:_validateShooter(player, payload)
	if not definition then
		return
	end

	self.services.Player:ClearSpawnProtection(player)

	local shooterTeam = self.services.Player:GetTeamKey(player)
	local shotTime = math.min(payload.t or workspace:GetServerTimeNow(), workspace:GetServerTimeNow())
	local counted = {} :: { [Player]: { damage: number, headshot: boolean, position: Vector3 } }

	for _, hit in payload.hits do
		local victim, zone, distance = self:_resolveHit(player, hit, shotTime, shooterTeam, definition)
		if victim then
			local damage = DamageMath.compute(definition, {
				distance = distance,
				zone = zone,
				wallbang = hit.wallbang == true,
			})

			local entry = counted[victim]
			if entry then
				entry.damage += damage
				entry.headshot = entry.headshot or zone == "Head"
			else
				counted[victim] = { damage = damage, headshot = zone == "Head", position = hit.position }
			end
		end
	end

	for victim, entry in counted do
		self:ApplyDamage(victim, player, entry.damage, {
			headshot = entry.headshot,
			weapon = definition.Id,
			position = entry.position,
		})
	end

	-- Cosmetic replication for everyone else (the shooter already drew its own).
	Net.toOtherClients("EffectBroadcast", player, "Shot", {
		weapon = definition.Id,
		origin = payload.origin,
		direction = payload.direction,
		hit = payload.hits[1] and payload.hits[1].position or nil,
	})

	if ammo then
		Net.toClient("WeaponState", player, {
			slot = payload.slot,
			mag = ammo.mag,
			reserve = ammo.reserve,
		})
	end
end

--[[ Validates one reported hit. Returns victim, zone and distance, or nil. ]]
function CombatService:_resolveHit(shooter: Player, hit, shotTime: number, shooterTeam: string, definition)
	if typeof(hit.part) ~= "Instance" or typeof(hit.position) ~= "Vector3" then
		return nil
	end

	local character = hit.part:FindFirstAncestorOfClass("Model")
	local victim = character and Players:GetPlayerFromCharacter(character)
	if not victim or victim == shooter then
		return nil
	end
	if not self.services.Player:IsAlive(victim) then
		return nil
	end
	if self.services.Player:GetTeamKey(victim) == shooterTeam and not self.services.Match:IsFriendlyFireEnabled() then
		return nil
	end
	if self.services.Player:IsSpawnProtected(victim) then
		return nil
	end

	-- Rewind: was the victim actually near the reported hit point at shot time?
	local rewound = self:_rewind(victim, shotTime)
	if rewound then
		local offset = (hit.position - rewound).Magnitude
		if offset > CombatConfig.HitRegistration.PositionTolerance then
			return nil
		end
	end

	local shooterCharacter = shooter.Character
	local head = shooterCharacter and shooterCharacter:FindFirstChild("Head")
	local origin = head and head.Position or hit.position
	local distance = (hit.position - origin).Magnitude
	if distance > math.min(definition.Range, CombatConfig.HitRegistration.MaxShotDistance) then
		return nil
	end

	-- Line of sight. Skipped for wallbangs, which are *defined* by shooting
	-- through something.
	if not hit.wallbang then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { shooterCharacter, character, workspace:FindFirstChild("HyperBlastFx") }
		local blocked = workspace:Raycast(origin, (hit.position - origin) * 0.98, params)
		if blocked then
			return nil
		end
	end

	return victim, DamageMath.zoneForPart(hit.part.Name), distance
end

function CombatService:_handleMelee(player: Player, payload)
	local playerService = self.services.Player
	if not playerService:IsAlive(player) or type(payload) ~= "table" then
		return
	end

	local state = playerService:GetState(player)
	local definition = WeaponConfig.get(state.loadout.Melee)
	if not definition then
		return
	end

	local now = os.clock()
	if state.lastMeleeAt and now - state.lastMeleeAt < WeaponConfig.fireInterval(definition) then
		return
	end
	state.lastMeleeAt = now

	local shooterTeam = playerService:GetTeamKey(player)
	for _, hit in payload.hits or {} do
		local victim, zone, distance = self:_resolveHit(
			player,
			hit,
			workspace:GetServerTimeNow(),
			shooterTeam,
			definition
		)
		if victim and distance <= definition.Range + 2 then
			-- Backstab: the victim's back is turned. Rewards the flank route the
			-- arena's tunnels exist to create.
			local victimRoot = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
			local attackerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local backstab = false
			if victimRoot and attackerRoot then
				local toAttacker = (attackerRoot.Position - victimRoot.Position)
				backstab = victimRoot.CFrame.LookVector:Dot(toAttacker.Unit) < -0.35
			end

			local damage = DamageMath.compute(definition, {
				distance = distance,
				zone = zone,
				backstab = backstab,
			})
			self:ApplyDamage(victim, player, damage, {
				headshot = false,
				weapon = definition.Id,
				position = hit.position,
				backstab = backstab,
			})
		end
	end
end

function CombatService:_handleReload(player: Player, slot: string)
	local state = self.services.Player:GetState(player)
	if not state or not state.ammo[slot] then
		return
	end

	local definition = WeaponConfig.get(state.loadout[slot])
	local ammo = state.ammo[slot]
	if not definition or ammo.mag >= definition.MagSize or ammo.reserve <= 0 then
		return
	end

	local empty = ammo.mag <= 0
	local duration = empty and definition.EmptyReloadTime or definition.ReloadTime
	if self.services.Ability:IsOverdriveActive(player) then
		duration /= AbilityConfig.get("Overdrive").ReloadMultiplier
	end

	state.reloadingSlot = slot
	state.reloadEndsAt = os.clock() + duration
	state.reloadToken = (state.reloadToken or 0) + 1
	local token = state.reloadToken

	task.delay(duration, function()
		-- A token, not a timestamp: only the reload that started this timer may
		-- finish it, so a cancel-then-restart can never double-fill a magazine.
		if state.reloadToken ~= token or state.reloadingSlot ~= slot then
			return
		end
		local needed = definition.MagSize - ammo.mag
		local taken = math.min(needed, ammo.reserve)
		ammo.mag += taken
		ammo.reserve -= taken
		state.reloadingSlot = nil

		Net.toClient("WeaponState", player, {
			slot = slot,
			mag = ammo.mag,
			reserve = ammo.reserve,
			reloading = false,
		})
	end)
end

----------------------------------------------------------------------
-- Damage / elimination
----------------------------------------------------------------------

function CombatService:ApplyDamage(victim: Player, attacker: Player?, damage: number, info)
	local playerService = self.services.Player
	if not playerService:IsAlive(victim) then
		return
	end

	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local victimState = playerService:GetState(victim)
	victimState.lastDamageAt = os.clock()

	if attacker then
		local log = victimState.damageLog[attacker] or { damage = 0, at = 0 }
		log.damage += damage
		log.at = os.clock()
		victimState.damageLog[attacker] = log
	end

	humanoid:TakeDamage(damage)
	local killed = humanoid.Health <= 0

	if attacker then
		Net.toClient("HitConfirm", attacker, {
			damage = damage,
			headshot = info.headshot == true,
			killed = killed,
			position = info.position,
		})
		self.DamageDealt:Fire(attacker, victim, damage, info)
	end

	local attackerRoot = attacker
		and attacker.Character
		and attacker.Character:FindFirstChild("HumanoidRootPart")
	Net.toClient("DamageTaken", victim, {
		damage = damage,
		from = attackerRoot and attackerRoot.Position or info.position,
	})

	if killed then
		self:_onEliminated(victim, attacker, info)
	end
end

function CombatService:_onEliminated(victim: Player, killer: Player?, info)
	local playerService = self.services.Player
	local victimState = playerService:GetState(victim)

	local character = victim.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = root and root.Position or info.position

	-- Elimination burst, skinned to the weapon that got the kill.
	Net.toAllClients("EffectBroadcast", "Elimination", {
		position = position,
		weapon = info.weapon,
	})

	if killer and killer ~= victim then
		playerService:AddKill(killer)
		playerService:AddScore(killer, CombatConfig.Score.Kill + (info.headshot and CombatConfig.Score.Headshot or 0))

		-- Assists: anyone who did meaningful damage inside the window.
		for other, log in victimState.damageLog do
			if
				other ~= killer
				and other.Parent
				and log.damage >= CombatConfig.Score.AssistDamageThreshold
				and os.clock() - log.at <= CombatConfig.Score.AssistWindow
			then
				playerService:AddScore(other, CombatConfig.Score.Assist)
				local otherState = playerService:GetState(other)
				if otherState then
					otherState.assists += 1
				end
			end
		end
	end

	Net.toAllClients("KillFeed", {
		killer = killer and killer.Name or "THE ARENA",
		victim = victim.Name,
		weapon = info.weapon and (WeaponConfig.get(info.weapon) or {}).DisplayName or "",
		headshot = info.headshot == true,
	})

	Net.toClient("PlayerEliminated", victim, {
		killer = killer and killer.Name or nil,
		weapon = info.weapon,
		respawnIn = self.services.Match:GetRespawnDelay(),
	})

	self.PlayerKilled:Fire(victim, killer, info)
end

----------------------------------------------------------------------
-- Regen
----------------------------------------------------------------------

function CombatService:_updateRegen(dt: number)
	local playerService = self.services.Player
	for _, player in Players:GetPlayers() do
		local state = playerService:GetState(player)
		if state and state.alive then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				if os.clock() - state.lastDamageAt >= CombatConfig.Health.RegenDelay then
					humanoid.Health = math.min(
						humanoid.MaxHealth,
						humanoid.Health + CombatConfig.Health.RegenRate * dt
					)
				end
			end
		end
	end
end

return CombatService
