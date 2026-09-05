--[[
	ScooterController
	Arcade scooter driving feel (brief sections 4-7). The scooter's VehicleSeat
	has its own physics zeroed out at build time (ScooterBuilder); this script
	drives it instead with a BodyVelocity (horizontal speed) + BodyAngularVelocity
	(turning) pair so it still collides with the world and respects gravity/jumps,
	while acceleration/turning/drift/boost feel fully arcade and hand-tuned.

	Drift note: the brief's control list only reserves W/S/A/D/Shift/Space, so
	drift isn't a separate button — it engages automatically when turning
	sharply while braking (S + A/D) above DriftMinSpeed, like classic arcade
	kart games.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ScooterData = require(ReplicatedStorage.Shared.ScooterData)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local Physics = ScooterData.Physics

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BoostRemote = Remotes:WaitForChild("Boost")
local ScooterAction = Remotes:WaitForChild("ScooterAction")
local BoostStateChanged = Remotes:WaitForChild("BoostStateChanged")

local currentScooterModel
local currentSpeed = 0
local driftTime = 0

BoostStateChanged.OnClientEvent:Connect(function(meter, active)
	ClientState.Scooter.BoostMeter = meter
	ClientState.Scooter.Boosting = active
end)

ClientState.Actions.SetBoost = function(active)
	BoostRemote:FireServer(active)
end

ClientState.Actions.Jump = function()
	ClientState.Scooter.JumpQueued = true
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		ClientState.Actions.Jump()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
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

local function ensureMovers(primary)
	local bodyVelocity = primary:FindFirstChild("ScooterBodyVelocity")
	if not bodyVelocity then
		bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Name = "ScooterBodyVelocity"
		bodyVelocity.MaxForce = Vector3.new(1e6, 0, 1e6)
		bodyVelocity.P = 3000
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity.Parent = primary
	end

	local bodyAngular = primary:FindFirstChild("ScooterBodyAngular")
	if not bodyAngular then
		bodyAngular = Instance.new("BodyAngularVelocity")
		bodyAngular.Name = "ScooterBodyAngular"
		bodyAngular.MaxTorque = Vector3.new(0, 1e6, 0)
		bodyAngular.AngularVelocity = Vector3.zero
		bodyAngular.Parent = primary
	end

	return bodyVelocity, bodyAngular
end

local function isGrounded(primary)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { primary.Parent, player.Character }
	local result = Workspace:Raycast(primary.Position, Vector3.new(0, -3.2, 0), params)
	return result ~= nil
end

RunService.Heartbeat:Connect(function(dt)
	local scooter = findMyScooter()
	if not scooter then
		currentScooterModel = nil
		ClientState.Scooter.Speed = 0
		return
	end

	if scooter ~= currentScooterModel then
		currentScooterModel = scooter
		currentSpeed = 0
		driftTime = 0
	end

	local seat = scooter:FindFirstChild("DriverSeat")
	local primary = scooter.PrimaryPart
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not seat or not primary or not humanoid or seat.Occupant ~= humanoid then
		return
	end

	local bodyVelocity, bodyAngular = ensureMovers(primary)

	local throttle = seat.Throttle
	local steer = seat.Steer
	local boosting = ClientState.Scooter.Boosting
	local topSpeed = boosting and Physics.BoostSpeed or Physics.MaxSpeed

	if boosting then
		currentSpeed = math.min(currentSpeed + Physics.Acceleration * 2.2 * dt, Physics.BoostSpeed)
	elseif throttle > 0 then
		currentSpeed = math.min(currentSpeed + Physics.Acceleration * dt, topSpeed)
	elseif throttle < 0 then
		if currentSpeed > 0 then
			currentSpeed = math.max(currentSpeed - Physics.Braking * dt, 0)
		else
			currentSpeed = math.max(currentSpeed - Physics.Acceleration * 0.6 * dt, -Physics.ReverseSpeed)
		end
	else
		if currentSpeed > 0 then
			currentSpeed = math.max(currentSpeed - Physics.Braking * 0.4 * dt, 0)
		elseif currentSpeed < 0 then
			currentSpeed = math.min(currentSpeed + Physics.Braking * 0.4 * dt, 0)
		end
	end

	local isDrifting = steer ~= 0 and throttle < 0 and currentSpeed > Physics.DriftMinSpeed
	ClientState.Scooter.Drifting = isDrifting

	local turnMultiplier = 1
	if isDrifting then
		turnMultiplier = Physics.DriftTurnMultiplier
		currentSpeed *= Physics.DriftSpeedRetention
		driftTime += dt
		if driftTime > 0.6 then
			ScooterAction:FireServer({ Type = "DriftReward", Amount = Physics.DriftBoostRewardPerSecond * dt })
		end
	else
		driftTime = 0
	end

	local speedFactor = math.clamp(math.abs(currentSpeed) / Physics.MaxSpeed, 0, 1)
	local turnSpeed = Physics.TurnSpeed - (Physics.TurnSpeed - Physics.TurnSpeedHighSpeed) * speedFactor
	local turnDirection = currentSpeed < 0 and -1 or 1
	local angularY = -math.rad(turnSpeed * turnMultiplier) * steer * turnDirection

	bodyAngular.AngularVelocity = Vector3.new(0, angularY, 0)

	local forward = primary.CFrame.LookVector
	bodyVelocity.Velocity = Vector3.new(forward.X, 0, forward.Z) * currentSpeed

	if ClientState.Scooter.JumpQueued then
		ClientState.Scooter.JumpQueued = false
		if isGrounded(primary) then
			local vel = primary.AssemblyLinearVelocity
			primary.AssemblyLinearVelocity = Vector3.new(vel.X, Physics.JumpPower, vel.Z)
		end
	end

	local trail = scooter:FindFirstChild("Deck") and scooter.Deck:FindFirstChild("BoostTrail")
	if trail then
		trail.Enabled = boosting or isDrifting
	end

	ClientState.Scooter.Speed = currentSpeed
	ClientState.Scooter.MaxSpeed = Physics.MaxSpeed
end)
