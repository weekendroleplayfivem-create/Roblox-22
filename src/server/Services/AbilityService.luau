--!nonstrict
--[[
	AbilityService.luau
	The authoritative cooldown ledger.

	The client predicts an ability the instant you press it (see the client's
	AbilityController) and tells us afterwards. Our job is to keep a ledger that
	the client cannot lie to, and to reject anything that doesn't fit - at which
	point the client refunds its optimistic spend and the HUD flashes.

	We are deliberately GENEROUS on timing (AbilityConfig.Validation.CooldownGrace)
	and STRICT on counting. A player on a 180ms connection should never be told
	"no" for being 40ms early, but nobody gets a fourth dash out of two charges.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local AbilityConfig = require(Root.Config.AbilityConfig)
local Signal = require(Root.Util.Signal)
local Net = require(Root.Util.Net)

local AbilityService = {}
AbilityService.__index = AbilityService

function AbilityService.new(services)
	local self = setmetatable({}, AbilityService)

	self.services = services
	self.ledgers = {} :: { [Player]: any }
	self.AbilityUsed = Signal.new()
	self._limiter = Net.RateLimiter.new(12, 1)

	return self
end

function AbilityService:Start()
	Net.onServer("UseAbility", function(player, id, clientTime)
		if not self._limiter:Check(player) then
			return
		end
		self:_handleUse(player, id, clientTime)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:ResetPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		self:ResetPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self.ledgers[player] = nil
		self._limiter:Clear(player)
	end)

	self.services.Player.CharacterSpawned:Connect(function(player)
		self:ResetPlayer(player)
	end)

	return self
end

function AbilityService:ResetPlayer(player: Player)
	local ledger = {}
	for id, definition in AbilityConfig.Abilities do
		ledger[id] = {
			charges = definition.Charges,
			maxCharges = definition.Charges,
			rechargeEndsAt = {},
			activeUntil = 0,
			enabled = true,
		}
	end
	self.ledgers[player] = ledger

	for id, state in ledger do
		Net.toClient("AbilityState", player, {
			id = id,
			charges = state.charges,
			rechargeEndsAt = {},
		})
	end
end

function AbilityService:_refreshCharges(state, definition)
	local now = os.clock()
	while #state.rechargeEndsAt > 0 and now >= state.rechargeEndsAt[1] do
		table.remove(state.rechargeEndsAt, 1)
		state.charges = math.min(state.charges + 1, state.maxCharges)
	end
	local _ = definition
end

function AbilityService:_handleUse(player: Player, id: string, clientTime: number?)
	local definition = AbilityConfig.get(id)
	local ledger = self.ledgers[player]
	if not definition or not ledger then
		return
	end

	local state = ledger[id]
	local playerService = self.services.Player

	local function reject()
		Net.toClient("AbilityState", player, {
			id = id,
			rejected = true,
			charges = state and state.charges or 0,
			rechargeEndsAt = state and state.rechargeEndsAt or {},
		})
	end

	if not state or not playerService:IsAlive(player) then
		reject()
		return
	end

	-- Mode rules (Hyper Duel disables Overdrive; a Core Rush carrier loses Phase
	-- Step) are authoritative here, not on the client.
	if not self.services.Match:IsAbilityAllowed(player, id) then
		reject()
		return
	end

	self:_refreshCharges(state, definition)

	if state.charges <= 0 then
		-- Grace: if the next charge is within the network slack, allow it. This is
		-- the difference between "responsive" and "the server ate my dash".
		local nextCharge = state.rechargeEndsAt[1]
		if not nextCharge or nextCharge - os.clock() > AbilityConfig.Validation.CooldownGrace then
			reject()
			return
		end
		table.remove(state.rechargeEndsAt, 1)
		state.charges += 1
	end

	state.charges -= 1
	table.insert(state.rechargeEndsAt, os.clock() + definition.Cooldown)
	table.sort(state.rechargeEndsAt)

	if id == "Overdrive" then
		state.activeUntil = os.clock() + definition.Duration
	end

	Net.toClient("AbilityState", player, {
		id = id,
		charges = state.charges,
		rechargeEndsAt = state.rechargeEndsAt,
		activeUntil = state.activeUntil,
	})

	-- Replicate the cosmetic side to everyone else so an enemy can SEE the dash
	-- coming. Abilities that are invisible to opponents are not counterplayable.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		Net.toOtherClients("EffectBroadcast", player, id == "PhaseStep" and "Phase" or "Dash", {
			position = root.Position,
			direction = root.CFrame.LookVector,
			from = root.Position,
			to = root.Position + root.CFrame.LookVector * (definition.Distance or 0),
		})
	end

	self.AbilityUsed:Fire(player, id, definition)
	local _ = clientTime
end

function AbilityService:IsOverdriveActive(player: Player): boolean
	local ledger = self.ledgers[player]
	return ledger ~= nil and os.clock() < (ledger.Overdrive and ledger.Overdrive.activeUntil or 0)
end

function AbilityService:GetLedger(player: Player)
	return self.ledgers[player]
end

--[[ The server's own view of a player's maximum legitimate speed right now,
	 used by MovementGuard so an Overdrive sprint is never flagged. ]]
function AbilityService:GetSpeedMultiplier(player: Player): number
	if self:IsOverdriveActive(player) then
		return AbilityConfig.get("Overdrive").SpeedMultiplier
	end
	return 1
end

return AbilityService
