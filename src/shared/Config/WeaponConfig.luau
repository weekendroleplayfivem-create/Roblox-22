--!nonstrict
--[[
	WeaponConfig.luau
	Data-driven weapon definitions. Nothing about a weapon is hard-coded in the
	controllers - if you want a new gun, add a table here.

	Balance shape of the arsenal (this is the actual design intent, keep it):
		PULSE    - the honest default. Wins mid-range trades if you can track.
		VOLT     - beats PULSE inside 25 studs, loses hard past 45.
		FRACTURE - lethal inside 14 studs, a joke outside it. Rewards flank routes.
		LANCE    - one-shots to the head, punishing on-miss. Rewards holding a line.
		SPARK    - sidearm; the answer to "I got caught mid-reload".
		RIFT     - melee finisher; fast, mobile, no ammo economy.

	Recoil philosophy: every pattern is DETERMINISTIC for the first N shots, with a
	small random cone bolted on. Deterministic patterns are learnable, which is what
	turns spraying into a skill instead of a dice roll.
--]]

local Palette = require(script.Parent.Palette)

local WeaponConfig = {}

WeaponConfig.Slots = {
	Primary = 1,
	Secondary = 2,
	Melee = 3,
}

-- Shared damage falloff helper shape: damage is `Base` up to `Start`, then lerps
-- down to `Base * EndMultiplier` at `End`, and stays flat past it.
local function falloff(startStud: number, endStud: number, endMultiplier: number)
	return { Start = startStud, End = endStud, EndMultiplier = endMultiplier }
end

