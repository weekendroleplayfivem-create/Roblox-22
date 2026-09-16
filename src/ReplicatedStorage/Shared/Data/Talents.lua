--!strict
-- Permanent talent tree, unlocked in the hub with meta-currency earned across
-- runs (see EconomyService/ProgressionService) - distinct from Relics.lua's
-- per-run picks. Talents are small, permanent stat/kit foundations; relics are
-- the big, run-defining swings on top of them. Tiered with prerequisites so
-- the tree reads as a real tree, not a flat shopping list.
local Types = require(script.Parent.Types)

local Talents: { [string]: Types.TalentNodeDef } = {
	-- Tier 1: foundation nodes, no prerequisites
	IronConditioning = {
		id = "IronConditioning",
		displayName = "Iron Conditioning",
		description = "+8% max health, permanently.",
		tier = 1,
		prerequisites = {},
		archetypeTag = nil,
		statModifiers = { MaxHealthPct = 0.08 },
	},
	QuickHands = {
		id = "QuickHands",
		displayName = "Quick Hands",
		description = "+6% attack speed with all weapon categories.",
		tier = 1,
		prerequisites = {},
		archetypeTag = nil,
		statModifiers = { AttackSpeedPct = 0.06 },
	},
	ScavengersEye = {
		id = "ScavengersEye",
		displayName = "Scavenger's Eye",
		description = "+10% chance for loot rolls to upgrade one rarity tier.",
		tier = 1,
		prerequisites = {},
		archetypeTag = nil,
		statModifiers = { LootUpgradeChance = 0.1 },
	},

	-- Tier 2: archetype-leaning nodes, one prerequisite each
	OpenWounds = {
		id = "OpenWounds",
		displayName = "Open Wounds",
		description = "Bleed stacks deal 15% more damage. Foundation node for a Bleed build.",
		tier = 2,
		prerequisites = { "QuickHands" },
		archetypeTag = "Bleed",
		statModifiers = { BleedDamagePct = 0.15 },
	},
	ColdBlooded = {
		id = "ColdBlooded",
		displayName = "Cold-Blooded",
		description = "Chill builds 20% faster toward its Stun threshold. Foundation node for a Kiter build.",
		tier = 2,
		prerequisites = { "IronConditioning" },
		archetypeTag = "Kiter",
		statModifiers = { ChillBuildRatePct = 0.2 },
	},
	Stoneguard = {
		id = "Stoneguard",
		displayName = "Stoneguard",
		description = "Blocking costs 25% less stamina. Foundation node for a Bulwark build.",
		tier = 2,
		prerequisites = { "IronConditioning" },
		archetypeTag = "Bulwark",
		statModifiers = { BlockStaminaCostPct = -0.25 },
	},
	Kindling = {
		id = "Kindling",
		displayName = "Kindling",
		description = "Burn duration extended by 25%. Foundation node for a Pyromancer build.",
		tier = 2,
		prerequisites = { "QuickHands" },
		archetypeTag = "Pyromancer",
		statModifiers = { BurnDurationPct = 0.25 },
	},

	-- Tier 3: deeper archetype investment, requires the tier-2 node in the same line
	ExsanguinatorsInstinct = {
		id = "ExsanguinatorsInstinct",
		displayName = "Exsanguinator's Instinct",
		description = "Killing a Bleeding enemy refunds 10% of your ability cooldowns.",
		tier = 3,
		prerequisites = { "OpenWounds" },
		archetypeTag = "Bleed",
		statModifiers = { OnBleedKill_CooldownRefundPct = 0.1 },
	},
	Permafrost = {
		id = "Permafrost",
		displayName = "Permafrost",
		description = "Fully Chilled (stunned) enemies take 20% more damage from all sources.",
		tier = 3,
		prerequisites = { "ColdBlooded" },
		archetypeTag = "Kiter",
		statModifiers = { DamageToStunnedPct = 0.2 },
	},
	Retribution = {
		id = "Retribution",
		displayName = "Retribution",
		description = "A perfectly-timed block reflects 30% of the blocked damage back at the attacker.",
		tier = 3,
		prerequisites = { "Stoneguard" },
		archetypeTag = "Bulwark",
		statModifiers = { PerfectBlockReflectPct = 0.3 },
	},
	Immolation = {
		id = "Immolation",
		displayName = "Immolation",
		description = "Burning enemies that die trigger a small explosion, spreading Burn to nearby enemies.",
		tier = 3,
		prerequisites = { "Kindling" },
		archetypeTag = "Pyromancer",
		statModifiers = { BurnDeathExplosionRadius = 8 },
	},

	-- Tier 4 capstone: one per line, expensive, meant to define a meta-build
	CrimsonHarvest = {
		id = "CrimsonHarvest",
		displayName = "Crimson Harvest",
		description = "Capstone: Bleed can now stack without limit, and each stack past 10 grants a small permanent-for-the-run damage buff.",
		tier = 4,
		prerequisites = { "ExsanguinatorsInstinct" },
		archetypeTag = "Bleed",
		statModifiers = { BleedMaxStacks = 999, BleedStackDamageBuffThreshold = 10 },
	},
}

return Talents
