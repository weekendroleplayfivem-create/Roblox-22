--!strict
-- Arcade driving model shared by the player's car (simulated on the client that owns it)
-- and AI cars (police and rivals, simulated on the server).
--
-- The chassis is a frictionless box that rests on the road. Every physics step we read its
-- real velocity, split it into forward / sideways parts, apply throttle, grip and steering,
-- and write it back. An AlignOrientation keeps the car upright on the ground normal.

local CarPhysics = {}

export type Input = {
	throttle: number, -- -1..1
	steer: number, -- -1..1 (positive = right)
	handbrake: boolean,
	nitro: boolean,
}

export type Stats = {
	maxSpeed: number,
	accel: number,
	brake: number,
	turn: number,
	grip: number,
	nitroMult: number,
	driftGrip: number?, -- grip multiplier while drifting (lower = longer slides)
	downforce: number?, -- 0..1, extra grip at high speed
}

export type State = {
	model: Model,
	root: BasePart,
	align: AlignOrientation?,
	params: RaycastParams,
	grounded: boolean,
	drifting: boolean,
	speed: number, -- signed forward speed
	lateral: number, -- signed sideways speed
	airTime: number,
	speedMult: number, -- extra multiplier (AI rubber banding, heat)
	weight: number, -- -1 (on the rear) .. 1 (on the nose): weight transfer
	brakeTap: number, -- os.clock() of the last brake, for brake-to-drift
	lowSlip: number, -- time spent nearly straight while drifting
}

function CarPhysics.NewState(model: Model): State
	local root = model.PrimaryPart :: BasePart
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	return {
		model = model,
		root = root,
		align = root:FindFirstChild("Upright") :: AlignOrientation?,
		params = params,
		grounded = false,
		drifting = false,
		speed = 0,
		lateral = 0,
		airTime = 0,
		speedMult = 1,
		weight = 0,
		brakeTap = 0,
		lowSlip = 0,
	}
end

-- Keep characters sitting in the car out of our ground raycasts.
function CarPhysics.SetIgnore(state: State, extra: { Instance })
	local list: { Instance } = { state.model }
	for _, inst in extra do
		table.insert(list, inst)
	end
	state.params.FilterDescendantsInstances = list
end

local UP = Vector3.yAxis

