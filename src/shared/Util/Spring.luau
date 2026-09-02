--!nonstrict
--[[
	Spring.luau
	Critically-dampable spring used for camera FOV, roll, recoil recovery and the
	viewmodel. Springs (not tweens) are the reason this game's camera feels alive
	without ever feeling like it's fighting you: an impulse mid-recovery blends
	instead of snapping.

	Works on numbers, Vector2 and Vector3 uniformly.
--]]

local Spring = {}
Spring.__index = Spring

local function zeroFor(value)
	local kind = typeof(value)
	if kind == "Vector3" then
		return Vector3.zero
	elseif kind == "Vector2" then
		return Vector2.zero
	end
	return 0
end

function Spring.new(initial, frequency: number?, damping: number?)
	return setmetatable({
		Position = initial,
		Target = initial,
		Velocity = zeroFor(initial),
		Frequency = frequency or 4,
		Damping = damping or 1,
	}, Spring)
end

--[[ Semi-implicit Euler with sub-stepping. Sub-stepping keeps a stiff spring
	 stable when a frame spikes (a 200ms hitch must not launch the camera). ]]
function Spring:Update(dt: number)
	local omega = 2 * math.pi * self.Frequency
	local steps = math.clamp(math.ceil(dt * omega / 2.4), 1, 8)
	local stepDt = dt / steps

	for _ = 1, steps do
		local displacement = self.Position - self.Target
		local accel = -(omega * omega) * displacement - (2 * self.Damping * omega) * self.Velocity
		self.Velocity += accel * stepDt
		self.Position += self.Velocity * stepDt
	end

	return self.Position
end

function Spring:Impulse(amount)
	self.Velocity += amount
end

function Spring:Set(value)
	self.Position = value
	self.Target = value
	self.Velocity = zeroFor(value)
end

function Spring:SetTarget(value)
	self.Target = value
end

return Spring
