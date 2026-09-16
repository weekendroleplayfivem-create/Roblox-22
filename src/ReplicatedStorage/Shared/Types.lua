--!strict
-- Depths / shared type definitions.
-- This is the contract every data-driven content module (biomes, enemies, items,
-- talents, relics, floors) and every service that consumes them must satisfy.
-- Keeping it centralized is what lets "add a 4th biome" or "add a new relic" stay
-- a content-authoring change instead of a change to DungeonGenerator/CombatService/etc.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type StatusEffectId = "Poison" | "Burn" | "Stun" | "Chill" | "Shock" | "Bleed" | "Sunder"

export type DamageType = "Physical" | "Fire" | "Cold" | "Shock" | "Blight" | "True"

export type WeaponCategory = "MeleeArc" | "MeleeThrust" | "Ranged" | "Magic"

export type EquipSlot = "MainHand" | "OffHand" | "Head" | "Chest" | "Legs" | "Trinket1" | "Trinket2"

export type BiomeId = "Crypt" | "FungalDepths" | "MoltenForge"

export type GenerationAlgorithm = "BSP" | "CellularAutomata" | "HazardGrid"

-- ── Status effects ──────────────────────────────────────────────────────────

export type StatusEffectDef = {
	id: StatusEffectId,
	displayName: string,
	description: string,
	tickInterval: number, -- seconds between ticks, 0 for non-ticking (e.g. Stun)
	defaultDuration: number,
	stacking: "Refresh" | "Stack" | "Ignore", -- how re-application behaves
	maxStacks: number,
	-- Called server-side once per tick with (character, stackCount) -> nothing.
	-- Kept as a string key into StatusEffectService's handler table rather than a
	-- function value so this module stays pure data (serializable, diffable, and
	-- safe to require from both server and client for read-only display purposes).
	tickHandlerId: string,
	tintColor: Color3,
	icon: string, -- asset id, filled in during Studio content pass
}

-- ── Enemies ──────────────────────────────────────────────────────────────────

export type EnemyStateId = "Idle" | "Alert" | "Chase" | "Attack" | "Cooldown" | "Flee" | "Casting" | "Stagger"

export type EnemyArchetypeDef = {
	id: string,
	displayName: string,
	biomes: { BiomeId },
	-- The one-sentence mechanical hook this archetype exists to teach the player.
	-- Every archetype must have one; "more HP than the last guy" is not a hook.
	mechanicalHook: string,
	flavorText: string,
	baseHealth: number,
	baseDamage: number,
	moveSpeed: number,
	aggroRadius: number,
	attackRange: number,
	states: { EnemyStateId }, -- the subset of the global state machine this archetype uses
	packBehavior: "Solo" | "Pack" | "Swarm",
	resistances: { [DamageType]: number }, -- multiplier, 1 = normal, 0 = immune
	lootTableId: string,
	tier: number, -- floor-tier gate; see FloorConfig.enemyTierRange
}

export type BossPhaseDef = {
	phaseIndex: number,
	healthThreshold: number, -- 0-1, phase ends when boss health drops below this
	telegraphs: { string }, -- ids into an animation/VFX telegraph table
	transitionMechanic: string, -- e.g. "ArenaCollapse", "AddWave", "EnrageTimer"
	description: string,
}

export type BossDef = {
	id: string,
	displayName: string,
	biome: BiomeId,
	flavorText: string,
	phases: { BossPhaseDef },
	arenaVaultId: string, -- key into the hand-placed vault/prefab registry
	introCinematicId: string,
}

-- ── Items ────────────────────────────────────────────────────────────────────

export type StatBlock = {
	[string]: number, -- e.g. "Damage", "AttackSpeed", "Armor", "MaxHealth", "CritChance"
}

export type ItemDef = {
	id: string,
	displayName: string,
	flavorText: string, -- shown on tooltip; must read like real item flavor, not a placeholder
	rarity: RarityId,
	slot: EquipSlot,
	weaponCategory: WeaponCategory?, -- set only when slot is MainHand/OffHand and item is a weapon
	baseStats: StatBlock,
	-- Rarity does not just scale numbers: each tier past Common should add or
	-- reroll an affix, not merely multiply baseStats, so a Legendary reads as
	-- categorically different rather than "Common x5".
	affixSlots: number,
	iconId: string,
	meshId: string,
}

export type ConsumableDef = {
	id: string,
	displayName: string,
	flavorText: string,
	rarity: RarityId,
	effectId: string, -- key into ConsumableService's effect handler table
	cooldown: number,
	iconId: string,
}

-- ── Talents / Relics ─────────────────────────────────────────────────────────

export type TalentNodeDef = {
	id: string,
	displayName: string,
	description: string,
	tier: number, -- talent-tree depth, gates prerequisites
	prerequisites: { string }, -- talent ids
	archetypeTag: string?, -- e.g. "Bleed", "Kiter", "Bulwark" - used for the synergy readout UI
	statModifiers: StatBlock,
}

export type RelicDef = {
	id: string,
	displayName: string,
	flavorText: string,
	rarity: RarityId,
	archetypeTags: { string }, -- for the Balatro-style "why is my build strong" readout
	-- Human-readable synergy notes consumed by the run-readout UI; not gameplay logic.
	synergiesWith: { string },
	effectId: string, -- key into RelicService's effect handler table
	iconId: string,
}

-- ── Floors / Biomes ──────────────────────────────────────────────────────────

export type SpawnTableEntry = {
	enemyId: string,
	weight: number,
}

export type FloorConfig = {
	floorIndex: number, -- 1-based within the biome
	tierLabel: string, -- e.g. "Outer Crypt", "Deep Crypt"
	minRooms: number,
	maxRooms: number,
	enemyTierRange: { number }, -- {min, max} inclusive
	spawnTable: { SpawnTableEntry },
	hazardDensity: number, -- 0-1, biome-specific meaning (lava tiles, gas pockets, etc.)
	vaultChance: number, -- 0-1 probability a secret/vault room is seeded this floor
	isBossFloor: boolean,
}

export type BiomeDef = {
	id: BiomeId,
	displayName: string,
	identity: string, -- one-paragraph setting/tone/hook, from the design bible
	generationAlgorithm: GenerationAlgorithm,
	floors: { FloorConfig },
	bossId: string,
	ambientLoopId: string,
	combatLayerId: string,
	fogColor: Color3,
	fogEnd: number,
	primaryMaterialPalette: { Enum.Material },
	accentColor: Color3, -- drives biome sub-palette in UIStyle
}

return {}
