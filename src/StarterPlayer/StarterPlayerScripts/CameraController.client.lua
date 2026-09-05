--[[
	CameraController
	Fully scriptable FPS camera (brief section 35). Runs independently of
	Roblox's default vehicle camera restrictions so mouselook stays free even
	while the player is seated on the scooter. Reads ADS/boost/recoil state
	from ClientState so WeaponController and ScooterController don't need to
	know anything about the camera directly.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local ScooterData = require(ReplicatedStorage.Shared.ScooterData)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

camera.CameraType = Enum.CameraType.Scriptable
ClientState.Camera.InputEnabled = true

local yaw, pitch = 0, 0
local currentFOV = ClientState.Camera.FOVBase

local function updateMouseLock()
	if ClientState.Camera.InputEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end
updateMouseLock()

UserInputService.InputChanged:Connect(function(input)
	if not ClientState.Camera.InputEnabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		local sensitivity = 0.0025 + (ClientState.Camera.Sensitivity * 0.006)
		yaw -= input.Delta.X * sensitivity
		pitch = math.clamp(pitch - input.Delta.Y * sensitivity, math.rad(-85), math.rad(85))
	end
end)

local function getEyeCFrame()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head then
		return head.CFrame
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.CFrame * CFrame.new(0, 1.5, 0)
	end
	return camera.CFrame
end

local function targetFOV()
	local weaponId = ClientState.Weapon.EquippedWeaponId
	local weapon = weaponId and WeaponData.Get(weaponId)

	if ClientState.Weapon.ADS and weapon and weapon.ADSZoomFOV then
		return weapon.ADSZoomFOV
	elseif ClientState.Scooter.Boosting then
		return ScooterData.Camera.BoostFOV
	end
	return ClientState.Camera.FOVBase
end

RunService.RenderStepped:Connect(function(dt)
	updateMouseLock()

	-- Recoil recovers over time; ADS holds it slightly longer for readability.
	local weaponId = ClientState.Weapon.EquippedWeaponId
	local weapon = weaponId and WeaponData.Get(weaponId)
	local recovery = (weapon and weapon.Recoil and weapon.Recoil.Recovery) or 6
	ClientState.Camera.RecoilPitch = math.max(0, ClientState.Camera.RecoilPitch - recovery * dt)
	ClientState.Camera.RecoilYaw *= math.max(0, 1 - recovery * dt)

	-- Camera shake decay.
	local shakeOffset = Vector3.zero
	if ClientState.Camera.ShakeDuration > 0 and ClientState.Camera.CameraShakeEnabled then
		ClientState.Camera.ShakeDuration = math.max(0, ClientState.Camera.ShakeDuration - dt)
		local magnitude = ClientState.Camera.ShakeMagnitude * (ClientState.Camera.ShakeDuration > 0 and 1 or 0)
		shakeOffset = Vector3.new(
			(math.random() - 0.5) * magnitude,
			(math.random() - 0.5) * magnitude,
			0
		)
		if ClientState.Camera.ShakeDuration <= 0 then
			ClientState.Camera.ShakeMagnitude = 0
		end
	end

	local eye = getEyeCFrame()
	local recoilRad = math.rad(ClientState.Camera.RecoilPitch)
	local recoilYawRad = math.rad(ClientState.Camera.RecoilYaw)

	local rotation = CFrame.Angles(0, yaw + recoilYawRad, 0) * CFrame.Angles(pitch + recoilRad, 0, 0)
	camera.CFrame = CFrame.new(eye.Position + shakeOffset) * rotation

	currentFOV += (targetFOV() - currentFOV) * math.clamp(dt * 8, 0, 1)
	camera.FieldOfView = currentFOV
end)
