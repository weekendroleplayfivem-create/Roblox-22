--!strict
-- Helpers for the city road grid. Intersection (i, j) sits at X = i*Cell - H, Z = j*Cell - H.

local Config = require(script.Parent.Config)

local Grid = {}

local G = Config.Grid
local CELL = G.Cell
local HALF = G.HalfExtent
local N = G.Blocks -- intersections go 0..N

Grid.Size = N
Grid.Cell = CELL
Grid.Half = HALF
Grid.RoadY = G.GroundY + 0.5

function Grid.Intersection(i: number, j: number): Vector3
	return Vector3.new(i * CELL - HALF, Grid.RoadY, j * CELL - HALF)
end

function Grid.BlockCenter(bx: number, bz: number): Vector3
	return Vector3.new((bx + 0.5) * CELL - HALF, Grid.RoadY, (bz + 0.5) * CELL - HALF)
end

function Grid.InBounds(i: number, j: number): boolean
	return i >= 0 and i <= N and j >= 0 and j <= N
end

function Grid.NearestIntersection(pos: Vector3): (number, number)
	local i = math.clamp(math.round((pos.X + HALF) / CELL), 0, N)
	local j = math.clamp(math.round((pos.Z + HALF) / CELL), 0, N)
	return i, j
end

-- Midpoint of the road segment starting at intersection (i, j) along axis "x" or "z".
function Grid.SegmentMid(i: number, j: number, axis: string): Vector3
	local a = Grid.Intersection(i, j)
	local b = if axis == "x" then Grid.Intersection(i + 1, j) else Grid.Intersection(i, j + 1)
	return (a + b) / 2
end

-- Is this position on a road (not inside a block)?
function Grid.IsOnRoad(pos: Vector3): boolean
	local half = G.RoadWidth / 2
	local fx = (pos.X + HALF) % CELL
	local fz = (pos.Z + HALF) % CELL
	return fx < half or fx > CELL - half or fz < half or fz > CELL - half
end

-- Snap a position to the closest point on the road network (road centre line).
function Grid.SnapToRoad(pos: Vector3): Vector3
	local i, j = Grid.NearestIntersection(pos)
	local ix = i * CELL - HALF
	local jz = j * CELL - HALF
	local x = math.clamp(pos.X, -HALF, HALF)
	local z = math.clamp(pos.Z, -HALF, HALF)
	-- choose whichever road line (vertical x=ix or horizontal z=jz) is closer
	if math.abs(x - ix) < math.abs(z - jz) then
		return Vector3.new(ix, Grid.RoadY, z)
	else
		return Vector3.new(x, Grid.RoadY, jz)
	end
end

-- Returns the neighbouring intersections of (i, j).
function Grid.Neighbours(i: number, j: number): { { number } }
	local out = {}
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local ni, nj = i + d[1], j + d[2]
		if Grid.InBounds(ni, nj) then
			table.insert(out, { ni, nj })
		end
	end
	return out
end

return Grid
