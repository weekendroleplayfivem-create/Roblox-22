--[[
	DamageService
	The single place health is ever changed. Applies damage, resolves kills,
	awards score/XP, fires kill feed events, and hands respawning off to
	MatchManager. Nothing else should touch Humanoid.Health directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchData = require(ReplicatedStorage.Shared.MatchData)
local PlayerData = require(script.Parent.PlayerData)
local XPService = require(script.Parent.XPService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayerEliminated = Remotes:WaitForChild("PlayerEliminated")
local PlayerDamaged = Remotes:WaitForChild("PlayerDamaged")

local DamageService = {}

-- [player] = { streak = number, lastDamagedBy = player, lastDamageTime = number }
local combatState = {}

-- Set by MatchManager so DamageService can award team score / trigger respawns
-- without a circular require.
DamageService.OnElimination = nil -- function(victim, killer, weaponId, isHeadshot)

local function getState(player)
	local state = combatState[player]
	if not state then
		state = { streak = 0 }
		combatState[player] = state
	end
	return state
end

function DamageService.ResetStreak(player)
	getState(player).streak = 0
end

function DamageService.ApplyDamage(attacker, victim, amount, weaponId, isHeadshot)
	if not victim or not attacker then
		return
	end
	if victim == attacker then
		return
	end

	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	amount = math.clamp(amount, 0, 1000)
	humanoid:TakeDamage(amount)

	local vState = getState(victim)
	vState.lastDamagedBy = attacker
	vState.lastDamageTime = os.clock()

	PlayerDamaged:FireClient(victim, amount, isHeadshot)

	if humanoid.Health <= 0 then
		DamageService.HandleElimination(attacker, victim, weaponId, isHeadshot)
	end
end

function DamageService.HandleElimination(killer, victim, weaponId, isHeadshot)
	local killerProfile = killer and PlayerData.Get(killer)
	local victimProfile = PlayerData.Get(victim)

	if killerProfile then
		killerProfile.Kills += 1
		local kState = getState(killer)
		kState.streak += 1
		for _, threshold in ipairs(MatchData.KillstreakThresholds) do
			if kState.streak == threshold then
				PlayerEliminated:FireAllClients({
					Type = "Killstreak",
					Player = killer.Name,
					Streak = threshold,
				})
			end
		end
		XPService.Award(killer, MatchData.XP.PerKill, "Elimination")
	end

	if victimProfile then
		victimProfile.Deaths += 1
	end
	DamageService.ResetStreak(victim)

	PlayerEliminated:FireAllClients({
		Type = "Elimination",
		Killer = killer and killer.Name or "World",
		Victim = victim.Name,
		WeaponId = weaponId,
		Headshot = isHeadshot,
		Score = MatchData.KillScore,
	})

	if DamageService.OnElimination then
		DamageService.OnElimination(victim, killer, weaponId, isHeadshot)
	end
end

return DamageService
