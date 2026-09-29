--!strict
-- Local visual effects for every car near the camera: spinning wheels, front wheels steering,
-- headlights at night, and brake / reverse lights on your own car.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Drive = require(script.Parent.DriveController)
local Signals = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Signals"))

local CarVisuals = {}

type Entry = {
	welds: { Weld },
	spin: number,
	steer: number,
	night: boolean?,
	braking: boolean?,
	reversing: boolean?,
	heads: { SpotLight },
	tails: { BasePart },
	reverse: { BasePart },
	tailGlow: SurfaceLight?,
}

local cache: { [Model]: Entry } = setmetatable({}, { __mode = "k" }) :: any
local TAIL = Color3.fromRGB(230, 15, 30)
local BRAKE = Color3.fromRGB(255, 70, 70)

local function build(model: Model): Entry
	local e: Entry = { welds = {}, spin = 0, steer = 0, heads = {}, tails = {}, reverse = {} }
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") and d.Name == "WheelWeld" then
			table.insert(e.welds, d)
		elseif d:IsA("SpotLight") and d.Name == "Beam" then
			table.insert(e.heads, d)
		elseif d:IsA("BasePart") and d.Name == "Taillight" then
			table.insert(e.tails, d)
		elseif d:IsA("BasePart") and d.Name == "ReverseLight" then
			table.insert(e.reverse, d)
		elseif d:IsA("SurfaceLight") and d.Name == "TailGlow" then
			e.tailGlow = d
		end
	end
	cache[model] = e
	return e
end

local function animate(model: Model, dt: number, night: boolean, camPos: Vector3)
	local root = model.PrimaryPart
	if not root then
		return
	end
	if (root.Position - camPos).Magnitude > 400 then
		return
	end
	local e = cache[model] or build(model)
	local cf = root.CFrame
	local vel = root.AssemblyLinearVelocity
	local fwd = vel:Dot(cf.LookVector)
	local own = model == Drive.Car

	local steerTarget = 0
	if own then
		steerTarget = Drive.Steer
	elseif math.abs(fwd) > 3 then
		steerTarget = math.clamp(-root.AssemblyAngularVelocity.Y / 2.2, -1, 1) * math.sign(fwd)
	end
	e.steer += (steerTarget * 0.45 - e.steer) * math.min(1, dt * 10)

	for _, weld in e.welds do
		local base = weld:GetAttribute("BaseC0")
		local radius = weld:GetAttribute("Radius")
		if typeof(base) ~= "CFrame" or type(radius) ~= "number" then
			continue
		end
		local steer = if weld:GetAttribute("Front") then -e.steer else 0
		weld.C0 = base * CFrame.Angles(0, steer, 0) * CFrame.Angles(e.spin, 0, 0)
	end
	local r = 1
	local first = e.welds[1]
	if first then
		local rv = first:GetAttribute("Radius")
		if type(rv) == "number" then
			r = rv
		end
	end
	e.spin = (e.spin - fwd / r * dt) % (math.pi * 2)

	if e.night ~= night then
		e.night = night
		for _, light in e.heads do
			light.Enabled = night
		end
	end

	if own then
		local braking = Drive.Handbrake or (Drive.Throttle < -0.1 and fwd > 2)
		if braking ~= e.braking then
			e.braking = braking
			for _, t in e.tails do
				t.Color = if braking then BRAKE else TAIL
			end
			if e.tailGlow then
				e.tailGlow.Brightness = if braking then 5 else 1.2
				e.tailGlow.Range = if braking then 14 else 9
			end
		end
		local reversing = fwd < -1 and Drive.Throttle < -0.1
		if reversing ~= e.reversing then
			e.reversing = reversing
			for _, p in e.reverse do
				p.Material = if reversing then Enum.Material.Neon else Enum.Material.Glass
			end
		end
	end
end

local function eachCar(folder: Instance?, fn: (Model) -> ())
	if not folder then
		return
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			if m.PrimaryPart then
				fn(m)
			else
				-- roadblocks and race folders contain car models one level down
				for _, inner in m:GetChildren() do
					if inner:IsA("Model") and inner.PrimaryPart then
						fn(inner)
					end
				end
			end
		elseif m:IsA("Folder") then
			for _, inner in m:GetChildren() do
				if inner:IsA("Model") and inner.PrimaryPart then
					fn(inner)
				end
			end
		end
	end
end

-- Traffic lights: every client animates the lamps from the shared server clock.
local lampState: { [BasePart]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local signalTimer = 0
local function updateSignals(dt: number)
	signalTimer += dt
	if signalTimer < 0.2 then
		return
	end
	signalTimer = 0
	local map = workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("Signals")
	if not folder then
		return
	end
	local now = Signals.Now()
	local xState = Signals.State("x", now)
	local zState = Signals.State("z", now)
	for _, lamp in folder:GetChildren() do
		if not lamp:IsA("BasePart") then
			continue
		end
		local axis = lamp:GetAttribute("Axis")
		local on = lamp:GetAttribute("Light") == (if axis == "x" then xState else zState)
		if lampState[lamp] ~= on then
			lampState[lamp] = on
			local color = lamp:GetAttribute("On")
			if typeof(color) == "Color3" then
				lamp.Color = if on then color else color:Lerp(Color3.new(0, 0, 0), 0.75)
			end
			lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	updateSignals(dt)
	local time = Lighting.ClockTime
	local night = time >= 17.8 or time < 7
	local camPos = workspace.CurrentCamera.CFrame.Position
	local function fn(m: Model)
		animate(m, dt, night, camPos)
	end
	eachCar(workspace:FindFirstChild("Cars"), fn)
	eachCar(workspace:FindFirstChild("Police"), fn)
	eachCar(workspace:FindFirstChild("Races"), fn)
	eachCar(workspace:FindFirstChild("Traffic"), fn)
end)

return CarVisuals
