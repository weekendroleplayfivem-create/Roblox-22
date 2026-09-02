--!nonstrict
--[[
	CoreRush.luau
	One glowing energy core, two objectives. Pick it up, carry it home.

	This is the mode that exists to make the movement system the *content*. The
	carrier is slower, restricted to a sidearm and denied Phase Step, so the only
	way through is real routing: slide tunnels, jump pads, wall-jump lines, and a
	team that clears them for you.

	The core is a physical object the whole lobby can see (it's tethered to a beam
	and highlighted), because a carrier the enemy can't find isn't a carrier -
	it's a stealth mission, and this isn't that game.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local CombatConfig = require(Root.Config.CombatConfig)
local Palette = require(Root.Config.Palette)
local Net = require(Root.Util.Net)

local BaseMode = require(script.Parent.BaseMode)

local CoreRush = setmetatable({}, { __index = BaseMode })
CoreRush.__index = CoreRush

local PICKUP_RADIUS = 7

function CoreRush.new(services, arena)
	local self = BaseMode.new(services, arena, "CoreRush")
	setmetatable(self, CoreRush)

	self.carrier = nil :: Player?
	self.corePosition = arena.config.CoreSpawn
	self.droppedAt = 0
	self.core = nil :: BasePart?

	return self
end

function CoreRush:Start()
	BaseMode.Start(self)
	self:_spawnCore()

	self._connection = self.services.Player.PlayerDied:Connect(function(player)
		if self.carrier == player then
			self:_dropCore()
		end
	end)
end

function CoreRush:Stop()
	BaseMode.Stop(self)
	if self._connection then
		self._connection:Disconnect()
	end
	if self.core then
		self.core:Destroy()
		self.core = nil
	end
end

function CoreRush:_spawnCore()
	if self.core then
		self.core:Destroy()
	end

	local core = Instance.new("Part")
	core.Name = "EnergyCore"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(4, 4, 4)
	core.Material = Enum.Material.Neon
	core.Color = Palette.NeonPurple
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.Position = self.arena.config.CoreSpawn
	core.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Palette.NeonPurple
	light.Brightness = 6
	light.Range = 40
	light.Parent = core

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Palette.NeonPurple
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Palette.NeonMagenta
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = core

	self.core = core
	self.corePosition = core.Position
	self.carrier = nil
	self.droppedAt = 0
end

function CoreRush:Update(dt: number)
	if not self.running or not self.core then
		return
	end

	if self.carrier then
		self:_updateCarrier(dt)
	else
		self:_updateLooseCore(dt)
	end

	self:_broadcast()
end

function CoreRush:_updateCarrier(dt: number)
	local carrier = self.carrier
	local character = carrier and carrier.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root or not self.services.Player:IsAlive(carrier) then
		self:_dropCore()
		return
	end

	-- The core rides above the carrier's head: a visible, chaseable target.
	self.core.Position = root.Position + Vector3.new(0, 5.5, 0)
	self.core.CFrame = CFrame.new(self.core.Position) * CFrame.Angles(0, os.clock() * 2, 0)

	local teamKey = self.services.Player:GetTeamKey(carrier)
	local objective = self.arena.coreObjectives[teamKey]
	if objective and (root.Position - objective.position).Magnitude <= self.config.DeliverRadius then
		self:_deliver(carrier, teamKey)
	end

	local _ = dt
end

function CoreRush:_updateLooseCore(dt: number)
	self.core.CFrame = CFrame.new(self.corePosition + Vector3.new(0, math.sin(os.clock() * 2) * 0.6, 0))
		* CFrame.Angles(0, os.clock(), 0)

	if self.droppedAt > 0 and os.clock() - self.droppedAt >= self.config.CoreDropTime then
		self.corePosition = self.arena.config.CoreSpawn
		self.droppedAt = 0
		Net.toAllClients("Announce", "CORE RESET", 1.5, Palette.NeonPurple)
	end

	for _, player in Players:GetPlayers() do
		if self.services.Player:IsAlive(player) then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - self.core.Position).Magnitude <= PICKUP_RADIUS then
				self:_pickUp(player)
				return
			end
		end
	end

	local _ = dt
end

function CoreRush:_pickUp(player: Player)
	self.carrier = player
	self.droppedAt = 0

	-- Carrying costs you your kit. That trade is the whole mode.
	self.services.Player:RestrictWeapons(player, self.config.CarrierWeaponIds)
	self.services.Player:AddScore(player, CombatConfig.Score.CoreCarry)

	local team = Palette.Teams[self.services.Player:GetTeamKey(player)]
	Net.toAllClients("Announce", `{string.upper(player.Name)} HAS THE CORE`, 2.0, team.Color)
end

function CoreRush:_dropCore()
	local carrier = self.carrier
	if carrier then
		self.services.Player:RestrictWeapons(carrier, nil)
		local root = carrier.Character and carrier.Character:FindFirstChild("HumanoidRootPart")
		self.corePosition = root and (root.Position + Vector3.new(0, 3, 0)) or self.arena.config.CoreSpawn
	end

	self.carrier = nil
	self.droppedAt = os.clock()
	Net.toAllClients("Announce", "CORE DROPPED", 1.5, Palette.NeonAmber)
end

function CoreRush:_deliver(player: Player, teamKey: string)
	self:AddScore(teamKey, 1)
	self.services.Player:AddScore(player, CombatConfig.Score.CoreDeliver)
	self.services.Player:RestrictWeapons(player, nil)

	local team = Palette.Teams[teamKey]
	Net.toAllClients("Announce", `{team.Name} DELIVERED THE CORE`, 2.5, team.Color)

	self.carrier = nil
	task.delay(self.config.CoreRespawnTime, function()
		if self.running then
			self:_spawnCore()
		end
	end)
	self.corePosition = self.arena.config.CoreSpawn
	self.core.Position = Vector3.new(0, -500, 0) -- parked until it respawns
end

function CoreRush:IsAbilityAllowed(player: Player, id: string): boolean
	if self.carrier == player then
		local allowed = self.config.CarrierAbilitiesEnabled
		return allowed[id] ~= false
	end
	return BaseMode.IsAbilityAllowed(self, player, id)
end

function CoreRush:GetObjectiveState()
	return {
		core = {
			carrier = self.carrier and self.carrier.Name or nil,
			position = self.core and self.core.Position or self.corePosition,
			team = self.carrier and self.services.Player:GetTeamKey(self.carrier) or nil,
		},
	}
end

function CoreRush:_broadcast()
	-- Objective state is small but not free; a quarter-second cadence is well
	-- inside human reaction time and a fraction of the bandwidth.
	if os.clock() - (self._lastBroadcast or 0) >= 0.25 then
		self._lastBroadcast = os.clock()
		Net.toAllClients("ObjectiveState", self:GetObjectiveState())
	end
end

return CoreRush
