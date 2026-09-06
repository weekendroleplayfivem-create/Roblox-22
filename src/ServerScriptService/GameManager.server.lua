--[[
	GameManager
	Boot sequence for the whole server side of HYPER BLAST:
	build the map, configure lighting, then start the match loop.
	Runs after RemotesSetup (both are plain Scripts in ServerScriptService;
	every consumer WaitForChild's the remotes it needs, so exact script
	init order between them doesn't matter).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

-- Cyberpunk-at-night atmosphere: dark ambient with strong neon highlights
-- rather than a uniformly bright map (brief section 2).
Lighting.Ambient = Color3.fromRGB(20, 20, 30)
Lighting.OutdoorAmbient = Color3.fromRGB(15, 15, 25)
Lighting.Brightness = 1.5
Lighting.ClockTime = 22
Lighting.FogColor = Color3.fromRGB(20, 15, 40)
Lighting.FogStart = 120
Lighting.FogEnd = 500
Lighting.GlobalShadows = true

if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.35
	atmosphere.Color = Color3.fromRGB(40, 30, 70)
	atmosphere.Decay = Color3.fromRGB(60, 40, 100)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
end

if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Saturation = 0.15
	colorCorrection.Contrast = 0.1
	colorCorrection.TintColor = Color3.fromRGB(235, 235, 255)
	colorCorrection.Parent = Lighting
end

if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.9
	bloom.Threshold = 1.4
	bloom.Size = 24
	bloom.Parent = Lighting
end

local MapGenerator = require(script.Parent.MapGenerator)
MapGenerator.Build()

local MatchManager = require(script.Parent.MatchManager)
MatchManager.Init()

print("[HyperBlast] GameManager ready — NEON DISTRICT online.")
