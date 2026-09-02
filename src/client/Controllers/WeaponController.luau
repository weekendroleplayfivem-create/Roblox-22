--!nonstrict
--[[
	WeaponController.luau
	Firing, aiming, recoil, reloading and weapon switching.

	HIT REGISTRATION MODEL
	----------------------
	The client raycasts and reports; the server re-simulates the same shot against
	rewound positions and authors the damage (Services/CombatService). The client
	shows its hitmarker immediately from the SHARED DamageMath module, so the
	feedback is instant and - because both sides run identical maths on the same
	inputs - almost always identical to the authoritative result.

	This is the standard tradeoff for a responsive shooter. The alternative,
	server-side raycasting from server-side aim, costs a full round trip of
	feedback latency and feels dead. The trust window is bounded by the server's
	rate, distance and rewind checks.

	RECOIL MODEL
	------------
	Deterministic pattern + small random cone. The camera is moved by the recoil,
	so the pattern must be pulled down by the player, and it recovers on a spring
	when they stop firing. Learnable, not random.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local WeaponConfig = require(Root.Config.WeaponConfig)
local CombatConfig = require(Root.Config.CombatConfig)
local MovementConfig = require(Root.Config.MovementConfig)
local MovementState = require(Root.Shared.MovementState)
local DamageMath = require(Root.Shared.DamageMath)
local Tags = require(Root.Shared.Tags)
local Net = require(Root.Util.Net)
local Trove = require(Root.Util.Trove)
local Viewmodel = require(script.Parent.Parent.Viewmodel.Viewmodel)

local LocalPlayer = Players.LocalPlayer

local WeaponController = {}
WeaponController.__index = WeaponController

local SLOT_ORDER = { "Primary", "Secondary", "Melee" }

function WeaponController.new(context)
	local self = setmetatable({}, WeaponController)

	self.context = context
	self.input = context.Input
	self._trove = Trove.new()

	self.viewmodel = Viewmodel.new()
	self.loadout = table.clone(WeaponConfig.DefaultLoadout)
	self.ammo = {} :: { [string]: { mag: number, reserve: number } }

	self.currentSlot = "Primary"
	self.previousSlot = "Secondary"
	self.definition = nil

	self.firing = false
	self.aiming = false
	self.adsAlpha = 0
	self.reloading = false
	self.reloadEndsAt = 0
	self.equipEndsAt = 0
	self.inspecting = false
	self.enabled = true

	self.shotIndex = 0
	self.lastShotAt = 0
	self.lastRecoilAt = 0
	self.spread = 0
	self._fireQueued = false
	self._pendingShotId = 0

	return self
end

function WeaponController:Start()
	self:_resetAmmo()

	self._trove:Connect(self.input.ActionPressed, function(action)
		self:_onAction(action, true)
	end)
	self._trove:Connect(self.input.ActionReleased, function(action)
		self:_onAction(action, false)
	end)

	self._trove:Add(RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(self._update, self, math.min(dt, 1 / 15))
		if not ok then
			warn(`[Weapon] update error: {err}`)
		end
	end))

	-- The server is the authority on ammo; it corrects us if we drift.
	self._trove:Add(Net.onClient("WeaponState", function(payload)
		if payload.slot and self.ammo[payload.slot] then
			self.ammo[payload.slot].mag = payload.mag
			self.ammo[payload.slot].reserve = payload.reserve
			if payload.reloading == false and self.reloading then
				self:_finishReload(true)
			end
		end
	end))

	self._trove:Add(Net.onClient("HitConfirm", function(payload)
		self.context.Effects:Hitmarker(payload.headshot, payload.killed)
		self.context.HUD:PushDamageNumber(payload.damage, payload.headshot, payload.position)
	end))

	self._trove:Add(Net.onClient("SetLoadout", function(loadout)
		self:SetLoadout(loadout)
	end))

	self:Equip(self.currentSlot, true)
	return self
end

----------------------------------------------------------------------
-- Loadout / ammo
----------------------------------------------------------------------

function WeaponController:_resetAmmo()
	table.clear(self.ammo)
	for _, slot in SLOT_ORDER do
		local id = self.loadout[slot]
		local definition = id and WeaponConfig.get(id)
		if definition then
			self.ammo[slot] = { mag = definition.MagSize, reserve = definition.ReserveAmmo }
		end
	end
end

function WeaponController:SetLoadout(loadout)
	for slot, id in loadout do
		if WeaponConfig.get(id) then
			self.loadout[slot] = id
		end
	end
	self:_resetAmmo()
	self:Equip(self.loadout[self.currentSlot] and self.currentSlot or "Primary", true)
end

function WeaponController:GetAmmo()
	return self.ammo[self.currentSlot]
end

----------------------------------------------------------------------
-- Equip / switch
----------------------------------------------------------------------

function WeaponController:Equip(slot: string, immediate: boolean?)
	local id = self.loadout[slot]
	local definition = id and WeaponConfig.get(id)
	if not definition then
		return
	end

	if slot ~= self.currentSlot then
		self.previousSlot = self.currentSlot
	end

	self:_cancelReload()
	self.inspecting = false
	self.currentSlot = slot
	self.definition = definition
	self.shotIndex = 0
	self.spread = 0

	local swapMultiplier = self.context.Ability and self.context.Ability:GetSwapMultiplier() or 1
	local equipTime = immediate and 0.05 or definition.EquipTime / swapMultiplier
	self.equipEndsAt = os.clock() + equipTime

	self.viewmodel:Build(definition)
	self.viewmodel:PlayEquip(math.max(equipTime, 0.08))

	self.context.Movement:SetModifier("weaponSpeed", definition.MoveSpeedMultiplier)
	self.context.Movement:SetModifier("adsSpeedMultiplier", definition.AdsSpeedMultiplier)
	self.context.Camera:SetRecoilRecovery(definition.RecoilRecovery)
	self.context.HUD:SetWeapon(definition, self.ammo[slot])

	Net.toServer("SwitchWeapon", slot)
end

function WeaponController:_onAction(action: string, pressed: boolean)
	if not self.enabled then
		return
	end

	if action == "Fire" then
		self.firing = pressed
		if pressed then
			self._fireQueued = true
			self.inspecting = false
			self.viewmodel:CancelAnimation()
			-- A shotgun mid-shell-reload can fire what it has: cancelling a reload
			-- by shooting is a real decision, not a bug.
			if self.reloading and self.definition.ShellReload and self:GetAmmo().mag > 0 then
				self:_finishReload(true)
			end
		end
	elseif action == "Aim" then
		self.aiming = pressed
		if pressed then
			self.inspecting = false
		end
	elseif action == "Reload" and pressed then
		self:StartReload()
	elseif action == "Inspect" and pressed then
		self:_inspect()
	elseif action == "Slot1" and pressed then
		self:Equip("Primary")
	elseif action == "Slot2" and pressed then
		self:Equip("Secondary")
	elseif action == "Slot3" and pressed then
		self:Equip("Melee")
	elseif action == "Melee" and pressed then
		self:_quickMelee()
	elseif action == "NextWeapon" and pressed then
		local index = table.find(SLOT_ORDER, self.currentSlot) or 1
		self:Equip(SLOT_ORDER[(index % #SLOT_ORDER) + 1])
	end
end

function WeaponController:_inspect()
	if self.reloading or os.clock() < self.equipEndsAt then
		return
	end
	self.inspecting = true
	self.viewmodel:PlayInspect(self.definition.InspectTime)
	task.delay(self.definition.InspectTime, function()
		self.inspecting = false
	end)
end

----------------------------------------------------------------------
-- Reload
----------------------------------------------------------------------

function WeaponController:StartReload()
	local definition = self.definition
	local ammo = self:GetAmmo()
	if not definition or not ammo or self.reloading then
		return
	end
	if definition.FireMode == "Melee" then
		return
	end
	if ammo.mag >= definition.MagSize or ammo.reserve <= 0 then
		return
	end

	local empty = ammo.mag <= 0
	local multiplier = self.context.Ability and self.context.Ability:GetReloadMultiplier() or 1
	local duration = (empty and definition.EmptyReloadTime or definition.ReloadTime) / multiplier

	self.reloading = true
	self.reloadEndsAt = os.clock() + duration
	self.inspecting = false
	self.viewmodel:PlayReload(duration, empty)
	self.context.HUD:SetReloading(true, duration)
	Net.toServer("RequestReload", self.currentSlot)
end

function WeaponController:_cancelReload()
	if not self.reloading then
		return
	end
	self.reloading = false
	self.viewmodel:CancelAnimation()
	self.context.HUD:SetReloading(false, 0)
	Net.toServer("CancelReload")
end

function WeaponController:_finishReload(cancelled: boolean?)
	if not self.reloading then
		return
	end
	self.reloading = false
	self.context.HUD:SetReloading(false, 0)

	if cancelled then
		self.viewmodel:CancelAnimation()
		return
	end

	local definition = self.definition
	local ammo = self:GetAmmo()
	local needed = definition.MagSize - ammo.mag
	local taken = math.min(needed, ammo.reserve)
	ammo.mag += taken
	ammo.reserve -= taken
	self.shotIndex = 0
	self.context.HUD:SetWeapon(definition, ammo)
end

----------------------------------------------------------------------
-- Firing
----------------------------------------------------------------------

function WeaponController:_canFire(): boolean
	if not self.enabled or not self.definition then
		return false
	end
	if self.context.Movement.modifiers.frozen then
		return false
	end
	local humanoid = self.context.Movement.humanoid
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if os.clock() < self.equipEndsAt then
		return false
	end
	if self.reloading then
		return false
	end

	-- Sprinting holsters the gun; the shot fires as soon as it comes back up.
	if self.context.Movement:GetState() == MovementState.Sprint and self.adsAlpha < 0.05 then
		return false
	end

	local interval = WeaponConfig.fireInterval(self.definition)
	if os.clock() - self.lastShotAt < interval then
		return false
	end

	local ammo = self:GetAmmo()
	if self.definition.FireMode ~= "Melee" and (not ammo or ammo.mag <= 0) then
		return false
	end
	return true
end

--[[ Current cone half-angle in degrees. Movement and airtime widen it, aiming and
	 standing still tighten it. The HUD crosshair reads this value directly, so
	 what you see is exactly what the gun will do. ]]
function WeaponController:_currentSpread(): number
	local definition = self.definition
	local snapshot = self.context.Movement:GetSnapshot()

	local base = definition.SpreadHip + (definition.SpreadAds - definition.SpreadHip) * self.adsAlpha
	local speedRatio = snapshot.horizontalSpeed / MovementConfig.Speed.Sprint
	local penalty = speedRatio * definition.SpreadMoveScale

	if not snapshot.grounded then
		penalty += definition.SpreadJumpScale
	end

	return base + penalty + self.spread
end

function WeaponController:_spreadDirection(base: Vector3, degrees: number): Vector3
	if degrees <= 1e-3 then
		return base
	end
	-- Uniform disc sampling inside the cone (sqrt keeps it uniform by AREA, which
	-- is what stops every "random" shot from clustering dead centre).
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local rotation = math.random() * math.pi * 2
	local cf = CFrame.lookAt(Vector3.zero, base)
	return (cf * CFrame.Angles(0, 0, rotation) * CFrame.Angles(angle, 0, 0)).LookVector
end

function WeaponController:_buildRaycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local exclusions = { workspace:FindFirstChild("HyperBlastFx") }
	if self.context.Movement.character then
		table.insert(exclusions, self.context.Movement.character)
	end
	if self.viewmodel.model then
		table.insert(exclusions, self.viewmodel.model)
	end
	params.FilterDescendantsInstances = exclusions
	return params
end

function WeaponController:Fire()
	local definition = self.definition
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	self.lastShotAt = os.clock()
	local ammo = self:GetAmmo()
	if definition.FireMode ~= "Melee" then
		ammo.mag -= 1
		self.context.HUD:SetWeapon(definition, ammo)
	end

	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local spread = self:_currentSpread()
	local params = self:_buildRaycastParams()
	local muzzlePosition = self.viewmodel:GetMuzzlePosition()

	local hits = {}
	local predictedDamage, predictedHeadshot = 0, false

	for _ = 1, definition.Pellets do
		local direction = self:_spreadDirection(look, spread)
		local result = self:_castPellet(origin, direction, definition, params)

		local endPoint = origin + direction * definition.Range
		if result then
			endPoint = result.Position
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.Health > 0 then
				local zone = DamageMath.zoneForPart(result.Instance.Name)
				local distance = (result.Position - origin).Magnitude
				predictedDamage += DamageMath.compute(definition, { distance = distance, zone = zone })
				predictedHeadshot = predictedHeadshot or zone == "Head"

				table.insert(hits, {
					part = result.Instance,
					position = result.Position,
					distance = distance,
					wallbang = result.wallbang,
				})
			else
				self.context.Effects:Impact(result.Position, result.Normal, definition, result.Instance)
			end
		end

		self.context.Effects:Tracer(muzzlePosition, endPoint, definition)
	end

	-- Feedback fires on THIS frame - never waiting on the server.
	self.context.Effects:MuzzleFlash(muzzlePosition, look, definition)
	if predictedDamage > 0 then
		self.context.Effects:Hitmarker(predictedHeadshot, false)
	end

	self:_applyRecoil(definition)
	self.viewmodel:PlayFire()

	self._pendingShotId += 1
	Net.toServer("FireWeapon", {
		slot = self.currentSlot,
		weapon = definition.Id,
		id = self._pendingShotId,
		origin = origin,
		direction = look,
		hits = hits,
		t = workspace:GetServerTimeNow(),
	})

	if definition.FireMode ~= "Melee" and ammo.mag <= 0 then
		task.delay(0.12, function()
			if not self.firing or definition.FireMode == "Auto" then
				self:StartReload()
			end
		end)
	end
end

--[[ One pellet. Returns a plain result table (never a RaycastResult, so callers
	 can annotate it) or nil.

	 Handles two special cases:
	   * NoShoot geometry - decorative neon that bullets pass straight through.
	   * Wallbangs - a piercing weapon punches one THIN surface at a damage
	     penalty, so LANCE can punish someone hiding behind a single panel but
	     not someone behind real cover. ]]
function WeaponController:_castPellet(origin: Vector3, direction: Vector3, definition, params: RaycastParams)
	local function pack(result: RaycastResult?, wallbang: boolean?)
		if not result then
			return nil
		end
		return {
			Instance = result.Instance,
			Position = result.Position,
			Normal = result.Normal,
			wallbang = wallbang == true,
		}
	end

	local ignored = table.clone(params.FilterDescendantsInstances)
	local result = workspace:Raycast(origin, direction * definition.Range, params)

	-- Skip through any decorative geometry we hit along the way.
	local guard = 0
	while result and CollectionService:HasTag(result.Instance, Tags.NoShoot) and guard < 4 do
		guard += 1
		table.insert(ignored, result.Instance)
		local nested = RaycastParams.new()
		nested.FilterType = Enum.RaycastFilterType.Exclude
		nested.IgnoreWater = true
		nested.FilterDescendantsInstances = ignored
		result = workspace:Raycast(origin, direction * definition.Range, nested)
	end

	if not result then
		return nil
	end

	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local isCharacter = model and model:FindFirstChildOfClass("Humanoid") ~= nil
	if isCharacter or not definition.Piercing or definition.Piercing < 1 then
		return pack(result)
	end

	-- Measure thickness by casting back from the far side of the surface.
	local thickness = CombatConfig.HitRegistration.WallbangThickness
	local backParams = RaycastParams.new()
	backParams.FilterType = Enum.RaycastFilterType.Include
	backParams.FilterDescendantsInstances = { result.Instance }
	local exit = workspace:Raycast(
		result.Position + direction * (thickness + 0.1),
		-direction * (thickness + 0.2),
		backParams
	)
	if not exit then
		return pack(result) -- too thick to punch through
	end

	local throughParams = RaycastParams.new()
	throughParams.FilterType = Enum.RaycastFilterType.Exclude
	throughParams.IgnoreWater = true
	table.insert(ignored, result.Instance)
	throughParams.FilterDescendantsInstances = ignored

	local continued = workspace:Raycast(exit.Position + direction * 0.05, direction * definition.Range, throughParams)
	return pack(continued, true) or pack(result)
end

function WeaponController:_applyRecoil(definition)
	local now = os.clock()
	if now - self.lastRecoilAt > definition.RecoilResetTime then
		self.shotIndex = 0
	end
	self.lastRecoilAt = now

	self.shotIndex += 1
	local pattern = definition.RecoilPattern
	local step = pattern[math.min(self.shotIndex, #pattern)]

	local jitter = definition.RecoilJitter
	local pitch = step.X * (1 - jitter * 0.5 + math.random() * jitter)
	local yaw = step.Y + (math.random() - 0.5) * jitter * 2

	-- Aiming tightens the pattern; it does not remove it.
	local adsScale = 1 - self.adsAlpha * 0.25
	self.context.Camera:AddRecoil(pitch * adsScale, yaw * adsScale)

	local kick = definition.VisualKick
	self.context.Camera:Kick(Vector3.new(0, kick.up * 0.2, kick.back * 0.25))

	-- Firing also blooms the cone; it recovers in _update.
	self.spread = math.min(self.spread + step.X * 0.25, definition.SpreadHip * 2.2)
end

--[[ Quick melee: swing the blade without switching to it. The panic button. ]]
function WeaponController:_quickMelee()
	local melee = WeaponConfig.get(self.loadout.Melee)
	local camera = workspace.CurrentCamera
	if not melee or not camera or os.clock() - self.lastShotAt < 0.35 then
		return
	end

	self.lastShotAt = os.clock()
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local params = self:_buildRaycastParams()
	local result = workspace:Raycast(origin, direction * melee.Range, params)

	self.viewmodel:PlayFire()
	self.context.Effects:MeleeSwing(camera.CFrame, melee)

	local hits = {}
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			table.insert(hits, {
				part = result.Instance,
				position = result.Position,
				distance = (result.Position - origin).Magnitude,
			})
			self.context.Effects:Hitmarker(false, false)
		end
	end

	Net.toServer("MeleeSwing", { origin = origin, direction = direction, hits = hits })
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------

function WeaponController:_update(dt: number)
	local definition = self.definition
	if not definition then
		return
	end

	-- ADS blend --------------------------------------------------------
	local wantsAds = self.aiming
		and not self.reloading
		and os.clock() >= self.equipEndsAt
		and self.context.Movement:GetState() ~= MovementState.Sprint
		and definition.FireMode ~= "Melee"

	local adsRate = dt / math.max(definition.AdsTime, 0.01)
	self.adsAlpha = math.clamp(self.adsAlpha + (wantsAds and adsRate or -adsRate * 1.4), 0, 1)
	self.context.Movement:SetModifier("adsFactor", self.adsAlpha)
	self.context.Camera:SetAds(definition.AdsFov, self.adsAlpha, definition.AdsFov / MovementConfig.Camera.BaseFov)

	-- Spread recovery ---------------------------------------------------
	self.spread = math.max(0, self.spread - definition.SpreadRecovery * dt)

	-- Reload completion -------------------------------------------------
	if self.reloading and os.clock() >= self.reloadEndsAt then
		self:_finishReload(false)
	end

	-- Firing ------------------------------------------------------------
	-- Auto holds; semi and melee fire once per press. The queued flag survives a
	-- reload or a swap for as long as the input buffer, so a click during either
	-- fires the instant the weapon is ready instead of being swallowed.
	if definition.FireMode == "Auto" then
		if self.firing and self:_canFire() then
			self:Fire()
		end
	else
		if self._fireQueued and self:_canFire() then
			self._fireQueued = false
			self:Fire()
		elseif not self.firing and not self.input:PeekBuffer("Fire") then
			self._fireQueued = false
		end
	end

	-- Viewmodel ---------------------------------------------------------
	local snapshot = self.context.Movement:GetSnapshot()
	self.viewmodel:Update(dt, {
		adsAlpha = self.adsAlpha,
		moveSpeed = snapshot.horizontalSpeed,
		grounded = snapshot.grounded,
		sprinting = snapshot.state == MovementState.Sprint,
	})

	self.context.HUD:SetCrosshairSpread(self:_currentSpread(), self.adsAlpha)
end

function WeaponController:SetEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled then
		self.firing = false
		self.aiming = false
		self:_cancelReload()
	end
	self.viewmodel:SetVisible(enabled)
end

function WeaponController:GetDefinition()
	return self.definition
end

function WeaponController:Destroy()
	self.viewmodel:Destroy()
	self._trove:Clean()
	local _ = LocalPlayer
end

return WeaponController
