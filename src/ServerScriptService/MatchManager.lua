--[[
	MatchManager
	Owns the match state machine: team balance, spawning, scoring, win
	conditions, and respawn timers for both game modes (Team Blast, Hyper
	Rush). GameManager.server.lua boots this module and pumps its update loop.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamsService = game:GetService("Teams")

local MatchData = require(ReplicatedStorage.Shared.MatchData)
local ScooterBuilder = require(ReplicatedStorage.Shared.ScooterBuilder)
local PlayerData = require(script.Parent.PlayerData)
local DamageService = require(script.Parent.DamageService)
local XPService = require(script.Parent.XPService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStateChanged = Remotes:WaitForChild("MatchStateChanged")
local RespawnCountdown = Remotes:WaitForChild("RespawnCountdown")
local PlayClicked = Remotes:WaitForChild("PlayClicked")

local MatchManager = {}

MatchManager.State = "Waiting" -- Waiting | Countdown | InProgress | PostMatch
MatchManager.Mode = MatchData.DefaultMode
MatchManager.TimeLeft = 0
MatchManager.Scores = { Blue = 0, Purple = 0 }
MatchManager.PlayerScores = {} -- FFA mode: [player] = score
MatchManager.PlayerTeams = {} -- [player] = "Blue" | "Purple" | nil (FFA)

local scootersFolder = Instance.new("Folder")
scootersFolder.Name = "Scooters"
scootersFolder.Parent = Workspace

local function getMap()
	return Workspace:FindFirstChild("HyperBlastMap")
end

local function getSpawnPoints(teamName)
	local map = getMap()
	if not map then
		return {}
	end
	local spawnFolder = map:FindFirstChild(teamName .. "Spawn")
	local points = spawnFolder and spawnFolder:FindFirstChild("SpawnPoints")
	if not points then
		return {}
	end
	return points:GetChildren()
end

local function pickSpawnPoint(team)
	local candidates = {}
	if team then
		candidates = getSpawnPoints(team)
	else
		for _, p in ipairs(getSpawnPoints("Blue")) do
			table.insert(candidates, p)
		end
		for _, p in ipairs(getSpawnPoints("Purple")) do
			table.insert(candidates, p)
		end
	end

	if #candidates == 0 then
		return CFrame.new(0, 10, 0)
	end

	-- Prefer whichever candidate spawn is farthest from any living enemy,
	-- so players don't spawn muzzle-to-muzzle with the enemy team.
	local best, bestScore = candidates[1], -math.huge
	for _, point in ipairs(candidates) do
		local pos = point.Position
		local minEnemyDist = math.huge
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local plrTeam = MatchManager.PlayerTeams[plr]
				if not team or plrTeam ~= team then
					minEnemyDist = math.min(minEnemyDist, (root.Position - pos).Magnitude)
				end
			end
		end
		if minEnemyDist > bestScore then
			bestScore = minEnemyDist
			best = point
		end
	end

	return best.CFrame + Vector3.new(0, 3, 0)
end

-- Real Teams service objects so the client can read player.Team directly
-- (name tag coloring, end-screen win check) without a dedicated remote.
local teamObjects = {}
for key, data in pairs(MatchData.Teams) do
	local existing = TeamsService:FindFirstChild(data.Name)
	local teamObj = existing or Instance.new("Team")
	teamObj.Name = data.Name
	teamObj.TeamColor = data.BrickColor
	teamObj.AutoAssignable = false
	teamObj.Parent = TeamsService
	teamObjects[key] = teamObj
end

local function assignTeam(player)
	if MatchManager.PlayerTeams[player] then
		return MatchManager.PlayerTeams[player]
	end
	local blueCount, purpleCount = 0, 0
	for _, t in pairs(MatchManager.PlayerTeams) do
		if t == "Blue" then
			blueCount += 1
		elseif t == "Purple" then
			purpleCount += 1
		end
	end
	local team = (blueCount <= purpleCount) and "Blue" or "Purple"
	MatchManager.PlayerTeams[player] = team
	player.Team = teamObjects[team]
	player.Neutral = false
	return team
end

local function spawnScooterFor(player)
	local old = scootersFolder:FindFirstChild("Scooter_" .. player.UserId)
	if old then
		old:Destroy()
	end

	local profile = PlayerData.Get(player)
	local skinId = profile and profile.Loadout.ScooterSkin
	local scooter = ScooterBuilder.Build(skinId)
	scooter.Name = "Scooter_" .. player.UserId
	scooter:SetAttribute("Owner", player.UserId)
	scooter.Parent = scootersFolder
	return scooter
end

function MatchManager.SpawnPlayer(player)
	local team = MatchManager.Mode == "TeamBlast" and assignTeam(player) or nil
	local spawnCFrame = pickSpawnPoint(team)

	if not player.Character then
		player:LoadCharacter()
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")

	humanoid.Health = humanoid.MaxHealth
	root.CFrame = spawnCFrame
	root.AssemblyLinearVelocity = Vector3.zero

	local scooter = spawnScooterFor(player)
	scooter:PivotTo(spawnCFrame)

	task.defer(function()
		local seat = scooter:FindFirstChild("DriverSeat")
		if seat and humanoid.Health > 0 then
			seat:Sit(humanoid)
		end
	end)
end

local function onElimination(victim, killer, _weaponId, _isHeadshot)
	if MatchManager.State ~= "InProgress" then
		return
	end

	if killer and killer ~= victim then
		if MatchManager.Mode == "TeamBlast" then
			local team = MatchManager.PlayerTeams[killer]
			if team then
				MatchManager.Scores[team] += 1
			end
		else
			MatchManager.PlayerScores[killer] = (MatchManager.PlayerScores[killer] or 0) + 1
		end
	end

	MatchManager.BroadcastState()
	MatchManager.CheckWinCondition()

	-- Respawn countdown for the victim.
	task.spawn(function()
		local modeData = MatchData.Modes[MatchManager.Mode]
		local respawnTime = modeData.RespawnTime
		for i = respawnTime, 1, -1 do
			if not victim.Parent then
				return
			end
			RespawnCountdown:FireClient(victim, i)
			task.wait(1)
		end
		if MatchManager.State == "InProgress" and victim.Parent then
			MatchManager.SpawnPlayer(victim)
		end
	end)
end

DamageService.OnElimination = onElimination

function MatchManager.BroadcastState()
	MatchStateChanged:FireAllClients({
		State = MatchManager.State,
		Mode = MatchManager.Mode,
		TimeLeft = MatchManager.TimeLeft,
		Scores = MatchManager.Scores,
		PlayerScores = (function()
			local out = {}
			for plr, score in pairs(MatchManager.PlayerScores) do
				out[plr.Name] = score
			end
			return out
		end)(),
	})
end

function MatchManager.CheckWinCondition()
	local modeData = MatchData.Modes[MatchManager.Mode]
	local winningTeam, winningPlayer

	if MatchManager.Mode == "TeamBlast" then
		if MatchManager.Scores.Blue >= modeData.ScoreToWin then
			winningTeam = "Blue"
		elseif MatchManager.Scores.Purple >= modeData.ScoreToWin then
			winningTeam = "Purple"
		end
	else
		for plr, score in pairs(MatchManager.PlayerScores) do
			if score >= modeData.ScoreToWin then
				winningPlayer = plr
			end
		end
	end

	if winningTeam or winningPlayer then
		MatchManager.EndMatch(winningTeam, winningPlayer)
	end
end

function MatchManager.EndMatch(winningTeam, winningPlayer)
	if MatchManager.State == "PostMatch" then
		return
	end
	MatchManager.State = "PostMatch"

	local mvp, mvpScore = nil, -1
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerData.Get(player)
		if not profile then
			continue
		end
		profile.Matches += 1

		local won
		if winningPlayer then
			won = (player == winningPlayer)
		elseif winningTeam then
			won = (MatchManager.PlayerTeams[player] == winningTeam)
		else
			won = false
		end

		if won then
			profile.Wins += 1
			XPService.Award(player, MatchData.XP.PerWin, "Victory")
		else
			profile.Losses += 1
			XPService.Award(player, MatchData.XP.PerLoss, "Defeat")
		end
		XPService.Award(player, MatchData.XP.PerMatchComplete, "MatchComplete")

		local score = MatchManager.Mode == "TeamBlast" and profile.Kills or (MatchManager.PlayerScores[player] or 0)
		if score > mvpScore then
			mvpScore = score
			mvp = player
		end
	end

	MatchStateChanged:FireAllClients({
		State = "PostMatch",
		Mode = MatchManager.Mode,
		Scores = MatchManager.Scores,
		WinningTeam = winningTeam,
		WinningPlayer = winningPlayer and winningPlayer.Name or nil,
		MVP = mvp and mvp.Name or nil,
	})

	task.delay(MatchData.IntermissionTime, function()
		MatchManager.StartNewMatch()
	end)
end

function MatchManager.StartNewMatch()
	MatchManager.State = "Countdown"
	MatchManager.Scores = { Blue = 0, Purple = 0 }
	MatchManager.PlayerScores = {}
	MatchManager.PlayerTeams = {}
	MatchManager.TimeLeft = MatchData.MatchStartCountdown

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerData.Get(player)
		if profile then
			profile.Kills, profile.Deaths, profile.Assists = 0, 0, 0
		end
		player.Team = nil
		player.Neutral = true
	end

	MatchManager.BroadcastState()

	task.spawn(function()
		while MatchManager.TimeLeft > 0 do
			task.wait(1)
			MatchManager.TimeLeft -= 1
			MatchManager.BroadcastState()
		end

		MatchManager.State = "InProgress"
		MatchManager.TimeLeft = MatchData.MaxMatchDuration
		for _, player in ipairs(Players:GetPlayers()) do
			MatchManager.SpawnPlayer(player)
		end
		MatchManager.BroadcastState()
	end)
end

function MatchManager.Init()
	Players.PlayerAdded:Connect(function(player)
		if MatchManager.State == "InProgress" then
			task.wait(1)
			MatchManager.SpawnPlayer(player)
		end
	end)

	PlayClicked.OnServerEvent:Connect(function(player)
		if MatchManager.State == "InProgress" and not player.Character then
			MatchManager.SpawnPlayer(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchManager.PlayerTeams[player] = nil
		MatchManager.PlayerScores[player] = nil
		local scooter = scootersFolder:FindFirstChild("Scooter_" .. player.UserId)
		if scooter then
			scooter:Destroy()
		end
	end)

	-- Match duration countdown while InProgress.
	task.spawn(function()
		while true do
			task.wait(1)
			if MatchManager.State == "InProgress" then
				MatchManager.TimeLeft = math.max(0, MatchManager.TimeLeft - 1)
				MatchManager.BroadcastState()
				if MatchManager.TimeLeft <= 0 then
					-- Time's up: declare whichever side is ahead.
					if MatchManager.Mode == "TeamBlast" then
						local winner = MatchManager.Scores.Blue >= MatchManager.Scores.Purple and "Blue" or "Purple"
						MatchManager.EndMatch(winner, nil)
					else
						local best, bestScore = nil, -1
						for plr, score in pairs(MatchManager.PlayerScores) do
							if score > bestScore then
								best, bestScore = plr, score
							end
						end
						MatchManager.EndMatch(nil, best)
					end
				end
			end
		end
	end)

	MatchManager.StartNewMatch()
end

return MatchManager
