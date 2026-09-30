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
local Config = require(Shared:WaitForChild("Config"))
local Settings = require(script.Parent.Settings)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NitroState = Remotes:WaitForChild("NitroState") :: RemoteEvent
local RespawnCar = Remotes:WaitForChild("RespawnCar") :: RemoteEvent
local NearMissEvent = Remotes:WaitForChild("NearMiss") :: RemoteEvent

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
Drive.Throttle = 0
Drive.Steer = 0
Drive.Handbrake = false
Drive.Flat = false
Drive.MenuOpen = false -- the title screen drives the camera while this is true
Drive.Shake = 0 -- camera shake impulse (crashes)
Drive.NearMissCombo = 0
Drive.OnNearMiss = {} :: { (combo: number) -> () }
Drive.OnCrash = {} :: { (strength: number) -> () }
Drive.OnBackfire = {} :: { () -> () }
Drive.OnShift = {} :: { (gear: number) -> () }
-- simulated drivetrain for the HUD tachometer and the engine sound
Drive.Gear = 1
Drive.Rpm = 0.2 -- 0..1
Drive.Gears = 6

local seat: VehicleSeat? = nil
local handbrake = false
local nitroHeld = false
local keyThrottle = 0
local keySteer = 0
local sentNitro = false
local camPos: Vector3? = nil
local lastSpeed = 0
local lastThrottle = 0
local smoothSteer = 0
local smoothThrottle = 0
local nearTrack: { [Model]: { min: number, rel: number, speed: number } } = setmetatable({}, { __mode = "k" }) :: any
local lastNearMiss = 0
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
	-- smooth the inputs: keyboard steering ramps in and recentres quickly, like a real rack
	local steerRate = if math.abs(steer) < math.abs(smoothSteer) or steer * smoothSteer < 0 then 9 else 5.5
	smoothSteer += (steer - smoothSteer) * math.min(1, dt * steerRate)
	steer = smoothSteer
	smoothThrottle += (throttle - smoothThrottle) * math.min(1, dt * 10)
	throttle = smoothThrottle

	local capacity = stat(car, "nitroCapacity", 1)
	Drive.NitroCapacity = capacity
	local nitroOn = nitroHeld and Drive.Nitro > 0.02 and throttle > 0 and car:GetAttribute("Flat") ~= true
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
		driftGrip = stat(car, "driftGrip", 0.4),
		downforce = stat(car, "downforce", 0.2),
	}
	-- spiked tyres: slow and slippery
	Drive.Flat = car:GetAttribute("Flat") == true
	if Drive.Flat then
		stats.maxSpeed *= Config.Spikes.FlatSpeedMult
		stats.grip *= Config.Spikes.FlatGripMult
		stats.turn *= 0.8
		nitroOn = false
	end
	Drive.Throttle = throttle
	Drive.Steer = steer
	Drive.Handbrake = handbrake
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

	-- drivetrain: pick a gear from road speed, rpm sweeps through each gear's band
	local maxSpd = stats.maxSpeed * (if nitroOn then stats.nitroMult else 1)
	local frac = math.clamp(math.abs(state.speed) / math.max(maxSpd, 1), 0, 1.05)
	local gear = if state.speed < -1 then 1 else math.clamp(math.floor(frac * Drive.Gears) + 1, 1, Drive.Gears)
	if gear ~= Drive.Gear then
		local up = gear > Drive.Gear
		Drive.Gear = gear
		if up then
			for _, fn in Drive.OnShift do
				task.spawn(fn, gear)
			end
		end
	end
	local band = frac * Drive.Gears - (gear - 1)
	local targetRpm = 0.22 + 0.72 * math.clamp(band, 0, 1)
	if not state.grounded or (handbrake and throttle > 0) then
		targetRpm = math.min(1, targetRpm + 0.25 * math.max(throttle, 0)) -- revving in the air / drifting
	end
	if math.abs(state.speed) < 3 then
		targetRpm = 0.18 + 0.45 * math.max(throttle, 0)
	end
	local prevThrottle = lastThrottle
	lastThrottle = throttle
	Drive.Rpm += (targetRpm - Drive.Rpm) * math.min(1, dt * 8)
	-- lifting off at high revs pops the exhaust
	if prevThrottle > 0.6 and throttle < 0.1 and Drive.Rpm > 0.6 and speed > 60 then
		for _, fn in Drive.OnBackfire do
			task.spawn(fn)
		end
	end

	-- crash detection (sudden loss of speed) for camera shake
	if lastSpeed - speed > 35 then
		local strength = math.clamp((lastSpeed - speed) / 80, 0.3, 1)
		Drive.Shake = math.max(Drive.Shake, strength)
		for _, fn in Drive.OnCrash do
			task.spawn(fn, strength)
		end
	end
	lastSpeed = speed

	local smokeAtt = state.root:FindFirstChild("Smoke")
	local smoke = smokeAtt and smokeAtt:FindFirstChild("DriftSmoke") :: ParticleEmitter?
	if smoke then
		smoke.Enabled = drifting
	end
