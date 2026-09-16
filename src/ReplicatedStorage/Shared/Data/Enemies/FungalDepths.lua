--!strict
-- Fungal Depths enemy roster. Ambush and area-denial focused - this biome's
-- caves are carved by cellular automata (see DungeonGenerator) so sightlines
-- are short and irregular, and the roster is built around punishing players
-- who don't respect that (stealth ambush, forced-kite bombers, area denial).
local Types = require(script.Parent.Parent.Parent.Types)

local Enemies: { Types.EnemyArchetypeDef } = {
	{
		id = "SporeStalker",
		displayName = "Spore Stalker",
		biomes = { "FungalDepths" },
		mechanicalHook = "Camouflages against cave walls and is invisible until a puff of spores telegraphs its lunge 0.5s before impact.",
		flavorText = "It doesn't hunt by sight. By the time you smell the spores, it has already chosen its angle.",
		baseHealth = 95,
		baseDamage = 26,
		moveSpeed = 16,
		aggroRadius = 14, -- short, ambush-oriented
		attackRange = 6,
		states = { "Idle", "Alert", "Chase", "Attack", "Cooldown" },
		packBehavior = "Solo",
		resistances = { Physical = 1.0, Cold = 1.0, Fire = 1.3, Shock = 1.0, Blight = 0.4, True = 1.0 },
		lootTableId = "Fungal_Tier2",
		tier = 2,
	},
	{
		id = "BloatCyst",
		displayName = "Bloat Cyst",
		biomes = { "FungalDepths" },
		mechanicalHook = "Slow-moving suicide bomber that must be killed at range or kited - it detonates into a lingering poison cloud on death or contact.",
		flavorText = "A pale, distended sac that pulses toward warmth. It has one purpose and no self-preservation instinct to speak of.",
		baseHealth = 55,
		baseDamage = 0, -- damage comes entirely from the detonation, not a direct attack
		moveSpeed = 6,
		aggroRadius = 20,
		attackRange = 5,
		states = { "Idle", "Alert", "Chase", "Attack" },
		packBehavior = "Pack",
		resistances = { Physical = 1.0, Cold = 1.0, Fire = 1.5, Shock = 1.0, Blight = 0, True = 1.0 },
		lootTableId = "Fungal_Tier2",
		tier = 2,
	},
	{
		id = "MycelialWeaver",
		displayName = "Mycelial Weaver",
		biomes = { "FungalDepths" },
		mechanicalHook = "Roots the player in place with a tendril cast that must be interrupted or broken by leaving line of sight before it completes.",
		flavorText = "It doesn't move to fight you. It waits for the network beneath the floor to do that for it.",
		baseHealth = 150,
		baseDamage = 18,
		moveSpeed = 4,
		aggroRadius = 26,
		attackRange = 22,
		states = { "Idle", "Alert", "Casting", "Cooldown" },
		packBehavior = "Solo",
		resistances = { Physical = 1.0, Cold = 1.0, Fire = 1.2, Shock = 0.8, Blight = 0.3, True = 1.0 },
		lootTableId = "Fungal_Tier2",
		tier = 2,
	},
}

return Enemies
