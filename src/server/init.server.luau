--!nonstrict
--[[
	HyperBlastServer
	Server bootstrap.

	Order matters and is explicit:
		1. Remotes exist before anything can reference them.
		2. Services are constructed with a shared `services` table so they can
		   reference each other without a require cycle.
		3. Services start in dependency order.

	The `services` table is passed by reference at construction time, so a service
	can hold onto it and read `services.Match` later even though Match is created
	after it. That is the whole reason this pattern is used instead of requires.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Spawning is owned by PlayerService/MatchService, never by Roblox. Asserted here
-- as well as in the project file so a place built without Rojo still behaves.
Players.CharacterAutoLoads = false

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Net = require(Root.Util.Net)

Net.init()

local Services = script.Services
local PlayerService = require(Services.PlayerService)
local CombatService = require(Services.CombatService)
local AbilityService = require(Services.AbilityService)
local MovementGuard = require(Services.MovementGuard)
local MatchService = require(Services.MatchService)

local services = {}

services.Player = PlayerService.new(services)
services.Ability = AbilityService.new(services)
services.Combat = CombatService.new(services)
services.Movement = MovementGuard.new(services)
services.Match = MatchService.new(services)

services.Player:Start()
services.Ability:Start()
services.Combat:Start()
services.Movement:Start()
services.Match:Start()

print("[HYPER BLAST] server online")
