--[[
	NEON DISTRICT (placeholder geometry)
	Futuristic city block. Point-symmetric for team modes.
	  * Central raised plaza with a hologram pillar that breaks the long middle sightline
	  * Rooftops (ramp + jump pad access) joined by sky bridges on both flanks
	  * Side alleys behind shop rows
	  * Passages through each building at street level
	Side A (Nova) spawns at -Z, side B (Flux) at +Z.
]]

local Colors = {
	Ground = Color3.fromRGB(28, 28, 42),
	Street = Color3.fromRGB(38, 36, 58),
	Wall = Color3.fromRGB(45, 40, 75),
	Building = Color3.fromRGB(58, 52, 96),
	BuildingAlt = Color3.fromRGB(74, 62, 118),
	Shop = Color3.fromRGB(50, 70, 100),
	Cover = Color3.fromRGB(95, 90, 130),
	Plaza = Color3.fromRGB(48, 46, 78),
	Cyan = Color3.fromRGB(40, 225, 255),
	Pink = Color3.fromRGB(255, 80, 200),
	Yellow = Color3.fromRGB(255, 210, 70),
}

local ROOF = 14

local function building(b, x: number, z: number, accent: Color3)
	-- Two halves with a street-level passage between them (x-axis split).
	local depth = 36
	b:Block(Vector3.new(12, ROOF, depth), Vector3.new(x - 11, ROOF / 2, z), Colors.Building, Enum.Material.SmoothPlastic, "Building")
	b:Block(Vector3.new(12, ROOF, depth), Vector3.new(x + 11, ROOF / 2, z), Colors.BuildingAlt, Enum.Material.SmoothPlastic, "Building")
	b:Block(Vector3.new(10, 6, depth), Vector3.new(x, ROOF - 3, z), Colors.Building, Enum.Material.SmoothPlastic, "Building")
	-- Roof trim + low rooftop cover.
	b:Neon(Vector3.new(34.4, 0.4, 0.4), Vector3.new(x, ROOF + 0.1, z - depth / 2), accent)
	b:Neon(Vector3.new(34.4, 0.4, 0.4), Vector3.new(x, ROOF + 0.1, z + depth / 2), accent)
	b:Neon(Vector3.new(0.4, 0.4, depth), Vector3.new(x - 17, ROOF + 0.1, z), accent)
	b:Neon(Vector3.new(0.4, 0.4, depth), Vector3.new(x + 17, ROOF + 0.1, z), accent)
	b:Neon(Vector3.new(10.4, 0.3, 0.3), Vector3.new(x, ROOF - 6.2, z - depth / 2), accent)
	b:Block(Vector3.new(6, 3, 1.5), Vector3.new(x - 6, ROOF + 1.5, z - 6), Colors.Cover, Enum.Material.Metal, "Cover")
	b:Block(Vector3.new(1.5, 3, 6), Vector3.new(x + 8, ROOF + 1.5, z + 6), Colors.Cover, Enum.Material.Metal, "Cover")
	b:Light(Vector3.new(x, ROOF - 7, z), accent, 18, 1.5)
end

