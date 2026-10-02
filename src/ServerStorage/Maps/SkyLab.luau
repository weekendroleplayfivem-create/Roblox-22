--[[
	SKY LAB (placeholder geometry)
	Floating research platforms over an open sky. Falling off eliminates you
	("out of bounds"), so routes reward careful movement.
	  * Central hub with lab dome cover
	  * Two bridges per side + jump gaps on the flank platforms
	  * Lower level under the hub with jump pads back up
	  * High observation pods reached by jump pads
	  * Railings along bridges and base edges (you can still jump over them)
	Dressing: sea of clouds below, glass lab dome with halo rings, satellite
	dishes, glowing conduits, floating cubes, wind streaks, consoles.
	Side A spawns at -Z, side B at +Z.
]]

local Colors = {
	Deck = Color3.fromRGB(215, 225, 240),
	DeckAlt = Color3.fromRGB(180, 195, 220),
	Lab = Color3.fromRGB(235, 240, 250),
	Glass = Color3.fromRGB(150, 220, 255),
	Cover = Color3.fromRGB(120, 140, 170),
	Lower = Color3.fromRGB(90, 105, 135),
	Cyan = Color3.fromRGB(40, 200, 255),
	Orange = Color3.fromRGB(255, 150, 40),
	Green = Color3.fromRGB(80, 255, 160),
	Cloud = Color3.fromRGB(245, 250, 255),
	Metal = Color3.fromRGB(150, 160, 180),
}

local DECK = 20 -- main level surface height
local LOWER = 6 -- lower level surface height
local HIGH = 36 -- observation pods

