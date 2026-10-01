--[[
	WeaponController
	Client side of the weapon framework. Predicts everything for instant
	feedback (fire timing, ammo, spread, recoil, tracers, muzzle flash,
	predicted hit markers) and sends *intent* to the server:

	  RequestFire { Weapon, Shot, Origin, Direction, Pellets?, Hits? }

	`Hits` are claims; the server re-validates them and computes damage.
	Server WeaponState snapshots correct any mismatch (ammo, slots).

	Fire modes: Auto, Semi, Burst, Charge (hold to charge, release to fire)
	and Beam (continuous ticks). Switching is instant-feeling and cancels
	reloads/charges.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local MathUtil = require(Shared.Modules.MathUtil)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local ClientState = require(script.Parent.ClientState)
local InputController = require(script.Parent.InputController)
local SoundController = require(script.Parent.SoundController)
local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)
local EffectsController = require(script.Parent.EffectsController)
local Viewmodel = require(script.Parent.Viewmodel)

local WeaponController = {}

WeaponController.ShotFired = Signal.new() -- (weapon)
WeaponController.PredictedHit = Signal.new() -- (headshot)
WeaponController.StateChanged = Signal.new()

local player = Players.LocalPlayer

local SLOT_ORDER = { "Primary", "Secondary" }
local AUTO_RELOAD_DELAY = 0.25
local SERVER_EQUIP_GRACE = 0.6
local ADS_RECOIL_MULTIPLIER = 0.6

local state = {
	Slots = {} :: { [string]: string },
	Equipped = nil :: string?,
	Ammo = {} :: { [string]: { Mag: number, Reserve: number } },
	InfiniteReserve = false,
	Reloading = false,
	ReloadEndsAt = 0,
	ReloadToken = 0,
	EquipReadyAt = 0,
	LastLocalEquip = 0,
	NextShotAt = 0,
	BurstRemaining = 0,
	Charging = false,
	ChargeStart = 0,
	AimToggled = false,
	Bloom = 0,
	ShotCounter = 0,
}

local viewmodel = nil

function WeaponController:GetWeapon()
	local id = state.Equipped and state.Slots[state.Equipped]
	return id and WeaponConfig.Get(id)
end

function WeaponController:IsAiming(): boolean
	local weapon = WeaponController:GetWeapon()
	if not weapon or not ClientState.IsInMatch() or MovementController:IsSliding() then
		return false
	end
	if ClientState.GetSetting("ToggleAim") then
		return state.AimToggled
	end
	return InputController:IsDown("Aim")
end

function WeaponController:GetChargeLevel(): number
	local weapon = WeaponController:GetWeapon()
	if not state.Charging or not weapon or not weapon.Charge then
		return 0
	end
	return math.clamp((os.clock() - state.ChargeStart) / weapon.Charge.Time, 0, 1)
end

-- Current total spread in degrees (used for shots and the crosshair).
function WeaponController:GetSpreadDegrees(): number
	local weapon = WeaponController:GetWeapon()
	if not weapon then
		return 0
	end
	local spread = weapon.Spread
	local base = if WeaponController:IsAiming() then spread.Ads else spread.Hip
	local speedFactor = math.clamp(MovementController:GetHorizontalSpeed() / PlayerConfig.Movement.SprintSpeed, 0, 1)
	local total = base + spread.Move * speedFactor + state.Bloom
	if not MovementController:IsGrounded() then
		total += spread.Air
	end
	return total
end

function WeaponController:GetHudInfo()
	local weapon = WeaponController:GetWeapon()
	if not weapon then
		return nil
	end
	local ammo = state.Ammo[weapon.Id]
	local reloadProgress = 0
	if state.Reloading then
		reloadProgress = 1 - math.clamp((state.ReloadEndsAt - os.clock()) / weapon.ReloadTime, 0, 1)
	end
	return {
		Weapon = weapon,
		Mag = ammo and ammo.Mag or 0,
		Reserve = ammo and ammo.Reserve or 0,
		Infinite = state.InfiniteReserve,
		Reloading = state.Reloading,
		ReloadProgress = reloadProgress,
		Slots = state.Slots,
		Equipped = state.Equipped,
		Charge = WeaponController:GetChargeLevel(),
	}
end

local function myTeam(): string?
	return player:GetAttribute("Team")
end

local function isEnemyModel(model: Model): boolean
	local team = myTeam()
	if CollectionService:HasTag(model, RaycastUtil.Tags.Decoy) then
		if model:GetAttribute("OwnerId") == player.UserId then
			return false
		end
		return team == nil or model:GetAttribute("Team") ~= team
	end
	local id = model:GetAttribute("CombatantId")
	if id == nil or id == player.UserId then
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end
	return team == nil or model:GetAttribute("Team") ~= team
end

local function canUseWeapons(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Frozen") then
		return false
	end
	local matchState = ClientState.Get("MatchState")
	return ClientState.IsInMatch() and matchState and matchState.Phase == "Active"
end

local function rebuildViewmodel()
	if viewmodel then
		viewmodel:Destroy()
		viewmodel = nil
	end
	local weapon = WeaponController:GetWeapon()
	if not weapon or not ClientState.IsInMatch() then
		return
	end
	local profile = ClientState.Get("Profile")
	local skin = profile and CosmeticConfig.Get(profile.Equipped.WeaponSkin)
	viewmodel = Viewmodel.new(weapon, skin, nil)
end

local function cancelReload()
	if state.Reloading then
		state.Reloading = false
		state.ReloadToken += 1
		if viewmodel then
			viewmodel:CancelReload()
		end
	end
end

function WeaponController:Reload()
	local weapon = WeaponController:GetWeapon()
	if not weapon or state.Reloading or not canUseWeapons() then
		return
	end
	local ammo = state.Ammo[weapon.Id]
	if not ammo or ammo.Mag >= weapon.MagazineSize then
		return
	end
	if ammo.Reserve <= 0 and not state.InfiniteReserve then
		return
	end
	state.Charging = false
	state.BurstRemaining = 0
	state.Reloading = true
	state.ReloadEndsAt = os.clock() + weapon.ReloadTime
	state.ReloadToken += 1
	local token = state.ReloadToken
	Net.Event("Combat", "RequestReload"):FireServer()
	SoundController:Play(weapon.Sounds.Reload)
	if viewmodel then
		viewmodel:PlayReload(weapon.ReloadTime)
	end
	task.delay(weapon.ReloadTime, function()
		if state.ReloadToken ~= token or not state.Reloading then
			return
		end
		state.Reloading = false
		-- Predict the refill; the server's WeaponState confirms it.
		local needed = weapon.MagazineSize - ammo.Mag
		local taken = if state.InfiniteReserve then needed else math.min(needed, ammo.Reserve)
		ammo.Mag += taken
		if not state.InfiniteReserve then
			ammo.Reserve -= taken
		end
		WeaponController.StateChanged:Fire()
	end)
	WeaponController.StateChanged:Fire()
end

function WeaponController:Equip(slot: string)
	if not state.Slots[slot] or state.Equipped == slot then
		return
	end
	cancelReload()
	state.Charging = false
	state.BurstRemaining = 0
	state.Equipped = slot
	state.LastLocalEquip = os.clock()
	local weapon = WeaponController:GetWeapon()
	state.EquipReadyAt = os.clock() + weapon.EquipTime
	state.Bloom = 0
	rebuildViewmodel()
	SoundController:Play(weapon.Sounds.Equip)
	Net.Event("Inventory", "EquipSlot"):FireServer(slot)
	WeaponController.StateChanged:Fire()
end

local function cycleWeapon(step: number)
	local available = {}
	for _, slot in SLOT_ORDER do
		if state.Slots[slot] then
			table.insert(available, slot)
		end
	end
	if #available < 2 then
		return
	end
	local index = table.find(available, state.Equipped) or 1
	local nextIndex = ((index - 1 + step) % #available) + 1
	WeaponController:Equip(available[nextIndex])
end

-- Performs one shot (or one pellet volley). Returns true if fired.
local function fireOnce(chargeLevel: number?): boolean
	local weapon = WeaponController:GetWeapon()
	if not weapon or not canUseWeapons() then
		return false
	end
	local now = os.clock()
	if now < state.EquipReadyAt then
		return false
	end
	local ammo = state.Ammo[weapon.Id]
	if not ammo then
		return false
	end
	if ammo.Mag <= 0 then
		SoundController:Play("DryFire")
		WeaponController:Reload()
		return false
	end
	if state.Reloading then
		cancelReload() -- rounds left in the mag: firing interrupts the reload
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	ammo.Mag -= 1
	state.ShotCounter += 1
	local shotId = state.ShotCounter
	local origin = camera.CFrame.Position
	local aim = camera.CFrame.LookVector
	local spreadRadians = math.rad(WeaponController:GetSpreadDegrees())
	local rng = Random.new()
	local muzzle = if viewmodel then viewmodel:GetMuzzlePosition() else origin
	local color = weapon.TracerColor

	local payload: { [string]: any } = { Weapon = weapon.Id, Shot = shotId, Origin = origin }

	if weapon.ProjectileType == "Projectile" then
		local direction = MathUtil.RandomInCone(aim, spreadRadians, rng)
		payload.Direction = direction
		EffectsController:SpawnProjectile(tostring(player.UserId) .. "_" .. tostring(shotId), origin, muzzle, direction * weapon.Projectile.Speed, weapon, true)
	else
		local ignore: { Instance } = { camera }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		local params = RaycastUtil.CombatParams(ignore, myTeam(), player.UserId)
		local directions = {}
		local hits = {}
		for pellet = 1, weapon.Pellets do
			local direction = MathUtil.RandomInCone(aim, spreadRadians, rng)
			directions[pellet] = direction
			local result = workspace:Raycast(origin, direction * weapon.Range, params)
			local endPoint = if result then result.Position else origin + direction * weapon.Range
			if result then
				local model = RaycastUtil.FindTargetModel(result.Instance)
				if model and isEnemyModel(model) then
					table.insert(hits, { Target = model, Part = result.Instance, Position = result.Position, Pellet = pellet })
					WeaponController.PredictedHit:Fire(result.Instance.Name == "Head")
					EffectsController:HitSpark(result.Position, color)
				else
					EffectsController:Impact(result.Position, result.Normal, color)
				end
			end
			if weapon.ProjectileType == "Chain" then
				EffectsController:Lightning(muzzle, endPoint, color)
			else
				EffectsController:Tracer(muzzle, endPoint, color, weapon.FireMode == "Beam")
			end
		end
		if weapon.Pellets > 1 then
			payload.Direction = aim
			payload.Pellets = directions
		else
			payload.Direction = directions[1]
		end
		if #hits > 0 then
			payload.Hits = hits
		end
	end

	Net.Event("Combat", "RequestFire"):FireServer(payload)

	-- Local feedback.
	local recoilScale = if WeaponController:IsAiming() then ADS_RECOIL_MULTIPLIER else 1
	if chargeLevel then
		recoilScale *= 0.5 + chargeLevel
	end
	CameraController:Recoil(weapon.Recoil.Vertical * recoilScale, weapon.Recoil.Horizontal * recoilScale)
	local maxBloom = math.max(0, weapon.Spread.Max - weapon.Spread.Hip)
	state.Bloom = math.min(maxBloom, state.Bloom + weapon.Spread.PerShot)
	if viewmodel then
		viewmodel:Kick(math.clamp(weapon.Recoil.Vertical / 2, 0.3, 2))
	end
	EffectsController:MuzzleFlash(muzzle, color)
	SoundController:Play(weapon.Sounds.Fire, 0.06)
	MovementController:NotifyFired()
	WeaponController.ShotFired:Fire(weapon)
	WeaponController.StateChanged:Fire()

	if ammo.Mag <= 0 then
		task.delay(AUTO_RELOAD_DELAY, function()
			if WeaponController:GetWeapon() == weapon then
				WeaponController:Reload()
			end
		end)
	end
	return true
end

local function onFirePressed()
	local weapon = WeaponController:GetWeapon()
	if not weapon or not canUseWeapons() then
		return
	end
	local now = os.clock()
	if weapon.FireMode == "Semi" then
		if now >= state.NextShotAt and fireOnce(nil) then
			state.NextShotAt = now + 1 / weapon.FireRate
		end
	elseif weapon.FireMode == "Burst" then
		if now >= state.NextShotAt and state.BurstRemaining == 0 then
			state.BurstRemaining = weapon.BurstCount
			state.BurstStart = now
		end
	elseif weapon.FireMode == "Charge" then
		local ammo = state.Ammo[weapon.Id]
		if now >= state.NextShotAt and now >= state.EquipReadyAt and ammo and ammo.Mag > 0 and not state.Reloading then
			state.Charging = true
			state.ChargeStart = now
			Net.Event("Combat", "ChargeStart"):FireServer()
			SoundController:Play(weapon.Sounds.Charge or "Charge")
		elseif ammo and ammo.Mag <= 0 then
			WeaponController:Reload()
		end
	end
end

local function onFireReleased()
	local weapon = WeaponController:GetWeapon()
	if weapon and weapon.FireMode == "Charge" and state.Charging then
		local charge = WeaponController:GetChargeLevel()
		state.Charging = false
		if fireOnce(charge) then
			state.NextShotAt = os.clock() + 1 / weapon.FireRate
		end
	end
end

local function update(deltaTime: number)
	local weapon = WeaponController:GetWeapon()
	local now = os.clock()
	if weapon then
		-- Held-trigger fire modes.
		if (weapon.FireMode == "Auto" or weapon.FireMode == "Beam") and InputController:IsDown("Fire") then
			if now >= state.NextShotAt then
				local interval = 1 / weapon.FireRate
				-- Continuous fire keeps an exact cadence; after a pause, restart from now.
				local base = if now - state.NextShotAt > interval then now else state.NextShotAt
				if fireOnce(nil) then
					state.NextShotAt = base + interval
				end
			end
		elseif weapon.FireMode == "Burst" and state.BurstRemaining > 0 and now >= state.NextShotAt then
			if fireOnce(nil) then
				state.BurstRemaining -= 1
				if state.BurstRemaining > 0 then
					state.NextShotAt = now + weapon.BurstInterval
				else
					state.NextShotAt = (state.BurstStart or now) + 1 / weapon.FireRate
				end
			else
				state.BurstRemaining = 0
			end
		end
		state.Bloom = math.max(0, state.Bloom - weapon.Spread.Recovery * deltaTime)
	end

	local aiming = WeaponController:IsAiming()
	CameraController:SetAimFov(if aiming and weapon then weapon.AdsFov else nil)

	if viewmodel then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local alive = humanoid ~= nil and humanoid.Health > 0
		viewmodel:SetVisible(alive and CameraController:IsFirstPerson())
		viewmodel:SetCharge(WeaponController:GetChargeLevel())
		local speed, grounded = MovementController:GetBobInfo()
		viewmodel:Update(deltaTime, aiming, speed, grounded)
	end
end

local function applyServerState(payload)
	if payload == nil then
		state.Slots = {}
		state.Equipped = nil
		state.Ammo = {}
		cancelReload()
		state.Charging = false
		rebuildViewmodel()
		WeaponController.StateChanged:Fire()
		return
	end
	local slotsChanged = false
	for _, slot in SLOT_ORDER do
		if state.Slots[slot] ~= payload.Slots[slot] then
			slotsChanged = true
		end
	end
	state.Slots = payload.Slots
	state.Ammo = payload.Ammo
	state.InfiniteReserve = payload.InfiniteReserve == true
	if not payload.Reloading and state.Reloading and os.clock() >= state.ReloadEndsAt - 0.05 then
		state.Reloading = false
	end
	local keepLocalEquip = not slotsChanged and os.clock() - state.LastLocalEquip < SERVER_EQUIP_GRACE
	if not keepLocalEquip and state.Equipped ~= payload.Equipped then
		state.Equipped = payload.Equipped
		slotsChanged = true
	end
	if slotsChanged then
		cancelReload()
		state.Charging = false
		state.BurstRemaining = 0
		state.Bloom = 0
		local weapon = WeaponController:GetWeapon()
		state.EquipReadyAt = os.clock() + (if weapon then weapon.EquipTime else 0)
		rebuildViewmodel()
	end
	WeaponController.StateChanged:Fire()
end

function WeaponController:Init()
	MovementController:SetWeaponInfo({
		SpeedMultiplier = function()
			local weapon = WeaponController:GetWeapon()
			return if weapon and ClientState.IsInMatch() then weapon.MovementPenalty else 1
		end,
		IsAiming = function()
			return WeaponController:IsAiming()
		end,
	})
end

function WeaponController:Start()
	Net.Event("Inventory", "WeaponState").OnClientEvent:Connect(applyServerState)

	InputController.ActionBegan:Connect(function(action)
		if action == "Fire" then
			onFirePressed()
		elseif action == "Reload" then
			WeaponController:Reload()
		elseif action == "Weapon1" then
			WeaponController:Equip("Primary")
		elseif action == "Weapon2" then
			WeaponController:Equip("Secondary")
		elseif action == "NextWeapon" then
			cycleWeapon(1)
		elseif action == "PrevWeapon" then
			cycleWeapon(-1)
		elseif action == "Aim" and ClientState.GetSetting("ToggleAim") then
			state.AimToggled = not state.AimToggled
		end
	end)
	InputController.ActionEnded:Connect(function(action)
		if action == "Fire" then
			onFireReleased()
		end
	end)

	player.CharacterAdded:Connect(function()
		state.AimToggled = false
		state.Charging = false
		state.BurstRemaining = 0
		cancelReload()
	end)
	ClientState.Observe("Location", function()
		rebuildViewmodel()
	end)

	RunService:BindToRenderStep("VectorRushWeapon", Enum.RenderPriority.Camera.Value + 2, update)
end

return WeaponController
