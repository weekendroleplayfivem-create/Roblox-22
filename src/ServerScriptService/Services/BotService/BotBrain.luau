--[[
	BotBrain
	State machine for one practice bot: Patrol, Investigate, Chase, Engage
	(shoot + strafe) and Retreat. Runs at BotConfig.ThinkRate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtil = require(Shared.Modules.MathUtil)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local BotConfig = require(Shared.Config.BotConfig)

local BotBrain = {}
BotBrain.__index = BotBrain

local WAYPOINT_REACHED = 3.5
local STUCK_TIME = 1.5
local PREFERRED_RANGE_FRACTION = 0.45
local MAX_PREFERRED_RANGE = 70
local MIN_PREFERRED_RANGE = 12
local RETREAT_TIME = 2.5
local DIRECT_MOVE_DISTANCE = 25
local EDGE_PROBE_DISTANCE = 3
local EDGE_PROBE_DEPTH = 12

function BotBrain.new(combatant, settings, services)
	return setmetatable({
		Combatant = combatant,
		Settings = settings,
		Services = services,
		Rng = Random.new(),
		State = "Patrol",
		Target = nil, -- combatant or decoy model
		TargetIsDecoy = false,
		LastSeenPosition = nil :: Vector3?,
		LastSeenTime = 0,
		ReactionReadyAt = 0,
		NextFireAt = 0,
		StrafeDirection = 1,
		StrafeUntil = 0,
		RetreatUntil = 0,
		Noise = nil :: Vector3?,
		NoiseTime = 0,
		Goal = nil :: Vector3?,
		Waypoints = nil,
		WaypointIndex = 1,
		LastPathTime = 0,
		PathPending = false,
		PathFailed = false,
		AimDirection = nil :: Vector3?,
		AimErrorAxis = nil :: Vector3?,
		AcquiredAt = 0,
		TargetHistory = {},
		AimAtHead = false,
		BurstLeft = 0,
		BurstPauseUntil = 0,
		PatrolGoal = nil :: Vector3?,
		LastPosition = nil :: Vector3?,
		StuckSince = nil :: number?,
		Align = nil :: AlignOrientation?,
		Path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5.5, AgentCanJump = true }),
	}, BotBrain)
end

function BotBrain:OnSpawned(character: Model)
	self.State = "Patrol"
	self.Target = nil
	self.AimDirection = nil
	self.TargetHistory = {}
	self.Goal = nil
	self.Waypoints = nil
	self.Noise = nil
	self.StuckSince = nil
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		-- Smoothly faces targets while strafing (AutoRotate would face movement).
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.Responsiveness = 25
		align.MaxTorque = math.huge
		align.Enabled = false
		align.Parent = root
		self.Align = align
	end
end

function BotBrain:HearNoise(position: Vector3)
	self.Noise = position
	self.NoiseTime = os.clock()
end

function BotBrain:OnDamaged(attacker)
	if attacker.Root then
		self:HearNoise(attacker.Root.Position)
	end
end

function BotBrain:Destroy()
	self.Combatant = nil
end

local function headOf(model: Model): Vector3?
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 1.5, 0)
	end
	return nil
end

