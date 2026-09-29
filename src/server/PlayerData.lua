--!strict
-- Saves and loads player progress with DataStoreService (falls back to memory in Studio
-- when API access is disabled).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}

export type Profile = {
	cash: number,
	owned: { [string]: boolean },
	selected: string,
	upgrades: { [string]: { [string]: number } },
	paint: { [string]: number }, -- index into Config.PaintColors
	effects: { [string]: boolean },
	effect: string,
	totalBounty: number,
	racesWon: number,
	blacklistBeaten: number, -- how many rivals beaten (rank 5 first)
}

local STORE_NAME = "WantedUnbound_v1"
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[WantedUnbound] DataStore unavailable, progress will not save:", result)
	end
end

local profiles: { [Player]: Profile } = {}

local function default(): Profile
	return {
		cash = Config.StartingCash,
		owned = { [Config.StarterCar] = true },
		selected = Config.StarterCar,
		upgrades = {},
		paint = {},
		effects = { neon = true },
		effect = "neon",
		totalBounty = 0,
		racesWon = 0,
		blacklistBeaten = 0,
	}
end

local function reconcile(data: any): Profile
	local base = default()
	if type(data) ~= "table" then
		return base
	end
	for k, v in pairs(base :: any) do
		if data[k] == nil or type(data[k]) ~= type(v) then
			data[k] = v
		end
	end
	if not data.owned[data.selected] then
		data.selected = Config.StarterCar
	end
	return data :: Profile
end

function PlayerData.Load(player: Player): Profile
	local data = nil
	if store then
		local s = store :: DataStore
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return s:GetAsync("player_" .. player.UserId)
			end)
			if ok then
				data = result
				break
			end
			warn("[WantedUnbound] load failed (attempt " .. attempt .. "):", result)
			task.wait(1)
		end
	end
	local profile = reconcile(data)
	profiles[player] = profile
	return profile
end

function PlayerData.Get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.Save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local s = store :: DataStore
	local ok, err = pcall(function()
		s:SetAsync("player_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[WantedUnbound] save failed:", err)
	end
end

function PlayerData.Release(player: Player)
	PlayerData.Save(player)
	profiles[player] = nil
end

function PlayerData.All(): { [Player]: Profile }
	return profiles
end

function PlayerData.Upgrades(profile: Profile, carId: string): { [string]: number }
	local u = profile.upgrades[carId]
	if not u then
		u = { engine = 0, nitro = 0, handling = 0 }
		profile.upgrades[carId] = u
	end
	return u
end

return PlayerData
