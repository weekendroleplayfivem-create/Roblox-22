--!strict
-- Aggregates every biome definition into an ordered list (run order) and an
-- id-keyed lookup. BiomeRegistry (server) is the only other place that should
-- need to know biome order - everything else resolves biomes by id.
local Types = require(script.Parent.Parent.Types)

local OrderedBiomes: { Types.BiomeDef } = {
	require(script.Crypt),
	require(script.FungalDepths),
	require(script.MoltenForge),
}

local ById: { [Types.BiomeId]: Types.BiomeDef } = {}
for _, biome in OrderedBiomes do
	ById[biome.id] = biome
end

return {
	Ordered = OrderedBiomes,
	ById = ById,
}