-- Finds the closest enemy (or enemy decoy) this bot can actually see.
function BotBrain:FindVisibleTarget(eye: Vector3, look: Vector3)
	local CombatantService = self.Services.CombatantService
	local bot = self.Combatant
	local settings = self.Settings
	local cosHalfFov = math.cos(math.rad(settings.FieldOfView / 2))
	local params = RaycastUtil.WorldParams(bot.Team, bot.Id)
	local best, bestDistance, bestIsDecoy = nil, settings.ViewDistance, false

	local function consider(model: Model, candidate, isDecoy: boolean)
		local head = headOf(model)
		if not head then
			return
		end
		local offset = head - eye
		local distance = offset.Magnitude
		if distance > bestDistance then
			return
		end
		local inCone = distance < 10 or look:Dot(offset.Unit) >= cosHalfFov
		if inCone and RaycastUtil.HasLineOfSight(eye, head, params, 1) then
			best, bestDistance, bestIsDecoy = candidate, distance, isDecoy
		end
	end

	for _, other in CombatantService:GetInMatch() do
		if CombatantService:IsAlive(other) and CombatantService:AreEnemies(bot, other) then
			-- Phased enemies are harder to notice at range.
			local character = other.Character
			if not (character:GetAttribute("Phased") and (other.Root.Position - eye).Magnitude > 30) then
				consider(character, other, false)
			end
		end
	end
	for _, decoy in CollectionService:GetTagged(RaycastUtil.Tags.Decoy) do
		local ownerId = decoy:GetAttribute("OwnerId")
		local owner = CombatantService:Get(ownerId)
		if owner and CombatantService:AreEnemies(bot, owner) and decoy:IsA("Model") then
			consider(decoy, decoy, true)
		end
	end
	return best, bestIsDecoy
end

function BotBrain:TargetModel(): Model?
	if not self.Target then
		return nil
	end
	if self.TargetIsDecoy then
		return if self.Target.Parent then self.Target else nil
	end
	return self.Target.Character
end

function BotBrain:MoveToGoal(goal: Vector3, now: number)
	local bot = self.Combatant
	local humanoid = bot.Humanoid
	local root = bot.Root
	local goalChanged = not self.Goal or (self.Goal - goal).Magnitude > 8
	if goalChanged or (now - self.LastPathTime > BotConfig.RepathInterval and not self.PathPending) then
		self.Goal = goal
		self.LastPathTime = now
		if not self.PathPending then
			self.PathPending = true
			local start = root.Position
			task.spawn(function()
				local ok = pcall(function()
					self.Path:ComputeAsync(start, goal)
				end)
				self.PathPending = false
				if ok and self.Path.Status == Enum.PathStatus.Success then
					self.Waypoints = self.Path:GetWaypoints()
					self.WaypointIndex = math.min(2, #self.Waypoints)
					self.PathFailed = false
				else
					self.Waypoints = nil
					self.PathFailed = true
				end
			end)
		end
	end

	local waypoints = self.Waypoints
	if waypoints and waypoints[self.WaypointIndex] then
		local waypoint = waypoints[self.WaypointIndex]
		if (MathUtil.Flatten(waypoint.Position - root.Position)).Magnitude < WAYPOINT_REACHED then
			self.WaypointIndex += 1
			waypoint = waypoints[self.WaypointIndex]
		end
		if waypoint then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoint.Position)
			return
		end
	end
	-- No path (e.g. across a jump gap): only walk straight there if it's close
	-- and safe, otherwise pick a different patrol goal.
	if self.PathFailed and (goal - root.Position).Magnitude > DIRECT_MOVE_DISTANCE then
		humanoid:Move(Vector3.zero)
		self.PatrolGoal = nil
		self.Noise = nil
		return
	end
	humanoid:MoveTo(goal)
end

-- Returns `direction` if walking that way keeps the bot on solid ground,
-- otherwise the reverse (or zero). Prevents strafing off ledges.
function BotBrain:SafeDirection(direction: Vector3): Vector3
	if direction.Magnitude < 0.01 then
		return direction
	end
	local root = self.Combatant.Root
	local params = RaycastUtil.WorldParams()
	local function hasGround(dir: Vector3): boolean
		local probe = root.Position + dir.Unit * EDGE_PROBE_DISTANCE
		return workspace:Raycast(probe, Vector3.new(0, -EDGE_PROBE_DEPTH, 0), params) ~= nil
	end
	if hasGround(direction) then
		return direction
	end
	if hasGround(-direction) then
		self.StrafeDirection = -self.StrafeDirection
		return -direction
	end
	return Vector3.zero
end

