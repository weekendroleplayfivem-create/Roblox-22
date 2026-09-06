--[[
	PlayerData
	Authoritative per-player profile: stats, XP/level, inventory, loadout.
	Backed by DataStoreService with an in-memory cache; every write goes
	through this module so nothing else can silently desync from what's
	persisted.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ScooterData = require(game:GetService("ReplicatedStorage").Shared.ScooterData)
local SkinData = require(game:GetService("ReplicatedStorage").Shared.SkinData)
local WeaponData = require(game:GetService("ReplicatedStorage").Shared.WeaponData)

local PlayerData = {}
PlayerData._profiles = {} -- [userId] = profile table
local store

local ok, result = pcall(function()
	return DataStoreService:GetDataStore("HyperBlast_PlayerProfiles_v1")
end)
if ok then
	store = result
else
	warn("[HyperBlast] DataStore unavailable, running with in-memory profiles only:", result)
end

local function defaultProfile()
	return {
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		Wins = 0,
		Losses = 0,
		Matches = 0,
		XP = 0,
		Level = 1,
		OwnedWeaponSkins = { [SkinData.DefaultSkin] = true },
		OwnedScooterSkins = { [ScooterData.DefaultSkin] = true },
		OwnedWeapons = {
			[WeaponData.Loadout.Primary] = true,
			[WeaponData.Loadout.Secondary] = true,
			[WeaponData.Loadout.Melee] = true,
			VoidLMG = true,
			NovaSMG = true,
			ApexBurst = true,
			RiftShotgun = true,
			EchoMarksman = true,
			MagnumX = true,
			MicroSMG = true,
		},
		Loadout = {
			Primary = WeaponData.Loadout.Primary,
			Secondary = WeaponData.Loadout.Secondary,
			Melee = WeaponData.Loadout.Melee,
			WeaponSkins = {},
			ScooterSkin = ScooterData.DefaultSkin,
		},
		Settings = {
			GraphicsQuality = "Auto",
			MusicVolume = 0.5,
			SFXVolume = 0.7,
			Sensitivity = 0.5,
			CameraShake = true,
			FOV = 80,
			ShowDamageNumbers = true,
			ShowKillFeed = true,
		},
	}
end

function PlayerData.Load(player)
	local key = "Player_" .. player.UserId
	local profile = defaultProfile()

	if store then
		local success, data = pcall(function()
			return store:GetAsync(key)
		end)
		if success and data then
			for k, v in pairs(data) do
				profile[k] = v
			end
		elseif not success then
			warn("[HyperBlast] Failed to load profile for", player.Name, data)
		end
	end

	PlayerData._profiles[player.UserId] = profile
	return profile
end

function PlayerData.Get(player)
	return PlayerData._profiles[player.UserId]
end

function PlayerData.Save(player)
	local profile = PlayerData._profiles[player.UserId]
	if not profile or not store then
		return
	end
	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		store:SetAsync(key, profile)
	end)
	if not success then
		warn("[HyperBlast] Failed to save profile for", player.Name, err)
	end
end

function PlayerData.Release(player)
	PlayerData.Save(player)
	PlayerData._profiles[player.UserId] = nil
end

-- Periodic autosave so long sessions don't lose progress on a crash.
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerData.Save(player)
		end
	end
end)

return PlayerData
