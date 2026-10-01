--[[
	MovementController
	Responsive arcade movement for the local character:
	  sprint, crouch, slide (with cooldown), slide-jump momentum, double jump,
	  optional wall jumps (Shared/Modules/WallMovement), dash, jump pads,
	  low-gravity fields, phase speed boost, smooth acceleration/deceleration,
	  momentum that bleeds off slower in the air, landing feedback, footsteps.

	The character's physics is client-owned (normal for Roblox), so movement
	is applied here for zero-latency feel. The server's AntiCheatService
	checks speeds/teleports against PlayerConfig plus allowances granted by
	legitimate actions (dash, pads), and corrects impossible movement.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Maid = require(Shared.Modules.Maid)
local MathUtil = require(Shared.Modules.MathUtil)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local WallMovement = require(Shared.Modules.WallMovement)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local ClientState = require(script.Parent.ClientState)
local InputController = require(script.Parent.InputController)
local SoundController = require(script.Parent.SoundController)
local CameraController = require(script.Parent.CameraController)

local MovementController = {}

local player = Players.LocalPlayer
local Movement = PlayerConfig.Movement

local AIM_SPEED_MULTIPLIER = 0.75
local CROUCH_CAMERA_OFFSET = -1.2
local CAMERA_OFFSET_RATE = 14
local FIRE_SPRINT_BLOCK = 0.3
local SLIDE_AIR_GRACE = 0.2
local FOOTSTEP_STRIDE = 8

local characterMaid = Maid.new()
local controls = nil -- PlayerModule ControlModule

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local trail: Trail? = nil
local gravityForce: VectorForce? = nil
local dashConstraint: LinearVelocity? = nil

local state = {
	SprintToggled = false,
	Sprinting = false,
	SprintBlockedUntil = 0,
	Crouching = false,
	Sliding = false,
	SlideStart = 0,
	SlideStartSpeed = 0,
	SlideDirection = Vector3.zAxis,
	SlideCooldownUntil = 0,
	SlideAirTime = 0,
	Speed = Movement.WalkSpeed,
	Momentum = 0,
	Grounded = true,
	LeftGroundAt = 0,
	AirJumps = 0,
	WallJumps = 0,
	LastWall = nil :: Instance?,
	LastWallTime = 0,
	DashUntil = 0,
	DashDirection = Vector3.zAxis,
	MinVerticalVelocity = 0,
	JumpPadCooldown = 0,
	FootstepProgress = 0,
	Frozen = false,
}

-- Provided by WeaponController (avoids a require cycle).
local weaponInfo = {
	SpeedMultiplier = function()
		return 1
	end,
	IsAiming = function()
		return false
	end,
}

function MovementController:SetWeaponInfo(info)
	weaponInfo = info
end

function MovementController:GetBobInfo(): (number, boolean)
	if not root then
		return 0, false
	end
	return MathUtil.Flatten(root.AssemblyLinearVelocity).Magnitude, state.Grounded and not state.Sliding
end

function MovementController:IsSliding(): boolean
	return state.Sliding
end

function MovementController:IsSprinting(): boolean
	return state.Sprinting
end

function MovementController:IsGrounded(): boolean
	return state.Grounded
end

function MovementController:GetHorizontalSpeed(): number
	return if root then MathUtil.Flatten(root.AssemblyLinearVelocity).Magnitude else 0
end

-- Firing briefly drops you out of sprint.
function MovementController:NotifyFired()
	state.SprintBlockedUntil = os.clock() + FIRE_SPRINT_BLOCK
end

local function setControlsEnabled(enabled: boolean)
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

local function worldParams(): RaycastParams
	return RaycastUtil.WorldParams()
end

local function trailColor(): ColorSequence
	local profile = ClientState.Get("Profile")
	local item = profile and CosmeticConfig.Get(profile.Equipped.Trail)
	if item and item.Rainbow then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
		})
	end
	return ColorSequence.new(if item then item.Color else Color3.fromRGB(60, 230, 255))
end

local function setTrail(enabled: boolean)
	if trail then
		if enabled then
			trail.Color = trailColor()
		end
		trail.Enabled = enabled
	end
