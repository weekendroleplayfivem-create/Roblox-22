--!strict
-- Drives the local player's car: input, arcade physics (we own the car's physics),
-- nitro, drift smoke and the chase camera.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarPhysics = require(Shared:WaitForChild("CarPhysics"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NitroState = Remotes:WaitForChild("NitroState") :: RemoteEvent
local RespawnCar = Remotes:WaitForChild("RespawnCar") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Drive = {}

Drive.Car = nil :: Model?
Drive.State = nil :: CarPhysics.State?
Drive.Speed = 0
Drive.Nitro = 1
Drive.NitroCapacity = 1
Drive.NitroOn = false
Drive.Drifting = false

local seat: VehicleSeat? = nil
local handbrake = false
local nitroHeld = false
local keyThrottle = 0
local keySteer = 0
local sentNitro = false
local camPos: Vector3? = nil
local camLook: Vector3? = nil

local function stat(car: Model, name: string, default: number): number
	local v = car:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function setNitroVisual(on: boolean)
	if on ~= sentNitro then
		sentNitro = on
		NitroState:FireServer(on)
	end
end

local function attach(newSeat: VehicleSeat?)
	seat = nil
	Drive.Car = nil
	Drive.State = nil
	if not newSeat or newSeat.Name ~= "DriverSeat" then
		return
	end
	local car = newSeat.Parent
	if not car or not car:IsA("Model") or car:GetAttribute("Owner") ~= player.UserId then
		return
	end
	seat = newSeat
	Drive.Car = car
	local state = CarPhysics.NewState(car)
	if player.Character then
		CarPhysics.SetIgnore(state, { player.Character })
	end
	Drive.State = state
	Drive.NitroCapacity = stat(car, "nitroCapacity", 1)
	Drive.Nitro = math.min(Drive.Nitro, Drive.NitroCapacity)
	camPos = nil
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") then
			attach(seatPart)
		else
			attach(nil)
		end
	end)
	if humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat") then
		attach(humanoid.SeatPart)
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local function handleHandbrake(_name: string, inputState: Enum.UserInputState, _obj: InputObject)
	handbrake = inputState == Enum.UserInputState.Begin
	return if Drive.Car then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end

local function handleNitro(_name: string, inputState: Enum.UserInputState, _obj: InputObject)
	nitroHeld = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

local function handleReset(_name: string, inputState: Enum.UserInputState, _obj: InputObject)
	if inputState == Enum.UserInputState.Begin then
		RespawnCar:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority("WU_Handbrake", handleHandbrake, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonX)
ContextActionService:BindActionAtPriority("WU_Nitro", handleNitro, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonA)
ContextActionService:BindActionAtPriority("WU_Reset", handleReset, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("WU_Handbrake", "DRIFT")
ContextActionService:SetTitle("WU_Nitro", "NOS")
ContextActionService:SetTitle("WU_Reset", "RESET")
pcall(function()
	ContextActionService:SetPosition("WU_Nitro", UDim2.new(1, -170, 1, -170))
	ContextActionService:SetPosition("WU_Handbrake", UDim2.new(1, -95, 1, -230))
	ContextActionService:SetPosition("WU_Reset", UDim2.new(1, -95, 0, 80))
end)

-- Fallback keyboard reading in case the default vehicle controls are disabled.
local function readKeys()
	if UserInputService:GetFocusedTextBox() then
		keyThrottle, keySteer = 0, 0
		return
	end
	local t, s = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		t += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		t -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		s += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		s -= 1
	end
	keyThrottle, keySteer = t, s
end

---------------------------------------------------------------------------
-- Physics (runs before each physics step)
---------------------------------------------------------------------------
RunService.PreSimulation:Connect(function(dt: number)
	local car = Drive.Car
	local state = Drive.State
	local s = seat
	if not car or not state or not s or not car.Parent or not car.PrimaryPart then
		Drive.Speed = 0
		setNitroVisual(false)
		return
	end
	readKeys()
	local throttle = s.ThrottleFloat
	local steer = s.SteerFloat
	if math.abs(keyThrottle) > math.abs(throttle) then
		throttle = keyThrottle
	end
	if math.abs(keySteer) > math.abs(steer) then
		steer = keySteer
	end

	local capacity = stat(car, "nitroCapacity", 1)
	Drive.NitroCapacity = capacity
	local nitroOn = nitroHeld and Drive.Nitro > 0.02 and throttle > 0
	if nitroOn then
		Drive.Nitro = math.max(0, Drive.Nitro - dt * 0.3)
	end
	Drive.NitroOn = nitroOn
	setNitroVisual(nitroOn)

	local stats: CarPhysics.Stats = {
		maxSpeed = stat(car, "maxSpeed", 130),
		accel = stat(car, "accel", 40),
		brake = stat(car, "brake", 90),
		turn = stat(car, "turn", 2.3),
		grip = stat(car, "grip", 6),
		nitroMult = stat(car, "nitroMult", 1.3),
	}
	CarPhysics.Step(state, { throttle = throttle, steer = steer, handbrake = handbrake, nitro = nitroOn }, stats, dt)

	local speed = state.root.AssemblyLinearVelocity.Magnitude
	Drive.Speed = speed
	local drifting = state.grounded and math.abs(state.lateral) > 12 and speed > 35
	Drive.Drifting = drifting

	-- Unbound style nitro refill: drifting, airtime and raw speed all earn boost
	if not nitroOn then
		local gain = 0.01
		if drifting then
			gain += 0.22
		end
		if not state.grounded and state.airTime > 0.3 then
			gain += 0.35
		end
		if speed > 110 then
			gain += 0.03
		end
		Drive.Nitro = math.min(capacity, Drive.Nitro + gain * dt)
	end

	local smokeAtt = state.root:FindFirstChild("Smoke")
	local smoke = smokeAtt and smokeAtt:FindFirstChild("DriftSmoke") :: ParticleEmitter?
	if smoke then
		smoke.Enabled = drifting
	end
end)

---------------------------------------------------------------------------
-- Chase camera
---------------------------------------------------------------------------
RunService:BindToRenderStep("WU_ChaseCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local car = Drive.Car
	local root = car and car.PrimaryPart
	if not car or not root then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local cf = root.CFrame
	local vel = root.AssemblyLinearVelocity
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if flatLook.Magnitude < 0.1 then
		flatLook = -Vector3.zAxis
	end
	flatLook = flatLook.Unit
	-- blend towards travel direction when drifting fast, like arcade racers
	local flatVel = Vector3.new(vel.X, 0, vel.Z)
	local dir = flatLook
	if flatVel.Magnitude > 30 and flatVel.Unit:Dot(flatLook) > 0 then
		dir = flatLook:Lerp(flatVel.Unit, 0.35).Unit
	end
	local speed = vel.Magnitude
	local back = 20 + math.clamp(speed / 12, 0, 8)
	local height = 7 + math.clamp(speed / 50, 0, 2)
	local desired = root.Position - dir * back + Vector3.new(0, height, 0)
	local lookAt = root.Position + dir * 12 + Vector3.new(0, 2.5, 0)
	local alpha = 1 - math.exp(-dt * 10)
	camPos = if camPos then (camPos :: Vector3):Lerp(desired, alpha) else desired
	camLook = if camLook then (camLook :: Vector3):Lerp(lookAt, alpha) else lookAt

	-- keep the camera out of buildings
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { car }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local from = root.Position + Vector3.new(0, 3, 0)
	local hit = workspace:Raycast(from, (camPos :: Vector3) - from, params)
	local finalPos = camPos :: Vector3
	if hit then
		finalPos = hit.Position + (from - hit.Position).Unit * 1.5
	end
	camera.CFrame = CFrame.lookAt(finalPos, camLook :: Vector3)
	local targetFov = 70 + math.clamp(speed / 6, 0, 22) + (if Drive.NitroOn then 10 else 0)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 4)
end)

return Drive
