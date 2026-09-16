--!strict
-- Procedural floor generation. Three algorithms, selected per-biome via
-- BiomeDef.generationAlgorithm, because a single algorithm reused across
-- every biome is the #1 AI-dungeon tell called out in the design brief:
--   BSP            - Crypt: planned architecture that has partially collapsed,
--                     so room-and-corridor generation with irregular room
--                     sizing and loop-backs reads truer than an organic cave.
--   CellularAutomata - Fungal Depths: no original floor plan, so automata-
--                     carved caverns read truer than planned rooms.
--   HazardGrid      - Molten Forge: BSP rooms with a second pass marking a
--                     subset of tiles as collapsing/lava hazards.
--
-- Output of every algorithm is a TileGrid (2D array of Tile) plus a RoomList,
-- kept algorithm-agnostic so InstanceBuilder (the part that turns a TileGrid
-- into real Parts/Models) and vault seeding don't care which algorithm ran.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

export type TileKind = "Empty" | "Floor" | "Wall" | "Hazard" | "Door" | "VaultFloor"

export type Tile = {
	kind: TileKind,
}

export type Room = {
	x: number,
	y: number,
	width: number,
	height: number,
	isVault: boolean,
	isSecret: boolean,
}

export type GeneratedFloor = {
	grid: { { Tile } }, -- grid[y][x]
	rooms: { Room },
	width: number,
	height: number,
	seed: number,
}

local DungeonGenerator = {}

local GRID_WIDTH = 90
local GRID_HEIGHT = 90
local MIN_LEAF_SIZE = 10 -- BSP: smallest partition before we stop splitting

local function newGrid(width: number, height: number): { { Tile } }
	local grid = table.create(height)
	for y = 1, height do
		local row = table.create(width)
		for x = 1, width do
			row[x] = { kind = "Empty" }
		end
		grid[y] = row
	end
	return grid
end

local function carveRoom(grid: { { Tile } }, room: Room)
	for y = room.y, room.y + room.height - 1 do
		for x = room.x, room.x + room.width - 1 do
			if grid[y] and grid[y][x] then
				grid[y][x].kind = room.isVault and "VaultFloor" or "Floor"
			end
		end
	end
end

local function carveCorridor(grid: { { Tile } }, x1: number, y1: number, x2: number, y2: number)
	-- L-shaped corridor: horizontal first then vertical. Randomizing the
	-- elbow order per-corridor (done by the caller) is what produces loops
	-- and prevents every corridor reading as the same right-angle stamp.
	local x, y = x1, y1
	while x ~= x2 do
		if grid[y] and grid[y][x] then
			grid[y][x].kind = "Floor"
		end
		x += (x2 > x) and 1 or -1
	end
	while y ~= y2 do
		if grid[y] and grid[y][x] then
			grid[y][x].kind = "Floor"
		end
		y += (y2 > y) and 1 or -1
	end
end

-- ── BSP (Crypt) ────────────────────────────────────────────────────────────

type BSPLeaf = {
	x: number,
	y: number,
	width: number,
	height: number,
	left: BSPLeaf?,
	right: BSPLeaf?,
	room: Room?,
}

local function splitLeaf(leaf: BSPLeaf, rng: Random): boolean
	if leaf.left or leaf.right then
		return false -- already split
	end

	local splitHorizontal = rng:NextNumber() > 0.5
	if leaf.width > leaf.height and leaf.width / leaf.height >= 1.25 then
		splitHorizontal = false
	elseif leaf.height > leaf.width and leaf.height / leaf.width >= 1.25 then
		splitHorizontal = true
	end

	local maxSize = (splitHorizontal and leaf.height or leaf.width) - MIN_LEAF_SIZE
	if maxSize <= MIN_LEAF_SIZE then
		return false -- too small to split further
	end

	local splitAt = rng:NextInteger(MIN_LEAF_SIZE, maxSize)
	if splitHorizontal then
		leaf.left = { x = leaf.x, y = leaf.y, width = leaf.width, height = splitAt }
		leaf.right = { x = leaf.x, y = leaf.y + splitAt, width = leaf.width, height = leaf.height - splitAt }
	else
		leaf.left = { x = leaf.x, y = leaf.y, width = splitAt, height = leaf.height }
		leaf.right = { x = leaf.x + splitAt, y = leaf.y, width = leaf.width - splitAt, height = leaf.height }
	end
	return true
end

local function buildBSPTree(leaf: BSPLeaf, rng: Random, depth: number)
	if depth <= 0 then
		return
	end
	if splitLeaf(leaf, rng) then
		buildBSPTree(leaf.left :: BSPLeaf, rng, depth - 1)
		buildBSPTree(leaf.right :: BSPLeaf, rng, depth - 1)
	end
end

local function leafCenter(leaf: BSPLeaf): (number, number)
	if leaf.room then
		return leaf.room.x + math.floor(leaf.room.width / 2), leaf.room.y + math.floor(leaf.room.height / 2)
	end
	-- descend to a child's room if this leaf was split but never got its own room
	local child = (leaf.left and leaf.left.room) and leaf.left or leaf.right
	return leafCenter(child :: BSPLeaf)