function CarPhysics.Step(state: State, input: Input, stats: Stats, dt: number)
	local root = state.root
	if root.Anchored then
		return
	end
	local cf = root.CFrame
	local halfHeight = root.Size.Y / 2
	local hit = workspace:Raycast(cf.Position, Vector3.new(0, -(halfHeight + 2.2), 0), state.params)

	local up = UP
	if hit then
		up = hit.Normal
		if up.Y < 0.5 then
			up = UP -- walls do not count as ground
			hit = nil
		end
	end
	state.grounded = hit ~= nil

	local align = state.align
	if align then
		align.PrimaryAxis = up
	end

	local vel = root.AssemblyLinearVelocity
	local look = cf.LookVector
	local flat = look - up * look:Dot(up)
	if flat.Magnitude < 0.05 then
		return
	end
	local forward = flat.Unit
	local right = forward:Cross(up)

	local fwd = vel:Dot(forward)
	local lat = vel:Dot(right)
	local vert = vel:Dot(up)

	if state.grounded then
		local landed = state.airTime > 0.35
		state.airTime = 0
		local mult = state.speedMult
		local maxSpeed = stats.maxSpeed * mult
		local accel = stats.accel * mult
		if input.nitro then
			maxSpeed *= stats.nitroMult
			accel *= 1.7
		end
		local absFwd = math.abs(fwd)
		local throttle = input.throttle
		local now = os.clock()

		-- Longitudinal: torque falls off towards top speed, tyres limit the launch.
		if throttle > 0.05 then
			if fwd < -2 then
				fwd = math.min(fwd + stats.brake * throttle * dt, 0)
			elseif fwd < maxSpeed then
				local ratio = math.max(fwd, 0) / maxSpeed
				local torque = 1 - 0.62 * ratio ^ 1.6
				local launch = if fwd < 25 then 0.75 + 0.25 * (fwd / 25) else 1 -- traction limit off the line
				fwd = math.min(fwd + accel * throttle * torque * launch * dt, maxSpeed)
			else
				fwd -= (fwd - maxSpeed) * math.min(dt * 1.2, 1)
			end
			state.weight += (-0.5 - state.weight) * math.min(1, dt * 4) -- weight moves back
		elseif throttle < -0.05 then
			if fwd > 2 then
				fwd = math.max(fwd - stats.brake * -throttle * dt, 0)
				state.weight += (1 - state.weight) * math.min(1, dt * 5) -- weight moves forward
				state.brakeTap = now
			else
				fwd = math.max(fwd - accel * 0.7 * -throttle * dt, -stats.maxSpeed * 0.35)
			end
		else
			-- engine braking + rolling resistance
			fwd -= fwd * math.min(dt * 0.3, 1) + math.sign(fwd) * math.min(math.abs(fwd), 1.5 * dt)
			state.weight += (0 - state.weight) * math.min(1, dt * 3)
		end

		-- Drifting: handbrake, or Unbound-style brake-tap then back on the gas while steering.
		local steerAbs = math.abs(input.steer)
		if input.handbrake then
			fwd -= fwd * math.min(dt * 0.55, 1)
			if absFwd > 35 and steerAbs > 0.2 then
				state.drifting = true
			end
		elseif throttle > 0.5 and steerAbs > 0.5 and absFwd > 60 and now - state.brakeTap < 0.45 then
			state.drifting = true
		end
		local slip = math.deg(math.atan2(math.abs(lat), math.max(absFwd, 1)))
		if state.drifting and not input.handbrake then
			if slip < 8 or absFwd < 20 then
				state.lowSlip += dt
			else
				state.lowSlip = 0
			end
			if state.lowSlip > 0.25 or (throttle <= 0.05 and steerAbs < 0.1 and slip < 15) then
				state.drifting = false
				state.lowSlip = 0
			end
		end

		-- Lateral grip: downforce adds grip at speed, weight on the nose sharpens turn-in.
		local grip = stats.grip * (1 + (stats.downforce or 0) * 0.6 * math.clamp(absFwd / stats.maxSpeed, 0, 1))
		if input.handbrake then
			grip *= 0.18
		elseif state.drifting then
			grip *= stats.driftGrip or 0.4
			-- drift assist: throttle holds the slide instead of scrubbing all the speed
			if throttle > 0.3 then
				fwd = math.min(fwd + accel * 0.35 * dt, maxSpeed)
			end
		end
		if landed then
			grip *= 0.5 -- a moment of looseness after landing a jump
		end
		local oldLat = math.abs(lat)
		lat *= math.max(0, 1 - grip * dt)
		-- carry part of the scrubbed sideways speed into forward speed so corners keep momentum
		if fwd > 5 then
			local carry = if state.drifting then 0.6 else 0.45
			fwd = math.min(fwd + (oldLat - math.abs(lat)) * carry, maxSpeed * 1.05)
		end

		-- Steering: needs speed, less lock at the top end, sharper with weight on the nose.
		local speedFactor = math.clamp(absFwd / 20, 0, 1)
		local highSpeedDamp = 1 - 0.5 * math.clamp(absFwd / (stats.maxSpeed * 1.15), 0, 1) ^ 1.2
		local turnIn = 1 + 0.18 * math.max(state.weight, 0) - 0.08 * math.max(-state.weight, 0)
		local targetYaw = -input.steer * stats.turn * speedFactor * highSpeedDamp * turnIn
		if fwd < 0 then
			targetYaw = -targetYaw
		end
		if state.drifting then
			targetYaw *= 1.45
			-- stop the car spinning out: past ~60 degrees of slip, yaw back towards the slide
			if slip > 60 then
				local slideSide = math.sign(lat)
				targetYaw -= slideSide * (slip - 60) * 0.05 -- turn the nose back towards the direction of travel
			end
		end
		-- yaw has inertia: the car rotates into the turn instead of snapping
		local av = root.AssemblyAngularVelocity
		local currentYaw = av:Dot(up)
		local response = if state.drifting then 5 else (6 + stats.grip * 0.5)
		local yaw = currentYaw + (targetYaw - currentYaw) * (1 - math.exp(-dt * response))

		root.AssemblyLinearVelocity = forward * fwd + right * lat + up * math.min(vert, 60)
		root.AssemblyAngularVelocity = av - up * currentYaw + up * yaw
	else
		state.airTime += dt
		-- slight air control, rotation keeps its momentum
		local av = root.AssemblyAngularVelocity
		local currentYaw = av:Dot(UP)
		local targetYaw = -input.steer * stats.turn * 0.35
		local yaw = currentYaw + (targetYaw - currentYaw) * (1 - math.exp(-dt * 2))
		root.AssemblyAngularVelocity = av - UP * currentYaw + UP * yaw
	end

	state.speed = fwd
	state.lateral = lat
end

-- Compute simple AI inputs to drive towards a world point.
function CarPhysics.SteerTowards(state: State, target: Vector3): (number, number, number)
	local localPos = state.root.CFrame:PointToObjectSpace(target)
	local angle = math.atan2(localPos.X, -localPos.Z) -- 0 = straight ahead, + = right
	local dist = Vector3.new(localPos.X, 0, localPos.Z).Magnitude
	local steer = math.clamp(angle * 2.2, -1, 1)
	return steer, angle, dist
end

return CarPhysics
