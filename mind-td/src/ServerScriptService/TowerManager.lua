--[[
	TowerManager
	Owns every tower: placement, targeting, firing, upgrades and selling.

	Placement is pad-based rather than free-form. That isn't a shortcut — it
	makes server validation exact (a pad either exists and is free, or it
	doesn't), it guarantees towers can never be dropped on the road, and it
	gives AdaptiveAI an authoritative Left/Right/Center reading for every
	tower without having to infer a side from a click position.

	Every request from a client is treated as a suggestion. The server
	re-derives cost, ownership, legality and stats from TowerData before
	anything changes.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local TowerData = require(ReplicatedStorage.Shared.TowerData)
local EconomyManager = require(script.Parent.EconomyManager)
local EnemyManager = require(script.Parent.EnemyManager)
local AdaptiveAI = require(script.Parent.AdaptiveAI)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")

local TowerManager = {}

export type Tower = {
	Id: number,
	TowerId: string,
	Owner: Player,
	Level: number,
	SpotId: number,
	Side: string,
	Model: Model,
	Head: BasePart,
	Position: Vector3,
	TargetMode: string,
	LastFire: number,
}

local towers: { [number]: Tower } = {}
local towersBySpot: { [number]: Tower } = {}
local nextTowerId = 1
local towerFolder: Folder

local function getFolder(): Folder
	if towerFolder and towerFolder.Parent then
		return towerFolder
	end
	local existing = Workspace:FindFirstChild("Towers")
	if existing then
		towerFolder = existing :: Folder
	else
		towerFolder = Instance.new("Folder")
		towerFolder.Name = "Towers"
		towerFolder.Parent = Workspace
	end
	return towerFolder
end

local function getSpot(spotId: number): BasePart?
	local map = Workspace:FindFirstChild("MIND_TD_Map")
	local spots = map and map:FindFirstChild("TowerSpots")
	if not spots then
		return nil
	end
	for _, pad in ipairs(spots:GetChildren()) do
		if pad:IsA("BasePart") and pad:GetAttribute("SpotId") == spotId then
			return pad
		end
	end
	return nil
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

-- Builds a tower at a given level. Higher levels bolt on visible hardware —
-- the player should be able to read a tower's level across the map without
-- clicking it.
local function buildTowerModel(towerId: string, level: number, position: Vector3): (Model, BasePart)
	local data = TowerData.Get(towerId) :: any
	local model = Instance.new("Model")
	model.Name = towerId

	local base = makePart(model, Vector3.new(5, 1.6, 5), data.Color)
	base.CFrame = CFrame.new(position + Vector3.new(0, 1.8, 0))
	base.Name = "Base"
	model.PrimaryPart = base

	local column = makePart(model, Vector3.new(2.4, 2.4, 2.4), data.Color)
	column.CFrame = base.CFrame * CFrame.new(0, 1.9, 0)
	column.Name = "Column"

	-- The head is what rotates to face a target.
	local head = makePart(model, Vector3.new(3, 1.8, 3), data.Color)
	head.CFrame = column.CFrame * CFrame.new(0, 1.8, 0)
	head.Name = "Head"

	local glow = makePart(model, Vector3.new(2, 0.3, 2), data.AccentColor, Enum.Material.Neon)
	glow.CFrame = base.CFrame * CFrame.new(0, 0.9, 0)
	glow.Name = "Glow"

	local light = Instance.new("PointLight")
	light.Color = data.AccentColor
	light.Range = 16 + level * 4
	light.Brightness = 1.2 + level * 0.4
	light.Parent = glow

	if towerId == "Guardian" then
		-- Barrels: one at level 1, two at 2, three at 3.
		for index = 1, level do
			local offset = (index - (level + 1) / 2) * 0.9
			local barrel = makePart(model, Vector3.new(0.55, 0.55, 4 + level * 0.4), Color3.fromRGB(38, 42, 50))
			barrel.CFrame = head.CFrame * CFrame.new(offset, 0, -2.4)
			barrel.Name = "Barrel" .. index
		end
	elseif towerId == "Cryo" then
		-- Coolant tanks ring the head; more tanks at higher levels.
		for index = 1, 2 + level do
			local angle = (index / (2 + level)) * math.pi * 2
			local tank = makePart(model, Vector3.new(0.9, 2.2, 0.9), data.AccentColor, Enum.Material.SmoothPlastic)
			tank.CFrame = head.CFrame * CFrame.new(math.cos(angle) * 1.9, -0.4, math.sin(angle) * 1.9)
			tank.Name = "Tank" .. index
		end
		local emitter = makePart(model, Vector3.new(1.6, 1.6, 1.6), data.AccentColor, Enum.Material.Neon)
		emitter.CFrame = head.CFrame * CFrame.new(0, 1, 0)
		emitter.Shape = Enum.PartType.Ball
		emitter.Name = "Emitter"
	else
		-- Analyzer: a sensor apparatus, not a gun. Rings and a lens, so it
		-- reads as observation equipment at a glance.
		local lens = makePart(model, Vector3.new(2.6, 2.6, 2.6), data.AccentColor, Enum.Material.Neon)
		lens.CFrame = head.CFrame * CFrame.new(0, 1.4, 0)
		lens.Shape = Enum.PartType.Ball
		lens.Transparency = 0.25
		lens.Name = "Lens"

		for index = 1, level do
			local ring = makePart(model, Vector3.new(0.25, 4 + index, 4 + index), data.AccentColor, Enum.Material.Neon)
			ring.Shape = Enum.PartType.Cylinder
			ring.CFrame = head.CFrame * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(index * 35), 0)
			ring.Transparency = 0.55
			ring.Name = "Ring" .. index
		end
	end

	return model, head
end

local function rebuildModel(tower: Tower)
	local oldModel = tower.Model
	local model, head = buildTowerModel(tower.TowerId, tower.Level, tower.Position)
	model:SetAttribute("TowerRuntimeId", tower.Id)
	model:SetAttribute("OwnerUserId", tower.Owner.UserId)
	model.Parent = getFolder()

	tower.Model = model
	tower.Head = head

	if oldModel then
		oldModel:Destroy()
	end
end

--============================================================
-- Placement / upgrade / sell
--============================================================

-- Returns (success, message). The client shows the message; the server has
-- already decided the outcome before it's called.
function TowerManager.PlaceTower(player: Player, towerId: string, spotId: number): (boolean, string)
	local data = TowerData.Get(towerId)
	if not data then
		return false, "Unknown tower"
	end
	if typeof(spotId) ~= "number" then
		return false, "Invalid spot"
	end

	local pad = getSpot(spotId)
	if not pad then
		return false, "That build pad doesn't exist"
	end
	if pad:GetAttribute("Occupied") == true or towersBySpot[spotId] then
		return false, "That pad is already occupied"
	end

	local cost = data.Levels[1].Cost
	if not EconomyManager.TrySpend(player, cost) then
		return false, "Not enough funds"
	end

	local side = pad:GetAttribute("Side") or "Center"
	local position = pad.Position

	local tower: Tower = {
		Id = nextTowerId,
		TowerId = towerId,
		Owner = player,
		Level = 1,
		SpotId = spotId,
		Side = side,
		Model = nil :: any,
		Head = nil :: any,
		Position = position,
		TargetMode = "First",
		LastFire = 0,
	}
	nextTowerId += 1

	rebuildModel(tower)

	towers[tower.Id] = tower
	towersBySpot[spotId] = tower
	pad:SetAttribute("Occupied", true)

	AdaptiveAI.OnTowerPlaced(towerId, side, 1)

	GameEvent:FireAllClients({
		Type = "TowerPlaced",
		TowerRuntimeId = tower.Id,
		TowerId = towerId,
		SpotId = spotId,
		Level = 1,
		OwnerUserId = player.UserId,
	})

	return true, "Placed"
end

function TowerManager.UpgradeTower(player: Player, towerRuntimeId: number): (boolean, string)
	local tower = towers[towerRuntimeId]
	if not tower then
		return false, "Tower not found"
	end
	if tower.Owner ~= player then
		return false, "That isn't your tower"
	end
	if tower.Level >= TowerData.MaxLevel then
		return false, "Already at maximum level"
	end

	local data = TowerData.Get(tower.TowerId) :: any
	local nextLevel = tower.Level + 1
	local cost = data.Levels[nextLevel].Cost

	if not EconomyManager.TrySpend(player, cost) then
		return false, "Not enough funds"
	end

	tower.Level = nextLevel
	rebuildModel(tower)
	AdaptiveAI.OnTowerUpgraded(tower.TowerId, tower.Side, nextLevel)

	GameEvent:FireAllClients({
		Type = "TowerUpgraded",
		TowerRuntimeId = tower.Id,
		Level = nextLevel,
	})

	return true, "Upgraded"
end

function TowerManager.SellTower(player: Player, towerRuntimeId: number): (boolean, string)
	local tower = towers[towerRuntimeId]
	if not tower then
		return false, "Tower not found"
	end
	if tower.Owner ~= player then
		return false, "That isn't your tower"
	end

	local refund = math.floor(TowerData.TotalInvested(tower.TowerId, tower.Level) * TowerData.SellRefundRatio)
	EconomyManager.Award(player, refund)

	AdaptiveAI.OnTowerSold(tower.TowerId, tower.Side, tower.Level)

	local pad = getSpot(tower.SpotId)
	if pad then
		pad:SetAttribute("Occupied", false)
	end

	towers[tower.Id] = nil
	towersBySpot[tower.SpotId] = nil
	tower.Model:Destroy()

	GameEvent:FireAllClients({
		Type = "TowerSold",
		TowerRuntimeId = towerRuntimeId,
		SpotId = tower.SpotId,
	})

	return true, string.format("Sold for %d", refund)
end

function TowerManager.ChangeTargetMode(player: Player, towerRuntimeId: number, mode: string): (boolean, string)
	local tower = towers[towerRuntimeId]
	if not tower then
		return false, "Tower not found"
	end
	if tower.Owner ~= player then
		return false, "That isn't your tower"
	end
	if not TowerData.IsValidTargetMode(mode) then
		return false, "Invalid target mode"
	end

	tower.TargetMode = mode
	AdaptiveAI.OnTargetModeChanged(mode)

	GameEvent:FireAllClients({
		Type = "TowerTargetMode",
		TowerRuntimeId = towerRuntimeId,
		Mode = mode,
	})

	return true, mode
end

function TowerManager.GetTower(towerRuntimeId: number): Tower?
	return towers[towerRuntimeId]
end

function TowerManager.GetTowerAtSpot(spotId: number): Tower?
	return towersBySpot[spotId]
end

function TowerManager.ClearAll()
	for _, tower in pairs(towers) do
		local pad = getSpot(tower.SpotId)
		if pad then
			pad:SetAttribute("Occupied", false)
		end
		tower.Model:Destroy()
	end
	towers = {}
	towersBySpot = {}
end

-- Snapshot for the client (late join, or rebuilding the selection UI).
function TowerManager.GetSnapshot()
	local list = {}
	for _, tower in pairs(towers) do
		table.insert(list, {
			TowerRuntimeId = tower.Id,
			TowerId = tower.TowerId,
			SpotId = tower.SpotId,
			Level = tower.Level,
			TargetMode = tower.TargetMode,
			OwnerUserId = tower.Owner.UserId,
		})
	end
	return list
end

--============================================================
-- Targeting + firing
--============================================================

local function selectTarget(tower: Tower, range: number)
	local best = nil
	local bestScore = nil
	local rangeSquared = range * range

	for _, enemy in pairs(EnemyManager.GetAll()) do
		if not enemy.Dead then
			local offset = enemy.Root.Position - tower.Position
			-- Squared comparison avoids a square root per enemy per shot.
			if offset.X * offset.X + offset.Z * offset.Z <= rangeSquared then
				local score
				if tower.TargetMode == "First" then
					score = enemy.Progress -- furthest along = closest to the Core
				elseif tower.TargetMode == "Last" then
					score = -enemy.Progress
				elseif tower.TargetMode == "Strongest" then
					score = enemy.Health
				else -- Weakest
					score = -enemy.Health
				end

				if bestScore == nil or score > bestScore then
					best, bestScore = enemy, score
				end
			end
		end
	end

	return best
end

local function spawnTracer(from: Vector3, to: Vector3, color: Color3, thickness: number)
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color
	tracer.Size = Vector3.new(thickness, thickness, distance)
	tracer.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
	tracer.Transparency = 0.15
	tracer.Parent = Workspace
	Debris:AddItem(tracer, 0.09)
end

local function fire(tower: Tower, enemy: any, levelData: any)
	local data = TowerData.Get(tower.TowerId) :: any

	-- Face the target. Only the head turns, so the base stays planted.
	local headPosition = tower.Head.Position
	local targetPosition = enemy.Root.Position
	local flatTarget = Vector3.new(targetPosition.X, headPosition.Y, targetPosition.Z)
	if (flatTarget - headPosition).Magnitude > 0.1 then
		tower.Head.CFrame = CFrame.lookAt(headPosition, flatTarget)
	end

	spawnTracer(headPosition, targetPosition, data.ProjectileColor, if tower.TowerId == "Cryo" then 0.5 else 0.3)

	EnemyManager.Damage(enemy, levelData.Damage, tower.TowerId)

	if levelData.Slow and levelData.SlowDuration then
		EnemyManager.ApplySlow(enemy, 1 - levelData.Slow, levelData.SlowDuration)
	end
end

local accumulator = 0
local TICK = 0.05 -- 20Hz is finer than the fastest cooldown; per-frame is waste
local firingConnection: RBXScriptConnection?

function TowerManager.Start()
	if firingConnection then
		return
	end
	firingConnection = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		accumulator = 0

		local now = os.clock()
		for _, tower in pairs(towers) do
			local levelData = TowerData.GetLevel(tower.TowerId, tower.Level)
			if levelData and now - tower.LastFire >= levelData.Cooldown then
				local target = selectTarget(tower, levelData.Range)
				if target then
					tower.LastFire = now
					fire(tower, target, levelData)
				end
			end
		end
	end)
end

function TowerManager.Stop()
	if firingConnection then
		firingConnection:Disconnect()
		firingConnection = nil
	end
end

return TowerManager
