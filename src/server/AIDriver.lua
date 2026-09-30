--!strict
-- Server-side driver for AI cars (police and race rivals). Each AI has a `think` callback
-- that picks a goal; AIDriver handles road-grid navigation, steering, unsticking and
-- runs the shared arcade physics.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarPhysics = require(Shared:WaitForChild("CarPhysics"))
local Grid = require(Shared:WaitForChild("Grid"))

local AIDriver = {}

export type AI = {
	model: Model,
	state: CarPhysics.State,
	stats: CarPhysics.Stats,
	input: CarPhysics.Input,
	kind: string,
	think: (ai: AI, dt: number) -> (),
	nav: { number }?,
	prev: { number }?,
	stuck: number,
	stuckTotal: number,
	reverse: number,
	flipped: number,
	alive: boolean,
	data: { [string]: any },
}

local ais: { AI } = {}
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Include

function AIDriver.SetBuildings(folder: Folder)
	losParams.FilterDescendantsInstances = { folder }
end

-- True when nothing solid in the city blocks the line between a and b.
function AIDriver.ClearLine(a: Vector3, b: Vector3, radius: number?): boolean
	local from = Vector3.new(a.X, Grid.RoadY + 3, a.Z)
	local to = Vector3.new(b.X, Grid.RoadY + 3, b.Z)
	local dir = to - from
	if dir.Magnitude < 1 then
		return true
	end
	local hit
	if radius then
		hit = workspace:Spherecast(from, radius, dir, losParams)
	else
		hit = workspace:Raycast(from, dir, losParams)
	end
	return hit == nil
end

function AIDriver.Add(model: Model, stats: CarPhysics.Stats, kind: string, think: (ai: AI, dt: number) -> ()): AI
	local ai: AI = {
		model = model,
		state = CarPhysics.NewState(model),
		stats = stats,
		input = { throttle = 0, steer = 0, handbrake = false, nitro = false },
		kind = kind,
		think = think,
		nav = nil,
		prev = nil,
		stuck = 0,
		stuckTotal = 0,
		reverse = 0,
		flipped = 0,
		alive = true,
		data = {},
	}
	table.insert(ais, ai)
	local root = model.PrimaryPart :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return ai
end

function AIDriver.Remove(ai: AI)
	ai.alive = false
	local anti = ai.state.root:FindFirstChild("AntiGravity") :: VectorForce?
	if anti then
		anti.Force = Vector3.zero
	end
	local idx = table.find(ais, ai)
	if idx then
		table.remove(ais, idx)
	end
end

function AIDriver.All(): { AI }
	return ais
end

local function chooseNav(ai: AI, pos: Vector3, goal: Vector3): { number }
	local ci, cj = Grid.NearestIntersection(pos)
	local cpos = Grid.Intersection(ci, cj)
	local flatDist = Vector3.new(pos.X - cpos.X, 0, pos.Z - cpos.Z).Magnitude
	if flatDist > 40 then
		-- mid-segment: pick the better end of the road we're on
		local candidates: { { number } } = {}
		if math.abs(pos.X - cpos.X) < math.abs(pos.Z - cpos.Z) then
			local f = (pos.Z + Grid.Half) / Grid.Cell
			local j0 = math.clamp(math.floor(f), 0, Grid.Size)
			local j1 = math.clamp(j0 + 1, 0, Grid.Size)
			candidates = { { ci, j0 }, { ci, j1 } }
		else
			local f = (pos.X + Grid.Half) / Grid.Cell
			local i0 = math.clamp(math.floor(f), 0, Grid.Size)
			local i1 = math.clamp(i0 + 1, 0, Grid.Size)
			candidates = { { i0, cj }, { i1, cj } }
		end
		local best, bestScore = candidates[1], math.huge
		for _, c in candidates do
			local p = Grid.Intersection(c[1], c[2])
			local score = (p - pos).Magnitude * 0.35 + (p - goal).Magnitude
			if score < bestScore then
				best, bestScore = c, score
			end
		end
		return best
	end
	local best, bestScore = nil, math.huge
	for _, n in Grid.Neighbours(ci, cj) do
		local p = Grid.Intersection(n[1], n[2])
		local score = (p - goal).Magnitude + math.random() * 20
		local prev = ai.prev
		if prev and prev[1] == n[1] and prev[2] == n[2] then
			score += 250 -- avoid ping-ponging
		end
		if score < bestScore then
			best, bestScore = n, score
		end
	end
	ai.prev = { ci, cj }
	return best or { ci, cj }
