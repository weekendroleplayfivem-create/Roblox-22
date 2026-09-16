--!strict
-- Resolves biome/floor data and the difficulty scaling curve applied on top of
-- it. This is the seam a "Season 1: 4th biome" content drop would extend:
-- adding a biome means adding one entry to Data/Biomes and Data/Enemies, and
-- BiomeRegistry picks it up automatically via Biomes.Ordered - no other
-- service needs to change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Biomes = require(ReplicatedStorage.Shared.Data.Biomes)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)

local BiomeRegistry = {}

function BiomeRegistry.GetBiome(biomeId: Types.BiomeId): Types.BiomeDef
	local biome = Biomes.ById[biomeId]
	assert(biome, `Unknown biome id "{biomeId}"`)
	return biome
end

function BiomeRegistry.GetBiomeOrder(): { Types.BiomeDef }
	return Biomes.Ordered
end

function BiomeRegistry.GetFloor(biomeId: Types.BiomeId, floorIndex: number): Types.FloorConfig
	local biome = BiomeRegistry.GetBiome(biomeId)
	local floor = biome.floors[floorIndex]
	assert(floor, `Biome "{biomeId}" has no floor {floorIndex}`)
	return floor
end

function BiomeRegistry.GetBoss(biomeId: Types.BiomeId)
	local biome = BiomeRegistry.GetBiome(biomeId)
	local boss = Bosses[biome.bossId]
	assert(boss, `Biome "{biomeId}" references unknown boss "{biome.bossId}"`)
	return boss
end

-- Difficulty scaling curve: enemy stats scale per absolute floor number across
-- the whole run (floor 7 = Fungal floor 1 is harder than Crypt floor 6), not
-- reset per-biome, so biome transitions feel like a continuation rather than
-- a difficulty reset. Curve is deliberately superlinear-but-damped (sqrt
-- growth after floor 6) so late-run enemies scale with the Vampire-Survivors-
-- style power snowball from relics/talents instead of out-pacing it linearly.
function BiomeRegistry.GetDifficultyMultiplier(absoluteFloorNumber: number, ante: number?): number
	local base = 1 + (absoluteFloorNumber - 1) * 0.12
	if absoluteFloorNumber > 6 then
		base += math.sqrt(absoluteFloorNumber - 6) * 0.08
	end
	-- `ante` is the optional Balatro/Hades-style difficulty modifier tier a
	-- player opts into pre-run (see EconomyService.GetAnteModifiers) in
	-- exchange for better rewards; each ante level adds a flat 15%.
	if ante and ante > 0 then
		base *= 1 + (ante * 0.15)
	end
	return base
end

-- Converts a (biomeIndex, floorIndexWithinBiome) pair into the absolute floor
-- number used by GetDifficultyMultiplier, given every biome currently has 6
-- floors. Kept as a function (not a hardcoded *6) so a future biome with a
-- different floor count doesn't silently break difficulty continuity.
function BiomeRegistry.ToAbsoluteFloorNumber(biomeId: Types.BiomeId, floorIndexWithinBiome: number): number
	local offset = 0
	for _, biome in Biomes.Ordered do
		if biome.id == biomeId then
			return offset + floorIndexWithinBiome
		end
		offset += #biome.floors
	end
	error(`Unknown biome id "{biomeId}"`)
end

return BiomeRegistry
