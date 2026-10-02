--[[
	CameraController
	First-person arena camera built on top of Roblox's default camera.

	Each frame:
	  1. (before the default camera) remove last frame's cosmetic offset
	  2. default camera updates from player input
	  3. (after) apply permanent recoil rotation + a new cosmetic offset
	     (bob, shake, landing dip, slide tilt)
	Undoing the offset keeps bob/shake from drifting the player's aim, while
	recoil intentionally moves the aim (and recovers back down).

	Also handles: smooth FOV (sprint/slide/dash/ADS), mouse + controller
	sensitivity from Settings, first-person lock in matches.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Spring = require(Shared.Modules.Spring)
local MathUtil = require(Shared.Modules.MathUtil)
local PlayerConfig = require(Shared.Config.PlayerConfig)

local ClientState = require(script.Parent.ClientState)

local CameraController = {}

local player = Players.LocalPlayer
local CameraConfig = PlayerConfig.Camera

local fovSpring = Spring.new(CameraConfig.DefaultFov, CameraConfig.FovStiffness, CameraConfig.FovDamping)
local recoilSpring = Spring.new(Vector3.zero, 160, 18) -- x = pitch, y = yaw (radians)
local dipSpring = Spring.new(0, 140, 12)
local tiltSpring = Spring.new(0, 90, 14)
local punchSpring = Spring.new(Vector3.zero, 200, 16)

local lastOffset = CFrame.identity
local lastRecoil = Vector3.zero
local trauma = 0
local bobTime = 0
local aimFov: number? = nil
local fovKick = 0
local movementFovState = "Walk" -- Walk | Sprint | Slide
local slideTilt = false
local pendingLook = Vector2.zero -- (yaw, pitch) radians from touch aim-drag
local firstPerson = false
local movementSource = nil -- set by MovementController (avoids a require cycle)

local TRAUMA_DECAY = 1.6
local SHAKE_MAX_ANGLE = math.rad(2.2)
local GAMEPAD_EXTRA_RATE = math.rad(220) -- deg/s of extra turn at full stick, per +1 sensitivity
local THUMBSTICK_DEADZONE = 0.15

function CameraController:SetFirstPerson(enabled: boolean)
	firstPerson = enabled
	if enabled then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 16
	end
end

function CameraController:IsFirstPerson(): boolean
	return firstPerson
end

-- Aim-down-sights FOV (nil = not aiming).
function CameraController:SetAimFov(fov: number?)
	aimFov = fov
end

function CameraController:SetMovementState(state: string)
	movementFovState = state
	slideTilt = state == "Slide"
end

function CameraController:DashKick()
	fovKick = CameraConfig.DashFovKick
end

-- Permanent aim kick in degrees (recovers via the spring). `yawDegrees` is
-- signed so weapons can follow a learnable recoil pattern. `recovery` (the
-- weapon's Recoil.Recovery) sets how quickly the aim settles back.
function CameraController:Recoil(verticalDegrees: number, yawDegrees: number, recovery: number?)
	if recovery then
		recoilSpring.Stiffness = math.clamp(recovery * 14, 70, 220)
		recoilSpring.Damping = 2 * math.sqrt(recoilSpring.Stiffness) * 0.8
	end
	recoilSpring:Impulse(Vector3.new(math.rad(verticalDegrees), math.rad(yawDegrees), 0) * 18)
end

-- Turns the camera permanently (used by the mobile fire button drag-to-aim).
function CameraController:AddLookDelta(yaw: number, pitch: number)
	pendingLook += Vector2.new(yaw, pitch)
end

function CameraController:Shake(amount: number)
	local scale = ClientState.GetSetting("CameraShake")
	trauma = math.min(CameraConfig.Shake.MaxIntensity, trauma + amount * scale)
end

function CameraController:Land(fallSpeed: number)
	local landing = CameraConfig.LandingShake
	if fallSpeed < landing.MinFallSpeed then
		return
	end
	local alpha = MathUtil.InverseLerp(landing.MinFallSpeed, landing.MaxFallSpeed, fallSpeed)
	dipSpring:Impulse(-landing.MaxDip * 12 * (0.3 + alpha) * ClientState.GetSetting("CameraShake"))
end

-- Small directional punch when taking damage.
function CameraController:DamagePunch(fromDirection: Vector3?)
	local camera = workspace.CurrentCamera
	local roll = 0
	if fromDirection and camera then
		local localDirection = camera.CFrame:VectorToObjectSpace(fromDirection)
		roll = math.sign(localDirection.X) * 0.03
	end
	punchSpring:Impulse(Vector3.new(0.02, 0, roll) * 20 * ClientState.GetSetting("CameraShake"))
end

local function targetFov(): number
	if aimFov then
		return aimFov
	end
	local base = ClientState.GetSetting("FieldOfView")
	local extra = 0
	if movementFovState == "Sprint" then
		extra = CameraConfig.SprintFov - CameraConfig.DefaultFov
	elseif movementFovState == "Slide" then
		extra = CameraConfig.SlideFov - CameraConfig.DefaultFov
	end
	return base + extra + fovKick
end

local function preCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame = camera.CFrame * lastOffset:Inverse()
	end
	lastOffset = CFrame.identity
end

local function postCamera(deltaTime: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	fovKick = MathUtil.Approach(fovKick, 0, 30 * deltaTime)
	fovSpring.Target = targetFov()
	camera.FieldOfView = math.clamp(fovSpring:Update(deltaTime), 20, 120)

	-- Sensitivity: slower while aiming so precision weapons feel controllable.
	local sensitivity = ClientState.GetSetting("MouseSensitivity")
	if aimFov then
		sensitivity *= aimFov / ClientState.GetSetting("FieldOfView")
	end
	UserInputService.MouseDeltaSensitivity = sensitivity

	if not firstPerson then
		trauma = 0
		pendingLook = Vector2.zero
		return
	end

	-- Permanent recoil (spring returns toward zero = recovery).
	recoilSpring.Target = Vector3.zero
	local recoil = recoilSpring:Update(deltaTime)
	local recoilDelta = recoil - lastRecoil
	lastRecoil = recoil

	-- Extra controller turn speed from the sensitivity setting.
	local gamepadDelta = CFrame.identity
	local gamepadSensitivity = ClientState.GetSetting("GamepadSensitivity")
	if gamepadSensitivity ~= 1 and UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then
		for _, input in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > THUMBSTICK_DEADZONE then
				local rate = GAMEPAD_EXTRA_RATE * (gamepadSensitivity - 1) * deltaTime
				gamepadDelta = CFrame.Angles(0, -input.Position.X * rate, 0)
					* CFrame.Angles(input.Position.Y * rate * 0.6, 0, 0)
			end
		end
	end

	local touchLook = CFrame.Angles(0, pendingLook.X, 0) * CFrame.Angles(pendingLook.Y, 0, 0)
	pendingLook = Vector2.zero

	-- Cosmetic offset (removed again next frame).
	trauma = math.max(0, trauma - TRAUMA_DECAY * deltaTime)
	local shake = trauma * trauma
	local now = os.clock()
	local shakePitch = math.noise(now * 18, 0.3) * SHAKE_MAX_ANGLE * shake
	local shakeYaw = math.noise(now * 18, 4.7) * SHAKE_MAX_ANGLE * shake
	local shakeRoll = math.noise(now * 18, 9.1) * SHAKE_MAX_ANGLE * shake

	local bobPitch, bobRoll, bobY = 0, 0, 0
	if movementSource then
		local speed, grounded = movementSource:GetBobInfo()
		if grounded and speed > 2 then
			local bob = CameraConfig.Bob
			local frequency = if speed > PlayerConfig.Movement.WalkSpeed + 2 then bob.SprintFrequency else bob.WalkFrequency
			bobTime += deltaTime * frequency
			local intensity = math.clamp(speed / PlayerConfig.Movement.SprintSpeed, 0, 1.2)
			bobY = math.sin(bobTime * 2) * bob.Amplitude * intensity
			bobRoll = math.rad(math.sin(bobTime) * bob.RollAmplitude * intensity)
			bobPitch = math.rad(math.cos(bobTime * 2) * bob.RollAmplitude * 0.4 * intensity)
		end
	end

	tiltSpring.Target = if slideTilt then math.rad(CameraConfig.SlideTilt) else 0
	local tilt = tiltSpring:Update(deltaTime)
	local dip = dipSpring:Update(deltaTime)
	local punch = punchSpring:Update(deltaTime)

	local offset = CFrame.new(0, bobY + dip, 0)
		* CFrame.Angles(shakePitch + bobPitch + punch.X, shakeYaw, shakeRoll + bobRoll + tilt + punch.Z)

	camera.CFrame = camera.CFrame * gamepadDelta * touchLook * CFrame.Angles(recoilDelta.X, recoilDelta.Y, 0) * offset
	lastOffset = offset
end

-- MovementController registers itself so the camera can read speed for bob.
function CameraController:SetMovementSource(source)
	movementSource = source
end

function CameraController:Init() end

function CameraController:Start()
	RunService:BindToRenderStep("VectorRushCameraPre", Enum.RenderPriority.Camera.Value - 1, preCamera)
	RunService:BindToRenderStep("VectorRushCameraPost", Enum.RenderPriority.Camera.Value + 1, postCamera)

	ClientState.Observe("Location", function(location)
		CameraController:SetFirstPerson(location == "Match")
	end)
end

return CameraController
