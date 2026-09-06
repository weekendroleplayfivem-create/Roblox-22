--[[
	DataManager
	Light persistence: best wave reached and runs played. Deliberately small —
	MIND TD has no progression to protect, so there's nothing here worth
	trusting a client with, and nothing personal is stored.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}

local store
local ok, result = pcall(function()
	return DataStoreService:GetDataStore("MindTD_Profiles_v1")
end)
if ok then
	store = result
else
	-- Studio without API access, or a datastore outage. The game is fully
	-- playable without persistence, so this is a warning, not a failure.
	warn("[MIND TD] DataStore unavailable; running with in-memory profiles:", result)
end

local profiles: { [number]: any } = {}

local function default()
	return {
		BestWave = 0,
		RunsPlayed = 0,
		Victories = 0,
	}
end

function DataManager.Load(player: Player)
	local profile = default()
	if store then
		local success, data = pcall(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)
		if success and type(data) == "table" then
			for key, value in pairs(data) do
				profile[key] = value
			end
		end
	end
	profiles[player.UserId] = profile
	return profile
end

function DataManager.Get(player: Player)
	return profiles[player.UserId]
end

function DataManager.Save(player: Player)
	local profile = profiles[player.UserId]
	if not profile or not store then
		return
	end
	pcall(function()
		store:SetAsync("Player_" .. player.UserId, profile)
	end)
end

function DataManager.Release(player: Player)
	DataManager.Save(player)
	profiles[player.UserId] = nil
end

function DataManager.RecordRun(waveReached: number, victory: boolean)
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = profiles[player.UserId]
		if profile then
			profile.RunsPlayed += 1
			profile.BestWave = math.max(profile.BestWave, waveReached)
			if victory then
				profile.Victories += 1
			end
		end
	end
end

return DataManager