end

-- Sets ai.input to drive towards `goal`, using the road grid when there's no clear line.
function AIDriver.DriveTo(ai: AI, goal: Vector3, aggressive: boolean?)
	local root = ai.state.root
	local pos = root.Position
	local waypoint = goal
	-- the spherecast is the expensive part: refresh it 5x a second instead of every frame
	local now = os.clock()
	if now >= (ai.data.losCheckAt or 0) then
		ai.data.losCheckAt = now + 0.2
		ai.data.losClear = AIDriver.ClearLine(pos, goal, 3.5)
	end
	if ai.data.losClear then
		ai.nav = nil
	else
		local nav = ai.nav
		if nav then
			local np = Grid.Intersection(nav[1], nav[2])
			if Vector3.new(np.X - pos.X, 0, np.Z - pos.Z).Magnitude < 26 then
				ai.prev = nav
				nav = nil
			end
		end
		if not nav then
			nav = chooseNav(ai, pos, goal)
			ai.nav = nav
		end
		local n = nav :: { number }
		waypoint = Grid.Intersection(n[1], n[2])
	end

	local steer, angle, dist = CarPhysics.SteerTowards(ai.state, waypoint)
	local speed = ai.state.speed
	local throttle = 1
	local handbrake = false
	local absAngle = math.abs(angle)
	if absAngle > 1.0 and speed > 45 then
		handbrake = true
		throttle = 0.4
	elseif absAngle > 0.5 and speed > 90 and dist < 120 then
		throttle = -0.3
	end
	if absAngle > 2.2 and speed < 15 then
		-- target behind us at low speed: back up while turning
		throttle = -1
		steer = -steer
	end
	if not aggressive and dist < 12 then
		throttle = 0.2
	end
	ai.input.throttle = throttle
	ai.input.steer = steer
	ai.input.handbrake = handbrake
end

local function uprightAt(ai: AI, pos: Vector3, look: Vector3)
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = -Vector3.zAxis
	end
	local root = ai.state.root
	local hover = ai.model:GetAttribute("HoverCenter")
	local target = Vector3.new(pos.X, Grid.RoadY + (if type(hover) == "number" then hover else root.Size.Y / 2) + 0.2, pos.Z)
	ai.model:PivotTo(CFrame.lookAt(target, target + flat.Unit))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end
AIDriver.Place = uprightAt

RunService.Heartbeat:Connect(function(dt: number)
	dt = math.min(dt, 1 / 20)
	for idx = #ais, 1, -1 do
		local ai = ais[idx]
		if not ai.alive or not ai.model.Parent or not ai.model.PrimaryPart then
			ai.alive = false
			table.remove(ais, idx)
			continue
		end
		local ok, err = pcall(function()
			ai.think(ai, dt)
		end)
		if not ok then
			warn("[AIDriver] think error:", err)
		end
		local root = ai.state.root
		if root.Anchored then
			continue
		end
		-- weapons (EMP, oil, spikes) can stall a car for a moment
		local stunned = ai.data.stunnedUntil
		if stunned and os.clock() < stunned then
			ai.input.throttle = 0
			ai.input.steer = 0
			ai.input.handbrake = true
			ai.input.nitro = false
		end

		-- unstick: back up when pushing against something
		if ai.reverse > 0 then
			ai.reverse -= dt
			ai.input.throttle = -1
			ai.input.steer = -ai.input.steer
			ai.input.handbrake = false
		elseif ai.input.throttle > 0.3 and math.abs(ai.state.speed) < 5 then
			ai.stuck += dt
			ai.stuckTotal += dt
			if ai.stuck > 1.2 then
				ai.stuck = 0
				ai.reverse = 1.1
			end
		else
			ai.stuck = 0
			ai.stuckTotal = math.max(0, ai.stuckTotal - dt * 0.5)
		end

		if root.CFrame.UpVector.Y < 0.3 then
			ai.flipped += dt
		else
			ai.flipped = 0
		end
		if ai.flipped > 1.5 or ai.stuckTotal > 6 or root.Position.Y < -30 then
			ai.flipped = 0
			ai.stuckTotal = 0
			ai.nav = nil
			local snapped = Grid.SnapToRoad(root.Position)
			uprightAt(ai, snapped, root.CFrame.LookVector)
		end

		CarPhysics.Step(ai.state, ai.input, ai.stats, dt)
	end
end)

return AIDriver
