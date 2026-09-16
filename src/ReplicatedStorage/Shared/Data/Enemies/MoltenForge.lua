--!strict
-- Molten Forge enemy roster. Aggressive and hazard-synergistic - archetypes are
-- built to be fought on and around collapsing floor / lava hazard tiles (see
-- Data/Biomes/MoltenForge.lua hazardDensity), rewarding players who use
-- knockback and positioning against the terrain itself.
local Types = require(script.Parent.Parent.Parent.Types)

local Enemies: { Types.EnemyArchetypeDef } = {
	{
		id = "SlagBrute",
		displayName = "Slag Brute",
		biomes = { "MoltenForge" },
		mechanicalHook = "Frontal armor plate halves incoming damage; its telegraphed overhead slam can be sidestepped into a hazard tile for bonus terrain damage.",
		flavorText = "Forge-slaves bound in cooling slag until the binding and the body became the same material.",
		baseHealth = 340,
		baseDamage = 34,
		moveSpeed = 11,
		aggroRadius = 20,
		attackRange = 8,
		states = { "Idle", "Alert", "Chase", "Attack", "Cooldown", "Stagger" },
		packBehavior = "Solo",
		resistances = { Physical = 0.6, Cold = 0.8, Fire = 0.2, Shock = 1.0, Blight = 1.0, True = 1.0 },
		lootTableId = "Molten_Tier3",
		tier = 3,
	},
	{
		id = "CinderWisp",
		displayName = "Cinder Wisp",
		biomes = { "MoltenForge" },
		mechanicalHook = "Fast aerial swarm-flier that drops a burning ember trail beneath standing players, forcing constant movement.",
		flavorText = "Sparks thrown from the forge that never quite went out - and never stopped being hungry.",
		baseHealth = 30,
		baseDamage = 6,
		moveSpeed = 22,
		aggroRadius = 24,
		attackRange = 3,
		states = { "Idle", "Alert", "Chase", "Attack" },
		packBehavior = "Swarm",
		resistances = { Physical = 1.0, Cold = 1.4, Fire = 0, Shock = 1.0, Blight = 1.0, True = 1.0 },
		lootTableId = "Molten_Tier3_Swarm",
		tier = 3,
	},
	{
		id = "ForgeboundSentinel",
		displayName = "Forgebound Sentinel",
		biomes = { "MoltenForge" },
		mechanicalHook = "Stationary turret-caster that locks onto a target and must be interrupted before it completes a room-wide molten barrage.",
		flavorText = "Welded to its post generations ago, still executing the last order it was ever given.",
		baseHealth = 180,
		baseDamage = 40,
		moveSpeed = 0,
		aggroRadius = 34,
		attackRange = 34,
		states = { "Idle", "Alert", "Casting", "Cooldown" },
		packBehavior = "Solo",
		resistances = { Physical = 0.5, Cold = 1.0, Fire = 0, Shock = 1.2, Blight = 1.0, True = 1.0 },
		lootTableId = "Molten_Tier3",
		tier = 3,
	},
}

return Enemies
