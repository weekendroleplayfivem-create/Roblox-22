--!nonstrict
--[[
	AbilityController.luau
	Client-side ability prediction + presentation.

	The client fires the ability immediately and tells the server. The server owns
	the cooldown ledger and can reject (Services/AbilityService); a rejection
	rolls the local charge back and refunds it in the HUD. Predicting is what makes
	a dash feel like it belongs to your hand rather than to the network.

	Charges recover independently and on a stagger, so banking one for a rotation
	is a real choice instead of a "use it the moment it's up" reflex.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local AbilityConfig = require(Root.Config.AbilityConfig)
local Signal = require(Root.Util.Signal)
local Trove = require(Root.Util.Trove)
local Net = require(Root.Util.Net)

local AbilityController = {}
AbilityController.__index = AbilityController

local ACTION_TO_ABILITY = {
	Ability1 = "HyperDash",
	Ability2 = "PhaseStep",
	Ability3 = "Overdrive",
}

function AbilityController.new(context)
	local self = setmetatable({}, AbilityController)

	self.context = context
	self.input = context.Input
	self._trove = Trove.new()

	self.states = {}
	for _, id in AbilityConfig.Slots do
		local definition = AbilityConfig.get(id)
		self.states[id] = {
			definition = definition,
			charges = definition.Charges,
			maxCharges = definition.Charges,
			rechargeEndsAt = {}, -- one timer per recovering charge
			activeUntil = 0,
			enabled = true,
		}
	end

	self.AbilityUsed = Signal.new()
	self.AbilityStateChanged = Signal.new()
	self.enabled = true

	return self
end

function AbilityController:Start()
	self._trove:Connect(self.input.ActionPressed, function(action)
		local id = ACTION_TO_ABILITY[action]
		if id then
			self:TryUse(id)
		end
	end)

	-- Server correction. It is authoritative on charges; we snap to whatever it
	-- says rather than trying to reconcile, because an ability the server thinks
	-- you don't have is an ability you don't have.
	self._trove:Add(Net.onClient("AbilityState", function(payload)
		local state = self.states[payload.id]
		if not state then
			return
		end
		if payload.rejected then
			-- Refund the optimistic spend.
			state.charges = math.min(state.maxCharges, payload.charges or (state.charges + 1))
			self.context.HUD:FlashAbilityDenied(payload.id)
		else
			state.charges = payload.charges or state.charges
		end
		state.rechargeEndsAt = payload.rechargeEndsAt or state.rechargeEndsAt
		if payload.activeUntil then
			state.activeUntil = payload.activeUntil
		end
		self.AbilityStateChanged:FireSync(payload.id, state)
	end))

	self._trove:Add(RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end))

	return self
end

----------------------------------------------------------------------
-- Use
----------------------------------------------------------------------

function AbilityController:CanUse(id: string): boolean
	local state = self.states[id]
	if not state or not self.enabled or not state.enabled then
		return false
	end
	if self.context.Movement.modifiers.frozen then
		return false
	end
	local humanoid = self.context.Movement.humanoid
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	return state.charges > 0
end

function AbilityController:TryUse(id: string): boolean
	if not self:CanUse(id) then
		self.context.HUD:FlashAbilityDenied(id)
		return false
	end

	local state = self.states[id]
	local definition = state.definition
	local executed = false

	if id == "HyperDash" then
		executed = self.context.Movement:StartDash(definition)
	elseif id == "PhaseStep" then
		executed = self:_usePhaseStep(definition)
	elseif id == "Overdrive" then
		executed = self:_useOverdrive(definition)
	end

	if not executed then
		return false -- the movement system refused (no direction, blocked blink)
	end

	-- Optimistic spend + local cooldown, then tell the server.
	state.charges -= 1
	table.insert(state.rechargeEndsAt, os.clock() + definition.Cooldown)
	table.sort(state.rechargeEndsAt)

	Net.toServer("UseAbility", id, workspace:GetServerTimeNow())
	self.AbilityUsed:FireSync(id, definition)
	self.AbilityStateChanged:FireSync(id, state)
	return true
end

function AbilityController:_usePhaseStep(definition): boolean
	local character = self.context.Movement.character
	if not character then
		return false
	end

	local started = self.context.Movement:StartPhase(definition)
	if not started then
		return false
	end

	-- Holographic decoys: they trail the blink, so an enemy tracking you gets a
	-- moment of ambiguity about which shape is real.
	self.context.Effects:PhaseAfterimages(character, definition)
	return true
end

function AbilityController:_useOverdrive(definition): boolean
	local state = self.states.Overdrive
	state.activeUntil = os.clock() + definition.Duration

	self.context.Movement:ApplyOverdrive(definition, true)
	self.context.Effects:OverdriveStart(definition, definition.Duration)
	self.context.HUD:SetOverdrive(true, definition.Duration)

	task.delay(definition.Duration, function()
		if os.clock() >= state.activeUntil - 0.05 then
			self.context.Movement:ApplyOverdrive(definition, false)
			self.context.Effects:OverdriveEnd(definition)
			self.context.HUD:SetOverdrive(false, 0)
		end
	end)

	return true
end

----------------------------------------------------------------------
-- Modifiers other controllers ask about
----------------------------------------------------------------------

function AbilityController:IsOverdriveActive(): boolean
	return os.clock() < self.states.Overdrive.activeUntil
end

function AbilityController:GetReloadMultiplier(): number
	return self:IsOverdriveActive() and AbilityConfig.get("Overdrive").ReloadMultiplier or 1
end

function AbilityController:GetSwapMultiplier(): number
	return self:IsOverdriveActive() and AbilityConfig.get("Overdrive").SwapMultiplier or 1
end

function AbilityController:GetState(id: string)
	return self.states[id]
end

--[[ Modes can disable abilities (Core Rush carriers, Hyper Duel rules). ]]
function AbilityController:SetAbilityEnabled(id: string, enabled: boolean)
	local state = self.states[id]
	if state then
		state.enabled = enabled
	end
end

function AbilityController:SetEnabled(enabled: boolean)
	self.enabled = enabled
end

function AbilityController:ResetAll()
	for id, state in self.states do
		state.charges = state.maxCharges
		table.clear(state.rechargeEndsAt)
		state.activeUntil = 0
		self.AbilityStateChanged:FireSync(id, state)
	end
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------

function AbilityController:_update(_dt: number)
	local now = os.clock()

	for id, state in self.states do
		local timers = state.rechargeEndsAt
		local recovered = false

		while #timers > 0 and now >= timers[1] do
			table.remove(timers, 1)
			state.charges = math.min(state.charges + 1, state.maxCharges)
			recovered = true
		end

		if recovered then
			self.context.HUD:FlashAbilityReady(id)
			self.AbilityStateChanged:FireSync(id, state)
		end
	end
end

--[[ 0..1 progress of the next recovering charge, for the HUD's radial. ]]
function AbilityController:GetCooldownAlpha(id: string): number
	local state = self.states[id]
	if not state or #state.rechargeEndsAt == 0 then
		return 1
	end
	local remaining = state.rechargeEndsAt[1] - os.clock()
	return math.clamp(1 - remaining / state.definition.Cooldown, 0, 1)
end

function AbilityController:Destroy()
	self._trove:Clean()
end

return AbilityController
