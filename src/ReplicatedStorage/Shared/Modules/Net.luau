--[[
	Net
	Single source of truth for every remote in the game.

	The server calls Net.Setup() once; it creates
	ReplicatedStorage.Remotes/<Category>/<Name>. Clients and server then use
	Net.Event / Net.Function to fetch remotes by category + name.

	Server handlers are registered with Net.OnServerEvent / Net.OnServerInvoke,
	which apply per-player token-bucket rate limiting. Requests over the limit
	are dropped and reported to the anti-cheat violation handler.

	Clients NEVER send damage, currency, XP or results. They send intents
	(RequestFire, RequestReload, UseAbility ...) and the server decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

type RemoteKind = "Event" | "Unreliable" | "Function"

-- [Category] = { [RemoteName] = kind }
Net.Definitions = {
	Combat = {
		RequestFire = "Event", -- C->S intent to fire (server validates everything)
		RequestReload = "Event", -- C->S
		ChargeStart = "Event", -- C->S charge weapons begin charging (server times it)
		ShotReplicated = "Unreliable", -- S->C cosmetic tracer for other players
		HitConfirm = "Event", -- S->C hit marker / damage number for the shooter
		DamageTaken = "Event", -- S->C direction indicator for the victim
		Elimination = "Event", -- S->C kill feed
		ProjectileSpawned = "Event", -- S->C render a projectile
		ProjectileImpact = "Event", -- S->C explosion visual
	},
	Inventory = {
		EquipSlot = "Event", -- C->S switch weapon slot
		WeaponState = "Event", -- S->C slots + ammo snapshot
		SetLoadout = "Function", -- C->S choose weapons/abilities (validated vs unlocks)
	},
	Movement = {
		MovementAction = "Event", -- C->S slide/double jump/wall jump/jump pad notification
		MovementFx = "Unreliable", -- S->C cosmetic movement effect of another player
		Correction = "Event", -- S->C server rejected movement; reset local state
	},
	Abilities = {
		UseAbility = "Event", -- C->S
		AbilityState = "Event", -- S->C cooldown timestamps
		AbilityEffect = "Event", -- S->C pulse reveals, etc.
	},
	Match = {
		QueueRequest = "Event", -- C->S join/leave queue, leave match
		QueueState = "Event", -- S->C
		MatchState = "Event", -- S->C phase/timer/scores
		Scoreboard = "Event", -- S->C roster snapshot
		Announcement = "Event", -- S->C round announcements
		Results = "Event", -- S->C end of match summary
		XPEvent = "Event", -- S->C XP popups
	},
	UI = {
		DataSync = "Event", -- S->C player's own profile data
		Notify = "Event", -- S->C toast notifications
		UpdateSettings = "Event", -- C->S (sanitized server side)
		PurchaseItem = "Function", -- C->S cosmetic purchase
		EquipCosmetic = "Function", -- C->S
		GetLeaderboard = "Function", -- C->S global leaderboard
		DevCommand = "Function", -- C->S Studio/private test only
		RequestData = "Function", -- C->S initial data fetch
	},
}

local REMOTES_FOLDER = "Remotes"

local violationHandler: ((Player, string) -> ())? = nil

function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup must run on the server")
	local root = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER)
	if not root then
		root = Instance.new("Folder")
		root.Name = REMOTES_FOLDER
		root.Parent = ReplicatedStorage
	end
	for category, remotes in Net.Definitions do
		local folder = root:FindFirstChild(category)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = category
			folder.Parent = root
		end
		for name, kind in remotes do
			if not folder:FindFirstChild(name) then
				local className = if kind == "Function"
					then "RemoteFunction"
					elseif kind == "Unreliable" then "UnreliableRemoteEvent"
					else "RemoteEvent"
				local remote = Instance.new(className)
				remote.Name = name
				remote.Parent = folder
			end
		end
	end
end

local cache: { [string]: Instance } = {}

local function getRemote(category: string, name: string): Instance
	local key = category .. "/" .. name
	local cached = cache[key]
	if cached then
		return cached
	end
	assert(Net.Definitions[category] and Net.Definitions[category][name], "Unknown remote " .. key)
	local root = if RunService:IsServer()
		then ReplicatedStorage:FindFirstChild(REMOTES_FOLDER)
		else ReplicatedStorage:WaitForChild(REMOTES_FOLDER)
	assert(root, "Remotes not set up; call Net.Setup() on the server first")
	local folder = if RunService:IsServer() then root:FindFirstChild(category) else root:WaitForChild(category)
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name)
	cache[key] = remote
	return remote
end

-- Returns a RemoteEvent or UnreliableRemoteEvent (both share the same API).
function Net.Event(category: string, name: string): RemoteEvent
	return getRemote(category, name) :: any
end

function Net.Function(category: string, name: string): RemoteFunction
	return getRemote(category, name) :: any
end

function Net.SetViolationHandler(handler: (Player, string) -> ())
	violationHandler = handler
end

-- Token bucket per player per remote.
type Bucket = { Tokens: number, Last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

local function allow(player: Player, key: string, rate: number, burst: number): boolean
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[key]
	if not bucket then
		bucket = { Tokens = burst, Last = now }
		perPlayer[key] = bucket
	end
	bucket.Tokens = math.min(burst, bucket.Tokens + (now - bucket.Last) * rate)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

export type RateLimit = { Rate: number, Burst: number }

local DEFAULT_LIMIT: RateLimit = { Rate = 10, Burst = 20 }

-- Connects a server handler with rate limiting. `limit` is requests/second.
function Net.OnServerEvent(category: string, name: string, handler: (Player, ...any) -> (), limit: RateLimit?)
	local remote = Net.Event(category, name)
	local rateLimit = limit or DEFAULT_LIMIT
	local key = category .. "/" .. name
	return remote.OnServerEvent:Connect(function(player, ...)
		if not allow(player, key, rateLimit.Rate, rateLimit.Burst) then
			if violationHandler then
				violationHandler(player, "RemoteSpam:" .. key)
			end
			return
		end
		handler(player, ...)
	end)
end

function Net.OnServerInvoke(category: string, name: string, handler: (Player, ...any) -> ...any, limit: RateLimit?)
	local remote = Net.Function(category, name)
	local rateLimit = limit or DEFAULT_LIMIT
	local key = category .. "/" .. name
	remote.OnServerInvoke = function(player, ...)
		if not allow(player, key, rateLimit.Rate, rateLimit.Burst) then
			if violationHandler then
				violationHandler(player, "RemoteSpam:" .. key)
			end
			return nil
		end
		return handler(player, ...)
	end
end

-- Exposed for automated tests.
Net._allow = allow

return Net
