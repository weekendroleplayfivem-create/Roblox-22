--[[
	EnemyManager
	Spawns, moves, damages and retires every enemy.

	Movement is deliberately kinematic: enemy parts are anchored and stepped
	along the waypoint list by CFrame in a SINGLE Heartbeat loop for all
	enemies. No Humanoids, no pathfinding, no physics. That means enemy
	positions are exactly reproducible, cost almost nothing per unit, and can
	never get shoved off the road by a collision — which matters a lot in a
	game where "which lane did it take" is a gameplay signal.

	Models are pooled: acquire/release below are the only places an enemy model
	is ever created or destroyed, so reuse stays contained.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyData = require(ReplicatedStorage.Shared.EnemyData)
local MapData = require(ReplicatedStorage.Shared.MapData)
local AdaptiveAI = require(script.Parent.AdaptiveAI)

local EnemyManager = {}

export type Enemy = {
	Id: number,
	EnemyId: string,
	Model: Model,
	Root: BasePart,
	Health: number,
	MaxHealth: number,
	BaseSpeed: number,
	Route: string,
	Waypoints: { Vector3 },
	WaypointIndex: number,
	Progress: number, -- studs travelled, used for First/Last targeting
	SlowFactor: number, -- 1 = unslowed
	SlowUntil: number,
	SlowResistance: number,
	DamageResistance: number,
	IsBoss: boolean,
	Dead: boolean,
}

local activeEnemies: { [number]: Enemy } = {}
local enemyPool: { [string]: { Model } } = {}
local nextEnemyId = 1
local enemyFolder: Folder

-- Set by GameManager so damage/leaks can be routed without a circular require.
EnemyManager.OnEnemyLeaked = nil :: ((enemy: Enemy) -> ())?
EnemyManager.OnEnemyKilled = nil :: ((enemy: Enemy) -> ())?

local function getFolder(): Folder
	if enemyFolder and enemyFolder.Parent then
		return enemyFolder
	end
	local existing = Workspace:FindFirstChild("Enemies")
	if existing then
		enemyFolder = existing :: Folder
	else
		enemyFolder = Instance.new("Folder")
		enemyFolder.Name = "Enemies"
		enemyFolder.Parent = Workspace
	end
	return enemyFolder
end

--============================================================
-- Model construction
--============================================================

local function makePart(parent: Instance, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function buildEnemyModel(enemyId: string): Model
	local data = EnemyData.Get(enemyId)
	assert(data, "Unknown enemy: " .. tostring(enemyId))

	local model = Instance.new("Model")
	model.Name = enemyId

	local root = makePart(model, data.Size, data.Color)
	root.Name = "Root"
	model.PrimaryPart = root

	-- Glowing eye: the single most readable "this is a machine" cue, and the
	-- colour is how a player tells variants apart at a glance.
	local eye = makePart(model, Vector3.new(data.Size.X * 0.5, data.Size.Y * 0.22, 0.4), data.EyeColor, Enum.Material.Neon)
	eye.Name = "Eye"

	local light = Instance.new("PointLight")
	light.Color = data.EyeColor
	light.Range = math.max(8, data.Size.X * 3)
	light.Brightness = 1.6
	light.Parent = eye

	-- Chassis detailing, scaled off the body so every variant reads as the
	-- same family of machine.
	local shoulder = makePart(model, Vector3.new(data.Size.X * 1.15, data.Size.Y * 0.22, data.Size.Z * 0.7), Color3.fromRGB(40, 44, 52))
	shoulder.Name = "Shoulder"

	local base = makePart(model, Vector3.new(data.Size.X * 0.8, data.Size.Y * 0.2, data.Size.Z * 0.8), Color3.fromRGB(30, 33, 40))
	base.Name = "Base"

	if data.IsBoss then
		-- Bosses get an armature of arms so their silhouette is unmistakable.
		for index = 1, 4 do
			local arm = makePart(model, Vector3.new(1.2, data.Size.Y * 0.9, 1.2), Color3.fromRGB(30, 33, 42))
			arm.Name = "Arm" .. index
		end
		local halo = makePart(model, Vector3.new(data.Size.X * 1.5, 0.5, data.Size.Z * 1.5), data.EyeColor, Enum.Material.Neon)
		halo.Name = "Halo"
		halo.Transparency = 0.4
	end

	-- Health bar.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.fromOffset(if data.IsBoss then 260 else 90, if data.IsBoss then 26 else 12)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, data.Size.Y * 0.8 + 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 400
	billboard.Parent = root

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	track.BorderSizePixel = 0
	track.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 235, 140)
	fill.BorderSizePixel = 0
	fill.Parent = track

	if data.IsBoss then
		local label = Instance.new("TextLabel")
		label.Name = "BossName"
		label.Size = UDim2.new(1, 0, 0, 22)
		label.Position = UDim2.new(0, 0, 0, -24)
		label.BackgroundTransparency = 1
		label.Text = data.DisplayName
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = data.EyeColor
		label.TextScaled = true
		label.Parent = billboard
	end

	return model
end

-- Lays out the child parts relative to the root. Called on every acquire so a
-- recycled model is geometrically identical to a fresh one.
local function layoutModel(model: Model, enemyId: string, cframe: CFrame)
	local data = EnemyData.Get(enemyId) :: any
	local root = model.PrimaryPart :: BasePart
	root.CFrame = cframe

	local eye = model:FindFirstChild("Eye") :: BasePart?
	if eye then
		eye.CFrame = cframe * CFrame.new(0, data.Size.Y * 0.2, -data.Size.Z / 2 - 0.15)
	end
	local shoulder = model:FindFirstChild("Shoulder") :: BasePart?
	if shoulder then
		shoulder.CFrame = cframe * CFrame.new(0, data.Size.Y * 0.45, 0)
	end
	local base = model:FindFirstChild("Base") :: BasePart?
	if base then
		base.CFrame = cframe * CFrame.new(0, -data.Size.Y * 0.55, 0)
	end
	local halo = model:FindFirstChild("Halo") :: BasePart?
	if halo then
		halo.CFrame = cframe * CFrame.new(0, data.Size.Y * 0.75, 0)
	end
	for index = 1, 4 do
		local arm = model:FindFirstChild("Arm" .. index) :: BasePart?
		if arm then
			local angle = (index / 4) * math.pi * 2
			arm.CFrame = cframe * CFrame.new(math.cos(angle) * data.Size.X * 0.7, 0, math.sin(angle) * data.Size.Z * 0.7)
		end
	end
end

local function acquireModel(enemyId: string): Model
	local pool = enemyPool[enemyId]
	if pool and #pool > 0 then
		local model = table.remove(pool) :: Model
		-- Full visual reset: a recycled model must be indistinguishable from
		-- a new one, including anything the death animation changed.
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Transparency = if descendant.Name == "Halo" then 0.4 else 0
			end
		end
		local bar = model.PrimaryPart and model.PrimaryPart:FindFirstChild("HealthBar")
		if bar then
			(bar :: BillboardGui).Enabled = true
		end
		return model
	end
	return buildEnemyModel(enemyId)
end

local function releaseModel(model: Model, enemyId: string)
	model.Parent = nil
	local pool = enemyPool[enemyId]
	if not pool then
		pool = {}
		enemyPool[enemyId] = pool
	end
	-- Cap the pool so a long run can't hoard models.
	if #pool < 24 then
		table.insert(pool, model)
	else
		model:Destroy()
	end
end

--============================================================
-- Spawning
--============================================================

function EnemyManager.Spawn(enemyId: string, routeOverride: string?): Enemy?
	local data = EnemyData.Get(enemyId)
	if not data then
		warn("[MIND TD] Tried to spawn unknown enemy:", enemyId)
		return nil
	end

	local route = routeOverride or AdaptiveAI.ChooseRoute()
	local waypointData = MapData.GetRoute(route)

	local waypoints: { Vector3 } = {}
	for _, waypoint in ipairs(waypointData) do
		table.insert(waypoints, waypoint.Position + Vector3.new(0, data.Size.Y / 2 + 0.5, 0))
	end

	local modifiers = AdaptiveAI.GetModifiers()
	-- Bosses are scripted encounters; they don't take the wave-level stat
	-- adaptation on top of their own, or the numbers get silly.
	local healthMultiplier = if data.IsBoss then 1 else modifiers.Health
	local speedMultiplier = if data.IsBoss then 1 else modifiers.Speed

	local model = acquireModel(enemyId)
	local startCFrame = CFrame.new(waypoints[1])
	layoutModel(model, enemyId, startCFrame)
	model.Parent = getFolder()

	local enemy: Enemy = {
		Id = nextEnemyId,
		EnemyId = enemyId,
		Model = model,
		Root = model.PrimaryPart :: BasePart,
		Health = data.Health * healthMultiplier,
		MaxHealth = data.Health * healthMultiplier,
		BaseSpeed = data.Speed * speedMultiplier,
		Route = route,
		Waypoints = waypoints,
		WaypointIndex = 2, -- index 1 is the spawn point we're standing on
		Progress = 0,
		SlowFactor = 1,
		SlowUntil = 0,
		SlowResistance = data.SlowResistance,
		DamageResistance = data.DamageResistance,
		IsBoss = data.IsBoss == true,
		Dead = false,
	}

	model:SetAttribute("EnemyId", enemyId)
	model:SetAttribute("Route", route)
	model:SetAttribute("RuntimeId", enemy.Id)

	activeEnemies[enemy.Id] = enemy
	nextEnemyId += 1

	return enemy
end

--============================================================
-- Combat
--============================================================

local HEALTH_GREEN = Color3.fromRGB(120, 235, 140)
local HEALTH_AMBER = Color3.fromRGB(255, 200, 80)
local HEALTH_RED = Color3.fromRGB(255, 90, 90)

local function updateHealthBar(enemy: Enemy)
	local bar = enemy.Root:FindFirstChild("HealthBar")
	if not bar then
		return
	end
	local track = bar:FindFirstChild("Track")
	local fill = track and track:FindFirstChild("Fill") :: Frame?
	if not fill then
		return
	end

	local ratio = math.clamp(enemy.Health / enemy.MaxHealth, 0, 1)
	fill.Size = UDim2.fromScale(ratio, 1)

	local color = HEALTH_RED
	if ratio > 0.5 then
		color = HEALTH_GREEN
	elseif ratio > 0.25 then
		color = HEALTH_AMBER
	end
	fill.BackgroundColor3 = color
end

local function retire(enemy: Enemy)
	activeEnemies[enemy.Id] = nil
	releaseModel(enemy.Model, enemy.EnemyId)
end

-- Applies damage from a tower. Returns true if this hit killed the enemy.
function EnemyManager.Damage(enemy: Enemy, amount: number, towerId: string?): boolean
	if enemy.Dead then
		return false
	end

	-- Armour blunts incoming damage. This is the one place resistance is
	-- applied, so no caller can bypass it.
	local effective = amount * enemy.DamageResistance
	enemy.Health -= effective

	if towerId then
		AdaptiveAI.OnDamageDealt(towerId, effective)
	end

	if enemy.Health <= 0 then
		enemy.Dead = true
		AdaptiveAI.OnEnemyKilled(enemy.EnemyId)
		if EnemyManager.OnEnemyKilled then
			EnemyManager.OnEnemyKilled(enemy)
		end
		retire(enemy)
		return true
	end

	updateHealthBar(enemy)
	return false
end

-- Slows an enemy. Slow resistance scales the strength, not the duration, so a
-- Sprinter still gets tagged — just barely enough to matter.
function EnemyManager.ApplySlow(enemy: Enemy, factor: number, duration: number)
	if enemy.Dead then
		return
	end
	local resisted = 1 - ((1 - factor) * enemy.SlowResistance)
	-- Strongest active slow wins; they don't stack multiplicatively.
	if resisted < enemy.SlowFactor or os.clock() >= enemy.SlowUntil then
		enemy.SlowFactor = resisted
	end
	enemy.SlowUntil = math.max(enemy.SlowUntil, os.clock() + duration)
end

function EnemyManager.GetAll(): { [number]: Enemy }
	return activeEnemies
end

function EnemyManager.Count(): number
	local count = 0
	for _ in pairs(activeEnemies) do
		count += 1
	end
	return count
end

function EnemyManager.ClearAll()
	for _, enemy in pairs(activeEnemies) do
		enemy.Dead = true
		retire(enemy)
	end
	activeEnemies = {}
end

--============================================================
-- Movement — one loop for every enemy on the map
--============================================================

local function step(enemy: Enemy, dt: number)
	local now = os.clock()
	if now >= enemy.SlowUntil then
		enemy.SlowFactor = 1
	end

	local speed = enemy.BaseSpeed * enemy.SlowFactor
	local target = enemy.Waypoints[enemy.WaypointIndex]
	if not target then
		-- Ran off the end of the path: it reached the Core.
		enemy.Dead = true
		AdaptiveAI.OnEnemyLeaked()
		if EnemyManager.OnEnemyLeaked then
			EnemyManager.OnEnemyLeaked(enemy)
		end
		retire(enemy)
		return
	end

	local position = enemy.Root.Position
	local delta = target - position
	local distance = delta.Magnitude
	local travel = speed * dt

	if travel >= distance then
		-- Reached this waypoint; advance. Any leftover movement is carried
		-- into the next segment next frame, which is imperceptible and keeps
		-- the maths simple.
		enemy.Progress += distance
		enemy.WaypointIndex += 1
		enemy.Root.CFrame = CFrame.new(target)
		local nextTarget = enemy.Waypoints[enemy.WaypointIndex]
		if nextTarget then
			layoutModel(enemy.Model, enemy.EnemyId, CFrame.lookAt(target, nextTarget))
		end
		return
	end

	enemy.Progress += travel
	local direction = delta.Unit
	local newPosition = position + direction * travel
	layoutModel(enemy.Model, enemy.EnemyId, CFrame.lookAt(newPosition, newPosition + direction))
end

local movementConnection: RBXScriptConnection?

function EnemyManager.Start()
	if movementConnection then
		return
	end
	movementConnection = RunService.Heartbeat:Connect(function(dt)
		-- Clamp dt so a hitching server can't teleport enemies through towers.
		local delta = math.min(dt, 0.1)
		for _, enemy in pairs(activeEnemies) do
			if not enemy.Dead then
				step(enemy, delta)
			end
		end
	end)
end

function EnemyManager.Stop()
	if movementConnection then
		movementConnection:Disconnect()
		movementConnection = nil
	end
end

return EnemyManager
