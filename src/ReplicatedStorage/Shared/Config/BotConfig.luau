--[[
	BotConfig
	Practice bot tuning. Bots perceive the world with vision cones, line of
	sight and hearing - they never read positions they could not see/hear.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local BotConfig = {
	Difficulties = {
		Easy = {
			ReactionTime = 0.75,
			AimErrorDegrees = 7,
			FireRateMultiplier = 0.55,
			ViewDistance = 110,
			FieldOfView = 100,
			HearingRadius = 45,
			StrafeChance = 0.2,
			RetreatHealth = 0.25,
			Weapons = { "PulseRifle", "RapidBlaster" },
		},
		Normal = {
			ReactionTime = 0.45,
			AimErrorDegrees = 4,
			FireRateMultiplier = 0.8,
			ViewDistance = 160,
			FieldOfView = 120,
			HearingRadius = 70,
			StrafeChance = 0.5,
			RetreatHealth = 0.3,
			Weapons = { "PulseRifle", "RapidBlaster", "BurstBlaster", "ScatterBlaster" },
		},
		Hard = {
			ReactionTime = 0.25,
			AimErrorDegrees = 2.2,
			FireRateMultiplier = 1,
			ViewDistance = 220,
			FieldOfView = 140,
			HearingRadius = 95,
			StrafeChance = 0.8,
			RetreatHealth = 0.35,
			Weapons = { "PulseRifle", "BurstBlaster", "ScatterBlaster", "PrecisionBlaster" },
		},
	},
	DifficultyOrder = { "Easy", "Normal", "Hard" },
	ThinkRate = 8, -- AI updates per second
	MemoryDuration = 4, -- seconds a bot remembers a target it lost sight of
	RepathInterval = 1.2,
	Names = {
		"Pixel", "Bolt", "Echo", "Nova", "Glitch", "Zippy", "Comet", "Byte",
		"Sprocket", "Flare", "Rocket", "Widget", "Neon", "Turbo", "Blip", "Volt",
	},
	MaxBots = 11,
}

return TableUtil.DeepFreeze(BotConfig)
