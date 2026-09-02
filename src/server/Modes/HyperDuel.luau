--!nonstrict
--[[
	HyperDuel.luau
	1v1, round-based, small arena, no Overdrive.

	Everything that could decide a fight for you is removed, so what's left is
	movement and aim. Rounds are short and the reset is instant: full heal, full
	ammo, both abilities back, opposite sides of the cage. Losing a round should
	cost you three seconds, not your patience.

	With exactly two players this is a true 1v1. With more, players are split
	alternately across the two sides and it becomes a small round-based team fight
	under the same rules - nobody sits out. A proper winner-stays-on queue would be
	the next step here if lobbies routinely run above two.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Palette = require(Root.Config.Palette)
local WeaponConfig = require(Root.Config.WeaponConfig)
local Net = require(Root.Util.Net)

local BaseMode = require(script.Parent.BaseMode)

local HyperDuel = setmetatable({}, { __index = BaseMode })
HyperDuel.__index = HyperDuel

function HyperDuel.new(services, arena)
	local self = BaseMode.new(services, arena, "HyperDuel")
	setmetatable(self, HyperDuel)

	self.roundActive = false
	self.roundEndsAt = 0
	self.intermissionEndsAt = 0
	self.roundNumber = 0

	return self
end

function HyperDuel:Start()
	BaseMode.Start(self)

	self._diedConnection = self.services.Player.PlayerDied:Connect(function(player)
		self:_onDeath(player)
	end)

	self:_beginIntermission(1.5)
end

function HyperDuel:Stop()
	BaseMode.Stop(self)
	if self._diedConnection then
		self._diedConnection:Disconnect()
	end
end

function HyperDuel:Update(_dt: number)
	if not self.running then
		return
	end

	local now = os.clock()

	if not self.roundActive then
		if now >= self.intermissionEndsAt then
			self:_startRound()
		end
		return
	end

	-- Round timer expiry: whoever has more health takes it. A timeout that awards
	-- nothing teaches players to stall, and stalling is the opposite of this game.
	if now >= self.roundEndsAt then
		self:_resolveTimeout()
	end
end

function HyperDuel:_activePlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, player)
	end
	return list
end

function HyperDuel:_startRound()
	local players = self:_activePlayers()
	if #players < 2 then
		self.intermissionEndsAt = os.clock() + 2
		return
	end

	self.roundNumber += 1
	self.roundActive = true
	self.roundEndsAt = os.clock() + self.config.RoundTime

	-- Alternate sides so a 1v1 is a 1v1 and a 6-player lobby is a 3v3.
	for index, player in players do
		local teamKey = index % 2 == 1 and "Cyan" or "Magenta"
		self.services.Player:AssignTeam(player, teamKey)
		self.services.Player:SetLoadout(player, WeaponConfig.DuelLoadout)
		self.services.Player:SpawnPlayer(player)
		self.services.Ability:ResetPlayer(player)
	end

	Net.toAllClients("Announce", `ROUND {self.roundNumber}`, 1.4, Palette.NeonCyan)
end

function HyperDuel:_beginIntermission(duration: number?)
	self.roundActive = false
	self.intermissionEndsAt = os.clock() + (duration or self.config.RoundIntermission)
end

function HyperDuel:_onDeath(victim: Player)
	if not self.roundActive then
		return
	end

	local victimTeam = self.services.Player:GetTeamKey(victim)
	local winner = victimTeam == "Cyan" and "Magenta" or "Cyan"
	self:_endRound(winner)
end

function HyperDuel:_resolveTimeout()
	local best, bestHealth = nil, -1
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > bestHealth then
			best, bestHealth = player, humanoid.Health
		end
	end

	if best then
		self:_endRound(self.services.Player:GetTeamKey(best))
	else
		self:_beginIntermission()
	end
end

function HyperDuel:_endRound(winnerKey: string)
	if not self.roundActive then
		return
	end
	self.roundActive = false
	self:AddScore(winnerKey, 1)

	local team = Palette.Teams[winnerKey]
	Net.toAllClients(
		"Announce",
		`{team.Name} TAKES THE ROUND  ({self.scores.Cyan} - {self.scores.Magenta})`,
		2.2,
		team.Color
	)

	self:_beginIntermission()
end

function HyperDuel:GetRespawnDelay(): number
	return 0
end

function HyperDuel:AllowsAutoRespawn(): boolean
	return false -- the round loop owns respawning
end

--[[ Opposite corners, facing each other. No spawn-advantage maths needed when
	 the arena is symmetrical and both players start looking down the same line. ]]
function HyperDuel:GetSpawnPoint(player: Player): CFrame
	local teamKey = self.services.Player:GetTeamKey(player)
	local spawn = self.arena.spawns[teamKey] or self.arena.spawns.Cyan
	local position = spawn.center
	return CFrame.lookAt(position, position + (spawn.facing or Vector3.new(0, 0, 1)))
end

return HyperDuel
