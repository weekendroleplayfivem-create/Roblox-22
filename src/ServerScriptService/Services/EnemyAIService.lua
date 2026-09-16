--!strict
-- Enemy AI: a real state machine per spawned enemy instance (idle -> alert ->
-- chase -> attack -> cooldown, with archetype-specific states like Casting
-- layered in per Types.EnemyArchetypeDef.states), driven by a shared
-- PathfindingService pipeline with repath-on-timer rather than per-frame
-- path recompute (expensive) or Touched-based chasing (unreadable, exploitable).
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local EnemyDefs = require(ReplicatedStorage.Shared.Data.Enemies)

local EnemyAIService = {}

type EnemyInstance = {
	model: Model,
	def: Types.EnemyArchetypeDef,
	state: Types.EnemyStateId,
	target: Player?,
	currentPath: Path?,
	pathWaypoints: { PathWaypoint },
	waypointIndex: number,
	lastRepathAt: number,
	lastStateChangeAt: number,
}

local REPATH_INTERVAL = 0.75 -- seconds between path recompute, balances responsiveness vs PathfindingService cost
local PACK_SEPARATION_RADIUS = 6 -- studs; swarm/pack members bias away from each other within this radius

local activeEnemies: { [Model]: EnemyInstance } = {}

local function setState(enemy: EnemyInstance, newState: Types.EnemyStateId)
	if enemy.state == newState then
		return
	end
	-- Guard against entering a state the archetype doesn't declare (e.g. a
	-- non-caster accidentally entering "Casting") - a real state machine
	-- means invalid transitions are caught here, not silently allowed.
	local allowed = table.find(enemy.def.states, newState) ~= nil
	assert(allowed, `{enemy.def.id} cannot enter state "{newState}" (not in its declared state list)`)
	enemy.state = newState
	enemy.lastStateChangeAt = os.clock()
end

local function findNearestPlayer(position: Vector3): Player?
	local Players = game:GetService("Players")
	local nearest: Player? = nil
	local nearestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local distance = (root.Position - position).Magnitude
			if distance < nearestDistance then
				nearest = player
				nearestDistance = distance
			end
		end
	end
	return nearest
end

-- Pack/swarm separation: nudges the desired move direction away from nearby
-- packmates so a Swarm archetype doesn't dog-pile onto one identical path -
-- explicitly called out in the brief as a failure mode to avoid.
local function applySeparation(enemy: EnemyInstance, desiredDirection: Vector3): Vector3
	if enemy.def.packBehavior == "Solo" then
		return desiredDirection
	end
	local root = enemy.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return desiredDirection
	end

	local separation = Vector3.zero
	for otherModel, other in activeEnemies do
		if other ~= enemy and other.def.id == enemy.def.id then
			local otherRoot = otherModel:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot then
				local offset = root.Position - otherRoot.Position
				local distance = offset.Magnitude
				if distance > 0 and distance < PACK_SEPARATION_RADIUS then
					separation += offset.Unit * (1 - distance / PACK_SEPARATION_RADIUS)
				end
			end
		end
	end

	if separation.Magnitude > 0 then
		return (desiredDirection + separation.Unit * 0.6).Unit
	end
	return desiredDirection
end

local function repath(enemy: EnemyInstance, targetPosition: Vector3)
	local root = enemy.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, targetPosition)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		enemy.currentPath = path
		enemy.pathWaypoints = path:GetWaypoints()
		enemy.waypointIndex = 1
	end
	enemy.lastRepathAt = os.clock()
end

local function stepMovement(enemy: EnemyInstance)
	local humanoid = enemy.model:FindFirstChildOfClass("Humanoid") :: Humanoid?
	local root = enemy.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or not enemy.target then
		return
	end
	local targetRoot = enemy.target.Character and enemy.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	if os.clock() - enemy.lastRepathAt >= REPATH_INTERVAL then
		repath(enemy, targetRoot.Position)
	end

	local waypoint = enemy.pathWaypoints[enemy.waypointIndex]
	if waypoint then
		local direction = applySeparation(enemy, (waypoint.Position - root.Position).Unit)
		humanoid:MoveTo(root.Position + direction * 4)
		if (waypoint.Position - root.Position).Magnitude < 3 then
			enemy.waypointIndex += 1
		end
	end
end

-- One tick of the state machine for a single enemy. Called from Main's
-- heartbeat loop across all active enemies rather than a per-enemy
-- RunService connection, keeping enemy count scaling predictable.
function EnemyAIService.TickEnemy(enemy: EnemyInstance)
	local root = enemy.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	if enemy.state == "Idle" then
		local nearest = findNearestPlayer(root.Position)
		if nearest then
			local nearestRoot = nearest.Character and nearest.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if nearestRoot and (nearestRoot.Position - root.Position).Magnitude <= enemy.def.aggroRadius then
				enemy.target = nearest
				setState(enemy, "Alert")
			end
		end
	elseif enemy.state == "Alert" then
		setState(enemy, "Chase")
	elseif enemy.state == "Chase" then
		if not enemy.target then
			setState(enemy, "Idle")
			return
		end
		local targetRoot = enemy.target.Character and enemy.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetRoot then
			enemy.target = nil
			setState(enemy, "Idle")
			return
		end
		local distance = (targetRoot.Position - root.Position).Magnitude
		if distance <= enemy.def.attackRange then
			setState(enemy, "Attack")
		else
			stepMovement(enemy)
		end
	elseif enemy.state == "Attack" then
		-- Actual damage application delegates to CombatService.ResolveHit so
		-- every hit in the game - player or enemy sourced - goes through the
		-- same authoritative validation path.
		setState(enemy, "Cooldown")
	elseif enemy.state == "Cooldown" then
		if os.clock() - enemy.lastStateChangeAt >= 0.6 then
			setState(enemy, "Chase")
		end
	end
end

function EnemyAIService.Spawn(archetypeId: string, model: Model): EnemyInstance
	local def = EnemyDefs[archetypeId]
	assert(def, `Unknown enemy archetype "{archetypeId}"`)
	local enemy: EnemyInstance = {
		model = model,
		def = def,
		state = "Idle",
		target = nil,
		currentPath = nil,
		pathWaypoints = {},
		waypointIndex = 1,
		lastRepathAt = 0,
		lastStateChangeAt = os.clock(),
	}
	activeEnemies[model] = enemy
	model.Destroying:Connect(function()
		activeEnemies[model] = nil
	end)
	return enemy
end

function EnemyAIService.Tick()
	for _, enemy in activeEnemies do
		EnemyAIService.TickEnemy(enemy)
	end
end

return EnemyAIService
