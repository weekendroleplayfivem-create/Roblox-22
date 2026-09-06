--[[
	UIController
	The single subscriber to the GameEvent remote.

	Everything the server sends lands here, gets written into ClientState, and
	is re-broadcast as a local signal. The UI scripts then only ever read
	ClientState and listen to signals — so there is exactly one place that
	knows the wire format, and adding a screen never means adding another
	remote subscription that could disagree with the others.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")
local RequestSnapshot = Remotes:WaitForChild("RequestSnapshot")

local Signals = ClientState.Signals

--============================================================
-- Tower mirror
--============================================================

-- Keyed by SpotId: a click on the map resolves to a pad, and the pad is how
-- the player refers to a tower. ClientState.GetTowerByRuntimeId handles the
-- other direction.
local function indexTower(entry)
	ClientState.Towers[entry.SpotId] = entry
end

--============================================================
-- Event routing
--============================================================

local handlers: { [string]: (any) -> () } = {}

handlers.StateChanged = function(payload)
	local game = ClientState.Game
	game.State = payload.State
	game.Wave = payload.Wave
	game.TotalWaves = payload.TotalWaves or game.TotalWaves
	game.CoreHP = payload.CoreHP
	game.MaxCoreHP = payload.MaxCoreHP
	game.PrepRemaining = payload.PrepRemaining or 0
	game.EnemiesAlive = payload.EnemiesAlive or 0
	game.WaveInfo = payload.WaveInfo
	Signals.StateChanged:Fire(payload)
end

handlers.CoreUpdate = function(payload)
	ClientState.Game.CoreHP = payload.CoreHP
	ClientState.Game.MaxCoreHP = payload.MaxCoreHP
	Signals.CoreUpdate:Fire(payload)
end

handlers.EconomyUpdate = function(payload)
	ClientState.Money = payload.Money
	Signals.EconomyUpdate:Fire(payload)
end

handlers.AIUpdate = function(payload)
	for key, value in pairs(payload.Snapshot) do
		ClientState.AI[key] = value
	end
	Signals.AIUpdate:Fire(ClientState.AI)
end

handlers.WavePreparing = function(payload)
	ClientState.Game.WaveInfo = payload.WaveInfo
	Signals.WavePreparing:Fire(payload)
end

handlers.WaveStarted = function(payload)
	Signals.WaveStarted:Fire(payload)
end

handlers.WaveCleared = function(payload)
	Signals.WaveCleared:Fire(payload)
end

handlers.RunEnded = function(payload)
	Signals.RunEnded:Fire(payload)
end

handlers.BossLine = function(payload)
	Signals.BossLine:Fire(payload.Text)
end

handlers.BossPhase = function(payload)
	Signals.BossPhase:Fire(payload.Phase)
end

handlers.ActionResult = function(payload)
	Signals.ActionResult:Fire(payload)
end

handlers.Leak = function(payload)
	Signals.Leak:Fire(payload)
end

handlers.TowerPlaced = function(payload)
	indexTower({
		TowerRuntimeId = payload.TowerRuntimeId,
		TowerId = payload.TowerId,
		SpotId = payload.SpotId,
		Level = payload.Level,
		TargetMode = "First",
		OwnerUserId = payload.OwnerUserId,
	})
	Signals.TowersChanged:Fire()
end

handlers.TowerUpgraded = function(payload)
	local tower = ClientState.GetTowerByRuntimeId(payload.TowerRuntimeId)
	if tower then
		tower.Level = payload.Level
	end
	Signals.TowersChanged:Fire()
end

handlers.TowerSold = function(payload)
	ClientState.Towers[payload.SpotId] = nil
	if ClientState.Selection.TowerRuntimeId == payload.TowerRuntimeId then
		ClientState.ClearSelection()
	end
	Signals.TowersChanged:Fire()
end

handlers.TowerTargetMode = function(payload)
	local tower = ClientState.GetTowerByRuntimeId(payload.TowerRuntimeId)
	if tower then
		tower.TargetMode = payload.Mode
	end
	Signals.TowersChanged:Fire()
end

GameEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.Type) ~= "string" then
		return
	end
	local handler = handlers[payload.Type]
	if handler then
		handler(payload)
	end
end)

--============================================================
-- Initial sync
--============================================================

-- Pull the current state once on join, so a player who arrives mid-wave sees
-- the real board instead of an empty HUD until the next broadcast.
task.spawn(function()
	local ok, snapshot = pcall(function()
		return RequestSnapshot:InvokeServer()
	end)
	if not ok or type(snapshot) ~= "table" then
		return
	end

	local game = ClientState.Game
	game.State = snapshot.State
	game.Wave = snapshot.Wave
	game.TotalWaves = snapshot.TotalWaves
	game.CoreHP = snapshot.CoreHP
	game.MaxCoreHP = snapshot.MaxCoreHP
	game.PrepRemaining = snapshot.PrepRemaining
	game.WaveInfo = snapshot.WaveInfo

	ClientState.Money = snapshot.Money or 0

	if snapshot.AI then
		for key, value in pairs(snapshot.AI) do
			ClientState.AI[key] = value
		end
	end

	for _, entry in ipairs(snapshot.Towers or {}) do
		indexTower(entry)
	end

	Signals.StateChanged:Fire(snapshot)
	Signals.EconomyUpdate:Fire({ Money = ClientState.Money })
	Signals.AIUpdate:Fire(ClientState.AI)
	Signals.TowersChanged:Fire()
end)
