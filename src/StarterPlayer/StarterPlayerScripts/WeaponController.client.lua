--[[
	WeaponController
	Client-side weapon input, prediction, and cosmetic feedback (brief
	sections 8-13). Ammo/cooldowns are predicted here for a snappy feel but
	WeaponServer is the only thing that actually applies damage — see the
	server script for the authoritative checks.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local SkinData = require(ReplicatedStorage.Shared.SkinData)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireWeapon = Remotes:WaitForChild("FireWeapon")
local ReloadWeapon = Remotes:WaitForChild("ReloadWeapon")
local SwitchWeapon = Remotes:WaitForChild("SwitchWeapon")
local WeaponFired = Remotes:WaitForChild("WeaponFired")
local HitConfirmed = Remotes:WaitForChild("HitConfirmed")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")

local loadout = { Primary = WeaponData.Loadout.Primary, Secondary = WeaponData.Loadout.Secondary, Melee = WeaponData.Loadout.Melee, WeaponSkins = {} }
ClientState.Weapon.EquippedSlot = "Primary"
ClientState.Weapon.EquippedWeaponId = loadout.Primary

local lastAutoFire = 0

local function currentWeapon()
	local id = ClientState.Weapon.EquippedWeaponId
	return id and WeaponData.Get(id)
end

local function ensureAmmo(weaponId)
	local weapon = WeaponData.Get(weaponId)
	if weapon and ClientState.Weapon.Ammo[weaponId] == nil then
		ClientState.Weapon.Ammo[weaponId] = weapon.Magazine
	end
end

InventoryUpdated.OnClientEvent:Connect(function(snapshot)
	if snapshot.Loadout then
		loadout = snapshot.Loadout
		local weaponId = loadout[ClientState.Weapon.EquippedSlot]
		if weaponId then
			ClientState.Weapon.EquippedWeaponId = weaponId
			ensureAmmo(weaponId)
		end
	end
end)

local function switchTo(slot)
	local weaponId = loadout[slot]
	if not weaponId then
		return
	end
	ClientState.Weapon.EquippedSlot = slot
	ClientState.Weapon.EquippedWeaponId = weaponId
	ClientState.Weapon.ADS = false
	ensureAmmo(weaponId)
	SwitchWeapon:FireServer(slot)
end

local function skinFor(weaponId)
	local skinId = loadout.WeaponSkins and loadout.WeaponSkins[weaponId]
	return SkinData.Collections[skinId] or SkinData.Collections[SkinData.DefaultSkin]
end

--============================================================
-- Firing
--============================================================

local function doReload()
	local weapon = currentWeapon()
	if not weapon or weapon.Slot == "Melee" then
		return
	end
	ensureAmmo(weapon.Id)
	if ClientState.Weapon.Reloading[weapon.Id] then
		return
	end
	if ClientState.Weapon.Ammo[weapon.Id] >= weapon.Magazine then
		return
	end
	ClientState.Weapon.Reloading[weapon.Id] = true
	ReloadWeapon:FireServer()
	task.delay(weapon.ReloadTime, function()
		ClientState.Weapon.Ammo[weapon.Id] = weapon.Magazine
		ClientState.Weapon.Reloading[weapon.Id] = false
	end)
end

local function fireOnce()
	local weapon = currentWeapon()
	if not weapon then
		return
	end
	if weapon.Slot ~= "Melee" then
		ensureAmmo(weapon.Id)
		if ClientState.Weapon.Reloading[weapon.Id] then
			return
		end
		if ClientState.Weapon.Ammo[weapon.Id] <= 0 then
			doReload()
			return
		end
		ClientState.Weapon.Ammo[weapon.Id] -= 1
	end

	local spread = ClientState.Weapon.ADS and (weapon.ADSSpread or 0) or (weapon.Spread or 0)
	local baseDirection = camera.CFrame.LookVector
	local spreadRad = math.rad(spread)
	local jitter = CFrame.Angles((math.random() - 0.5) * spreadRad, (math.random() - 0.5) * spreadRad, 0)
	local direction = (CFrame.new(Vector3.zero, baseDirection) * jitter).LookVector

	FireWeapon:FireServer({ Origin = camera.CFrame.Position, Direction = direction })

	if weapon.Recoil then
		ClientState.AddRecoil(weapon.Recoil.Vertical, (math.random() - 0.5) * weapon.Recoil.Horizontal * 2)
	end
	ClientState.Shake(weapon.Slot == "Melee" and 0 or 0.6, 0.08)
end

local function burstFire(weapon)
	for i = 1, weapon.BurstCount do
		task.delay((i - 1) * (1 / weapon.BurstRate), fireOnce)
	end
end

local function fireDown()
	ClientState.Weapon.FiringHeld = true
	local weapon = currentWeapon()
	if weapon and weapon.FireMode == "Burst" then
		burstFire(weapon)
	elseif weapon and (weapon.FireMode == "Semi" or weapon.FireMode == "Melee") then
		fireOnce()
	end
end

local function fireUp()
	ClientState.Weapon.FiringHeld = false
end

local function setADS(active)
	local weapon = currentWeapon()
	ClientState.Weapon.ADS = active and weapon and weapon.Slot ~= "Melee"
end

ClientState.Actions.FireDown = fireDown
ClientState.Actions.FireUp = fireUp
ClientState.Actions.Reload = doReload
ClientState.Actions.SwitchWeapon = switchTo
ClientState.Actions.SetADS = setADS

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		fireDown()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setADS(true)
	elseif input.KeyCode == Enum.KeyCode.R then
		doReload()
	elseif input.KeyCode == Enum.KeyCode.One then
		switchTo("Primary")
	elseif input.KeyCode == Enum.KeyCode.Two then
		switchTo("Secondary")
	elseif input.KeyCode == Enum.KeyCode.Three then
		switchTo("Melee")
	end
end)

UserInputService.InputEnded:Connect(function(input, _processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		fireUp()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setADS(false)
	end
end)

RunService.Heartbeat:Connect(function()
	if not ClientState.Weapon.FiringHeld then
		return
	end
	local weapon = currentWeapon()
	if not weapon or (weapon.FireMode ~= "Auto") then
		return
	end
	local minInterval = 1 / weapon.FireRate
	if os.clock() - lastAutoFire >= minInterval then
		lastAutoFire = os.clock()
		fireOnce()
	end
end)

--============================================================
-- Cosmetic replication: tracers, muzzle flash, sound, hitmarkers
--============================================================

local function spawnTracer(origin, direction, hitPosition, color)
	local distance = (hitPosition - origin).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = color
	tracer.Size = Vector3.new(0.08, 0.08, math.max(distance, 0.1))
	tracer.CFrame = CFrame.new(origin, hitPosition) * CFrame.new(0, 0, -distance / 2)
	tracer.Transparency = 0.2
	tracer.Parent = Workspace

	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.6, 0.6, 0.6)
	flash.Color = color
	flash.CFrame = CFrame.new(origin)
	flash.Parent = Workspace

	Debris:AddItem(tracer, 0.12)
	Debris:AddItem(flash, 0.08)
end

WeaponFired.OnClientEvent:Connect(function(shooter, weaponId, origin, direction, hitPosition)
	local weapon = WeaponData.Get(weaponId)
	if not weapon then
		return
	end
	local color = (shooter == player and skinFor(weaponId).MuzzleColor) or weapon.Color
	spawnTracer(origin, direction, hitPosition, color)

	local sound = Instance.new("Sound")
	sound.SoundGroup = SoundService:FindFirstChild("Weapons")
	sound.Name = weapon.Id .. "_Fire"
	sound.Volume = 0.5
	sound.PlaybackSpeed = 0.95 + math.random() * 0.1
	sound.Parent = Workspace
	sound:Play()
	Debris:AddItem(sound, 2)
end)

HitConfirmed.OnClientEvent:Connect(function(_isHeadshot)
	local sound = Instance.new("Sound")
	sound.SoundGroup = SoundService:FindFirstChild("UI")
	sound.Name = "HitMarker"
	sound.Volume = 0.6
	sound.Parent = Workspace
	sound:Play()
	Debris:AddItem(sound, 1)
end)
