--!strict
local Types = require(script.Parent.Parent.Types)

local Consumables: { [string]: Types.ConsumableDef } = {
	EmberSalve = {
		id = "EmberSalve",
		displayName = "Ember Salve",
		flavorText = "Forge-worker's field dressing. Smells like burnt hair; works better than it smells.",
		rarity = "Common",
		effectId = "HealFlat_Small",
		cooldown = 20,
		iconId = "",
	},
	SporeAntitoxin = {
		id = "SporeAntitoxin",
		displayName = "Spore Antitoxin",
		flavorText = "Cures what the Depths gave you, for about ninety seconds. Reapply liberally.",
		rarity = "Uncommon",
		effectId = "CleanseDebuffs_ShortImmunity",
		cooldown = 45,
		iconId = "",
	},
	VigilTincture = {
		id = "VigilTincture",
		displayName = "Vigil Tincture",
		flavorText = "Brewed by crypt-watch to stay awake through a nine-hour vigil. Also works on a dungeon floor, apparently.",
		rarity = "Rare",
		effectId = "HasteBuff_ShortDuration",
		cooldown = 60,
		iconId = "",
	},
}

return Consumables