local function half(b)
	-- Outer walls for this half (visible) + tall invisible barriers above them.
	b:Block(Vector3.new(228, 26, 4), Vector3.new(0, 13, -137), Colors.Wall, Enum.Material.Concrete, "Boundary")
	b:Block(Vector3.new(4, 26, 137), Vector3.new(-112, 13, -68.5), Colors.Wall, Enum.Material.Concrete, "Boundary")
	b:Block(Vector3.new(4, 26, 137), Vector3.new(112, 13, -68.5), Colors.Wall, Enum.Material.Concrete, "Boundary")
	b:Barrier(Vector3.new(228, 80, 4), Vector3.new(0, 66, -137))
	b:Barrier(Vector3.new(4, 80, 137), Vector3.new(-112, 66, -68.5))
	b:Barrier(Vector3.new(4, 80, 137), Vector3.new(112, 66, -68.5))
	b:Neon(Vector3.new(228, 0.5, 0.5), Vector3.new(0, 26, -134.8), Colors.Cyan)

	-- Spawn zone with sightline blockers in front.
	for index = 0, 5 do
		b:Spawn(Vector3.new(-45 + index * 18, 0, -122), "A")
	end
	b:Block(Vector3.new(26, 7, 2), Vector3.new(-32, 3.5, -102), Colors.Cover, Enum.Material.Metal, "SpawnCover")
	b:Block(Vector3.new(26, 7, 2), Vector3.new(32, 3.5, -102), Colors.Cover, Enum.Material.Metal, "SpawnCover")
	b:Neon(Vector3.new(26, 0.3, 0.3), Vector3.new(-32, 7, -102), Colors.Yellow)
	b:Neon(Vector3.new(26, 0.3, 0.3), Vector3.new(32, 7, -102), Colors.Yellow)
	b:Sign("VECTOR RUSH", Vector3.new(30, 6, 1), Vector3.new(0, 20, -134), Colors.Cyan, Vector3.new(0, 20, 0))

	-- Buildings: west reached by ramp, east by jump pad. Both have inner pads.
	building(b, -62, -45, Colors.Cyan)
	building(b, 62, -45, Colors.Pink)
	b:Ramp(Vector3.new(-73, 0, -96), Vector3.new(-73, ROOF, -63.5), 10, Colors.Street, Enum.Material.DiamondPlate)
	b:JumpPad(Vector3.new(32, 0, -45), Vector3.new(28, 88, 0), Colors.Pink)
	b:JumpPad(Vector3.new(-32, 0, -30), Vector3.new(-28, 88, 0), Colors.Cyan)

	-- West sky bridge (mirrored pass creates the east one).
	b:Block(Vector3.new(8, 1, 54.2), Vector3.new(-62, ROOF - 0.5, 0), Colors.Street, Enum.Material.DiamondPlate, "Bridge")
	b:Neon(Vector3.new(0.3, 0.3, 54), Vector3.new(-66, ROOF + 0.2, 0), Colors.Yellow)
	b:Block(Vector3.new(1, 3, 5), Vector3.new(-60, ROOF + 1.5, -10), Colors.Cover, Enum.Material.Metal, "Cover")

	-- Shop rows create the side alleys.
	b:Block(Vector3.new(16, 10, 44), Vector3.new(-102, 5, -40), Colors.Shop, Enum.Material.SmoothPlastic, "Shop")
	b:Block(Vector3.new(16, 10, 44), Vector3.new(102, 5, -40), Colors.Shop, Enum.Material.SmoothPlastic, "Shop")
	b:Neon(Vector3.new(0.3, 2, 40), Vector3.new(-93.9, 7, -40), Colors.Pink)
	b:Neon(Vector3.new(0.3, 2, 40), Vector3.new(93.9, 7, -40), Colors.Cyan)
	b:Block(Vector3.new(5, 4, 5), Vector3.new(-87, 2, -52), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(5, 6, 5), Vector3.new(-84, 3, -22), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(5, 4, 5), Vector3.new(86, 2, -30), Colors.Cover, Enum.Material.Metal, "Crate")

	-- Street cover.
	b:Block(Vector3.new(6, 5, 6), Vector3.new(-25, 2.5, -45), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(6, 5, 6), Vector3.new(24, 2.5, -62), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(16, 4, 2), Vector3.new(0, 2, -62), Colors.Cover, Enum.Material.Metal, "Wall")
	b:Block(Vector3.new(4, 6, 10), Vector3.new(-40, 3, -14), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(4, 4, 8), Vector3.new(40, 2, -22), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(10, 3, 2), Vector3.new(-14, 1.5, -80), Colors.Cover, Enum.Material.Metal, "Barricade")
	b:Block(Vector3.new(10, 3, 2), Vector3.new(16, 1.5, -86), Colors.Cover, Enum.Material.Metal, "Barricade")

	-- Plaza ramps (stage itself is built once, outside the mirrored pass).
	b:Ramp(Vector3.new(0, 0, -30), Vector3.new(0, 4, -15.5), 10, Colors.Plaza, Enum.Material.DiamondPlate)
	b:Ramp(Vector3.new(-30, 0, 0), Vector3.new(-15.5, 4, 0), 10, Colors.Plaza, Enum.Material.DiamondPlate)
	b:Block(Vector3.new(8, 3, 1.5), Vector3.new(-9, 5.5, -10), Colors.Cover, Enum.Material.Metal, "StageCover")
	b:Neon(Vector3.new(30.2, 0.3, 0.3), Vector3.new(0, 4.1, -15), Colors.Cyan)

	-- Street lights.
	b:Light(Vector3.new(-40, 10, -80), Colors.Cyan, 30, 1.5)
	b:Light(Vector3.new(40, 10, -80), Colors.Pink, 30, 1.5)
	b:Light(Vector3.new(-87, 8, -40), Colors.Yellow, 22, 1.5)
	b:Light(Vector3.new(0, 8, -40), Colors.Cyan, 26, 1.2)

	-- Neutral spawns (used by FFA / Gun Game and as overflow in TDM).
	b:Spawn(Vector3.new(-87, 0, -8), nil)
	b:Spawn(Vector3.new(66, ROOF, -50), nil)
	b:Spawn(Vector3.new(-20, 0, -72), nil)
	b:Spawn(Vector3.new(-62, 0, -45), nil, Vector3.new(-62, 0, 0))

	-- Bot navigation nodes.
	for _, node in
		{
			Vector3.new(0, 4, -8),
			Vector3.new(-62, ROOF, -45),
			Vector3.new(62, ROOF, -45),
			Vector3.new(-62, ROOF, -15),
			Vector3.new(-87, 0, -40),
			Vector3.new(-25, 0, -30),
			Vector3.new(25, 0, -30),
			Vector3.new(0, 0, -45),
			Vector3.new(-45, 0, -82),
			Vector3.new(45, 0, -82),
			Vector3.new(40, 0, -45),
		}
	do
		b:BotNode(node)
	end
end

return {
	KillY = -60,
	Build = function(b)
		b:Block(Vector3.new(228, 2, 278), Vector3.new(0, -1, 0), Colors.Ground, Enum.Material.Concrete, "Ground")
		b:Block(Vector3.new(60, 0.2, 270), Vector3.new(0, 0.1, 0), Colors.Street, Enum.Material.SmoothPlastic, "Street")
		b:Mirrored(half)

		-- Central plaza stage and hologram pillar (on the symmetry point).
		b:Block(Vector3.new(30, 4, 30), Vector3.new(0, 2, 0), Colors.Plaza, Enum.Material.SmoothPlastic, "Stage")
		b:Block(Vector3.new(6, 14, 6), Vector3.new(0, 11, 0), Colors.BuildingAlt, Enum.Material.Glass, "Pillar")
		b:Neon(Vector3.new(6.4, 0.5, 6.4), Vector3.new(0, 8, 0), Colors.Cyan)
		b:Neon(Vector3.new(6.4, 0.5, 6.4), Vector3.new(0, 13, 0), Colors.Pink)
		b:Neon(Vector3.new(6.4, 0.5, 6.4), Vector3.new(0, 17.8, 0), Colors.Yellow)
		b:Light(Vector3.new(0, 20, 0), Colors.Cyan, 40, 2)
	end,
}
