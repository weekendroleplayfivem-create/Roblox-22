--[[
	AdaptiveAI
	The system the whole game is named after (brief sections 15-19).

	How it works, in one paragraph: every meaningful player action (placing,
	upgrading, selling a tower, changing a target mode, dealing damage) updates
	a small behaviour ledger. That ledger is condensed into a handful of ratios
	— how lopsided the defence is, how much of it slows, how much of it is
	long-range, how much damage comes from chip fire. Thresholds in AIData turn
	those ratios into a named strategy, and the strategy decides which units
	the Adaptive wave slots spawn and which branch of the fork they walk.

	Two deliberate constraints, because "the enemy learns" stops being fun the
	moment it becomes "the enemy cheats":

	  * Stat changes are tiny and always routed through AIData.ClampModifier,
	    and are additionally scaled by how confident the read is. The AI wins by
	    sending the RIGHT unit down the RIGHT lane, not by inflating numbers.
	  * Every read is derived from things the player did in the open. Nothing
	    here inspects hidden state, and the AI gets no information the player
	    couldn't work out themselves by looking at their own board.

	Two separate numbers matter and are easy to confuse:
	  AdaptationScore — how confident the ENEMY is in its read of you.
	  AnalysisRate    — how much of that the PLAYER can see, raised by
	                    building Analyzer towers. Intel is something you buy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AIData = require(ReplicatedStorage.Shared.AIData)
local TowerData = require(ReplicatedStorage.Shared.TowerData)
local Utility = require(ReplicatedStorage.Shared.Utility)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")

local AdaptiveAI = {}

--============================================================
-- Behaviour ledger
--============================================================

local function freshLedger()
	return {
		TowersBySide = { Left = 0, Right = 0, Center = 0 },
		-- Investment-weighted, so a triple-upgraded tower counts for more than
		-- a fresh one. Counting bare placements would read a wall of level-1
		-- Guardians as "strong" when it isn't.
		ValueBySide = { Left = 0, Right = 0, Center = 0 },
		TowersByType = {},
		ValueByType = {},
		UpgradeCount = 0,
		TargetModeCount = {},
		DamageByType = {},
		KillsByEnemy = {},
		TotalRange = 0,
		TowerCount = 0,
		AnalysisBonus = 0,
		LeaksThisRun = 0,
	}
end

local ledger = freshLedger()

local state = {
	Strategy = AIData.DefaultStrategy,
	AdaptationScore = 0,
	AnalysisRate = AIData.BaseAnalysisRate,
	WeakSide = "UNKNOWN",
	StrategyData = {
		LeftUsage = 0.5,
		RightUsage = 0.5,
		SlowUsage = 0,
		LongRangeUsage = 0,
		ChipUsage = 0,
		PreferredTargetMode = "First",
	},
	WavesElapsed = 0,
	LastChangedWave = 0,
}

--============================================================
-- Analysis
--============================================================

local function dominantKey(map: { [string]: number }): (string?, number)
	local bestKey, bestValue = nil, 0
	for key, value in pairs(map) do
		if value > bestValue then
			bestKey, bestValue = key, value
		end
	end
	return bestKey, bestValue
end

-- Average range across all tower types, used as the "is this a long-range
-- defence" reference point so the check adapts if towers are rebalanced.
local averageTowerRange = (function()
	local total, count = 0, 0
	for _, tower in pairs(TowerData.Towers) do
		total += tower.Levels[1].Range
		count += 1
	end
	return Utility.SafeDivide(total, count, 28)
end)()

local function recomputeStrategyData()
	local data = state.StrategyData

	local sideTotal = ledger.ValueBySide.Left + ledger.ValueBySide.Right
	if sideTotal > 0 then
		data.LeftUsage = ledger.ValueBySide.Left / sideTotal
		data.RightUsage = ledger.ValueBySide.Right / sideTotal
	else
		data.LeftUsage, data.RightUsage = 0.5, 0.5
	end

	local totalValue = 0
	for _, value in pairs(ledger.ValueByType) do
		totalValue += value
	end

	-- Slow usage: share of defensive investment that applies a slow at all.
	local slowValue = 0
	local longRangeValue = 0
	for towerId, value in pairs(ledger.ValueByType) do
		local tower = TowerData.Get(towerId)
		if tower then
			if tower.Levels[1].Slow then
				slowValue += value
			end
			if tower.Levels[1].Range > averageTowerRange then
				longRangeValue += value
			end
		end
	end

	data.SlowUsage = Utility.SafeDivide(slowValue, totalValue, 0)
	data.LongRangeUsage = Utility.SafeDivide(longRangeValue, totalValue, 0)

	-- Chip usage: share of damage dealt by low-per-hit, fast-firing towers.
	local totalDamage, chipDamage = 0, 0
	for towerId, amount in pairs(ledger.DamageByType) do
		totalDamage += amount
		local tower = TowerData.Get(towerId)
		if tower and tower.Levels[1].Damage <= 15 then
			chipDamage += amount
		end
	end
	data.ChipUsage = Utility.SafeDivide(chipDamage, totalDamage, 0)

	local mode = dominantKey(ledger.TargetModeCount)
	data.PreferredTargetMode = mode or "First"

	state.WeakSide = if data.LeftUsage < data.RightUsage then "LEFT" else "RIGHT"
	if math.abs(data.LeftUsage - data.RightUsage) < 0.08 then
		state.WeakSide = "EVEN"
	end
end

-- How strongly the current behaviour deviates from "no pattern at all". This
-- is the enemy's confidence, and it scales every adaptation it makes.
local function computeAdaptationScore(): number
	local data = state.StrategyData

	local sideSkew = math.abs(data.LeftUsage - 0.5) * 2 -- 0 = even, 1 = all one side
	local slowSkew = data.SlowUsage
	local rangeSkew = data.LongRangeUsage
	local chipSkew = data.ChipUsage

	local strongest = math.max(sideSkew, slowSkew, rangeSkew, chipSkew)

	-- Confidence also builds with time: a pattern held for ten waves is a
	-- habit, the same pattern on wave two is a coincidence.
	local experience = math.clamp(state.WavesElapsed / 12, 0, 1)

	return math.clamp(strongest * 0.7 + experience * 0.3, 0, 1)
end

local function chooseStrategy(): string
	local data = state.StrategyData
	local thresholds = AIData.Thresholds

	-- Deliberate unpredictability: occasionally the enemy commits to something
	-- other than its best read, so a player can never fully solve it.
	if math.random() < AIData.UnpredictabilityChance then
		local options = { "Balanced", "Rush", "Overwhelm", "Siege" }
		return options[math.random(1, #options)]
	end

	-- Ordered by how exploitable each pattern is.
	if data.RightUsage >= thresholds.SideImbalance then
		return "AttackLeft" -- defence is right-heavy, so attack the left
	elseif data.LeftUsage >= thresholds.SideImbalance then
		return "AttackRight"
	elseif data.SlowUsage >= thresholds.SlowUsage then
		return "AntiSlow"
	elseif data.ChipUsage >= thresholds.ChipDamage then
		return "AntiChip"
	elseif data.LongRangeUsage >= thresholds.LongRangeUsage then
		return "AntiLongRange"
	end

	-- No single exploitable read: fall back on overall defensive density.
	if ledger.TowerCount <= 3 and state.WavesElapsed >= 4 then
		return "Rush"
	elseif ledger.TowerCount >= 12 then
		return "Siege"
	end

	return "Balanced"
end

local function broadcast()
	GameEvent:FireAllClients({
		Type = "AIUpdate",
		Snapshot = AdaptiveAI.GetSnapshot(),
	})
end

-- Full re-analysis. Cheap (a few dozen table reads), but still only run on
-- meaningful events and on a slow timer rather than per frame.
function AdaptiveAI.Analyse()
	recomputeStrategyData()
	state.AdaptationScore = computeAdaptationScore()
	state.AnalysisRate = math.min(AIData.BaseAnalysisRate + ledger.AnalysisBonus, AIData.MaxAnalysisRate)

	local chosen = chooseStrategy()
	if chosen ~= state.Strategy then
		state.Strategy = chosen
		state.LastChangedWave = state.WavesElapsed
	end

	broadcast()
end

--============================================================
-- Event hooks (called by TowerManager / EnemyManager / WaveManager)
--============================================================

function AdaptiveAI.OnTowerPlaced(towerId: string, side: string, level: number)
	local tower = TowerData.Get(towerId)
	if not tower then
		return
	end
	local value = TowerData.TotalInvested(towerId, level)

	ledger.TowersBySide[side] = (ledger.TowersBySide[side] or 0) + 1
	ledger.ValueBySide[side] = (ledger.ValueBySide[side] or 0) + value
	ledger.TowersByType[towerId] = (ledger.TowersByType[towerId] or 0) + 1
	ledger.ValueByType[towerId] = (ledger.ValueByType[towerId] or 0) + value
	ledger.TotalRange += tower.Levels[level].Range
	ledger.TowerCount += 1

	local bonus = tower.Levels[level].AnalysisBonus
	if bonus then
		ledger.AnalysisBonus += bonus
	end

	AdaptiveAI.Analyse()
end

function AdaptiveAI.OnTowerUpgraded(towerId: string, side: string, newLevel: number)
	local tower = TowerData.Get(towerId)
	if not tower then
		return
	end
	local delta = tower.Levels[newLevel].Cost

	ledger.ValueBySide[side] = (ledger.ValueBySide[side] or 0) + delta
	ledger.ValueByType[towerId] = (ledger.ValueByType[towerId] or 0) + delta
	ledger.UpgradeCount += 1

	-- Analyzer intel scales with level: replace the previous tier's bonus.
	local previousBonus = tower.Levels[newLevel - 1] and tower.Levels[newLevel - 1].AnalysisBonus
	local newBonus = tower.Levels[newLevel].AnalysisBonus
	if newBonus then
		ledger.AnalysisBonus += newBonus - (previousBonus or 0)
	end

	AdaptiveAI.Analyse()
end

function AdaptiveAI.OnTowerSold(towerId: string, side: string, level: number)
	local tower = TowerData.Get(towerId)
	if not tower then
		return
	end
	local value = TowerData.TotalInvested(towerId, level)

	ledger.TowersBySide[side] = math.max(0, (ledger.TowersBySide[side] or 0) - 1)
	ledger.ValueBySide[side] = math.max(0, (ledger.ValueBySide[side] or 0) - value)
	ledger.TowersByType[towerId] = math.max(0, (ledger.TowersByType[towerId] or 0) - 1)
	ledger.ValueByType[towerId] = math.max(0, (ledger.ValueByType[towerId] or 0) - value)
	ledger.TotalRange = math.max(0, ledger.TotalRange - tower.Levels[level].Range)
	ledger.TowerCount = math.max(0, ledger.TowerCount - 1)

	local bonus = tower.Levels[level].AnalysisBonus
	if bonus then
		ledger.AnalysisBonus = math.max(0, ledger.AnalysisBonus - bonus)
	end

	AdaptiveAI.Analyse()
end

function AdaptiveAI.OnTargetModeChanged(mode: string)
	ledger.TargetModeCount[mode] = (ledger.TargetModeCount[mode] or 0) + 1
end

-- Hot path: called on every tower shot, so it only accumulates. The ratios
-- built from it are recomputed on the slow timer instead.
function AdaptiveAI.OnDamageDealt(towerId: string, amount: number)
	ledger.DamageByType[towerId] = (ledger.DamageByType[towerId] or 0) + amount
end

function AdaptiveAI.OnEnemyKilled(enemyId: string)
	ledger.KillsByEnemy[enemyId] = (ledger.KillsByEnemy[enemyId] or 0) + 1
end

function AdaptiveAI.OnEnemyLeaked()
	ledger.LeaksThisRun += 1
end

function AdaptiveAI.OnWaveCompleted(waveNumber: number)
	state.WavesElapsed = waveNumber
	AdaptiveAI.Analyse()
end

--============================================================
-- Queries used by the spawner
--============================================================

function AdaptiveAI.GetStrategy(): string
	return state.Strategy
end

function AdaptiveAI.GetStrategyDefinition()
	return AIData.GetStrategy(state.Strategy)
end

function AdaptiveAI.GetAdaptationScore(): number
	return state.AdaptationScore
end

-- Which unit an Adaptive wave slot spawns. This is the main lever the AI
-- pulls: send the unit that answers what the player actually built.
function AdaptiveAI.GetCounterUnit(): string
	return AdaptiveAI.GetStrategyDefinition().CounterUnit
end

-- Which branch of the fork an enemy walks. At zero confidence this is a coin
-- flip; at full confidence it still leaves a fifth of units on the other lane
-- so the defended side never becomes completely safe to ignore.
function AdaptiveAI.ChooseRoute(): string
	local strategy = AdaptiveAI.GetStrategyDefinition()
	if not strategy.RouteBias then
		return if math.random() < 0.5 then "Left" else "Right"
	end
	local chance = Utility.Lerp(0.5, strategy.RouteBiasStrength, state.AdaptationScore)
	if math.random() < chance then
		return strategy.RouteBias
	end
	return if strategy.RouteBias == "Left" then "Right" else "Left"
end

-- Stat multipliers, scaled by confidence and hard-clamped. A fully-confident
-- AI still only moves a stat by AIData.MaxStatAdaptation at the very most.
function AdaptiveAI.GetModifiers(): { Speed: number, Health: number }
	local strategy = AdaptiveAI.GetStrategyDefinition()
	local score = state.AdaptationScore

	local speed = 1 + (strategy.SpeedModifier - 1) * score
	local health = 1 + (strategy.HealthModifier - 1) * score

	return {
		Speed = AIData.ClampModifier(speed),
		Health = AIData.ClampModifier(health),
	}
end

--============================================================
-- Presentation
--============================================================

-- What the client is allowed to render. Fields the player hasn't paid for
-- with Analyzer coverage come back redacted rather than simply missing, so
-- the UI can show that there IS something there it can't read yet.
function AdaptiveAI.GetSnapshot()
	local rate = state.AnalysisRate
	local strategy = AdaptiveAI.GetStrategyDefinition()
	local redacted = "▓▓▓▓▓▓"

	return {
		AnalysisRate = rate,
		Adaptation = state.AdaptationScore,
		-- Tiered reveal: more Analyzer coverage unlocks more of the readout.
		StrategyName = if rate >= 0.5 then strategy.DisplayName else redacted,
		Reasoning = if rate >= 0.75 then strategy.Reasoning else redacted,
		WeakSide = if rate >= 0.35 then state.WeakSide else redacted,
		CounterUnit = if rate >= 0.6 then strategy.CounterUnit else redacted,
		LeftUsage = state.StrategyData.LeftUsage,
		RightUsage = state.StrategyData.RightUsage,
		SlowUsage = state.StrategyData.SlowUsage,
		FullyRevealed = rate >= 0.75,
	}
end

-- End-of-run report. This one is never redacted: the run is over, and the
-- point of the screen is to show the player the pattern they didn't know
-- they had.
function AdaptiveAI.GetReport()
	recomputeStrategyData()
	local mostUsedTower = dominantKey(ledger.ValueByType) or "NONE"
	local strategy = AdaptiveAI.GetStrategyDefinition()
	local data = state.StrategyData

	local defenceShape
	if data.RightUsage >= 0.65 then
		defenceShape = "Heavy Right-Side Defence"
	elseif data.LeftUsage >= 0.65 then
		defenceShape = "Heavy Left-Side Defence"
	elseif ledger.TowerCount >= 12 then
		defenceShape = "Dense Layered Defence"
	elseif ledger.TowerCount <= 4 then
		defenceShape = "Minimal Defence"
	else
		defenceShape = "Balanced Defence"
	end

	local adaptationLabel
	if state.AdaptationScore >= 0.66 then
		adaptationLabel = "HIGH"
	elseif state.AdaptationScore >= 0.33 then
		adaptationLabel = "MODERATE"
	else
		adaptationLabel = "LOW"
	end

	return {
		DetectedStrategy = defenceShape,
		MostUsedTower = (TowerData.Get(mostUsedTower) and TowerData.Get(mostUsedTower).DisplayName or "NONE"):upper(),
		SlowUsage = data.SlowUsage,
		LongRangeUsage = data.LongRangeUsage,
		Adaptation = state.AdaptationScore,
		AdaptationLabel = adaptationLabel,
		WeakSide = state.WeakSide,
		CounterStrategy = strategy.DisplayName,
		CounterUnit = strategy.CounterUnit,
		TowersBuilt = ledger.TowerCount,
		Upgrades = ledger.UpgradeCount,
		Leaks = ledger.LeaksThisRun,
	}
end

function AdaptiveAI.GetDebugInfo()
	return {
		Strategy = state.Strategy,
		Adaptation = state.AdaptationScore,
		AnalysisRate = state.AnalysisRate,
		WeakSide = state.WeakSide,
		LeftUsage = state.StrategyData.LeftUsage,
		RightUsage = state.StrategyData.RightUsage,
		SlowUsage = state.StrategyData.SlowUsage,
		LongRangeUsage = state.StrategyData.LongRangeUsage,
		ChipUsage = state.StrategyData.ChipUsage,
		TowerCount = ledger.TowerCount,
	}
end

function AdaptiveAI.Reset()
	ledger = freshLedger()
	state.Strategy = AIData.DefaultStrategy
	state.AdaptationScore = 0
	state.AnalysisRate = AIData.BaseAnalysisRate
	state.WeakSide = "UNKNOWN"
	state.WavesElapsed = 0
	state.LastChangedWave = 0
	AdaptiveAI.Analyse()
end

-- Slow background pass. Event hooks do the reactive work; this only exists so
-- time-based confidence keeps creeping up during a long wave.
task.spawn(function()
	while true do
		task.wait(AIData.AnalysisInterval)
		AdaptiveAI.Analyse()
	end
end)

return AdaptiveAI
