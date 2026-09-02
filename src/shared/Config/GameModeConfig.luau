--!nonstrict
--[[
	GameModeConfig.luau
	Match flow parameters. Short matches are a design pillar: a HYPER BLAST round
	should fit inside the time it takes to decide whether you want another one.
--]]

local GameModeConfig = {}

GameModeConfig.Match = {
	IntroTime = 6, -- map fly-in + loadout
	WarmupTime = 4, -- frozen at spawn, weapons out, movement disabled
	PostMatchTime = 10,
	MinPlayersToStart = 1, -- 1 so a solo dev/playtester is never stuck in a lobby
	AutoBalanceTeams = true,
	OvertimeEnabled = true,
	OvertimeDuration = 90,
}

GameModeConfig.Modes = {
	--------------------------------------------------------------------
	HyperTeamDeathmatch = {
		Id = "HyperTeamDeathmatch",
		DisplayName = "HYPER TEAM DEATHMATCH",
		ShortName = "TDM",
		Teams = 2,
		ScoreLimit = 50,
		TimeLimit = 480,
		RespawnDelay = 3.0,
		SpawnMode = "TeamZoneFurthestFromEnemy",
		Description = "Two teams. First to the score limit wins.",
		Arena = "NeonSpire",
		LoadoutMode = "Full",
	},

	--------------------------------------------------------------------
	NeonControl = {
		Id = "NeonControl",
		DisplayName = "NEON CONTROL",
		ShortName = "CTRL",
		Teams = 2,
		ScoreLimit = 500,
		TimeLimit = 600,
		RespawnDelay = 4.0,
		SpawnMode = "TeamZoneNearestOwnedZone",
		Description = "Capture and hold the control zones. Points tick while you hold.",
		Arena = "NeonSpire",
		LoadoutMode = "Full",

		Zones = 3,
		CaptureTimePerPlayer = 6.0, -- solo capture time; more bodies capture faster
		CaptureSpeedPerExtraPlayer = 0.45, -- diminishing, so 5-stacking a point isn't free
		MaxCaptureSpeed = 2.4,
		ContestStopsProgress = true,
		DecayRate = 0.5, -- uncontested progress bleeds back this fast
		TickInterval = 1.0,
		PointsPerZonePerTick = 2,
		AllZonesBonusMultiplier = 1.75,
		RotateZonesAfter = 120, -- seconds before the active zone set rotates
	},

	--------------------------------------------------------------------
	CoreRush = {
		Id = "CoreRush",
		DisplayName = "CORE RUSH",
		ShortName = "RUSH",
		Teams = 2,
		ScoreLimit = 5,
		TimeLimit = 600,
		RespawnDelay = 5.0, -- long: dying while carrying the core has to hurt
		SpawnMode = "TeamZone",
		Description = "One core, two objectives. Carry it home.",
		Arena = "NeonSpire",
		LoadoutMode = "Full",

		CoreRespawnTime = 8,
		CoreDropTime = 15, -- dropped core returns to centre after this
		CarrierSpeedMultiplier = 0.9, -- slower, but not crippled: the carrier still moves
		CarrierAbilitiesEnabled = { HyperDash = true, PhaseStep = false, Overdrive = true },
		CarrierHighlight = true,
		CarrierCanFire = true,
		CarrierWeaponIds = { "SPARK", "RIFT" }, -- carrying the core means sidearm only
		DeliverRadius = 9,
	},

	--------------------------------------------------------------------
	HyperDuel = {
		Id = "HyperDuel",
		DisplayName = "1V1 HYPER DUEL",
		ShortName = "DUEL",
		Teams = 2,
		ScoreLimit = 7, -- first to 7 rounds
		TimeLimit = 420,
		RespawnDelay = 0, -- round-based, not respawn-based
		SpawnMode = "DuelOpposite",
		Description = "Small arena. Limited kit. Pure movement and aim.",
		Arena = "DuelCage",
		LoadoutMode = "Duel",

		RoundBased = true,
		RoundTime = 60,
		RoundIntermission = 3.5,
		FullHealOnRoundStart = true,
		AbilitiesEnabled = { HyperDash = true, PhaseStep = true, Overdrive = false },
	},
}

GameModeConfig.Rotation = {
	"HyperTeamDeathmatch",
	"NeonControl",
	"CoreRush",
	"HyperTeamDeathmatch",
	"HyperDuel",
}

GameModeConfig.Default = "HyperTeamDeathmatch"

function GameModeConfig.get(id: string)
	return GameModeConfig.Modes[id]
end

return GameModeConfig
