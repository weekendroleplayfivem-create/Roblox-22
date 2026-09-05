--[[ Utility: small shared helpers used by both client and server code. ]]

local TweenService = game:GetService("TweenService")

local Utility = {}

function Utility.Tween(instance, info, props)
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function Utility.QuickTween(instance, duration, props, style, direction)
	return Utility.Tween(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
end

function Utility.Round(n, decimals)
	local mult = 10 ^ (decimals or 0)
	return math.floor(n * mult + 0.5) / mult
end

function Utility.Clamp(n, min, max)
	return math.clamp(n, min, max)
end

function Utility.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

function Utility.Lerp(a, b, t)
	return a + (b - a) * t
end

-- Deterministic-ish unique id for cosmetics / inventory entries.
function Utility.NewId()
	return string.format("%x-%x", os.time(), math.random(0, 0xFFFFFF))
end

return Utility
