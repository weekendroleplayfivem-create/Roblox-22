--[[
	LOBBY (placeholder geometry)
	A small hangout space where players spawn, browse menus and queue.
	Includes a couple of jump pads and a dash lane so new players can try
	movement before their first match. Combat is disabled in the lobby.
]]

local Colors = {
	Floor = Color3.fromRGB(35, 30, 60),
	Tile = Color3.fromRGB(50, 44, 86),
	Wall = Color3.fromRGB(45, 40, 80),
	Cyan = Color3.fromRGB(40, 225, 255),
	Pink = Color3.fromRGB(255, 80, 200),
	Yellow = Color3.fromRGB(255, 210, 70),
	Green = Color3.fromRGB(110, 255, 150),
	Purple = Color3.fromRGB(170, 110, 255),
}

return {
	KillY = -60,
	Build = function(b)
		b:Block(Vector3.new(140, 2, 140), Vector3.new(0, -1, 0), Colors.Floor, Enum.Material.SmoothPlastic, "Floor")
		for x = -2, 2 do
			for z = -2, 2 do
				if (x + z) % 2 == 0 then
					b:Block(Vector3.new(20, 0.2, 20), Vector3.new(x * 24, 0.1, z * 24), Colors.Tile, Enum.Material.SmoothPlastic, "Tile")
				end
			end
		end
		for _, data in
			{
				{ Vector3.new(140, 20, 2), Vector3.new(0, 10, -70) },
				{ Vector3.new(140, 20, 2), Vector3.new(0, 10, 70) },
				{ Vector3.new(2, 20, 140), Vector3.new(-70, 10, 0) },
				{ Vector3.new(2, 20, 140), Vector3.new(70, 10, 0) },
			}
		do
			b:Block(data[1], data[2], Colors.Wall, Enum.Material.SmoothPlastic, "Wall")
			b:Barrier(Vector3.new(data[1].X, 80, data[1].Z), data[2] + Vector3.new(0, 50, 0))
		end
		b:Neon(Vector3.new(140, 0.5, 0.5), Vector3.new(0, 20, -68.8), Colors.Cyan)
		b:Neon(Vector3.new(140, 0.5, 0.5), Vector3.new(0, 20, 68.8), Colors.Pink)
		b:Sign("VECTOR RUSH", Vector3.new(50, 10, 1), Vector3.new(0, 12, -68), Colors.Cyan, Vector3.new(0, 12, 0))

		-- Movement playground.
		b:JumpPad(Vector3.new(-30, 0, 30), Vector3.new(0, 110, 0), Colors.Pink)
		b:JumpPad(Vector3.new(30, 0, 30), Vector3.new(0, 110, 0), Colors.Cyan)
		b:Block(Vector3.new(16, 16, 16), Vector3.new(-50, 8, 50), Colors.Wall, Enum.Material.SmoothPlastic, "Tower")
		b:Block(Vector3.new(16, 16, 16), Vector3.new(50, 8, 50), Colors.Wall, Enum.Material.SmoothPlastic, "Tower")
		b:Block(Vector3.new(2, 14, 30), Vector3.new(0, 7, 40), Colors.Tile, Enum.Material.SmoothPlastic, "WallJumpWall")
		b:Neon(Vector3.new(2.2, 0.4, 30), Vector3.new(0, 14, 40), Colors.Yellow)
		b:Ramp(Vector3.new(-50, 0, 20), Vector3.new(-50, 16, 42), 8, Colors.Tile, Enum.Material.DiamondPlate)
		b:Ramp(Vector3.new(50, 0, 20), Vector3.new(50, 16, 42), 8, Colors.Tile, Enum.Material.DiamondPlate)

		-- Showpiece: floating logo with halo rings above a glowing dais.
		b:Block(Vector3.new(16, 1, 16), Vector3.new(0, 0.5, -45), Colors.Tile, Enum.Material.SmoothPlastic, "Dais")
		b:Neon(Vector3.new(16.2, 0.2, 16.2), Vector3.new(0, 1, -45), Colors.Cyan)
		b:Hologram("VECTOR RUSH", Vector3.new(22, 5, 0.3), Vector3.new(0, 11, -45), Colors.Cyan, Vector3.new(0, 11, 0))
		b:HaloRing(Vector3.new(0, 11, -45), 26, Colors.Pink, 25, 14)
		b:HaloRing(Vector3.new(0, 11, -45), 20, Colors.Cyan, -40, -10)
		local orb = b:DecoCFrame(Vector3.one * 2, CFrame.new(0, 17, -45), Colors.Yellow, Enum.Material.Neon, Enum.PartType.Ball)
		b:Bob(orb, 0.7, 0.3)
		b:Particles(orb, "Sparkle", Colors.Yellow, 8)

		-- Mode billboards along the walls.
		b:Hologram("TEAM DEATHMATCH", Vector3.new(16, 3, 0.3), Vector3.new(-66, 9, -25), Colors.Cyan, Vector3.new(0, 9, -25))
		b:Hologram("FREE FOR ALL", Vector3.new(16, 3, 0.3), Vector3.new(-66, 9, 0), Colors.Yellow, Vector3.new(0, 9, 0))
		b:Hologram("GUN GAME", Vector3.new(16, 3, 0.3), Vector3.new(-66, 9, 25), Colors.Pink, Vector3.new(0, 9, 25))
		b:Hologram("MOVEMENT COURSE", Vector3.new(18, 3, 0.3), Vector3.new(0, 18, 66), Colors.Green, Vector3.new(0, 18, 0))

		-- Trees, lamps, drones, ambient sparkles.
		for _, data in { { Vector3.new(-58, 0, -58), Colors.Green }, { Vector3.new(58, 0, -58), Colors.Pink }, { Vector3.new(58, 0, 10), Colors.Purple }, { Vector3.new(-58, 0, 10), Colors.Cyan } } do
			b:Tree(data[1], data[2], 8)
		end
		b:Lamp(Vector3.new(-20, 0, -10), 9, Colors.Cyan)
		b:Lamp(Vector3.new(20, 0, -30), 9, Colors.Pink)
		b:Drone(Vector3.new(-25, 16, -35), Colors.Cyan)
		b:Drone(Vector3.new(28, 18, 10), Colors.Pink)
		b:Drone(Vector3.new(0, 20, 30), Colors.Yellow)
		local sparkle = b:Deco(Vector3.new(120, 20, 120), Vector3.new(0, 10, 0), Colors.Floor)
		sparkle.Transparency = 1
		b:Particles(sparkle, "Dust", Color3.fromRGB(200, 180, 255), 16)

		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			b:Spawn(Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12 - 20), nil, Vector3.new(0, 0, -68))
		end
		b:Light(Vector3.new(0, 18, 0), Colors.Cyan, 60, 1.5)
		b:Light(Vector3.new(0, 10, 40), Colors.Pink, 30, 1.5)
	end,
}
