--[[
	TestRunner
	Automated server-side checks. Runs automatically when a Studio play
	session starts (DevConfig.RunTestsOnStudioStart) and via the dev command
	"runtests". Tests use temporary bot combatants and dummy rigs so they never
	touch real players' data.

	Covered: config integrity, damage rules (no instant kills), data
	validation/migration/corruption repair, settings sanitizing, fire-rate
	limiting, ammo, reload cancel on weapon switch, ability cooldowns, remote
	rate limiting, progression curve.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local TableUtil = require(Shared.Modules.TableUtil)
local MathUtil = require(Shared.Modules.MathUtil)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local MapConfig = require(Shared.Config.MapConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local SettingsConfig = require(Shared.Config.SettingsConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local SoundConfig = require(Shared.Config.SoundConfig)
local WeaponModelBuilder = require(Shared.Modules.WeaponModelBuilder)

local TestRunner = {}

local VALID_FIRE_MODES = { Auto = true, Semi = true, Burst = true, Charge = true, Beam = true }
local VALID_PROJECTILE_TYPES = { Hitscan = true, Projectile = true, Chain = true }

local function assertTrue(condition: any, message: string)
	if not condition then
		error(message, 2)
	end
end

local function makeDummy(): Model
	local model = Instance.new("Model")
	model.Name = "TestDummy"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, -500, 0)
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.Size = Vector3.one
	head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = workspace
	return model
end

local function withTestBot(services, callback: (any) -> ())
	local bot = services.CombatantService:CreateForBot("TestBot")
	local dummy = makeDummy()
	local ok, err = pcall(function()
		services.CombatantService:AttachCharacter(bot, dummy)
		callback(bot)
	end)
	services.WeaponService:ClearLoadout(bot)
	services.AbilityService:ClearState(bot)
	services.CombatantService:Remove(bot)
	dummy:Destroy()
	if not ok then
		error(err, 0)
	end
end

local Tests = {}

Tests["Weapon configs are complete and valid"] = function()
	local count = 0
	for id, weapon in WeaponConfig.Weapons do
		count += 1
		assertTrue(weapon.Id == id, id .. " Id mismatch")
		assertTrue(weapon.Slot == "Primary" or weapon.Slot == "Secondary", id .. " bad slot")
		assertTrue(VALID_FIRE_MODES[weapon.FireMode], id .. " bad fire mode")
		assertTrue(VALID_PROJECTILE_TYPES[weapon.ProjectileType], id .. " bad projectile type")
		assertTrue(weapon.Damage > 0 and weapon.FireRate > 0 and weapon.MagazineSize > 0, id .. " bad numbers")
		assertTrue(weapon.Range > 0 and weapon.ReloadTime > 0 and weapon.EquipTime >= 0, id .. " bad timings")
		assertTrue(weapon.Spread and weapon.Recoil and weapon.Falloff, id .. " missing tables")
		assertTrue(weapon.Animations and weapon.Sounds and weapon.CosmeticCategory, id .. " missing refs")
		assertTrue(table.find(WeaponConfig.Order, id), id .. " missing from Order")
		if weapon.FireMode == "Burst" then
			assertTrue(weapon.BurstCount and weapon.BurstInterval, id .. " burst fields")
		end
		if weapon.ProjectileType == "Projectile" then
			assertTrue(weapon.Projectile and weapon.Projectile.Speed > 0, id .. " projectile fields")
		end
		if weapon.FireMode == "Charge" then
			assertTrue(weapon.Charge and weapon.Charge.Time > 0, id .. " charge fields")
		end
	end
	assertTrue(count >= 10, "Expected at least 10 weapons")
end

Tests["Every weapon has a model kit, tracer style and sound recipes"] = function()
	local kits = WeaponModelBuilder.GetKitNames()
	local styles = { Bolt = true, Rail = true, Pellet = true, Spray = true, Orb = true, Arc = true, Beam = true }
	for id, weapon in WeaponConfig.Weapons do
		assertTrue(table.find(kits, weapon.Viewmodel.Kit), id .. " unknown kit " .. tostring(weapon.Viewmodel.Kit))
		assertTrue(styles[weapon.TracerStyle], id .. " unknown tracer style")
		for slot, key in weapon.Sounds do
			assertTrue(SoundConfig.Sounds[key], id .. " missing sound recipe " .. slot .. "=" .. key)
		end
		local model, info = WeaponModelBuilder.Build(weapon, { Anchored = true })
		assertTrue(model.PrimaryPart and #info.Glow > 0, id .. " model has no core/glow parts")
		model:Destroy()
	end
end

Tests["No weapon can eliminate a full health+shield target in one shot"] = function()
	local total = PlayerConfig.Health.MaxHealth + PlayerConfig.Health.MaxShield
	for id, weapon in WeaponConfig.Weapons do
		local perPellet = weapon.Damage * weapon.HeadshotMultiplier * WeaponConfig.GetChargeMultiplier(weapon, 1)
		local maxShot = perPellet * weapon.Pellets
		if weapon.Projectile then
			maxShot = weapon.Damage + weapon.Projectile.SplashDamage
		end
		assertTrue(maxShot < total, string.format("%s max shot %.1f >= %d", id, maxShot, total))
	end
end

Tests["Ability, match, map and cosmetic configs are consistent"] = function()
	for id, ability in AbilityConfig.Abilities do
		assertTrue(ability.Slot == "Movement" or ability.Slot == "Tactical", id .. " bad slot")
		assertTrue(ability.Cooldown > 0, id .. " cooldown")
	end
	for _, weaponId in MatchConfig.Modes.GunGame.Ladder do
		assertTrue(WeaponConfig.Get(weaponId), "Gun game ladder weapon missing: " .. weaponId)
	end
	assertTrue(MatchConfig.Modes.GunGame.ScoreLimit == #MatchConfig.Modes.GunGame.Ladder, "Gun game score limit")
	for _, modeId in MatchConfig.ModeOrder do
		local rules = game:GetService("ServerScriptService").Services.MatchService.Modes:FindFirstChild(modeId)
		assertTrue(rules, "Missing rules module for " .. modeId)
	end
	for _, mapId in MapConfig.Order do
		assertTrue(ServerStorage.Maps:FindFirstChild(mapId), "Missing map module " .. mapId)
	end
	for category, defaultId in CosmeticConfig.Defaults do
		local item = CosmeticConfig.Get(defaultId)
		assertTrue(item and item.Category == category and item.Price == 0, "Bad default cosmetic " .. category)
	end
end

Tests["Data validation repairs corrupt and old profiles"] = function(services)
	local DataService = services.DataService
	local fresh = DataService.Validate(TableUtil.DeepCopy(DataService.DefaultData))
	assertTrue(fresh.Level == 1 and fresh.Version == DataService.DefaultData.Version, "Default data invalid")

	local old = { Version = 1, Coins = 75, XP = 10, Level = 1 }
	local migrated = DataService.Validate(old)
	assertTrue(migrated.Credits == 75, "Migration v1 Coins->Credits failed")
	assertTrue(migrated.Coins == nil, "Old key not removed")

	local corrupt = {
		Version = 2,
		XP = "lots",
		Credits = -50,
		Equipped = { Primary = "EnergySidearm", Secondary = "DoesNotExist", Movement = "Shield" },
		OwnedCosmetics = { FakeItem = true },
		Settings = { FieldOfView = 9999, Unknown = true },
	}
	local repaired = DataService.Validate(corrupt)
	assertTrue(repaired.XP == 0, "XP type not repaired")
	assertTrue(repaired.Credits == 0, "Negative credits not clamped")
	assertTrue(repaired.Equipped.Primary == WeaponConfig.DefaultPrimary, "Wrong-slot primary not reset")
	assertTrue(repaired.Equipped.Secondary == WeaponConfig.DefaultSecondary, "Unknown secondary not reset")
	assertTrue(repaired.Equipped.Movement == AbilityConfig.DefaultMovement, "Wrong-slot ability not reset")
	assertTrue(repaired.OwnedCosmetics.FakeItem == nil, "Unknown cosmetic kept")
	assertTrue(repaired.Settings.FieldOfView == 100, "Setting not clamped")
	assertTrue(repaired.Settings.Unknown == nil, "Unknown setting kept")
end

Tests["Settings sanitizer rejects invalid values"] = function()
	assertTrue(SettingsConfig.SanitizeValue("CrosshairStyle", "Skull") == nil, "Bad enum accepted")
	assertTrue(SettingsConfig.SanitizeValue("ToggleSprint", "yes") == nil, "Bad boolean accepted")
	assertTrue(SettingsConfig.SanitizeValue("MasterVolume", 0 / 0) == nil, "NaN accepted")
	assertTrue(SettingsConfig.SanitizeValue("CameraShake", 5) == 1, "Not clamped")
	assertTrue(SettingsConfig.SanitizeValue("NotASetting", 1) == nil, "Unknown key accepted")
end

Tests["Fire rate is limited server-side"] = function(services)
	withTestBot(services, function(bot)
		services.WeaponService:GiveLoadout(bot, { Primary = "PrecisionBlaster" }, false)
		local state = services.WeaponService:GetState(bot)
		state.EquipReadyAt = 0
		local accepted, rejected = 0, 0
		for _ = 1, 5 do
			local ok, reason = services.WeaponService:TryConsumeShot(bot, "PrecisionBlaster")
			if ok then
				accepted += 1
			elseif reason == "FireRate" then
				rejected += 1
			end
		end
		assertTrue(accepted <= 3, "Too many rapid shots accepted: " .. accepted)
		assertTrue(rejected >= 2, "Rapid shots were not rejected")
	end)
end

Tests["Ammo is enforced and wrong weapons rejected"] = function(services)
	withTestBot(services, function(bot)
		services.WeaponService:GiveLoadout(bot, { Primary = "PulseRifle", Secondary = "EnergySidearm" }, false)
		local state = services.WeaponService:GetState(bot)
		state.EquipReadyAt = 0
		local ok, reason = services.WeaponService:TryConsumeShot(bot, "EnergySidearm")
		assertTrue(not ok and reason == "NotEquipped", "Unequipped weapon fired")
		state.Ammo.PulseRifle.Mag = 0
		ok, reason = services.WeaponService:TryConsumeShot(bot, "PulseRifle")
		assertTrue(not ok and reason == "NoAmmo", "Fired with empty magazine")
	end)
end

Tests["Switching weapons cancels reload"] = function(services)
	withTestBot(services, function(bot)
		services.WeaponService:GiveLoadout(bot, { Primary = "PulseRifle", Secondary = "EnergySidearm" }, false)
		local state = services.WeaponService:GetState(bot)
		state.Ammo.PulseRifle.Mag = 3
		assertTrue(services.WeaponService:StartReload(bot), "Reload did not start")
		assertTrue(services.WeaponService:Equip(bot, "Secondary"), "Equip failed")
		assertTrue(not state.Reloading, "Reload not cancelled by switch")
		assertTrue(not services.WeaponService:Equip(bot, "Melee"), "Invalid slot accepted")
	end)
end

Tests["Abilities respect cooldowns"] = function(services)
	withTestBot(services, function(bot)
		services.AbilityService:ApplyLoadout(bot)
		assertTrue(services.AbilityService:TryUse(bot, "Movement", nil), "First dash rejected")
		assertTrue(not services.AbilityService:TryUse(bot, "Movement", nil), "Dash during cooldown accepted")
		assertTrue(not services.AbilityService:TryUse(bot, "Ultimate", nil), "Unknown slot accepted")
	end)
end

Tests["Remote rate limiter drops spam"] = function()
	local fakePlayer = newproxy() :: any
	local allowed = 0
	for _ = 1, 50 do
		if Net._allow(fakePlayer, "Test/Spam", 1, 5) then
			allowed += 1
		end
	end
	assertTrue(allowed == 5, "Rate limiter allowed " .. allowed)
end

Tests["Progression curve is monotonic"] = function()
	local previous = 0
	for level = 1, 50 do
		local needed = ProgressionConfig.XPForLevel(level)
		assertTrue(needed > previous, "XP curve not increasing at " .. level)
		previous = needed
	end
	local level = ProgressionConfig.LevelFromXP(0)
	assertTrue(level == 1, "Level from 0 XP")
	level = ProgressionConfig.LevelFromXP(ProgressionConfig.XPForLevel(1))
	assertTrue(level == 2, "Level up threshold")
end

Tests["Spread helper stays within cone"] = function()
	local rng = Random.new(1)
	local direction = Vector3.new(0.3, 0.1, -1).Unit
	for _ = 1, 200 do
		local sample = MathUtil.RandomInCone(direction, math.rad(5), rng)
		assertTrue(MathUtil.AngleBetween(sample, direction) <= math.rad(5) + 1e-3, "Sample outside cone")
	end
end

function TestRunner.Run(services): (number, number, string)
	local passed, failed = 0, 0
	local lines = {}
	local names = {}
	for name in Tests do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local ok, err = pcall(Tests[name], services)
		if ok then
			passed += 1
			table.insert(lines, "  PASS  " .. name)
		else
			failed += 1
			table.insert(lines, "  FAIL  " .. name .. " -> " .. tostring(err))
		end
	end
	return passed, failed, table.concat(lines, "\n")
end

return TestRunner
