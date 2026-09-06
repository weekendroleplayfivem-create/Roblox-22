--!strict
--[[ Utility: small shared helpers used on both sides of the network. ]]

local TweenService = game:GetService("TweenService")

local Utility = {}

function Utility.Tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function Utility.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Utility.Round(value: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(value * mult + 0.5) / mult
end

function Utility.FormatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Utility.FormatMoney(amount: number): string
	local formatted = tostring(math.floor(amount))
	local result = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	result = result:gsub("^,", "")
	return "$" .. result
end

function Utility.Percent(value: number): string
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

-- Total length of a waypoint path, used to measure how far along a route an
-- enemy is without recomputing per-frame distances.
function Utility.PathLength(points: { Vector3 }): number
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

function Utility.SafeDivide(numerator: number, denominator: number, fallback: number?): number
	if denominator == 0 then
		return fallback or 0
	end
	return numerator / denominator
end

return Utility
