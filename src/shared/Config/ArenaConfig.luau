--!nonstrict
--[[
	ArenaConfig.luau
	Layout parameters for the procedurally-built arenas.

	Arena design rules for HYPER BLAST (these drove every number below):
		* Every long sightline must have a covered flank route that beats it.
		* Every raised position must have at least TWO ways up, one of which is
		  movement-only (wall jump / jump pad) so mobility is a real map advantage.
		* Nothing is more than ~2.5 seconds of movement from cover.
		* Wall-jump panels are visually distinct (cyan trim) so routes are readable
		  at a glance rather than memorised.
		* Vertical space is capped so an enemy is never off-screen above you.
--]]

local ArenaConfig = {}

ArenaConfig.Arenas = {
	--------------------------------------------------------------------
	NeonSpire = {
		Id = "NeonSpire",
		DisplayName = "NEON SPIRE",
		-- Overall footprint. Square keeps the two team sides mirror-fair.
		Size = Vector3.new(360, 150, 360),
		FloorY = 0,
		WallHeight = 90,

		-- Central raised platform ("the spire") - the contested high ground.
		Spire = {
			Position = Vector3.new(0, 0, 0),
			BaseSize = Vector3.new(74, 20, 74),
			TopSize = Vector3.new(46, 6, 46),
			TopY = 30,
			RampCount = 4, -- readable ways up
			WallJumpFaces = 4, -- movement-only ways up
		},

		-- Four corner towers: rooftops with sightlines onto the spire.
		Towers = {
			{ offset = Vector2.new(118, 118), height = 40, size = Vector3.new(40, 40, 40) },
			{ offset = Vector2.new(-118, 118), height = 40, size = Vector3.new(40, 40, 40) },
			{ offset = Vector2.new(118, -118), height = 40, size = Vector3.new(40, 40, 40) },
			{ offset = Vector2.new(-118, -118), height = 40, size = Vector3.new(40, 40, 40) },
		},

		-- Slide tunnels: low ceilings, only passable at slide height. These are the
		-- fast lanes; you trade your ability to shoot for ~1.4s of map traversal.
		SlideTunnels = {
			{ from = Vector3.new(-150, 0, -40), to = Vector3.new(-40, 0, -40), width = 12, ceiling = 4.4 },
			{ from = Vector3.new(150, 0, 40), to = Vector3.new(40, 0, 40), width = 12, ceiling = 4.4 },
			{ from = Vector3.new(-40, 0, 150), to = Vector3.new(-40, 0, 44), width = 12, ceiling = 4.4 },
			{ from = Vector3.new(40, 0, -150), to = Vector3.new(40, 0, -44), width = 12, ceiling = 4.4 },
		},

		-- Jump pads: the movement-only routes onto the towers and the spire.
		JumpPads = {
			{ position = Vector3.new(72, 1, 0), power = 86, forwardKeep = 0.9 },
			{ position = Vector3.new(-72, 1, 0), power = 86, forwardKeep = 0.9 },
			{ position = Vector3.new(0, 1, 72), power = 86, forwardKeep = 0.9 },
			{ position = Vector3.new(0, 1, -72), power = 86, forwardKeep = 0.9 },
			{ position = Vector3.new(140, 1, 140), power = 96, forwardKeep = 0.75 },
			{ position = Vector3.new(-140, 1, -140), power = 96, forwardKeep = 0.75 },
		},

		-- Wall-jump route markers: tall panels players chain between.
		WallRoutes = {
			{ position = Vector3.new(96, 22, 46), size = Vector3.new(3, 44, 26), rotation = 0 },
			{ position = Vector3.new(-96, 22, -46), size = Vector3.new(3, 44, 26), rotation = 0 },
			{ position = Vector3.new(46, 22, -96), size = Vector3.new(26, 44, 3), rotation = 0 },
			{ position = Vector3.new(-46, 22, 96), size = Vector3.new(26, 44, 3), rotation = 0 },
		},

		-- Mid-height platforms, staggered so they chain with a dash.
		Platforms = {
			{ position = Vector3.new(60, 14, 60), size = Vector3.new(26, 2, 26) },
			{ position = Vector3.new(-60, 14, 60), size = Vector3.new(26, 2, 26) },
			{ position = Vector3.new(60, 14, -60), size = Vector3.new(26, 2, 26) },
			{ position = Vector3.new(-60, 14, -60), size = Vector3.new(26, 2, 26) },
			{ position = Vector3.new(0, 22, 96), size = Vector3.new(34, 2, 18) },
			{ position = Vector3.new(0, 22, -96), size = Vector3.new(34, 2, 18) },
			{ position = Vector3.new(96, 22, 0), size = Vector3.new(18, 2, 34) },
			{ position = Vector3.new(-96, 22, 0), size = Vector3.new(18, 2, 34) },
		},

		-- Cover: chest-high (mantleable) and full-height blocks scattered across
		-- the open floor so the open sightlines are crossable under fire.
		CoverGrid = {
			Rows = 5,
			Spacing = 52,
			Jitter = 11,
			LowSize = Vector3.new(10, 4, 10), -- mantleable
			HighSize = Vector3.new(8, 12, 8),
			LowChance = 0.62,
			ExclusionRadius = 46, -- keeps cover off the spire ramps
		},

		-- Team spawns, mirrored on the Z axis.
		Spawns = {
			Cyan = { center = Vector3.new(0, 2, -152), spread = 44, facing = Vector3.new(0, 0, 1) },
			Magenta = { center = Vector3.new(0, 2, 152), spread = 44, facing = Vector3.new(0, 0, -1) },
		},

		-- Neon Control zones. A/B/C: B is the spire (high risk, high reward).
		ControlZones = {
			{ id = "A", position = Vector3.new(-118, 1, 0), radius = 22 },
			{ id = "B", position = Vector3.new(0, 37, 0), radius = 24 },
			{ id = "C", position = Vector3.new(118, 1, 0), radius = 22 },
		},

		-- Core Rush.
		CoreSpawn = Vector3.new(0, 38, 0),
		CoreObjectives = {
			Cyan = Vector3.new(0, 3, -136),
			Magenta = Vector3.new(0, 3, 136),
		},

		Lighting = {
			FogEnd = 480,
			FogStart = 90,
			BloomIntensity = 1.1,
			BloomThreshold = 1.35,
			ColorCorrectionSaturation = 0.16,
			SunRaysIntensity = 0.02,
		},
	},

	--------------------------------------------------------------------
	DuelCage = {
		Id = "DuelCage",
		DisplayName = "DUEL CAGE",
		Size = Vector3.new(140, 80, 140),
		FloorY = 0,
		WallHeight = 52,

		Spire = {
			Position = Vector3.new(0, 0, 0),
			BaseSize = Vector3.new(34, 10, 34),
			TopSize = Vector3.new(24, 4, 24),
			TopY = 14,
			RampCount = 2,
			WallJumpFaces = 4,
		},

		Towers = {},

		SlideTunnels = {
			{ from = Vector3.new(-58, 0, -22), to = Vector3.new(-18, 0, -22), width = 10, ceiling = 4.4 },
			{ from = Vector3.new(58, 0, 22), to = Vector3.new(18, 0, 22), width = 10, ceiling = 4.4 },
		},

		JumpPads = {
			{ position = Vector3.new(44, 1, 0), power = 74, forwardKeep = 0.9 },
			{ position = Vector3.new(-44, 1, 0), power = 74, forwardKeep = 0.9 },
		},

		WallRoutes = {
			{ position = Vector3.new(52, 14, 30), size = Vector3.new(3, 28, 20), rotation = 0 },
			{ position = Vector3.new(-52, 14, -30), size = Vector3.new(3, 28, 20), rotation = 0 },
		},

		Platforms = {
			{ position = Vector3.new(40, 10, 40), size = Vector3.new(18, 2, 18) },
			{ position = Vector3.new(-40, 10, -40), size = Vector3.new(18, 2, 18) },
			{ position = Vector3.new(-40, 10, 40), size = Vector3.new(18, 2, 18) },
			{ position = Vector3.new(40, 10, -40), size = Vector3.new(18, 2, 18) },
		},

		CoverGrid = {
			Rows = 3,
			Spacing = 38,
			Jitter = 7,
			LowSize = Vector3.new(8, 4, 8),
			HighSize = Vector3.new(6, 10, 6),
			LowChance = 0.7,
			ExclusionRadius = 24,
		},

		Spawns = {
			Cyan = { center = Vector3.new(0, 2, -58), spread = 6, facing = Vector3.new(0, 0, 1) },
			Magenta = { center = Vector3.new(0, 2, 58), spread = 6, facing = Vector3.new(0, 0, -1) },
		},

		ControlZones = {},
		CoreSpawn = Vector3.new(0, 16, 0),
		CoreObjectives = {
			Cyan = Vector3.new(0, 3, -52),
			Magenta = Vector3.new(0, 3, 52),
		},

		Lighting = {
			FogEnd = 260,
			FogStart = 50,
			BloomIntensity = 1.2,
			BloomThreshold = 1.3,
			ColorCorrectionSaturation = 0.18,
			SunRaysIntensity = 0.02,
		},
	},
}

ArenaConfig.Default = "NeonSpire"

function ArenaConfig.get(id: string)
	return ArenaConfig.Arenas[id] or ArenaConfig.Arenas[ArenaConfig.Default]
end

return ArenaConfig
