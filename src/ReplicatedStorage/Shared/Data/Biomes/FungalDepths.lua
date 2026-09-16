--!strict
-- Fungal Depths: the second biome, reached through the Crypt's lowest flooded
-- stair. Identity: an organic cave network overtaken by a single, ancient
-- mycelial organism - claustrophobic, ambush-focused, and drenched in
-- bioluminescent green-violet spore light. Mechanical hook: short sightlines
-- and camouflage/ambush enemies punish players who don't slow down and read
-- their surroundings. Generated with cellular automata (not BSP) - unlike the
-- Crypt's planned architecture, these are organic caves with no original
-- floor plan, so automata-carved irregular caverns read truer than rooms and
-- corridors would.
local Types = require(script.Parent.Parent.Types)

local FungalDepths: Types.BiomeDef = {
	id = "FungalDepths",
	displayName = "The Fungal Depths",
	identity = "A cave network consumed by one ancient mycelial organism, still faintly aware of "
		.. "what walks through it. Tone is claustrophobic and ambush-driven rather than grand - "
		.. "short irregular sightlines carved by cellular automata replace the Crypt's planned "
		.. "corridors. Mechanical hook is read-and-react: camouflaged stalkers, forced-kite "
		.. "bombers, and area-denial spore bursts punish players who push forward without "
		.. "listening for tells. Palette is bioluminescent green-violet spore light against wet "
		.. "black stone; audio is a low fungal-drone hum punctuated by distant spore-pop tells.",
	generationAlgorithm = "CellularAutomata",
	bossId = "MotherSpore",
	ambientLoopId = "Amb_Fungal_SporeDrone",
	combatLayerId = "Combat_Fungal_Layer",
	fogColor = Color3.fromRGB(20, 26, 18),
	fogEnd = 55, -- shorter than Crypt's, reinforcing the claustrophobic sightline hook
	primaryMaterialPalette = { Enum.Material.Rock, Enum.Material.Ground, Enum.Material.Moss },
	accentColor = Color3.fromRGB(148, 92, 176),
	floors = {
		{
			floorIndex = 1,
			tierLabel = "Spore Threshold",
			minRooms = 14,
			maxRooms = 20, -- cave "rooms" from automata are smaller/more numerous than BSP rooms
			enemyTierRange = { 2, 2 },
			spawnTable = {
				{ enemyId = "BloatCyst", weight = 40 },
				{ enemyId = "SporeStalker", weight = 40 },
				{ enemyId = "MycelialWeaver", weight = 20 },
			},
			hazardDensity = 0.1, -- spore-gas pockets
			vaultChance = 0.15,
			isBossFloor = false,
		},
		{
			floorIndex = 2,
			tierLabel = "Weeping Hollows",
			minRooms = 15,
			maxRooms = 21,
			enemyTierRange = { 2, 2 },
			spawnTable = {
				{ enemyId = "SporeStalker", weight = 45 },
				{ enemyId = "BloatCyst", weight = 30 },
				{ enemyId = "MycelialWeaver", weight = 25 },
			},
			hazardDensity = 0.15,
			vaultChance = 0.18,
			isBossFloor = false,
		},
		{
			floorIndex = 3,
			tierLabel = "The Undergrowth",
			minRooms = 16,
			maxRooms = 22,
			enemyTierRange = { 2, 2 },
			spawnTable = {
				{ enemyId = "SporeStalker", weight = 35 },
				{ enemyId = "BloatCyst", weight = 35 },
				{ enemyId = "MycelialWeaver", weight = 30 },
			},
			hazardDensity = 0.2,
			vaultChance = 0.2,
			isBossFloor = false,
		},
		{
			floorIndex = 4,
			tierLabel = "Bloomveins",
			minRooms = 16,
			maxRooms = 22,
			enemyTierRange = { 2, 2 },
			spawnTable = {
				{ enemyId = "MycelialWeaver", weight = 35 },
				{ enemyId = "SporeStalker", weight = 35 },
				{ enemyId = "BloatCyst", weight = 30 },
			},
			hazardDensity = 0.25,
			vaultChance = 0.2,
			isBossFloor = false,
		},
		{
			floorIndex = 5,
			tierLabel = "Choking Gallery",
			minRooms = 17,
			maxRooms = 23,
			enemyTierRange = { 2, 2 },
			spawnTable = {
				{ enemyId = "MycelialWeaver", weight = 30 },
				{ enemyId = "SporeStalker", weight = 40 },
				{ enemyId = "BloatCyst", weight = 30 },
			},
			hazardDensity = 0.3, -- densest spore-gas coverage before the boss
			vaultChance = 0.25,
			isBossFloor = false,
		},
		{
			floorIndex = 6,
			tierLabel = "Mother's Chamber",
			minRooms = 1,
			maxRooms = 1,
			enemyTierRange = { 2, 2 },
			spawnTable = {},
			hazardDensity = 0,
			vaultChance = 0,
			isBossFloor = true,
		},
	},
}

return FungalDepths
