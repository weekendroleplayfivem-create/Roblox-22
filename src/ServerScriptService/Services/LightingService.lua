--!strict
-- Per-biome Lighting/atmosphere. Applies a biome's fog/palette to the global
-- Lighting service on floor transition, and manages flickering torch point
-- lights so each room reads as lit-by-something rather than ambiently bright.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local LightingService = {}

local flickeringLights: { [PointLight]: { baseBrightness: number, seed: number } } = {}

-- Presets tuned per biome identity (see Data/Biomes/*.identity for the prose
-- version of these choices): the Crypt reads cold and even, the Fungal
-- Depths reads dim and close, the Molten Forge reads hot and high-contrast.
local BiomeLightingPresets: { [Types.BiomeId]: { ambient: Color3, brightness: number, outdoorAmbient: Color3 } } = {
	Crypt = { ambient = Color3.fromRGB(48, 58, 64), brightness = 1.4, outdoorAmbient = Color3.fromRGB(30, 36, 42) },
	FungalDepths = { ambient = Color3.fromRGB(40, 30, 52), brightness = 0.9, outdoorAmbient = Color3.fromRGB(20, 16, 28) },
	MoltenForge = { ambient = Color3.fromRGB(58, 32, 20), brightness = 1.6, outdoorAmbient = Color3.fromRGB(40, 20, 12) },
}

function LightingService.ApplyBiome(biome: Types.BiomeDef)
	local preset = BiomeLightingPresets[biome.id]
	assert(preset, `No lighting preset for biome "{biome.id}"`)

	Lighting.Ambient = preset.ambient
	Lighting.OutdoorAmbient = preset.outdoorAmbient
	Lighting.Brightness = preset.brightness
	Lighting.FogColor = biome.fogColor
	Lighting.FogEnd = biome.fogEnd
	Lighting.FogStart = 0
end

-- Registers a torch/point light for the ambient flicker loop. Each light
-- gets its own pseudo-random seed so a room full of torches flickers
-- asynchronously rather than in visible unison (a dead giveaway of a single
-- shared sine-wave driving every light in the scene).
function LightingService.RegisterFlicker(light: PointLight)
	flickeringLights[light] = { baseBrightness = light.Brightness, seed = math.random(1, 10000) }
	light.Destroying:Connect(function()
		flickeringLights[light] = nil
	end)
end

function LightingService.Tick()
	local t = os.clock()
	for light, state in flickeringLights do
		-- Layered sine noise (two frequencies) reads as organic flicker rather
		-- than a metronomic pulse - a single sine wave is a common tell.
		local noise = math.sin(t * 7 + state.seed) * 0.5 + math.sin(t * 13 + state.seed * 2) * 0.5
		light.Brightness = state.baseBrightness * (0.85 + noise * 0.15)
	end
end

return LightingService
