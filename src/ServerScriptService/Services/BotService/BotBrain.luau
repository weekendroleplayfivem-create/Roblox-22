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

function BotBrain:TryFire(targetModel: Model, eye: Vector3, now: number)
	local bot = self.Combatant
	local WeaponService = self.Services.WeaponService
	if now < self.ReactionReadyAt or now < self.NextFireAt then
		return
	end
	local weapon = WeaponService:GetEquippedWeapon(bot)
	if not weapon then
		return
	end
	local ammo = WeaponService:GetAmmo(bot)
	if not ammo or ammo.Mag <= 0 then
		WeaponService:StartReload(bot)
		self.NextFireAt = now + 0.3
		return
	end

	local aimPart = targetModel:FindFirstChild("UpperTorso") or targetModel:FindFirstChild("Torso") or targetModel:FindFirstChild("HumanoidRootPart")
	if self.Rng:NextNumber() < 0.2 then
		aimPart = targetModel:FindFirstChild("Head") or aimPart
	end
	if not aimPart or not aimPart:IsA("BasePart") then
		return
	end
	local distance = (aimPart.Position - eye).Magnitude
	if distance > weapon.Range then
		return
	end
	-- Aim error grows with target speed so strafing players are harder to hit.
	local targetSpeed = aimPart.AssemblyLinearVelocity.Magnitude
	local errorDegrees = self.Settings.AimErrorDegrees * (1 + targetSpeed / 30)
	local aimPoint = aimPart.Position
	if weapon.Projectile then
		-- Lead projectile targets a little.
		aimPoint += aimPart.AssemblyLinearVelocity * (distance / weapon.Projectile.Speed) * 0.6
	end
	local direction = MathUtil.RandomInCone((aimPoint - eye).Unit, math.rad(errorDegrees), self.Rng)
	self.Services.CombatService:FireBotShot(bot, weapon.Id, eye, direction, self.Rng)
	local interval = 1 / WeaponConfig.GetMaxShotsPerSecond(weapon)
	self.NextFireAt = now + interval / self.Settings.FireRateMultiplier
end

function BotBrain:Think(_deltaTime: number)
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
		self:Face(targetPosition)
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
			self:TryFire(model, eye, now)
		end
	elseif state == "Chase" then
		self:Face(nil)
		self:MoveToGoal(self.LastSeenPosition, now)
		if (root.Position - self.LastSeenPosition).Magnitude < 6 then
			self.Target = nil
		end
	elseif state == "Investigate" then
		self:Face(nil)
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
