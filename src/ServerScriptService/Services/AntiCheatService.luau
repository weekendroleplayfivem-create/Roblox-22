--[[
	AntiCheatService
	Basic server-side protection. Philosophy:
	  * Validation first: invalid requests are simply rejected by the systems
	    that receive them (combat, weapons, abilities).
	  * Suspicion is scored. Each Flag adds weight that decays over time.
	    Single events never punish; only sustained high suspicion leads to a
	    (non-permanent) kick.
	  * Movement is checked against configured speeds plus temporary
	    "allowances" granted by legitimate actions (dash, jump pads, wall
	    jumps, slides). Impossible movement is corrected by moving the player
	    back to their last valid position.
	  * Internals are never revealed to players.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local MathUtil = require(Shared.Modules.MathUtil)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local WallMovement = require(Shared.Modules.WallMovement)

local AntiCheatService = {}

local MOVEMENT_ACTIONS = { Slide = true, DoubleJump = true, WallJump = true }
-- Extra wall-detection reach on the server to absorb latency.
local WALL_CHECK_SLACK = 3

-- Tuning (kept local because it is intentionally not shared with clients).
local SUSPICION_DECAY_PER_SECOND = 2
local CORRECTION_THRESHOLD = 40
local KICK_THRESHOLD = 400
local LOG_COOLDOWN = 5
local CHECK_INTERVAL = 0.1
local SPEED_TOLERANCE = 1.35 -- multiplier over the theoretical max
local FLAT_SPEED_SLACK = 6 -- studs/s for physics jitter
local TELEPORT_DISTANCE = 45 -- studs in one check without allowance
local MAX_UPWARD_SPEED = 95
local AIRTIME_LIMIT = 6 -- seconds airborne without an allowance
local GROUND_PROBE = Vector3.new(0, -6, 0)

local WEIGHTS = {
	SpeedHack = 6,
	Teleport = 25,
	NoClip = 20,
	Flight = 10,
	FireRate = 4,
	InvalidWeapon = 6,
	InvalidAmmo = 4,
	InvalidHit = 3,
	InvalidOrigin = 4,
	InvalidPayload = 8,
	AbilityCooldown = 3,
	RemoteSpam = 2,
}

type Allowance = { Speed: number, Vertical: number, ExpiresAt: number }

type State = {
	Suspicion: number,
	LastDecay: number,
	LastLog: number,
	Counters: { [string]: number },
	LastValidPosition: Vector3?,
	LastCheckPosition: Vector3?,
	LastCheckTime: number,
	Allowances: { Allowance },
	AirborneSince: number?,
	IgnoreUntil: number,
}

local states: { [Player]: State } = {}

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = {
			Suspicion = 0,
			LastDecay = os.clock(),
			LastLog = 0,
			Counters = {},
			LastValidPosition = nil,
			LastCheckPosition = nil,
			LastCheckTime = os.clock(),
			Allowances = {},
			AirborneSince = nil,
			IgnoreUntil = 0,
		}
		states[player] = state
	end
	return state
end

local function decay(state: State)
	local now = os.clock()
	state.Suspicion = math.max(0, state.Suspicion - (now - state.LastDecay) * SUSPICION_DECAY_PER_SECOND)
	state.LastDecay = now
end

-- Records a suspicious event. `category` should be a key of WEIGHTS.
function AntiCheatService:Flag(player: Player?, category: string, detail: string?)
	if not player or not player.Parent then
		return
	end
	local state = getState(player)
	decay(state)
	local baseCategory = string.match(category, "^[^:]+") or category
	local weight = WEIGHTS[baseCategory] or 2
	state.Suspicion += weight
	state.Counters[baseCategory] = (state.Counters[baseCategory] or 0) + 1

	local now = os.clock()
	if now - state.LastLog > LOG_COOLDOWN then
		state.LastLog = now
		-- Server log only; players never see anti-cheat details.
		warn(string.format(
			"[AntiCheat] %s (%d) %s %s | suspicion=%.1f",
			player.Name,
			player.UserId,
			category,
			detail or "",
			state.Suspicion
		))
	end

	if state.Suspicion >= KICK_THRESHOLD and not RunService:IsStudio() then
		warn(string.format("[AntiCheat] Removing %s for sustained suspicious activity", player.Name))
		player:Kick("You were disconnected because of unusual activity. You are welcome to rejoin.")
	end
end

function AntiCheatService:GetSuspicion(player: Player): number
	local state = getState(player)
	decay(state)
	return state.Suspicion
end

function AntiCheatService:GetCounter(player: Player, category: string): number
	return getState(player).Counters[category] or 0
end

-- Allows faster-than-normal movement for a short window (dash, pads ...).
function AntiCheatService:GrantMovement(player: Player, speed: number, vertical: number, duration: number)
	local state = getState(player)
	table.insert(state.Allowances, {
		Speed = speed,
		Vertical = vertical,
		ExpiresAt = os.clock() + duration,
	})
	state.AirborneSince = nil
	-- The client usually starts the action slightly before this grant arrives;
	-- re-baseline so that head start isn't counted as a violation.
	state.LastCheckPosition = nil
end

-- Call after the server moves a character itself (spawn, respawn, teleport).
function AntiCheatService:ResetBaseline(player: Player, position: Vector3?, graceSeconds: number?)
	local state = getState(player)
	state.LastValidPosition = position
	state.LastCheckPosition = position
	state.LastCheckTime = os.clock()
	state.AirborneSince = nil
	state.IgnoreUntil = os.clock() + (graceSeconds or 1)
	table.clear(state.Allowances)
end

local function activeAllowance(state: State): (number, number)
	local now = os.clock()
	local speed, vertical = 0, 0
	for index = #state.Allowances, 1, -1 do
		local allowance = state.Allowances[index]
		if allowance.ExpiresAt < now then
			table.remove(state.Allowances, index)
		else
			speed = math.max(speed, allowance.Speed)
			vertical = math.max(vertical, allowance.Vertical)
		end
	end
	return speed, vertical
end

local function isInGravityField(position: Vector3): boolean
	for _, field in CollectionService:GetTagged(RaycastUtil.Tags.GravityField) do
		if field:IsA("BasePart") then
			local radius = field:GetAttribute("Radius") or field.Size.X / 2
			if (field.Position - position).Magnitude <= radius + 4 then
				return true
			end
		end
	end
	return false
end

local function correct(player: Player, root: BasePart, state: State, reason: string)
	if state.LastValidPosition then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(state.LastValidPosition) * root.CFrame.Rotation
		Net.Event("Movement", "Correction"):FireClient(player, reason)
	end
	state.LastCheckPosition = state.LastValidPosition
end

local function maxBaseSpeed(player: Player): number
	local movement = PlayerConfig.Movement
	local base = math.max(movement.SprintSpeed, movement.SlideSpeed)
	local character = player.Character
	if character and character:GetAttribute("Phased") then
		base *= AbilityConfig.Get("Phase").SpeedMultiplier
	end
	return base
end

local function checkPlayer(player: Player, now: number)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local state = getState(player)
	local position = root.Position
	if not state.LastCheckPosition or now < state.IgnoreUntil then
		state.LastCheckPosition = position
		state.LastValidPosition = position
		state.LastCheckTime = now
		return
	end

	local dt = math.max(now - state.LastCheckTime, 1 / 60)
	local delta = position - state.LastCheckPosition
	local horizontal = MathUtil.Flatten(delta).Magnitude / dt
	local vertical = delta.Y / dt
	local allowanceSpeed, allowanceVertical = activeAllowance(state)
	local allowedHorizontal = math.max(maxBaseSpeed(player), allowanceSpeed) * SPEED_TOLERANCE + FLAT_SPEED_SLACK

	-- Teleport: huge jump in one interval with no allowance.
	if delta.Magnitude > TELEPORT_DISTANCE and allowanceSpeed == 0 then
		AntiCheatService:Flag(player, "Teleport", string.format("%.1f studs", delta.Magnitude))
		correct(player, root, state, "Teleport")
		state.LastCheckTime = now
		return
	end

	-- No-clip: something solid between the last valid position and now.
	if state.LastValidPosition and delta.Magnitude > 2 then
		local params = RaycastUtil.WorldParams()
		local result = workspace:Raycast(state.LastCheckPosition, delta, params)
		if result and result.Instance.CanCollide and (result.Position - state.LastCheckPosition).Magnitude < delta.Magnitude - 1.5 then
			AntiCheatService:Flag(player, "NoClip", result.Instance:GetFullName())
			correct(player, root, state, "NoClip")
			state.LastCheckTime = now
			return
		end
	end

	local suspicious = false
	if horizontal > allowedHorizontal then
		AntiCheatService:Flag(player, "SpeedHack", string.format("%.1f > %.1f", horizontal, allowedHorizontal))
		suspicious = true
	end

	local gravityField = isInGravityField(position)
	if vertical > math.max(MAX_UPWARD_SPEED, allowanceVertical * SPEED_TOLERANCE) and not gravityField then
		AntiCheatService:Flag(player, "Flight", string.format("vy %.1f", vertical))
		suspicious = true
	end

	-- Sustained airtime without allowances or low-gravity fields.
	-- Ground check by raycast (FloorMaterial is computed on the owning client).
	local airborne = workspace:Raycast(position, GROUND_PROBE, RaycastUtil.WorldParams()) == nil
	if airborne and not gravityField and allowanceVertical == 0 then
		state.AirborneSince = state.AirborneSince or now
		if now - state.AirborneSince > AIRTIME_LIMIT and delta.Y > -0.5 then
			AntiCheatService:Flag(player, "Flight", "airtime")
			suspicious = true
		end
	else
		state.AirborneSince = nil
	end

	if suspicious and AntiCheatService:GetSuspicion(player) >= CORRECTION_THRESHOLD then
		correct(player, root, state, "Speed")
	else
		state.LastCheckPosition = position
		if not suspicious then
			state.LastValidPosition = position
		end
	end
	state.LastCheckTime = now
end

-- Clients report double jumps / wall jumps / slides. The server checks they
-- are plausible, resets airtime tracking and relays the cosmetic effect.
local function onMovementAction(player: Player, kind: any)
	if type(kind) ~= "string" or not MOVEMENT_ACTIONS[kind] then
		AntiCheatService:Flag(player, "InvalidPayload", "movement action")
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if kind == "WallJump" then
		if not WallMovement.IsEnabled() then
			AntiCheatService:Flag(player, "Flight", "wall jump disabled")
			return
		end
		local normal = WallMovement.FindWall(root.Position, RaycastUtil.WorldParams(), WALL_CHECK_SLACK)
		if not normal then
			AntiCheatService:Flag(player, "Flight", "wall jump without wall")
			return
		end
	end
	if kind ~= "Slide" then
		getState(player).AirborneSince = nil
	end
	local remote = Net.Event("Movement", "MovementFx")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			remote:FireClient(other, { Kind = kind, Character = character })
		end
	end
end

function AntiCheatService:Init()
	Net.SetViolationHandler(function(player, reason)
		AntiCheatService:Flag(player, reason)
	end)
	Net.OnServerEvent("Movement", "MovementAction", onMovementAction, { Rate = 6, Burst = 8 })
end

function AntiCheatService:Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < CHECK_INTERVAL then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			checkPlayer(player, now)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

-- Exposed for automated tests.
AntiCheatService._states = states
AntiCheatService._weights = WEIGHTS

return AntiCheatService
