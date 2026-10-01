--[[
	PlayerService
	Player lifecycle: join -> load data -> lobby spawn -> (match) -> leave.
	Characters never auto-load; every spawn goes through SpawnCombatant so
	position, health, shields, loadout and anti-cheat baselines are set in one
	place for players and bots alike.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Modules.Signal)
local PlayerConfig = require(Shared.Config.PlayerConfig)

local PlayerService = {}

PlayerService.CombatantSpawned = Signal.new() -- (combatant, character)

local Services

local LOBBY_RESPAWN_DELAY = 2
local BOUNDS_CHECK_INTERVAL = 0.25

local diedConnections: { [Model]: RBXScriptConnection } = {}

-- Applies config values to a freshly spawned character (player or bot).
function PlayerService:ConfigureCharacter(combatant, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local movement = PlayerConfig.Movement
	humanoid.UseJumpPower = true
	humanoid.JumpPower = movement.JumpPower
	humanoid.WalkSpeed = movement.WalkSpeed
	humanoid.MaxHealth = PlayerConfig.Health.MaxHealth
	humanoid.Health = PlayerConfig.Health.MaxHealth
	humanoid.BreakJointsOnDeath = false
	-- No overhead health bars; the HUD shows health instead.
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 60

	-- Built-in regeneration is replaced by CombatService's shield/health regen.
	local regenScript = character:FindFirstChild("Health")
	if regenScript and regenScript:IsA("Script") then
		regenScript:Destroy()
	end

	Services.CombatantService:AttachCharacter(combatant, character)

	local existing = diedConnections[character]
	if existing then
		existing:Disconnect()
	end
	diedConnections[character] = humanoid.Died:Connect(function()
		diedConnections[character] = nil
		-- Deaths not caused by CombatService (reset button, physics) still count.
		if combatant.Character == character and combatant.Alive then
			Services.CombatService:HandleUnscoredDeath(combatant, "Reset")
		end
	end)
end

-- Spawns any combatant at `cframe`. Yields while a player character loads.
function PlayerService:SpawnCombatant(combatant, cframe: CFrame)
	if combatant.IsBot then
		local character = Services.BotService:SpawnBotCharacter(combatant, cframe)
		if character then
			PlayerService:ConfigureCharacter(combatant, character)
			PlayerService.CombatantSpawned:Fire(combatant, character)
		end
		return character
	end

	local player = combatant.Player
	if not player or not player.Parent then
		return nil
	end
	-- Mark dead while the new character loads so nothing targets it early,
	-- and pause movement checks until it has been moved to the spawn.
	combatant.Alive = false
	Services.AntiCheatService:ResetBaseline(player, nil, 3)
	player:LoadCharacter()
	local character = player.Character
	if not character or not player.Parent then
		return nil
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return nil
	end
	PlayerService:ConfigureCharacter(combatant, character)
	character:PivotTo(cframe)
	Services.AntiCheatService:ResetBaseline(player, cframe.Position, 1.5)
	PlayerService.CombatantSpawned:Fire(combatant, character)
	return character
end

function PlayerService:SendToLobby(player: Player)
	local combatant = Services.CombatantService:GetByPlayer(player)
	if not combatant then
		return
	end
	combatant.InMatch = false
	Services.CombatantService:SetTeam(combatant, nil)
	player:SetAttribute("Location", "Lobby")
	Services.WeaponService:ClearLoadout(combatant)
	task.spawn(function()
		PlayerService:SpawnCombatant(combatant, Services.MapService:GetLobbySpawn())
	end)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Location", "Loading")
	local combatant = Services.CombatantService:CreateForPlayer(player)

	local profile = Services.DataService:LoadProfile(player)
	if not player.Parent then
		return
	end
	combatant.Level = profile.Data.Level
	combatant.Banner = profile.Data.Equipped.Banner
	player:SetAttribute("Level", profile.Data.Level)

	PlayerService:SendToLobby(player)
end

local function onPlayerRemoving(player: Player)
	local combatant = Services.CombatantService:GetByPlayer(player)
	Services.QueueService:RemovePlayer(player)
	if combatant then
		Services.MatchService:OnCombatantLeaving(combatant)
		Services.WeaponService:ClearLoadout(combatant)
		Services.AbilityService:ClearState(combatant)
		Services.CombatantService:Remove(combatant)
	end
end

-- Respawns lobby players that died (reset / fell) and catches anyone who
-- falls out of the world.
local function boundsLoop()
	local CombatantService = Services.CombatantService
	for _, combatant in CombatantService:GetAll() do
		if CombatantService:IsAlive(combatant) then
			local root = combatant.Root
			if root.Position.Y < Services.MapService:GetKillY(root.Position) then
				if combatant.InMatch then
					Services.CombatService:HandleUnscoredDeath(combatant, "OutOfBounds")
				elseif combatant.Player then
					local target = Services.MapService:GetLobbySpawn()
					root.AssemblyLinearVelocity = Vector3.zero
					combatant.Character:PivotTo(target)
					Services.AntiCheatService:ResetBaseline(combatant.Player, target.Position, 1)
				end
			end
		end
	end
end

function PlayerService:Init(services)
	Services = services
	Players.CharacterAutoLoads = false
end

function PlayerService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Lobby deaths (reset button) respawn quickly.
	Services.CombatService.CombatantDied:Connect(function(combatant)
		if not combatant.InMatch and combatant.Player then
			task.delay(LOBBY_RESPAWN_DELAY, function()
				local player = combatant.Player
				if player and player.Parent and not combatant.InMatch and not combatant.Alive then
					PlayerService:SpawnCombatant(combatant, Services.MapService:GetLobbySpawn())
				end
			end)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed >= BOUNDS_CHECK_INTERVAL then
			elapsed = 0
			boundsLoop()
		end
	end)
end

return PlayerService
