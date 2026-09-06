--[[
	ScooterController
	Arcade scooter feel (brief sections 4-7), applied to the player's Humanoid.

	The scooter is a cosmetic rig welded under the character (ScooterBuilder),
	so movement rides Roblox's own character controller and always responds —
	no VehicleSeat, no client-authored BodyVelocity on a server-owned part.
	This script layers the arcade feel on top: a speed ramp instead of instant
	top speed, boost, drift, jump, and cosmetic lean.

	Controls: W/A/S/D move (camera-relative, so you steer by looking — the rig
	leans into turns), SHIFT boosts, SPACE jumps. Drifting engages
	automatically when you carve sideways at speed, and pays back boost meter.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ScooterData = require(ReplicatedStorage.Shared.ScooterData)
local ScooterBuilder = require(ReplicatedStorage.Shared.ScooterBuilder)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local Physics = ScooterData.Physics

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BoostRemote = Remotes:WaitForChild("Boost")
local ScooterAction = Remotes:WaitForChild("ScooterAction")
local BoostStateChanged = Remotes:WaitForChild("BoostStateChanged")

local currentSpeed = 0
local driftTime = 0
local leanAngle = 0

BoostStateChanged.OnClientEvent:Connect(function(meter, active)
	ClientState.Scooter.BoostMeter = meter
	ClientState.Scooter.Boosting = active
end)

ClientState.Actions.SetBoost = function(active)
	BoostRemote:FireServer(active)
end

ClientState.Actions.Jump = function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Jump = true
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		ClientState.Actions.SetBoost(true)
	end
end)

UserInputService.InputEnded:Connect(function(input, _processed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		ClientState.Actions.SetBoost(false)
	end
end)

local function findMyScooter()
	local scootersFolder = Workspace:FindFirstChild("Scooters")
	return scootersFolder and scootersFolder:FindFirstChild("Scooter_" .. player.UserId)
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		currentSpeed = 0
		ClientState.Scooter.Speed = 0
		ClientState.Scooter.Drifting = false
		return
	end

	local moveDirection = humanoid.MoveDirection
	local moving = moveDirection.Magnitude > 0.1
	local boosting = ClientState.Scooter.Boosting

	-- Speed ramp: you accelerate up to top speed rather than snapping to it,
	-- and coast back down when you let go.
	if moving then
		currentSpeed = math.max(currentSpeed, Physics.BaseSpeed)
		local target = boosting and Physics.BoostSpeed or Physics.MaxSpeed
		local accel = Physics.Acceleration * (boosting and 2.2 or 1)
		if currentSpeed < target then
			currentSpeed = math.min(currentSpeed + accel * dt, target)
		else
			currentSpeed = math.max(currentSpeed - Physics.Braking * dt, target)
		end
	else
		currentSpeed = math.max(currentSpeed - Physics.Braking * dt, 0)
	end

	-- Drift: carving hard sideways relative to where you're facing, at speed.
	local sideways = math.abs(moveDirection:Dot(root.CFrame.RightVector))
	local isDrifting = moving and currentSpeed > Physics.DriftMinSpeed and sideways > 0.55
	ClientState.Scooter.Drifting = isDrifting

	if isDrifting then
		currentSpeed *= (1 - (1 - Physics.DriftSpeedRetention) * dt * 6)
		driftTime += dt
		if driftTime > 0.6 then
			ScooterAction:FireServer({ Type = "DriftReward", Amount = Physics.DriftBoostRewardPerSecond * dt })
		end
	else
		driftTime = 0
	end

	-- Never fall below a walkable speed, so the player can always move even
	-- mid-ramp or right after respawning.
	humanoid.WalkSpeed = math.clamp(currentSpeed, Physics.BaseSpeed * 0.6, Physics.BoostSpeed)
	humanoid.JumpPower = Physics.JumpPower
	humanoid.UseJumpPower = true

	-- Cosmetic lean into the turn.
	local scooter = findMyScooter()
	if scooter then
		local deck = scooter.PrimaryPart
		local weld = deck and deck:FindFirstChild("ScooterWeld")
		local targetLean = -moveDirection:Dot(root.CFrame.RightVector) * (isDrifting and 0.5 or 0.25)
		leanAngle += (targetLean - leanAngle) * math.clamp(dt * 8, 0, 1)
		if weld then
			weld.C0 = ScooterBuilder.RideOffset * CFrame.Angles(0, 0, leanAngle)
		end

		local trail = deck and deck:FindFirstChild("BoostTrail")
		if trail then
			trail.Enabled = boosting or isDrifting
		end
	end

	ClientState.Scooter.Speed = currentSpeed
	ClientState.Scooter.MaxSpeed = Physics.MaxSpeed
end)
