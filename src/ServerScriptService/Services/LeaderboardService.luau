--[[
	LeaderboardService
	* Match scoreboard: broadcasts a compact roster snapshot once per second
	  (name, team, eliminations, deaths, assists, score, ping). No private
	  information (no UserIds of other players beyond display ids, no data).
	* Global leaderboard: lifetime eliminations in an OrderedDataStore, cached
	  and refreshed at most once a minute.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)

local LeaderboardService = {}

local Services

local SNAPSHOT_INTERVAL = 1
local GLOBAL_STORE = "VectorRush_Eliminations_v1"
local GLOBAL_REFRESH = 60
local GLOBAL_SIZE = 10

local globalCache = { Entries = {}, Updated = 0 }
local orderedStore: OrderedDataStore? = nil

function LeaderboardService:BuildSnapshot()
	local entries = {}
	for _, combatant in Services.CombatantService:GetInMatch() do
		local stats = combatant.Stats
		table.insert(entries, {
			Id = combatant.Id,
			Name = combatant.Name,
			Team = combatant.Team,
			Kills = stats.Kills,
			Deaths = stats.Deaths,
			Assists = stats.Assists,
			Score = stats.Score,
			Ping = if combatant.Player then math.floor(Services.CombatService.GetPing(combatant.Player) * 1000) else 0,
			IsBot = combatant.IsBot,
			Level = combatant.Level,
			Banner = combatant.Banner,
			Alive = combatant.Alive,
			GunGameLevel = combatant.GunGameLevel,
		})
	end
	table.sort(entries, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		return a.Kills > b.Kills
	end)
	return entries
end

function LeaderboardService:Broadcast()
	Net.Event("Match", "Scoreboard"):FireAllClients(LeaderboardService:BuildSnapshot())
end

local function getStore(): OrderedDataStore?
	if orderedStore then
		return orderedStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(GLOBAL_STORE)
	end)
	if ok then
		orderedStore = result
	end
	return orderedStore
end

function LeaderboardService:SubmitLifetime(player: Player)
	local data = Services.DataService:Get(player)
	if not data or Services.DataService:IsTemporary(player) then
		return
	end
	local store = getStore()
	if not store then
		return
	end
	local value = data.Stats.Eliminations
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(player.UserId), value)
		end)
		if not ok then
			warn("[Leaderboard] Submit failed: " .. tostring(err))
		end
	end)
end

function LeaderboardService:GetGlobal()
	if os.clock() - globalCache.Updated < GLOBAL_REFRESH and globalCache.Updated > 0 then
		return globalCache.Entries
	end
	globalCache.Updated = os.clock()
	local store = getStore()
	if not store then
		return globalCache.Entries
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, GLOBAL_SIZE)
	end)
	if not ok then
		warn("[Leaderboard] Fetch failed: " .. tostring(pages))
		return globalCache.Entries
	end
	local entries = {}
	for rank, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		local name = "Player"
		if userId then
			local nameOk, result = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if nameOk then
				name = result
			end
		end
		table.insert(entries, { Rank = rank, Name = name, Value = entry.value })
	end
	globalCache.Entries = entries
	return entries
end

function LeaderboardService:Init(services)
	Services = services
	Net.OnServerInvoke("UI", "GetLeaderboard", function()
		return LeaderboardService:GetGlobal()
	end, { Rate = 0.5, Burst = 2 })
end

function LeaderboardService:Start()
	task.spawn(function()
		while true do
			task.wait(SNAPSHOT_INTERVAL)
			if Services.MatchService:GetPhase() ~= "Lobby" then
				LeaderboardService:Broadcast()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		LeaderboardService:SubmitLifetime(player)
	end)
end

return LeaderboardService
