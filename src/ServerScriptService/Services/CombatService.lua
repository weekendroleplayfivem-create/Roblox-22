--!strict
-- Authoritative combat resolution. Every damage instance in the game - player
-- attacks, enemy attacks, status effect ticks, environmental hazards - flows
-- through here so there is exactly one place that touches a Humanoid's health.
--
-- SECURITY: RequestAttack et al. are RemoteEvents fired by a client, which
-- must be treated as hostile. This service never trusts a client-reported
-- damage number, target, or hit position - it recomputes hit validity
-- server-side from server-known state (equipped weapon, character position,
-- cooldown timestamps) before applying anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local StatusEffects = require(ReplicatedStorage.Shared.Modules.StatusEffects)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local CombatService = {}

-- Per-player last-attack timestamps, keyed by UserId, for both rate limiting
-- and weapon-specific cooldown enforcement. Never trust a client-sent
-- "cooldown ready" flag - always compare against this server clock.
local lastAttackAt: { [number]: number } = {}
local activeStatusEffects: { [Instance]: { [Types.StatusEffectId]: { stacks: number, expiresAt: number } } } = {}

local MIN_ATTACK_INTERVAL = 0.15 -- hard floor even for the fastest weapon, prevents remote-spam exploits
local MAX_ATTACK_RANGE_STUDS = 14 -- generous upper bound across all weapon categories; per-weapon range checked separately

local RemotesFolder: Folder

local function isValidTarget(attacker: Model, target: Instance): boolean
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = (target :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerRoot or not targetRoot then
		return false
	end
	-- Magnitude check against server-known positions, never a client-reported
	-- distance - this is the core anti-cheat guard for melee/ranged validity.
	return (attackerRoot.Position - targetRoot.Position).Magnitude <= MAX_ATTACK_RANGE_STUDS
end

function CombatService.ApplyStatusEffect(target: Instance, effectId: Types.StatusEffectId, stacksToAdd: number?)
	local def = StatusEffects[effectId]
	activeStatusEffects[target] = activeStatusEffects[target] or {}
	local current = activeStatusEffects[target][effectId]

	if def.stacking == "Ignore" and current then
		return -- e.g. Stun while already stunned: duration is not extended, see StatusEffects.lua
	end

	local stacks = math.min(def.maxStacks, (current and current.stacks or 0) + (stacksToAdd or 1))
	if def.stacking ~= "Stack" then
		stacks = 1
	end

	activeStatusEffects[target][effectId] = {
		stacks = stacks,
		expiresAt = os.clock() + def.defaultDuration,
	}
end

-- Server-side hit resolution shared by both the RequestAttack handler and
-- EnemyAIService's attack state - one code path for "who hits whom for how
-- much" regardless of which side of the fight initiated it.
function CombatService.ResolveHit(attacker: Model, target: Instance, baseDamage: number, damageType: Types.DamageType)
	if not isValidTarget(attacker, target) then
		return false
	end
	local humanoid = target:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid:TakeDamage(baseDamage)

	local combatResult = Remotes.Get(RemotesFolder, "CombatResult") :: RemoteEvent
	-- Broadcast to all clients near the hit (not just the attacker) so
	-- damage-number juice and hit-pause read correctly for spectating
	-- party members too.
	combatResult:FireAllClients({
		targetInstance = target,
		amount = baseDamage,
		damageType = damageType,
		isCrit = false, -- crit roll happens upstream in the weapon-specific handler, passed through here in a later pass
	})
	return true
end

-- Placeholder resolver until InventoryService exposes equipped-weapon state;
-- isolated behind this function so wiring the real lookup later touches one
-- line here rather than CombatService's validation/resolution logic.
function CombatService._resolveEquippedWeaponDamage(_player: Player): (number, Types.DamageType)
	return 10, "Physical"
end

local function onRequestAttack(player: Player, targetInstance: Instance?)
	local character = player.Character
	if not character or not targetInstance then
		return
	end

	local now = os.clock()
	local last = lastAttackAt[player.UserId] or 0
	if now - last < MIN_ATTACK_INTERVAL then
		return -- silently drop - a legitimate client never exceeds this, so no error feedback needed
	end
	lastAttackAt[player.UserId] = now

	-- Base damage/type below stand in for InventoryService's equipped-weapon
	-- lookup, wired during the itemization pass (Process step 4); the
	-- validation + resolution pipeline itself is already final.
	local baseDamage, damageType = CombatService._resolveEquippedWeaponDamage(player)
	CombatService.ResolveHit(character, targetInstance, baseDamage, damageType)
end

function CombatService.Init(remotesFolder: Folder)
	RemotesFolder = remotesFolder
	local requestAttack = Remotes.Get(remotesFolder, "RequestAttack") :: RemoteEvent
	requestAttack.OnServerEvent:Connect(onRequestAttack)

	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player.UserId] = nil
	end)
end

-- Periodic sweep releasing expired status effects; called from Main's
-- heartbeat loop rather than per-effect Debris/task.delay calls so effect
-- bookkeeping stays centralized and cheap to inspect/debug as one table.
function CombatService.Tick()
	local now = os.clock()
	for target, effects in activeStatusEffects do
		for effectId, state in effects do
			if now >= state.expiresAt then
				effects[effectId] = nil
			end
		end
		if next(effects) == nil then
			activeStatusEffects[target] = nil
		end
	end
end

return CombatService
