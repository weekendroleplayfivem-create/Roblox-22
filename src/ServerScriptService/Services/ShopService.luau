--[[
	ShopService
	Transparent cosmetic shop. Every item has a fixed, visible Credit price.
	No random rewards, no paid currency, no stat changes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local ShopService = {}

local Services

function ShopService:Owns(data, itemId: string): boolean
	return CosmeticConfig.IsFree(itemId) or data.OwnedCosmetics[itemId] == true
end

-- Returns (success, message).
function ShopService:Purchase(player: Player, itemId: any): (boolean, string)
	if type(itemId) ~= "string" then
		return false, "Invalid item"
	end
	local item = CosmeticConfig.Get(itemId)
	if not item then
		return false, "Item not found"
	end
	local data = Services.DataService:Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if ShopService:Owns(data, itemId) then
		return false, "Already owned"
	end
	if data.Level < item.RequiredLevel then
		return false, "Requires level " .. item.RequiredLevel
	end
	if data.Credits < item.Price then
		return false, "Not enough Credits"
	end
	local purchased = false
	Services.DataService:Update(player, function(profile)
		-- Re-check inside the update in case of concurrent requests.
		if profile.Credits >= item.Price and not profile.OwnedCosmetics[itemId] then
			profile.Credits -= item.Price
			profile.OwnedCosmetics[itemId] = true
			purchased = true
		end
	end)
	if not purchased then
		return false, "Purchase failed"
	end
	return true, "Purchased " .. item.Name
end

function ShopService:Equip(player: Player, itemId: any): (boolean, string)
	if type(itemId) ~= "string" then
		return false, "Invalid item"
	end
	local item = CosmeticConfig.Get(itemId)
	local data = Services.DataService:Get(player)
	if not item or not data then
		return false, "Item not found"
	end
	if not ShopService:Owns(data, itemId) then
		return false, "You don't own this yet"
	end
	Services.DataService:Update(player, function(profile)
		profile.Equipped[item.Category] = itemId
	end)
	local combatant = Services.CombatantService:GetByPlayer(player)
	if combatant and item.Category == "Banner" then
		combatant.Banner = itemId
	end
	return true, "Equipped " .. item.Name
end

function ShopService:Init(services)
	Services = services
	Net.OnServerInvoke("UI", "PurchaseItem", function(player, itemId)
		return ShopService:Purchase(player, itemId)
	end, { Rate = 2, Burst = 4 })
	Net.OnServerInvoke("UI", "EquipCosmetic", function(player, itemId)
		return ShopService:Equip(player, itemId)
	end, { Rate = 4, Burst = 8 })
end

function ShopService:Start() end

return ShopService
