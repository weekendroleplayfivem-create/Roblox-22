--!nonstrict
--[[
	MatchService.luau
	Match flow: builds the arena, runs the mode, owns the phase clock, and is the
	one place that answers "what are the rules right now?" for every other service.

	Phase machine:
		Warmup   -> players frozen at spawn, weapons out, movement disabled
		Live     -> the match
		Overtime -> only if the clock expired on a tie
		PostMatch-> scoreboard, then rotate to the next mode

	Modes are hot-swapped: nothing outside this file knows which mode is running.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local GameModeConfig = require(Root.Config.GameModeConfig)
local ArenaConfig = require(Root.Config.ArenaConfig)
local Palette = require(Root.Config.Palette)
local Net = require(Root.Util.Net)

local ArenaBuilder = require(script.Parent.Parent.Arena.ArenaBuilder)
local Modes = script.Parent.Parent.Modes

local MODE_CLASSES = {
	HyperTeamDeathmatch = require(Modes.HyperTeamDeathmatch),
	NeonControl = require(Modes.NeonControl),
	CoreRush = require(Modes.CoreRush),
	HyperDuel = require(Modes.HyperDuel),
}

local MatchService = {}
MatchService.__index = MatchService

function MatchService.new(services)
	local self = setmetatable({}, MatchService)

	self.services = services
	self.phase = "Warmup"
	self.phaseEndsAt = 0
	self.rotationIndex = 0
	self.mode = nil
	self.arena = nil
	self.friendlyFire = false

	return self
end

function MatchService:Start()
	self.services.Combat.PlayerKilled:Connect(function(victim, killer, info)
		if self.mode and self.phase ~= "PostMatch" then
			self.mode:OnKill(victim, killer, info)
			self:_checkWinCondition()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(self._update, self, dt)
		if not ok then
			warn(`[Match] update error: {err}`)
		end
	end)

	-- Late joiners need the current state immediately, not at the next broadcast.
	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			if player.Parent then
				Net.toClient("MatchState", player, self:GetStateSnapshot())
			end
		end)
	end)

	Net.get("GetMatchSnapshot").OnServerInvoke = function()
		return self:GetStateSnapshot()
	end
	Net.get("GetServerTime").OnServerInvoke = function()
		return workspace:GetServerTimeNow()
	end

	self:StartMatch(GameModeConfig.Default)
	return self
end

----------------------------------------------------------------------
-- Match lifecycle
----------------------------------------------------------------------

function MatchService:StartMatch(modeId: string)
	local modeConfig = GameModeConfig.get(modeId) or GameModeConfig.get(GameModeConfig.Default)

	if self.mode then
		self.mode:Stop()
		self.mode = nil
	end

	-- Rebuild the arena only when the mode actually needs a different one; a
	-- rebuild is cheap but it also resets every objective, so don't do it idly.
	local arenaId = modeConfig.Arena or ArenaConfig.Default
	if not self.arena or self.arena.id ~= arenaId then
		self.arena = ArenaBuilder.build(arenaId)
	end

	self.mode = MODE_CLASSES[modeConfig.Id].new(self.services, self.arena)
	self.services.Player:ResetStats()

	self:_setPhase("Warmup", GameModeConfig.Match.WarmupTime + GameModeConfig.Match.IntroTime)

	Net.toAllClients("Announce", modeConfig.DisplayName, 3.0, Palette.NeonCyan)

	-- Everyone gets a fresh body for the new mode, wherever they are.
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self.services.Player:SpawnPlayer(player)
		end)
	end
end

function MatchService:_setPhase(phase: string, duration: number)
	self.phase = phase
	self.phaseEndsAt = workspace:GetServerTimeNow() + duration
	self:_broadcastState(phase == "Live")
end