end

local function createRoomsAndCorridors(leaf: BSPLeaf, grid: { { Tile } }, rng: Random, rooms: { Room })
	if leaf.left or leaf.right then
		if leaf.left then
			createRoomsAndCorridors(leaf.left, grid, rng, rooms)
		end
		if leaf.right then
			createRoomsAndCorridors(leaf.right, grid, rng, rooms)
		end
		if leaf.left and leaf.right then
			local x1, y1 = leafCenter(leaf.left)
			local x2, y2 = leafCenter(leaf.right)
			-- 35% chance to carve the elbow the other direction too, creating a
			-- loop instead of a single dead-end corridor - loops are called out
			-- explicitly as required, not optional, in the anti-slop brief.
			carveCorridor(grid, x1, y1, x2, y2)
			if rng:NextNumber() < 0.35 then
				carveCorridor(grid, x2, y1, x1, y2)
			end
		end
		return
	end

	-- Leaf room sized irregularly within its partition, never filling the
	-- whole leaf, so rooms read as varied rather than a uniform grid.
	local roomWidth = rng:NextInteger(math.max(5, math.floor(leaf.width * 0.4)), math.max(6, leaf.width - 2))
	local roomHeight = rng:NextInteger(math.max(5, math.floor(leaf.height * 0.4)), math.max(6, leaf.height - 2))
	local roomX = leaf.x + rng:NextInteger(1, math.max(1, leaf.width - roomWidth - 1))
	local roomY = leaf.y + rng:NextInteger(1, math.max(1, leaf.height - roomHeight - 1))

	local room: Room = {
		x = roomX,
		y = roomY,
		width = roomWidth,
		height = roomHeight,
		isVault = false,
		isSecret = false,
	}
	leaf.room = room
	table.insert(rooms, room)
	carveRoom(grid, room)
end

function DungeonGenerator.GenerateBSP(seed: number, floorConfig: Types.FloorConfig): GeneratedFloor
	local rng = Random.new(seed)
	local grid = newGrid(GRID_WIDTH, GRID_HEIGHT)
	local rooms: { Room } = {}

	local root: BSPLeaf = { x = 2, y = 2, width = GRID_WIDTH - 4, height = GRID_HEIGHT - 4 }
	-- Split depth scales with target room count so minRooms/maxRooms from the
	-- floor config actually influence layout size rather than being decorative.
	local targetDepth = math.clamp(math.ceil(math.log(floorConfig.maxRooms, 2)), 3, 6)
	buildBSPTree(root, rng, targetDepth)
	createRoomsAndCorridors(root, grid, rng, rooms)

	DungeonGenerator._seedVaults(grid, rooms, rng, floorConfig)

	return { grid = grid, rooms = rooms, width = GRID_WIDTH, height = GRID_HEIGHT, seed = seed }
end

-- ── Cellular Automata (Fungal Depths) ──────────────────────────────────────

local CA_INITIAL_WALL_CHANCE = 0.45
local CA_ITERATIONS = 5
local CA_BIRTH_LIMIT = 4 -- a wall cell becomes floor if it has < this many wall neighbors
local CA_SURVIVE_LIMIT = 3 -- a floor cell becomes wall if it has >= this many wall neighbors... (see step function)

local function countWallNeighbors(grid: { { boolean } }, x: number, y: number, width: number, height: number): number
	local count = 0
	for dy = -1, 1 do
		for dx = -1, 1 do
			if not (dx == 0 and dy == 0) then
				local nx, ny = x + dx, y + dy
				if nx < 1 or ny < 1 or nx > width or ny > height then
					count += 1 -- treat out-of-bounds as walls so caves don't leak to the edge
				elseif grid[ny][nx] then
					count += 1
				end
			end
		end
	end
	return count
end

local function stepAutomata(grid: { { boolean } }, width: number, height: number): { { boolean } }
	local next = table.create(height)
	for y = 1, height do
		local row = table.create(width)
		for x = 1, width do
			local wallNeighbors = countWallNeighbors(grid, x, y, width, height)
			if grid[y][x] then
				row[x] = wallNeighbors >= CA_SURVIVE_LIMIT
			else
				row[x] = wallNeighbors > CA_BIRTH_LIMIT
			end
		end
		next[y] = row
	end
	return next
end

-- Flood-fill to find the largest connected open region, so the carved cave is
-- always fully traversable instead of splitting into disconnected pockets -
-- a failure mode automata generation is prone to without this pass.
local function keepLargestRegion(walls: { { boolean } }, width: number, height: number): { { boolean } }
	local visited = {}
	local regions: { { { x: number, y: number } } } = {}

	for y = 1, height do
		for x = 1, width do
			local key = y * width + x
			if not walls[y][x] and not visited[key] then
				local region = {}
				local stack = { { x = x, y = y } }
				visited[key] = true
				while #stack > 0 do
					local cell = table.remove(stack) :: { x: number, y: number }
					table.insert(region, cell)
					for _, delta in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local nx, ny = cell.x + delta[1], cell.y + delta[2]
						local nkey = ny * width + nx
						if nx >= 1 and ny >= 1 and nx <= width and ny <= height and not walls[ny][nx] and not visited[nkey] then
							visited[nkey] = true
							table.insert(stack, { x = nx, y = ny })
						end
					end
				end
				table.insert(regions, region)
			end
		end
	end

	table.sort(regions, function(a, b)
		return #a > #b
	end)

	local result = table.create(height)
	for y = 1, height do
		local row = table.create(width)
		for x = 1, width do
			row[x] = true -- default to wall; only the largest region gets carved back open
		end
		result[y] = row
	end
	if regions[1] then
		for _, cell in regions[1] do
			result[cell.y][cell.x] = false
		end
	end
	return result
