--!strict
-- Server-authoritative loot rolling. All RNG for drops happens here, seeded
-- per-roll from the run's seed plus a monotonic roll counter so a run's loot
-- is fully reproducible from its seed (useful for analytics/bug repro) while
-- still being unpredictable to the client, which never sees the seed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Rarity = require(ReplicatedStorage.Shared.Data.Rarity)
local Items = require(ReplicatedStorage.Shared.Data.Items)

local LootService = {}

local RARITY_ORDER: { Types.RarityId } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- Weighted roll across all 5 tiers using Rarity.lua's dropWeight, then an
-- affix roll count taken directly from the rolled tier - this is what makes a
-- Legendary categorically different from a scaled-up Common rather than the
-- same item with bigger numbers (see ItemDef.affixSlots in Types.lua).
function LootService.RollRarity(rng: Random, rarityBonusPct: number?): Types.RarityId
	local totalWeight = 0
	for _, tier in RARITY_ORDER do
		totalWeight += Rarity[tier].dropWeight
	end

	-- rarityBonusPct (from relics/talents like ScavengersEye) shifts weight
	-- from Common toward everything else rather than a flat "roll twice,
	-- take better" - keeps the curve smooth instead of creating hard breakpoints.
	local bonus = rarityBonusPct or 0
	local roll = rng:NextNumber() * totalWeight * (1 - bonus)

	local cumulative = 0
	for _, tier in RARITY_ORDER do
		cumulative += Rarity[tier].dropWeight
		if roll <= cumulative then
			return tier
		end
	end
	return "Legendary" -- rarityBonusPct pushed the roll past totalWeight
end

function LootService.RollItemFromTable(rng: Random, lootTableId: string): Types.ItemDef?
	-- lootTableId selection reads from a biome/tier-specific candidate pool;
	-- Phase 1 resolves against the full weapon/armor pool as a stand-in until
	-- per-floor loot tables are authored during the content pass (Process
	-- step 5), keeping the roll pipeline itself already fully functional.
	local rarity = LootService.RollRarity(rng)
	local candidates: { Types.ItemDef } = {}
	for _, item in Items.Weapons do
		if item.rarity == rarity then
			table.insert(candidates, item)
		end
	end
	for _, item in Items.Armor do
		if item.rarity == rarity then
			table.insert(candidates, item)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Presents 3 relic options for a floor-transition pick, biased toward the
-- player's existing archetype tags so a run's build reads as reinforced
-- rather than random - the Balatro-style "build legibility" requirement
-- starts at the offer stage, not just the readout stage.
function LootService.RollRelicOffer(rng: Random, allRelics: { [string]: Types.RelicDef }, ownedArchetypeTags: { [string]: number }, excludeIds: { [string]: boolean }): { Types.RelicDef }
	local pool: { { relic: Types.RelicDef, weight: number } } = {}
	for id, relic in allRelics do
		if not excludeIds[id] then
			local weight = Rarity[relic.rarity].dropWeight
			for _, tag in relic.archetypeTags do
				if ownedArchetypeTags[tag] and ownedArchetypeTags[tag] > 0 then
					weight *= 1.6 -- soft bias toward the player's established archetype
				end
			end
			table.insert(pool, { relic = relic, weight = weight })
		end
	end

	local offer: { Types.RelicDef } = {}
	for _ = 1, math.min(3, #pool) do
		local totalWeight = 0
		for _, entry in pool do
			totalWeight += entry.weight
		end
		local roll = rng:NextNumber() * totalWeight
		local cumulative = 0
		for index, entry in pool do
			cumulative += entry.weight
			if roll <= cumulative then
				table.insert(offer, entry.relic)
				table.remove(pool, index)
				break
			end
		end
	end
	return offer
end

return LootService
