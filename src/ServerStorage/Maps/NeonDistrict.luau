--[[
	NEON DISTRICT (placeholder geometry, procedurally detailed)
	Futuristic city block. Point-symmetric for team modes.
	Gameplay:
	  * central raised plaza; a hologram pillar breaks the middle sightline
	  * rooftops (ramp + jump pad access) joined by sky bridges on both flanks
	  * balconies with stairs on every building = a mid-height route
	    (double-jump from a balcony to reach the roof)
	  * side alleys behind shop rows, passages through each building
	Dressing: window lights, holo billboards, street lamps, neon trees, food
	kiosks, drones, rooftop machinery, steam vents, spinning plaza halos,
	floating dust. Side A (Nova) spawns at -Z, side B (Flux) at +Z.
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
	Machine = Color3.fromRGB(70, 75, 95),
	Cyan = Color3.fromRGB(40, 225, 255),
	Pink = Color3.fromRGB(255, 80, 200),
	Yellow = Color3.fromRGB(255, 210, 70),
	Green = Color3.fromRGB(110, 255, 150),
	Purple = Color3.fromRGB(170, 110, 255),
}

local ROOF = 14
local BALCONY = 7
local DEPTH = 36

local function windows(b, x: number, z: number, accent: Color3)
	-- Rows of lit windows on the faces toward the street and middle.
	for _, faceZ in { z - DEPTH / 2 - 0.06, z + DEPTH / 2 + 0.06 } do
		for row, y in { 3.5, 7.5, 11.5 } do
			for _, halfX in { x - 11, x + 11 } do
				local light = b:Deco(Vector3.new(9, 1.2, 0.1), Vector3.new(halfX, y, faceZ), if row % 2 == 0 then accent else Colors.Yellow)
				light.Transparency = 0.25
				if (row + math.floor(halfX)) % 3 == 0 then
					b:Pulse(light, 0.12, 0.15, 0.7)
				end
			end
		end
	end
end

local function building(b, x: number, z: number, accent: Color3)
	-- Two halves with a street-level passage between them (x-axis split).
	b:Block(Vector3.new(12, ROOF, DEPTH), Vector3.new(x - 11, ROOF / 2, z), Colors.Building, Enum.Material.SmoothPlastic, "Building")
	b:Block(Vector3.new(12, ROOF, DEPTH), Vector3.new(x + 11, ROOF / 2, z), Colors.BuildingAlt, Enum.Material.SmoothPlastic, "Building")
	b:Block(Vector3.new(10, 6, DEPTH), Vector3.new(x, ROOF - 3, z), Colors.Building, Enum.Material.SmoothPlastic, "Building")
	-- Roof trim + low rooftop cover.
	b:Neon(Vector3.new(34.4, 0.4, 0.4), Vector3.new(x, ROOF + 0.1, z - DEPTH / 2), accent)
	b:Neon(Vector3.new(34.4, 0.4, 0.4), Vector3.new(x, ROOF + 0.1, z + DEPTH / 2), accent)
	b:Neon(Vector3.new(0.4, 0.4, DEPTH), Vector3.new(x - 17, ROOF + 0.1, z), accent)
	b:Neon(Vector3.new(0.4, 0.4, DEPTH), Vector3.new(x + 17, ROOF + 0.1, z), accent)
	b:Neon(Vector3.new(10.4, 0.3, 0.3), Vector3.new(x, ROOF - 6.2, z - DEPTH / 2), accent)
	b:Block(Vector3.new(6, 3, 1.5), Vector3.new(x - 6, ROOF + 1.5, z - 6), Colors.Cover, Enum.Material.Metal, "Cover")
	b:Block(Vector3.new(1.5, 3, 6), Vector3.new(x + 8, ROOF + 1.5, z + 6), Colors.Cover, Enum.Material.Metal, "Cover")
	b:Light(Vector3.new(x, ROOF - 7, z), accent, 18, 1.5)
	windows(b, x, z, accent)

	-- Rooftop machinery (AC units double as cover) and an antenna with a halo.
	b:Crate(Vector3.new(x - 10, ROOF, z + 12), Vector3.new(3.5, 2.2, 3.5), Colors.Machine, accent)
	for blade = 0, 1 do
		local fan = b:DecoCFrame(Vector3.new(3, 0.1, 0.5), CFrame.new(x - 10, ROOF + 2.3, z + 12) * CFrame.Angles(0, math.rad(blade * 90), 0), Colors.Wall, Enum.Material.Metal)
		b:Spin(fan, Vector3.yAxis, 240)
	end
	b:Block(Vector3.new(0.4, 8, 0.4), Vector3.new(x + 12, ROOF + 4, z - 12), Colors.Machine, Enum.Material.Metal, "Antenna")
	local beacon = b:DecoCFrame(Vector3.one * 0.8, CFrame.new(x + 12, ROOF + 8.3, z - 12), accent, Enum.Material.Neon, Enum.PartType.Ball)
	b:Pulse(beacon, 1, 0, 0.8)
	b:HaloRing(Vector3.new(x + 12, ROOF + 6, z - 12), 3, accent, 90)

	-- Balcony on the inner face (toward the centre street) + stairs up to it.
	local inner = if x < 0 then 1 else -1
	local faceX = x + inner * 17
	local balconyX = faceX + inner * 1.5
	b:Block(Vector3.new(3, 0.6, 30), Vector3.new(balconyX, BALCONY - 0.3, z), Colors.Street, Enum.Material.DiamondPlate, "Balcony")
	b:Neon(Vector3.new(0.2, 0.2, 30), Vector3.new(balconyX + inner * 1.5, BALCONY, z), accent)
	b:Stairs(Vector3.new(balconyX, 0, z - 29), Vector3.new(balconyX, BALCONY, z - 15), 3, 7, Colors.Street, accent)
	b:BotNode(Vector3.new(balconyX, BALCONY, z))
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
	-- Skyline silhouettes behind the boundary (decoration only).
	for index = -4, 4 do
		local height = 30 + ((index * 7) % 5) * 9
		local tower = b:Deco(Vector3.new(18, height, 14), Vector3.new(index * 24, height / 2, -150 - (index % 2) * 8), Colors.Wall, Enum.Material.SmoothPlastic)
		tower.Transparency = 0
		b:Deco(Vector3.new(18.2, 0.5, 0.2), Vector3.new(index * 24, height - 2, -143 - (index % 2) * 8), if index % 2 == 0 then Colors.Pink else Colors.Cyan)
	end

	-- Spawn zone: arch, sightline blockers and floor glow.
	for index = 0, 5 do
		b:Spawn(Vector3.new(-45 + index * 18, 0, -122), "A")
	end
	b:Block(Vector3.new(26, 7, 2), Vector3.new(-32, 3.5, -102), Colors.Cover, Enum.Material.Metal, "SpawnCover")
	b:Block(Vector3.new(26, 7, 2), Vector3.new(32, 3.5, -102), Colors.Cover, Enum.Material.Metal, "SpawnCover")
	b:Neon(Vector3.new(26, 0.3, 0.3), Vector3.new(-32, 7, -102), Colors.Yellow)
	b:Neon(Vector3.new(26, 0.3, 0.3), Vector3.new(32, 7, -102), Colors.Yellow)
	b:Block(Vector3.new(2, 14, 2), Vector3.new(-54, 7, -112), Colors.Machine, Enum.Material.Metal, "ArchPillar")
	b:Block(Vector3.new(2, 14, 2), Vector3.new(54, 7, -112), Colors.Machine, Enum.Material.Metal, "ArchPillar")
	local arch = b:Deco(Vector3.new(110, 0.8, 0.8), Vector3.new(0, 14, -112), Colors.Cyan)
	b:Pulse(arch, 0.4, 0, 0.5)
	local spawnGlow = b:Deco(Vector3.new(100, 0.05, 16), Vector3.new(0, 0.23, -122), Colors.Cyan)
	spawnGlow.Transparency = 0.85
	b:Sign("VECTOR RUSH", Vector3.new(30, 6, 1), Vector3.new(0, 20, -134), Colors.Cyan, Vector3.new(0, 20, 0))

	-- Buildings: west reached by ramp, east by jump pad. Both have inner pads + balconies.
	building(b, -62, -45, Colors.Cyan)
	building(b, 62, -45, Colors.Pink)
	b:Ramp(Vector3.new(-73, 0, -96), Vector3.new(-73, ROOF, -63.5), 10, Colors.Street, Enum.Material.DiamondPlate)
	do -- glowing edge along the ramp
		local low, high = Vector3.new(-78, 0.6, -96), Vector3.new(-78, ROOF + 0.6, -63.5)
		b:DecoCFrame(Vector3.new(0.2, 0.2, (high - low).Magnitude), CFrame.lookAt((low + high) / 2, high), Colors.Cyan)
	end
	b:JumpPad(Vector3.new(32, 0, -45), Vector3.new(28, 88, 0), Colors.Pink)
	b:JumpPad(Vector3.new(-32, 0, -30), Vector3.new(-28, 88, 0), Colors.Cyan)

	-- West sky bridge (mirrored pass creates the east one).
	b:Block(Vector3.new(8, 1, 54.2), Vector3.new(-62, ROOF - 0.5, 0), Colors.Street, Enum.Material.DiamondPlate, "Bridge")
	b:Neon(Vector3.new(0.3, 0.3, 54), Vector3.new(-66, ROOF + 0.2, 0), Colors.Yellow)
	b:Neon(Vector3.new(0.3, 0.3, 54), Vector3.new(-58, ROOF + 0.2, 0), Colors.Yellow)
	b:Block(Vector3.new(1, 3, 5), Vector3.new(-60, ROOF + 1.5, -10), Colors.Cover, Enum.Material.Metal, "Cover")
	-- Glowing cables hanging under the bridge.
	b:Pipe(Vector3.new(-62, ROOF - 1.5, -27), Vector3.new(-62, ROOF - 3, 0), 0.35, Colors.Machine, Colors.Purple)

	-- Shop rows create the side alleys.
	b:Block(Vector3.new(16, 10, 44), Vector3.new(-102, 5, -40), Colors.Shop, Enum.Material.SmoothPlastic, "Shop")
	b:Block(Vector3.new(16, 10, 44), Vector3.new(102, 5, -40), Colors.Shop, Enum.Material.SmoothPlastic, "Shop")
	b:Neon(Vector3.new(0.3, 2, 40), Vector3.new(-93.9, 7, -40), Colors.Pink)
	b:Neon(Vector3.new(0.3, 2, 40), Vector3.new(93.9, 7, -40), Colors.Cyan)
	b:Hologram("ARCADE", Vector3.new(10, 3, 0.3), Vector3.new(-93.5, 12, -48), Colors.Pink, Vector3.new(0, 12, -48))
	b:Hologram("NOODLES", Vector3.new(10, 3, 0.3), Vector3.new(93.5, 12, -32), Colors.Cyan, Vector3.new(0, 12, -32))
	b:Crate(Vector3.new(-87, 0, -52), Vector3.new(5, 4, 5), Colors.Cover, Colors.Pink)
	b:Crate(Vector3.new(-84, 0, -22), Vector3.new(5, 6, 5), Colors.Cover, Colors.Cyan)
	b:Crate(Vector3.new(86, 0, -30), Vector3.new(5, 4, 5), Colors.Cover, Colors.Yellow)
	b:Vent(Vector3.new(-87, 0, -34), Colors.Pink)
	b:Pipe(Vector3.new(-94.6, 9, -62), Vector3.new(-94.6, 9, -18), 0.6, Colors.Machine, Colors.Pink)
	b:Pipe(Vector3.new(94.6, 8, -62), Vector3.new(94.6, 8, -18), 0.6, Colors.Machine, Colors.Cyan)

	-- Street cover.
	b:Crate(Vector3.new(-25, 0, -45), Vector3.new(6, 5, 6), Colors.Cover, Colors.Cyan)
	b:Crate(Vector3.new(24, 0, -62), Vector3.new(6, 5, 6), Colors.Cover, Colors.Pink)
	b:Block(Vector3.new(16, 4, 2), Vector3.new(0, 2, -62), Colors.Cover, Enum.Material.Metal, "Wall")
	b:Neon(Vector3.new(16.1, 0.25, 2.1), Vector3.new(0, 4, -62), Colors.Yellow)
	b:Block(Vector3.new(4, 6, 10), Vector3.new(-40, 3, -14), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(4, 4, 8), Vector3.new(40, 2, -22), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(10, 3, 2), Vector3.new(-14, 1.5, -80), Colors.Cover, Enum.Material.Metal, "Barricade")
	b:Block(Vector3.new(10, 3, 2), Vector3.new(16, 1.5, -86), Colors.Cover, Enum.Material.Metal, "Barricade")
	b:Neon(Vector3.new(10.1, 0.2, 2.1), Vector3.new(-14, 3, -80), Colors.Pink)
	b:Neon(Vector3.new(10.1, 0.2, 2.1), Vector3.new(16, 3, -86), Colors.Cyan)

	-- Food kiosk (cover) with a floating menu.
	b:Block(Vector3.new(6, 4, 4), Vector3.new(12, 2, -42), Colors.Shop, Enum.Material.SmoothPlastic, "Kiosk")
	b:Block(Vector3.new(7, 0.5, 5), Vector3.new(12, 6, -42), Colors.Machine, Enum.Material.Metal, "KioskRoof")
	b:Block(Vector3.new(0.4, 2, 0.4), Vector3.new(9, 5, -40), Colors.Machine, Enum.Material.Metal, "KioskPost")
	b:Block(Vector3.new(0.4, 2, 0.4), Vector3.new(15, 5, -40), Colors.Machine, Enum.Material.Metal, "KioskPost")
	b:Neon(Vector3.new(7.1, 0.2, 5.1), Vector3.new(12, 5.7, -42), Colors.Yellow)
	b:Hologram("PIXEL PIZZA", Vector3.new(7, 2, 0.2), Vector3.new(12, 8.5, -42), Colors.Yellow, Vector3.new(12, 8.5, 0))

	-- Plaza ramps (stage itself is built once, outside the mirrored pass).
	b:Ramp(Vector3.new(0, 0, -30), Vector3.new(0, 4, -15.5), 10, Colors.Plaza, Enum.Material.DiamondPlate)
	b:Ramp(Vector3.new(-30, 0, 0), Vector3.new(-15.5, 4, 0), 10, Colors.Plaza, Enum.Material.DiamondPlate)
	b:Block(Vector3.new(8, 3, 1.5), Vector3.new(-9, 5.5, -10), Colors.Cover, Enum.Material.Metal, "StageCover")
	b:Neon(Vector3.new(8.1, 0.2, 1.6), Vector3.new(-9, 7, -10), Colors.Cyan)
	b:Neon(Vector3.new(30.2, 0.3, 0.3), Vector3.new(0, 4.1, -15), Colors.Cyan)
	b:Tree(Vector3.new(-22, 0, -22), Colors.Green)
	b:Tree(Vector3.new(22, 0, -22), Colors.Pink)

	-- Street dressing: lane markings, lamps, drones, billboards, dust.
	for z = -125, -10, 12 do
		b:Deco(Vector3.new(0.6, 0.05, 5), Vector3.new(0, 0.23, z), Colors.Yellow).Transparency = 0.3
	end
	b:Deco(Vector3.new(0.3, 0.05, 105), Vector3.new(-29.5, 0.23, -82), Colors.Cyan).Transparency = 0.2
	b:Deco(Vector3.new(0.3, 0.05, 105), Vector3.new(29.5, 0.23, -82), Colors.Pink).Transparency = 0.2
	b:Lamp(Vector3.new(-31, 0, -20), 10, Colors.Cyan)
	b:Lamp(Vector3.new(31, 0, -75), 10, Colors.Pink)
	b:Lamp(Vector3.new(-31, 0, -88), 10, Colors.Yellow)
	b:Drone(Vector3.new(-20, 18, -40), Colors.Cyan)
	b:Drone(Vector3.new(34, 21, -12), Colors.Pink)
	b:Hologram("VECTOR RUSH", Vector3.new(18, 5, 0.3), Vector3.new(0, 24, -70), Colors.Purple, Vector3.new(0, 24, 0))
	local dust = b:Deco(Vector3.new(160, 24, 110), Vector3.new(0, 12, -70), Colors.Ground)
	dust.Transparency = 1
	b:Particles(dust, "Dust", Color3.fromRGB(200, 170, 255), 18)

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
		for index, y in { 8, 13, 17.8 } do
			local band = b:Neon(Vector3.new(6.4, 0.5, 6.4), Vector3.new(0, y, 0), ({ Colors.Cyan, Colors.Pink, Colors.Yellow })[index])
			b:Pulse(band, 0.5 + index * 0.2, 0, 0.5)
		end
		local core = b:DecoCFrame(Vector3.one * 3, CFrame.new(0, 22, 0), Colors.Cyan, Enum.Material.Neon, Enum.PartType.Ball)
		b:Bob(core, 0.8, 0.3)
		b:Particles(core, "Sparkle", Colors.Cyan, 10)
		b:HaloRing(Vector3.new(0, 22, 0), 9, Colors.Pink, 50, 25)
		b:HaloRing(Vector3.new(0, 22, 0), 13, Colors.Cyan, -35, -15)
		b:Light(Vector3.new(0, 20, 0), Colors.Cyan, 40, 2)
	end,
}
