--!strict
--[[
	EnemyData
	Base stats for every rogue machine. Adaptive variants (Flanker, Sprinter,
	Armor Unit) are separate entries rather than buffed Normals, so the player
	can actually SEE the counter arrive — the adaptation has to be legible or
	it just feels like the game got harder for no reason.

	Resistances are multipliers applied to incoming effects:
	  SlowResistance  1.0 = fully slowed, 0.0 = immune
	  DamageResistance 1.0 = full damage,  0.7 = takes 30% less
]]

export type Enemy = {
	Id: string,
	DisplayName: string,
	Health: number,
	Speed: number,
	Reward: number,
	CoreDamage: number,
	Size: Vector3,
	Color: Color3,
	EyeColor: Color3,
	SlowResistance: number,
	DamageResistance: number,
	IsBoss: boolean?,
	Description: string,
}

local EnemyData = {}

EnemyData.Enemies = {
	Normal = {
		Id = "Normal",
		DisplayName = "Drone",
		Health = 100,
		Speed = 8,
		Reward = 20,
		CoreDamage = 5,
		Size = Vector3.new(3, 3.5, 3),
		Color = Color3.fromRGB(120, 128, 140),
		EyeColor = Color3.fromRGB(255, 90, 90),
		SlowResistance = 1,
		DamageResistance = 1,
		Description = "Standard escaped unit.",
	},

	Runner = {
		Id = "Runner",
		DisplayName = "Runner",
		Health = 55,
		Speed = 14,
		Reward = 25,
		CoreDamage = 4,
		Size = Vector3.new(2.2, 3.8, 2.2),
		Color = Color3.fromRGB(150, 140, 110),
		EyeColor = Color3.fromRGB(255, 180, 60),
		SlowResistance = 1,
		DamageResistance = 1,
		Description = "Thin chassis, overclocked drive.",
	},

	Tank = {
		Id = "Tank",
		DisplayName = "Tank",
		Health = 500,
		Speed = 4,
		Reward = 75,
		CoreDamage = 15,
		Size = Vector3.new(6, 5.5, 6),
		Color = Color3.fromRGB(90, 96, 104),
		EyeColor = Color3.fromRGB(255, 70, 70),
		SlowResistance = 1,
		DamageResistance = 1,
		Description = "Heavy armoured hauler.",
	},

	--== Adaptive variants =====================================================

	Flanker = {
		Id = "Flanker",
		DisplayName = "Flanker",
		Health = 120,
		Speed = 10,
		Reward = 30,
		CoreDamage = 6,
		Size = Vector3.new(3, 3.2, 3.4),
		Color = Color3.fromRGB(110, 90, 140),
		EyeColor = Color3.fromRGB(190, 120, 255),
		SlowResistance = 1,
		DamageResistance = 1,
		Description = "Routes toward your thinnest defence.",
	},

	Sprinter = {
		Id = "Sprinter",
		DisplayName = "Sprinter",
		Health = 90,
		Speed = 16,
		Reward = 35,
		CoreDamage = 5,
		Size = Vector3.new(2.2, 4, 2.2),
		Color = Color3.fromRGB(160, 120, 90),
		EyeColor = Color3.fromRGB(255, 200, 80),
		SlowResistance = 0.45, -- shrugs off most of a Cryo field
		DamageResistance = 1,
		Description = "Hardened drive coils. Resists slowing.",
	},

	ArmorUnit = {
		Id = "ArmorUnit",
		DisplayName = "Armour Unit",
		Health = 260,
		Speed = 6,
		Reward = 55,
		CoreDamage = 10,
		Size = Vector3.new(4.6, 4.6, 4.6),
		Color = Color3.fromRGB(80, 100, 96),
		EyeColor = Color3.fromRGB(120, 255, 180),
		SlowResistance = 1,
		DamageResistance = 0.7, -- blunts high-rate chip damage
		Description = "Plated against sustained low-calibre fire.",
	},

	--== Bosses ================================================================

	MiniBoss = {
		Id = "MiniBoss",
		DisplayName = "Prototype",
		Health = 2200,
		Speed = 5,
		Reward = 400,
		CoreDamage = 40,
		Size = Vector3.new(8, 8, 8),
		Color = Color3.fromRGB(70, 78, 96),
		EyeColor = Color3.fromRGB(255, 120, 60),
		SlowResistance = 0.7,
		DamageResistance = 0.9,
		IsBoss = true,
		Description = "An early build. It remembers less than its successor.",
	},

	Learner = {
		Id = "Learner",
		DisplayName = "THE LEARNER",
		Health = 9000,
		Speed = 4.5,
		Reward = 2000,
		CoreDamage = 1000, -- reaching the Core ends the run
		Size = Vector3.new(12, 12, 12),
		Color = Color3.fromRGB(40, 44, 58),
		EyeColor = Color3.fromRGB(255, 60, 60),
		SlowResistance = 0.8,
		DamageResistance = 0.95,
		IsBoss = true,
		Description = "It has been watching the whole time.",
	},
} :: { [string]: Enemy }

function EnemyData.Get(enemyId: string): Enemy?
	return EnemyData.Enemies[enemyId]
end

return EnemyData
