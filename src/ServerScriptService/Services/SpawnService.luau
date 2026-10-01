--[[
	SpawnService
	Chooses the safest spawn point for a combatant by scoring every candidate:

	  + distance from the nearest living enemy (up to a cap)
	  - visible to an enemy (line of sight from enemy heads)
	  - enemy very close
	  - recent deaths nearby
	  - recent combat (damage events) nearby
	  + teammates nearby (team modes)
	  + own team's side (team modes)
	  - used very recently (prevents spawn stacking)

	A little randomness keeps spawns from being predictable.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaycastUtil = require(Shared.Modules.RaycastUtil)

local SpawnService = {}

local Services

-- Scoring weights (tuning).
local ENEMY_DISTANCE_CAP = 120
local ENEMY_DISTANCE_WEIGHT = 1
local ENEMY_TOO_CLOSE = 25
local ENEMY_TOO_CLOSE_PENALTY = 250
local VISIBLE_PENALTY = 180
local VISIBILITY_RANGE = 220
local DEATH_RADIUS = 25
local DEATH_MEMORY = 8
local DEATH_PENALTY = 60
local COMBAT_RADIUS = 35
local COMBAT_MEMORY = 5
local COMBAT_PENALTY = 45
local TEAMMATE_RADIUS = 50
local TEAMMATE_BONUS = 15
local TEAM_SIDE_BONUS = 120
local NEUTRAL_IN_TEAM_MODE_PENALTY = 40
local RECENT_USE_SECONDS = 3
local RECENT_USE_PENALTY = 80
local RANDOM_JITTER = 10

type Event = { Position: Vector3, Time: number }

local recentDeaths: { Event } = {}
local recentCombat: { Event } = {}
local recentUse: { [any]: number } = {}
local rng = Random.new()

local function prune(list: { Event }, memory: number)
	local cutoff = os.clock() - memory
	for index = #list, 1, -1 do
		if list[index].Time < cutoff then
			table.remove(list, index)
		end
	end
end

function SpawnService:Init(services)
	Services = services
end

function SpawnService:Start() end

function SpawnService:RecordDeath(position: Vector3)
	table.insert(recentDeaths, { Position = position, Time = os.clock() })
end

function SpawnService:RecordCombat(position: Vector3)
	-- Throttle: ignore events very close to the last recorded one.
	local last = recentCombat[#recentCombat]
	if last and os.clock() - last.Time < 0.25 and (last.Position - position).Magnitude < 10 then
		return
	end
	table.insert(recentCombat, { Position = position, Time = os.clock() })
end

function SpawnService:Reset()
	table.clear(recentDeaths)
	table.clear(recentCombat)
	table.clear(recentUse)
end

-- Scores one spawn for `combatant`. Exposed for tests/debugging.
function SpawnService:ScoreSpawn(spawnPoint, combatant, teamSide: string?, teamBased: boolean): number
	local CombatantService = Services.CombatantService
	local position = spawnPoint.CFrame.Position
	local eye = position + Vector3.new(0, 1.5, 0)
	local score = 0
	local nearestEnemy = ENEMY_DISTANCE_CAP
	local params = RaycastUtil.WorldParams()

	for _, other in CombatantService:GetInMatch() do
		if other ~= combatant and CombatantService:IsAlive(other) then
			local otherPosition = other.Root.Position
			local distance = (otherPosition - position).Magnitude
			if CombatantService:AreEnemies(combatant, other) then
				nearestEnemy = math.min(nearestEnemy, distance)
				if distance < ENEMY_TOO_CLOSE then
					score -= ENEMY_TOO_CLOSE_PENALTY
				end
				if distance < VISIBILITY_RANGE then
					local head = CombatantService:GetHeadPosition(other)
					if head and RaycastUtil.HasLineOfSight(head, eye, params, 1) then
						score -= VISIBLE_PENALTY
					end
				end
			elseif teamBased and distance < TEAMMATE_RADIUS then
				score += TEAMMATE_BONUS
			end
		end
	end
	score += nearestEnemy * ENEMY_DISTANCE_WEIGHT

	for _, death in recentDeaths do
		if (death.Position - position).Magnitude < DEATH_RADIUS then
			score -= DEATH_PENALTY
		end
	end
	for _, event in recentCombat do
		if (event.Position - position).Magnitude < COMBAT_RADIUS then
			score -= COMBAT_PENALTY
		end
	end

	if teamBased then
		if spawnPoint.Side == nil then
			score -= NEUTRAL_IN_TEAM_MODE_PENALTY
		elseif spawnPoint.Side == teamSide then
			score += TEAM_SIDE_BONUS
		else
			score -= TEAM_SIDE_BONUS
		end
	end

	local lastUsed = recentUse[spawnPoint]
	if lastUsed and os.clock() - lastUsed < RECENT_USE_SECONDS then
		score -= RECENT_USE_PENALTY
	end
	return score + rng:NextNumber(0, RANDOM_JITTER)
end

-- Returns the best spawn CFrame for the combatant in the current arena.
function SpawnService:ChooseSpawn(combatant, teamSide: string?, teamBased: boolean): CFrame?
	local arena = Services.MapService:GetArena()
	if not arena or #arena.Spawns == 0 then
		return nil
	end
	prune(recentDeaths, DEATH_MEMORY)
	prune(recentCombat, COMBAT_MEMORY)

	local bestScore = -math.huge
	local best = nil
	for _, spawnPoint in arena.Spawns do
		local score = SpawnService:ScoreSpawn(spawnPoint, combatant, teamSide, teamBased)
		if score > bestScore then
			bestScore = score
			best = spawnPoint
		end
	end
	if best then
		recentUse[best] = os.clock()
		return best.CFrame
	end
	return nil
end

return SpawnService