function BotBrain:PickPatrolGoal(): Vector3?
	local arena = self.Services.MapService:GetArena()
	if not arena or #arena.BotNodes == 0 then
		return nil
	end
	return arena.BotNodes[self.Rng:NextInteger(1, #arena.BotNodes)]
end

function BotBrain:CheckStuck(now: number)
	local root = self.Combatant.Root
	local position = root.Position
	if self.LastPosition and (position - self.LastPosition).Magnitude < 0.4 and self.Combatant.Humanoid.MoveDirection.Magnitude > 0.1 then
		self.StuckSince = self.StuckSince or now
		if now - self.StuckSince > STUCK_TIME then
			self.Combatant.Humanoid.Jump = true
			self.Goal = nil
			self.Waypoints = nil
			self.PatrolGoal = self:PickPatrolGoal()
			self.StuckSince = nil
		end
	else
		self.StuckSince = nil
	end
	self.LastPosition = position
end

function BotBrain:Face(position: Vector3?)
	local align = self.Align
	local root = self.Combatant.Root
	local humanoid = self.Combatant.Humanoid
	if not align or not root then
		return
	end
	if position then
		local flat = Vector3.new(position.X, root.Position.Y, position.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			align.CFrame = CFrame.lookAt(root.Position, flat)
			align.Enabled = true
			humanoid.AutoRotate = false
			return
		end
	end
	align.Enabled = false
	humanoid.AutoRotate = true
end

--[[ Aiming: human-like, never an aimbot ]]

local HISTORY_SECONDS = 1

local function rotateToward(current: Vector3, target: Vector3, maxRadians: number): Vector3
	local angle = MathUtil.AngleBetween(current, target)
	if angle <= maxRadians or angle < 1e-4 then
		return target
	end
	local axis = current:Cross(target)
	if axis.Magnitude < 1e-4 then
		axis = Vector3.yAxis
	end
	return (CFrame.fromAxisAngle(axis.Unit, maxRadians) * current).Unit
end

local function perpendicular(direction: Vector3, rng: Random): Vector3
	local random = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	local axis = direction:Cross(random)
	return if axis.Magnitude > 1e-3 then axis.Unit else Vector3.yAxis
end

local function aimPartOf(model: Model, head: boolean): BasePart?
	local part = if head then model:FindFirstChild("Head") else nil
	part = part or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Called when a new target is spotted: aim starts off-target and settles.
function BotBrain:OnAcquire(now: number)
	self.AcquiredAt = now
	self.AimErrorAxis = nil
	self.TargetHistory = {}
	self.AimAtHead = self.Rng:NextNumber() < self.Settings.HeadAimChance
	self.BurstLeft = self.Rng:NextInteger(self.Settings.Burst[1], self.Settings.Burst[2])
end

-- Where the bot *thinks* the target is: a delayed sample of its position.
function BotBrain:PerceivedPoint(part: BasePart, now: number): Vector3
	local history = self.TargetHistory
	table.insert(history, { Time = now, Position = part.Position, Velocity = part.AssemblyLinearVelocity })
	while history[1] and now - history[1].Time > HISTORY_SECONDS do
		table.remove(history, 1)
	end
	local wanted = now - self.Settings.TrackingLag
	local sample = history[1]
	for _, entry in history do
		if entry.Time <= wanted then
			sample = entry
		else
			break
		end
	end
	return sample.Position, sample.Velocity
end

-- Rotates the bot's aim toward the (delayed, error-offset) target at a
-- limited turn speed. Returns the true direction to the target.
function BotBrain:UpdateAim(targetModel: Model, eye: Vector3, now: number, deltaTime: number): (Vector3?, number)
	local settings = self.Settings
	local part = aimPartOf(targetModel, self.AimAtHead)
	if not part then
		return nil, 0
	end
	local perceived, velocity = self:PerceivedPoint(part, now)
	local weapon = self.Services.WeaponService:GetEquippedWeapon(self.Combatant)
	local distance = (perceived - eye).Magnitude
	if weapon and weapon.Projectile and settings.LeadFactor > 0 then
		perceived += velocity * (distance / weapon.Projectile.Speed) * settings.LeadFactor
	end
	local desired = (perceived - eye).Unit

	-- Acquisition error that shrinks as the bot settles onto the target.
	local settle = math.clamp((now - (self.AcquiredAt or now)) / settings.SettleTime, 0, 1)
	local acquireError = settings.AcquireError * (1 - settle) ^ 2
	-- Constant hand shake, worse while the bot itself is moving.
	local moving = math.clamp(self.Combatant.Root.AssemblyLinearVelocity.Magnitude / 20, 0, 1)
	local shake = settings.AimShake * (1 + moving)
	self.AimErrorAxis = self.AimErrorAxis or perpendicular(desired, self.Rng)
	local errored = CFrame.fromAxisAngle(self.AimErrorAxis, math.rad(acquireError)) * desired
	errored = MathUtil.RandomInCone(errored, math.rad(shake), self.Rng)

	local current = self.AimDirection or self.Combatant.Root.CFrame.LookVector
	self.AimDirection = rotateToward(current, errored, math.rad(settings.TurnSpeed) * deltaTime)
	local trueDirection = (part.Position - eye).Unit
	return trueDirection, distance
end

function BotBrain:TryFire(targetModel: Model, eye: Vector3, now: number, deltaTime: number)
	local bot = self.Combatant
	local settings = self.Settings
	local WeaponService = self.Services.WeaponService
	local trueDirection, distance = self:UpdateAim(targetModel, eye, now, deltaTime)
	if not trueDirection or not self.AimDirection then
		return
	end
	if now < self.ReactionReadyAt or now < self.NextFireAt or now < (self.BurstPauseUntil or 0) then
		return
	end
	local weapon = WeaponService:GetEquippedWeapon(bot)
	if not weapon or distance > weapon.Range * 0.9 then
		return
	end
	local ammo = WeaponService:GetAmmo(bot)
	if not ammo or ammo.Mag <= 0 then
		WeaponService:StartReload(bot)
		self.NextFireAt = now + 0.3
		return
	end
	-- Only pull the trigger when the aim is actually near the target.
	if MathUtil.AngleBetween(self.AimDirection, trueDirection) > math.rad(settings.FireCone) then
		return
	end

	self.Services.CombatService:FireBotShot(bot, weapon.Id, eye, self.AimDirection, self.Rng)
	local interval = 1 / WeaponConfig.GetMaxShotsPerSecond(weapon)
	self.NextFireAt = now + interval / settings.FireRateMultiplier
	-- Burst discipline: pause between bursts like a person would.
	self.BurstLeft = (self.BurstLeft or 1) - 1
	if self.BurstLeft <= 0 then
		self.BurstPauseUntil = now + self.Rng:NextNumber(settings.BurstPause[1], settings.BurstPause[2])
		self.BurstLeft = self.Rng:NextInteger(settings.Burst[1], settings.Burst[2])
		self.AimAtHead = self.Rng:NextNumber() < settings.HeadAimChance
		self.AimErrorAxis = nil
	end
end

function BotBrain:Think(deltaTime: number)
	local bot = self.Combatant
	if not bot then
		return
	end
	local Services = self.Services
	if not Services.CombatantService:IsAlive(bot) then
		return
	end
	local character = bot.Character
	local humanoid = bot.Humanoid
	local root = bot.Root
	if character:GetAttribute("Frozen") or not Services.MatchService:IsCombatActive() then
		humanoid:Move(Vector3.zero)
		self:Face(nil)
		return
	end

	local now = os.clock()
	local eye = headOf(character) or root.Position
	local look = root.CFrame.LookVector
	local target, isDecoy = self:FindVisibleTarget(eye, look)

	if target then
		if target ~= self.Target then
			self.ReactionReadyAt = now + self.Settings.ReactionTime
			self:OnAcquire(now)
		end
		self.Target = target
		self.TargetIsDecoy = isDecoy
		local model = self:TargetModel()
		self.LastSeenPosition = model and headOf(model) or self.LastSeenPosition
		self.LastSeenTime = now
	elseif self.Target and now - self.LastSeenTime > BotConfig.MemoryDuration then
		self.Target = nil
	end

	-- State selection.
	local healthFraction = humanoid.Health / humanoid.MaxHealth
	if target and healthFraction <= self.Settings.RetreatHealth and now > self.RetreatUntil + 4 then
		self.RetreatUntil = now + RETREAT_TIME
	end
	if now < self.RetreatUntil then
		self.State = "Retreat"
	elseif target then
		self.State = "Engage"
	elseif self.Target and self.LastSeenPosition then
		self.State = "Chase"
	elseif self.Noise and now - self.NoiseTime < BotConfig.MemoryDuration then
		self.State = "Investigate"
	else
		self.State = "Patrol"
	end

	local state = self.State
	if state == "Engage" or state == "Retreat" then
		local model = self:TargetModel()
		local targetPosition = model and headOf(model)
		if not targetPosition then
			self.Target = nil
			return
		end
		-- The body turns with the bot's (imperfect) aim, not straight at the target.
		self:Face(eye + (self.AimDirection or (targetPosition - eye).Unit) * 10)
		local toTarget = MathUtil.Flatten(targetPosition - root.Position)
		local distance = toTarget.Magnitude
		local forward = MathUtil.SafeUnit(toTarget, look)
		local right = forward:Cross(Vector3.yAxis)

		if now > self.StrafeUntil then
			self.StrafeUntil = now + self.Rng:NextNumber(0.6, 1.4)
			if self.Rng:NextNumber() < self.Settings.StrafeChance then
				self.StrafeDirection = if self.Rng:NextNumber() < 0.5 then -1 else 1
			else
				self.StrafeDirection = 0
			end
			if self.Rng:NextNumber() < self.Settings.StrafeChance * 0.25 then
				humanoid.Jump = true
			end
		end

		local weapon = Services.WeaponService:GetEquippedWeapon(bot)
		local preferred = math.clamp((weapon and weapon.Range or 100) * PREFERRED_RANGE_FRACTION, MIN_PREFERRED_RANGE, MAX_PREFERRED_RANGE)
		local approach = 0
		if state == "Retreat" then
			approach = -1
		elseif distance > preferred * 1.2 then
			approach = 1
		elseif distance < preferred * 0.5 then
			approach = -0.6
		end
		local moveDirection = forward * approach + right * self.StrafeDirection
		humanoid:Move(self:SafeDirection(MathUtil.SafeUnit(moveDirection, Vector3.zero)))
		if model then
			self:TryFire(model, eye, now, deltaTime)
		end
	elseif state == "Chase" then
		self:Face(nil)
		self.AimDirection = nil
		self:MoveToGoal(self.LastSeenPosition, now)
		if (root.Position - self.LastSeenPosition).Magnitude < 6 then
			self.Target = nil
		end
	elseif state == "Investigate" then
		self:Face(nil)
		self.AimDirection = nil
		self:MoveToGoal(self.Noise, now)
		if (root.Position - self.Noise).Magnitude < 8 then
			self.Noise = nil
		end
	else
		self:Face(nil)
		if not self.PatrolGoal or (root.Position - self.PatrolGoal).Magnitude < 8 then
			self.PatrolGoal = self:PickPatrolGoal()
		end
		if self.PatrolGoal then
			self:MoveToGoal(self.PatrolGoal, now)
		end
	end

	-- Reload during downtime.
	if state ~= "Engage" then
		local ammo = Services.WeaponService:GetAmmo(bot)
		local weapon = Services.WeaponService:GetEquippedWeapon(bot)
		if ammo and weapon and ammo.Mag < weapon.MagazineSize * 0.4 then
			Services.WeaponService:StartReload(bot)
		end
	end
	self:CheckStuck(now)
end

return BotBrain