end)

---------------------------------------------------------------------------
-- Near misses: pass traffic close and fast without touching it (Unbound)
---------------------------------------------------------------------------
local TR = Config.Traffic
RunService.Heartbeat:Connect(function()
	local car = Drive.Car
	local root = car and car.PrimaryPart
	local traffic = workspace:FindFirstChild("Traffic")
	if not root or not traffic then
		return
	end
	local myPos = root.Position
	local myVel = root.AssemblyLinearVelocity
	if os.clock() - lastNearMiss > 3 then
		Drive.NearMissCombo = 0
	end
	for _, civ in traffic:GetChildren() do
		if not civ:IsA("Model") or not civ.PrimaryPart then
			continue
		end
		local cr = civ.PrimaryPart
		local dist = (cr.Position - myPos).Magnitude
		local entry = nearTrack[civ]
		if dist < 16 then
			local rel = (myVel - cr.AssemblyLinearVelocity).Magnitude
			if not entry then
				nearTrack[civ] = { min = dist, rel = rel, speed = myVel.Magnitude }
			else
				entry.min = math.min(entry.min, dist)
				entry.rel = math.max(entry.rel, rel)
			end
		elseif entry then
			nearTrack[civ] = nil
			local clean = myVel.Magnitude > entry.speed * 0.75
			if clean and entry.min >= TR.NearMissMin and entry.min <= TR.NearMissMax and entry.rel >= TR.NearMissSpeed then
				lastNearMiss = os.clock()
				Drive.NearMissCombo += 1
				Drive.Nitro = math.min(Drive.NitroCapacity, Drive.Nitro + TR.NearMissNitro)
				NearMissEvent:FireServer(civ)
				for _, fn in Drive.OnNearMiss do
					task.spawn(fn, Drive.NearMissCombo)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Chase camera
---------------------------------------------------------------------------
RunService:BindToRenderStep("WU_ChaseCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if Drive.MenuOpen or player:GetAttribute("InGarage") then
		return
	end
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

	-- keep the camera out of buildings (only buildings, so traffic doesn't make it jump)
	local params = RaycastParams.new()
	local map = workspace:FindFirstChild("Map")
	local buildings = map and map:FindFirstChild("Buildings")
	if buildings then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { buildings }
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { car }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		params.FilterDescendantsInstances = ignore
	end
	local from = root.Position + Vector3.new(0, 3, 0)
	local hit = workspace:Raycast(from, (camPos :: Vector3) - from, params)
	local finalPos = camPos :: Vector3
	if hit then
		finalPos = hit.Position + (from - hit.Position).Unit * 1.5
	end
	-- camera shake: crashes, top speed and nitro
	Drive.Shake = math.max(0, Drive.Shake - dt * 2.5)
	local shake = Drive.Shake * 1.2 + math.clamp((speed - 120) / 400, 0, 0.18) + (if Drive.NitroOn then 0.15 else 0)
	if not Settings.Values.shake then
		shake = 0
	end
	if shake > 0.001 then
		local t = os.clock() * 18
		finalPos += Vector3.new(math.noise(t, 0.3) * shake, math.noise(0.7, t) * shake, math.noise(t, 1.9) * shake * 0.5)
	end
	camera.CFrame = CFrame.lookAt(finalPos, camLook :: Vector3)
	local targetFov = 70 + math.clamp(speed / 6, 0, 22) + (if Drive.NitroOn then 10 else 0)
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 4)
end)

return Drive
