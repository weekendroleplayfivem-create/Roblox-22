--!nonstrict
--[[
	HyperTeamDeathmatch.luau
	The baseline mode: two teams, first to the score limit.

	It exists to be the control group. If a weapon or a movement change is broken,
	it will show up here first, because nothing else is competing for the player's
	attention.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Net = require(Root.Util.Net)
local Palette = require(Root.Config.Palette)

local BaseMode = require(script.Parent.BaseMode)

local HyperTeamDeathmatch = setmetatable({}, { __index = BaseMode })
HyperTeamDeathmatch.__index = HyperTeamDeathmatch

function HyperTeamDeathmatch.new(services, arena)
	local self = BaseMode.new(services, arena, "HyperTeamDeathmatch")
	return setmetatable(self, HyperTeamDeathmatch)
end

function HyperTeamDeathmatch:OnKill(victim: Player, killer: Player?)
	if not killer or killer == victim then
		-- Self-elimination (out of bounds) feeds the other team, so falling off
		-- the map is a real cost rather than a free reset.
		local victimTeam = self.services.Player:GetTeamKey(victim)
		for teamKey in self.scores do
			if teamKey ~= victimTeam then
				self:AddScore(teamKey, 1)
			end
		end
		return
	end

	local teamKey = self.services.Player:GetTeamKey(killer)
	self:AddScore(teamKey, 1)

	-- Callout when a team gets within touching distance of the limit.
	local remaining = self.config.ScoreLimit - self.scores[teamKey]
	if remaining == 5 or remaining == 1 then
		local team = Palette.Teams[teamKey]
		Net.toAllClients(
			"Announce",
			remaining == 1 and `{team.Name} — MATCH POINT` or `{team.Name} — {remaining} TO WIN`,
			2.0,
			team.Color
		)
	end
end

return HyperTeamDeathmatch