end

function DungeonGenerator.GenerateCellularAutomata(seed: number, floorConfig: Types.FloorConfig): GeneratedFloor
	local rng = Random.new(seed)
	local width, height = GRID_WIDTH, GRID_HEIGHT

	local walls = table.create(height)
	for y = 1, height do
		local row = table.create(width)
		for x = 1, width do
			row[x] = rng:NextNumber() < CA_INITIAL_WALL_CHANCE
		end
		walls[y] = row
	end

	for _ = 1, CA_ITERATIONS do
		walls = stepAutomata(walls, width, height)
	end
	walls = keepLargestRegion(walls, width, height)

	local grid = newGrid(width, height)
	for y = 1, height do
		for x = 1, width do
			grid[y][x].kind = walls[y][x] and "Wall" or "Floor"
		end
	end

	-- Rooms list for automata caves is derived, not authored: each is a coarse
	-- bounding pocket used only for enemy-density/vault placement, not literal
	-- geometry, since automata caves don't have discrete "rooms."
	local rooms: { Room } = {
		{ x = 1, y = 1, width = width, height = height, isVault = false, isSecret = false },
	}

	DungeonGenerator._seedVaults(grid, rooms, rng, floorConfig)

	return { grid = grid, rooms = rooms, width = width, height = height, seed = seed }
end

-- ── Hazard Grid (Molten Forge) ─────────────────────────────────────────────

function DungeonGenerator.GenerateHazardGrid(seed: number, floorConfig: Types.FloorConfig): GeneratedFloor
	-- Molten Forge reuses BSP for its planned-industrial-space room shapes,
	-- then layers a hazard pass on top - see module doc for why.
	local floor = DungeonGenerator.GenerateBSP(seed, floorConfig)
	local rng = Random.new(seed + 1) -- distinct RNG stream so hazard placement doesn't correlate with room layout

	for y = 1, floor.height do
		for x = 1, floor.width do
			local tile = floor.grid[y][x]
			if tile.kind == "Floor" and rng:NextNumber() < floorConfig.hazardDensity then
				tile.kind = "Hazard"
			end
		end
	end

	return floor
end

-- ── Vault / prefab seeding ──────────────────────────────────────────────────

-- Marks one eligible room as a hand-placed vault per floorConfig.vaultChance.
-- The actual vault contents (a Model under ServerStorage.Vaults) are stamped
-- in by InstanceBuilder during instancing, keyed off Room.isVault - generation
-- only decides placement, never authors vault geometry itself.
function DungeonGenerator._seedVaults(grid: { { Tile } }, rooms: { Room }, rng: Random, floorConfig: Types.FloorConfig)
	if #rooms <= 1 or rng:NextNumber() > floorConfig.vaultChance then
		return
	end
	-- Bias toward rooms that aren't the first (spawn) or last (likely exit)
	-- room so vaults don't sit right next to the entrance.
	local candidateStart = math.min(2, #rooms)
	local candidateEnd = math.max(candidateStart, #rooms - 1)
	local index = rng:NextInteger(candidateStart, candidateEnd)
	local room = rooms[index]
	room.isVault = true
	room.isSecret = rng:NextNumber() < 0.4 -- some vaults are in-the-open rewards, some require finding a hidden entrance
	carveRoom(grid, room)
end

-- Dispatches to the correct algorithm based on the biome's declared
-- generationAlgorithm. This is the only place that needs to know all three
-- algorithms exist; everything downstream just consumes a GeneratedFloor.
function DungeonGenerator.Generate(seed: number, biome: Types.BiomeDef, floorConfig: Types.FloorConfig): GeneratedFloor
	if floorConfig.isBossFloor then
		-- Boss floors are single hand-placed vault arenas, not generated -
		-- InstanceBuilder loads floorConfig's arena vault wholesale.
		local grid = newGrid(GRID_WIDTH, GRID_HEIGHT)
		return { grid = grid, rooms = {}, width = GRID_WIDTH, height = GRID_HEIGHT, seed = seed }
	elseif biome.generationAlgorithm == "BSP" then
		return DungeonGenerator.GenerateBSP(seed, floorConfig)
	elseif biome.generationAlgorithm == "CellularAutomata" then
		return DungeonGenerator.GenerateCellularAutomata(seed, floorConfig)
	elseif biome.generationAlgorithm == "HazardGrid" then
		return DungeonGenerator.GenerateHazardGrid(seed, floorConfig)
	end
	error(`Unknown generation algorithm: {biome.generationAlgorithm}`)
end

return DungeonGenerator
