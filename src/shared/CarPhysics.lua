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
		state.airTime = 0
		local mult = state.speedMult
		local maxSpeed = stats.maxSpeed * mult
		local accel = stats.accel * mult
		if input.nitro then
			maxSpeed *= stats.nitroMult
			accel *= 1.7
		end

		local throttle = input.throttle
		if throttle > 0.05 then
			if fwd < -2 then
				fwd = math.min(fwd + stats.brake * throttle * dt, 0)
			elseif fwd < maxSpeed then
				local taper = 1 - 0.55 * (math.max(fwd, 0) / maxSpeed) ^ 2
				fwd = math.min(fwd + accel * throttle * taper * dt, maxSpeed)
			else
				fwd -= (fwd - maxSpeed) * math.min(dt * 1.2, 1)
			end
		elseif throttle < -0.05 then
			if fwd > 2 then
				fwd = math.max(fwd - stats.brake * -throttle * dt, 0)
			else
				fwd = math.max(fwd - accel * 0.7 * -throttle * dt, -stats.maxSpeed * 0.35)
			end
		else
			-- coasting drag
			fwd -= fwd * math.min(dt * 0.35, 1)
			if math.abs(fwd) < 1 then
				fwd = 0
			end
		end

		-- Drift logic: brake-to-drift / handbrake starts it, low lateral speed ends it.
		local absFwd = math.abs(fwd)
		if input.handbrake then
			fwd -= fwd * math.min(dt * 0.6, 1)
			if absFwd > 35 and math.abs(input.steer) > 0.2 then
				state.drifting = true
			end
		end
		if state.drifting and (math.abs(lat) < 5 or absFwd < 20) and not input.handbrake then
			state.drifting = false
		end

		local grip = stats.grip
		if input.handbrake then
			grip *= 0.18
		elseif state.drifting then
			grip *= 0.4
		end
		local oldLat = math.abs(lat)
		lat *= math.max(0, 1 - grip * dt)
		-- Convert part of the scrubbed sideways speed back into forward speed so corners
		-- keep momentum, the arcade way.
		if fwd > 5 then
			fwd = math.min(fwd + (oldLat - math.abs(lat)) * 0.55, maxSpeed * 1.05)
		end

		-- Steering: needs speed, softens at the top end, stronger in a drift.
		local speedFactor = math.clamp(absFwd / 22, 0, 1)
		local highSpeedDamp = 1 - 0.4 * math.clamp(absFwd / (stats.maxSpeed * 1.2), 0, 1)
		local yaw = -input.steer * stats.turn * speedFactor * highSpeedDamp
		if fwd < 0 then
			yaw = -yaw
		end
		if state.drifting then
			yaw *= 1.35
		end

		root.AssemblyLinearVelocity = forward * fwd + right * lat + up * math.min(vert, 60)
		local av = root.AssemblyAngularVelocity
		root.AssemblyAngularVelocity = av - up * av:Dot(up) + up * yaw
	else
		state.airTime += dt
		-- slight air control
		local av = root.AssemblyAngularVelocity
		local yaw = -input.steer * stats.turn * 0.35
		root.AssemblyAngularVelocity = av - UP * av:Dot(UP) + UP * yaw
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
