--!strict
-- Central RemoteEvent/RemoteFunction registry. Every remote used by the game is
-- declared here and created once under ReplicatedStorage.Remotes by the server
-- bootstrap (Main.server.lua) before any service starts - this avoids the
-- "FindFirstChild race" bug class and gives one place to audit every
-- client<->server surface for the security review pass.
--
-- IMPORTANT: every RemoteEvent handler on the server must treat its arguments
-- as hostile input - see CombatService/InventoryService for the validation
-- pattern (ownership check, magnitude/range sanity check, cooldown timestamp
-- check, rate limit). This module only declares the wire surface, it does not
-- grant trust.

local Remotes = {}

Remotes.Events = {
	-- Combat: client requests an attack attempt, server resolves hit detection,
	-- damage, and status application authoritatively and replicates the result.
	"RequestAttack",
	"RequestDodge",
	"RequestAbilityCast",
	"RequestInterruptCast", -- for casters that can be interrupted mid-cast (ranged caster archetype hook)
	"CombatResult", -- server -> client: damage numbers, hit-pause cue, status applied

	-- Movement-adjacent, still server-validated (e.g. dash distance clamped server-side)
	"RequestDash",

	-- Inventory / itemization
	"RequestEquipItem",
	"RequestUnequipItem",
	"RequestUseConsumable",
	"RequestDropItem",
	"InventoryUpdated", -- server -> client push after any authoritative inventory change

	-- Progression / meta
	"RequestSelectTalent",
	"RequestSelectRelic", -- floor-transition relic offer pick
	"RelicOfferPresented", -- server -> client: the 3-option relic choice for this floor transition
	"ProgressionUpdated",

	-- Economy / hub
	"RequestPurchase",
	"RequestBankDeposit",
	"RequestBankWithdraw",
	"EconomyUpdated",

	-- Dungeon / run flow
	"RunStarted",
	"FloorTransition", -- server -> client: new floor loaded, triggers transition/reward screen
	"RunEnded", -- server -> client: death or extraction, carries run-summary stat breakdown
	"DifficultyModifiersChanged", -- ante/pact-style optional modifier selection before a run

	-- Boss
	"BossIntroCinematic", -- server -> client: camera pan/UI banner cue
	"BossPhaseTransition",

	-- Party / co-op (config-flag gated, see PartyService)
	"RequestPartyInvite",
	"RequestPartyJoin",
	"PartyUpdated",
}

Remotes.Functions = {
	-- Request/response calls where the client needs a synchronous authoritative
	-- answer (e.g. "can I afford this" before playing a purchase animation).
	"GetInventorySnapshot",
	"GetProgressionSnapshot",
	"GetShopCatalog",
}

-- Idempotent: safe to call from both the server bootstrap (which creates) and
-- any script needing a reference (which just reads what bootstrap made).
function Remotes.EnsureFolder(parent: Instance): Folder
	local folder = parent:FindFirstChild("Remotes") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = parent
	end
	return folder :: Folder
end

function Remotes.CreateAll(remotesFolder: Folder)
	for _, eventName in Remotes.Events do
		if not remotesFolder:FindFirstChild(eventName) then
			local event = Instance.new("RemoteEvent")
			event.Name = eventName
			event.Parent = remotesFolder
		end
	end
	for _, funcName in Remotes.Functions do
		if not remotesFolder:FindFirstChild(funcName) then
			local func = Instance.new("RemoteFunction")
			func.Name = funcName
			func.Parent = remotesFolder
		end
	end
end

function Remotes.Get(remotesFolder: Folder, name: string): RemoteEvent | RemoteFunction
	local remote = remotesFolder:FindFirstChild(name)
	assert(remote, `Remote "{name}" was not found - was Remotes.CreateAll run by bootstrap?`)
	return remote :: RemoteEvent | RemoteFunction
end

return Remotes
