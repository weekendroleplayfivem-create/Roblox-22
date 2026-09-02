--!nonstrict
--[[
	PlayerService.luau
	Owns players: teams, characters, spawning, loadouts and the per-player state
	every other service reads.

	Spawning is server-authoritative and mode-aware (Players.CharacterAutoLoads is
	off in the project file). A shooter that spawns you on a random SpawnLocation
	is a shooter that spawns you behind an enemy, and no amount of good movement
	design survives that.
--]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local CombatConfig = require(Root.Config.CombatConfig)
local WeaponConfig = require(Root.Config.WeaponConfig)
local Palette = require(Root.Config.Palette)
local Signal = require(Root.Util.Signal)
local Net = require(Root.Util.Net)

local PlayerService = {}
PlayerService.__index = PlayerService

local PLAYER_COLLISION_GROUP = "HB_Players"

function PlayerService.new(services)
	local self = setmetatable({}, PlayerService)

	self.services = services
	self.states = {} :: { [Player]: any }
	self.teams = {}

	self.CharacterSpawned = Signal.new()
	self.PlayerDied = Signal.new()

	return self
end

function PlayerService:Start()
	self:_setupCollisionGroups()
	self:_setupTeams()

	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_onPlayerAdded(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		self.states[player] = nil
	end)

	Net.onServer("RequestRespawn", function(player)
		local state = self.states[player]
		if state and not state.alive and os.clock() >= (state.respawnAt or 0) then
			self:SpawnPlayer(player)
		end
	end)

	Net.onServer("SetLoadout", function(player, loadout)
		self:SetLoadout(player, loadout)
	end)

	return self
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

function PlayerService:_setupCollisionGroups()
	-- Players never collide with each other. Body-blocking in a movement shooter
	-- turns a clean flank into a wrestling match, and it is the single most
	-- common source of "the game stopped me" complaints.
	local ok = pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYER_COLLISION_GROUP)
	end)
	if ok then
		PhysicsService:CollisionGroupSetCollidable(PLAYER_COLLISION_GROUP, PLAYER_COLLISION_GROUP, false)
	end
end

function PlayerService:_setupTeams()
	for key, data in Palette.Teams do
		local existing
		for _, team in game:GetService("Teams"):GetTeams() do
			if team.Name == data.Name then
				existing = team
				break
			end
		end

		local team = existing or Instance.new("Team")
		team.Name = data.Name
		team.TeamColor = data.TeamColor
		team.AutoAssignable = false
		team.Parent = game:GetService("Teams")
		self.teams[key] = team
	end
end

function PlayerService:_onPlayerAdded(player: Player)
	self.states[player] = {
		alive = false,
		respawnAt = 0,
		kills = 0,
		deaths = 0,
		score = 0,
		assists = 0,
		loadout = table.clone(WeaponConfig.DefaultLoadout),
		currentSlot = "Primary",
		ammo = {},
		damageLog = {}, -- attacker -> { damage, at } for assist credit
		lastDamageAt = 0,
		spawnProtectedUntil = 0,
	}

	player:SetAttribute("HB_Kills", 0)
	player:SetAttribute("HB_Deaths", 0)
	player:SetAttribute("HB_Score", 0)

	self:AssignTeam(player)
	self:ResetAmmo(player)

	player.CharacterRemoving:Connect(function()
		local state = self.states[player]
		if state then
			state.alive = false
		end
	end)

	-- The client asks for a body once it has booted; if it never does (studio
	-- server test, bot), spawn it anyway after a beat.
	task.delay(2, function()
		local state = self.states[player]
		if state and not state.alive and player.Parent then
			self:SpawnPlayer(player)
		end
	end)
end

----------------------------------------------------------------------
-- Teams
----------------------------------------------------------------------

function PlayerService:AssignTeam(player: Player, forcedKey: string?)
	local key = forcedKey
	if not key then
		-- Balance by headcount, then by score so the losing side gets the new
		-- player. Cheap, but it beats letting a 5v1 happen.
		local counts = {}
		local scores = {}
		for teamKey, team in self.teams do
			counts[teamKey] = 0
			scores[teamKey] = 0
			for _, other in Players:GetPlayers() do
				if other.Team == team then
					counts[teamKey] += 1
					scores[teamKey] += self.states[other] and self.states[other].score or 0
				end
			end
		end

		local best, bestCount, bestScore = nil, math.huge, math.huge
		for teamKey, count in counts do
			if count < bestCount or (count == bestCount and scores[teamKey] < bestScore) then
				best, bestCount, bestScore = teamKey, count, scores[teamKey]
			end
		end
		key = best or "Cyan"
	end

	player.Team = self.teams[key]
	player:SetAttribute("HB_TeamKey", key)
	return key
end

function PlayerService:GetTeamKey(player: Player): string
	return player:GetAttribute("HB_TeamKey") or "Cyan"
end

