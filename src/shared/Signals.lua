--!strict
-- Traffic light timing shared by the server (traffic AI) and clients (lamp visuals).
-- Both sides use the server clock, so every light in the city is in sync.

local Signals = {}

Signals.Cycle = 24

-- State of the lights for traffic moving along `axis` ("x" or "z") at server time `t`.
function Signals.State(axis: string, t: number): string
	local p = t % Signals.Cycle
	if axis == "x" then
		if p < 10 then
			return "green"
		elseif p < 12 then
			return "yellow"
		end
		return "red"
	end
	if p < 12 then
		return "red"
	elseif p < 22 then
		return "green"
	end
	return "yellow"
end

function Signals.Now(): number
	return workspace:GetServerTimeNow()
end

return Signals
