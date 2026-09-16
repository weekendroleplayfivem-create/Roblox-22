--!strict
-- Server-authoritative per-player inventory/equipment. The client never holds
-- the source of truth for what it owns or has equipped - it requests changes
-- via Remotes and renders whatever InventoryUpdated pushes back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local InventoryService = {}

export type PlayerInventory = {
	items: { string }, -- owned item ids (unequipped + equipped)
	equipped: { [Types.EquipSlot]: string? },
	consumableCharges: { [string]: number },
}

local inventories: { [number]: PlayerInventory } = {} -- keyed by UserId
local RemotesFolder: Folder

local function newInventory(): PlayerInventory
	return { items = {}, equipped = {}, consumableCharges = {} }
end

function InventoryService.Get(player: Player): PlayerInventory
	local inventory = inventories[player.UserId]
	if not inventory then
		inventory = newInventory()
		inventories[player.UserId] = inventory
	end
	return inventory
end

function InventoryService.GrantItem(player: Player, itemId: string)
	local inventory = InventoryService.Get(player)
	table.insert(inventory.items, itemId)
	InventoryService._push(player)
end

local function onRequestEquipItem(player: Player, itemId: string?)
	if typeof(itemId) ~= "string" then
		return
	end
	local inventory = InventoryService.Get(player)
	-- Ownership check: a client cannot equip an item id it doesn't actually
	-- hold, regardless of what it claims - closes the "equip arbitrary item
	-- by id" exploit class.
	if not table.find(inventory.items, itemId) then
		return
	end
	local itemDef = Items.GetEquippable(itemId)
	if not itemDef then
		return
	end
	inventory.equipped[itemDef.slot] = itemId
	InventoryService._push(player)
end

local function onRequestUnequipItem(player: Player, slot: Types.EquipSlot?)
	if typeof(slot) ~= "string" then
		return
	end
	local inventory = InventoryService.Get(player)
	inventory.equipped[slot] = nil
	InventoryService._push(player)
end

local function onRequestUseConsumable(player: Player, consumableId: string?)
	if typeof(consumableId) ~= "string" then
		return
	end
	local inventory = InventoryService.Get(player)
	local charges = inventory.consumableCharges[consumableId] or 0
	if charges <= 0 then
		return -- server rejects silently; client should never let this fire if it's tracking state correctly
	end
	local def = Items.GetConsumable(consumableId)
	if not def then
		return
	end
	inventory.consumableCharges[consumableId] = charges - 1
	-- Effect dispatch (heal/cleanse/haste) resolves via ConsumableService's
	-- effectId handler table - kept out of InventoryService so inventory
	-- bookkeeping stays independent of gameplay-effect implementations.
	InventoryService._push(player)
end

function InventoryService._push(player: Player)
	local event = Remotes.Get(RemotesFolder, "InventoryUpdated") :: RemoteEvent
	local inventory = InventoryService.Get(player)
	event:FireClient(player, {
		items = inventory.items,
		equipped = inventory.equipped,
		consumableCharges = inventory.consumableCharges,
	})
end

function InventoryService.Init(remotesFolder: Folder)
	RemotesFolder = remotesFolder
	(Remotes.Get(remotesFolder, "RequestEquipItem") :: RemoteEvent).OnServerEvent:Connect(onRequestEquipItem)
	(Remotes.Get(remotesFolder, "RequestUnequipItem") :: RemoteEvent).OnServerEvent:Connect(onRequestUnequipItem)
	(Remotes.Get(remotesFolder, "RequestUseConsumable") :: RemoteEvent).OnServerEvent:Connect(onRequestUseConsumable)

	(Remotes.Get(remotesFolder, "GetInventorySnapshot") :: RemoteFunction).OnServerInvoke = function(player: Player)
		local inventory = InventoryService.Get(player)
		return { items = inventory.items, equipped = inventory.equipped, consumableCharges = inventory.consumableCharges }
	end

	Players.PlayerRemoving:Connect(function(player)
		inventories[player.UserId] = nil
	end)
end

return InventoryService
