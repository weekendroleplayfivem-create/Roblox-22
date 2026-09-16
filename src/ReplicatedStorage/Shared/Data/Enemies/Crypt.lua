--!strict
-- Crypt enemy roster. Cold, patient, attrition-focused - every Crypt archetype
-- punishes players who try to brute-force through undead numbers instead of
-- using the biome's chill/control tools (see StatusEffects.Chill stacking to Stun).
local Types = require(script.Parent.Parent.Parent.Types)

local Enemies: { Types.EnemyArchetypeDef } = {
	{
		id = "GraveWarden",
		displayName = "Grave Warden",
		biomes = { "Crypt" },
		mechanicalHook = "Raises a bone shield that blocks all frontal damage, so it must be flanked or baited into an overextended swing.",
		flavorText = "Once an oathsworn crypt-guard, still standing post centuries after the oath - and the body - expired.",
		baseHealth = 260,
		baseDamage = 22,
		moveSpeed = 12,
		aggroRadius = 22,
		attackRange = 7,
		states = { "Idle", "Alert", "Chase", "Attack", "Cooldown" },
		packBehavior = "Solo",
		resistances = { Physical = 0.7, Cold = 1.2, Fire = 1.0, Shock = 1.0, Blight = 1.0, True = 1.0 },
		lootTableId = "Crypt_Tier1",
		tier = 1,
	},
	{
		id = "WailingHusk",
		displayName = "Wailing Husk",
		biomes = { "Crypt" },
		mechanicalHook = "Channels a dread bolt over 1.6s that must be interrupted or it applies a stacking fear that scrambles player controls briefly.",
		flavorText = "Its keening carries down three corridors before you ever see it - by then the bolt is already half-cast.",
		baseHealth = 130,
		baseDamage = 30,
		moveSpeed = 10,
		aggroRadius = 30,
		attackRange = 26,
		states = { "Idle", "Alert", "Casting", "Cooldown", "Flee" },
		packBehavior = "Solo",
		resistances = { Physical = 1.0, Cold = 1.0, Fire = 1.0, Shock = 1.1, Blight = 1.0, True = 1.0 },
		lootTableId = "Crypt_Tier1",
		tier = 1,
	},
	{
		id = "RattlingSwarm",
		displayName = "Rattling Crawler",
		biomes = { "Crypt" },
		mechanicalHook = "Burrows beneath standing players after a 0.8s tell, punishing players who plant and tank hits instead of repositioning.",
		flavorText = "Finger bones and rib fragments, animated as one skittering mass by whatever still dreams beneath the ossuary floor.",
		baseHealth = 40,
		baseDamage = 8,
		moveSpeed = 18,
		aggroRadius = 18,
		attackRange = 4,
		states = { "Idle", "Alert", "Chase", "Attack" },
		packBehavior = "Swarm",
		resistances = { Physical = 1.0, Cold = 1.0, Fire = 1.3, Shock = 1.0, Blight = 0.6, True = 1.0 },
		lootTableId = "Crypt_Tier1_Swarm",
		tier = 1,
	},
}

return Enemies