WeaponConfig.Weapons = {
	--------------------------------------------------------------------
	PULSE = {
		Id = "PULSE",
		DisplayName = "PULSE-7",
		Class = "Assault Rifle",
		Slot = WeaponConfig.Slots.Primary,

		FireMode = "Auto",
		Rpm = 660,
		Damage = 24,
		HeadshotMultiplier = 1.85,
		LegMultiplier = 0.85,
		Falloff = falloff(45, 95, 0.62),
		Pellets = 1,
		Range = 900,

		MagSize = 30,
		ReserveAmmo = 150,
		ReloadTime = 2.05,
		EmptyReloadTime = 2.55,

		SpreadHip = 1.35, -- degrees of cone
		SpreadAds = 0.18,
		SpreadMoveScale = 0.9, -- extra cone per (speed / sprintSpeed)
		SpreadJumpScale = 2.4,
		SpreadRecovery = 6.5,

		AdsTime = 0.18,
		AdsFov = 70,
		AdsSpeedMultiplier = 0.62,
		EquipTime = 0.30,
		InspectTime = 2.4,
		MoveSpeedMultiplier = 1.0,

		-- {vertical, horizontal}. Index clamps to the last entry (sustained spray).
		RecoilPattern = {
			Vector2.new(1.30, 0.05),
			Vector2.new(1.15, -0.22),
			Vector2.new(1.05, 0.30),
			Vector2.new(0.95, -0.42),
			Vector2.new(0.88, 0.48),
			Vector2.new(0.80, -0.30),
			Vector2.new(0.74, 0.62),
			Vector2.new(0.70, -0.70),
			Vector2.new(0.66, 0.55),
			Vector2.new(0.62, -0.48),
		},
		RecoilJitter = 0.14,
		RecoilRecovery = 9.0, -- how fast the camera returns after the last shot
		RecoilResetTime = 0.32, -- trigger released this long -> pattern index resets
		VisualKick = { back = 0.16, up = 0.07, roll = 2.2 },

		Muzzle = { Color = Palette.NeonCyan, Size = 1.0, Light = 6 },
		Tracer = { Color = Palette.NeonCyan, Width = 0.09, Life = 0.07 },
		Skin = "VoltEdge",

		Viewmodel = {
			Length = 2.6,
			BarrelLength = 1.15,
			Accent = Palette.NeonCyan,
			GripOffset = Vector3.new(0.95, -0.75, -1.35),
			AdsOffset = Vector3.new(0, -0.42, -0.95),
			ReloadStyle = "MagSwap",
		},
	},

	--------------------------------------------------------------------
	VOLT = {
		Id = "VOLT",
		DisplayName = "VOLT-SMG",
		Class = "Submachine Gun",
		Slot = WeaponConfig.Slots.Primary,

		FireMode = "Auto",
		Rpm = 900,
		Damage = 16,
		HeadshotMultiplier = 1.7,
		LegMultiplier = 0.9,
		Falloff = falloff(25, 55, 0.5),
		Pellets = 1,
		Range = 600,

		MagSize = 35,
		ReserveAmmo = 175,
		ReloadTime = 1.65,
		EmptyReloadTime = 2.1,

		SpreadHip = 2.1,
		SpreadAds = 0.55,
		SpreadMoveScale = 0.45, -- barely punished for moving: this is the runner's gun
		SpreadJumpScale = 1.5,
		SpreadRecovery = 8.0,

		AdsTime = 0.13,
		AdsFov = 76,
		AdsSpeedMultiplier = 0.75,
		EquipTime = 0.22,
		InspectTime = 2.0,
		MoveSpeedMultiplier = 1.06, -- rewards the aggressive movement build

		RecoilPattern = {
			Vector2.new(0.92, 0.18),
			Vector2.new(0.86, -0.30),
			Vector2.new(0.80, 0.42),
			Vector2.new(0.74, -0.52),
			Vector2.new(0.70, 0.60),
			Vector2.new(0.66, -0.66),
			Vector2.new(0.62, 0.72),
		},
		RecoilJitter = 0.22,
		RecoilRecovery = 11.0,
		RecoilResetTime = 0.26,
		VisualKick = { back = 0.11, up = 0.05, roll = 1.6 },

		Muzzle = { Color = Palette.NeonBlue, Size = 0.8, Light = 5 },
		Tracer = { Color = Palette.NeonBlue, Width = 0.07, Life = 0.06 },
		Skin = "PulseWave",

		Viewmodel = {
			Length = 1.9,
			BarrelLength = 0.75,
			Accent = Palette.NeonBlue,
			GripOffset = Vector3.new(0.88, -0.70, -1.15),
			AdsOffset = Vector3.new(0, -0.38, -0.8),
			ReloadStyle = "MagSwap",
		},
	},

	--------------------------------------------------------------------
	FRACTURE = {
		Id = "FRACTURE",
		DisplayName = "FRACTURE-12",
		Class = "Energy Shotgun",
		Slot = WeaponConfig.Slots.Primary,

		FireMode = "Semi",
		Rpm = 78,
		Damage = 11, -- per pellet
		HeadshotMultiplier = 1.5,
		LegMultiplier = 0.95,
		Falloff = falloff(14, 34, 0.28),
		Pellets = 9,
		Range = 220,

		MagSize = 6,
		ReserveAmmo = 36,
		ReloadTime = 2.6,
		EmptyReloadTime = 2.9,
		ShellReload = true, -- reloads one shell at a time, cancellable

		SpreadHip = 5.2,
		SpreadAds = 3.4,
		SpreadMoveScale = 0.3,
		SpreadJumpScale = 0.8,
		SpreadRecovery = 5.0,

		AdsTime = 0.22,
		AdsFov = 80,
		AdsSpeedMultiplier = 0.7,
		EquipTime = 0.34,
		InspectTime = 2.6,
		MoveSpeedMultiplier = 0.98,

		RecoilPattern = {
			Vector2.new(3.4, 0.0),
			Vector2.new(3.1, 0.5),
			Vector2.new(3.1, -0.5),
		},
		RecoilJitter = 0.3,
		RecoilRecovery = 6.0,
		RecoilResetTime = 0.45,
		VisualKick = { back = 0.42, up = 0.20, roll = 4.5 },

		Muzzle = { Color = Palette.NeonMagenta, Size = 1.7, Light = 9 },
		Tracer = { Color = Palette.NeonMagenta, Width = 0.06, Life = 0.05 },
		Skin = "HexBurst",

		Viewmodel = {
			Length = 2.4,
			BarrelLength = 1.3,
			Accent = Palette.NeonMagenta,
			GripOffset = Vector3.new(0.95, -0.78, -1.3),
			AdsOffset = Vector3.new(0, -0.44, -0.9),
			ReloadStyle = "ShellFeed",
		},
	},

	--------------------------------------------------------------------
	LANCE = {
		Id = "LANCE",
		DisplayName = "LANCE-R",
		Class = "Rail Marksman",
		Slot = WeaponConfig.Slots.Primary,

		FireMode = "Semi",
		Rpm = 48,
		Damage = 78,
		HeadshotMultiplier = 1.6, -- 124 -> lethal on a 100hp target
		LegMultiplier = 0.75,
		Falloff = falloff(200, 400, 0.9),
		Pellets = 1,
		Range = 1400,
		Piercing = 1, -- punches through one thin surface / player

		MagSize = 5,
		ReserveAmmo = 25,
		ReloadTime = 2.4,
		EmptyReloadTime = 2.8,

		SpreadHip = 4.5, -- hip-firing a rail gun is a mistake, and it should feel like one
		SpreadAds = 0.0,
		SpreadMoveScale = 1.6,
		SpreadJumpScale = 3.5,
		SpreadRecovery = 4.0,

		AdsTime = 0.28,
		AdsFov = 42,
		AdsSpeedMultiplier = 0.45,
		EquipTime = 0.42,
		InspectTime = 2.8,
		MoveSpeedMultiplier = 0.94,

		RecoilPattern = {
			Vector2.new(4.6, 0.15),
			Vector2.new(4.2, -0.4),
		},
		RecoilJitter = 0.1,
		RecoilRecovery = 5.0,
		RecoilResetTime = 0.6,
		VisualKick = { back = 0.5, up = 0.26, roll = 3.0 },

		Muzzle = { Color = Palette.NeonPurple, Size = 1.4, Light = 12 },
		Tracer = { Color = Palette.NeonPurple, Width = 0.16, Life = 0.13 },
		Skin = "PhaseLance",

		Viewmodel = {
			Length = 3.2,
			BarrelLength = 1.8,
			Accent = Palette.NeonPurple,
			GripOffset = Vector3.new(0.98, -0.74, -1.5),
			AdsOffset = Vector3.new(0, -0.40, -1.1),
			ReloadStyle = "BoltCycle",
		},
	},

	--------------------------------------------------------------------
	SPARK = {
		Id = "SPARK",
		DisplayName = "SPARK-9",
		Class = "Sidearm",
		Slot = WeaponConfig.Slots.Secondary,

		FireMode = "Semi",
		Rpm = 300,
		Damage = 26,
		HeadshotMultiplier = 2.0,
		LegMultiplier = 0.85,
		Falloff = falloff(28, 60, 0.55),
		Pellets = 1,
		Range = 500,

		MagSize = 14,
		ReserveAmmo = 70,
		ReloadTime = 1.35,
		EmptyReloadTime = 1.7,

		SpreadHip = 1.1,
		SpreadAds = 0.25,
		SpreadMoveScale = 0.6,
		SpreadJumpScale = 1.8,
		SpreadRecovery = 9.0,

		AdsTime = 0.11,
		AdsFov = 74,
		AdsSpeedMultiplier = 0.82,
		EquipTime = 0.16, -- fastest swap in the game: the panic answer
		InspectTime = 1.8,
		MoveSpeedMultiplier = 1.1,

		RecoilPattern = {
			Vector2.new(1.9, 0.12),
			Vector2.new(1.7, -0.3),
			Vector2.new(1.6, 0.35),
		},
		RecoilJitter = 0.18,
		RecoilRecovery = 12.0,
		RecoilResetTime = 0.3,
		VisualKick = { back = 0.2, up = 0.11, roll = 2.4 },

		Muzzle = { Color = Palette.NeonAmber, Size = 0.8, Light = 5 },
		Tracer = { Color = Palette.NeonAmber, Width = 0.07, Life = 0.06 },
		Skin = "EmberDot",

		Viewmodel = {
			Length = 1.3,
			BarrelLength = 0.5,
			Accent = Palette.NeonAmber,
			GripOffset = Vector3.new(0.7, -0.62, -0.9),
			AdsOffset = Vector3.new(0, -0.34, -0.66),
			ReloadStyle = "MagSwap",
		},
	},

	--------------------------------------------------------------------
	RIFT = {
		Id = "RIFT",
		DisplayName = "RIFT BLADE",
		Class = "Melee",
		Slot = WeaponConfig.Slots.Melee,

		FireMode = "Melee",
		Rpm = 105,
		Damage = 62,
		HeadshotMultiplier = 1.0,
		LegMultiplier = 1.0,
		BackstabMultiplier = 2.2, -- rewards the flank route, again
		Falloff = falloff(9, 10, 1.0),
		Pellets = 1,
		Range = 9.5,

		MagSize = math.huge,
		ReserveAmmo = 0,
		ReloadTime = 0,
		EmptyReloadTime = 0,

		SpreadHip = 0,
		SpreadAds = 0,
		SpreadMoveScale = 0,
		SpreadJumpScale = 0,
		SpreadRecovery = 0,

		AdsTime = 0.1,
		AdsFov = 90,
		AdsSpeedMultiplier = 1.0,
		EquipTime = 0.18,
		InspectTime = 2.2,
		MoveSpeedMultiplier = 1.14, -- knife-out running is a real movement choice

		RecoilPattern = { Vector2.new(0, 0) },
		RecoilJitter = 0,
		RecoilRecovery = 10,
		RecoilResetTime = 0.3,
		VisualKick = { back = 0.0, up = 0.0, roll = 0.0 },

		Muzzle = { Color = Palette.NeonLime, Size = 0, Light = 0 },
		Tracer = { Color = Palette.NeonLime, Width = 0.0, Life = 0.0 },
		Skin = "RiftEdge",

		Viewmodel = {
			Length = 1.7,
			BarrelLength = 0.0,
			Accent = Palette.NeonLime,
			GripOffset = Vector3.new(0.8, -0.7, -1.0),
			AdsOffset = Vector3.new(0.35, -0.5, -0.8),
			ReloadStyle = "None",
		},
	},
}

