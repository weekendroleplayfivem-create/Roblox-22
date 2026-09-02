--!nonstrict
--[[
	BaseMode.luau
	The contract every game mode implements. MatchService only ever talks to this
	interface, which is what keeps mode-specific rules out of the core services.

	A mode owns: scoring, spawn selection, win conditions, and any objective
	entities it needs. It does NOT own health, weapons, movement or abilities -
	it can only *restrict* those through the hooks below.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local GameModeConfig = require(Root.Config.GameModeConfig)

local BaseMode = {}
BaseMode.__index = BaseMode

function BaseMode.new(services, arena, modeId: string)
	local self = setmetatable({}, BaseMode)

	self.services = services
	self.arena = arena
	self.config = GameModeConfig.get(modeId)
	self.scores = { Cyan = 0, Magenta = 0 }
	self.running = false

	return self
end

function BaseMode:Start()
	self.running = true
end

function BaseMode:Stop()
	self.running = false
end

function BaseMode:Update(_dt: number) end

function BaseMode:OnKill(_victim: Player, _killer: Player?, _info) end

function BaseMode:OnPlayerSpawned(_player: Player) end

function BaseMode:GetScores()
	return self.scores
end

function BaseMode:AddScore(teamKey: string, amount: number)
	self.scores[teamKey] = (self.scores[teamKey] or 0) + amount
end

--[[ Returns winnerKey or nil. MatchService polls this. ]]
function BaseMode:GetWinner(): string?
	for teamKey, score in self.scores do
		if score >= self.config.ScoreLimit then
			return teamKey
		end
	end
	return nil
end

--[[ Called when the clock runs out. Highest score wins; equal scores return nil,
	 which MatchService turns into overtime (or a draw if overtime is disabled). ]]
function BaseMode:GetTimeoutWinner(): string?
	local best, bestScore, tied = nil, -math.huge, false
	for teamKey, score in self.scores do
		if score > bestScore then
			best, bestScore, tied = teamKey, score, false
		elseif score == bestScore then
			tied = true
		end
	end
	return (not tied) and best or nil
end

function BaseMode:IsAbilityAllowed(_player: Player, id: string): boolean
	local allowed = self.config.AbilitiesEnabled
	if allowed then
		return allowed[id] ~= false
	end
	return true
end

function BaseMode:GetRespawnDelay(): number
	return self.config.RespawnDelay
end

function BaseMode:AllowsAutoRespawn(): boolean
	return not self.config.RoundBased
end

function BaseMode:GetObjectiveState()
	return {}
end

----------------------------------------------------------------------
-- Spawn selection
----------------------------------------------------------------------

--[[ Default: spawn in the team's zone at the point furthest from the nearest
	 living enemy. "Random point in a box" spawns you into a duel you didn't
	 choose; this costs one loop over a handful of candidates and prevents it. ]]
function BaseMode:GetSpawnPoint(player: Player): CFrame
	local playerService = self.services.Player
	local teamKey = playerService:GetTeamKey(player)
	local spawn = self.arena.spawns[teamKey] or self.arena.spawns.Cyan
	local enemies = {}

	for otherKey in self.arena.spawns do
		if otherKey ~= teamKey then
			for _, enemy in playerService:GetTeamPlayers(otherKey) do
				local root = enemy.Character and enemy.Character:FindFirstChild("HumanoidRootPart")
				if root and playerService:IsAlive(enemy) then
					table.insert(enemies, root.Position)
				end
			end
		end
	end

	local best, bestScore
	local random = Random.new()

	for _ = 1, 8 do
		local candidate = spawn.center
			+ Vector3.new(random:NextNumber(-spawn.spread, spawn.spread), 0, random:NextNumber(-8, 8))

		local score = math.huge
		for _, enemyPosition in enemies do
			score = math.min(score, (candidate - enemyPosition).Magnitude)
		end

		if not best or score > bestScore then
			best, bestScore = candidate, score
		end
	end

	local facing = spawn.facing or Vector3.new(0, 0, 1)
	return CFrame.lookAt(best, best + facing)
end

return BaseMode
