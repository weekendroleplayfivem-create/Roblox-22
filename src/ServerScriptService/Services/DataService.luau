--[[
	DataService
	Persistent player profiles on DataStoreService.

	* Retries every DataStore call with exponential backoff.
	* Session locking: the profile stores which server owns it. Another server
	  will not overwrite it until the lock is released or goes stale, which
	  prevents item duplication / rollback when a player server-hops quickly.
	* Default data + Reconcile fills missing keys; Migrations upgrade old
	  versions step by step.
	* If loading fails, the player gets a temporary in-memory profile that is
	  NEVER saved (so a DataStore outage can't wipe their real data), and they
	  are told progress won't save this session.
	* Autosave + BindToClose save everything on shutdown.

	Clients never write data directly; services call DataService:Update().
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Modules.Signal)
local TableUtil = require(Shared.Modules.TableUtil)
local Net = require(Shared.Modules.Net)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local SettingsConfig = require(Shared.Config.SettingsConfig)

local DataService = {}

DataService.ProfileLoaded = Signal.new() -- (player, data)
DataService.DataChanged = Signal.new() -- (player, data)

local STORE_NAME = "VectorRush_PlayerData_v1"
local KEY_PREFIX = "Player_"
local CURRENT_VERSION = 2
local MAX_RETRIES = 5
local RETRY_BASE_DELAY = 1
local LOCK_STALE_SECONDS = 30 * 60 -- a lock older than this is from a crashed server
local LOCK_WAIT_ATTEMPTS = 4
local LOCK_WAIT_SECONDS = 6
local AUTOSAVE_INTERVAL = 120

local SESSION_ID = if game.JobId ~= "" then game.JobId else ("Studio_" .. HttpService:GenerateGUID(false))

-- Default profile. Keep every value a plain Luau type (DataStore-safe).
DataService.DefaultData = {
	Version = CURRENT_VERSION,
	XP = 0,
	Level = 1,
	Credits = 250,
	OwnedCosmetics = {},
	Equipped = {
		Primary = WeaponConfig.DefaultPrimary,
		Secondary = WeaponConfig.DefaultSecondary,
		Movement = AbilityConfig.DefaultMovement,
		Tactical = AbilityConfig.DefaultTactical,
		WeaponSkin = CosmeticConfig.Defaults.WeaponSkin,
		Trail = CosmeticConfig.Defaults.Trail,
		EliminationEffect = CosmeticConfig.Defaults.EliminationEffect,
		Banner = CosmeticConfig.Defaults.Banner,
		Crosshair = CosmeticConfig.Defaults.Crosshair,
		Emote = CosmeticConfig.Defaults.Emote,
	},
	Stats = {
		Eliminations = 0,
		Deaths = 0,
		Assists = 0,
		Headshots = 0,
		DamageDealt = 0,
		MatchesPlayed = 0,
		Wins = 0,
		BestStreak = 0,
		PlayTimeSeconds = 0,
	},
	Settings = SettingsConfig.GetDefaults(),
}

-- Migrations[n] upgrades a profile from version n to n + 1.
DataService.Migrations = {
	[1] = function(data)
		-- v1 stored "Coins"; v2 renamed it to "Credits".
		if type(data.Coins) == "number" then
			data.Credits = (data.Credits or 0) + data.Coins
			data.Coins = nil
		end
		return data
	end,
}

type Profile = {
	Data: { [string]: any },
	Temporary: boolean,
	Loaded: boolean,
	JoinTime: number,
	LastSave: number,
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function retry<T...>(label: string, callback: () -> T...): (boolean, any)
	local lastError
	for attempt = 1, MAX_RETRIES do
		local results = table.pack(pcall(callback))
		if results[1] then
			return true, table.unpack(results, 2, results.n)
		end
		lastError = results[2]
		warn(string.format("[DataService] %s failed (attempt %d/%d): %s", label, attempt, MAX_RETRIES, tostring(lastError)))
		-- Studio without API access / unpublished places will never succeed.
		local message = tostring(lastError)
		if string.find(message, "StudioAccessToApisNotAllowed") or string.find(message, "publish") then
			break
		end
		if attempt < MAX_RETRIES then
			task.wait(RETRY_BASE_DELAY * 2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

function DataService.Migrate(data: { [string]: any }): { [string]: any }
	local version = if type(data.Version) == "number" then data.Version else 1
	while version < CURRENT_VERSION do
		local migration = DataService.Migrations[version]
		if migration then
			data = migration(data)
		end
		version += 1
	end
	data.Version = CURRENT_VERSION
	return data
end

-- Repairs any invalid values so later code can trust the profile shape.
function DataService.Validate(data: { [string]: any }): { [string]: any }
	data = DataService.Migrate(data)
	TableUtil.Reconcile(data, DataService.DefaultData)
	data.XP = math.max(0, math.floor(data.XP))
	data.Credits = math.max(0, math.floor(data.Credits))
	data.Level = math.max(1, math.floor(data.Level))
	data.Settings = SettingsConfig.Sanitize(data.Settings)

	-- Drop cosmetics that no longer exist.
	for id in data.OwnedCosmetics do
		if type(id) ~= "string" or not CosmeticConfig.Get(id) then
			data.OwnedCosmetics[id] = nil
		end
	end
	local equipped = data.Equipped
	local primary = WeaponConfig.Get(equipped.Primary)
	if not primary or primary.Slot ~= "Primary" then
		equipped.Primary = WeaponConfig.DefaultPrimary
	end
	local secondary = WeaponConfig.Get(equipped.Secondary)
	if not secondary or secondary.Slot ~= "Secondary" then
		equipped.Secondary = WeaponConfig.DefaultSecondary
	end
	local movement = AbilityConfig.Get(equipped.Movement)
	if not movement or movement.Slot ~= "Movement" then
		equipped.Movement = AbilityConfig.DefaultMovement
	end
	local tactical = AbilityConfig.Get(equipped.Tactical)
	if not tactical or tactical.Slot ~= "Tactical" then
		equipped.Tactical = AbilityConfig.DefaultTactical
	end
	for category, defaultId in CosmeticConfig.Defaults do
		local item = CosmeticConfig.Get(equipped[category])
		if not item or item.Category ~= category then
			equipped[category] = defaultId
		end
	end
	return data
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	warn("[DataService] DataStore unavailable: " .. tostring(result))
	return nil
end

local function keyFor(player: Player): string
	return KEY_PREFIX .. tostring(player.UserId)
end

-- Attempts to claim the session lock and read the profile.
-- Returns ("ok", data) | ("locked", nil) | ("error", message)
local function tryLoad(player: Player): (string, any)
	local dataStore = getStore()
	if not dataStore then
		return "error", "No DataStore"
	end
	local lockedByOther = false
	local ok, result = retry("Load " .. player.UserId, function()
		lockedByOther = false
		return dataStore:UpdateAsync(keyFor(player), function(saved)
			local record = if type(saved) == "table" then saved else { Data = nil, Lock = nil }
			local lock = record.Lock
			if type(lock) == "table" and lock.Session ~= SESSION_ID and os.time() - (lock.Time or 0) < LOCK_STALE_SECONDS then
				lockedByOther = true
				return nil -- cancel write, keep other server's lock
			end
			record.Lock = { Session = SESSION_ID, Time = os.time() }
			return record
		end)
	end)
	if not ok then
		return "error", result
	end
	if lockedByOther then
		return "locked", nil
	end
	local record = result
	local data = if type(record) == "table" and type(record.Data) == "table" then record.Data else TableUtil.DeepCopy(DataService.DefaultData)
	return "ok", data
end

function DataService:LoadProfile(player: Player): Profile
	local status, data = tryLoad(player)
	local attempts = 1
	while status == "locked" and attempts < LOCK_WAIT_ATTEMPTS and player.Parent do
		task.wait(LOCK_WAIT_SECONDS)
		status, data = tryLoad(player)
		attempts += 1
	end

	local profile: Profile
	if status == "ok" then
		profile = { Data = DataService.Validate(data), Temporary = false, Loaded = true, JoinTime = os.clock(), LastSave = os.clock() }
	else
		-- Fall back to temporary data. NEVER saved, so real data stays safe.
		warn(string.format("[DataService] Using temporary profile for %s (%s)", player.Name, tostring(status)))
		profile = {
			Data = DataService.Validate(TableUtil.DeepCopy(DataService.DefaultData)),
			Temporary = true,
			Loaded = true,
			JoinTime = os.clock(),
			LastSave = os.clock(),
		}
	end

	if not player.Parent then
		-- Left while loading; release the lock we may have taken.
		if not profile.Temporary then
			profiles[player] = profile
			DataService:SaveProfile(player, true)
			profiles[player] = nil
		end
		return profile
	end

	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile.Data)
	DataService:Sync(player)
	if profile.Temporary then
		local notify = Net.Event("UI", "Notify")
		notify:FireClient(player, {
			Text = "We couldn't load your saved progress. You can still play, but progress won't save this session.",
			Kind = "Warning",
			Duration = 8,
		})
	end
	return profile
end

function DataService:SaveProfile(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.Temporary or not profile.Loaded then
		return false
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end

	-- Track play time.
	local now = os.clock()
	profile.Data.Stats.PlayTimeSeconds += math.floor(now - profile.LastSave)
	profile.LastSave = now

	local snapshot = TableUtil.DeepCopy(profile.Data)
	local lostLock = false
	local ok, err = retry("Save " .. player.UserId, function()
		lostLock = false
		return dataStore:UpdateAsync(keyFor(player), function(saved)
			local record = if type(saved) == "table" then saved else {}
			local lock = record.Lock
			if type(lock) == "table" and lock.Session ~= SESSION_ID and os.time() - (lock.Time or 0) < LOCK_STALE_SECONDS then
				lostLock = true
				return nil -- another server owns this profile now; don't overwrite
			end
			record.Data = snapshot
			record.Lock = if release then nil else { Session = SESSION_ID, Time = os.time() }
			return record
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	if lostLock then
		warn("[DataService] Session lock lost for " .. player.Name .. "; save skipped")
		return false
	end
	return true
end

function DataService:GetProfile(player: Player): Profile?
	return profiles[player]
end

-- Returns the live data table (read-only by convention; use Update to change).
function DataService:Get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:IsTemporary(player: Player): boolean
	local profile = profiles[player]
	return profile == nil or profile.Temporary
end

-- The only way services change player data. Pushes the new data to the client.
function DataService:Update(player: Player, mutator: (data: { [string]: any }) -> ())
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.Data)
	DataService.DataChanged:Fire(player, profile.Data)
	DataService:Sync(player)
	return true
end

function DataService:Sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Net.Event("UI", "DataSync"):FireClient(player, profile.Data, profile.Temporary)
end

function DataService:WaitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 30)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService:ReleaseProfile(player: Player)
	DataService:SaveProfile(player, true)
	profiles[player] = nil
end

function DataService:Init()
	Net.OnServerInvoke("UI", "RequestData", function(player)
		local profile = DataService:WaitForProfile(player, 15)
		if not profile then
			return nil, true
		end
		return profile.Data, profile.Temporary
	end, { Rate = 1, Burst = 3 })

	Net.OnServerEvent("UI", "UpdateSettings", function(player, settings)
		if type(settings) ~= "table" then
			return
		end
		DataService:Update(player, function(data)
			-- Merge sanitized values only; unknown keys are discarded.
			for key, value in settings do
				if type(key) == "string" then
					local clean = SettingsConfig.SanitizeValue(key, value)
					if clean ~= nil then
						data.Settings[key] = clean
					end
				end
			end
		end)
	end, { Rate = 2, Burst = 5 })
end

function DataService:Start()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.SaveProfile, DataService, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			-- Studio may not have API access; still attempt but don't hang.
			task.wait(0.5)
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService:SaveProfile(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- PlayerService also runs match cleanup on leave; save after it.
		task.defer(function()
			DataService:ReleaseProfile(player)
		end)
	end)
end

return DataService
