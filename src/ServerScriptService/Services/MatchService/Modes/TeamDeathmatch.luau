--[[
	Team Deathmatch rules: two teams, team eliminations count toward the
	score limit. Highest team score wins at the time limit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.MatchConfig)

local Mode = {}

Mode.TeamBased = true

function Mode.Setup(match)
	for _, team in MatchConfig.TeamOrder do
		match.TeamScores[team] = 0
	end
end

-- Team with fewer members (ties -> lower score) gets the next combatant.
function Mode.PickTeam(match): string
	local counts = {}
	for _, team in MatchConfig.TeamOrder do
		counts[team] = 0
	end
	for combatant in match.Participants do
		if combatant.Team and counts[combatant.Team] then
			counts[combatant.Team] += 1
		end
	end
	local best = MatchConfig.TeamOrder[1]
	for _, team in MatchConfig.TeamOrder do
		if counts[team] < counts[best] or (counts[team] == counts[best] and match.TeamScores[team] < match.TeamScores[best]) then
			best = team
		end
	end
	return best
end

function Mode.GetLoadout(match, combatant)
	return match.Services.MatchService:GetChosenLoadout(combatant), false
end

-- Returns true when the match should end.
function Mode.OnElimination(match, _victim, killer)
	if killer and killer.Team then
		match.TeamScores[killer.Team] += 1
		return match.TeamScores[killer.Team] >= match.ModeConfig.ScoreLimit
	end
	return false
end

function Mode.GetWinner(match)
	local bestTeam, bestScore, tie = nil, -1, false
	for team, score in match.TeamScores do
		if score > bestScore then
			bestTeam, bestScore, tie = team, score, false
		elseif score == bestScore then
			tie = true
		end
	end
	if tie then
		return { Team = nil, Draw = true }
	end
	return { Team = bestTeam }
end

return Mode