-- Detail for one half (called at the end of `half`, so it is mirrored too).
local function dress(b)
	-- Railings: bridges and base edges (gaps left where the jump routes are).
	for _, x in { -25, 25 } do
		b:Railing(Vector3.new(x - 3.7, DECK, -84), Vector3.new(x - 3.7, DECK, -21), Colors.Cyan)
		b:Railing(Vector3.new(x + 3.7, DECK, -84), Vector3.new(x + 3.7, DECK, -21), Colors.Cyan)
		b:Pipe(Vector3.new(x, DECK - 1.6, -85), Vector3.new(x, DECK - 1.6, -20), 0.7, Colors.Metal, Colors.Orange)
	end
	b:Railing(Vector3.new(-27.7, DECK, -114), Vector3.new(-27.7, DECK, -92), Colors.Cyan)
	b:Railing(Vector3.new(27.7, DECK, -114), Vector3.new(27.7, DECK, -86), Colors.Cyan)

	-- Base: satellite dish, consoles, beacons, glowing spawn pad.
	b:Block(Vector3.new(0.8, 6, 0.8), Vector3.new(18, DECK + 3, -111), Colors.Metal, Enum.Material.Metal, "DishPole")
	local dish = b:DecoCFrame(Vector3.new(0.4, 7, 7), CFrame.new(18, DECK + 7, -111) * CFrame.Angles(0, 0, math.rad(55)), Colors.Lab, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	b:Spin(dish, Vector3.yAxis, 12)
	local emitter = b:DecoCFrame(Vector3.one * 0.7, CFrame.new(18, DECK + 8.5, -111), Colors.Orange, Enum.Material.Neon, Enum.PartType.Ball)
	b:Pulse(emitter, 1.2, 0, 0.7)
	b:Console("ALT 2,400m\nWIND 34kn\nSTATUS: OK", Vector3.new(-12, DECK + 1.5, -114.4), Vector3.new(-12, DECK + 1.5, 0), Colors.Cyan)
	for _, x in { -27, 27 } do
		local beacon = b:Deco(Vector3.new(1, 1, 1), Vector3.new(x, DECK + 0.5, -86), Colors.Orange)
		b:Pulse(beacon, 1, 0, 0.8)
	end
	local pad = b:Deco(Vector3.new(50, 0.05, 12), Vector3.new(0, DECK + 0.03, -106), Colors.Cyan)
	pad.Transparency = 0.85
	b:Hologram("SKY LAB", Vector3.new(14, 4, 0.3), Vector3.new(0, DECK + 14, -116), Colors.Cyan, Vector3.new(0, DECK + 14, 0))

	-- Lower level: vents, pipes, floor glow.
	b:Vent(Vector3.new(-22, LOWER, -18), Colors.Green)
	b:Pipe(Vector3.new(-34, LOWER + 10, -45), Vector3.new(34, LOWER + 10, -45), 0.8, Colors.Metal, Colors.Green)
	local glow = b:Deco(Vector3.new(60, 0.05, 0.4), Vector3.new(0, LOWER + 0.03, -12), Colors.Green)
	b:Pulse(glow, 0.5, 0, 0.6)

	-- Pod: little research screen.
	b:Console("SCAN...", Vector3.new(50, HIGH + 1.5, 1), Vector3.new(50, HIGH + 1.5, -20), Colors.Orange)

	-- Floating cubes + wind streaks.
	for _, data in { { Vector3.new(55, 30, -24), Colors.Cyan }, { Vector3.new(-32, 42, -44), Colors.Orange }, { Vector3.new(62, 14, -74), Colors.Green } } do
		local cube = b:DecoCFrame(Vector3.one * 2.5, CFrame.new(data[1]) * CFrame.Angles(0.6, 0.6, 0), data[2], Enum.Material.Neon)
		cube.Transparency = 0.2
		b:Bob(cube, 2, 0.15)
		b:Spin(cube, Vector3.new(0.3, 1, 0.2), 30)
	end
	local wind = b:Deco(Vector3.new(2, 40, 220), Vector3.new(-95, 22, 0), Colors.Cloud)
	wind.Transparency = 1
	b:Particles(wind, "Wind", Colors.Cloud, 14)
end

local function half(b)
	-- Base platform + spawns.
	b:Block(Vector3.new(56, 2, 30), Vector3.new(0, DECK - 1, -100), Colors.Deck, Enum.Material.SmoothPlastic, "Base")
	b:Block(Vector3.new(56, 10, 2), Vector3.new(0, DECK + 5, -116), Colors.Lab, Enum.Material.SmoothPlastic, "BaseWall")
	b:Block(Vector3.new(14, 6, 2), Vector3.new(0, DECK + 3, -86), Colors.Cover, Enum.Material.Metal, "SpawnCover")
	b:Neon(Vector3.new(56, 0.4, 0.4), Vector3.new(0, DECK, -85), Colors.Cyan)
	for index = 0, 5 do
		b:Spawn(Vector3.new(-22.5 + index * 9, DECK, -106), "A")
	end

	-- Bridges to the hub (x = +-25) with mid cover.
	for _, x in { -25, 25 } do
		b:Block(Vector3.new(8, 1, 66), Vector3.new(x, DECK - 0.5, -52), Colors.DeckAlt, Enum.Material.DiamondPlate, "Bridge")
		b:Block(Vector3.new(6, 3.5, 1.2), Vector3.new(x, DECK + 1.75, -55), Colors.Cover, Enum.Material.Metal, "Cover")
		b:Neon(Vector3.new(0.3, 0.3, 66), Vector3.new(x - 4, DECK, -52), Colors.Orange)
		b:Neon(Vector3.new(0.3, 0.3, 66), Vector3.new(x + 4, DECK, -52), Colors.Orange)
	end

	-- West flank platform: jump gap from the base, walkway to the hub side.
	b:Block(Vector3.new(24, 2, 24), Vector3.new(-56, DECK - 1, -60), Colors.Deck, Enum.Material.SmoothPlastic, "Flank")
	b:Block(Vector3.new(6, 6, 6), Vector3.new(-56, DECK + 3, -60), Colors.Lab, Enum.Material.SmoothPlastic, "Crate")
	b:Block(Vector3.new(10, 2, 10), Vector3.new(-38, DECK - 1, -84), Colors.DeckAlt, Enum.Material.SmoothPlastic, "Step")
	b:Block(Vector3.new(10, 2, 26), Vector3.new(-56, DECK - 1, -30), Colors.DeckAlt, Enum.Material.SmoothPlastic, "FlankWalk")
	b:Block(Vector3.new(24, 2, 10), Vector3.new(-36, DECK - 1, -10), Colors.Deck, Enum.Material.SmoothPlastic, "FlankLink")
	b:Neon(Vector3.new(24.2, 0.3, 0.3), Vector3.new(-56, DECK, -72), Colors.Green)

	-- Ramp from the base down to the lower level.
	b:Ramp(Vector3.new(12, DECK, -86), Vector3.new(12, LOWER, -58), 8, Colors.Lower, Enum.Material.DiamondPlate)
	b:Block(Vector3.new(12, 2, 10), Vector3.new(12, LOWER - 1, -53), Colors.Lower, Enum.Material.SmoothPlastic, "LowerLanding")

	-- Lower level half (under the hub) with cover and launch pads.
	b:Block(Vector3.new(70, 2, 49), Vector3.new(0, LOWER - 1, -24.5), Colors.Lower, Enum.Material.SmoothPlastic, "Lower")
	b:Block(Vector3.new(5, 5, 5), Vector3.new(-14, LOWER + 2.5, -34), Colors.Cover, Enum.Material.Metal, "Crate")
	b:Block(Vector3.new(10, 4, 1.5), Vector3.new(16, LOWER + 2, -40), Colors.Cover, Enum.Material.Metal, "Wall")
	-- Placed at +z so it is not underneath this side's flank link.
	b:JumpPad(Vector3.new(-29, LOWER, 6), Vector3.new(24, 92, 0), Colors.Green)
	b:Light(Vector3.new(0, LOWER + 6, -30), Colors.Cyan, 30, 1.5)

	-- High observation pod (east), reached from a hub-corner pad.
	b:Block(Vector3.new(16, 1, 16), Vector3.new(44, HIGH - 0.5, -6), Colors.Deck, Enum.Material.SmoothPlastic, "Pod")
	b:Block(Vector3.new(16, 3, 1), Vector3.new(44, HIGH + 1.5, -14), Colors.Glass, Enum.Material.Glass, "PodGlass")
	b:Block(Vector3.new(1, 3, 8), Vector3.new(36.5, HIGH + 1.5, -2), Colors.Glass, Enum.Material.Glass, "PodGlass")
	b:JumpPad(Vector3.new(16, DECK, -16), Vector3.new(24, 112, 8), Colors.Orange)
	b:Light(Vector3.new(44, HIGH + 4, -6), Colors.Orange, 20, 1.5)

	-- Hub corner cover.
	b:Block(Vector3.new(3, 6, 3), Vector3.new(-12, DECK + 3, -12), Colors.Lab, Enum.Material.SmoothPlastic, "Pillar")
	b:Block(Vector3.new(8, 3, 1.2), Vector3.new(6, DECK + 1.5, -15), Colors.Cover, Enum.Material.Metal, "Cover")

	-- Neutral spawns and bot nodes.
	b:Spawn(Vector3.new(-56, DECK, -66), nil)
	b:Spawn(Vector3.new(0, LOWER, -42), nil)
	b:Spawn(Vector3.new(44, HIGH, -8), nil)
	for _, node in
		{
			Vector3.new(-25, DECK, -52),
			Vector3.new(25, DECK, -52),
			Vector3.new(-56, DECK, -45),
			Vector3.new(-38, DECK, -10),
			Vector3.new(10, DECK, -10),
			Vector3.new(0, LOWER, -30),
			Vector3.new(-20, LOWER, -40),
			Vector3.new(20, LOWER, -30),
			Vector3.new(0, DECK, -92),
		}
	do
		b:BotNode(node)
	end
	dress(b)
end

return {
	KillY = -40,
	Build = function(b)
		b:Mirrored(half)
		-- Hub (on the symmetry point).
		b:Block(Vector3.new(40, 2, 40), Vector3.new(0, DECK - 1, 0), Colors.Deck, Enum.Material.SmoothPlastic, "Hub")
		b:Block(Vector3.new(12, 8, 12), Vector3.new(0, DECK + 4, 0), Colors.Lab, Enum.Material.SmoothPlastic, "Lab")
		b:Block(Vector3.new(12.4, 2, 12.4), Vector3.new(0, DECK + 5, 0), Colors.Glass, Enum.Material.Glass, "LabWindow")
		b:Neon(Vector3.new(40.2, 0.4, 0.4), Vector3.new(0, DECK, -20), Colors.Cyan)
		b:Neon(Vector3.new(40.2, 0.4, 0.4), Vector3.new(0, DECK, 20), Colors.Cyan)
		b:Light(Vector3.new(0, DECK + 12, 0), Colors.Cyan, 40, 2)
		-- Thin "antenna" for visual identity, with halo rings.
		b:Neon(Vector3.new(0.6, 30, 0.6), Vector3.new(0, DECK + 23, 0), Colors.Orange)
		b:HaloRing(Vector3.new(0, DECK + 28, 0), 8, Colors.Cyan, 45, 20)
		b:HaloRing(Vector3.new(0, DECK + 34, 0), 5, Colors.Orange, -70, -25)
		local tip = b:DecoCFrame(Vector3.one * 1.4, CFrame.new(0, DECK + 38.5, 0), Colors.Orange, Enum.Material.Neon, Enum.PartType.Ball)
		b:Pulse(tip, 1, 0, 0.7)
		-- Glass dome cap on the lab.
		local dome = b:DecoCFrame(Vector3.one * 12, CFrame.new(0, DECK + 8, 0), Colors.Glass, Enum.Material.Glass, Enum.PartType.Ball)
		dome.Transparency = 0.55
		b:Particles(dome, "Sparkle", Colors.Cyan, 6)
		local floorRing = b:DecoCFrame(Vector3.new(0.05, 36, 36), CFrame.new(0, DECK + 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), Colors.Cyan, Enum.Material.Neon, Enum.PartType.Cylinder)
		floorRing.Transparency = 0.85

		-- Sea of clouds far below the platforms.
		for index = 0, 9 do
			local angle = index / 10 * math.pi * 2
			local distance = 30 + (index % 3) * 35
			local size = 26 + (index % 4) * 8
			local puff = b:DecoCFrame(Vector3.one * size, CFrame.new(math.cos(angle) * distance, -22 - (index % 3) * 6, math.sin(angle) * distance * 1.4), Colors.Cloud, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			puff.Transparency = 0.35
			b:Bob(puff, 2, 0.05)
		end
		for _, position in { Vector3.new(0, -18, 0), Vector3.new(70, -20, 80), Vector3.new(-70, -20, -80) } do
			local cloudSource = b:Deco(Vector3.new(120, 4, 120), position, Colors.Cloud)
			cloudSource.Transparency = 1
			b:Particles(cloudSource, "Cloud", Colors.Cloud, 3)
		end
	end,
}
