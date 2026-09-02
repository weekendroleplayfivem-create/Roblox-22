--!nonstrict
--[[
	Net.luau
	Single declaration of every remote in the game, plus the plumbing to create
	them (server) and fetch them (client).

	Reliability choices are deliberate:
		Reliable   - anything that changes authoritative state (shots, abilities,
		             scores). Losing one of these desyncs the match.
		Unreliable - anything that is re-sent constantly and is stale in 80ms
		             (movement snapshots, cosmetic effect broadcasts). Dropping a
		             packet here is free; head-of-line blocking is not.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local FOLDER_NAME = "HyperBlastNet"

Net.Definitions = {
	-- Client -> Server (authoritative requests)
	FireWeapon = "RemoteEvent",
	MeleeSwing = "RemoteEvent",
	RequestReload = "RemoteEvent",
	CancelReload = "RemoteEvent",
	SwitchWeapon = "RemoteEvent",
	UseAbility = "RemoteEvent",
	MovementEvent = "RemoteEvent", -- discrete: wall jump, mantle, jump pad
	MovementSnapshot = "UnreliableRemoteEvent", -- continuous: state + position + speed
	RequestRespawn = "RemoteEvent",
	SetLoadout = "RemoteEvent",

	-- Server -> Client (authoritative state)
	HitConfirm = "RemoteEvent", -- you hit someone: damage, headshot, killed
	DamageTaken = "RemoteEvent", -- you got hit: direction, amount
	AbilityState = "RemoteEvent", -- charges, cooldown ends, active modifiers
	WeaponState = "RemoteEvent", -- ammo/reserve/reload authority
	MovementCorrection = "RemoteEvent", -- server rejected your position
	MatchState = "RemoteEvent", -- phase, timer, scores, mode
	KillFeed = "RemoteEvent",
	ObjectiveState = "RemoteEvent", -- zones, core carrier, capture progress
	Announce = "RemoteEvent", -- big centre-screen callouts
	PlayerEliminated = "RemoteEvent", -- local death: respawn timer, killer info
	EffectBroadcast = "UnreliableRemoteEvent", -- cosmetic replication for other players

	-- Round trips
	GetServerTime = "RemoteFunction",
	GetMatchSnapshot = "RemoteFunction",
}

local cache: { [string]: Instance } = {}
local folder: Folder? = nil

--[[ Server only. Builds the remote folder. Idempotent. ]]
function Net.init()
	assert(RunService:IsServer(), "Net.init() is server-only")

	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME

	for name, className in Net.Definitions do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = created
		cache[name] = remote
	end

	created.Parent = ReplicatedStorage
	folder = created
	return created
end

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
	assert(folder, "HyperBlast remotes never replicated - is the server bootstrap running?")
	return folder
end

--[[ Returns the remote instance by name. Client calls yield until replicated. ]]
function Net.get(name: string): any
	local cached = cache[name]
	if cached and cached.Parent then
		return cached
	end

	assert(Net.Definitions[name], `unknown remote "{name}"`)
	local remote = getFolder():WaitForChild(name, 30)
	assert(remote, `remote "{name}" never replicated`)
	cache[name] = remote
	return remote
end

----------------------------------------------------------------------
-- Convenience wrappers. They exist so gameplay code reads as intent
-- ("Net.onServer('FireWeapon', handler)") rather than as plumbing.
----------------------------------------------------------------------

function Net.onServer(name: string, handler: (Player, ...any) -> ())
	return Net.get(name).OnServerEvent:Connect(handler)
end

function Net.onClient(name: string, handler: (...any) -> ())
	return Net.get(name).OnClientEvent:Connect(handler)
end

function Net.toClient(name: string, player: Player, ...)
	Net.get(name):FireClient(player, ...)
end

function Net.toAllClients(name: string, ...)
	Net.get(name):FireAllClients(...)
end

function Net.toOtherClients(name: string, except: Player, ...)
	local remote = Net.get(name)
	for _, player in game:GetService("Players"):GetPlayers() do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

function Net.toServer(name: string, ...)
	Net.get(name):FireServer(...)
end

----------------------------------------------------------------------
-- Rate limiting. Every client->server remote is wrapped in one of these on the
-- server; an unbounded remote is a free denial-of-service against your own match.
----------------------------------------------------------------------

local RateLimiter = {}
RateLimiter.__index = RateLimiter
Net.RateLimiter = RateLimiter

function RateLimiter.new(maxPerWindow: number, window: number)
	return setmetatable({
		_max = maxPerWindow,
		_window = window,
		_buckets = {} :: { [Player]: { count: number, resetAt: number } },
	}, RateLimiter)
end

function RateLimiter:Check(player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]

	if not bucket or now >= bucket.resetAt then
		self._buckets[player] = { count = 1, resetAt = now + self._window }
		return true
	end

	bucket.count += 1
	return bucket.count <= self._max
end

function RateLimiter:Clear(player: Player)
	self._buckets[player] = nil
end

return Net
