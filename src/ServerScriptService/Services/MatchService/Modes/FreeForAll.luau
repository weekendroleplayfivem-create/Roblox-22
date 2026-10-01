--[[
	Free For All rules: everyone is an enemy; first to the elimination limit
	wins. Most eliminations (then score) wins at the time limit.
]]

local Mode = {}

Mode.TeamBased = false

function Mode.Setup(_match) end

function Mode.PickTeam(_match): string?
	return nil
end

function Mode.GetLoadout(match, combatant)
	return match.Services.MatchService:GetChosenLoadout(combatant), false
end

function Mode.OnElimination(match, _victim, killer)
	return killer ~= nil and killer.Stats.Kills >= match.ModeConfig.ScoreLimit
end

function Mode.GetWinner(match)
	local best = nil
	for combatant in match.Participants do
		if not best
			or combatant.Stats.Kills > best.Stats.Kills
			or (combatant.Stats.Kills == best.Stats.Kills and combatant.Stats.Score > best.Stats.Score)
		then
			best = combatant
		end
	end
	return { Combatant = best }
end

return Mode
