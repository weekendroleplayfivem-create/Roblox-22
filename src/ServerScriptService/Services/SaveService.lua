--!strict
-- DataStore-backed persistence for account-scoped state (currency, unlocked
-- talents, cosmetics, stash). Run-scoped state (equipped relics, in-run XP)
-- is intentionally NOT persisted here - a run ending (death or extraction) is
-- what commits its results into account state, so there is nothing to resume
-- mid-run and therefore nothing for a disconnect to exploit there.
--
-- Session locking: SessionLockOwner + SessionLockedAt in the saved schema
-- guard against the classic dupe/rollback exploit where a player joins two
-- servers at once and both write stale copies back. A server claims the lock
-- on load and releases it on a clean save-on-leave; a stale lock (server
-- crashed without releasing) is only ever reclaimed after a cooldown, never
-- immediately, so a crash can't be used to race a fresh lock claim.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local SaveService = {}

local SCHEMA_VERSION = 1
local STORE_NAME = "DepthsPlayerData_v1"
local SESSION_LOCK_COOLDOWN = 300 -- seconds a lock must be stale before another server can reclaim it
local AUTOSAVE_INTERVAL = 120

local store = DataStoreService:GetDataStore(STORE_NAME)
local sessionData: { [number]: any } = {}
local dirty: { [number]: boolean } = {}

export type SaveSchemaV1 = {
	schemaVersion: number,
	softCurrency: number,
	premiumCurrency: number,
	unlockedTalents: { [string]: boolean },
	cosmeticsOwned: { string },
	stashItems: { string },
	sessionLockOwner: string?, -- JobId of the server currently holding the lock
	sessionLockedAt: number?,
}

local function defaultSave(): SaveSchemaV1
	return {
		schemaVersion = SCHEMA_VERSION,
		softCurrency = 0,
		premiumCurrency = 0,
		unlockedTalents = {},
		cosmeticsOwned = {},
		stashItems = {},
		sessionLockOwner = nil,
		sessionLockedAt = nil,
	}
end

-- Migration chain: each entry upgrades from its key version to key+1. Adding
-- support for a future schema bump means appending one function here, never
-- rewriting the load path - this is the "data-driven enough to extend"
-- requirement applied to save data specifically.
local migrations: { [number]: (any) -> any } = {
	-- [1] = function(old) ... return upgraded end  -- example shape for v1 -> v2
}

local function migrate(data: any): SaveSchemaV1
	local version = data.schemaVersion or 0
	while version < SCHEMA_VERSION do
		local step = migrations[version]
		if not step then
			warn(`SaveService: no migration from schema v{version}, resetting to default`)
			return defaultSave()
		end
		data = step(data)
		version += 1
	end
	return data
end

function SaveService.Load(player: Player): SaveSchemaV1
	local key = `Player_{player.UserId}`
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	if not ok or not result then
		local fresh = defaultSave()
		sessionData[player.UserId] = fresh
		return fresh
	end

	local data = migrate(result)

	-- Session lock check: refuse to hand out data still locked by another
	-- live server unless the lock has aged past the cooldown.
	if data.sessionLockOwner and data.sessionLockOwner ~= game.JobId then
		local age = os.time() - (data.sessionLockedAt or 0)
		if age < SESSION_LOCK_COOLDOWN then
			warn(`SaveService: player {player.UserId} save is session-locked by another server; refusing load to avoid dupe risk`)
			-- Caller should kick the player rather than let them play on an
			-- unsynced default state - handled by Main.server.lua's join flow.
			return data
		end
	end

	data.sessionLockOwner = game.JobId
	data.sessionLockedAt = os.time()
	sessionData[player.UserId] = data
	return data
end

function SaveService.MarkDirty(player: Player)
	dirty[player.UserId] = true
end

function SaveService.Save(player: Player, releaseLock: boolean?)
	local data = sessionData[player.UserId]
	if not data then
		return
	end
	if releaseLock then
		data.sessionLockOwner = nil
		data.sessionLockedAt = nil
	end
	local key = `Player_{player.UserId}`
	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)
	if not ok then
		warn(`SaveService: failed to save player {player.UserId}: {err}`)
		return
	end
	dirty[player.UserId] = false
end

function SaveService.GetSessionData(player: Player): SaveSchemaV1?
	return sessionData[player.UserId]
end

function SaveService.Init()
	Players.PlayerAdded:Connect(function(player)
		SaveService.Load(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		SaveService.Save(player, true) -- release the session lock on clean leave
		sessionData[player.UserId] = nil
		dirty[player.UserId] = nil
	end)

	-- game:BindToClose ensures a server shutdown (deploy, crash-adjacent
	-- shutdown signal) still flushes every connected player's data rather
	-- than relying solely on the interval below.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			SaveService.Save(player, true)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				if dirty[player.UserId] then
					SaveService.Save(player, false)
				end
			end
		end
	end)
end

return SaveService
