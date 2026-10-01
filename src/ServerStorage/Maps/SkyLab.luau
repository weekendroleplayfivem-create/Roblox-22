--[[
	SKY LAB (placeholder geometry)
	Floating research platforms over an open sky. Falling off eliminates you
	("out of bounds"), so routes reward careful movement.
	  * Central hub with lab dome cover
	  * Two bridges per side + jump gaps on the flank platforms
	  * Lower level under the hub with jump pads back up
	  * High observation pods reached by jump pads
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
}

local DECK = 20 -- main level surface height
local LOWER = 6 -- lower level surface height
local HIGH = 36 -- observation pods

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
		-- Thin "antenna" for visual identity.
		b:Neon(Vector3.new(0.6, 30, 0.6), Vector3.new(0, DECK + 23, 0), Colors.Orange)
	end,
}