end

local function cameraLookFlat(): Vector3
	local camera = workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else Vector3.zAxis
	return MathUtil.SafeUnit(MathUtil.Flatten(look), Vector3.zAxis)
end

local function endSlide(carrySpeed: number?)
	if not state.Sliding then
		return
	end
	state.Sliding = false
	state.SlideCooldownUntil = os.clock() + Movement.Slide.Cooldown
	state.Momentum = math.max(state.Momentum, carrySpeed or Movement.Slide.EndSpeed)
	setControlsEnabled(true)
	if os.clock() > state.DashUntil then
		setTrail(false)
	end
end

local function startSlide()
	if not root or not humanoid then
		return
	end
	local horizontal = MathUtil.Flatten(root.AssemblyLinearVelocity)
	state.Sliding = true
	state.Crouching = false
	state.SlideStart = os.clock()
	state.SlideAirTime = 0
	state.SlideStartSpeed = math.max(Movement.SlideSpeed, horizontal.Magnitude)
	state.SlideDirection = MathUtil.SafeUnit(horizontal, cameraLookFlat())
	setControlsEnabled(false)
	setTrail(true)
	SoundController:Play("Slide", 0.05)
	Net.Event("Movement", "MovementAction"):FireServer("Slide")
end

local function endDash()
	if dashConstraint then
		dashConstraint:Destroy()
		dashConstraint = nil
	end
	if root then
		local carry = Movement.Dash.Speed * Movement.Dash.MomentumCarry
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(state.DashDirection.X * carry, velocity.Y, state.DashDirection.Z * carry)
		state.Momentum = math.max(state.Momentum, carry)
	end
	if not state.Sliding then
		setTrail(false)
	end
end

-- Called by AbilityController. Returns true if the dash happened.
function MovementController:Dash(): boolean
	if not root or not humanoid or humanoid.Health <= 0 or state.Frozen then
		return false
	end
	endSlide(nil)
	local moveDirection = humanoid.MoveDirection
	local direction = if moveDirection.Magnitude > 0.1 then MathUtil.SafeUnit(MathUtil.Flatten(moveDirection), cameraLookFlat()) else cameraLookFlat()
	local dash = Movement.Dash
	local duration = dash.Duration
	-- Never dash into/through walls: shorten the dash to stop before them.
	local result = workspace:Raycast(root.Position, direction * (dash.Speed * dash.Duration + dash.WallBuffer), worldParams())
	if result then
		duration = math.max(0, (result.Distance - dash.WallBuffer) / dash.Speed)
	end

	if dashConstraint then
		dashConstraint:Destroy()
	end
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end
	local constraint = Instance.new("LinearVelocity")
	constraint.Attachment0 = attachment :: Attachment
	constraint.RelativeTo = Enum.ActuatorRelativeTo.World
	constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	constraint.PrimaryTangentAxis = Vector3.xAxis
	constraint.SecondaryTangentAxis = Vector3.zAxis
	constraint.PlaneVelocity = Vector2.new(direction.X * dash.Speed, direction.Z * dash.Speed)
	constraint.MaxForce = math.huge
	constraint.Parent = root
	dashConstraint = constraint

	state.DashDirection = direction
	state.DashUntil = os.clock() + duration
	setTrail(true)
	CameraController:DashKick()
	SoundController:Play("Dash", 0.05)
	return true
end

