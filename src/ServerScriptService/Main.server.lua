--!strict
-- Slim bootstrap. Owns exactly two responsibilities: (1) create the shared
-- Remotes surface before anything else runs, and (2) Init() every service in
-- a fixed, dependency-aware order, then drive the shared per-frame tick loop.
-- No gameplay logic belongs in this file - it exists so the codebase never
-- accretes into "one giant script."
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local Services = script.Parent.Services
local CombatService = require(Services.CombatService)
local EnemyAIService = require(Services.EnemyAIService)
local BossService = require(Services.BossService)
local InventoryService = require(Services.InventoryService)
local ProgressionService = require(Services.ProgressionService)
local EconomyService = require(Services.EconomyService)
local LightingService = require(Services.LightingService)
local SaveService = require(Services.SaveService)
local PartyService = require(Services.PartyService)
local AnalyticsService = require(Services.AnalyticsService)
-- DungeonGenerator, BiomeRegistry, and LootService are pure-function modules
-- (no per-player state, no Remotes) required directly by whichever service
-- needs them rather than through this bootstrap.

local remotesFolder = Remotes.EnsureFolder(ReplicatedStorage)
Remotes.CreateAll(remotesFolder)

-- Init order matters: SaveService first (other services may want to read
-- loaded account state as players join), then the Remote-owning services,
-- each passed the already-created remotesFolder rather than re-deriving it.
SaveService.Init()
CombatService.Init(remotesFolder)
InventoryService.Init(remotesFolder)
ProgressionService.Init(remotesFolder)
EconomyService.Init(remotesFolder)
BossService.Init(remotesFolder)
PartyService.Init(remotesFolder)

AnalyticsService.LogEvent("ServerStarted", nil, { placeId = game.PlaceId, jobId = game.JobId })

-- Shared heartbeat tick for every service that needs periodic work but not a
-- dedicated RunService connection (enemy AI, status-effect expiry, torch
-- flicker) - keeps per-frame cost centralized and profileable in one place
-- rather than scattered across N independent Heartbeat:Connect calls.
RunService.Heartbeat:Connect(function()
	EnemyAIService.Tick()
	CombatService.Tick()
	LightingService.Tick()
end)
