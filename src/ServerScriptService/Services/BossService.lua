--!strict
-- Boss encounter orchestration: phase tracking driven by health thresholds
-- (not timers), telegraph dispatch, and phase-transition mechanics
-- (arena change / add-spawn / enrage). Kept separate from EnemyAIService
-- because bosses need scripted, authored phase sequencing rather than a
-- generic archetype state machine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local BossService = {}

type BossInstance = {
	model: Model,
	def: Types.BossDef,
	currentPhaseIndex: number,
	enrageStartedAt: number?,
}

local activeBosses: { [Model]: BossInstance } = {}
local RemotesFolder: Folder

function BossService.Init(remotesFolder: Folder)
	RemotesFolder = remotesFolder
end

function BossService.Spawn(bossDef: Types.BossDef, model: Model): BossInstance
	local instance: BossInstance = {
		model = model,
		def = bossDef,
		currentPhaseIndex = 1,
		enrageStartedAt = nil,
	}
	activeBosses[model] = instance

	local intro = Remotes.Get(RemotesFolder, "BossIntroCinematic") :: RemoteEvent
	intro:FireAllClients({ bossId = bossDef.id, introCinematicId = bossDef.introCinematicId })

	model.Destroying:Connect(function()
		activeBosses[model] = nil
	end)
	return instance
end

-- Called whenever a boss takes damage. Health is read as a fraction (0-1) so
-- phase thresholds in BossDef are readable design values, not raw HP numbers
-- that would need updating every time base health is rebalanced.
function BossService.OnDamageTaken(model: Model, healthFraction: number)
	local instance = activeBosses[model]
	if not instance then
		return
	end

	local phases = instance.def.phases
	local nextPhase = phases[instance.currentPhaseIndex + 1]
	if nextPhase and healthFraction <= nextPhase.healthThreshold then
		BossService._transitionToPhase(instance, nextPhase)
	end
end

function BossService._transitionToPhase(instance: BossInstance, phase: Types.BossPhaseDef)
	instance.currentPhaseIndex = phase.phaseIndex

	local transitionEvent = Remotes.Get(RemotesFolder, "BossPhaseTransition") :: RemoteEvent
	-- Camera punch-in and UI banner cues fire client-side off this same
	-- event, so the phase-transition "juice" beat is always in sync with the
	-- authoritative moment the phase actually changed, never estimated
	-- client-side from a health-bar watch.
	transitionEvent:FireAllClients({
		bossId = instance.def.id,
		phaseIndex = phase.phaseIndex,
		telegraphs = phase.telegraphs,
		transitionMechanic = phase.transitionMechanic,
	})

	if phase.transitionMechanic == "EnrageTimer" then
		instance.enrageStartedAt = os.clock()
	elseif phase.transitionMechanic == "AddWave" then
		BossService._spawnPhaseAdds(instance)
	elseif phase.transitionMechanic == "ArenaCollapse" then
		BossService._collapseArena(instance)
	end
end

function BossService._spawnPhaseAdds(_instance: BossInstance)
	-- Delegates to DungeonGenerator's vault-spawn table for the boss's arena
	-- vault; wired once vault Models are authored in Studio content pass.
end

function BossService._collapseArena(_instance: BossInstance)
	-- Toggles a subset of the arena vault's hazard-tagged parts (see
	-- Molten Forge's HazardGrid tiles) to their active state; wired once
	-- arena vault Models are authored in Studio content pass.
end

function BossService.GetEnrageMultiplier(model: Model): number
	local instance = activeBosses[model]
	if not instance or not instance.enrageStartedAt then
		return 1
	end
	local elapsed = os.clock() - instance.enrageStartedAt
	-- Attack-speed ramp readable as a visible timer in the boss HUD widget,
	-- not a hidden stat - "Readable chaos" requires the player be able to
	-- see the enrage clock, not just feel its effect.
	return 1 + math.min(elapsed / 30, 1) * 0.8
end

return BossService