local function tryAirJump()
	if not root or not humanoid then
		return
	end
	local now = os.clock()
	local airTime = now - state.LeftGroundAt

	-- Wall jump first (if enabled and a wall is close).
	local wallConfig = Movement.WallJump
	if WallMovement.IsEnabled() and airTime > wallConfig.MinAirTime and state.WallJumps < wallConfig.MaxPerAirtime then
		local normal, part = WallMovement.FindWall(root.Position, worldParams())
		if normal and part and (part ~= state.LastWall or now - state.LastWallTime > wallConfig.SameWallCooldown) then
			local camera = workspace.CurrentCamera
			local velocity = WallMovement.ComputeJumpVelocity(normal, if camera then camera.CFrame.LookVector else root.CFrame.LookVector)
			root.AssemblyLinearVelocity = velocity
			state.Momentum = math.max(state.Momentum, wallConfig.PushSpeed)
			state.WallJumps += 1
			state.LastWall = part
			state.LastWallTime = now
			state.MinVerticalVelocity = 0
			SoundController:Play("DoubleJump", 0.1)
			Net.Event("Movement", "MovementAction"):FireServer("WallJump")
			return
		end
	end

	-- Double jump.
	local jumpConfig = Movement.DoubleJump
	if jumpConfig.Enabled and airTime > jumpConfig.MinAirTime and state.AirJumps < jumpConfig.MaxPerAirtime then
		state.AirJumps += 1
		local velocity = root.AssemblyLinearVelocity
		local horizontal = MathUtil.Flatten(velocity)
		local moveDirection = humanoid.MoveDirection
		if moveDirection.Magnitude > 0.1 then
			-- Air redirect: keep speed but steer toward input.
			horizontal = MathUtil.SafeUnit(MathUtil.Flatten(moveDirection), horizontal) * math.max(horizontal.Magnitude, state.Speed)
		end
		root.AssemblyLinearVelocity = Vector3.new(horizontal.X, jumpConfig.Power, horizontal.Z)
		state.MinVerticalVelocity = 0
		SoundController:Play("DoubleJump", 0.1)
		Net.Event("Movement", "MovementAction"):FireServer("DoubleJump")
	end
end

local function onJumpPressed()
	if not humanoid or not root or state.Frozen or humanoid.Health <= 0 then
		return
	end
	if state.Sliding then
		local carry = state.SlideStartSpeed * Movement.Slide.JumpCarry
		endSlide(carry)
		humanoid.Jump = true
		return
	end
	if state.Grounded then
		humanoid.Jump = true -- touch jump button; keyboard/gamepad already jump natively
		return
	end
	tryAirJump()
end

local function onCrouchPressed()
	if not root or not humanoid or state.Frozen then
		return
	end
	local speed = MathUtil.Flatten(root.AssemblyLinearVelocity).Magnitude
	if state.Grounded and not state.Sliding and os.clock() >= state.SlideCooldownUntil
		and (state.Sprinting or speed >= Movement.Slide.MinStartSpeed) and speed >= Movement.Slide.MinStartSpeed
	then
		startSlide()
	elseif state.Grounded then
		state.Crouching = true
	end
end

local function updateGravityField()
	if not root or not gravityForce then
		return
	end
	local multiplier = nil
	for _, field in CollectionService:GetTagged(RaycastUtil.Tags.GravityField) do
		if field:IsA("BasePart") then
			local radius = field:GetAttribute("Radius") or field.Size.X / 2
			if (field.Position - root.Position).Magnitude <= radius then
				multiplier = field:GetAttribute("Multiplier") or 0.5
				break
			end
		end
	end
	if multiplier then
		gravityForce.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * (1 - multiplier), 0)
		gravityForce.Enabled = true
	else
		gravityForce.Enabled = false
	end
end

