--[[
	ProgressionConfig
	XP sources, level curve and level-up rewards. Progression never requires
	purchases; everything is earned by playing.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local ProgressionConfig = {
	MaxLevel = 100,

	XP = {
		Participation = 150, -- finishing a match
		ParticipationPerMinute = 20, -- capped by match length
		Elimination = 50,
		Assist = 20,
		Headshot = 10,
		Victory = 200,
		TopThreeFFA = 100,
		ChallengeComplete = 0, -- per-challenge values below
	},

	Credits = {
		PerMatch = 40,
		PerElimination = 3,
		Victory = 40,
		PerLevelUp = 100,
	},

	-- Per-match challenges, evaluated by the server at match end.
	Challenges = {
		{ Id = "Eliminations10", Description = "Get 10 eliminations in one match", Stat = "Kills", Goal = 10, XP = 150 },
		{ Id = "Headshots3", Description = "Land 3 headshot eliminations", Stat = "Headshots", Goal = 3, XP = 100 },
		{ Id = "Assists5", Description = "Earn 5 assists", Stat = "Assists", Goal = 5, XP = 100 },
		{ Id = "Damage1500", Description = "Deal 1500 damage", Stat = "DamageDealt", Goal = 1500, XP = 120 },
	},
}

-- XP needed to go from `level` to `level + 1`.
function ProgressionConfig.XPForLevel(level: number): number
	return math.floor(500 + (level - 1) * 125)
end

-- Converts a total XP value into (level, xpIntoLevel, xpNeededForNext).
function ProgressionConfig.LevelFromXP(totalXP: number): (number, number, number)
	local level = 1
	local remaining = math.max(0, totalXP)
	while level < ProgressionConfig.MaxLevel do
		local needed = ProgressionConfig.XPForLevel(level)
		if remaining < needed then
			return level, remaining, needed
		end
		remaining -= needed
		level += 1
	end
	return ProgressionConfig.MaxLevel, 0, 0
end

return TableUtil.DeepFreeze(ProgressionConfig)
