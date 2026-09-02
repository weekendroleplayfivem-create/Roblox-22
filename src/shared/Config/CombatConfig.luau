--!nonstrict
--[[
	CombatConfig.luau
	Health, hit registration and the rules that decide whether a shot counts.
--]]

local CombatConfig = {}

CombatConfig.Health = {
	Max = 100,
	RegenDelay = 6.0, -- long: winning a fight should leave you vulnerable
	RegenRate = 12, -- hp/sec once it starts
	RegenTickInterval = 0.1,
	LowHealthThreshold = 35, -- HUD warning trips here
	CriticalHealthThreshold = 18,
	SpawnProtection = 1.25, -- seconds of immunity, cancelled the instant you shoot
}

CombatConfig.HitRegistration = {
	-- The client raycasts and reports; the server re-validates. This is the standard
	-- responsive-shooter tradeoff: we accept a bounded trust window in exchange for
	-- shots that land the frame you click them.
	MaxShotDistance = 1500,
	MuzzleOriginTolerance = 12, -- studs between reported origin and the real head
	MaxRewindTime = 0.25, -- lag compensation window
	PositionTolerance = 9, -- studs of slack on a rewound target position
	MaxShotsPerSecondFactor = 1.15, -- fire-rate audit multiplier before we drop shots
	MaxPendingShots = 24,
	WallbangThickness = 1.6, -- studs of geometry a piercing weapon can punch
	WallbangDamageScale = 0.55,
}

CombatConfig.Hitboxes = {
	-- Multipliers are applied on top of the weapon's own head/leg multipliers.
	Head = { parts = { "Head" }, tag = "Head" },
	Limb = {
		parts = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
		tag = "Leg",
	},
	-- Everything else falls through to Torso (1.0x).
}

CombatConfig.Feedback = {
	HitmarkerTime = 0.16,
	HeadshotHitmarkerTime = 0.22,
	KillMarkerTime = 0.35,
	DamageNumberLife = 0.9,
	DamageNumberRise = 3.2,
	DamageIndicatorLife = 1.6, -- directional "you got shot from there" arc
	KillFeedLife = 5.0,
	KillFeedMax = 5,
}

CombatConfig.Elimination = {
	RagdollTime = 0.0, -- we dissolve instead of ragdolling: cleaner reads, cheaper
	DissolveTime = 0.85,
	RespawnDelay = 3.0,
	KillCamTime = 0.0, -- off by default; short matches shouldn't take control away
}

CombatConfig.Score = {
	Kill = 100,
	Assist = 40,
	Headshot = 25,
	ZoneCapture = 150,
	ZoneTick = 10,
	CoreCarry = 50,
	CoreDeliver = 300,
	AssistDamageThreshold = 25,
	AssistWindow = 8.0,
}

return CombatConfig
