--[[
	MatchService
	Owns the match lifecycle:

	  Lobby -> Loading (build arena) -> Countdown (spawned, frozen)
	        -> Active (combat on) -> Results (rewards shown) -> Lobby

	Mode-specific rules live in ./Modes/<ModeId>; this service only knows the
	common flow (participants, spawning, respawns, timers, results). Adding a
	mode = add a config entry in MatchConfig + a rules module.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local MatchConfig = require(Shared.Config.MatchConfig)
local MapConfig = require(Shared.Config.MapConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)

local ModeRules = {}
for _, module in script:WaitForChild("Modes"):GetChildren() do
	if module:IsA("ModuleScript") then
		ModeRules[module.Name] = require(module)
	end
end

local MatchService = {}

MatchService.PhaseChanged = Signal.new() -- (phase)
MatchService.MatchEnded = Signal.new() -- (match, winner)

local Services

local phase = "Lobby"
local match = nil -- current match context
local matchCounter = 0
local lastMapId: string? = nil

local TEAM_SIDES = { Nova = "A", Flux = "B" }

local function serverTime(clockTime: number): number
	return workspace:GetServerTimeNow() + (clockTime - os.clock())
end

local function setPhase(newPhase: string, duration: number?)
	phase = newPhase
	if match then
		match.Phase = newPhase
		match.PhaseEndsAt = if duration then os.clock() + duration else nil
	end
	MatchService:BroadcastState()
	MatchService.PhaseChanged:Fire(newPhase)
end

function MatchService:GetPhase(): string
	return phase
end

function MatchService:IsCombatActive(): boolean
	return phase == "Active"
end

function MatchService:GetMatch()
	return match
end

function MatchService:GetSummaryInfo()
	return { Mode = match and match.ModeId, Map = match and match.MapId }
end

function MatchService:IsParticipant(combatant): boolean
	return match ~= nil and match.Participants[combatant] == true
end

function MatchService:CanJoinInProgress(): boolean
	if not match or not MatchConfig.Queue.AllowJoinInProgress then
		return false
	end
	if phase ~= "Active" and phase ~= "Countdown" then
		return false
	end
	local realPlayers = 0
	for combatant in match.Participants do
		if not combatant.IsBot then
			realPlayers += 1
		end
	end
	return realPlayers < match.ModeConfig.MaxPlayers
end

function MatchService:BroadcastState(target: Player?)
	local payload = {
		Phase = phase,
		Mode = match and match.ModeId,
		Map = match and match.MapId,
		PhaseEndsAt = if match and match.PhaseEndsAt then serverTime(match.PhaseEndsAt) else nil,
		TeamScores = match and match.TeamScores,
		ScoreLimit = match and match.ModeConfig.ScoreLimit,
		TeamBased = match and match.Rules.TeamBased,
	}
	local remote = Net.Event("Match", "MatchState")
	if target then
		remote:FireClient(target, payload)
	else
		remote:FireAllClients(payload)
	end
end

function MatchService:Announce(target: Player?, data)
	local remote = Net.Event("Match", "Announcement")
	if target then
		remote:FireClient(target, data)
		return
	end
	if not match then
		return
	end
	for combatant in match.Participants do
		if combatant.Player then
			remote:FireClient(combatant.Player, data)
		end
	end
end

-- Weapons the player picked in the Loadout menu (validated in WeaponService).
function MatchService:GetChosenLoadout(combatant)
	if combatant.Player then
		return Services.WeaponService:GetPlayerLoadout(combatant.Player)
	end
	return combatant.BotLoadout or { Primary = "PulseRifle", Secondary = "EnergySidearm" }
end

local function chooseMap(modeId: string): string
	local options = {}
	for _, mapId in MapConfig.Order do
		if MapConfig.SupportsMode(mapId, modeId) and mapId ~= lastMapId then
			table.insert(options, mapId)
		end
	end
	if #options == 0 then
		return MapConfig.Order[1]
	end
	return options[math.random(1, #options)]
end

local function setFrozen(combatant, frozen: boolean)
	if combatant.Character then
		combatant.Character:SetAttribute("Frozen", frozen)
	end
end

local function applySpawnProtection(combatant)
	local duration = PlayerConfig.Respawn.SpawnProtection
	combatant.SpawnProtectedUntil = os.clock() + duration
	local character = combatant.Character
	if character then
		character:SetAttribute("SpawnProtected", true)
		task.delay(duration, function()
			if character.Parent and combatant.Character == character then
				character:SetAttribute("SpawnProtected", false)
			end
		end)
	end
end

-- Spawns (or respawns) a participant at the best spawn and gives the loadout.
function MatchService:SpawnParticipant(combatant)
	if not match or not match.Participants[combatant] then
		return
	end
	local spawnCFrame = Services.SpawnService:ChooseSpawn(combatant, TEAM_SIDES[combatant.Team or ""], match.Rules.TeamBased)
	if not spawnCFrame then
		warn("[MatchService] No spawn available")
		return
	end
	if combatant.Player then
		combatant.Player:SetAttribute("Location", "Match")
	end
	local character = Services.PlayerService:SpawnCombatant(combatant, spawnCFrame)
	if not character or not match or not match.Participants[combatant] then
		return
	end
	local slots, infinite = match.Rules.GetLoadout(match, combatant)
	Services.WeaponService:GiveLoadout(combatant, slots, infinite)
	applySpawnProtection(combatant)
	setFrozen(combatant, phase == "Countdown")
end

local function scheduleRespawn(combatant)
	local token = match.Id
	task.delay(PlayerConfig.Respawn.Delay, function()
		if match and match.Id == token and phase == "Active" and match.Participants[combatant] and not combatant.Alive then
			MatchService:SpawnParticipant(combatant)
		end
	end)
end

local function addParticipant(combatant)
	Services.CombatantService:ResetMatchState(combatant)
	combatant.InMatch = true
	match.Participants[combatant] = true
	local team = match.Rules.PickTeam(match)
	Services.CombatantService:SetTeam(combatant, team)
	Services.AbilityService:ApplyLoadout(combatant)
	if combatant.Player then
		-- "Location" flips to Match when the player actually spawns in the arena.
		Services.QueueService:RemovePlayer(combatant.Player)
	end
end

function MatchService:StartMatch(modeId: string, players: { Player }, mapId: string?)
	if match then
		return false
	end
	local modeConfig = MatchConfig.Modes[modeId]
	local rules = ModeRules[modeId]
	if not modeConfig or not rules then
		warn("[MatchService] Unknown mode " .. tostring(modeId))
		return false
	end
	matchCounter += 1
	local selectedMap = if mapId and MapConfig.Get(mapId) then mapId else chooseMap(modeId)
	lastMapId = selectedMap
	match = {
		Id = matchCounter,
		ModeId = modeId,
		ModeConfig = modeConfig,
		Rules = rules,
		MapId = selectedMap,
		Participants = {},
		TeamScores = {},
		Phase = "Loading",
		PhaseEndsAt = nil,
		StartedAt = 0,
		Services = Services,
		GunGameWinner = nil,
	}
	local thisMatch = match
	rules.Setup(match)
	setPhase("Loading", MatchConfig.Phases.LoadingTime)
	Services.SpawnService:Reset()
	Services.MapService:LoadArena(selectedMap)

	for _, player in players do
		local combatant = Services.CombatantService:GetByPlayer(player)
		if combatant and player.Parent then
			addParticipant(combatant)
		end
	end

	-- Fill with practice bots.
	if MatchConfig.Queue.FillWithBots then
		local realCount = 0
		for _ in match.Participants do
			realCount += 1
		end
		local botCount = math.max(0, modeConfig.BotFillTarget - realCount)
		for _, bot in Services.BotService:CreateBots(botCount, MatchConfig.Queue.DefaultBotDifficulty) do
			addParticipant(bot)
		end
	end

	task.wait(MatchConfig.Phases.LoadingTime)
	if match ~= thisMatch then
		return false
	end

	-- Countdown: everyone spawns frozen.
	setPhase("Countdown", MatchConfig.Phases.CountdownTime)
	for combatant in match.Participants do
		task.spawn(MatchService.SpawnParticipant, MatchService, combatant)
	end
	MatchService:Announce(nil, {
		Text = string.upper(modeConfig.DisplayName),
		Sub = MapConfig.Get(selectedMap).DisplayName,
		Duration = 2.5,
	})
	task.wait(MatchConfig.Phases.CountdownTime)
	if match ~= thisMatch then
		return false
	end

	for combatant in match.Participants do
		setFrozen(combatant, false)
		Services.AbilityService:ResetCooldowns(combatant)
	end
	match.StartedAt = os.clock()
	setPhase("Active", modeConfig.TimeLimit)
	MatchService:Announce(nil, { Text = "GO!", Duration = 1.2 })

	-- Time limit watcher.
	task.spawn(function()
		while match == thisMatch and phase == "Active" do
			task.wait(1)
			if match == thisMatch and phase == "Active" and match.PhaseEndsAt and os.clock() >= match.PhaseEndsAt then
				MatchService:EndMatch("TimeLimit")
			end
		end
	end)
	return true
end

function MatchService:OnElimination(victim, killer, assists, info)
	if not match or phase ~= "Active" or not match.Participants[victim] then
		return
	end
	local score = MatchConfig.Score
	if killer and match.Participants[killer] then
		killer.Stats.Score += score.Elimination + (if info.Headshot then score.HeadshotBonus else 0)
	else
		killer = nil
	end
	for _, helper in assists do
		if match.Participants[helper] then
			helper.Stats.Score += score.Assist
		end
	end
	Services.ProgressionService:RecordElimination(killer, victim, assists, info)

	local shouldEnd = match.Rules.OnElimination(match, victim, killer, assists, info)
	MatchService:BroadcastState()
	if shouldEnd then
		MatchService:EndMatch("ScoreLimit")
		return
	end
	scheduleRespawn(victim)
end

function MatchService:EndMatch(reason: string)
	if not match or phase == "Results" then
		return
	end
	local thisMatch = match
	local winner = match.Rules.GetWinner(match)
	local duration = if match.StartedAt > 0 then os.clock() - match.StartedAt else 0
	setPhase("Results", MatchConfig.Phases.ResultsTime)
	Services.ProjectileService:ClearAll()

	-- Freeze everyone in place for the results screen.
	for combatant in match.Participants do
		setFrozen(combatant, true)
	end

	local snapshot = Services.LeaderboardService:BuildSnapshot()
	local ranking = {}
	for index, entry in snapshot do
		ranking[entry.Id] = index
	end
	local winnerName = nil
	if winner.Combatant then
		winnerName = winner.Combatant.Name
	elseif winner.Team then
		winnerName = MatchConfig.Teams[winner.Team].DisplayName
	end

	for combatant in match.Participants do
		if combatant.Player and reason ~= "Aborted" then
			local won = (winner.Team ~= nil and combatant.Team == winner.Team) or winner.Combatant == combatant
			local rewards = Services.ProgressionService:AwardMatch(combatant, {
				Duration = duration,
				Won = won,
				TopThree = not match.Rules.TeamBased and (ranking[combatant.Id] or 99) <= 3,
			})
			Net.Event("Match", "Results"):FireClient(combatant.Player, {
				Mode = match.ModeId,
				Map = match.MapId,
				Reason = reason,
				Won = won,
				Draw = winner.Draw == true,
				WinnerTeam = winner.Team,
				WinnerName = winnerName,
				TeamScores = match.TeamScores,
				Scoreboard = snapshot,
				Rewards = rewards,
				Stats = combatant.Stats,
				Duration = MatchConfig.Phases.ResultsTime,
			})
		end
	end
	MatchService.MatchEnded:Fire(match, winner)

	task.delay(MatchConfig.Phases.ResultsTime, function()
		if match == thisMatch then
			MatchService:Cleanup()
		end
	end)
end

-- Returns everyone to the lobby and removes the arena + bots.
function MatchService:Cleanup()
	if not match then
		return
	end
	local participants = match.Participants
	match = nil
	for combatant in participants do
		if combatant.IsBot then
			Services.BotService:RemoveBot(combatant)
		elseif combatant.Player and combatant.Player.Parent then
			Services.PlayerService:SendToLobby(combatant.Player)
		end
	end
	Services.MapService:UnloadArena()
	setPhase("Lobby")
	Services.QueueService:OnLobbyFree()
end

function MatchService:AddLatecomer(player: Player)
	if not MatchService:CanJoinInProgress() then
		return false
	end
	local combatant = Services.CombatantService:GetByPlayer(player)
	if not combatant or match.Participants[combatant] then
		return false
	end
	addParticipant(combatant)
	-- Keep the lobby size steady by removing a bot from the same team.
	local total = 0
	for _ in match.Participants do
		total += 1
	end
	if total > match.ModeConfig.BotFillTarget then
		for other in match.Participants do
			if other.IsBot and other.Team == combatant.Team then
				MatchService:RemoveParticipant(other)
				Services.BotService:RemoveBot(other)
				break
			end
		end
	end
	MatchService:BroadcastState(player)
	task.spawn(MatchService.SpawnParticipant, MatchService, combatant)
	return true
end

-- Removes a combatant from the match bookkeeping (no lobby transfer).
function MatchService:RemoveParticipant(combatant)
	if not match or not match.Participants[combatant] then
		return
	end
	match.Participants[combatant] = nil
	combatant.InMatch = false
	if combatant.Alive and combatant.Character then
		combatant.Alive = false
	end
end

-- Voluntary leave through the menu.
function MatchService:RemoveFromMatch(player: Player)
	local combatant = Services.CombatantService:GetByPlayer(player)
	if not combatant or not match or not match.Participants[combatant] then
		return
	end
	MatchService:RemoveParticipant(combatant)
	Services.PlayerService:SendToLobby(player)
	MatchService:CheckAbandoned()
end

-- Player disconnected.
function MatchService:OnCombatantLeaving(combatant)
	if match and match.Participants[combatant] then
		MatchService:RemoveParticipant(combatant)
		MatchService:CheckAbandoned()
	end
end

-- Ends the match early (no rewards) when no real players remain.
function MatchService:CheckAbandoned()
	if not match or phase == "Results" then
		return
	end
	for combatant in match.Participants do
		if not combatant.IsBot then
			return
		end
	end
	MatchService:EndMatch("Aborted")
end

-- Dev/testing helper: end the match now.
function MatchService:ForceEnd()
	if match then
		MatchService:EndMatch("TimeLimit")
	end
end

function MatchService:Init(services)
	Services = services
end

function MatchService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.defer(MatchService.BroadcastState, MatchService, player)
	end)
end

return MatchService
