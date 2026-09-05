--[[ XPService: awards XP, resolves level-ups, notifies the owning client. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchData = require(ReplicatedStorage.Shared.MatchData)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local XPGained = Remotes:WaitForChild("XPGained")
local LevelUp = Remotes:WaitForChild("LevelUp")

local XPService = {}

function XPService.Award(player, amount, reason)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end

	profile.XP += amount
	XPGained:FireClient(player, amount, reason, profile.XP)

	local leveledUp = false
	while profile.XP >= MatchData.XPForLevel(profile.Level) do
		profile.XP -= MatchData.XPForLevel(profile.Level)
		profile.Level += 1
		leveledUp = true
	end

	if leveledUp then
		LevelUp:FireClient(player, profile.Level)
	end
end

return XPService
