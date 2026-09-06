--[[ MatchData: game mode definitions and shared match constants. ]]

local MatchData = {}

MatchData.Teams = {
	Blue = { Name = "Blue Team", Color = Color3.fromRGB(50, 140, 255), BrickColor = BrickColor.new("Cyan") },
	Purple = { Name = "Purple Team", Color = Color3.fromRGB(170, 70, 255), BrickColor = BrickColor.new("Royal purple") },
}

MatchData.Modes = {
	TeamBlast = {
		Id = "TeamBlast",
		DisplayName = "Team Blast",
		Teams = true,
		ScoreToWin = 50,
		MinPlayers = 2,
		MaxPlayers = 8,
		RespawnTime = 3,
	},
	HyperRush = {
		Id = "HyperRush",
		DisplayName = "Hyper Rush",
		Teams = false,
		ScoreToWin = 30,
		MinPlayers = 2,
		MaxPlayers = 12,
		RespawnTime = 3,
	},
}

MatchData.DefaultMode = "TeamBlast"

MatchData.MatchStartCountdown = 5
MatchData.IntermissionTime = 10
MatchData.MaxMatchDuration = 10 * 60 -- 10 minutes hard cap

MatchData.KillScore = 100
MatchData.AssistScore = 25

MatchData.KillstreakThresholds = { 3, 5, 10 }

MatchData.XP = {
	PerKill = 50,
	PerAssist = 20,
	PerWin = 200,
	PerLoss = 75,
	PerMatchComplete = 25,
}

-- XP required to reach the NEXT level, indexed by current level.
function MatchData.XPForLevel(level)
	return 100 + (level - 1) * 45
end

return MatchData
