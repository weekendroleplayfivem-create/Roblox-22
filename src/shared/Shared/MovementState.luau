--!nonstrict
--[[
	MovementState.luau
	The movement state machine's vocabulary, shared by client (simulation),
	server (validation) and the effects layer (what to draw).

	States are exclusive. Modifiers (Overdrive, ADS) are NOT states - they scale
	the numbers of whatever state you're in. Keeping that separation is what stops
	a state machine from turning into a combinatorial mess.
--]]

local MovementState = {}

MovementState.Idle = "Idle"
MovementState.Walk = "Walk"
MovementState.Sprint = "Sprint"
MovementState.Crouch = "Crouch"
MovementState.Slide = "Slide"
MovementState.Air = "Air"
MovementState.WallSlide = "WallSlide"
MovementState.Dash = "Dash"
MovementState.Phase = "Phase"
MovementState.Mantle = "Mantle"
MovementState.Launched = "Launched" -- jump pad arc

-- Ordered for the network: sending a byte beats sending a string 12x a second.
MovementState.Order = {
	MovementState.Idle,
	MovementState.Walk,
	MovementState.Sprint,
	MovementState.Crouch,
	MovementState.Slide,
	MovementState.Air,
	MovementState.WallSlide,
	MovementState.Dash,
	MovementState.Phase,
	MovementState.Mantle,
	MovementState.Launched,
}

MovementState.ToId = {}
for index, name in MovementState.Order do
	MovementState.ToId[name] = index
end

-- States where the movement controller (not the Humanoid) drives velocity.
MovementState.Scripted = {
	[MovementState.Slide] = true,
	[MovementState.Dash] = true,
	[MovementState.Phase] = true,
	[MovementState.Mantle] = true,
}

-- States that should be spilling visual trails.
MovementState.Stylish = {
	[MovementState.Slide] = true,
	[MovementState.Dash] = true,
	[MovementState.Phase] = true,
	[MovementState.WallSlide] = true,
	[MovementState.Launched] = true,
}

-- The highest horizontal speed each state may legitimately produce. The server's
-- MovementGuard uses this table, so it must stay honest with MovementConfig.
function MovementState.speedCeiling(state: string, config): number
	if state == MovementState.Dash then
		return 80
	elseif state == MovementState.Phase then
		return 140 -- blink interpolation reads as a very high instantaneous speed
	elseif state == MovementState.Slide then
		return config.Slide.EntryMaxSpeed + 8
	elseif state == MovementState.Launched then
		return config.JumpPad.DefaultPower
	end
	return config.Speed.MaxMomentum
end

function MovementState.isAirborne(state: string): boolean
	return state == MovementState.Air
		or state == MovementState.WallSlide
		or state == MovementState.Launched
end

return MovementState
