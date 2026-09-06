--[[
	InventoryService
	Validates every cosmetic/loadout change server-side. The client only ever
	*requests* a change; ownership and shape are re-checked here before the
	profile is mutated. Cosmetics never touch gameplay stats.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local SkinData = require(ReplicatedStorage.Shared.SkinData)
local ScooterData = require(ReplicatedStorage.Shared.ScooterData)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")

local InventoryService = {}

local function pushSnapshot(player)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	InventoryUpdated:FireClient(player, {
		OwnedWeapons = profile.OwnedWeapons,
		OwnedWeaponSkins = profile.OwnedWeaponSkins,
		OwnedScooterSkins = profile.OwnedScooterSkins,
		Loadout = profile.Loadout,
	})
end
InventoryService.PushSnapshot = pushSnapshot

-- payload: { Primary, Secondary, Melee, ScooterSkin }
function InventoryService.ChangeLoadout(player, payload)
	local profile = PlayerData.Get(player)
	if not profile or type(payload) ~= "table" then
		return false, "No profile"
	end

	local function validSlot(id, slot)
		if id == nil then
			return true
		end
		local weapon = WeaponData.Get(id)
		if not weapon or weapon.Slot ~= slot then
			return false
		end
		return profile.OwnedWeapons[id] == true
	end

	if payload.Primary and not validSlot(payload.Primary, "Primary") then
		return false, "Invalid or unowned primary"
	end
	if payload.Secondary and not validSlot(payload.Secondary, "Secondary") then
		return false, "Invalid or unowned secondary"
	end
	if payload.Melee and not validSlot(payload.Melee, "Melee") then
		return false, "Invalid or unowned melee"
	end
	if payload.ScooterSkin then
		local skin = ScooterData.Skins[payload.ScooterSkin]
		if not skin or not profile.OwnedScooterSkins[payload.ScooterSkin] then
			return false, "Invalid or unowned scooter skin"
		end
	end

	profile.Loadout.Primary = payload.Primary or profile.Loadout.Primary
	profile.Loadout.Secondary = payload.Secondary or profile.Loadout.Secondary
	profile.Loadout.Melee = payload.Melee or profile.Loadout.Melee
	profile.Loadout.ScooterSkin = payload.ScooterSkin or profile.Loadout.ScooterSkin

	pushSnapshot(player)
	return true
end

-- payload: { WeaponId, SkinId }
function InventoryService.EquipWeaponSkin(player, weaponId, skinId)
	local profile = PlayerData.Get(player)
	if not profile then
		return false
	end
	if not WeaponData.Get(weaponId) then
		return false, "Unknown weapon"
	end
	local skin = SkinData.Collections[skinId]
	if not skin then
		return false, "Unknown skin"
	end
	if skin.Id ~= SkinData.DefaultSkin and not profile.OwnedWeaponSkins[skinId] then
		return false, "Skin not owned"
	end

	profile.Loadout.WeaponSkins[weaponId] = skinId
	pushSnapshot(player)
	return true
end

function InventoryService.GrantWeapon(player, weaponId)
	local profile = PlayerData.Get(player)
	if not profile or not WeaponData.Get(weaponId) then
		return false
	end
	profile.OwnedWeapons[weaponId] = true
	pushSnapshot(player)
	return true
end

function InventoryService.GrantWeaponSkin(player, skinId)
	local profile = PlayerData.Get(player)
	if not profile or not SkinData.Collections[skinId] then
		return false
	end
	profile.OwnedWeaponSkins[skinId] = true
	pushSnapshot(player)
	return true
end

function InventoryService.GrantScooterSkin(player, skinId)
	local profile = PlayerData.Get(player)
	if not profile or not ScooterData.Skins[skinId] then
		return false
	end
	profile.OwnedScooterSkins[skinId] = true
	pushSnapshot(player)
	return true
end

return InventoryService
