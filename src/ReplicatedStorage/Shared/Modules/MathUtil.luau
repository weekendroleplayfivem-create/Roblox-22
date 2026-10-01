--[[
	MathUtil
	Small, pure math helpers shared by client and server.
]]

local MathUtil = {}

function MathUtil.Lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

function MathUtil.InverseLerp(a: number, b: number, value: number): number
	if a == b then
		return 0
	end
	return math.clamp((value - a) / (b - a), 0, 1)
end

-- Frame-rate independent exponential smoothing factor.
function MathUtil.Damp(rate: number, deltaTime: number): number
	return 1 - math.exp(-rate * deltaTime)
end

function MathUtil.Approach(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

function MathUtil.Flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function MathUtil.SafeUnit(vector: Vector3, fallback: Vector3?): Vector3
	if vector.Magnitude < 1e-4 then
		return fallback or Vector3.zero
	end
	return vector.Unit
end

-- Angle in radians between two vectors (0..pi).
function MathUtil.AngleBetween(a: Vector3, b: Vector3): number
	if a.Magnitude < 1e-6 or b.Magnitude < 1e-6 then
		return math.pi
	end
	local dot = math.clamp(a.Unit:Dot(b.Unit), -1, 1)
	return math.acos(dot)
end

-- Returns a random unit direction inside a cone of `angle` radians around `direction`.
function MathUtil.RandomInCone(direction: Vector3, angle: number, rng: Random): Vector3
	if angle <= 0 then
		return direction.Unit
	end
	local cosAngle = math.cos(angle)
	local z = cosAngle + (1 - cosAngle) * rng:NextNumber()
	local theta = rng:NextNumber() * math.pi * 2
	local radius = math.sqrt(1 - z * z)
	local localDirection = Vector3.new(radius * math.cos(theta), radius * math.sin(theta), -z)
	return (CFrame.lookAt(Vector3.zero, direction) * localDirection).Unit
end

-- Linear damage falloff between start and end distance.
function MathUtil.Falloff(distance: number, startDistance: number, endDistance: number, minMultiplier: number): number
	if distance <= startDistance then
		return 1
	end
	if distance >= endDistance then
		return minMultiplier
	end
	local alpha = (distance - startDistance) / (endDistance - startDistance)
	return MathUtil.Lerp(1, minMultiplier, alpha)
end

function MathUtil.Round(value: number, increment: number?): number
	local step = increment or 1
	return math.floor(value / step + 0.5) * step
end

function MathUtil.FormatTime(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", clamped // 60, clamped % 60)
end

function MathUtil.IsFiniteVector(vector: Vector3): boolean
	local x, y, z = vector.X, vector.Y, vector.Z
	return x == x and y == y and z == z and math.abs(x) < 1e6 and math.abs(y) < 1e6 and math.abs(z) < 1e6
end

return MathUtil
