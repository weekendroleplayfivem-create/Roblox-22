--!strict
-- Aggregates every biome's enemy roster into one id-keyed lookup so
-- EnemyAIService/LootService/DungeonGenerator can resolve any enemy id without
-- knowing which biome file it lives in. Adding a biome's enemy file to the
-- `sources` list here is the only wiring a new biome's roster needs.
local Types = require(script.Parent.Parent.Types)

local sources = {
	require(script.Crypt),
	require(script.FungalDepths),
	require(script.MoltenForge),
}

local ById: { [string]: Types.EnemyArchetypeDef } = {}
for _, roster in sources do
	for _, enemy in roster do
		assert(not ById[enemy.id], `Duplicate enemy id "{enemy.id}"`)
		ById[enemy.id] = enemy
	end
end

return ById
