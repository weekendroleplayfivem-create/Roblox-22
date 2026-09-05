--[[ ScooterData: tunable physics + cosmetic catalog for combat scooters. ]]

local ScooterData = {}

ScooterData.Physics = {
	Acceleration = 55,
	MaxSpeed = 85,
	ReverseSpeed = 35,
	BoostSpeed = 120,
	BoostDuration = 1.5,
	BoostCooldown = 5,
	BoostDrainPerSecond = 100 / 1.5, -- full meter over BoostDuration
	BoostRegenPerSecond = 18,
	BoostRegenDelay = 1.2,
	TurnSpeed = 130, -- degrees/sec at low speed
	TurnSpeedHighSpeed = 70, -- degrees/sec at max speed
	Braking = 90,
	JumpPower = 42,
	AirControl = 0.35,
	DriftTurnMultiplier = 1.6,
	DriftSpeedRetention = 0.92,
	DriftMinSpeed = 25,
	DriftBoostRewardPerSecond = 8, -- boost meter % per second of sustained drift
}

ScooterData.Camera = {
	NormalFOV = 80,
	BoostFOV = 92,
	ADSFOV = 65,
}

-- Cosmetic scooter skins. Purely visual (color/material), no stat changes.
ScooterData.Skins = {
	NeonGhost = {
		Id = "NeonGhost",
		DisplayName = "Neon Ghost",
		Rarity = "Epic",
		BodyColor = Color3.fromRGB(20, 20, 25),
		AccentColor = Color3.fromRGB(60, 140, 255),
		Material = Enum.Material.SmoothPlastic,
	},
	PurpleComet = {
		Id = "PurpleComet",
		DisplayName = "Purple Comet",
		Rarity = "Rare",
		BodyColor = Color3.fromRGB(35, 25, 45),
		AccentColor = Color3.fromRGB(170, 70, 255),
		Material = Enum.Material.SmoothPlastic,
	},
	CyberTiger = {
		Id = "CyberTiger",
		DisplayName = "Cyber Tiger",
		Rarity = "Legendary",
		BodyColor = Color3.fromRGB(15, 15, 15),
		AccentColor = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Metal,
	},
	VoidRacer = {
		Id = "VoidRacer",
		DisplayName = "Void Racer",
		Rarity = "Epic",
		BodyColor = Color3.fromRGB(8, 8, 10),
		AccentColor = Color3.fromRGB(120, 60, 220),
		Material = Enum.Material.Metal,
	},
	QuantumBike = {
		Id = "QuantumBike",
		DisplayName = "Quantum Bike",
		Rarity = "Mythic",
		BodyColor = Color3.fromRGB(30, 30, 40),
		AccentColor = Color3.fromRGB(80, 220, 255),
		Material = Enum.Material.ForceField,
	},
}

ScooterData.DefaultSkin = "NeonGhost"

return ScooterData
