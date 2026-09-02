--!nonstrict
--[[
	CameraController.luau
	First-person camera. Everything here is spring-driven and bounded.

	The rule this file exists to enforce: THE CAMERA NEVER FIGHTS THE PLAYER.
	Feel is communicated through FOV, a couple of degrees of roll, and a small
	view bob. There is no traumatic screen shake anywhere in HYPER BLAST - a
	shake big enough to be exciting is a shake big enough to lose a duel to, and
	we would rather sell speed with FOV and trails than with noise.

	Every effect below is capped by MovementConfig.Camera.MaxShake / MaxFovAdd.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local MovementConfig = require(Root.Config.MovementConfig)
local MovementState = require(Root.Shared.MovementState)
local Spring = require(Root.Util.Spring)
local Trove = require(Root.Util.Trove)

local LocalPlayer = Players.LocalPlayer

local CameraController = {}
CameraController.__index = CameraController

local CameraCfg = MovementConfig.Camera

function CameraController.new(context)
	local self = setmetatable({}, CameraController)

	self.context = context
	self._trove = Trove.new()

	self.fovSpring = Spring.new(CameraCfg.BaseFov, CameraCfg.FovSpring.frequency, CameraCfg.FovSpring.damping)
	self.rollSpring = Spring.new(0, CameraCfg.RollSpring.frequency, CameraCfg.RollSpring.damping)
	self.offsetSpring = Spring.new(Vector3.zero, 5.0, 0.75) -- landing dip + kick
	self.recoilSpring = Spring.new(Vector2.zero, 6.5, 0.62) -- pitch/yaw in degrees

	self.bobPhase = 0
	self.adsFov = nil :: number?
	self.adsAlpha = 0
	self.adsSensitivity = 1
	self.extraFov = 0 -- ability-driven, decays on its own
	self.enabled = true

	return self
end

function CameraController:Start()
	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	LocalPlayer.CameraMinZoomDistance = 0.5
	LocalPlayer.CameraMaxZoomDistance = 0.5

	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = CameraCfg.BaseFov
	end

	-- Bind AFTER the default camera script so our offsets are applied last.
	RunService:BindToRenderStep("HyperBlast_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local ok, err = pcall(self._render, self, math.min(dt, 1 / 15))
		if not ok then
			warn(`[Camera] render error: {err}`)
		end
	end)
	self._trove:Fn(function()
		RunService:UnbindFromRenderStep("HyperBlast_Camera")
	end)

	local movement = self.context.Movement
	self._trove:Connect(movement.Landed, function(fallSpeed, _horizontal, heavy)
		local dip = if heavy then CameraCfg.LandDip.heavy else CameraCfg.LandDip.light
		-- Scale by fall speed but hard-clamp: a 200-stud fall dips no more than a
		-- 60-stud one, because a big dip is exactly when you need to see.
		local scaled = math.clamp(dip * (fallSpeed / CameraCfg.LandDipHeavyFallSpeed), 0.08, CameraCfg.MaxShake)
		self.offsetSpring:Impulse(Vector3.new(0, -scaled * 22, 0))
	end)

	self._trove:Connect(movement.WallJumped, function(_position, normal)
		-- A tiny lateral nudge away from the wall: enough to feel the kick,
		-- small enough that your crosshair is still on target.
		local camera = workspace.CurrentCamera
		if camera then
			local lateral = camera.CFrame.RightVector:Dot(normal)
			self.rollSpring:Impulse(-lateral * 26)
		end
	end)

	self._trove:Connect(movement.DashStarted, function(_direction, config)
		self:PulseFov(config.Fov or 12, 0.28)
	end)

	self._trove:Connect(movement.PhaseStarted, function(_from, _to, config)
		self:PulseFov(config.Fov or 6, 0.22)
	end)

	self._trove:Connect(movement.PadLaunched, function()
		self:PulseFov(10, 0.35)
	end)

	return self
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

--[[ Weapon ADS. `alpha` is the 0..1 blend so the FOV and sensitivity ease
	 together with the viewmodel instead of snapping between two states. ]]
function CameraController:SetAds(fov: number?, alpha: number, sensitivityScale: number?)
	self.adsFov = fov
	self.adsAlpha = math.clamp(alpha, 0, 1)
	self.adsSensitivity = sensitivityScale or 1
end

--[[ Camera recoil, in degrees. Also moves the aim, so patterns must be pulled
	 down by the player - that's the skill being tested. ]]
function CameraController:AddRecoil(pitch: number, yaw: number)
	self.recoilSpring:Impulse(Vector2.new(pitch, yaw) * 34)
end

function CameraController:SetRecoilRecovery(frequency: number, damping: number?)
	self.recoilSpring.Frequency = frequency
	self.recoilSpring.Damping = damping or self.recoilSpring.Damping
end

function CameraController:PulseFov(amount: number, duration: number)
	self.extraFov = math.min(self.extraFov + amount, CameraCfg.MaxFovAdd)
	task.delay(duration, function()
		self.extraFov = math.max(0, self.extraFov - amount)
	end)
end

--[[ Bounded positional impulse. The ONLY way anything in the game shakes the
	 camera, and it clamps to MaxShake. Weapons use it for a subtle kick. ]]
function CameraController:Kick(offset: Vector3)
	local clamped = offset
	if clamped.Magnitude > CameraCfg.MaxShake then
		clamped = clamped.Unit * CameraCfg.MaxShake
	end
	self.offsetSpring:Impulse(clamped * 20)
end

function CameraController:SetEnabled(enabled: boolean)
	self.enabled = enabled
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------

function CameraController:_targetFov(snapshot): number
	local base = CameraCfg.BaseFov
	local add = 0

	if snapshot then
		local sprintSpeed = MovementConfig.Speed.Sprint
		if snapshot.state == MovementState.Sprint then
			add += CameraCfg.SprintFovAdd
		elseif snapshot.state == MovementState.Slide then
			add += CameraCfg.SlideFovAdd
		end

		-- Speed-linked FOV is the primary "you are going fast" readout. It scales
		-- with real horizontal speed, so a preserved-momentum landing still reads
		-- as fast even though the state says "Walk".
		local excess = math.max(snapshot.horizontalSpeed - sprintSpeed, 0)
		add += excess * CameraCfg.SpeedFovScale
	end

	add = math.min(add + self.extraFov, CameraCfg.MaxFovAdd)
	local target = base + add

	if self.adsFov and self.adsAlpha > 0 then
		target = target + (self.adsFov - target) * self.adsAlpha
	end

	return target
end

function CameraController:_targetRoll(snapshot): number
	local camera = workspace.CurrentCamera
	if not camera or not snapshot then
		return 0
	end

	local humanoid = self.context.Movement.humanoid
	if not humanoid then
		return 0
	end

	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude < 0.05 then
		return 0
	end

	local lateral = camera.CFrame.RightVector:Dot(moveDirection)
	local amount = if snapshot.state == MovementState.Slide
		then MovementConfig.Slide.CameraRoll
		elseif snapshot.grounded then CameraCfg.StrafeRoll
		else CameraCfg.AirRoll

	-- Roll leans INTO the movement and is scaled down while aiming: precision
	-- beats flourish the moment the player commits to a shot.
	return -lateral * amount * (1 - self.adsAlpha * 0.85)
end

function CameraController:_updateBob(dt: number, snapshot): Vector3
	if not snapshot or not snapshot.grounded or snapshot.horizontalSpeed < 1 then
		self.bobPhase = 0
		return Vector3.zero
	end

	local speedRatio = snapshot.horizontalSpeed / MovementConfig.Speed.Sprint
	self.bobPhase += dt * CameraCfg.BobFrequency * speedRatio

	local amplitude = CameraCfg.BobAmplitude * math.min(speedRatio, 1.4) * (1 - self.adsAlpha * 0.9)
	return Vector3.new(
		math.cos(self.bobPhase * 0.5) * amplitude * 0.6,
		math.abs(math.sin(self.bobPhase)) * amplitude,
		0
	)
end

function CameraController:_render(dt: number)
	local camera = workspace.CurrentCamera
	if not camera or not self.enabled then
		return
	end

	local movement = self.context.Movement
	local snapshot = movement and movement:GetSnapshot()
	local humanoid = movement and movement.humanoid

	-- FOV -------------------------------------------------------------
	self.fovSpring:SetTarget(self:_targetFov(snapshot))
	camera.FieldOfView = self.fovSpring:Update(dt)

	-- Stance height. Humanoid.CameraOffset moves the eye with the body, so a
	-- crouching player's view matches their (genuinely smaller) hitbox.
	if humanoid and snapshot then
		local bob = self:_updateBob(dt, snapshot)
		local dip = self.offsetSpring:Update(dt)
		humanoid.CameraOffset = Vector3.new(
			bob.X + dip.X,
			(snapshot.viewHeightOffset or 0) * 0.45 + bob.Y + dip.Y,
			dip.Z
		)
	end

	-- Roll + recoil ----------------------------------------------------
	self.rollSpring:SetTarget(self:_targetRoll(snapshot))
	local roll = self.rollSpring:Update(dt)

	self.recoilSpring:SetTarget(Vector2.zero)
	local recoil = self.recoilSpring:Update(dt)

	camera.CFrame = camera.CFrame
		* CFrame.Angles(math.rad(recoil.X), math.rad(recoil.Y), math.rad(roll))

	-- ADS sensitivity. Scaling the raw mouse delta keeps the *angular* sensitivity
	-- consistent between hip and scope, which is what muscle memory actually wants.
	local sensitivity = 1 + (self.adsSensitivity - 1) * self.adsAlpha
	UserInputService.MouseDeltaSensitivity = math.clamp(sensitivity, 0.1, 1)
end

function CameraController:Destroy()
	UserInputService.MouseDeltaSensitivity = 1
	self._trove:Clean()
end

return CameraController
