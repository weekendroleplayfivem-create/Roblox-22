--[[
	CameraController
	Fully scriptable FPS camera (brief section 35). Reads ADS/boost/recoil
	state from ClientState so WeaponController and ScooterController don't need
	to know anything about the camera directly.

	The camera type is re-asserted every frame — Roblox resets it to Custom on
	respawn, which would otherwise hand control back to the default camera
	mid-match.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local ScooterData = require(ReplicatedStorage.Shared.ScooterData)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer

-- Never cache CurrentCamera: Roblox swaps the camera instance on respawn, and
-- a stale reference is a black/frozen screen.
local function getCamera()
	return Workspace.CurrentCamera
end

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

local function getEyePosition()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head then
		return head.Position
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position + Vector3.new(0, 1.5, 0)
	end
	return getCamera().CFrame.Position
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

	local camera = getCamera()
	if not camera then
		return
	end
	-- Re-assert every frame: respawning resets this to Custom.
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local recoilRad = math.rad(ClientState.Camera.RecoilPitch)
	local recoilYawRad = math.rad(ClientState.Camera.RecoilYaw)
	local rotation = CFrame.Angles(0, yaw + recoilYawRad, 0) * CFrame.Angles(pitch + recoilRad, 0, 0)

	-- Push the eye slightly forward along the look direction so the camera can
	-- never end up inside the player's own head mesh.
	local eyePosition = getEyePosition() + shakeOffset + rotation.LookVector * 0.8
	camera.CFrame = CFrame.new(eyePosition) * rotation

	currentFOV += (targetFOV() - currentFOV) * math.clamp(dt * 8, 0, 1)
	camera.FieldOfView = currentFOV
end)

-- Keep the character's own body from ever obscuring the first-person view.
-- The engine resets LocalTransparencyModifier, so it has to be re-applied each
-- frame; the part list is cached so this isn't a per-frame tree walk.
local hiddenParts = {}

local function trackCharacter(character)
	table.clear(hiddenParts)
	local function track(instance)
		if instance:IsA("BasePart") or instance:IsA("Decal") then
			table.insert(hiddenParts, instance)
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		track(descendant)
	end
	character.DescendantAdded:Connect(track)
end

if player.Character then
	trackCharacter(player.Character)
end
player.CharacterAdded:Connect(trackCharacter)

RunService.RenderStepped:Connect(function()
	for index = #hiddenParts, 1, -1 do
		local instance = hiddenParts[index]
		if instance.Parent then
			instance.LocalTransparencyModifier = 1
		else
			table.remove(hiddenParts, index)
		end
	end
end)
