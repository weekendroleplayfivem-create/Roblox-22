--[[
	MatchConfig
	Game modes, queue rules, teams and scoring. New modes are added by
	adding an entry to Modes and (if needed) a rule handler in
	ServerScriptService/Services/MatchService/Modes.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local MatchConfig = {
	Modes = {
		TeamDeathmatch = {
			DisplayName = "Team Deathmatch",
			ShortName = "TDM",
			Description = "Two teams. First to 50 eliminations wins.",
			TeamBased = true,
			MaxPlayers = 12,
			TimeLimit = 600,
			ScoreLimit = 50,
			BotFillTarget = 8,
		},
		FreeForAll = {
			DisplayName = "Free For All",
			ShortName = "FFA",
			Description = "Everyone for themselves. First to 30 eliminations wins.",
			TeamBased = false,
			MaxPlayers = 12,
			TimeLimit = 480,
			ScoreLimit = 30,
			BotFillTarget = 8,
		},
		GunGame = {
			DisplayName = "Gun Game",
			ShortName = "GG",
			Description = "Every elimination upgrades your blaster. One kill with the last one wins.",
			TeamBased = false,
			MaxPlayers = 12,
			TimeLimit = 480,
			-- Score limit is the ladder length (one elimination per tier).
			ScoreLimit = 0,
			BotFillTarget = 6,
			Ladder = {
				"RapidBlaster",
				"PulseRifle",
				"BurstBlaster",
				"ScatterBlaster",
				"ArcBlaster",
				"BeamBlaster",
				"ChargeBlaster",
				"PlasmaLauncher",
				"PrecisionBlaster",
				"FlickSidearm",
				"CometSidearm", -- final weapon: one elimination wins
			},
		},
	},
	ModeOrder = { "TeamDeathmatch", "FreeForAll", "GunGame" },

	Teams = {
		Nova = { DisplayName = "Nova", Color = Color3.fromRGB(40, 210, 255) },
		Flux = { DisplayName = "Flux", Color = Color3.fromRGB(255, 90, 200) },
	},
	TeamOrder = { "Nova", "Flux" },
	FreeForAllColor = Color3.fromRGB(255, 210, 70),

	Queue = {
		-- Minimum real players before the match countdown begins. Bots fill
		-- the rest when FillWithBots is on, so 1 = solo players can play.
		MinPlayers = 1,
		StartDelay = 8, -- seconds of "match starting" after the minimum is met
		FillWithBots = true,
		DefaultBotDifficulty = "Normal",
		AllowJoinInProgress = true,
	},

	Phases = {
		LoadingTime = 2,
		CountdownTime = 5,
		ResultsTime = 12,
	},

	Score = {
		Elimination = 100,
		Assist = 40,
		HeadshotBonus = 25,
		AssistWindow = 10, -- seconds a damage contribution counts toward an assist
	},
}

-- Gun game score limit equals ladder length.
MatchConfig.Modes.GunGame.ScoreLimit = #MatchConfig.Modes.GunGame.Ladder

function MatchConfig.GetMode(id: string)
	return MatchConfig.Modes[id]
end

return TableUtil.DeepFreeze(MatchConfig)
