--!strict
--[[
	AIData
	Tuning for the adaptive enemy intelligence.

	Two rules govern everything in this file:

	1. The enemy may only react to things the player has actually DONE and
	   could see themselves — tower types, positions, upgrades, target modes.
	   It never reads hidden state and never gets free information.

	2. Every stat adjustment is bounded by MaxStatAdaptation. Adaptation
	   changes WHICH units arrive and WHERE they walk far more than it changes
	   how strong they are, because a counter you can see coming is fair and a
	   silent stat buff just feels like the game cheating.
]]

export type Strategy = {
	Id: string,
	DisplayName: string,
	Reasoning: string, -- shown to the player: why the enemy chose this
	CounterUnit: string, -- what an Adaptive wave slot spawns
	RouteBias: string?, -- "Left" | "Right" | nil (no preference)
	RouteBiasStrength: number, -- 0..1 chance of taking the biased route
	SpeedModifier: number,
	HealthModifier: number,
}

local AIData = {}

-- Hard ceiling on any stat change the AI is allowed to make. The brief's
-- 10-30% band; nothing in this file may exceed it.
AIData.MaxStatAdaptation = 0.30
AIData.MinStatAdaptation = 0.10

-- How confident a read has to be before the AI acts on it. Below this the
-- enemy stays Balanced rather than guessing.
AIData.Thresholds = {
	SideImbalance = 0.68, -- fraction of towers on one side
	SlowUsage = 0.55, -- fraction of towers that apply slow
	LongRangeUsage = 0.60, -- fraction of towers with above-average range
	ChipDamage = 0.60, -- fraction of damage from low-damage/fast towers
}

-- Chance the AI deliberately ignores its own read and picks something else,
-- so a player can never fully solve it. Keeps it feeling like an opponent
-- rather than a lookup table.
AIData.UnpredictabilityChance = 0.18

-- How often the analysis re-runs, in seconds. Event-driven updates handle
-- tower changes; this is just the slow background pass.
AIData.AnalysisInterval = 5

-- Base share of player behaviour the enemy can perceive without help, and the
-- ceiling once Analyzers are feeding it. The Analyzer tower is the player
-- CHOOSING to see more of what the enemy sees.
AIData.BaseAnalysisRate = 0.35
AIData.MaxAnalysisRate = 1.0

AIData.Strategies = {
	Balanced = {
		Id = "Balanced",
		DisplayName = "BALANCED",
		Reasoning = "No exploitable pattern yet.",
		CounterUnit = "Normal",
		RouteBias = nil,
		RouteBiasStrength = 0.5,
		SpeedModifier = 1.0,
		HealthModifier = 1.0,
	},

	AttackLeft = {
		Id = "AttackLeft",
		DisplayName = "FLANK LEFT",
		Reasoning = "Defence is concentrated on the right. Left approach is thin.",
		CounterUnit = "Flanker",
		RouteBias = "Left",
		RouteBiasStrength = 0.80,
		SpeedModifier = 1.0,
		HealthModifier = 1.0,
	},

	AttackRight = {
		Id = "AttackRight",
		DisplayName = "FLANK RIGHT",
		Reasoning = "Defence is concentrated on the left. Right approach is thin.",
		CounterUnit = "Flanker",
		RouteBias = "Right",
		RouteBiasStrength = 0.80,
		SpeedModifier = 1.0,
		HealthModifier = 1.0,
	},

	AntiSlow = {
		Id = "AntiSlow",
		DisplayName = "ANTI-SLOW",
		Reasoning = "Heavy reliance on slowing fields. Deploying hardened drives.",
		CounterUnit = "Sprinter",
		RouteBias = nil,
		RouteBiasStrength = 0.5,
		SpeedModifier = 1.15,
		HealthModifier = 1.0,
	},

	AntiLongRange = {
		Id = "AntiLongRange",
		DisplayName = "ANTI-RANGE",
		Reasoning = "Long-range emplacements detected. Closing distance faster.",
		CounterUnit = "Sprinter",
		RouteBias = nil,
		RouteBiasStrength = 0.5,
		SpeedModifier = 1.20,
		HealthModifier = 0.95,
	},

	AntiChip = {
		Id = "AntiChip",
		DisplayName = "ANTI-CHIP",
		Reasoning = "Sustained low-calibre fire detected. Rotating plated units forward.",
		CounterUnit = "ArmorUnit",
		RouteBias = nil,
		RouteBiasStrength = 0.5,
		SpeedModifier = 0.95,
		HealthModifier = 1.15,
	},

	Rush = {
		Id = "Rush",
		DisplayName = "RUSH",
		Reasoning = "Defence is thin overall. Pushing before it can be built.",
		CounterUnit = "Runner",
		RouteBias = nil,
		RouteBiasStrength = 0.5,
		SpeedModifier = 1.20,
		HealthModifier = 0.90,
	},

	Siege = {
		Id = "Siege",
		DisplayName = "SIEGE",
		Reasoning = "Defence is dense and layered. Committing heavier chassis.",
		CounterUnit = "ArmorUnit",
		RouteBias = nil,
		RouteBiasStrength = 0.5,
		SpeedModifier = 0.90,
		HealthModifier = 1.25,
	},

	Overwhelm = {
		Id = "Overwhelm",
		DisplayName = "OVERWHELM",
		Reasoning = "Firepower is concentrated. Spreading the approach.",
		CounterUnit = "Flanker",
		RouteBias = nil,
		RouteBiasStrength = 0.5,
		SpeedModifier = 1.10,
		HealthModifier = 1.10,
	},
} :: { [string]: Strategy }

AIData.DefaultStrategy = "Balanced"

-- THE LEARNER's lines, keyed by what it detected. Delivered on phase change.
AIData.BossLines = {
	Spawn = "I have been watching this entire time.",
	AntiSlow = "Adaptation detected: your fields no longer hold me.",
	AntiLongRange = "Adaptation detected: your range means nothing up close.",
	AntiChip = "Adaptation detected: your fire is insufficient.",
	AttackLeft = "Defensive imbalance detected. Your left is undefended.",
	AttackRight = "Defensive imbalance detected. Your right is undefended.",
	Balanced = "No pattern. Curious. I will make one.",
	PhaseTwo = "Recalculating.",
	PhaseThree = "I have learned enough.",
	Defeated = "Insufficient... data...",
}

-- Clamps any AI-authored multiplier into the fairness band. Every stat change
-- funnels through this — there is no other path to modifying enemy stats.
function AIData.ClampModifier(value: number): number
	local ceiling = 1 + AIData.MaxStatAdaptation
	local floor = 1 - AIData.MaxStatAdaptation
	return math.clamp(value, floor, ceiling)
end

function AIData.GetStrategy(id: string): Strategy
	return AIData.Strategies[id] or AIData.Strategies[AIData.DefaultStrategy]
end

return AIData