-- Elimination effect "skins": what an enemy dissolves into when you kill them.
-- Keyed by the `Skin` field above so the kill visually credits the weapon.
WeaponConfig.Skins = {
	VoltEdge = { Primary = Palette.NeonCyan, Secondary = Palette.NeonBlue, Shape = "Shards", Particles = 46 },
	PulseWave = { Primary = Palette.NeonBlue, Secondary = Palette.NeonCyan, Shape = "Rings", Particles = 38 },
	HexBurst = { Primary = Palette.NeonMagenta, Secondary = Palette.NeonPurple, Shape = "Scatter", Particles = 64 },
	PhaseLance = { Primary = Palette.NeonPurple, Secondary = Palette.NeonMagenta, Shape = "Beam", Particles = 30 },
	EmberDot = { Primary = Palette.NeonAmber, Secondary = Palette.NeonMagenta, Shape = "Scatter", Particles = 34 },
	RiftEdge = { Primary = Palette.NeonLime, Secondary = Palette.NeonCyan, Shape = "Slice", Particles = 42 },
}

WeaponConfig.DefaultLoadout = { Primary = "PULSE", Secondary = "SPARK", Melee = "RIFT" }

-- 1v1 Hyper Duel intentionally strips the sandbox down to movement + aim.
WeaponConfig.DuelLoadout = { Primary = "PULSE", Secondary = "SPARK", Melee = "RIFT" }

function WeaponConfig.get(id: string)
	return WeaponConfig.Weapons[id]
end

function WeaponConfig.fireInterval(def): number
	return 60 / math.max(def.Rpm, 1)
end

function WeaponConfig.skinFor(def)
	return WeaponConfig.Skins[def.Skin] or WeaponConfig.Skins.VoltEdge
end

return WeaponConfig
