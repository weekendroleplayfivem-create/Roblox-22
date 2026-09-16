--!strict
-- Rarity tier table. Every item/relic/consumable rarity reads from here so color,
-- affix count, and drop weight stay consistent across every UI screen and the
-- loot roller instead of being re-hardcoded per system.
local Types = require(script.Parent.Parent.Types)

export type RarityTier = {
	id: Types.RarityId,
	displayName: string,
	order: number, -- ascending power order, used for sorting and upgrade comparisons
	color: Color3,
	dropWeight: number, -- relative weight in LootService's weighted roll
	affixCount: number, -- how many affix rolls an item of this rarity gets beyond baseStats
	statMultiplier: number, -- applied to baseStats before affixes
	pickupStingerId: string, -- distinct audio per tier, legendary gets a unique stinger
}

local Rarity: { [Types.RarityId]: RarityTier } = {
	Common = {
		id = "Common",
		displayName = "Common",
		order = 1,
		color = Color3.fromRGB(184, 176, 162), -- bone/ash grey, reads as "unremarkable" against the torchlit palette
		dropWeight = 1000,
		affixCount = 0,
		statMultiplier = 1.0,
		pickupStingerId = "loot_pickup_common",
	},
	Uncommon = {
		id = "Uncommon",
		displayName = "Uncommon",
		order = 2,
		color = Color3.fromRGB(107, 178, 110),
		dropWeight = 420,
		affixCount = 1,
		statMultiplier = 1.15,
		pickupStingerId = "loot_pickup_uncommon",
	},
	Rare = {
		id = "Rare",
		displayName = "Rare",
		order = 3,
		color = Color3.fromRGB(90, 150, 214),
		dropWeight = 130,
		affixCount = 2,
		statMultiplier = 1.35,
		pickupStingerId = "loot_pickup_rare",
	},
	Epic = {
		id = "Epic",
		displayName = "Epic",
		order = 4,
		color = Color3.fromRGB(168, 96, 214),
		dropWeight = 32,
		affixCount = 3,
		statMultiplier = 1.6,
		pickupStingerId = "loot_pickup_epic",
	},
	Legendary = {
		id = "Legendary",
		displayName = "Legendary",
		order = 5,
		color = Color3.fromRGB(224, 154, 58), -- warm forge-gold, deliberately the only tier that reads warm against every biome's cool/rust palette
		dropWeight = 4,
		affixCount = 4,
		statMultiplier = 2.0,
		pickupStingerId = "loot_pickup_legendary", -- unique multi-layer stinger, not a pitched-up copy of epic's
	},
}

return Rarity
