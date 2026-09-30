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
	tuning: { [string]: Config.Tune },
	paint: { [string]: number }, -- index into Config.PaintColors
	effects: { [string]: boolean },
	effect: string,
	totalBounty: number,
	racesWon: number,
	blacklistBeaten: number, -- how many rivals beaten (rank 5 first)
	stats: { [string]: number }, -- milestone stats
	milestones: { [string]: boolean }, -- completed milestone ids
	settings: { [string]: any }, -- client settings (camera shake, units, volume...)
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
		tuning = {},
		paint = {},
		effects = { neon = true },
		effect = "neon",
		totalBounty = 0,
		racesWon = 0,
		blacklistBeaten = 0,
		stats = {},
		milestones = {},
		settings = {},
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
	-- migrate the old 3-slot upgrade system to the new tuning parts
	if type(data.upgrades) == "table" then
		for carId, u in data.upgrades do
			if type(u) == "table" and not data.tuning[carId] then
				local tune = Config.DefaultTune()
				tune.parts.engine = math.clamp(tonumber(u.engine) or 0, 0, 4)
				tune.parts.nitrous = math.clamp(tonumber(u.nitro) or 0, 0, 4)
				tune.parts.suspension = math.clamp(tonumber(u.handling) or 0, 0, 4)
				data.tuning[carId] = tune
			end
		end
		data.upgrades = nil
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

-- Returns the tuning for a car, filling in any missing fields.
function PlayerData.Tune(profile: Profile, carId: string): Config.Tune
	local t = profile.tuning[carId]
	local base = Config.DefaultTune()
	if type(t) ~= "table" then
		profile.tuning[carId] = base
		return base
	end
	for _, group in { "parts", "handling", "visual" } do
		local have = (t :: any)[group]
		if type(have) ~= "table" then
			(t :: any)[group] = (base :: any)[group]
		else
			for k, v in (base :: any)[group] do
				if type(have[k]) ~= "number" then
					have[k] = v
				end
			end
		end
	end
	return t
end

return PlayerData
