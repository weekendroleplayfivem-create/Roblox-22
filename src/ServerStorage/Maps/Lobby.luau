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

		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			b:Spawn(Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12 - 20), nil, Vector3.new(0, 0, -68))
		end
		b:Light(Vector3.new(0, 18, 0), Colors.Cyan, 60, 1.5)
		b:Light(Vector3.new(0, 10, 40), Colors.Pink, 30, 1.5)
	end,
}
