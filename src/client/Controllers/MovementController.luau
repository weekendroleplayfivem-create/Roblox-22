--!nonstrict
--[[
	MovementController.luau
	The HYPER BLAST movement model. This is the game.

	ARCHITECTURE
	------------
	Roblox gives the client network ownership of its own character, so movement is
	simulated locally (zero input latency) and AUDITED by the server
	(Services/MovementGuard). That is the only arrangement that produces a shooter
	that feels good; server-simulated movement in Roblox costs a round trip per
	input and no amount of prediction hides it.

	We deliberately run a HYBRID physics model rather than replacing the Humanoid:

		* Ordinary ground locomotion is left to the Humanoid, with our momentum
		  scalar driving `Humanoid.WalkSpeed` every frame. The Humanoid is very
		  good at stairs, slopes, ledges and standing on moving parts, and
		  reimplementing that is weeks of bugs for no player-facing gain.
		* Air control is a Quake-style acceleration layered on top of the assembly
		  velocity. This is what gives strafing a skill ceiling.
		* Scripted states (slide, dash, phase, mantle) TAKE OVER the assembly
		  velocity outright and set `WalkSpeed = 0` so the Humanoid stops fighting.

	The momentum scalar (`self.speed`) is the heart of the feel: it is not reset
	when a state ends. A slide-hop hands its speed to the air state, which hands it
	back on landing, which bleeds away slowly. Speed you earned is speed you keep.

	Everything is driven from one update, in one fixed order (see :_step). Movement
	code that runs in several unordered event handlers is movement code you cannot
	debug at 2am before a playtest.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local MovementConfig = require(Root.Config.MovementConfig)
local MovementState = require(Root.Shared.MovementState)
local Tags = require(Root.Shared.Tags)
local Signal = require(Root.Util.Signal)
local Trove = require(Root.Util.Trove)
local Net = require(Root.Util.Net)

local LocalPlayer = Players.LocalPlayer

local MovementController = {}
MovementController.__index = MovementController

local UP = Vector3.yAxis
local ZERO = Vector3.zero

local function flatten(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return if flat.Magnitude > 1e-4 then flat.Unit else ZERO
end

local function horizontalOf(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------

function MovementController.new(context)
	local self = setmetatable({}, MovementController)

	self.context = context
	self.input = context.Input
	self.config = MovementConfig
	self._trove = Trove.new()
	self._characterTrove = Trove.new()

	-- Simulation state -------------------------------------------------
	self.state = MovementState.Idle
	self.previousState = MovementState.Idle
	self.speed = MovementConfig.Speed.Walk -- the momentum scalar
	self.stamina = MovementConfig.Stamina.Max
	self.exhausted = false
	self.enabled = false

	self.grounded = false
	self.groundNormal = UP
	self.groundPart = nil :: BasePart?
	self.viewHeightOffset = 0 -- consumed by the camera for crouch/slide dips

	self._lastGroundedAt = 0
	self._lastJumpAt = -1
	self._lastLandAt = -1
	self._lastSlideAt = -1
	self._lastWallJumpAt = -1
	self._lastWallPart = nil :: BasePart?
	self._lastMantleAt = -1
	self._lastPadAt = -1
	self._lastStaminaDrainAt = 0
	self._wallChain = 0
	self._airDashes = 0
	self._sprintHeld = false
	self._crouchHeld = false
	self._snapshotAccumulator = 0

	self._slide = { direction = ZERO, speed = 0, startedAt = 0, boosted = false }
	self._dash = { direction = ZERO, endsAt = 0, speed = 0 }
	self._phase = { from = CFrame.identity, to = CFrame.identity, startedAt = 0, duration = 0 }
	self._mantle = { from = CFrame.identity, to = CFrame.identity, startedAt = 0, duration = 0 }

	-- External modifiers. Abilities and weapons write here; nothing else does.
	self.modifiers = {
		speed = 1, -- Overdrive
		accel = 1,
		staminaDrain = 1,
		weaponSpeed = 1, -- equipped weapon's mobility
		adsFactor = 0, -- 0..1, blended toward the weapon's ADS speed multiplier
		adsSpeedMultiplier = 1,
		frozen = false, -- warmup / post-match
	}

	-- Signals ----------------------------------------------------------
	self.StateChanged = Signal.new()
	self.Jumped = Signal.new()
	self.Landed = Signal.new()
	self.SlideStarted = Signal.new()
	self.SlideEnded = Signal.new()
	self.WallJumped = Signal.new()
	self.Mantled = Signal.new()
	self.DashStarted = Signal.new()
	self.PhaseStarted = Signal.new()
	self.PadLaunched = Signal.new()
	self.StaminaChanged = Signal.new()
	self.Stepped = Signal.new() -- (dt, snapshot) - camera + HUD ride on this

	self.snapshot = {
		state = self.state,
		speed = 0,
		horizontalSpeed = 0,
		verticalSpeed = 0,
		stamina = self.stamina,
		grounded = false,
		position = ZERO,
		wallNormal = nil,
	}

	return self
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------

function MovementController:Start()
	local stepSignal = RunService.Heartbeat
	do
		-- PreSimulation lands our velocity writes *before* the physics step, which
		-- removes a frame of latency. Fall back on older clients.
		local ok, signal = pcall(function()
			return RunService.PreSimulation
		end)
		if ok and signal then
			stepSignal = signal
		end
	end

	self._trove:Add(stepSignal:Connect(function(dt)
		local ok, err = pcall(self._step, self, math.min(dt, 1 / 15))
		if not ok then
			warn(`[Movement] step error: {err}`)
		end
	end))

	self._trove:Add(LocalPlayer.CharacterAdded:Connect(function(character)
		self:_bindCharacter(character)
	end))
	if LocalPlayer.Character then
		self:_bindCharacter(LocalPlayer.Character)
	end

	-- The server can pull us back if the guard rejects a position. This should be
	-- vanishingly rare in normal play; if players feel it, the guard is too tight.
	self._trove:Add(Net.onClient("MovementCorrection", function(position: Vector3)
		if self.root then
			self.root.CFrame = CFrame.new(position) * (self.root.CFrame - self.root.CFrame.Position)
			self.root.AssemblyLinearVelocity = ZERO
			self.speed = MovementConfig.Speed.Walk
		end
	end))

	self._trove:Connect(self.input.ActionPressed, function(action)
		self:_onActionPressed(action)
	end)
	self._trove:Connect(self.input.ActionReleased, function(action)
		if action == "Sprint" then
			self._sprintHeld = false
		elseif action == "Crouch" or action == "Slide" then
			self._crouchHeld = false
		end
	end)

	return self
end

function MovementController:_bindCharacter(character: Model)
	self._characterTrove:Clean()

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart
	if not humanoid or not root then
		return
	end

	self.character = character
	self.humanoid = humanoid
	self.root = root
	self.enabled = true

	self.baseHipHeight = humanoid.HipHeight
	self.speed = MovementConfig.Speed.Walk
	self.stamina = MovementConfig.Stamina.Max
	self.exhausted = false
	self._wallChain = 0
	self._airDashes = 0
	self:_setState(MovementState.Idle)

	-- Humanoid setup. Jump height (not JumpPower) so the arc is gravity-independent.
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = MovementConfig.Jump.Height
	humanoid.WalkSpeed = MovementConfig.Speed.Walk
	humanoid.MaxSlopeAngle = 60
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false

	-- States we never want: they take control away, which this game never does.
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll } do
		humanoid:SetStateEnabled(state, false)
	end

	self._characterTrove:Add(humanoid.Died:Connect(function()
		self.enabled = false
		self:_setState(MovementState.Idle)
	end))

	self._characterTrove:Fn(function()
		self.character = nil
		self.humanoid = nil
		self.root = nil
		self.enabled = false
	end)

	self._raycastParams = RaycastParams.new()
	self._raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self._raycastParams.FilterDescendantsInstances = { character, workspace:FindFirstChild("HyperBlastFx") }
	self._raycastParams.IgnoreWater = true
end

function MovementController:Destroy()
	self._characterTrove:Clean()
	self._trove:Clean()
end

----------------------------------------------------------------------
-- Input plumbing
----------------------------------------------------------------------

function MovementController:_onActionPressed(action: string)
	if action == "Sprint" then
		self._sprintHeld = true
	elseif action == "Crouch" or action == "Slide" then
		self._crouchHeld = true
	end
end

--[[ World-space wish direction. Humanoid.MoveDirection already merges WASD, the
	 left stick and touch input, and is camera-relative - so gamepad parity is free. ]]
function MovementController:_wishDirection(): Vector3
	local humanoid = self.humanoid
	if not humanoid or self.modifiers.frozen then
		return ZERO
	end
	return flatten(humanoid.MoveDirection)
end

function MovementController:_lookDirection(): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return ZERO
	end
	return flatten(camera.CFrame.LookVector)
end

----------------------------------------------------------------------
-- Environment probes
----------------------------------------------------------------------

function MovementController:_probeGround()
	local humanoid, root = self.humanoid, self.root
	local wasGrounded = self.grounded

	-- The Humanoid's own floor detection is authoritative for "am I standing on
	-- something" (it handles ledges and moving platforms). We raycast only to
	-- recover the floor NORMAL and PART, which slide physics and jump pads need.
	-- Note: this stays honest during scripted states. An earlier version forced
	-- `grounded = false` while dashing, which quietly broke dash -> slide (the
	-- flagship combo) because _endDash checks `self.grounded` to decide whether to
	-- hand off into a slide. Scripted states already bypass ground locomotion in
	-- _applyMotion, so they gain nothing from lying here.
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air

	local origin = root.Position
	local result = workspace:Raycast(origin, Vector3.new(0, -(humanoid.HipHeight + 3.2), 0), self._raycastParams)

	if result then
		self.groundNormal = result.Normal
		self.groundPart = result.Instance
		self.groundDistance = (origin - result.Position).Magnitude
	else
		self.groundNormal = UP
		self.groundPart = nil
		self.groundDistance = math.huge
	end

	self.grounded = grounded
	if grounded then
		self._lastGroundedAt = os.clock()
	end

	return wasGrounded
end

--[[ Finds a wall-jumpable surface next to the player.
	 We probe outward from the root in the directions that matter: where you're
	 looking, where you're moving, and both sides. Four rays, once a frame. ]]
function MovementController:_probeWall()
	local cfg = MovementConfig.Wall
	local root = self.root
	local origin = root.Position

	if self.grounded or self.groundDistance < cfg.MinHeightAboveGround then
		return nil
	end

	local look = self:_lookDirection()
	local wish = self:_wishDirection()
	local right = flatten(root.CFrame.RightVector)

	local directions = { wish, look, right, -right }
	local best, bestDistance = nil, math.huge

	for _, direction in directions do
		if direction.Magnitude > 0.1 then
			local result = workspace:Raycast(origin, direction * cfg.DetectDistance, self._raycastParams)
			if result and math.abs(result.Normal.Y) <= cfg.MaxNormalY then
				local part = result.Instance
				local eligible = not cfg.RequireTaggedSurface
					or CollectionService:HasTag(part, Tags.WallJump)
					or part:GetAttribute("HyperBlast_WallJump") == true

				if eligible then
					local distance = (result.Position - origin).Magnitude
					if distance < bestDistance then
						best, bestDistance = result, distance
					end
				end
			end
		end
	end

	return best
end

--[[ Ledge detection for mantling.
	 Two-step probe: find a wall face ahead, then find the top surface behind it.
	 Returns the CFrame to end the mantle at, or nil. ]]
function MovementController:_probeMantle(): CFrame?
	local cfg = MovementConfig.Mantle
	local root = self.root
	local look = self:_lookDirection()
	if look.Magnitude < 0.1 then
		return nil
	end

	local feetY = root.Position.Y - self.humanoid.HipHeight
	local chest = Vector3.new(root.Position.X, feetY + cfg.MinLedgeHeight * 0.6, root.Position.Z)

	local face = workspace:Raycast(chest, look * cfg.ForwardCheck, self._raycastParams)
	if not face or math.abs(face.Normal.Y) > 0.4 then
		return nil
	end
	if CollectionService:HasTag(face.Instance, Tags.NoMantle) then
		return nil
	end

	-- Probe straight down onto the top surface, just past the wall face.
	local overshoot = face.Position + look * cfg.DepthCheck + UP * (cfg.MaxLedgeHeight + 1)
	local top = workspace:Raycast(overshoot, Vector3.new(0, -(cfg.MaxLedgeHeight + 2), 0), self._raycastParams)
	if not top or top.Normal.Y < cfg.MaxDownAngle then
		return nil
	end

	local ledgeHeight = top.Position.Y - feetY
	if ledgeHeight < cfg.MinLedgeHeight or ledgeHeight > cfg.MaxLedgeHeight then
		return nil
	end

	-- Headroom check: refuse to mantle into a ceiling.
	local clearance = workspace:Raycast(top.Position + UP * 0.4, UP * cfg.ClearanceHeight, self._raycastParams)
	if clearance then
		return nil
	end

	local landing = top.Position + UP * (self.humanoid.HipHeight + root.Size.Y * 0.5) + look * 0.6
	return CFrame.lookAt(landing, landing + look)
end

----------------------------------------------------------------------
-- State machine
----------------------------------------------------------------------

function MovementController:_setState(state: string)
	if self.state == state then
		return
	end
	self.previousState = self.state
	self.state = state
	self.snapshot.state = state
	self.StateChanged:FireSync(state, self.previousState)
end

function MovementController:_canSprint(wish: Vector3): boolean
	if not self._sprintHeld or self.modifiers.frozen then
		return false
	end
	if wish.Magnitude < 0.1 then
		return false
	end
	if self.exhausted then
		return false
	end
	if self.state == MovementState.Sprint then
		return self.stamina > 0
	end
	-- Starting a sprint has a higher bar than continuing one, so tapping shift at
	-- 2 stamina doesn't produce a one-frame sprint.
	if self.stamina < MovementConfig.Stamina.SprintMinimum then
		return false
	end
	return wish:Dot(self:_lookDirection()) >= MovementConfig.Stamina.SprintDotThreshold
end

function MovementController:_targetGroundSpeed(wish: Vector3): number
	local speeds = MovementConfig.Speed
	local base

	if self.state == MovementState.Crouch then
		base = speeds.Crouch
	elseif self.state == MovementState.Sprint then
		base = speeds.Sprint
	elseif wish.Magnitude < 0.1 then
		return 0
	else
		base = speeds.Walk
	end

	-- Directional multipliers make positioning matter: you cannot backpedal out of
	-- a duel at full speed, so committing forward is a real decision.
	if wish.Magnitude > 0.1 and self.state ~= MovementState.Crouch then
		local dot = wish:Dot(self:_lookDirection())
		if dot < -0.4 then
			base *= speeds.Backpedal
		elseif dot < 0.55 then
			base *= speeds.Strafe
		end
	end

	base *= self.modifiers.speed
	base *= self.modifiers.weaponSpeed

	-- ADS blends in rather than snapping, so aiming mid-strafe doesn't jolt.
	local adsBlend = self.modifiers.adsFactor
	if adsBlend > 0 then
		local adsMultiplier = self.modifiers.adsSpeedMultiplier
		base *= 1 + (adsMultiplier - 1) * adsBlend
	end

	return base
end

----------------------------------------------------------------------
-- The frame
----------------------------------------------------------------------

function MovementController:_step(dt: number)
	if not self.enabled or not self.root or not self.humanoid or self.humanoid.Health <= 0 then
		return
	end

	local wasGrounded = self:_probeGround()
	local wish = self:_wishDirection()

	self:_handleTransitions(dt, wish, wasGrounded)
	self:_updateStamina(dt)
	self:_applyMotion(dt, wish)
	self:_updateStance(dt)
	self:_publish(dt)
end

function MovementController:_handleTransitions(dt: number, wish: Vector3, wasGrounded: boolean)
	local now = os.clock()
	local state = self.state

	-- Scripted states own themselves until they expire.
	if state == MovementState.Dash then
		if now >= self._dash.endsAt then
			self:_endDash()
		end
		return
	elseif state == MovementState.Phase then
		if now - self._phase.startedAt >= self._phase.duration then
			self:_endPhase()
		end
		return
	elseif state == MovementState.Mantle then
		if now - self._mantle.startedAt >= self._mantle.duration then
			self:_endMantle()
		end
		return
	end

	------------------------------------------------------------------
	-- Landing / leaving the ground
	------------------------------------------------------------------
	if self.grounded and not wasGrounded then
		-- Landing can itself start a jump (buffered) or a slide (crouch held). When
		-- it does it owns the frame: falling through would re-evaluate stale local
		-- state and, for example, restart the slide it just began.
		if self:_onLanded() then
			return
		end
	elseif not self.grounded and wasGrounded and state ~= MovementState.Slide then
		self:_setState(MovementState.Air)
	end

	------------------------------------------------------------------
	-- Jump pads (read from the floor part; no Touched events, no double-fires)
	------------------------------------------------------------------
	if self.grounded and self.groundPart and now - self._lastPadAt > MovementConfig.JumpPad.Cooldown then
		if CollectionService:HasTag(self.groundPart, Tags.JumpPad) then
			self:_launchFromPad(self.groundPart)
			return
		end
	end

	------------------------------------------------------------------
	-- Jump: coyote time + buffered input + wall jump + mantle, in priority order
	------------------------------------------------------------------
	if self.input:PeekBuffer("Jump") and not self.modifiers.frozen then
		local mantleTarget = (now - self._lastMantleAt > MovementConfig.Mantle.Cooldown) and self:_probeMantle() or nil
		if mantleTarget then
			self.input:ConsumeBuffer("Jump")
			self:_beginMantle(mantleTarget)
			return
		end

		local wallHit = self:_probeWall()
		if wallHit and self:_canWallJump(wallHit, now) then
			self.input:ConsumeBuffer("Jump")
			self:_wallJump(wallHit)
			return
		end

		local withinCoyote = (now - self._lastGroundedAt) <= MovementConfig.Jump.CoyoteTime
		if (self.grounded or withinCoyote) and (now - self._lastJumpAt) > 0.08 then
			self.input:ConsumeBuffer("Jump")
			self:_jump()
			return
		end
	end

	------------------------------------------------------------------
	-- Slide / crouch
	------------------------------------------------------------------
	if state == MovementState.Slide then
		self:_updateSlideState(now, wish)
		return
	end

	if self._crouchHeld and self.grounded and not self.modifiers.frozen then
		local horizontalSpeed = horizontalOf(self.root.AssemblyLinearVelocity).Magnitude
		local canSlide = horizontalSpeed >= MovementConfig.Slide.EntrySpeedRequired
			and (now - self._lastSlideAt) > MovementConfig.Slide.Cooldown * (self.modifiers.slideCooldown or 1)
			and self.stamina >= 1

		if canSlide then
			self:_beginSlide(wish)
			return
		end
		self:_setState(MovementState.Crouch)
		return
	end

	if state == MovementState.Crouch and not self._crouchHeld then
		if self:_hasHeadroom() then
			self:_setState(self.grounded and MovementState.Idle or MovementState.Air)
		else
			return -- stuck under geometry: stay crouched, don't clip the player upward
		end
	end

	------------------------------------------------------------------
	-- Airborne states
	------------------------------------------------------------------
	if not self.grounded then
		local wallHit = self:_probeWall()
		local falling = self.root.AssemblyLinearVelocity.Y < -1
		if wallHit and falling and wish.Magnitude > 0.1 and wish:Dot(-wallHit.Normal) > 0.35 then
			self.snapshot.wallNormal = wallHit.Normal
			self:_setState(MovementState.WallSlide)
		elseif state ~= MovementState.Launched or self.root.AssemblyLinearVelocity.Y < 0 then
			self.snapshot.wallNormal = nil
			self:_setState(MovementState.Air)
		end
		return
	end

	------------------------------------------------------------------
	-- Grounded states
	------------------------------------------------------------------
	self.snapshot.wallNormal = nil
	if self:_canSprint(wish) then
		self:_setState(MovementState.Sprint)
	elseif wish.Magnitude > 0.1 then
		self:_setState(MovementState.Walk)
	else
		self:_setState(MovementState.Idle)
	end
end

----------------------------------------------------------------------
-- Motion application
----------------------------------------------------------------------

function MovementController:_applyMotion(dt: number, wish: Vector3)
	local state = self.state

	if state == MovementState.Slide then
		self:_applySlide(dt, wish)
	elseif state == MovementState.Dash then
		self:_applyDash(dt)
	elseif state == MovementState.Phase then
		self:_applyPhase()
	elseif state == MovementState.Mantle then
		self:_applyMantle()
	elseif self.grounded then
		self:_applyGround(dt, wish)
	else
		self:_applyAir(dt, wish, state == MovementState.WallSlide)
	end
end

function MovementController:_applyGround(dt: number, wish: Vector3)
	local accel = MovementConfig.Acceleration
	local target = self:_targetGroundSpeed(wish)
	local sprintSpeed = MovementConfig.Speed.Sprint * self.modifiers.speed

	if self.speed > target then
		-- Excess momentum (from a slide, dash or pad) bleeds slowly; ordinary
		-- over-speed brakes fast. This asymmetry IS the momentum system.
		local rate = if self.speed > sprintSpeed then accel.MomentumBleed else accel.GroundBrake
		self.speed = math.max(target, self.speed - rate * dt)
	else
		local rate = accel.Ground * self.modifiers.accel
		self.speed = math.min(target, self.speed + rate * dt)
	end

	self.speed = math.clamp(self.speed, 0, MovementConfig.Speed.MaxMomentum)
	self.humanoid.WalkSpeed = self.speed
end

function MovementController:_applyAir(dt: number, wish: Vector3, wallSliding: boolean)
	local air = MovementConfig.Air
	local root = self.root
	local velocity = root.AssemblyLinearVelocity
	local horizontal = horizontalOf(velocity)

	-- Quake air acceleration: only the component of speed ALONG the wish direction
	-- is capped, so turning the camera while holding a strafe key keeps adding
	-- speed. Four lines of code, an entire movement meta.
	if wish.Magnitude > 0.1 then
		local currentInWish = horizontal:Dot(wish)
		local addSpeed = math.clamp(air.WishSpeed - currentInWish, 0, air.Accel * air.Control * dt)
		horizontal += wish * addSpeed
	end

	-- Soft cap: speed above the cap decays exponentially instead of clamping, so a
	-- dash or a pad launch keeps its punch and only *sustained* strafing is limited.
	local speed = horizontal.Magnitude
	if speed > air.SpeedCap then
		local excess = speed - air.SpeedCap
		local decayed = air.SpeedCap + excess * math.exp(-air.Drag * dt)
		horizontal = horizontal.Unit * math.min(decayed, MovementConfig.Speed.MaxMomentum)
	end

	local verticalVelocity = velocity.Y

	if wallSliding then
		local wall = MovementConfig.Wall
		-- Counteract most of gravity while hugging the wall: a wall slide is a
		-- decision point, not a free hover.
		verticalVelocity += workspace.Gravity * (1 - wall.SlideGravityScale) * dt
		verticalVelocity = math.max(verticalVelocity, -wall.SlideMaxFallSpeed)
	elseif verticalVelocity < 0 then
		-- Snappier apex-to-ground half of the jump arc.
		verticalVelocity -= workspace.Gravity * (air.FastFallMultiplier - 1) * dt
	end

	root.AssemblyLinearVelocity = Vector3.new(horizontal.X, verticalVelocity, horizontal.Z)

	-- Keep the momentum scalar in sync so landing hands the speed straight back.
	self.speed = math.clamp(horizontal.Magnitude, MovementConfig.Speed.Walk, MovementConfig.Speed.MaxMomentum)
	self.humanoid.WalkSpeed = self.speed
end

----------------------------------------------------------------------
-- Jump / land
----------------------------------------------------------------------

function MovementController:_jump()
	local now = os.clock()
	local slideHop = self.state == MovementState.Slide

	if slideHop then
		self:_endSlide(true)
	end

	self._lastJumpAt = now
	self.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	-- A clean re-jump inside the hop window keeps ALL of your speed. This is the
	-- payoff for a well-timed sprint -> slide -> jump chain.
	local sinceLanding = now - self._lastLandAt
	if slideHop or sinceLanding <= MovementConfig.Jump.HopWindow then
		local velocity = self.root.AssemblyLinearVelocity
		local horizontal = horizontalOf(velocity)
		local keep = if slideHop then MovementConfig.Slide.JumpSpeedKeep else MovementConfig.Jump.HopSpeedKeep
		local kept = math.max(horizontal.Magnitude, self.speed) * keep
		if horizontal.Magnitude > 0.1 then
			horizontal = horizontal.Unit * math.min(kept, MovementConfig.Speed.MaxMomentum)
			self.root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
			self.speed = horizontal.Magnitude
		end
	end

	self._wallChain = 0
	self:_setState(MovementState.Air)
	self.Jumped:FireSync(slideHop)
end

--[[ Returns true if landing consumed the frame (a buffered jump or a slide
	 started), telling the caller to stop evaluating transitions. ]]
function MovementController:_onLanded(): boolean
	local now = os.clock()
	local velocity = self.root.AssemblyLinearVelocity
	local fallSpeed = -math.min(velocity.Y, 0)
	local horizontal = horizontalOf(velocity).Magnitude

	self._lastLandAt = now
	self._wallChain = 0
	self._airDashes = 0

	-- Momentum handoff: airborne speed becomes ground momentum, which then bleeds.
	local keep = MovementConfig.Jump.LandSpeedKeep
	self.speed = math.clamp(
		math.max(horizontal * keep, MovementConfig.Speed.Walk),
		0,
		MovementConfig.Speed.MaxMomentum
	)

	-- Buffered jump means you never "eat" a landing: press early, hop instantly.
	local consumed = false
	if self.input:PeekBuffer("Jump") then
		self.input:ConsumeBuffer("Jump")
		self:_jump()
		consumed = true
	elseif self._crouchHeld and horizontal >= MovementConfig.Slide.EntrySpeedRequired then
		self:_beginSlide(self:_wishDirection())
		consumed = true
	else
		self:_setState(self.grounded and MovementState.Idle or MovementState.Air)
	end

	self.Landed:FireSync(fallSpeed, horizontal, fallSpeed >= MovementConfig.Camera.LandDipHeavyFallSpeed)
	return consumed
end

----------------------------------------------------------------------
-- Slide
----------------------------------------------------------------------

function MovementController:_beginSlide(wish: Vector3)
	local cfg = MovementConfig.Slide
	local velocity = self.root.AssemblyLinearVelocity
	local horizontal = horizontalOf(velocity)

	local direction = if horizontal.Magnitude > 1 then horizontal.Unit else self:_lookDirection()
	if direction.Magnitude < 0.1 then
		direction = flatten(self.root.CFrame.LookVector)
	end

	local entrySpeed = math.clamp(
		math.max(horizontal.Magnitude, self.speed) * cfg.EntryBoost,
		cfg.EntryMinSpeed,
		cfg.EntryMaxSpeed
	)

	self._slide.direction = direction
	self._slide.speed = entrySpeed
	self._slide.startedAt = os.clock()
	self._lastSlideAt = os.clock()
	self.speed = entrySpeed

	self:_drainStamina(MovementConfig.Stamina.SlideCost)
	self:_setState(MovementState.Slide)
	self.SlideStarted:FireSync(direction, entrySpeed)
	self:_reportEvent("Slide", { direction = direction, speed = entrySpeed })
end

function MovementController:_updateSlideState(now: number, wish: Vector3)
	local cfg = MovementConfig.Slide
	local elapsed = now - self._slide.startedAt

	if elapsed < cfg.MinDuration then
		return -- committed: no jittery one-frame slides
	end

	local expired = elapsed >= cfg.MaxDuration
	local tooSlow = self._slide.speed <= cfg.MinSpeed
	local released = not self._crouchHeld
	local leftGround = not self.grounded

	if expired or tooSlow or released or leftGround then
		self:_endSlide(false)
	end
end

function MovementController:_endSlide(fromJump: boolean)
	if self.state ~= MovementState.Slide then
		return
	end

	self.speed = math.max(self.speed, self._slide.speed)
	self.SlideEnded:FireSync(fromJump)

	if fromJump then
		return -- _jump() sets the next state
	end

	if not self.grounded then
		self:_setState(MovementState.Air)
	elseif self._crouchHeld or not self:_hasHeadroom() then
		self:_setState(MovementState.Crouch)
	else
		self:_setState(MovementState.Idle)
	end
end

function MovementController:_applySlide(dt: number, wish: Vector3)
	local cfg = MovementConfig.Slide
	local root = self.root
	local slide = self._slide

	-- Slope physics: downhill accelerates, uphill brakes. `groundNormal:Dot(dir)`
	-- is positive when the surface descends along the slide direction.
	local slope = self.groundNormal:Dot(slide.direction)
	if slope > 0 then
		slide.speed += cfg.SlopeAccel * slope * dt
	else
		slide.speed += cfg.SlopeBrake * slope * dt
	end

	-- Slide-boost tunnels are near-frictionless: the arena's fast lanes.
	local friction = cfg.Friction
	if self.groundPart and CollectionService:HasTag(self.groundPart, Tags.SlideBoost) then
		friction *= 0.25
	end
	slide.speed = math.clamp(slide.speed - friction * dt, 0, MovementConfig.Speed.MaxMomentum)

	-- Limited steering. You can curve a slide around a corner, but you cannot
	-- turn it into free strafing - the commitment is the cost of the speed.
	if wish.Magnitude > 0.1 then
		local current = slide.direction
		local angle = math.acos(math.clamp(current:Dot(wish), -1, 1))
		if angle > 1e-3 then
			local maxStep = cfg.SteerRate * dt
			local alpha = math.clamp(maxStep / angle, 0, 1)
			slide.direction = flatten(current:Lerp(wish, alpha))
		end
	end

	self.speed = slide.speed
	self.humanoid.WalkSpeed = 0 -- the Humanoid must not fight the slide

	local velocity = slide.direction * slide.speed
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, root.AssemblyLinearVelocity.Y, velocity.Z)
end

----------------------------------------------------------------------
-- Wall jump / wall slide
----------------------------------------------------------------------

function MovementController:_canWallJump(hit: RaycastResult, now: number): boolean
	local cfg = MovementConfig.Wall
	if self._wallChain >= cfg.MaxChain then
		return false
	end
	if now - self._lastWallJumpAt < cfg.Cooldown then
		return false
	end
	-- Re-using the same wall immediately would let a player elevator up one
	-- surface forever. Alternating surfaces is the intended skill expression.
	if hit.Instance == self._lastWallPart and now - self._lastWallJumpAt < cfg.SameWallLockout then
		return false
	end
	return self.stamina >= MovementConfig.Stamina.WallJumpCost * 0.5
end

function MovementController:_wallJump(hit: RaycastResult)
	local cfg = MovementConfig.Wall
	local root = self.root
	local away = flatten(hit.Normal)
	local look = self:_lookDirection()
	local horizontal = horizontalOf(root.AssemblyLinearVelocity)

	-- Blend "push off the wall" with "keep going where you're looking" so a wall
	-- jump redirects momentum instead of resetting it.
	local carried = look * horizontal.Magnitude * cfg.ForwardKeep
	local result = away * cfg.JumpOutSpeed + carried
	if result.Magnitude > MovementConfig.Speed.MaxMomentum then
		result = result.Unit * MovementConfig.Speed.MaxMomentum
	end

	root.AssemblyLinearVelocity = Vector3.new(result.X, cfg.JumpUpSpeed, result.Z)
	self.speed = math.clamp(horizontalOf(result).Magnitude, MovementConfig.Speed.Walk, MovementConfig.Speed.MaxMomentum)

	self._wallChain += 1
	self._lastWallJumpAt = os.clock()
	self._lastWallPart = hit.Instance
	self:_drainStamina(MovementConfig.Stamina.WallJumpCost)
	self:_setState(MovementState.Air)

	self.WallJumped:FireSync(hit.Position, hit.Normal, self._wallChain)
	self:_reportEvent("WallJump", { position = hit.Position, normal = hit.Normal, chain = self._wallChain })
end

----------------------------------------------------------------------
-- Mantle
----------------------------------------------------------------------

function MovementController:_beginMantle(target: CFrame)
	local cfg = MovementConfig.Mantle
	local root = self.root

	self._mantle.from = root.CFrame
	self._mantle.to = target
	self._mantle.startedAt = os.clock()
	self._mantle.duration = cfg.Duration
	self._lastMantleAt = os.clock()

	root.Anchored = true
	self.humanoid.WalkSpeed = 0
	self:_drainStamina(MovementConfig.Stamina.MantleCost)
	self:_setState(MovementState.Mantle)

	self.Mantled:FireSync(target.Position)
	self:_reportEvent("Mantle", { position = target.Position })
end

function MovementController:_applyMantle()
	local alpha = math.clamp((os.clock() - self._mantle.startedAt) / self._mantle.duration, 0, 1)
	-- Ease-out: fast off the wall, settles at the top. Reads as effort, not teleport.
	local eased = 1 - (1 - alpha) ^ 3

	local from, to = self._mantle.from, self._mantle.to
	local position = from.Position:Lerp(to.Position, eased)
	-- The player keeps camera authority throughout; we only move the body.
	self.root.CFrame = CFrame.new(position) * (from - from.Position)
end

function MovementController:_endMantle()
	local root = self.root
	root.Anchored = false
	root.CFrame = CFrame.new(self._mantle.to.Position) * (root.CFrame - root.CFrame.Position)

	local exit = self:_lookDirection() * MovementConfig.Mantle.ExitSpeed
	root.AssemblyLinearVelocity = Vector3.new(exit.X, 2, exit.Z)
	self.speed = MovementConfig.Mantle.ExitSpeed
	self:_setState(self.grounded and MovementState.Walk or MovementState.Air)
end

----------------------------------------------------------------------
-- Jump pads
----------------------------------------------------------------------

function MovementController:_launchFromPad(pad: BasePart)
	local cfg = MovementConfig.JumpPad
	local power = pad:GetAttribute("Power") or cfg.DefaultPower
	local forwardKeep = pad:GetAttribute("ForwardKeep") or cfg.DefaultForwardKeep

	local horizontal = horizontalOf(self.root.AssemblyLinearVelocity) * forwardKeep
	self.root.AssemblyLinearVelocity = Vector3.new(horizontal.X, power, horizontal.Z)

	self._lastPadAt = os.clock()
	self._airDashes = 0 -- pads refresh your air dash: pad -> dash is an intended route
	self:_setState(MovementState.Launched)

	self.PadLaunched:FireSync(pad, power)
	self:_reportEvent("JumpPad", { position = pad.Position, power = power })
end

----------------------------------------------------------------------
-- Ability hooks (called by AbilityController; validated server-side)
----------------------------------------------------------------------

--[[ Hyper Dash. Horizontal burst in the wish direction, falling back to look.
	 Returns false if the dash cannot legally start right now. ]]
function MovementController:StartDash(config): boolean
	if not self.enabled or not self.root or self.modifiers.frozen then
		return false
	end
	if self.state == MovementState.Dash or self.state == MovementState.Phase then
		return false
	end
	if not self.grounded and self._airDashes >= config.AirUses then
		return false
	end

	local direction = self:_wishDirection()
	if direction.Magnitude < 0.1 then
		direction = self:_lookDirection()
	end
	if direction.Magnitude < 0.1 then
		return false
	end

	if not self.grounded then
		self._airDashes += 1
	end

	self._dash.direction = direction
	self._dash.speed = config.Speed
	self._dash.endsAt = os.clock() + config.Duration
	self._dash.exitKeep = config.ExitSpeedKeep
	self._dash.verticalKeep = config.VerticalKeep

	-- Cancel most of the fall so an air dash reads as a clean horizontal snap.
	local velocity = self.root.AssemblyLinearVelocity
	self.root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y * config.VerticalKeep, velocity.Z)

	self:_setState(MovementState.Dash)
	self.DashStarted:FireSync(direction, config)
	self:_reportEvent("Dash", { direction = direction })
	return true
end

function MovementController:_applyDash(dt: number)
	local dash = self._dash
	local velocity = dash.direction * dash.speed
	self.humanoid.WalkSpeed = 0
	self.root.AssemblyLinearVelocity = Vector3.new(velocity.X, self.root.AssemblyLinearVelocity.Y, velocity.Z)
	self.speed = dash.speed
end

function MovementController:_endDash()
	local exitSpeed = self._dash.speed * (self._dash.exitKeep or 0.7)
	local velocity = self._dash.direction * exitSpeed
	self.root.AssemblyLinearVelocity =
		Vector3.new(velocity.X, self.root.AssemblyLinearVelocity.Y, velocity.Z)

	-- Handing the speed to the momentum scalar is what makes dash -> slide work.
	self.speed = math.clamp(exitSpeed, MovementConfig.Speed.Walk, MovementConfig.Speed.MaxMomentum)

	if self._crouchHeld and self.grounded then
		self:_beginSlide(self:_wishDirection())
	else
		self:_setState(self.grounded and MovementState.Walk or MovementState.Air)
	end
end

--[[ Phase Step. Short forward blink that refuses to put you inside geometry:
	 we sweep for the furthest legal point along the look direction. ]]
function MovementController:StartPhase(config): boolean
	if not self.enabled or not self.root or self.modifiers.frozen then
		return false
	end
	if self.state == MovementState.Phase or self.state == MovementState.Mantle then
		return false
	end

	local root = self.root
	local direction = self:_lookDirection()
	if direction.Magnitude < 0.1 then
		return false
	end

	-- Geometry-only sweep. Players are ignored (you phase through bodies), walls
	-- are not (you never phase into or through the level).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local exclusions = { self.character }
	if config.PhaseThroughPlayers then
		for _, player in Players:GetPlayers() do
			if player ~= LocalPlayer and player.Character then
				table.insert(exclusions, player.Character)
			end
		end
	end
	params.FilterDescendantsInstances = exclusions

	local distance = config.Distance
	local hit = workspace:Blockcast(
		root.CFrame,
		Vector3.new(2, 4, 2),
		direction * config.Distance,
		params
	)
	if hit then
		distance = math.max((hit.Position - root.Position).Magnitude - 1.6, 0)
	end

	if distance < config.MinDistance then
		return false -- refuse rather than fizzle you into a wall
	end

	self._phase.from = root.CFrame
	self._phase.to = root.CFrame + direction * distance
	self._phase.startedAt = os.clock()
	self._phase.duration = config.Duration
	self._phase.postSpeed = config.PostSpeed

	root.Anchored = true
	self:_setState(MovementState.Phase)
	self.PhaseStarted:FireSync(self._phase.from, self._phase.to, config)
	self:_reportEvent("Phase", { from = self._phase.from.Position, to = self._phase.to.Position })
	return true
end

function MovementController:_applyPhase()
	local alpha = math.clamp((os.clock() - self._phase.startedAt) / self._phase.duration, 0, 1)
	local eased = alpha * alpha * (3 - 2 * alpha) -- smoothstep: no pop at either end
	local position = self._phase.from.Position:Lerp(self._phase.to.Position, eased)
	self.root.CFrame = CFrame.new(position) * (self.root.CFrame - self.root.CFrame.Position)
end

function MovementController:_endPhase()
	local root = self.root
	root.Anchored = false
	root.CFrame = CFrame.new(self._phase.to.Position) * (root.CFrame - root.CFrame.Position)

	local exit = self:_lookDirection() * (self._phase.postSpeed or 24)
	root.AssemblyLinearVelocity = Vector3.new(exit.X, math.min(root.AssemblyLinearVelocity.Y, 0), exit.Z)
	self.speed = self._phase.postSpeed or 24
	self:_setState(self.grounded and MovementState.Walk or MovementState.Air)
end

----------------------------------------------------------------------
-- Stamina
----------------------------------------------------------------------

function MovementController:_drainStamina(amount: number)
	if amount <= 0 then
		return
	end
	local previous = self.stamina
	self.stamina = math.max(0, self.stamina - amount * self.modifiers.staminaDrain)
	self._lastStaminaDrainAt = os.clock()
	if self.stamina <= 0 then
		self.exhausted = true
	end
	if previous ~= self.stamina then
		self.StaminaChanged:FireSync(self.stamina, self.exhausted)
	end
end

function MovementController:_updateStamina(dt: number)
	local cfg = MovementConfig.Stamina
	local previous = self.stamina

	if self.state == MovementState.Sprint then
		self.stamina = math.max(0, self.stamina - cfg.SprintDrain * self.modifiers.staminaDrain * dt)
		self._lastStaminaDrainAt = os.clock()
		if self.stamina <= 0 then
			self.exhausted = true
		end
	else
		local delay = if self.exhausted then cfg.ExhaustedRegenDelay else cfg.RegenDelay
		if os.clock() - self._lastStaminaDrainAt >= delay then
			self.stamina = math.min(cfg.Max, self.stamina + cfg.Regen * dt)
			if self.exhausted and self.stamina >= cfg.SprintMinimum then
				self.exhausted = false
			end
		end
	end

	if math.abs(previous - self.stamina) > 1e-3 then
		self.StaminaChanged:FireSync(self.stamina, self.exhausted)
	end
end

----------------------------------------------------------------------
-- Stance (crouch / slide height)
----------------------------------------------------------------------

function MovementController:_hasHeadroom(): boolean
	local origin = self.root.Position
	local result = workspace:Raycast(origin, UP * MovementConfig.Crouch.UncrouchClearance, self._raycastParams)
	return result == nil
end

function MovementController:_updateStance(dt: number)
	local targetOffset = 0
	if self.state == MovementState.Slide then
		targetOffset = -MovementConfig.Slide.HeightOffset
	elseif self.state == MovementState.Crouch then
		targetOffset = -MovementConfig.Crouch.HeightOffset
	end

	local rate = MovementConfig.Crouch.TransitionSpeed * dt
	self.viewHeightOffset += math.clamp(targetOffset - self.viewHeightOffset, -rate, rate)

	-- Lowering HipHeight sinks the character model with the camera, so a crouching
	-- player is genuinely a smaller target instead of just a lower viewpoint.
	if self.baseHipHeight then
		self.humanoid.HipHeight = math.max(self.baseHipHeight + self.viewHeightOffset * 0.55, 0.1)
	end
end

----------------------------------------------------------------------
-- Publishing (local listeners + network)
----------------------------------------------------------------------

function MovementController:_publish(dt: number)
	local root = self.root
	local velocity = root.AssemblyLinearVelocity
	local snapshot = self.snapshot

	snapshot.state = self.state
	snapshot.speed = self.speed
	snapshot.horizontalSpeed = horizontalOf(velocity).Magnitude
	snapshot.verticalSpeed = velocity.Y
	snapshot.stamina = self.stamina
	snapshot.grounded = self.grounded
	snapshot.position = root.Position
	snapshot.viewHeightOffset = self.viewHeightOffset
	snapshot.exhausted = self.exhausted

	self.Stepped:FireSync(dt, snapshot)

	-- Throttled, unreliable, tiny: this is telemetry for the server's audit and
	-- for other clients' cosmetic replication, not authoritative position.
	self._snapshotAccumulator += dt
	local interval = 1 / MovementConfig.Network.SnapshotRate
	if self._snapshotAccumulator >= interval then
		self._snapshotAccumulator = 0
		Net.toServer(
			"MovementSnapshot",
			MovementState.ToId[self.state] or 1,
			snapshot.position,
			snapshot.horizontalSpeed,
			self.grounded
		)
	end
end

function MovementController:_reportEvent(kind: string, payload)
	Net.toServer("MovementEvent", kind, payload)
end

----------------------------------------------------------------------
-- Public API used by other controllers
----------------------------------------------------------------------

function MovementController:GetSnapshot()
	return self.snapshot
end

function MovementController:GetState(): string
	return self.state
end

function MovementController:IsSprinting(): boolean
	return self.state == MovementState.Sprint
end

--[[ Current slide heading, for the effects layer's floor trail. ]]
function MovementController:GetSlideDirection(): Vector3
	return self._slide.direction
end

function MovementController:SetModifier(name: string, value)
	self.modifiers[name] = value
end

function MovementController:SetFrozen(frozen: boolean)
	self.modifiers.frozen = frozen
	if frozen and self.root then
		self.root.AssemblyLinearVelocity = ZERO
		self.speed = 0
		if self.humanoid then
			self.humanoid.WalkSpeed = 0
		end
		self:_setState(MovementState.Idle)
	end
end

--[[ Applied by Overdrive. One call configures every affected system. ]]
function MovementController:ApplyOverdrive(config, active: boolean)
	if active then
		self.modifiers.speed = config.SpeedMultiplier
		self.modifiers.accel = config.AccelMultiplier
		self.modifiers.staminaDrain = config.StaminaDrainMultiplier
		self.modifiers.slideCooldown = config.SlideCooldownMultiplier
	else
		self.modifiers.speed = 1
		self.modifiers.accel = 1
		self.modifiers.staminaDrain = 1
		self.modifiers.slideCooldown = 1
	end
end

return MovementController
