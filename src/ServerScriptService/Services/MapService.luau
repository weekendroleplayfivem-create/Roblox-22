--[[
	MapService
	Builds the lobby once and loads/unloads one arena at a time from
	ServerStorage/Maps. Exposes spawn points, bot navigation nodes and the
	kill height of the current arena. Also handles jump pads (server side
	movement allowance + bot launches) and out-of-bounds checks.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Modules.Signal)
local Maid = require(Shared.Modules.Maid)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local MapConfig = require(Shared.Config.MapConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)

local MapsFolder = ServerStorage:WaitForChild("Maps")
local MapBuilder = require(MapsFolder:WaitForChild("MapBuilder"))

local MapService = {}

MapService.ArenaLoaded = Signal.new()
MapService.ArenaUnloaded = Signal.new()

local Services

export type MapData = {
	Id: string,
	Spawns: { { CFrame: CFrame, Side: string? } },
	BotNodes: { Vector3 },
	KillY: number,
	Folder: Folder,
}

local lobby: MapData? = nil
local arena: MapData? = nil
local arenaMaid = Maid.new()
local padCooldowns: { [Model]: number } = {}

local function build(moduleName: string, container: Folder, origin: Vector3): MapData
	local definition = require(MapsFolder:FindFirstChild(moduleName))
	local builder = MapBuilder.new(container, moduleName, origin)
	definition.Build(builder)
	return {
		Id = moduleName,
		Spawns = builder.Spawns,
		BotNodes = builder.BotNodes,
		KillY = origin.Y + (definition.KillY or PlayerConfig.Health.FallOutOfWorldY),
		Folder = builder.Folder,
	}
end

-- Jump pads: the client launches its own character for responsiveness; the
-- server grants a matching movement allowance so anti-cheat accepts the
-- launch, and launches bots directly.
local function connectPad(pad: BasePart, maid)
	maid:GiveTask(pad.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character or not character:IsA("Model") then
			return
		end
		local now = os.clock()
		if (padCooldowns[character] or 0) > now then
			return
		end
		padCooldowns[character] = now + PlayerConfig.Movement.JumpPad.Cooldown
		local velocity = pad:GetAttribute("LaunchVelocity")
		if typeof(velocity) ~= "Vector3" then
			return
		end
		local combatant = Services.CombatantService:GetFromInstance(character)
		if combatant and combatant.Player then
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			Services.AntiCheatService:GrantMovement(combatant.Player, horizontal + 10, velocity.Y + 10, 3)
		elseif combatant and combatant.IsBot and combatant.Root then
			combatant.Root.AssemblyLinearVelocity = velocity
		end
	end))
end

local function connectPads(data: MapData, maid)
	for _, pad in data.Folder:GetDescendants() do
		if pad:IsA("BasePart") and CollectionService:HasTag(pad, RaycastUtil.Tags.JumpPad) then
			connectPad(pad, maid)
		end
	end
end

function MapService:Init(services)
	Services = services
	for _, name in RaycastUtil.Containers do
		if name ~= RaycastUtil.Containers.Effects then
			RaycastUtil.GetContainer(name)
		end
	end
end

function MapService:Start()
	local container = RaycastUtil.GetContainer(RaycastUtil.Containers.Lobby)
	lobby = build("Lobby", container, MapConfig.LobbyOrigin)
	connectPads(lobby :: MapData, Maid.new())
end

function MapService:GetLobby(): MapData
	return lobby :: MapData
end

function MapService:GetLobbySpawn(): CFrame
	local spawns = (lobby :: MapData).Spawns
	local choice = spawns[math.random(1, #spawns)]
	return choice.CFrame
end

function MapService:LoadArena(mapId: string): MapData
	assert(MapConfig.Get(mapId), "Unknown map " .. tostring(mapId))
	MapService:UnloadArena()
	local container = RaycastUtil.GetContainer(RaycastUtil.Containers.Arena)
	local started = os.clock()
	arena = build(mapId, container, MapConfig.ArenaOrigin)
	connectPads(arena :: MapData, arenaMaid)
	print(string.format("[MapService] Built %s in %.2fs (%d spawns)", mapId, os.clock() - started, #(arena :: MapData).Spawns))
	MapService.ArenaLoaded:Fire(arena)
	return arena :: MapData
end

function MapService:UnloadArena()
	arenaMaid:DoCleaning()
	table.clear(padCooldowns)
	if arena then
		arena.Folder:Destroy()
		arena = nil
		MapService.ArenaUnloaded:Fire()
	end
	-- Clear any leftover ability objects (barriers, fields, decoys).
	RaycastUtil.GetContainer(RaycastUtil.Containers.AbilityObjects):ClearAllChildren()
end

function MapService:GetArena(): MapData?
	return arena
end

-- Kill height for whichever area the position is in.
function MapService:GetKillY(position: Vector3): number
	if arena and (position - MapConfig.ArenaOrigin).Magnitude < (position - MapConfig.LobbyOrigin).Magnitude then
		return arena.KillY
	end
	return lobby and lobby.KillY or PlayerConfig.Health.FallOutOfWorldY
end

return MapService