function PlayerService:GetTeamPlayers(teamKey: string)
	local result = {}
	local team = self.teams[teamKey]
	for _, player in Players:GetPlayers() do
		if player.Team == team then
			table.insert(result, player)
		end
	end
	return result
end

----------------------------------------------------------------------
-- Loadout / ammo
----------------------------------------------------------------------

function PlayerService:SetLoadout(player: Player, loadout)
	local state = self.states[player]
	if not state or type(loadout) ~= "table" then
		return
	end

	for slot, id in loadout do
		local definition = WeaponConfig.get(id)
		-- Validate against the config: a client cannot invent a weapon, and it
		-- cannot put a rifle in the melee slot.
		if definition and definition.Slot == WeaponConfig.Slots[slot] then
			state.loadout[slot] = id
		end
	end

	self:ResetAmmo(player)
	Net.toClient("SetLoadout", player, state.loadout)
end

function PlayerService:ResetAmmo(player: Player)
	local state = self.states[player]
	if not state then
		return
	end

	table.clear(state.ammo)
	for slot, id in state.loadout do
		local definition = WeaponConfig.get(id)
		if definition then
			state.ammo[slot] = { mag = definition.MagSize, reserve = definition.ReserveAmmo }
		end
	end
end

--[[ Modes can restrict the arsenal (Core Rush carriers, Hyper Duel). ]]
function PlayerService:RestrictWeapons(player: Player, allowedIds: { string }?)
	local state = self.states[player]
	if not state then
		return
	end
	state.restrictedTo = allowedIds
	Net.toClient("WeaponState", player, { restrictedTo = allowedIds })
end

----------------------------------------------------------------------
-- Spawning
----------------------------------------------------------------------

function PlayerService:SpawnPlayer(player: Player)
	local state = self.states[player]
	if not state then
		return
	end

	local spawnCFrame = self.services.Match and self.services.Match:GetSpawnPoint(player)
	player:LoadCharacter()

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.MaxHealth = CombatConfig.Health.Max
	humanoid.Health = CombatConfig.Health.Max
	humanoid.BreakJointsOnDeath = false
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayDistance = 0

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = PLAYER_COLLISION_GROUP
		end
	end

	if spawnCFrame then
		root.CFrame = spawnCFrame
	end

	state.alive = true
	state.lastDamageAt = 0
	table.clear(state.damageLog)
	state.spawnProtectedUntil = os.clock() + CombatConfig.Health.SpawnProtection
	self:ResetAmmo(player)

	humanoid.Died:Once(function()
		self:_onDied(player)
	end)

	Net.toClient("SetLoadout", player, state.loadout)
	self.CharacterSpawned:Fire(player, character)
	return character
end

function PlayerService:_onDied(player: Player)
	local state = self.states[player]
	if not state or not state.alive then
		return
	end

	state.alive = false
	state.deaths += 1
	player:SetAttribute("HB_Deaths", state.deaths)

	local delay = self.services.Match and self.services.Match:GetRespawnDelay() or CombatConfig.Elimination.RespawnDelay
	state.respawnAt = os.clock() + delay

	self.PlayerDied:Fire(player)

	-- Round-based modes (Hyper Duel) handle respawning themselves.
	if delay > 0 and self.services.Match and self.services.Match:AllowsAutoRespawn() then
		task.delay(delay, function()
			if player.Parent and not self.states[player].alive then
				self:SpawnPlayer(player)
			end
		end)
	end
end

----------------------------------------------------------------------
-- Queries used by the other services
----------------------------------------------------------------------

function PlayerService:GetState(player: Player)
	return self.states[player]
end

function PlayerService:IsAlive(player: Player): boolean
	local state = self.states[player]
	return state ~= nil and state.alive
end

function PlayerService:IsSpawnProtected(player: Player): boolean
	local state = self.states[player]
	return state ~= nil and os.clock() < state.spawnProtectedUntil
end

--[[ Firing cancels your own spawn protection: it is there so you can get out of
	 the gate, not so you can win a fight for free. ]]
function PlayerService:ClearSpawnProtection(player: Player)
	local state = self.states[player]
	if state then
		state.spawnProtectedUntil = 0
	end
end

function PlayerService:AddScore(player: Player, amount: number)
	local state = self.states[player]
	if not state then
		return
	end
	state.score += amount
	player:SetAttribute("HB_Score", state.score)
end

function PlayerService:AddKill(player: Player)
	local state = self.states[player]
	if not state then
		return
	end
	state.kills += 1
	player:SetAttribute("HB_Kills", state.kills)
end

function PlayerService:ResetStats()
	for player, state in self.states do
		state.kills, state.deaths, state.score, state.assists = 0, 0, 0, 0
		player:SetAttribute("HB_Kills", 0)
		player:SetAttribute("HB_Deaths", 0)
		player:SetAttribute("HB_Score", 0)
	end
end

return PlayerService
