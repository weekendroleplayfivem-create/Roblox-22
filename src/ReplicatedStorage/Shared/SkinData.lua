--[[ SkinData: original weapon skin catalog. Cosmetic only, never affects stats. ]]

local SkinData = {}

SkinData.Rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

SkinData.RarityColor = {
	Common = Color3.fromRGB(180, 180, 190),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(170, 70, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 60, 140),
}

-- Each collection can be applied to any weapon that has a matching entry.
SkinData.Collections = {
	CyberWave = {
		Id = "CyberWave",
		DisplayName = "Cyberwave",
		Rarity = "Epic",
		PrimaryColor = Color3.fromRGB(40, 150, 255),
		SecondaryColor = Color3.fromRGB(160, 70, 255),
		Material = Enum.Material.SmoothPlastic,
		MuzzleColor = Color3.fromRGB(120, 200, 255),
	},
	VoidCore = {
		Id = "VoidCore",
		DisplayName = "Voidcore",
		Rarity = "Legendary",
		PrimaryColor = Color3.fromRGB(15, 15, 18),
		SecondaryColor = Color3.fromRGB(140, 40, 220),
		Material = Enum.Material.Metal,
		MuzzleColor = Color3.fromRGB(170, 60, 255),
	},
	ArcticPulse = {
		Id = "ArcticPulse",
		DisplayName = "Arctic Pulse",
		Rarity = "Rare",
		PrimaryColor = Color3.fromRGB(235, 245, 255),
		SecondaryColor = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Ice,
		MuzzleColor = Color3.fromRGB(180, 230, 255),
	},
	PlasmaRush = {
		Id = "PlasmaRush",
		DisplayName = "Plasma Rush",
		Rarity = "Epic",
		PrimaryColor = Color3.fromRGB(150, 30, 220),
		SecondaryColor = Color3.fromRGB(255, 60, 160),
		Material = Enum.Material.Neon,
		MuzzleColor = Color3.fromRGB(255, 100, 200),
	},
	NeonCircuit = {
		Id = "NeonCircuit",
		DisplayName = "Neon Circuit",
		Rarity = "Rare",
		PrimaryColor = Color3.fromRGB(20, 20, 25),
		SecondaryColor = Color3.fromRGB(60, 255, 200),
		Material = Enum.Material.SmoothPlastic,
		MuzzleColor = Color3.fromRGB(80, 255, 210),
		Animated = true,
	},
	Quantum = {
		Id = "Quantum",
		DisplayName = "Quantum",
		Rarity = "Mythic",
		PrimaryColor = Color3.fromRGB(60, 60, 80),
		SecondaryColor = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.ForceField,
		MuzzleColor = Color3.fromRGB(200, 220, 255),
		Animated = true,
	},
	Default = {
		Id = "Default",
		DisplayName = "Standard Issue",
		Rarity = "Common",
		PrimaryColor = Color3.fromRGB(30, 30, 34),
		SecondaryColor = Color3.fromRGB(60, 140, 255),
		Material = Enum.Material.Metal,
		MuzzleColor = Color3.fromRGB(255, 220, 150),
	},
}

SkinData.DefaultSkin = "Default"

return SkinData
