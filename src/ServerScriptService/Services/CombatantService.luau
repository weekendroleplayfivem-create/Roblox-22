--[[
	CombatantService
	Registry of everything that can fight: real players and practice bots.
	Other services work with "combatants" instead of Players so bots share
	the exact same damage, scoring and spawning code paths.

	Character models get the attribute "CombatantId" so hit validation can map
	a hit part back to its combatant.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Modules.Signal)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local PlayerConfig = require(Shared.Config.PlayerConfig)

local CombatantService = {}

CombatantService.Added = Signal.new()
CombatantService.Removed = Signal.new()
CombatantService.CharacterAttached = Signal.new()

-- Bot ids start far below zero so they never collide with Studio test
-- players (which use small negative UserIds).
local BOT_ID_START = -1000000

local combatants: { [number]: any } = {}
local byPlayer: { [Player]: any } = {}
local nextBotId = BOT_ID_START

local function newStats()
	return {
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		Score = 0,
		Headshots = 0,
		DamageDealt = 0,
		Streak = 0,
		BestStreak = 0,
	}
end

local function newCombatant(id: number, name: string, isBot: boolean, player: Player?)
	return {
		Id = id,
		Name = name,
		IsBot = isBot,
		Player = player,
		Bot = nil,
		Team = nil :: string?,
		Character = nil :: Model?,
		Humanoid = nil :: Humanoid?,
		Root = nil :: BasePart?,
		Alive = false,
		InMatch = false,
		Stats = newStats(),
		GunGameLevel = 1,
		Shield = 0,
		LastDamagedAt = 0,
		DamageLog = {},
		SpawnProtectedUntil = 0,
		Level = 1,
		Banner = "Banner_Default",
	}
end

function CombatantService:Init() end
function CombatantService:Start() end

function CombatantService:CreateForPlayer(player: Player)
	local existing = byPlayer[player]
	if existing then
		return existing
	end
	local combatant = newCombatant(player.UserId, player.DisplayName, false, player)
	combatants[combatant.Id] = combatant
	byPlayer[player] = combatant
	CombatantService.Added:Fire(combatant)
	return combatant
end

function CombatantService:CreateForBot(name: string)
	nextBotId -= 1
	local combatant = newCombatant(nextBotId, name, true, nil)
	combatants[combatant.Id] = combatant
	CombatantService.Added:Fire(combatant)
	return combatant
end

function CombatantService:Remove(combatant)
	if not combatants[combatant.Id] then
		return
	end
	combatants[combatant.Id] = nil
	if combatant.Player then
		byPlayer[combatant.Player] = nil
	end
	combatant.Alive = false
	CombatantService.Removed:Fire(combatant)
end

function CombatantService:Get(id: number)
	return combatants[id]
end

function CombatantService:GetByPlayer(player: Player)
	return byPlayer[player]
end

-- Maps any descendant of a character model back to its combatant.
function CombatantService:GetFromInstance(instance: Instance?)
	local model = RaycastUtil.FindTargetModel(instance)
	if not model then
		return nil
	end
	local id = model:GetAttribute("CombatantId")
	if type(id) ~= "number" then
		return nil
	end
	local combatant = combatants[id]
	if combatant and combatant.Character == model then
		return combatant
	end
	return nil
end

function CombatantService:GetAll(): { any }
	local list = {}
	for _, combatant in combatants do
		table.insert(list, combatant)
	end
	return list
end

function CombatantService:GetInMatch(): { any }
	local list = {}
	for _, combatant in combatants do
		if combatant.InMatch then
			table.insert(list, combatant)
		end
	end
	return list
end

function CombatantService:ResetMatchState(combatant)
	combatant.Stats = newStats()
	combatant.GunGameLevel = 1
	combatant.DamageLog = {}
	combatant.Team = nil
	combatant.Shield = 0
end

function CombatantService:SetTeam(combatant, team: string?)
	combatant.Team = team
	if combatant.Player then
		combatant.Player:SetAttribute("Team", team)
	end
	if combatant.Character then
		combatant.Character:SetAttribute("Team", team)
	end
end

-- Links a freshly spawned character model to its combatant.
function CombatantService:AttachCharacter(combatant, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	combatant.Character = character
	combatant.Humanoid = humanoid
	combatant.Root = root
	combatant.Alive = humanoid ~= nil and humanoid.Health > 0
	combatant.Shield = PlayerConfig.Health.MaxShield
	combatant.LastDamagedAt = 0
	combatant.DamageLog = {}
	character:SetAttribute("CombatantId", combatant.Id)
	character:SetAttribute("Team", combatant.Team)
	character:SetAttribute("Shield", combatant.Shield)
	character:SetAttribute("MaxShield", PlayerConfig.Health.MaxShield)
	CombatantService.CharacterAttached:Fire(combatant, character)
end

function CombatantService:IsAlive(combatant): boolean
	if not combatant or not combatant.Alive then
		return false
	end
	local humanoid = combatant.Humanoid
	local root = combatant.Root
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root.Parent ~= nil
end

-- Teams decide friendliness in team modes; without teams everyone else is an enemy.
function CombatantService:AreEnemies(a, b): boolean
	if a == nil or b == nil or a == b or a.Id == b.Id then
		return false
	end
	if a.Team ~= nil and b.Team ~= nil then
		return a.Team ~= b.Team
	end
	return true
end

function CombatantService:GetHeadPosition(combatant): Vector3?
	local character = combatant.Character
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	if combatant.Root then
		return combatant.Root.Position + PlayerConfig.Character.HeadOffset
	end
	return nil
end

return CombatantService
