--[[
	Spring
	Damped spring used for camera FOV, recoil, sway and UI motion.
	Works with numbers and Vector3 values. Integrated with fixed sub-steps so
	behaviour is stable at low frame rates (mobile).
]]

local Spring = {}
Spring.__index = Spring

local MAX_STEP = 1 / 120

function Spring.new(initial: any, stiffness: number?, damping: number?)
	return setmetatable({
		Position = initial,
		Velocity = initial * 0,
		Target = initial,
		Stiffness = stiffness or 120,
		Damping = damping or 14,
	}, Spring)
end

function Spring:Impulse(velocity: any)
	self.Velocity += velocity
end

function Spring:Reset(value: any)
	self.Position = value
	self.Target = value
	self.Velocity = value * 0
end

function Spring:Update(deltaTime: number)
	local remaining = math.min(deltaTime, 0.1)
	while remaining > 0 do
		local step = math.min(remaining, MAX_STEP)
		local displacement = self.Position - self.Target
		local acceleration = displacement * -self.Stiffness - self.Velocity * self.Damping
		self.Velocity += acceleration * step
		self.Position += self.Velocity * step
		remaining -= step
	end
	return self.Position
end

return Spring
