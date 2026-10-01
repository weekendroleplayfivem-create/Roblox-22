--[[
	ServerMain
	Boots every server service in a fixed order: Init (wire dependencies, no
	yielding) for all, then Start (connect events, begin loops) for all.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Net"))
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

-- Remotes must exist before any service registers handlers.
Net.Setup()

local ServicesFolder = ServerScriptService:WaitForChild("Services")

local ORDER = {
	"CombatantService",
	"DataService",
	"AntiCheatService",
	"MapService",
	"SpawnService",
	"WeaponService",
	"CombatService",
	"ProjectileService",
	"AbilityService",
	"ProgressionService",
	"ShopService",
	"LeaderboardService",
	"BotService",
	"MatchService",
	"QueueService",
	"PlayerService",
	"DevCommandService",
}

local Services = {}
for _, name in ORDER do
	local module = ServicesFolder:FindFirstChild(name)
	assert(module, "Missing service " .. name)
	Services[name] = require(module)
end

for _, name in ORDER do
	Services[name]:Init(Services)
end
for _, name in ORDER do
	Services[name]:Start()
end

print("[VectorRush] Server started")

if RunService:IsStudio() and DevConfig.RunTestsOnStudioStart then
	task.defer(function()
		local runner = require(ServerScriptService:WaitForChild("Tests"):WaitForChild("TestRunner"))
		local passed, failed, report = runner.Run(Services)
		local summary = string.format("[Tests] %d passed, %d failed", passed, failed)
		if failed > 0 then
			warn(summary .. "\n" .. report)
		else
			print(summary)
		end
	end)
end
