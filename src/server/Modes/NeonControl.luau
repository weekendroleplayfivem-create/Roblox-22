--!nonstrict
--[[
	NeonControl.luau
	Capture and hold the neon zones; points tick while you hold them.

	Design intent: zones convert the arena's movement routes into pressure. Zone B
	is the spire - the best position and the most exposed one - so the mode is
	really asking "can your team hold the high ground while it's being wall-jumped
	from four sides at once?"

	Capture rules that matter:
		* Extra bodies capture faster, with diminishing returns, so stacking a
		  point is good but not a win button.
		* A contested zone freezes rather than reverses, which means a single
		  player can always deny by touching the point - the classic, readable rule.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local CombatConfig = require(Root.Config.CombatConfig)
local Palette = require(Root.Config.Palette)
local Net = require(Root.Util.Net)

local BaseMode = require(script.Parent.BaseMode)

local NeonControl = setmetatable({}, { __index = BaseMode })
NeonControl.__index = NeonControl

function NeonControl.new(services, arena)
	local self = BaseMode.new(services, arena, "NeonControl")
	setmetatable(self, NeonControl)

	self.zones = {}
	for _, zone in arena.zones do
		table.insert(self.zones, {
			id = zone.id,
			position = zone.position,
			radius = zone.radius,
			marker = zone.marker,
			owner = nil :: string?,
			capturingTeam = nil :: string?,
			progress = 0,
		})
	end

	self.tickAccumulator = 0
	return self
end

function NeonControl:Update(dt: number)
	if not self.running then
		return
	end

	for _, zone in self.zones do
		self:_updateZone(zone, dt)
	end

	self.tickAccumulator += dt
	if self.tickAccumulator >= self.config.TickInterval then
		self.tickAccumulator -= self.config.TickInterval
		self:_tickScores()
	end

	self:_broadcast()
end

function NeonControl:_playersInZone(zone)
	local counts = { Cyan = 0, Magenta = 0 }
	local occupants = {}

	for _, player in Players:GetPlayers() do
		if self.services.Player:IsAlive(player) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local delta = root.Position - zone.position
				local horizontal = Vector2.new(delta.X, delta.Z).Magnitude
				-- Generous vertical band so a player standing on the spire's top
				-- counts, but someone sprinting underneath it does not.
				if horizontal <= zone.radius and math.abs(delta.Y) <= 18 then
					local teamKey = self.services.Player:GetTeamKey(player)
					counts[teamKey] = (counts[teamKey] or 0) + 1
					table.insert(occupants, player)
				end
			end
		end
	end

	return counts, occupants
end

function NeonControl:_captureRate(count: number): number
	if count <= 0 then
		return 0
	end
	local base = 1 / self.config.CaptureTimePerPlayer
	local bonus = 1 + (count - 1) * self.config.CaptureSpeedPerExtraPlayer
	return base * math.min(bonus, self.config.MaxCaptureSpeed)
end

function NeonControl:_updateZone(zone, dt: number)
	local counts = self:_playersInZone(zone)
	local cyan, magenta = counts.Cyan or 0, counts.Magenta or 0

	if cyan > 0 and magenta > 0 then
		zone.capturingTeam = nil -- contested: frozen, by design
		return
	end

	local attacker = if cyan > 0 then "Cyan" elseif magenta > 0 then "Magenta" else nil

	if not attacker then
		-- Uncontested progress decays back toward the owner's control.
		if zone.owner == nil and zone.progress > 0 then
			zone.progress = math.max(0, zone.progress - self.config.DecayRate * dt)
			if zone.progress <= 0 then
				zone.capturingTeam = nil
			end
		end
		return
	end

	if zone.owner == attacker then
		zone.progress = 1
		zone.capturingTeam = attacker
		return
	end

	local count = attacker == "Cyan" and cyan or magenta
	local rate = self:_captureRate(count)

	if zone.owner ~= nil and zone.capturingTeam ~= attacker then
		-- First you have to break the enemy's hold, then you take it. That's what
		-- makes a defended point expensive rather than a coin flip.
		zone.progress = math.max(0, zone.progress - rate * dt)
		if zone.progress <= 0 then
			zone.owner = nil
			zone.capturingTeam = attacker
		end
		return
	end

	zone.capturingTeam = attacker
	zone.progress = math.min(1, zone.progress + rate * dt)

	if zone.progress >= 1 and zone.owner ~= attacker then
		zone.owner = attacker
		self:_onCaptured(zone, attacker)
	end
end

function NeonControl:_onCaptured(zone, teamKey: string)
	local team = Palette.Teams[teamKey]
	if zone.marker then
		zone.marker.Color = team.Color
	end

	local _, occupants = self:_playersInZone(zone)
	for _, player in occupants do
		if self.services.Player:GetTeamKey(player) == teamKey then
			self.services.Player:AddScore(player, CombatConfig.Score.ZoneCapture)
		end
	end

	Net.toAllClients("Announce", `{team.Name} CAPTURED {zone.id}`, 1.8, team.Color)
end

function NeonControl:_tickScores()
	local held = { Cyan = 0, Magenta = 0 }
	for _, zone in self.zones do
		if zone.owner then
			held[zone.owner] += 1
		end
	end

	for teamKey, count in held do
		if count > 0 then
			local points = count * self.config.PointsPerZonePerTick
			if count == #self.zones then
				points = math.floor(points * self.config.AllZonesBonusMultiplier)
			end
			self:AddScore(teamKey, points)

			for _, player in self.services.Player:GetTeamPlayers(teamKey) do
				self.services.Player:AddScore(player, CombatConfig.Score.ZoneTick * count)
			end
		end
	end
end

function NeonControl:GetObjectiveState()
	local zones = {}
	for _, zone in self.zones do
		table.insert(zones, {
			id = zone.id,
			owner = zone.owner,
			capturingTeam = zone.capturingTeam,
			progress = zone.progress,
		})
	end
	return { zones = zones }
end

function NeonControl:_broadcast()
	Net.toAllClients("ObjectiveState", self:GetObjectiveState())
end

--[[ Spawn nearest to a zone you already own, so holding points shortens your
	 rotations. Losing the map should also mean losing your spawn tempo. ]]
function NeonControl:GetSpawnPoint(player: Player): CFrame
	local teamKey = self.services.Player:GetTeamKey(player)
	local owned = {}
	for _, zone in self.zones do
		if zone.owner == teamKey then
			table.insert(owned, zone)
		end
	end

	if #owned == 0 then
		return BaseMode.GetSpawnPoint(self, player)
	end

	local base = BaseMode.GetSpawnPoint(self, player)
	local target = owned[math.random(1, #owned)]
	local direction = (target.position - base.Position)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1 then
		return base
	end
	return CFrame.lookAt(base.Position, base.Position + flat.Unit)
end

return NeonControl
