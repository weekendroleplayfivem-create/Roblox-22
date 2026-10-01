--[[
	WallMovement
	Optional wall-jump logic, isolated so it can be disabled with
	PlayerConfig.Movement.WallJump.Enabled = false (no other code changes).

	The client uses FindWall/ComputeJumpVelocity for responsiveness; the
	server re-checks with FindWall that a wall really exists near the player
	before granting the movement allowance.
]]

local PlayerConfig = require(script.Parent.Parent.Config.PlayerConfig)
local MathUtil = require(script.Parent.MathUtil)

local WallMovement = {}

local SAMPLE_DIRECTIONS = 8
-- Walls must be close to vertical to count (|normal.Y| below this).
local MAX_NORMAL_Y = 0.35
-- Approximate half width of a character's root part.
local BODY_RADIUS = 1

function WallMovement.IsEnabled(): boolean
	return PlayerConfig.Movement.WallJump.Enabled
end

-- Finds the closest near-vertical surface around `position`.
-- Returns (normal, part) or nil.
function WallMovement.FindWall(position: Vector3, params: RaycastParams, extraDistance: number?): (Vector3?, BasePart?)
	local reach = PlayerConfig.Movement.WallJump.DetectDistance + BODY_RADIUS + (extraDistance or 0)
	local bestDistance = math.huge
	local bestNormal: Vector3? = nil
	local bestPart: BasePart? = nil
	for index = 0, SAMPLE_DIRECTIONS - 1 do
		local angle = (index / SAMPLE_DIRECTIONS) * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local result = workspace:Raycast(position, direction * reach, params)
		if result and math.abs(result.Normal.Y) < MAX_NORMAL_Y then
			local distance = (result.Position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestNormal = result.Normal
				bestPart = result.Instance :: BasePart
			end
		end
	end
	return bestNormal, bestPart
end

-- Velocity after jumping off a wall with `normal`, nudged toward where the
-- player is looking so wall jumps can be aimed.
function WallMovement.ComputeJumpVelocity(normal: Vector3, lookDirection: Vector3): Vector3
	local config = PlayerConfig.Movement.WallJump
	local away = MathUtil.SafeUnit(MathUtil.Flatten(normal), Vector3.zero)
	local look = MathUtil.SafeUnit(MathUtil.Flatten(lookDirection), away)
	-- Never push back into the wall.
	if look:Dot(away) < 0 then
		look = (look - away * look:Dot(away))
		look = MathUtil.SafeUnit(look, away)
	end
	local horizontal = MathUtil.SafeUnit(away * 0.7 + look * 0.6, away) * config.PushSpeed
	return Vector3.new(horizontal.X, config.UpPower, horizontal.Z)
end

return WallMovement
