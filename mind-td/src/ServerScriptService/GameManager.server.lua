--[[
	GameManager
	Boots the server and owns the game state machine. Every state transition
	happens here — no other script decides what state the game is in, they only
	react to being told (brief section 29).

	This is also the only place client requests are accepted, so all of the
	"never trust the client" validation sits behind one door: the handlers
	below check nothing themselves beyond argument types, and delegate the real
	decisions to TowerManager/EconomyManager, which re-derive costs and
	legality from the shared data tables.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MapData = require(ReplicatedStorage.Shared.MapData)
local WaveData = require(ReplicatedStorage.Shared.WaveData)
local EnemyData = require(ReplicatedStorage.Shared.EnemyData)

local MapBuilder = require(script.Parent.MapBuilder)
local EconomyManager = require(script.Parent.EconomyManager)
local EnemyManager = require(script.Parent.EnemyManager)
local TowerManager = require(script.Parent.TowerManager)
local WaveManager = require(script.Parent.WaveManager)
local AdaptiveAI = require(script.Parent.AdaptiveAI)
local BossController = require(script.Parent.BossController)
local DataManager = require(script.Parent.DataManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaceTower = Remotes:WaitForChild("PlaceTower")
local SellTower = Remotes:WaitForChild("SellTower")
local UpgradeTower = Remotes:WaitForChild("UpgradeTower")
local ChangeTargetMode = Remotes:WaitForChild("ChangeTargetMode")
local StartWave = Remotes:WaitForChild("StartWave")
local GameEvent = Remotes:WaitForChild("GameEvent")
local RequestSnapshot = Remotes:WaitForChild("RequestSnapshot")

--============================================================
-- State
--============================================================

local MAX_CORE_HP = 1000

local state = {
	Name = "Lobby", -- Lobby | Preparing | WaveActive | Boss | Victory | Defeat | Intermission
	Wave = 0,
	CoreHP = MAX_CORE_HP,
	PrepEndsAt = 0,
}

local map: Model
local coreModel: Model
local runToken = 0 -- invalidates timers belonging to an abandoned run

-- Forward declarations: the transition functions call each other and are
-- reached from the damage/enemy handlers defined above them.
local setState, beginPreparing, beginWave, finishRun, startRun

local function broadcastState()
	GameEvent:FireAllClients({
		Type = "StateChanged",
		State = state.Name,
		Wave = state.Wave,
		TotalWaves = WaveData.TotalWaves,
		CoreHP = state.CoreHP,
		MaxCoreHP = MAX_CORE_HP,
		PrepRemaining = math.max(0, state.PrepEndsAt - os.clock()),
		WaveInfo = WaveManager.GetWaveInfo(math.min(state.Wave + 1, WaveData.TotalWaves)),
		EnemiesAlive = EnemyManager.Count(),
	})
end

--============================================================
-- Core presentation
--============================================================

local corePulse: Tween?

-- The Core is the health bar, so its behaviour has to read from across the
-- map: as it drops it reddens, brightens and pulses faster.
local function refreshCoreVisuals()
	if not coreModel or not coreModel.PrimaryPart then
		return
	end
	local shell = coreModel.PrimaryPart
	local inner = coreModel:FindFirstChild("Inner") :: BasePart?
	local light = shell:FindFirstChild("CoreLight") :: PointLight?
	local billboard = shell:FindFirstChild("CoreHP") :: BillboardGui?

	local ratio = math.clamp(state.CoreHP / MAX_CORE_HP, 0, 1)

	local color
	if ratio > 0.6 then
		color = MapData.Colors.CoreGlow
	elseif ratio > 0.3 then
		color = Color3.fromRGB(255, 190, 90)
	else
		color = Color3.fromRGB(255, 80, 80)
	end

	shell.Color = color
	if light then
		light.Color = color
		light.Brightness = 2 + (1 - ratio) * 4
	end

	if billboard then
		local value = billboard:FindFirstChild("Value") :: TextLabel?
		if value then
			value.Text = string.format("%d / %d", math.max(0, math.floor(state.CoreHP)), MAX_CORE_HP)
			value.TextColor3 = color
		end
		local track = billboard:FindFirstChild("BarTrack")
		local fill = track and track:FindFirstChild("BarFill") :: Frame?
		if fill then
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = color
		end
	end

	-- Re-time the pulse rather than stacking tweens.
	if corePulse then
		corePulse:Cancel()
	end
	if inner then
		local period = 0.35 + ratio * 1.15 -- healthy = slow, critical = frantic
		corePulse = TweenService:Create(
			inner,
			TweenInfo.new(period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Size = Vector3.new(10, 10, 10) }
		)
		if corePulse then
			corePulse:Play()
		end
	end
end

local function damageCore(amount: number)
	if state.Name == "Victory" or state.Name == "Defeat" then
		return
	end

	state.CoreHP = math.max(0, state.CoreHP - amount)
	refreshCoreVisuals()

	GameEvent:FireAllClients({
		Type = "CoreUpdate",
		CoreHP = state.CoreHP,
		MaxCoreHP = MAX_CORE_HP,
		Critical = state.CoreHP <= MAX_CORE_HP * 0.3,
	})

	if state.CoreHP <= 0 then
		finishRun(false)
	end
end

--============================================================
-- State transitions
--============================================================

function setState(name: string)
	state.Name = name
	broadcastState()
end

function beginPreparing(waveNumber: number)
	local token = runToken
	local info = WaveManager.GetWaveInfo(waveNumber)
	if not info then
		return
	end

	state.Wave = waveNumber - 1
	state.PrepEndsAt = os.clock() + info.PrepTime
	setState("Preparing")

	GameEvent:FireAllClients({
		Type = "WavePreparing",
		WaveInfo = info,
		PrepTime = info.PrepTime,
	})

	task.spawn(function()
		while token == runToken and state.Name == "Preparing" and os.clock() < state.PrepEndsAt do
			task.wait(1)
			broadcastState()
		end
		-- A player may have started the wave early, or the run may have been
		-- reset; only auto-start if we're still the ones waiting.
		if token == runToken and state.Name == "Preparing" then
			beginWave(waveNumber)
		end
	end)
end

function beginWave(waveNumber: number)
	local info = WaveManager.GetWaveInfo(waveNumber)
	if not info then
		return
	end

	state.Wave = waveNumber
	setState(if info.IsBossWave then "Boss" else "WaveActive")

	GameEvent:FireAllClients({
		Type = "WaveStarted",
		WaveInfo = info,
	})

	WaveManager.StartWave(waveNumber)
end

function finishRun(victory: boolean)
	local reachedWave = state.Wave
	setState(if victory then "Victory" else "Defeat")

	EnemyManager.ClearAll()
	BossController.ClearAll()
	WaveManager.Reset()
	DataManager.RecordRun(reachedWave, victory)

	GameEvent:FireAllClients({
		Type = "RunEnded",
		Victory = victory,
		Wave = reachedWave,
		TotalWaves = WaveData.TotalWaves,
		Report = AdaptiveAI.GetReport(),
	})

	-- Reset into a fresh run so a lobby is never left stranded on an end
	-- screen with nothing to do.
	task.delay(20, function()
		startRun()
	end)
end

function startRun()
	runToken += 1

	TowerManager.ClearAll()
	EnemyManager.ClearAll()
	BossController.ClearAll()
	WaveManager.Reset()
	AdaptiveAI.Reset()
	EconomyManager.ResetAll()

	state.CoreHP = MAX_CORE_HP
	state.Wave = 0
	refreshCoreVisuals()

	if #Players:GetPlayers() == 0 then
		setState("Lobby")
		return
	end

	beginPreparing(1)
end

--============================================================
-- Enemy outcomes
--============================================================

EnemyManager.OnEnemyKilled = function(enemy)
	local data = EnemyData.Get(enemy.EnemyId)
	if data then
		-- Shared income: the defence is a team effort, so kills pay everyone
		-- rather than whoever happened to land the shot.
		EconomyManager.AwardAll(data.Reward)
	end

	if enemy.IsBoss then
		BossController.OnBossDefeated(enemy)
	end

	WaveManager.NotifyEnemyRemoved()
end

EnemyManager.OnEnemyLeaked = function(enemy)
	local data = EnemyData.Get(enemy.EnemyId)
	damageCore(if data then data.CoreDamage else 5)

	GameEvent:FireAllClients({
		Type = "Leak",
		EnemyId = enemy.EnemyId,
		Route = enemy.Route,
	})

	WaveManager.NotifyEnemyRemoved()
end

WaveManager.OnWaveCleared = function(waveNumber)
	local info = WaveManager.GetWaveInfo(waveNumber)
	if info then
		EconomyManager.AwardAll(info.Reward)
	end

	GameEvent:FireAllClients({
		Type = "WaveCleared",
		Wave = waveNumber,
		Reward = info and info.Reward or 0,
	})

	if waveNumber >= WaveData.TotalWaves then
		finishRun(true)
	else
		task.delay(2, function()
			if state.Name == "WaveActive" or state.Name == "Boss" then
				beginPreparing(waveNumber + 1)
			end
		end)
	end
end

--============================================================
-- Client requests — the only entry points, all re-validated
--============================================================

PlaceTower.OnServerEvent:Connect(function(player, towerId, spotId)
	if type(towerId) ~= "string" or type(spotId) ~= "number" then
		return
	end
	local success, message = TowerManager.PlaceTower(player, towerId, spotId)
	GameEvent:FireClient(player, { Type = "ActionResult", Success = success, Message = message })
end)

UpgradeTower.OnServerEvent:Connect(function(player, towerRuntimeId)
	if type(towerRuntimeId) ~= "number" then
		return
	end
	local success, message = TowerManager.UpgradeTower(player, towerRuntimeId)
	GameEvent:FireClient(player, { Type = "ActionResult", Success = success, Message = message })
end)

SellTower.OnServerEvent:Connect(function(player, towerRuntimeId)
	if type(towerRuntimeId) ~= "number" then
		return
	end
	local success, message = TowerManager.SellTower(player, towerRuntimeId)
	GameEvent:FireClient(player, { Type = "ActionResult", Success = success, Message = message })
end)

ChangeTargetMode.OnServerEvent:Connect(function(player, towerRuntimeId, mode)
	if type(towerRuntimeId) ~= "number" or type(mode) ~= "string" then
		return
	end
	local success, message = TowerManager.ChangeTargetMode(player, towerRuntimeId, mode)
	GameEvent:FireClient(player, { Type = "ActionResult", Success = success, Message = message })
end)

-- Players may skip the remaining prep time once they're ready.
StartWave.OnServerEvent:Connect(function(_player)
	if state.Name ~= "Preparing" then
		return
	end
	beginWave(state.Wave + 1)
end)

RequestSnapshot.OnServerInvoke = function(player)
	return {
		State = state.Name,
		Wave = state.Wave,
		TotalWaves = WaveData.TotalWaves,
		CoreHP = state.CoreHP,
		MaxCoreHP = MAX_CORE_HP,
		PrepRemaining = math.max(0, state.PrepEndsAt - os.clock()),
		Money = EconomyManager.Get(player),
		Towers = TowerManager.GetSnapshot(),
		AI = AdaptiveAI.GetSnapshot(),
		WaveInfo = WaveManager.GetWaveInfo(math.min(state.Wave + 1, WaveData.TotalWaves)),
	}
end

--============================================================
-- Players
--============================================================

Players.PlayerAdded:Connect(function(player)
	DataManager.Load(player)
	EconomyManager.Register(player)

	-- First player through the door starts the run.
	if state.Name == "Lobby" then
		task.wait(2)
		startRun()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	DataManager.Release(player)
	EconomyManager.Unregister(player)
end)

--============================================================
-- Boot
--============================================================

-- Players never need a character in a tower defence game; the camera is
-- scripted and everything is driven through UI. Not spawning one avoids an
-- avatar wandering around the map and falling off the road.
Players.CharacterAutoLoads = false

Lighting.Ambient = Color3.fromRGB(24, 26, 34)
Lighting.OutdoorAmbient = Color3.fromRGB(20, 22, 30)
Lighting.Brightness = 1.2
Lighting.ClockTime = 1
Lighting.FogColor = Color3.fromRGB(14, 18, 26)
Lighting.FogStart = 120
Lighting.FogEnd = 520
Lighting.GlobalShadows = true

if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Color = Color3.fromRGB(40, 50, 70)
	atmosphere.Decay = Color3.fromRGB(30, 40, 60)
	atmosphere.Haze = 1.4
	atmosphere.Glare = 0.15
	atmosphere.Parent = Lighting
end

if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Threshold = 1.5
	bloom.Size = 24
	bloom.Parent = Lighting
end

WaveManager.Validate()

map = MapBuilder.Build()
MapBuilder.AddSignage(map)
coreModel = map:WaitForChild("Core") :: Model
refreshCoreVisuals()

EnemyManager.Start()
TowerManager.Start()

-- Players who were already in the server when this script finished booting
-- (Studio solo play always hits this) still need registering.
for _, player in ipairs(Players:GetPlayers()) do
	DataManager.Load(player)
	EconomyManager.Register(player)
end

setState("Lobby")
if #Players:GetPlayers() > 0 then
	task.wait(2)
	startRun()
end

print("[MIND TD] NEURAL OUTPOST online — " .. WaveData.TotalWaves .. " waves loaded")
