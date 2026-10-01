--[[
	QueueService
	Simple in-server matchmaking queue.
	  * Players queue with an optional preferred mode (a vote).
	  * When enough players are queued and no match is running, a short
	    start countdown begins; the most-voted mode is played.
	  * Players can join a match already in progress (if there is room).
	  * Leaving a match only happens through RequestLeaveMatch, which goes
	    through MatchService so stats and teams stay consistent.

	MMR hook: `RankPlayers` is where skill-based sorting/splitting can be
	added later; today it keeps queue order.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local MatchConfig = require(Shared.Config.MatchConfig)

local QueueService = {}

local Services

type Entry = { Mode: string?, JoinedAt: number }

local queue: { [Player]: Entry } = {}
local startingAt: number? = nil -- os.clock() when the countdown ends

local function queuedPlayers(): { Player }
	local list = {}
	for player in queue do
		if player.Parent then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		return queue[a].JoinedAt < queue[b].JoinedAt
	end)
	return list
end

-- Future MMR integration point.
function QueueService:RankPlayers(players: { Player }): { Player }
	return players
end

function QueueService:GetVotes(): { [string]: number }
	local votes = {}
	for _, modeId in MatchConfig.ModeOrder do
		votes[modeId] = 0
	end
	for _, entry in queue do
		if entry.Mode and votes[entry.Mode] then
			votes[entry.Mode] += 1
		end
	end
	return votes
end

function QueueService:PickMode(): string
	local votes = QueueService:GetVotes()
	local best, bestCount, tied = nil, -1, {}
	for _, modeId in MatchConfig.ModeOrder do
		local count = votes[modeId]
		if count > bestCount then
			best, bestCount, tied = modeId, count, { modeId }
		elseif count == bestCount then
			table.insert(tied, modeId)
		end
	end
	if #tied > 1 then
		return tied[math.random(1, #tied)]
	end
	return best or MatchConfig.ModeOrder[1]
end

function QueueService:Broadcast()
	local remote = Net.Event("Match", "QueueState")
	local count = 0
	for player in queue do
		if player.Parent then
			count += 1
		end
	end
	local phase = Services.MatchService:GetPhase()
	local matchInfo = Services.MatchService:GetSummaryInfo()
	local startsAt = if startingAt then workspace:GetServerTimeNow() + (startingAt - os.clock()) else nil
	for _, player in Players:GetPlayers() do
		remote:FireClient(player, {
			Queued = queue[player] ~= nil,
			Mode = queue[player] and queue[player].Mode,
			Count = count,
			MinPlayers = MatchConfig.Queue.MinPlayers,
			Votes = QueueService:GetVotes(),
			StartsAt = startsAt,
			MatchPhase = phase,
			MatchMode = matchInfo.Mode,
			MatchMap = matchInfo.Map,
			CanJoinInProgress = Services.MatchService:CanJoinInProgress(),
		})
	end
end

function QueueService:AddPlayer(player: Player, mode: string?)
	if player:GetAttribute("Location") ~= "Lobby" then
		return
	end
	local combatant = Services.CombatantService:GetByPlayer(player)
	if not combatant or Services.MatchService:IsParticipant(combatant) then
		return
	end
	if mode ~= nil and (type(mode) ~= "string" or not MatchConfig.Modes[mode]) then
		mode = nil
	end
	if Services.MatchService:CanJoinInProgress() then
		queue[player] = nil
		Services.MatchService:AddLatecomer(player)
		QueueService:Broadcast()
		return
	end
	local existing = queue[player]
	queue[player] = { Mode = mode, JoinedAt = if existing then existing.JoinedAt else os.clock() }
	QueueService:Broadcast()
end

function QueueService:RemovePlayer(player: Player)
	if queue[player] then
		queue[player] = nil
		QueueService:Broadcast()
	end
end

function QueueService:IsQueued(player: Player): boolean
	return queue[player] ~= nil
end

-- Called by MatchService when a match finishes and the lobby is free.
function QueueService:OnLobbyFree()
	startingAt = nil
	QueueService:Broadcast()
end

local function tick()
	if Services.MatchService:GetPhase() ~= "Lobby" then
		startingAt = nil
		return
	end
	local players = queuedPlayers()
	if #players < MatchConfig.Queue.MinPlayers then
		if startingAt then
			startingAt = nil
			QueueService:Broadcast()
		end
		return
	end
	if not startingAt then
		startingAt = os.clock() + MatchConfig.Queue.StartDelay
		QueueService:Broadcast()
		return
	end
	if os.clock() >= startingAt then
		startingAt = nil
		local mode = QueueService:PickMode()
		local selected = QueueService:RankPlayers(players)
		local maxPlayers = MatchConfig.Modes[mode].MaxPlayers
		local starting = {}
		for index, player in selected do
			if index <= maxPlayers then
				table.insert(starting, player)
				queue[player] = nil
			end
		end
		task.spawn(function()
			Services.MatchService:StartMatch(mode, starting)
		end)
		QueueService:Broadcast()
	end
end

function QueueService:Init(services)
	Services = services
	Net.OnServerEvent("Match", "QueueRequest", function(player, action, mode)
		if action == "Join" then
			QueueService:AddPlayer(player, mode)
		elseif action == "Leave" then
			QueueService:RemovePlayer(player)
		elseif action == "LeaveMatch" then
			Services.MatchService:RemoveFromMatch(player)
		elseif action == "Refresh" then
			QueueService:Broadcast()
		end
	end, { Rate = 2, Burst = 5 })
end

function QueueService:Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			tick()
		end
	end)
	Players.PlayerAdded:Connect(function()
		task.defer(QueueService.Broadcast, QueueService)
	end)
end

return QueueService
