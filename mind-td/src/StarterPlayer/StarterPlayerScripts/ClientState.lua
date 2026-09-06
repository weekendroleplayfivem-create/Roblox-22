--[[
	ClientState
	Shared client-side state and a small signal bus.

	UIController is the ONLY script that subscribes to the GameEvent remote.
	It writes what it receives into the fields here and fires the matching
	signal, so every UI script reads one consistent picture instead of each
	one racing to parse the same remote. Signals are BindableEvents created
	once (module results are cached per client), so any script can connect to
	them regardless of load order.
]]

local ClientState = {}

local function signal(): BindableEvent
	return Instance.new("BindableEvent")
end

ClientState.Signals = {
	StateChanged = signal(),
	CoreUpdate = signal(),
	AIUpdate = signal(),
	EconomyUpdate = signal(),
	WavePreparing = signal(),
	WaveStarted = signal(),
	WaveCleared = signal(),
	RunEnded = signal(),
	BossLine = signal(),
	BossPhase = signal(),
	ActionResult = signal(),
	Leak = signal(),
	TowersChanged = signal(),
	-- Client-local selection changes (shop pick / existing tower pick).
	SelectionChanged = signal(),
}

ClientState.Game = {
	State = "Lobby",
	Wave = 0,
	TotalWaves = 20,
	CoreHP = 1000,
	MaxCoreHP = 1000,
	PrepRemaining = 0,
	EnemiesAlive = 0,
	WaveInfo = nil,
}

ClientState.Money = 0

ClientState.AI = {
	AnalysisRate = 0.35,
	Adaptation = 0,
	StrategyName = "▓▓▓▓▓▓",
	Reasoning = "▓▓▓▓▓▓",
	WeakSide = "▓▓▓▓▓▓",
	CounterUnit = "▓▓▓▓▓▓",
	LeftUsage = 0.5,
	RightUsage = 0.5,
	SlowUsage = 0,
	FullyRevealed = false,
}

-- Towers currently on the board, mirrored from the server and keyed by SpotId
-- (that's what a click on the map gives you).
ClientState.Towers = {}

-- Lives here rather than in UIController so UI scripts can call it regardless
-- of which client script happened to load first.
function ClientState.GetTowerByRuntimeId(runtimeId: number)
	for _, tower in pairs(ClientState.Towers) do
		if tower.TowerRuntimeId == runtimeId then
			return tower
		end
	end
	return nil
end

ClientState.Selection = {
	ShopTowerId = nil :: string?, -- a tower type picked from the shop, ready to place
	TowerRuntimeId = nil :: number?, -- an existing tower selected for upgrade/sell
}

function ClientState.SelectShopTower(towerId: string?)
	ClientState.Selection.ShopTowerId = towerId
	if towerId then
		ClientState.Selection.TowerRuntimeId = nil
	end
	ClientState.Signals.SelectionChanged:Fire()
end

function ClientState.SelectPlacedTower(runtimeId: number?)
	ClientState.Selection.TowerRuntimeId = runtimeId
	if runtimeId then
		ClientState.Selection.ShopTowerId = nil
	end
	ClientState.Signals.SelectionChanged:Fire()
end

function ClientState.ClearSelection()
	ClientState.Selection.ShopTowerId = nil
	ClientState.Selection.TowerRuntimeId = nil
	ClientState.Signals.SelectionChanged:Fire()
end

return ClientState
