--[[
	AbilityService
	Server-authoritative abilities. Every combatant has a Movement slot and a
	Tactical slot. The server:
	  * owns cooldowns (client predictions are corrected by AbilityState)
	  * validates the combatant is alive and (for tacticals) in an active match
	  * creates every gameplay object (barriers, decoys, low-g fields)
	  * decides who is revealed by a scan pulse
	Movement abilities also grant anti-cheat movement allowances.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local MathUtil = require(Shared.Modules.MathUtil)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local MatchConfig = require(Shared.Config.MatchConfig)

local AbilityService = {}

local Services

type SlotState = { Id: string, ReadyAt: number }
type State = { Movement: SlotState, Tactical: SlotState, PhaseToken: number }

local states: { [number]: State } = {}

local function serverTime(clockTime: number): number
	return workspace:GetServerTimeNow() + (clockTime - os.clock())
end

function AbilityService:SendState(combatant)
	local player = combatant.Player
	local state = states[combatant.Id]
	if not player or not state then
		return
	end
	Net.Event("Abilities", "AbilityState"):FireClient(player, {
		Movement = { Id = state.Movement.Id, ReadyAt = serverTime(state.Movement.ReadyAt) },
		Tactical = { Id = state.Tactical.Id, ReadyAt = serverTime(state.Tactical.ReadyAt) },
	})
end

-- Reads the equipped abilities (validated against level) into the state.
function AbilityService:ApplyLoadout(combatant)
	local movement, tactical = AbilityConfig.DefaultMovement, AbilityConfig.DefaultTactical
	if combatant.Player then
		local data = Services.DataService:Get(combatant.Player)
		if data then
			local movementAbility = AbilityConfig.Get(data.Equipped.Movement)
			local tacticalAbility = AbilityConfig.Get(data.Equipped.Tactical)
			if movementAbility and data.Level >= movementAbility.UnlockLevel then
				movement = movementAbility.Id
			end
			if tacticalAbility and data.Level >= tacticalAbility.UnlockLevel then
				tactical = tacticalAbility.Id
			end
		end
	elseif combatant.BotAbilities then
		movement = combatant.BotAbilities.Movement
		tactical = combatant.BotAbilities.Tactical
	end
	local existing = states[combatant.Id]
	states[combatant.Id] = {
		Movement = { Id = movement, ReadyAt = if existing and existing.Movement.Id == movement then existing.Movement.ReadyAt else 0 },
		Tactical = { Id = tactical, ReadyAt = if existing and existing.Tactical.Id == tactical then existing.Tactical.ReadyAt else 0 },
		PhaseToken = if existing then existing.PhaseToken else 0,
	}
	AbilityService:SendState(combatant)
end

function AbilityService:ResetCooldowns(combatant)
	local state = states[combatant.Id]
	if state then
		state.Movement.ReadyAt = 0
		state.Tactical.ReadyAt = 0
		AbilityService:SendState(combatant)
	end
end

function AbilityService:ClearState(combatant)
	states[combatant.Id] = nil
end

local function teamColor(combatant): Color3
	if combatant.Team and MatchConfig.Teams[combatant.Team] then
		return MatchConfig.Teams[combatant.Team].Color
	end
	return MatchConfig.FreeForAllColor
end

local function lookDirection(combatant, payload): Vector3
	local direction = if type(payload) == "table" then payload.Direction else nil
	if typeof(direction) == "Vector3" and MathUtil.IsFiniteVector(direction) and direction.Magnitude > 0.1 then
		return direction.Unit
	end
	return combatant.Root.CFrame.LookVector
end

--[[ Ability implementations ]]

local Implementations = {}

function Implementations.Dash(combatant, _config, _payload)
	local dash = PlayerConfig.Movement.Dash
	if combatant.Player then
		Services.AntiCheatService:GrantMovement(combatant.Player, dash.Speed + 10, 20, dash.Duration + 0.8)
	elseif combatant.Root then
		combatant.Root.AssemblyLinearVelocity = combatant.Root.CFrame.LookVector * dash.Speed
	end
	local remote = Net.Event("Movement", "MovementFx")
	for _, player in Players:GetPlayers() do
		if player ~= combatant.Player then
			remote:FireClient(player, { Kind = "Dash", Character = combatant.Character })
		end
	end
end

function Implementations.Phase(combatant, config, _payload)
	local state = states[combatant.Id]
	state.PhaseToken += 1
	local token = state.PhaseToken
	local character = combatant.Character
	character:SetAttribute("Phased", true)
	if combatant.Player then
		local speed = PlayerConfig.Movement.SprintSpeed * config.SpeedMultiplier
		Services.AntiCheatService:GrantMovement(combatant.Player, speed, 0, config.Duration + 0.5)
	end
	task.delay(config.Duration, function()
		if states[combatant.Id] == state and state.PhaseToken == token and character.Parent then
			character:SetAttribute("Phased", false)
		end
	end)
end

function Implementations.Shield(combatant, config, payload)
	local look = MathUtil.SafeUnit(MathUtil.Flatten(lookDirection(combatant, payload)), combatant.Root.CFrame.LookVector)
	local position = combatant.Root.Position + look * config.Distance + Vector3.new(0, 1, 0)
	local barrier = Instance.new("Part")
	barrier.Name = "Barrier"
	barrier.Size = config.Size
	barrier.CFrame = CFrame.lookAt(position, position + look)
	barrier.Anchored = true
	barrier.CanCollide = false -- players walk through; shots don't
	barrier.CanTouch = false
	barrier.CanQuery = true
	barrier.CastShadow = false
	barrier.Material = Enum.Material.ForceField
	barrier.Color = teamColor(combatant)
	barrier.Transparency = 0.1
	barrier:SetAttribute("OwnerId", combatant.Id)
	barrier:SetAttribute("Team", combatant.Team)
	CollectionService:AddTag(barrier, RaycastUtil.Tags.ShotBlocker)
	barrier.Parent = RaycastUtil.GetContainer(RaycastUtil.Containers.AbilityObjects)
	Debris:AddItem(barrier, config.Duration)
end

function Implementations.Decoy(combatant, config, payload)
	local character = combatant.Character
	local wasArchivable = character.Archivable
	character.Archivable = true
	local decoy = character:Clone()
	character.Archivable = wasArchivable
	if not decoy then
		return
	end
	decoy.Name = combatant.Name
	decoy:SetAttribute("CombatantId", nil)
	decoy:SetAttribute("OwnerId", combatant.Id)
	decoy:SetAttribute("Team", combatant.Team)
	for _, descendant in decoy:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanTouch = false
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.85
	highlight.OutlineTransparency = 0.6
	highlight.FillColor = config.Color
	highlight.OutlineColor = config.Color
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = decoy
	CollectionService:AddTag(decoy, RaycastUtil.Tags.Decoy)
	decoy.Parent = RaycastUtil.GetContainer(RaycastUtil.Containers.AbilityObjects)

	local root = decoy:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = decoy:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		humanoid.WalkSpeed = config.RunSpeed
		local look = MathUtil.SafeUnit(MathUtil.Flatten(lookDirection(combatant, payload)), root.CFrame.LookVector)
		humanoid:MoveTo(root.Position + look * config.RunSpeed * config.Duration)
	end
	Debris:AddItem(decoy, config.Duration)
end

function Implementations.Pulse(combatant, config, _payload)
	local CombatantService = Services.CombatantService
	local origin = combatant.Root.Position
	local revealed = {}
	local revealedPlayers = {}
	for _, other in CombatantService:GetInMatch() do
		if CombatantService:IsAlive(other) and CombatantService:AreEnemies(combatant, other) then
			if (other.Root.Position - origin).Magnitude <= config.Radius then
				table.insert(revealed, other.Character)
				if other.Player then
					table.insert(revealedPlayers, other.Player)
				end
			end
		end
	end
	local remote = Net.Event("Abilities", "AbilityEffect")
	local payload = { Kind = "Reveal", Targets = revealed, Duration = config.RevealDuration, Origin = origin, Radius = config.Radius }
	for _, ally in CombatantService:GetInMatch() do
		if ally.Player and (ally == combatant or (ally.Team ~= nil and ally.Team == combatant.Team)) then
			remote:FireClient(ally.Player, payload)
		end
	end
	-- Fair counterplay: revealed players are told they were scanned.
	for _, player in revealedPlayers do
		remote:FireClient(player, { Kind = "Revealed", Duration = config.RevealDuration })
	end
	Services.BotService:OnPulse(combatant, revealed, config.RevealDuration)
end

function Implementations.Gravity(combatant, config, payload)
	local head = Services.CombatantService:GetHeadPosition(combatant) or combatant.Root.Position
	local target = if type(payload) == "table" then payload.Target else nil
	local position
	if typeof(target) == "Vector3" and MathUtil.IsFiniteVector(target) and (target - head).Magnitude <= config.Range + 2 then
		local params = RaycastUtil.WorldParams()
		if RaycastUtil.HasLineOfSight(head, target, params, 2) then
			position = target
		end
	end
	position = position or (combatant.Root.Position + combatant.Root.CFrame.LookVector * 8)

	local field = Instance.new("Part")
	field.Name = "GravityField"
	field.Shape = Enum.PartType.Ball
	field.Size = Vector3.one * config.Radius * 2
	field.Position = position
	field.Anchored = true
	field.CanCollide = false
	field.CanQuery = false
	field.CanTouch = false
	field.CastShadow = false
	field.Material = Enum.Material.ForceField
	field.Color = config.Color
	field.Transparency = 0.2
	field:SetAttribute("Radius", config.Radius)
	field:SetAttribute("Multiplier", config.GravityMultiplier)
	CollectionService:AddTag(field, RaycastUtil.Tags.GravityField)
	field.Parent = RaycastUtil.GetContainer(RaycastUtil.Containers.AbilityObjects)
	Debris:AddItem(field, config.Duration)
end

-- Validates and runs an ability. Returns true on success.
function AbilityService:TryUse(combatant, slot: string, payload): boolean
	local state = states[combatant.Id]
	if not state or (slot ~= "Movement" and slot ~= "Tactical") then
		return false
	end
	if not Services.CombatantService:IsAlive(combatant) then
		return false
	end
	local slotState: SlotState = state[slot]
	local config = AbilityConfig.Get(slotState.Id)
	if not config then
		return false
	end
	if slot == "Tactical" and not (combatant.InMatch and Services.MatchService:IsCombatActive()) then
		return false
	end
	local now = os.clock()
	if now < slotState.ReadyAt - AbilityConfig.CooldownTolerance then
		if combatant.Player then
			Services.AntiCheatService:Flag(combatant.Player, "AbilityCooldown", slotState.Id)
		end
		AbilityService:SendState(combatant)
		return false
	end
	slotState.ReadyAt = now + config.Cooldown
	local implementation = Implementations[slotState.Id]
	if implementation then
		implementation(combatant, config, payload)
	end
	AbilityService:SendState(combatant)
	return true
end

function AbilityService:HitDecoy(decoy: Model, attacker)
	if not decoy.Parent then
		return
	end
	local ownerId = decoy:GetAttribute("OwnerId")
	local owner = Services.CombatantService:Get(ownerId)
	if owner and not Services.CombatantService:AreEnemies(attacker, owner) then
		return
	end
	local root = decoy:FindFirstChild("HumanoidRootPart")
	local position = if root and root:IsA("BasePart") then root.Position else decoy:GetPivot().Position
	Net.Event("Abilities", "AbilityEffect"):FireAllClients({ Kind = "DecoyPopped", Position = position })
	if attacker.Player then
		Net.Event("Combat", "HitConfirm"):FireClient(attacker.Player, { Decoy = true, Position = position })
	end
	decoy:Destroy()
end

function AbilityService:GetState(combatant)
	return states[combatant.Id]
end

function AbilityService:Init(services)
	Services = services
	Net.OnServerEvent("Abilities", "UseAbility", function(player, slot, payload)
		local combatant = Services.CombatantService:GetByPlayer(player)
		if combatant and type(slot) == "string" then
			AbilityService:TryUse(combatant, slot, payload)
		end
	end, { Rate = 4, Burst = 6 })
end

function AbilityService:Start()
	Services.CombatantService.Removed:Connect(function(combatant)
		states[combatant.Id] = nil
	end)
end

AbilityService._implementations = Implementations

return AbilityService