function MatchService:_update(dt: number)
	if self.mode and self.phase ~= "Warmup" and self.phase ~= "PostMatch" then
		self.mode:Update(dt)
		self:_checkWinCondition()
	end

	self:_enforceBounds()

	local now = workspace:GetServerTimeNow()
	if now >= self.phaseEndsAt then
		self:_advancePhase()
	end

	-- State is broadcast on a slow cadence; the HUD interpolates its own timer
	-- against the server clock, so this only needs to carry score changes.
	if now - (self._lastBroadcast or 0) >= 1 then
		self._lastBroadcast = now
		self:_broadcastState(false)
	end
end

function MatchService:_advancePhase()
	if self.phase == "Warmup" then
		self:_setPhase("Live", self.mode.config.TimeLimit)
		self.mode:Start()
	elseif self.phase == "Live" then
		local winner = self.mode:GetTimeoutWinner()
		if not winner and GameModeConfig.Match.OvertimeEnabled then
			self:_setPhase("Overtime", GameModeConfig.Match.OvertimeDuration)
		else
			self:_endMatch(winner)
		end
	elseif self.phase == "Overtime" then
		self:_endMatch(self.mode:GetTimeoutWinner())
	elseif self.phase == "PostMatch" then
		self.rotationIndex += 1
		local nextId = GameModeConfig.Rotation[(self.rotationIndex % #GameModeConfig.Rotation) + 1]
		self:StartMatch(nextId)
	end
end

function MatchService:_checkWinCondition()
	if self.phase ~= "Live" and self.phase ~= "Overtime" then
		return
	end
	local winner = self.mode:GetWinner()
	if winner then
		self:_endMatch(winner)
	end
end

function MatchService:_endMatch(winnerKey: string?)
	if self.phase == "PostMatch" then
		return
	end

	self.winner = winnerKey
	if self.mode then
		self.mode:Stop()
	end
	self:_setPhase("PostMatch", GameModeConfig.Match.PostMatchTime)
end

----------------------------------------------------------------------
-- Bounds
----------------------------------------------------------------------

--[[ Out-of-bounds is lethal and credited to nobody. Falling off the map in a
	 movement game is a mistake you should own, not a soft reset. ]]
function MatchService:_enforceBounds()
	if not self.arena then
		return
	end

	local floorY = self.arena.config.FloorY
	for _, player in Players:GetPlayers() do
		if self.services.Player:IsAlive(player) then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root.Position.Y < floorY - 60 then
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Queries used by other services
----------------------------------------------------------------------

function MatchService:GetSpawnPoint(player: Player): CFrame?
	if self.mode then
		return self.mode:GetSpawnPoint(player)
	end
	return nil
end

function MatchService:GetRespawnDelay(): number
	return self.mode and self.mode:GetRespawnDelay() or 3
end

function MatchService:AllowsAutoRespawn(): boolean
	if self.phase == "PostMatch" then
		return false
	end
	return self.mode == nil or self.mode:AllowsAutoRespawn()
end

function MatchService:IsAbilityAllowed(player: Player, id: string): boolean
	if self.phase == "Warmup" or self.phase == "PostMatch" then
		return false
	end
	return self.mode == nil or self.mode:IsAbilityAllowed(player, id)
end

function MatchService:IsFriendlyFireEnabled(): boolean
	return self.friendlyFire
end

function MatchService:GetStateSnapshot()
	local modeConfig = self.mode and self.mode.config
	return {
		phase = self.phase,
		mode = modeConfig and modeConfig.Id or nil,
		modeName = modeConfig and modeConfig.DisplayName or "",
		arena = self.arena and self.arena.id or nil,
		scores = self.mode and self.mode:GetScores() or { Cyan = 0, Magenta = 0 },
		scoreLimit = modeConfig and modeConfig.ScoreLimit or 0,
		endsAt = self.phaseEndsAt,
		winner = self.winner,
	}
end

function MatchService:_broadcastState(justStarted: boolean)
	local snapshot = self:GetStateSnapshot()
	snapshot.justStarted = justStarted
	Net.toAllClients("MatchState", snapshot)

	if self.mode then
		local objectives = self.mode:GetObjectiveState()
		if next(objectives) ~= nil then
			Net.toAllClients("ObjectiveState", objectives)
		end
	end
end

return MatchService
