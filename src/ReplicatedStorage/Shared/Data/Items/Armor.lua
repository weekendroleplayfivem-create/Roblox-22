--!strict
-- Armor item definitions across equip slots. Same Phase 1 seeding approach as
-- Weapons.lua: enough real entries to prove the rarity/slot pattern, full
-- per-biome armor sets authored later.
local Types = require(script.Parent.Parent.Types)

local Armor: { [string]: Types.ItemDef } = {
	WatchmansHelm = {
		id = "WatchmansHelm",
		displayName = "Watchman's Helm",
		flavorText = "Dented in a pattern that suggests its last owner did not see the second blow coming either.",
		rarity = "Common",
		slot = "Head",
		baseStats = { Armor = 8, MaxHealth = 15 },
		affixSlots = 0,
		iconId = "",
		meshId = "",
	},
	CrownOfTheUnburied = {
		id = "CrownOfTheUnburied",
		displayName = "Crown of the Unburied",
		flavorText = "Taken from a court that, technically, never got a proper funeral. They noticed.",
		rarity = "Epic",
		slot = "Head",
		baseStats = { Armor = 22, MaxHealth = 60, ColdResist = 0.2 },
		affixSlots = 3,
		iconId = "",
		meshId = "",
	},
	SlagWovenChestplate = {
		id = "SlagWovenChestplate",
		displayName = "Slag-Woven Chestplate",
		flavorText = "Cooled mid-pour around whoever was wearing the mold. Forge workers don't ask which came first anymore.",
		rarity = "Rare",
		slot = "Chest",
		baseStats = { Armor = 34, MaxHealth = 45, FireResist = 0.25 },
		affixSlots = 2,
		iconId = "",
		meshId = "",
	},
	MyceliumWrappedGreaves = {
		id = "MyceliumWrappedGreaves",
		displayName = "Mycelium-Wrapped Greaves",
		flavorText = "The fungal wrap keeps growing after you put them on. It also keeps you standing after a hit that shouldn't have let you.",
		rarity = "Uncommon",
		slot = "Legs",
		baseStats = { Armor = 12, MoveSpeed = 0.08 },
		affixSlots = 1,
		iconId = "",
		meshId = "",
	},
}

return Armor
