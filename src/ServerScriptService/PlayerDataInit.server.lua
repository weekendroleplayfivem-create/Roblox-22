--[[ PlayerDataInit: wires player lifecycle to PlayerData and the inventory remotes. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local InventoryService = require(script.Parent.InventoryService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ChangeLoadout = Remotes:WaitForChild("ChangeLoadout")
local EquipCosmetic = Remotes:WaitForChild("EquipCosmetic")
local RequestPlayerProfile = Remotes:WaitForChild("RequestPlayerProfile")
local UpdateSettings = Remotes:WaitForChild("UpdateSettings")

local ALLOWED_SETTINGS = {
	GraphicsQuality = "string",
	MusicVolume = "number",
	SFXVolume = "number",
	Sensitivity = "number",
	CameraShake = "boolean",
	FOV = "number",
	ShowDamageNumbers = "boolean",
	ShowKillFeed = "boolean",
}

Players.PlayerAdded:Connect(function(player)
	PlayerData.Load(player)
	InventoryService.PushSnapshot(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player)
end)

ChangeLoadout.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	InventoryService.ChangeLoadout(player, payload)
end)

-- payload: { Kind = "WeaponSkin", WeaponId, SkinId }
EquipCosmetic.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.Kind == "WeaponSkin" and type(payload.WeaponId) == "string" and type(payload.SkinId) == "string" then
		InventoryService.EquipWeaponSkin(player, payload.WeaponId, payload.SkinId)
	elseif payload.Kind == "ScooterSkin" and type(payload.SkinId) == "string" then
		InventoryService.ChangeLoadout(player, { ScooterSkin = payload.SkinId })
	end
end)

UpdateSettings.OnServerEvent:Connect(function(player, payload)
	local profile = PlayerData.Get(player)
	if not profile or typeof(payload) ~= "table" then
		return
	end
	for key, expectedType in pairs(ALLOWED_SETTINGS) do
		local value = payload[key]
		if value ~= nil and typeof(value) == expectedType then
			if key == "FOV" then
				value = math.clamp(value, 50, 120)
			elseif expectedType == "number" then
				value = math.clamp(value, 0, 1)
			end
			profile.Settings[key] = value
		end
	end
end)

RequestPlayerProfile.OnServerInvoke = function(player)
	local profile = PlayerData.Get(player)
	if not profile then
		return nil
	end
	return {
		Kills = profile.Kills,
		Deaths = profile.Deaths,
		Assists = profile.Assists,
		Wins = profile.Wins,
		Losses = profile.Losses,
		Matches = profile.Matches,
		XP = profile.XP,
		Level = profile.Level,
		Loadout = profile.Loadout,
		Settings = profile.Settings,
	}
end
