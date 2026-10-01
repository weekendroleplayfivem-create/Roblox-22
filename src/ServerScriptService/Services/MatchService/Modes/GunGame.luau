--[[
	Gun Game rules: everyone starts on the first ladder weapon. Each
	elimination advances you one weapon. An elimination with the final
	weapon wins. Reserve ammo is infinite so nobody gets stuck.
]]

local Mode = {}

Mode.TeamBased = false

function Mode.Setup(_match) end

function Mode.PickTeam(_match): string?
	return nil
end

local function ladder(match)
	return match.ModeConfig.Ladder
end

function Mode.GetLoadout(match, combatant)
	local list = ladder(match)
	local level = math.clamp(combatant.GunGameLevel, 1, #list)
	return { Primary = list[level] }, true
end

function Mode.OnElimination(match, _victim, killer)
	if not killer then
		return false
	end
	local list = ladder(match)
	if killer.GunGameLevel >= #list then
		match.GunGameWinner = killer
		return true
	end
	killer.GunGameLevel += 1
	-- Swap to the next weapon immediately.
	if killer.Alive then
		local slots, infinite = Mode.GetLoadout(match, killer)
		match.Services.WeaponService:GiveLoadout(killer, slots, infinite)
	end
	if killer.Player then
		local nextWeapon = list[killer.GunGameLevel]
		match.Services.MatchService:Announce(killer.Player, {
			Text = if killer.GunGameLevel == #list then "FINAL WEAPON!" else "WEAPON UP!",
			Sub = string.format("%d / %d", killer.GunGameLevel, #list),
			Weapon = nextWeapon,
			Duration = 1.5,
			Small = true,
		})
	end
	return false
end

function Mode.GetWinner(match)
	if match.GunGameWinner then
		return { Combatant = match.GunGameWinner }
	end
	local best = nil
	for combatant in match.Participants do
		if not best
			or combatant.GunGameLevel > best.GunGameLevel
			or (combatant.GunGameLevel == best.GunGameLevel and combatant.Stats.Kills > best.Stats.Kills)
		then
			best = combatant
		end
	end
	return { Combatant = best }
end

return Mode
