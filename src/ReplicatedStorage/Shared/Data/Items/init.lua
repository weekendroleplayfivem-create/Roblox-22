--!strict
-- Aggregates all item categories into one id-keyed lookup for InventoryService/
-- LootService. Consumables are kept in a separate table (ConsumableDef has a
-- different shape than ItemDef - no equip slot) but merged into the same
-- Get() surface so callers don't need to know the category up front.
local Weapons = require(script.Weapons)
local Armor = require(script.Armor)
local Consumables = require(script.Consumables)

local Items = {
	Weapons = Weapons,
	Armor = Armor,
	Consumables = Consumables,
}

function Items.GetEquippable(id: string)
	return Weapons[id] or Armor[id]
end

function Items.GetConsumable(id: string)
	return Consumables[id]
end

return Items
