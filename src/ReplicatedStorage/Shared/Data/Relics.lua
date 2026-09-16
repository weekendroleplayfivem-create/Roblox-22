--!strict
-- Relic pool: the per-run, Hades/Balatro-style pick system offered at every
-- floor transition (3 random options, see Remotes.RelicOfferPresented).
-- Relics are tagged with archetypeTags so ProgressionService's run-readout UI
-- can compute and display *why* a build is strong (shared tags = synergy),
-- rather than the player having to infer it from stat tooltips alone.
--
-- 18 relics across 4 build archetypes plus a small universal pool - deliberately
-- above the "5 relics" floor called out as a slop-tell, and each entry below
-- is meant to combo with at least one other relic in its archetype, not just
-- stack a flat stat.
local Types = require(script.Parent.Types)

local Relics: { [string]: Types.RelicDef } = {
	-- ── Bleed archetype: physical DoT stacking, rewards weapon variety ────────
	FesteringHook = {
		id = "FesteringHook",
		displayName = "Festering Hook",
		flavorText = "A gaff-hook pulled from something that had stopped struggling days before it stopped moving.",
		rarity = "Common",
		archetypeTags = { "Bleed" },
		synergiesWith = { "CrimsonLedger", "WoundsThatCount" },
		effectId = "OnHit_ApplyBleedStack",
		iconId = "",
	},
	CrimsonLedger = {
		id = "CrimsonLedger",
		displayName = "Crimson Ledger",
		flavorText = "Every debt it tracks is paid in the same currency.",
		rarity = "Rare",
		archetypeTags = { "Bleed" },
		synergiesWith = { "FesteringHook", "WoundsThatCount" },
		effectId = "BleedDamage_ScalesWithStacksOnTarget",
		iconId = "",
	},
	WoundsThatCount = {
		id = "WoundsThatCount",
		displayName = "Wounds That Count",
		flavorText = "It keeps a tally. The tally is not for your benefit, but you get to read it.",
		rarity = "Uncommon",
		archetypeTags = { "Bleed" },
		synergiesWith = { "FesteringHook", "CrimsonLedger" },
		effectId = "MaxBleedStacks_Plus3",
		iconId = "",
	},
	ThePatientKnife = {
		id = "ThePatientKnife",
		displayName = "The Patient Knife",
		flavorText = "It was never in a hurry. Neither, now, are you.",
		rarity = "Epic",
		archetypeTags = { "Bleed" },
		synergiesWith = { "CrimsonLedger" },
		effectId = "BleedTargetsBelow30Pct_InstantExecute",
		iconId = "",
	},

	-- ── Kiter archetype: dash/chill/range uptime, punishes standing still ────
	FrostboundLantern = {
		id = "FrostboundLantern",
		displayName = "Frostbound Lantern",
		flavorText = "Its light doesn't warm anything. It was never meant to.",
		rarity = "Common",
		archetypeTags = { "Kiter" },
		synergiesWith = { "LastStepsSeen", "TheLongRetreat" },
		effectId = "OnHit_ApplyChillStack",
		iconId = "",
	},
	LastStepsSeen = {
		id = "LastStepsSeen",
		displayName = "Last Steps Seen",
		flavorText = "It shows you exactly where the ground was safe a half-second ago.",
		rarity = "Rare",
		archetypeTags = { "Kiter" },
		synergiesWith = { "FrostboundLantern", "TheLongRetreat" },
		effectId = "DashCooldown_Reduced",
		iconId = "",
	},
	TheLongRetreat = {
		id = "TheLongRetreat",
		displayName = "The Long Retreat",
		flavorText = "Retreating with purpose is not the same as retreating.",
		rarity = "Uncommon",
		archetypeTags = { "Kiter" },
		synergiesWith = { "FrostboundLantern", "LastStepsSeen" },
		effectId = "DamageDealt_ScalesWithDistanceFromTarget",
		iconId = "",
	},
	WinterSAudience = {
		id = "WinterSAudience",
		displayName = "Winter's Audience",
		flavorText = "It waits until everything in the room has stopped moving. Then it applauds, once.",
		rarity = "Legendary",
		archetypeTags = { "Kiter" },
		synergiesWith = { "FrostboundLantern" },
		effectId = "FullyChilledTarget_TakesTrueDamageBurst",
		iconId = "",
	},

	-- ── Bulwark archetype: shield/counter/tank, rewards standing your ground ──
	WardensOath = {
		id = "WardensOath",
		displayName = "Warden's Oath",
		flavorText = "An oath outlives the one who swore it. This one is still collecting on the terms.",
		rarity = "Common",
		archetypeTags = { "Bulwark" },
		synergiesWith = { "UnbrokenLine", "TheLastGuard" },
		effectId = "BlockedHit_ReflectPctDamage",
		iconId = "",
	},
	UnbrokenLine = {
		id = "UnbrokenLine",
		displayName = "Unbroken Line",
		flavorText = "The court fell. The formation, somehow, did not.",
		rarity = "Uncommon",
		archetypeTags = { "Bulwark" },
		synergiesWith = { "WardensOath", "TheLastGuard" },
		effectId = "BlockWindow_Extended",
		iconId = "",
	},
	TheLastGuard = {
		id = "TheLastGuard",
		displayName = "The Last Guard",
		flavorText = "It only matters who is standing at the end. It intends for that to be you.",
		rarity = "Rare",
		archetypeTags = { "Bulwark" },
		synergiesWith = { "WardensOath", "UnbrokenLine" },
		effectId = "LowHealth_GrantShieldOnce",
		iconId = "",
	},
	SlagboundBastion = {
		id = "SlagboundBastion",
		displayName = "Slagbound Bastion",
		flavorText = "Named for the brute it was pried off of, who was not using it politely.",
		rarity = "Epic",
		archetypeTags = { "Bulwark" },
		synergiesWith = { "WardensOath" },
		effectId = "PerfectBlock_AoEStagger",
		iconId = "",
	},

	-- ── Pyromancer archetype: burn/spellpower stacking, punishes turtling ────
	CinderSeed = {
		id = "CinderSeed",
		displayName = "Cinder Seed",
		flavorText = "Plant it in a wound. It grows fast and it does not grow kindly.",
		rarity = "Common",
		archetypeTags = { "Pyromancer" },
		synergiesWith = { "ForgebreathSigil", "AshToAsh" },
		effectId = "OnCast_ApplyBurn",
		iconId = "",
	},
	ForgebreathSigil = {
		id = "ForgebreathSigil",
		displayName = "Forgebreath Sigil",
		flavorText = "It burns hotter every time you refuse to let it cool.",
		rarity = "Rare",
		archetypeTags = { "Pyromancer" },
		synergiesWith = { "CinderSeed", "AshToAsh" },
		effectId = "ConsecutiveCasts_BurnDamageRamp",
		iconId = "",
	},
	AshToAsh = {
		id = "AshToAsh",
		displayName = "Ash to Ash",
		flavorText = "Everything it burns becomes fuel for the next thing it burns.",
		rarity = "Uncommon",
		archetypeTags = { "Pyromancer" },
		synergiesWith = { "CinderSeed", "ForgebreathSigil" },
		effectId = "TargetDeathWhileBurning_SpreadsBurn",
		iconId = "",
	},
	ForgeheartsPromise = {
		id = "ForgeheartsPromise",
		displayName = "Forgeheart's Promise",
		flavorText = "It kept burning for a full minute after the Colossus stopped moving. It hasn't stopped since.",
		rarity = "Legendary",
		archetypeTags = { "Pyromancer" },
		synergiesWith = { "ForgebreathSigil" },
		effectId = "ManaCost_RemovedWhileBurningTarget",
		iconId = "",
	},

	-- ── Universal pool: no single archetype tag, but genuinely build-shaping ──
	GravekeepersToll = {
		id = "GravekeepersToll",
		displayName = "Gravekeeper's Toll",
		flavorText = "One coin for the crossing. It does not make change.",
		rarity = "Uncommon",
		archetypeTags = { "Universal" },
		synergiesWith = {},
		effectId = "OnKill_ChanceExtraCurrency",
		iconId = "",
	},
	SecondWind = {
		id = "SecondWind",
		displayName = "Second Wind",
		flavorText = "It only works once per descent. It has never needed to work twice.",
		rarity = "Epic",
		archetypeTags = { "Universal" },
		synergiesWith = {},
		effectId = "OnLethalDamage_SurviveAt1HP_OncePerRun",
		iconId = "",
	},
}

return Relics
