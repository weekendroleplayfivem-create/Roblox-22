--!strict
-- Biome boss definitions. Each boss is multi-phase with a hard phase-transition
-- mechanic (arena change / add-spawn / enrage) so encounters read as a fight
-- with structure, not a single damage-sponge health bar.
local Types = require(script.Parent.Parent.Types)

local Bosses: { [string]: Types.BossDef } = {
	SepulcherKing = {
		id = "SepulcherKing",
		displayName = "The Sepulcher King",
		biome = "Crypt",
		flavorText = "Buried with his court so they could not depose him. He has had a very long time to notice they are gone.",
		phases = {
			{
				phaseIndex = 1,
				healthThreshold = 1.0,
				telegraphs = { "GraveWardBash", "ChillingWail" },
				transitionMechanic = "None",
				description = "Slow, heavy single-target strikes; introduces Chill stacking to teach the Crypt control loop before phase 2 punishes ignoring it.",
			},
			{
				phaseIndex = 2,
				healthThreshold = 0.6,
				telegraphs = { "SummonCourt", "FrozenFloorSweep" },
				transitionMechanic = "AddWave",
				description = "Summons two Grave Wardens as an honor guard; arena floor periodically freezes, forcing movement or eating stacking Chill into Stun.",
			},
			{
				phaseIndex = 3,
				healthThreshold = 0.25,
				telegraphs = { "CourtsEndEnrage" },
				transitionMechanic = "EnrageTimer",
				description = "Sheds his shield entirely (fully flankable) but attack speed ramps on a visible enrage timer - a race, not an attrition check.",
			},
		},
		arenaVaultId = "Vault_CryptBossArena",
		introCinematicId = "Cine_SepulcherKing",
	},
	MotherSpore = {
		id = "MotherSpore",
		displayName = "The Mother Spore",
		biome = "FungalDepths",
		flavorText = "Every Spore Stalker in the Depths grew from something it exhaled. It has been very patient about all of it.",
		phases = {
			{
				phaseIndex = 1,
				healthThreshold = 1.0,
				telegraphs = { "SporeBurst", "TendrilLash" },
				transitionMechanic = "None",
				description = "Area-denial spore bursts on a readable cadence; player must weave the safe lanes rather than tank chip poison damage.",
			},
			{
				phaseIndex = 2,
				healthThreshold = 0.55,
				telegraphs = { "CamouflageBloom", "StalkerAmbush" },
				transitionMechanic = "ArenaCollapse",
				description = "Arena lighting dims and the boss camouflages between bursts, forcing players to track it by the spore-puff audio tell (readable-chaos test case).",
			},
			{
				phaseIndex = 3,
				healthThreshold = 0.2,
				telegraphs = { "FinalBloom" },
				transitionMechanic = "EnrageTimer",
				description = "Full-arena spore bloom that shrinks the safe zone over time, forcing an aggressive close-out rather than a stalling strategy.",
			},
		},
		arenaVaultId = "Vault_FungalBossArena",
		introCinematicId = "Cine_MotherSpore",
	},
	ForgeheartColossus = {
		id = "ForgeheartColossus",
		displayName = "The Forgeheart Colossus",
		biome = "MoltenForge",
		flavorText = "What the forge could not temper, it simply kept feeding coal until something answered back.",
		phases = {
			{
				phaseIndex = 1,
				healthThreshold = 1.0,
				telegraphs = { "SlamCombo", "EmberSpray" },
				transitionMechanic = "None",
				description = "Standard heavy-hitter kit; teaches the sidestep-into-hazard-tile counterplay shared with Slag Brutes.",
			},
			{
				phaseIndex = 2,
				healthThreshold = 0.5,
				telegraphs = { "FloorIgnition" },
				transitionMechanic = "ArenaCollapse",
				description = "Two-thirds of the arena floor ignites into hazard tiles on a rotating pattern, shrinking safe ground while the fight continues.",
			},
			{
				phaseIndex = 3,
				healthThreshold = 0.2,
				telegraphs = { "MoltenCoreExposed" },
				transitionMechanic = "EnrageTimer",
				description = "Chest core exposed as a critical-damage weak point, but the collosus's attack tempo doubles - a high-risk burn window.",
			},
		},
		arenaVaultId = "Vault_MoltenBossArena",
		introCinematicId = "Cine_ForgeheartColossus",
	},
}

return Bosses
