--!strict
-- The Crypt: the first biome, entered through the hub's collapsed chapel floor.
-- Identity: a flooded ossuary-cathedral, cold and patient rather than hostile -
-- water-table damp stone, guttering blue-white torches, distant choir-drone
-- ambience. Mechanical hook: Chill-stacking control play (see StatusEffects.Chill
-- stacking to Stun at 3 stacks) rewards deliberate, controlled engagements over
-- rushing rooms. Generated with BSP (Binary Space Partitioning): the Crypt is
-- built from once-planned architecture (naves, galleries, vaults) that has
-- partially collapsed, so a room-and-corridor BSP layout with irregular room
-- sizing reads truer to the setting than an organic cave algorithm would.
local Types = require(script.Parent.Parent.Types)

local Crypt: Types.BiomeDef = {
	id = "Crypt",
	displayName = "The Crypt",
	identity = "A flooded ossuary-cathedral built for a court that outlived its welcome. "
		.. "Tone is cold and funerary rather than jump-scare hostile - the danger is patient, "
		.. "not frantic. Mechanical hook is attrition-and-control: Chill stacks from ice-touched "
		.. "weapons and relics build toward a hard Stun, rewarding players who fight deliberately "
		.. "over players who rush rooms. Visual palette is wet grey-blue stone with guttering "
		.. "white-blue torchlight; audio is a distant choir-drone ambience that swells when combat starts.",
	generationAlgorithm = "BSP",
	bossId = "SepulcherKing",
	ambientLoopId = "Amb_Crypt_ChoirDrone",
	combatLayerId = "Combat_Crypt_Layer",
	fogColor = Color3.fromRGB(28, 34, 40),
	fogEnd = 90,
	primaryMaterialPalette = { Enum.Material.Basalt, Enum.Material.Slate, Enum.Material.Concrete },
	accentColor = Color3.fromRGB(122, 150, 168),
	floors = {
		{
			floorIndex = 1,
			tierLabel = "Outer Ossuary",
			minRooms = 10,
			maxRooms = 14,
			enemyTierRange = { 1, 1 },
			spawnTable = {
				{ enemyId = "RattlingSwarm", weight = 55 },
				{ enemyId = "GraveWarden", weight = 30 },
				{ enemyId = "WailingHusk", weight = 15 },
			},
			hazardDensity = 0.05, -- shallow standing water only, mostly cosmetic
			vaultChance = 0.15,
			isBossFloor = false,
		},
		{
			floorIndex = 2,
			tierLabel = "Sunken Nave",
			minRooms = 11,
			maxRooms = 15,
			enemyTierRange = { 1, 1 },
			spawnTable = {
				{ enemyId = "RattlingSwarm", weight = 45 },
				{ enemyId = "GraveWarden", weight = 35 },
				{ enemyId = "WailingHusk", weight = 20 },
			},
			hazardDensity = 0.12, -- deeper flooded sections slow movement
			vaultChance = 0.18,
			isBossFloor = false,
		},
		{
			floorIndex = 3,
			tierLabel = "Reliquary Halls",
			minRooms = 12,
			maxRooms = 16,
			enemyTierRange = { 1, 1 },
			spawnTable = {
				{ enemyId = "GraveWarden", weight = 40 },
				{ enemyId = "WailingHusk", weight = 30 },
				{ enemyId = "RattlingSwarm", weight = 30 },
			},
			hazardDensity = 0.15,
			vaultChance = 0.22, -- reliquaries are where the biome's best vault loot lives
			isBossFloor = false,
		},
		{
			floorIndex = 4,
			tierLabel = "The Long Vigil",
			minRooms = 13,
			maxRooms = 17,
			enemyTierRange = { 1, 1 },
			spawnTable = {
				{ enemyId = "GraveWarden", weight = 45 },
				{ enemyId = "WailingHusk", weight = 25 },
				{ enemyId = "RattlingSwarm", weight = 30 },
			},
			hazardDensity = 0.18,
			vaultChance = 0.2,
			isBossFloor = false,
		},
		{
			floorIndex = 5,
			tierLabel = "Weeping Crypts",
			minRooms = 13,
			maxRooms = 18,
			enemyTierRange = { 1, 1 },
			spawnTable = {
				{ enemyId = "GraveWarden", weight = 40 },
				{ enemyId = "WailingHusk", weight = 30 },
				{ enemyId = "RattlingSwarm", weight = 30 },
			},
			hazardDensity = 0.22,
			vaultChance = 0.25,
			isBossFloor = false,
		},
		{
			floorIndex = 6,
			tierLabel = "Sepulcher Throne",
			minRooms = 1,
			maxRooms = 1, -- single hand-placed boss arena vault, not procedurally generated
			enemyTierRange = { 1, 1 },
			spawnTable = {},
			hazardDensity = 0,
			vaultChance = 0,
			isBossFloor = true,
		},
	},
}

return Crypt