local function step(deltaTime: number)
	if not humanoid or not root or humanoid.Health <= 0 or not character then
		return
	end
	local now = os.clock()
	local frozen = character:GetAttribute("Frozen") == true
	state.Frozen = frozen
	if frozen then
		endSlide(0)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	humanoid.JumpPower = Movement.JumpPower

	-- Ground tracking.
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if grounded and not state.Grounded then
		state.AirJumps = 0
		state.WallJumps = 0
		state.LastWall = nil
	elseif not grounded and state.Grounded then
		state.LeftGroundAt = now
		state.MinVerticalVelocity = 0
	end
	state.Grounded = grounded
	local velocity = root.AssemblyLinearVelocity
	if not grounded then
		state.MinVerticalVelocity = math.min(state.MinVerticalVelocity, velocity.Y)
	end

	-- Dash lifetime.
	if dashConstraint and now >= state.DashUntil then
		endDash()
	end

	local moveDirection = humanoid.MoveDirection
	local horizontalSpeed = MathUtil.Flatten(velocity).Magnitude
	local aiming = weaponInfo.IsAiming()

	-- Sprint.
	local toggle = ClientState.GetSetting("ToggleSprint")
	local wantsSprint = if toggle then state.SprintToggled else InputController:IsDown("Sprint")
	local movingForward = moveDirection.Magnitude > 0.1 and moveDirection.Unit:Dot(cameraLookFlat()) > Movement.SprintForwardDot
	if moveDirection.Magnitude < 0.1 then
		state.SprintToggled = false
	end
	state.Sprinting = wantsSprint and movingForward and not state.Crouching and not aiming and not state.Sliding
		and now >= state.SprintBlockedUntil

	if state.Crouching and not InputController:IsDown("Crouch") then
		state.Crouching = false
	end

	local target = Movement.WalkSpeed
	if state.Sprinting then
		target = Movement.SprintSpeed
	elseif state.Crouching then
		target = Movement.CrouchSpeed
	end
	target *= weaponInfo.SpeedMultiplier()
	if aiming then
		target *= AIM_SPEED_MULTIPLIER
	end
	if character:GetAttribute("Phased") then
		target *= AbilityConfig.Get("Phase").SpeedMultiplier
	end

	if state.Sliding then
		local alpha = (now - state.SlideStart) / Movement.Slide.Duration
		local slideSpeed = MathUtil.Lerp(state.SlideStartSpeed, Movement.Slide.EndSpeed, math.clamp(alpha, 0, 1))
		humanoid.WalkSpeed = slideSpeed
		humanoid:Move(state.SlideDirection, false)
		state.SlideAirTime = if grounded then 0 else state.SlideAirTime + deltaTime
		if alpha >= 1 or state.SlideAirTime > SLIDE_AIR_GRACE then
			endSlide(slideSpeed)
		end
	else
		local rate = if target > state.Speed then Movement.Acceleration else Movement.Deceleration
		state.Speed = MathUtil.Approach(state.Speed, target, rate * deltaTime)
		local decay = if grounded then Movement.GroundMomentumDecay else Movement.AirMomentumDecay
		state.Momentum = math.max(0, state.Momentum - decay * deltaTime)
		humanoid.WalkSpeed = math.max(state.Speed, state.Momentum)
	end

	-- Camera height + FOV state.
	local cameraTarget = 0
	if state.Sliding then
		cameraTarget = Movement.Slide.CameraOffsetY
	elseif state.Crouching then
		cameraTarget = CROUCH_CAMERA_OFFSET
	end
	local offset = humanoid.CameraOffset
	humanoid.CameraOffset = Vector3.new(0, MathUtil.Lerp(offset.Y, cameraTarget, MathUtil.Damp(CAMERA_OFFSET_RATE, deltaTime)), 0)
	if state.Sliding then
		CameraController:SetMovementState("Slide")
	elseif state.Sprinting and horizontalSpeed > Movement.WalkSpeed + 2 then
		CameraController:SetMovementState("Sprint")
	else
		CameraController:SetMovementState("Walk")
	end

	updateGravityField()

	-- Footsteps.
	if grounded and not state.Sliding and horizontalSpeed > 4 then
		state.FootstepProgress += horizontalSpeed * deltaTime / FOOTSTEP_STRIDE
		if state.FootstepProgress >= 1 then
			state.FootstepProgress = 0
			SoundController:Play("Footstep", 0.12)
		end
	end
end

local function onJumpPad(pad: BasePart)
	if not root or not humanoid then
		return
	end
	local now = os.clock()
	if now < state.JumpPadCooldown then
		return
	end
	local velocity = pad:GetAttribute("LaunchVelocity")
	if typeof(velocity) ~= "Vector3" then
		return
	end
	state.JumpPadCooldown = now + Movement.JumpPad.Cooldown
	endSlide(nil)
	root.AssemblyLinearVelocity = velocity
	state.Momentum = math.max(state.Momentum, MathUtil.Flatten(velocity).Magnitude)
	state.AirJumps = 0
	state.WallJumps = 0
	state.LeftGroundAt = now
	SoundController:Play("JumpPad", 0.05)
	CameraController:Shake(0.25)
