--[[
	CORE STATION (placeholder geometry)
	Indoor energy facility built around a central reactor.
	  * Reactor column in the middle blocks every cross-map sightline
	  * Inner ring room with four doorways
	  * Outer circular corridor with doorways to side corridors
	  * Upper catwalk ring reached by inner jump pads; corner shafts launch to vantage ledges
	  * Separate spawn rooms for each team plus neutral side rooms
	Side A spawns at -Z, side B at +Z.
]]

local Colors = {
	Floor = Color3.fromRGB(40, 48, 58),
	Wall = Color3.fromRGB(60, 72, 86),
	WallAlt = Color3.fromRGB(75, 88, 104),
	Cover = Color3.fromRGB(95, 110, 125),
	Reactor = Color3.fromRGB(30, 255, 200),
	Catwalk = Color3.fromRGB(85, 95, 110),
	Teal = Color3.fromRGB(30, 255, 200),
	Amber = Color3.fromRGB(255, 180, 50),
	Blue = Color3.fromRGB(70, 140, 255),
}

local WALL_HEIGHT = 14
local CATWALK = 15 -- catwalk surface height
local CEILING = 30

local function half(b)
	-- Spawn room (south) connected to the outer corridor by a short hall.
	b:Block(Vector3.new(50, WALL_HEIGHT, 2), Vector3.new(0, WALL_HEIGHT / 2, -98), Colors.Wall, Enum.Material.Metal, "SpawnWall")
	b:Block(Vector3.new(2, WALL_HEIGHT, 22), Vector3.new(-25, WALL_HEIGHT / 2, -87), Colors.Wall, Enum.Material.Metal, "SpawnWall")
	b:Block(Vector3.new(2, WALL_HEIGHT, 22), Vector3.new(25, WALL_HEIGHT / 2, -87), Colors.Wall, Enum.Material.Metal, "SpawnWall")
	b:Block(Vector3.new(18, WALL_HEIGHT, 2), Vector3.new(-16, WALL_HEIGHT / 2, -76), Colors.WallAlt, Enum.Material.Metal, "SpawnWall")
	b:Block(Vector3.new(18, WALL_HEIGHT, 2), Vector3.new(16, WALL_HEIGHT / 2, -76), Colors.WallAlt, Enum.Material.Metal, "SpawnWall")
	b:Block(Vector3.new(10, 5, 2), Vector3.new(0, 2.5, -82), Colors.Cover, Enum.Material.Metal, "SpawnCover")
	b:Neon(Vector3.new(14, 0.4, 0.4), Vector3.new(0, WALL_HEIGHT - 0.5, -76.8), Colors.Blue)
	for index = 0, 5 do
		b:Spawn(Vector3.new(-17.5 + index * 7, 0, -92), "A")
	end

	-- Neutral side room (west).
	b:Block(Vector3.new(2, WALL_HEIGHT, 40), Vector3.new(-98, WALL_HEIGHT / 2, 0), Colors.Wall, Enum.Material.Metal, "SideWall")
	b:Block(Vector3.new(22, WALL_HEIGHT, 2), Vector3.new(-87, WALL_HEIGHT / 2, -20), Colors.Wall, Enum.Material.Metal, "SideWall")
	-- (Mirrors into the west room's north wall.)
	b:Block(Vector3.new(22, WALL_HEIGHT, 2), Vector3.new(87, WALL_HEIGHT / 2, -20), Colors.Wall, Enum.Material.Metal, "SideWall")
	b:Block(Vector3.new(4, 4, 8), Vector3.new(-88, 2, 0), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Spawn(Vector3.new(-92, 0, -12), nil, Vector3.new(0, 0, 0))
	b:Light(Vector3.new(-88, 10, 0), Colors.Amber, 26, 1.5)

	-- Outer boundary for this half.
	b:Block(Vector3.new(200, CEILING, 2), Vector3.new(0, CEILING / 2, -100), Colors.Wall, Enum.Material.Metal, "Outer")
	b:Block(Vector3.new(2, CEILING, 100), Vector3.new(-100, CEILING / 2, -50), Colors.Wall, Enum.Material.Metal, "Outer")
	b:Block(Vector3.new(2, CEILING, 100), Vector3.new(100, CEILING / 2, -50), Colors.Wall, Enum.Material.Metal, "Outer")

	-- Vertical shaft in the outer corner: launch pad up to a vantage ledge.
	b:Block(Vector3.new(2, WALL_HEIGHT, 14), Vector3.new(-54, WALL_HEIGHT / 2, -46), Colors.WallAlt, Enum.Material.Metal, "Shaft")
	b:Block(Vector3.new(14, WALL_HEIGHT, 2), Vector3.new(-46, WALL_HEIGHT / 2, -54), Colors.WallAlt, Enum.Material.Metal, "Shaft")
	b:Block(Vector3.new(8, 1, 8), Vector3.new(-51, 17.5, -51), Colors.Catwalk, Enum.Material.DiamondPlate, "Ledge")
	b:Block(Vector3.new(8, 3, 1), Vector3.new(-51, 19.5, -47.5), Colors.Cover, Enum.Material.Metal, "LedgeCover")
	b:JumpPad(Vector3.new(-42, 0, -42), Vector3.new(-8, 100, -8), Colors.Teal)
	b:Neon(Vector3.new(0.4, CATWALK, 0.4), Vector3.new(-52.8, CATWALK / 2, -52.8), Colors.Teal)
	b:Light(Vector3.new(-46, 6, -46), Colors.Teal, 18, 2)

	-- Inner diagonal pads lift players onto the catwalk ring.
	b:JumpPad(Vector3.new(-25.5, 0, -25.5), Vector3.new(7.07, 85, 7.07), Colors.Teal)
	b:JumpPad(Vector3.new(25.5, 0, -25.5), Vector3.new(-7.07, 85, 7.07), Colors.Teal)

	-- Side corridor cover.
	b:Block(Vector3.new(6, 4, 6), Vector3.new(-72, 2, -36), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(8, 5, 2), Vector3.new(40, 2.5, -72), Colors.Cover, Enum.Material.Metal, "Barricade")
	b:Block(Vector3.new(2, 5, 8), Vector3.new(70, 2.5, -40), Colors.Cover, Enum.Material.Metal, "Barricade")

	-- Inner room cover (between reactor and ring walls).
	b:Block(Vector3.new(6, 4, 2), Vector3.new(-14, 2, -26), Colors.Cover, Enum.Material.Metal, "Cover")
	b:Block(Vector3.new(2, 4, 6), Vector3.new(26, 2, -12), Colors.Cover, Enum.Material.Metal, "Cover")

	b:Light(Vector3.new(0, 10, -60), Colors.Blue, 30, 1.5)
	b:Light(Vector3.new(60, 10, -60), Colors.Amber, 30, 1.2)

	-- Neutral spawns + bot nodes.
	b:Spawn(Vector3.new(60, 0, -70), nil)
	b:Spawn(Vector3.new(-20.5, CATWALK, -20.5), nil)
	b:Spawn(Vector3.new(-51, 18, -51), nil)
	for _, node in
		{
			Vector3.new(0, 0, -60),
			Vector3.new(-50, 0, -20),
			Vector3.new(50, 0, -20),
			Vector3.new(-20, 0, -20),
			Vector3.new(20, 0, -25),
			Vector3.new(0, 0, -30),
			Vector3.new(-60, 0, -60),
			Vector3.new(60, 0, -55),
			Vector3.new(0, CATWALK, -29),
			Vector3.new(-80, 0, 0),
		}
	do
		b:BotNode(node)
	end
end

return {
	KillY = -40,
	Build = function(b)
		b:Block(Vector3.new(204, 2, 204), Vector3.new(0, -1, 0), Colors.Floor, Enum.Material.DiamondPlate, "Floor")
		local ceiling = b:Block(Vector3.new(204, 2, 204), Vector3.new(0, CEILING + 1, 0), Colors.Wall, Enum.Material.Metal, "Ceiling")
		ceiling.CastShadow = false
		b:Mirrored(half)

		-- Inner ring room: 12 segments, doorways at 4 positions.
		b:Ring(40, 12, 2, WALL_HEIGHT, 0, Colors.WallAlt, { 1, 4, 7, 10 }, Enum.Material.Metal)
		-- Outer ring corridor wall with diagonal + cardinal doorways.
		b:Ring(62, 16, 2, WALL_HEIGHT, 0, Colors.Wall, { 1, 3, 5, 7, 9, 11, 13, 15 }, Enum.Material.Metal)
		-- Upper catwalk ring.
		b:RingFloor(29, 16, 6, CATWALK, Colors.Catwalk, Enum.Material.DiamondPlate)

		-- Reactor.
		b:Cylinder(16, CEILING, Vector3.new(0, CEILING / 2, 0), Colors.WallAlt, Enum.Material.Metal)
		b:Cylinder(16.6, 3, Vector3.new(0, 6, 0), Colors.Reactor, Enum.Material.Neon).CanCollide = false
		b:Cylinder(16.6, 3, Vector3.new(0, 20, 0), Colors.Reactor, Enum.Material.Neon).CanCollide = false
		b:Light(Vector3.new(0, 12, 12), Colors.Teal, 40, 3)
		b:Light(Vector3.new(0, 12, -12), Colors.Teal, 40, 3)
	end,
}
