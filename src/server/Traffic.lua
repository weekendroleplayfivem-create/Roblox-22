--!strict
-- Civilian traffic: cars that keep to the right-hand lane, turn at intersections and brake for
-- whatever is in front of them. Players weave through them for near misses (Unbound).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local CarPhysics = require(Shared:WaitForChild("CarPhysics"))
local AIDriver = require(script.Parent.AIDriver)
local CarBuilder = require(script.Parent.CarBuilder)
local Session = require(script.Parent.Session)
local Signals = require(Shared:WaitForChild("Signals"))

local Traffic = {}

local T = Config.Traffic
local folder = Instance.new("Folder")
folder.Name = "Traffic"
folder.Parent = workspace
Traffic.Folder = folder

local cars: { AIDriver.AI } = {}
local obstacleParams = RaycastParams.new()
obstacleParams.FilterType = Enum.RaycastFilterType.Include

local function laneFor(fromIJ: { number }, toIJ: { number })
	local from = Grid.Intersection(fromIJ[1], fromIJ[2])
	local to = Grid.Intersection(toIJ[1], toIJ[2])
	local dir = (to - from).Unit
	local right = dir:Cross(Vector3.yAxis)
	return from + right * T.LaneOffset, dir, (to - from).Magnitude
end

local function pickNext(fromIJ: { number }, toIJ: { number }): { number }
	local options = {}
	local straight: { number }? = nil
	local di, dj = toIJ[1] - fromIJ[1], toIJ[2] - fromIJ[2]
	for _, n in Grid.Neighbours(toIJ[1], toIJ[2]) do
		if not (n[1] == fromIJ[1] and n[2] == fromIJ[2]) then
			table.insert(options, n)
			if n[1] - toIJ[1] == di and n[2] - toIJ[2] == dj then
				straight = n
			end
		end
	end
	if straight and math.random() < 0.55 then
		return straight
	end
	if #options == 0 then
		return fromIJ
	end
	return options[math.random(1, #options)]
end

local function setSegment(ai: AIDriver.AI, fromIJ: { number }, toIJ: { number })
	local d = ai.data
	d.from = fromIJ
	d.to = toIJ
	d.laneStart, d.dir, d.segLen = laneFor(fromIJ, toIJ)
	d.nextTo = pickNext(fromIJ, toIJ)
end

-- Re-attach a car to the road network after it got knocked off its lane.
local function resync(ai: AIDriver.AI)
	local root = ai.state.root
	local i, j = Grid.NearestIntersection(root.Position)
	local look = root.CFrame.LookVector
	local best, bestDot = nil, -math.huge
	for _, n in Grid.Neighbours(i, j) do
		local dir = (Grid.Intersection(n[1], n[2]) - Grid.Intersection(i, j)).Unit
		local dot = dir:Dot(look)
		if dot > bestDot then
			best, bestDot = n, dot
		end
	end
	if best then
		setSegment(ai, { i, j }, best)
	end
end

local function think(ai: AIDriver.AI, dt: number)
	local d = ai.data
	local root = ai.state.root
	local pos = root.Position
	local rel = pos - d.laneStart
	local t = rel:Dot(d.dir)
	local off = (rel - d.dir * t).Magnitude
	if off > 45 or t < -40 or t > d.segLen + 40 then
		resync(ai)
		return
	end
	if t > d.segLen - 8 then
		setSegment(ai, d.to, d.nextTo)
		return
	end
	local target = d.laneStart + d.dir * math.min(t + 26, d.segLen + 12)
	local steer = CarPhysics.SteerTowards(ai.state, target)

	-- slow down before turning corners
	local turning = (d.nextTo[1] - d.to[1]) ~= (d.to[1] - d.from[1]) or (d.nextTo[2] - d.to[2]) ~= (d.to[2] - d.from[2])
	local mult = if turning and t > d.segLen - 45 then 0.5 else 1

	-- brake for anything ahead
	d.scan = (d.scan or 0) - dt
	if d.scan <= 0 then
		d.scan = 0.2
		local look = root.CFrame.LookVector
		local start = pos + look * (root.Size.Z / 2 + 0.5)
		local hit = workspace:Raycast(start, look * (18 + math.max(ai.state.speed, 0) * 0.5), obstacleParams)
		d.blocked = hit ~= nil
		d.blockedFor = if d.blocked then (d.blockedFor or 0) + 0.2 else 0
		if d.blockedFor > 5 then
			-- stuck behind something that isn't moving: nose around it
			d.blocked = false
		end
	end
	ai.state.speedMult = mult

	-- stop at red lights (and at yellow when there's room to stop) before the stop line
	local redLight = false
	local toI, toJ = d.to[1], d.to[2]
	if toI > 0 and toI < Grid.Size and toJ > 0 and toJ < Grid.Size then
		local toGo = d.segLen - t
		local speed = math.max(ai.state.speed, 0)
		local stopAt = 41
		local brakeDist = speed * speed / 140 + 2
		if toGo > 27 and toGo - stopAt < brakeDist then
			local axis = if math.abs(d.dir.X) > 0.5 then "x" else "z"
			local light = Signals.State(axis, Signals.Now())
			redLight = light == "red" or (light == "yellow" and toGo - stopAt > 6)
		end
	end

	if redLight then
		ai.input.throttle = if ai.state.speed > 1 then -0.9 else 0
	elseif d.blocked then
		ai.input.throttle = if ai.state.speed > 4 then -0.6 else 0
	else
		ai.input.throttle = 1
	end
	ai.input.steer = steer
	ai.input.handbrake = false
end

local function farFromPlayers(p: Vector3, dist: number): boolean
	for _, s in Session.All() do
		local cp = Session.CarPosition(s)
		if cp and (cp - p).Magnitude < dist then
			return false
		end
	end
	return true
end

local function spawnOne()
	for _ = 1, 12 do
		local i, j = math.random(0, Grid.Size), math.random(0, Grid.Size)
		local neighbours = Grid.Neighbours(i, j)
		local toIJ = neighbours[math.random(1, #neighbours)]
		local laneStart, dir, segLen = laneFor({ i, j }, toIJ)
		local pos = laneStart + dir * (segLen * math.random(25, 70) / 100)
		if farFromPlayers(pos, 160) then
			local model = CarBuilder.Build({
				style = T.Styles[math.random(1, #T.Styles)],
				heavy = false,
				color = T.Colors[math.random(1, #T.Colors)],
				name = "Civilian",
				rim = math.random(1, 2),
				tint = 0.3,
			})
			local root = model.PrimaryPart :: BasePart
			local p = Vector3.new(pos.X, Grid.RoadY + root.Size.Y / 2 + 0.4, pos.Z)
			model:PivotTo(CFrame.lookAt(p, p + dir))
			model:SetAttribute("Civilian", true)
			model.Parent = folder
			local cruise = math.random(T.Speed[1], T.Speed[2])
			local ai = AIDriver.Add(model, {
				maxSpeed = cruise,
				accel = 22,
				brake = 80,
				turn = 2.2,
				grip = 8,
				nitroMult = 1,
			}, "civilian", think)
			setSegment(ai, { i, j }, toIJ)
			table.insert(cars, ai)
			return
		end
	end
end

function Traffic.Init()
	local carsFolder = workspace:WaitForChild("Cars")
	local police = workspace:WaitForChild("Police")
	obstacleParams.FilterDescendantsInstances = { carsFolder, police, folder }
	task.spawn(function()
		while true do
			for idx = #cars, 1, -1 do
				if not cars[idx].alive then
					table.remove(cars, idx)
				end
			end
			if #cars < T.Count then
				spawnOne()
			end
			task.wait(0.5)
		end
	end)
end

return Traffic