end

local function onCharacterAdded(newCharacter: Model)
	characterMaid:DoCleaning()
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	local hum = humanoid :: Humanoid
	local rootPart = root :: BasePart

	state.Sliding = false
	state.Crouching = false
	state.Momentum = 0
	state.Speed = Movement.WalkSpeed
	state.DashUntil = 0
	dashConstraint = nil
	setControlsEnabled(true)

	-- Movement trail (enabled while sliding/dashing).
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = rootPart
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.8, 0)
	bottom.Parent = rootPart
	local newTrail = Instance.new("Trail")
	newTrail.Attachment0 = top
	newTrail.Attachment1 = bottom
	newTrail.Lifetime = 0.25
	newTrail.LightEmission = 0.8
	newTrail.Transparency = NumberSequence.new(0.3, 1)
	newTrail.Enabled = false
	newTrail.Parent = rootPart
	trail = newTrail
	characterMaid:GiveTask(top)
	characterMaid:GiveTask(bottom)
	characterMaid:GiveTask(newTrail)

	-- Low-gravity support force.
	local forceAttachment = Instance.new("Attachment")
	forceAttachment.Parent = rootPart
	local force = Instance.new("VectorForce")
	force.Attachment0 = forceAttachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Enabled = false
	force.Parent = rootPart
	gravityForce = force
	characterMaid:GiveTask(forceAttachment)
	characterMaid:GiveTask(force)

	characterMaid:GiveTask(hum.Touched:Connect(function(hit)
		if hit:IsA("BasePart") and CollectionService:HasTag(hit, RaycastUtil.Tags.JumpPad) then
			onJumpPad(hit)
		end
	end))

	characterMaid:GiveTask(hum.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Landed then
			local fallSpeed = -state.MinVerticalVelocity
			CameraController:Land(fallSpeed)
			if fallSpeed > 25 then
				SoundController:Play("Land", 0.08)
			end
			state.MinVerticalVelocity = 0
		elseif new == Enum.HumanoidStateType.Jumping then
			SoundController:Play("Jump", 0.08)
		end
	end))

	characterMaid:GiveTask(hum.Died:Connect(function()
		endSlide(0)
		if dashConstraint then
			dashConstraint:Destroy()
			dashConstraint = nil
		end
		setControlsEnabled(true)
	end))
end

-- Lobby emotes (PLACEHOLDER procedural motions until animations exist).
function MovementController:PlayEmote(motion: string)
	if not humanoid or not root or not state.Grounded then
		return
	end
	if motion == "Spin" then
		local spinRoot = root
		task.spawn(function()
			for _ = 1, 12 do
				if not spinRoot.Parent then
					return
				end
				spinRoot.CFrame = spinRoot.CFrame * CFrame.Angles(0, math.rad(30), 0)
				task.wait(0.03)
			end
		end)
	else
		humanoid.Jump = true
	end
end

function MovementController:Init()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
	end)
	if ok and playerModule then
		controls = playerModule:GetControls()
	else
		warn("[MovementController] PlayerModule unavailable; slides will follow input direction")
	end
end

function MovementController:Start()
	CameraController:SetMovementSource(MovementController)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	InputController.ActionBegan:Connect(function(action)
		if action == "Jump" then
			onJumpPressed()
		elseif action == "Crouch" then
			onCrouchPressed()
		elseif action == "Sprint" then
			if ClientState.GetSetting("ToggleSprint") then
				state.SprintToggled = not state.SprintToggled
			end
		elseif action == "Emote" then
			local profile = ClientState.Get("Profile")
			local emote = profile and CosmeticConfig.Get(profile.Equipped.Emote)
			if emote and not ClientState.IsInMatch() then
				MovementController:PlayEmote(emote.Motion)
			end
		end
	end)

	-- Server rejected our movement: drop all local momentum.
	Net.Event("Movement", "Correction").OnClientEvent:Connect(function()
		state.Momentum = 0
		endSlide(0)
		if dashConstraint then
			dashConstraint:Destroy()
			dashConstraint = nil
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return MovementController
