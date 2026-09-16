--!strict
-- Co-op party grouping. Depths launches solo-first (CO_OP_ENABLED = false),
-- but CombatService/DungeonGenerator/InventoryService are all written against
-- a player-or-party notion of "run owner" rather than a single Player, so
-- flipping this flag on is a config change, not a rewrite - see how
-- ProgressionService keys state by UserId today; the party-aware version
-- keys the same tables by PartyId with a 1-member default party per solo
-- player, which is why UserId-keyed tables elsewhere were kept behind
-- Get()-style accessors instead of direct table access.
local Players = game:GetService("Players")
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Modules.Remotes)

local PartyService = {}

PartyService.CO_OP_ENABLED = false

export type Party = {
	id: string,
	members: { Player },
	leaderUserId: number,
}

local partiesByPlayer: { [number]: Party } = {}
local RemotesFolder: Folder

local function newSoloParty(player: Player): Party
	return { id = `solo_{player.UserId}`, members = { player }, leaderUserId = player.UserId }
end

function PartyService.GetParty(player: Player): Party
	local party = partiesByPlayer[player.UserId]
	if not party then
		party = newSoloParty(player)
		partiesByPlayer[player.UserId] = party
	end
	return party
end

local function onRequestPartyInvite(player: Player, targetUserId: number?)
	if not PartyService.CO_OP_ENABLED then
		return
	end
	if typeof(targetUserId) ~= "number" then
		return
	end
	-- Invite/accept flow wired alongside co-op enablement; the config-flag
	-- gate above is what keeps this a no-op in the solo-first launch config.
end

function PartyService.Init(remotesFolder: Folder)
	RemotesFolder = remotesFolder
	(Remotes.Get(remotesFolder, "RequestPartyInvite") :: RemoteEvent).OnServerEvent:Connect(onRequestPartyInvite)

	Players.PlayerRemoving:Connect(function(player)
		partiesByPlayer[player.UserId] = nil
	end)
end

return PartyService
