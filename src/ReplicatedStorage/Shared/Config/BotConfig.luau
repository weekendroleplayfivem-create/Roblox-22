--[[
	BotConfig
	Practice bot tuning. Bots perceive the world with vision cones, line of
	sight and hearing - they never read positions they could not see/hear.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local BotConfig = {
	--[[
		Bots aim like people, not aimbots:
		  TurnSpeed       max degrees/second their aim can rotate (no snapping)
		  TrackingLag     they aim where you were this many seconds ago
		  AcquireError    degrees off-target when they first spot you...
		  SettleTime      ...shrinking over this many seconds
		  AimShake        constant hand wobble (degrees), worse while moving
		  FireCone        only shoot when their aim is within this angle
		  Burst/BurstPause shoot in bursts with pauses between them
		  HeadAimChance   chance a burst aims at the head instead of the body
		  LeadFactor      how much they lead projectile shots (0..1)
	]]
	Difficulties = {
		Easy = {
			ReactionTime = 0.8,
			TurnSpeed = 110,
			TrackingLag = 0.35,
			AcquireError = 20,
			SettleTime = 1.1,
			AimShake = 4,
			FireCone = 8,
			Burst = { 2, 4 },
			BurstPause = { 0.7, 1.3 },
			HeadAimChance = 0,
			LeadFactor = 0,
			FireRateMultiplier = 0.55,
			ViewDistance = 110,
			FieldOfView = 100,
			HearingRadius = 45,
			StrafeChance = 0.2,
			RetreatHealth = 0.25,
			Weapons = { "PulseRifle", "RapidBlaster" },
		},
		Normal = {
			ReactionTime = 0.5,
			TurnSpeed = 170,
			TrackingLag = 0.24,
			AcquireError = 14,
			SettleTime = 0.75,
			AimShake = 2.6,
			FireCone = 6,
			Burst = { 3, 6 },
			BurstPause = { 0.45, 0.9 },
			HeadAimChance = 0.05,
			LeadFactor = 0.3,
			FireRateMultiplier = 0.75,
			ViewDistance = 160,
			FieldOfView = 120,
			HearingRadius = 70,
			StrafeChance = 0.5,
			RetreatHealth = 0.3,
			Weapons = { "PulseRifle", "RapidBlaster", "BurstBlaster", "ScatterBlaster" },
		},
		Hard = {
			ReactionTime = 0.32,
			TurnSpeed = 250,
			TrackingLag = 0.15,
			AcquireError = 10,
			SettleTime = 0.5,
			AimShake = 1.6,
			FireCone = 4.5,
			Burst = { 4, 8 },
			BurstPause = { 0.3, 0.6 },
			HeadAimChance = 0.12,
			LeadFactor = 0.6,
			FireRateMultiplier = 0.9,
			ViewDistance = 220,
			FieldOfView = 140,
			HearingRadius = 95,
			StrafeChance = 0.8,
			RetreatHealth = 0.35,
			Weapons = { "PulseRifle", "BurstBlaster", "ScatterBlaster", "MarksmanRifle" },
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
