--[[
	WeaponConfig
	Every weapon is pure data. Systems (client WeaponController, server
	WeaponService/CombatService, bots) read these tables; nothing about a
	weapon's behaviour is hardcoded elsewhere.

	Field reference:
	  Id, DisplayName, Category, Slot ("Primary" | "Secondary"), Description
	  Damage            base damage per bullet / pellet / tick
	  HeadshotMultiplier
	  FireRate          shots per second (bursts per second for Burst weapons)
	  FireMode          "Auto" | "Semi" | "Burst" | "Charge" | "Beam"
	  BurstCount, BurstInterval (Burst only)
	  MagazineSize, ReserveAmmo, ReloadTime
	  Range             max hit distance in studs
	  Falloff           { Start, End, MinMultiplier }
	  Spread            degrees: { Hip, Ads, Move, Air, PerShot, Max, Recovery }
	  Recoil            degrees: { Vertical, Horizontal, Recovery }
	  ProjectileType    "Hitscan" | "Projectile" | "Chain"
	  Pellets           rays per shot (Scatter)
	  Projectile        { Speed, Gravity, Lifetime, SplashRadius, SplashDamage, MinSplashMultiplier }
	  Charge            { Time, MinMultiplier, MaxMultiplier }
	  Chain             { Radius, MaxJumps, DamageMultiplier }
	  MovementPenalty   walk-speed multiplier while equipped (1 = none)
	  EquipTime, AdsFov
	  Animations        { Equip, Fire, Reload } -- PLACEHOLDER asset ids
	  Sounds            { Fire, Reload, Equip } -- keys into SoundConfig
	  CosmeticCategory  which weapon skins apply
	  UnlockLevel       level required (progression, never purchases)
	  Viewmodel         placeholder procedural model description
	  TracerColor
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local NO_ANIMATION = "" -- PLACEHOLDER: insert rbxassetid:// animation ids here.

local function animations()
	return { Equip = NO_ANIMATION, Fire = NO_ANIMATION, Reload = NO_ANIMATION }
end

local Weapons = {
	PulseRifle = {
		DisplayName = "Pulse Rifle",
		Category = "Pulse Rifle",
		Slot = "Primary",
		Description = "Reliable full-auto energy rifle. Great at any range.",
		Damage = 20,
		HeadshotMultiplier = 1.5,
		FireRate = 8,
		FireMode = "Auto",
		MagazineSize = 30,
		ReserveAmmo = 150,
		ReloadTime = 1.6,
		Range = 300,
		Falloff = { Start = 80, End = 220, MinMultiplier = 0.7 },
		Spread = { Hip = 1.6, Ads = 0.35, Move = 1.2, Air = 2.5, PerShot = 0.35, Max = 4.5, Recovery = 9 },
		Recoil = { Vertical = 0.9, Horizontal = 0.35, Recovery = 10 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 0.96,
		EquipTime = 0.3,
		AdsFov = 62,
		Sounds = { Fire = "PulseFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Rifle",
		UnlockLevel = 1,
		Viewmodel = { BodySize = Vector3.new(0.35, 0.45, 2.0), BarrelLength = 0.9, Color = Color3.fromRGB(40, 220, 255) },
		TracerColor = Color3.fromRGB(60, 230, 255),
	},

	BurstBlaster = {
		DisplayName = "Triad Burst",
		Category = "Burst Blaster",
		Slot = "Primary",
		Description = "Three-shot bursts with tight accuracy. Reward precise aim.",
		Damage = 24,
		HeadshotMultiplier = 1.5,
		FireRate = 2.6, -- bursts per second
		FireMode = "Burst",
		BurstCount = 3,
		BurstInterval = 0.065,
		MagazineSize = 24,
		ReserveAmmo = 120,
		ReloadTime = 1.8,
		Range = 320,
		Falloff = { Start = 110, End = 260, MinMultiplier = 0.75 },
		Spread = { Hip = 1.0, Ads = 0.2, Move = 0.9, Air = 2.2, PerShot = 0.15, Max = 3, Recovery = 10 },
		Recoil = { Vertical = 0.7, Horizontal = 0.2, Recovery = 12 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 0.95,
		EquipTime = 0.32,
		AdsFov = 58,
		Sounds = { Fire = "BurstFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Rifle",
		UnlockLevel = 3,
		Viewmodel = { BodySize = Vector3.new(0.4, 0.5, 1.8), BarrelLength = 0.7, Color = Color3.fromRGB(255, 200, 40) },
		TracerColor = Color3.fromRGB(255, 220, 80),
	},

	ScatterBlaster = {
		DisplayName = "Spreadshot",
		Category = "Scatter Blaster",
		Slot = "Primary",
		Description = "Fires a wide burst of energy pellets. Brutal up close.",
		Damage = 11,
		HeadshotMultiplier = 1.25,
		FireRate = 1.25,
		FireMode = "Semi",
		MagazineSize = 6,
		ReserveAmmo = 36,
		ReloadTime = 2.0,
		Range = 70,
		Falloff = { Start = 18, End = 55, MinMultiplier = 0.35 },
		Spread = { Hip = 5.5, Ads = 4.0, Move = 0.5, Air = 1.0, PerShot = 0, Max = 7, Recovery = 10 },
		Recoil = { Vertical = 3.2, Horizontal = 0.8, Recovery = 8 },
		ProjectileType = "Hitscan",
		Pellets = 9,
		MovementPenalty = 0.97,
		EquipTime = 0.35,
		AdsFov = 72,
		Sounds = { Fire = "ScatterFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Heavy",
		UnlockLevel = 2,
		Viewmodel = { BodySize = Vector3.new(0.55, 0.55, 1.6), BarrelLength = 0.5, Color = Color3.fromRGB(255, 120, 60) },
		TracerColor = Color3.fromRGB(255, 150, 80),
	},

	PrecisionBlaster = {
		DisplayName = "Longshot",
		Category = "Precision Blaster",
		Slot = "Primary",
		Description = "Slow, powerful and pin-point accurate. Can't one-shot a full-shield target.",
		Damage = 70,
		HeadshotMultiplier = 1.8, -- 126 < 150 total HP, so never an instant kill from full
		FireRate = 0.95,
		FireMode = "Semi",
		MagazineSize = 5,
		ReserveAmmo = 30,
		ReloadTime = 2.3,
		Range = 600,
		Falloff = { Start = 600, End = 600, MinMultiplier = 1 },
		Spread = { Hip = 4.5, Ads = 0, Move = 2.5, Air = 4, PerShot = 0, Max = 7, Recovery = 6 },
		Recoil = { Vertical = 4, Horizontal = 0.6, Recovery = 6 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 0.9,
		EquipTime = 0.45,
		AdsFov = 32,
		Sounds = { Fire = "PrecisionFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Precision",
		UnlockLevel = 5,
		Viewmodel = { BodySize = Vector3.new(0.35, 0.45, 2.6), BarrelLength = 1.3, Color = Color3.fromRGB(170, 90, 255) },
		TracerColor = Color3.fromRGB(190, 120, 255),
	},

	RapidBlaster = {
		DisplayName = "Buzzsaw",
		Category = "Rapid Blaster",
		Slot = "Primary",
		Description = "Very high fire rate, low damage per shot. Spray while you slide.",
		Damage = 12,
		HeadshotMultiplier = 1.4,
		FireRate = 14,
		FireMode = "Auto",
		MagazineSize = 42,
		ReserveAmmo = 210,
		ReloadTime = 1.7,
		Range = 180,
		Falloff = { Start = 40, End = 120, MinMultiplier = 0.6 },
		Spread = { Hip = 2.2, Ads = 1.2, Move = 0.6, Air = 1.2, PerShot = 0.2, Max = 5.5, Recovery = 12 },
		Recoil = { Vertical = 0.45, Horizontal = 0.45, Recovery = 12 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 1,
		EquipTime = 0.25,
		AdsFov = 70,
		Sounds = { Fire = "RapidFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Compact",
		UnlockLevel = 1,
		Viewmodel = { BodySize = Vector3.new(0.4, 0.5, 1.3), BarrelLength = 0.4, Color = Color3.fromRGB(80, 255, 140) },
		TracerColor = Color3.fromRGB(100, 255, 160),
	},

	PlasmaLauncher = {
		DisplayName = "Plasmortar",
		Category = "Plasma Launcher",
		Slot = "Primary",
		Description = "Lobs slow plasma orbs that burst on impact.",
		Damage = 55, -- direct-hit bonus on top of splash
		HeadshotMultiplier = 1,
		FireRate = 1.1,
		FireMode = "Semi",
		MagazineSize = 4,
		ReserveAmmo = 16,
		ReloadTime = 2.4,
		Range = 400,
		Falloff = { Start = 400, End = 400, MinMultiplier = 1 },
		Spread = { Hip = 0, Ads = 0, Move = 0, Air = 0, PerShot = 0, Max = 0, Recovery = 1 },
		Recoil = { Vertical = 3.5, Horizontal = 0.4, Recovery = 7 },
		ProjectileType = "Projectile",
		Pellets = 1,
		Projectile = {
			Speed = 130,
			Gravity = 40,
			Lifetime = 4,
			Radius = 0.6,
			SplashRadius = 11,
			SplashDamage = 60,
			MinSplashMultiplier = 0.3,
		},
		MovementPenalty = 0.9,
		EquipTime = 0.45,
		AdsFov = 70,
		Sounds = { Fire = "PlasmaFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Heavy",
		UnlockLevel = 8,
		Viewmodel = { BodySize = Vector3.new(0.6, 0.6, 1.9), BarrelLength = 0.6, Color = Color3.fromRGB(255, 70, 200) },
		TracerColor = Color3.fromRGB(255, 90, 220),
	},

	ChargeBlaster = {
		DisplayName = "Capacitor",
		Category = "Charge Blaster",
		Slot = "Primary",
		Description = "Hold fire to charge. More charge = more damage. Release to shoot.",
		Damage = 70, -- at full charge before multiplier
		HeadshotMultiplier = 1.5,
		FireRate = 1.6,
		FireMode = "Charge",
		MagazineSize = 8,
		ReserveAmmo = 40,
		ReloadTime = 2.0,
		Range = 450,
		Falloff = { Start = 450, End = 450, MinMultiplier = 1 },
		Spread = { Hip = 1.2, Ads = 0.1, Move = 1.5, Air = 2.5, PerShot = 0, Max = 4, Recovery = 8 },
		Recoil = { Vertical = 2.5, Horizontal = 0.4, Recovery = 8 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		-- Damage = Damage * lerp(Min, Max, charge). 70 * 1.3 * 1.5 headshot = 136 < 150.
		Charge = { Time = 1.0, MinMultiplier = 0.35, MaxMultiplier = 1.3 },
		MovementPenalty = 0.92,
		EquipTime = 0.4,
		AdsFov = 48,
		Sounds = { Fire = "ChargeFire", Reload = "Reload", Equip = "Equip", Charge = "Charge" },
		CosmeticCategory = "Precision",
		UnlockLevel = 10,
		Viewmodel = { BodySize = Vector3.new(0.45, 0.5, 2.2), BarrelLength = 1.0, Color = Color3.fromRGB(80, 140, 255) },
		TracerColor = Color3.fromRGB(110, 170, 255),
	},

	ArcBlaster = {
		DisplayName = "Tesla Coil",
		Category = "Arc Blaster",
		Slot = "Primary",
		Description = "Short-range arcs that jump to a nearby enemy.",
		Damage = 17,
		HeadshotMultiplier = 1.2,
		FireRate = 6.5,
		FireMode = "Auto",
		MagazineSize = 24,
		ReserveAmmo = 120,
		ReloadTime = 1.9,
		Range = 55,
		Falloff = { Start = 30, End = 55, MinMultiplier = 0.7 },
		Spread = { Hip = 1.0, Ads = 0.6, Move = 0.4, Air = 0.8, PerShot = 0.1, Max = 2.5, Recovery = 10 },
		Recoil = { Vertical = 0.6, Horizontal = 0.6, Recovery = 10 },
		ProjectileType = "Chain",
		Pellets = 1,
		Chain = { Radius = 14, MaxJumps = 1, DamageMultiplier = 0.55 },
		MovementPenalty = 0.97,
		EquipTime = 0.3,
		AdsFov = 72,
		Sounds = { Fire = "ArcFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Heavy",
		UnlockLevel = 12,
		Viewmodel = { BodySize = Vector3.new(0.5, 0.55, 1.5), BarrelLength = 0.5, Color = Color3.fromRGB(120, 255, 255) },
		TracerColor = Color3.fromRGB(150, 255, 255),
	},

	BeamBlaster = {
		DisplayName = "Lumen Beam",
		Category = "Beam Blaster",
		Slot = "Primary",
		Description = "Continuous light beam. Steady tracking beats flicks.",
		Damage = 8, -- per tick
		HeadshotMultiplier = 1,
		FireRate = 15, -- ticks per second
		FireMode = "Beam",
		MagazineSize = 90,
		ReserveAmmo = 270,
		ReloadTime = 2.1,
		Range = 100,
		Falloff = { Start = 60, End = 100, MinMultiplier = 0.75 },
		Spread = { Hip = 0.3, Ads = 0.1, Move = 0.2, Air = 0.4, PerShot = 0, Max = 0.8, Recovery = 10 },
		Recoil = { Vertical = 0.05, Horizontal = 0.08, Recovery = 12 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 0.93,
		EquipTime = 0.35,
		AdsFov = 70,
		Sounds = { Fire = "BeamFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Heavy",
		UnlockLevel = 15,
		Viewmodel = { BodySize = Vector3.new(0.5, 0.5, 1.7), BarrelLength = 0.8, Color = Color3.fromRGB(255, 255, 120) },
		TracerColor = Color3.fromRGB(255, 255, 150),
	},

	EnergySidearm = {
		DisplayName = "Spark",
		Category = "Energy Sidearm",
		Slot = "Secondary",
		Description = "Snappy semi-auto sidearm. Fast to swap to.",
		Damage = 22,
		HeadshotMultiplier = 1.6,
		FireRate = 6,
		FireMode = "Semi",
		MagazineSize = 12,
		ReserveAmmo = 72,
		ReloadTime = 1.2,
		Range = 220,
		Falloff = { Start = 50, End = 150, MinMultiplier = 0.7 },
		Spread = { Hip = 1.1, Ads = 0.4, Move = 0.6, Air = 1.5, PerShot = 0.4, Max = 3.5, Recovery = 12 },
		Recoil = { Vertical = 1.4, Horizontal = 0.4, Recovery = 12 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 1,
		EquipTime = 0.18,
		AdsFov = 68,
		Sounds = { Fire = "SidearmFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Sidearm",
		UnlockLevel = 1,
		Viewmodel = { BodySize = Vector3.new(0.3, 0.5, 0.9), BarrelLength = 0.3, Color = Color3.fromRGB(255, 255, 255) },
		TracerColor = Color3.fromRGB(230, 240, 255),
	},

	FlickSidearm = {
		DisplayName = "Flicker",
		Category = "Energy Sidearm",
		Slot = "Secondary",
		Description = "Compact full-auto sidearm for close-range clean-up.",
		Damage = 13,
		HeadshotMultiplier = 1.4,
		FireRate = 11,
		FireMode = "Auto",
		MagazineSize = 20,
		ReserveAmmo = 100,
		ReloadTime = 1.3,
		Range = 140,
		Falloff = { Start = 30, End = 90, MinMultiplier = 0.6 },
		Spread = { Hip = 2.0, Ads = 1.0, Move = 0.4, Air = 1.0, PerShot = 0.25, Max = 5, Recovery = 12 },
		Recoil = { Vertical = 0.6, Horizontal = 0.5, Recovery = 12 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 1,
		EquipTime = 0.18,
		AdsFov = 72,
		Sounds = { Fire = "RapidFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Sidearm",
		UnlockLevel = 4,
		Viewmodel = { BodySize = Vector3.new(0.3, 0.55, 1.0), BarrelLength = 0.25, Color = Color3.fromRGB(120, 255, 200) },
		TracerColor = Color3.fromRGB(140, 255, 210),
	},

	CometSidearm = {
		DisplayName = "Comet",
		Category = "Energy Sidearm",
		Slot = "Secondary",
		Description = "Heavy hand-blaster. Two good shots finish a fight.",
		Damage = 42,
		HeadshotMultiplier = 1.5,
		FireRate = 2.2,
		FireMode = "Semi",
		MagazineSize = 6,
		ReserveAmmo = 36,
		ReloadTime = 1.6,
		Range = 260,
		Falloff = { Start = 60, End = 180, MinMultiplier = 0.7 },
		Spread = { Hip = 1.5, Ads = 0.25, Move = 1.0, Air = 2.0, PerShot = 0, Max = 3.5, Recovery = 8 },
		Recoil = { Vertical = 3.5, Horizontal = 0.7, Recovery = 8 },
		ProjectileType = "Hitscan",
		Pellets = 1,
		MovementPenalty = 1,
		EquipTime = 0.22,
		AdsFov = 64,
		Sounds = { Fire = "PrecisionFire", Reload = "Reload", Equip = "Equip" },
		CosmeticCategory = "Sidearm",
		UnlockLevel = 7,
		Viewmodel = { BodySize = Vector3.new(0.35, 0.6, 1.1), BarrelLength = 0.35, Color = Color3.fromRGB(255, 100, 100) },
		TracerColor = Color3.fromRGB(255, 130, 130),
	},
}

-- Display order for menus.
local Order = {
	"PulseRifle",
	"RapidBlaster",
	"ScatterBlaster",
	"BurstBlaster",
	"PrecisionBlaster",
	"PlasmaLauncher",
	"ChargeBlaster",
	"ArcBlaster",
	"BeamBlaster",
	"EnergySidearm",
	"FlickSidearm",
	"CometSidearm",
}

for id, weapon in Weapons do
	weapon.Id = id
	weapon.Animations = animations()
end

local WeaponConfig = {
	Weapons = Weapons,
	Order = Order,
	DefaultPrimary = "PulseRifle",
	DefaultSecondary = "EnergySidearm",
	-- Extra degrees allowed by server spread validation (network/precision slack).
	SpreadTolerance = 2.5,
}

function WeaponConfig.Get(id: string)
	return Weapons[id]
end

-- Time between individual shots (handles burst weapons).
function WeaponConfig.GetShotInterval(weapon): number
	if weapon.FireMode == "Burst" then
		return weapon.BurstInterval
	end
	return 1 / weapon.FireRate
end

-- Highest sustained shots-per-second a legit client can produce.
function WeaponConfig.GetMaxShotsPerSecond(weapon): number
	if weapon.FireMode == "Burst" then
		return weapon.FireRate * weapon.BurstCount
	end
	return weapon.FireRate
end

-- Largest spread (degrees) a legit client could apply; used by the server.
function WeaponConfig.GetMaxSpreadDegrees(weapon): number
	local spread = weapon.Spread
	return math.max(spread.Hip, spread.Max) + spread.Move + spread.Air + WeaponConfig.SpreadTolerance
end

function WeaponConfig.GetChargeMultiplier(weapon, charge: number): number
	local chargeData = weapon.Charge
	if not chargeData then
		return 1
	end
	local alpha = math.clamp(charge, 0, 1)
	return chargeData.MinMultiplier + (chargeData.MaxMultiplier - chargeData.MinMultiplier) * alpha
end

return TableUtil.DeepFreeze(WeaponConfig)
