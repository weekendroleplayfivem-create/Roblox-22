--[[
	WeaponService
	Server-authoritative weapon state for every combatant:
	  * which weapons are in which slot and which slot is equipped
	  * magazine + reserve ammo
	  * reload timing (cancelled by switching)
	  * equip timing
	  * fire-rate validation (token bucket per weapon)
	  * charge timing for charge weapons (server measures the charge itself)
	  * third-person placeholder weapon models

	The client predicts all of this for responsiveness, but only this service
	decides whether a shot is allowed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local WeaponService = {}

local Services

-- Network jitter allowances.
local EQUIP_TOLERANCE = 0.15 -- seconds a shot may arrive before equip finishes
local FIRE_RATE_TOLERANCE = 1.2 -- allowed multiplier over max shots/second
local AUTO_BUCKET_SIZE = 2.5 -- shots that may arrive bunched together

type AmmoState = { Mag: number, Reserve: number }
type Bucket = { Tokens: number, Last: number }

type WeaponState = {
	Slots: { [string]: string },
	Equipped: string,
	Ammo: { [string]: AmmoState },
	Reloading: boolean,
	ReloadToken: number,
	EquipReadyAt: number,
	Buckets: { [string]: Bucket },
	ChargeStartedAt: number?,
	InfiniteReserve: boolean,
}

local states: { [number]: WeaponState } = {}

local function now(): number
	return os.clock()
end

function WeaponService:GetState(combatant): WeaponState?
	return states[combatant.Id]
end

function WeaponService:GetEquippedWeaponId(combatant): string?
	local state = states[combatant.Id]
	if not state then
		return nil
	end
	return state.Slots[state.Equipped]
end

function WeaponService:GetEquippedWeapon(combatant)
	local id = WeaponService:GetEquippedWeaponId(combatant)
	return id and WeaponConfig.Get(id)
end

-- Sends the authoritative state to the owning client.
function WeaponService:SendState(combatant)
	local player = combatant.Player
	if not player then
		return
	end
	local state = states[combatant.Id]
	local payload = nil
	if state then
		payload = {
			Slots = state.Slots,
			Equipped = state.Equipped,
			Ammo = state.Ammo,
			Reloading = state.Reloading,
			InfiniteReserve = state.InfiniteReserve,
		}
	end
	Net.Event("Inventory", "WeaponState"):FireClient(player, payload)
end

local function skinFor(combatant)
	if combatant.Player then
		local data = Services.DataService:Get(combatant.Player)
		if data then
			return CosmeticConfig.Get(data.Equipped.WeaponSkin)
		end
	end
	return nil
end

-- PLACEHOLDER third-person weapon: a few welded parts built from the weapon's
-- Viewmodel description. Replace with real models from ServerStorage/Weapons.
local function attachWorldModel(combatant, weaponId: string?)
	local character = combatant.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("WorldWeapon")
	if old then
		old:Destroy()
	end
	character:SetAttribute("Weapon", weaponId)
	if not weaponId then
		return
	end
	local weapon = WeaponConfig.Get(weaponId)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not weapon or not hand or not hand:IsA("BasePart") then
		return
	end

	-- A hand-built model in ServerStorage/Weapons/<WeaponId> takes priority.
	local custom = game:GetService("ServerStorage"):FindFirstChild("Weapons")
	local template = custom and custom:FindFirstChild(weaponId)

	local model = Instance.new("Model")
	model.Name = "WorldWeapon"
	local skin = skinFor(combatant)
	local bodyColor = if skin and skin.Color then skin.Color else Color3.fromRGB(40, 40, 55)
	local material = if skin then Enum.Material[skin.Material] else Enum.Material.SmoothPlastic

	local body: BasePart
	if template and template:IsA("BasePart") then
		body = template:Clone()
	else
		local part = Instance.new("Part")
		part.Size = weapon.Viewmodel.BodySize
		part.Color = bodyColor
		part.Material = material
		body = part
	end
	body.Name = "Body"
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -body.Size.Z / 2 + 0.3)
	body.Parent = model

	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = Vector3.new(body.Size.X + 0.05, 0.12, body.Size.Z * 0.8)
	accent.Color = weapon.Viewmodel.Color
	accent.Material = Enum.Material.Neon
	accent.CanCollide = false
	accent.CanQuery = false
	accent.CanTouch = false
	accent.Massless = true
	accent.CFrame = body.CFrame * CFrame.new(0, body.Size.Y / 2, 0)
	accent.Parent = model

	for _, part in { accent } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	local handWeld = Instance.new("WeldConstraint")
	handWeld.Part0 = hand
	handWeld.Part1 = body
	handWeld.Parent = body
	model.PrimaryPart = body
	model.Parent = character
end

local function newAmmo(weaponId: string): AmmoState
	local weapon = WeaponConfig.Get(weaponId)
	return { Mag = weapon.MagazineSize, Reserve = weapon.ReserveAmmo }
end

-- Gives a fresh loadout (full ammo). `slots` = { Primary = id, Secondary = id? }
function WeaponService:GiveLoadout(combatant, slots: { [string]: string }, infiniteReserve: boolean?)
	local state: WeaponState = {
		Slots = {},
		Equipped = "Primary",
		Ammo = {},
		Reloading = false,
		ReloadToken = 0,
		EquipReadyAt = 0,
		Buckets = {},
		ChargeStartedAt = nil,
		InfiniteReserve = infiniteReserve == true,
	}
	for slot, weaponId in slots do
		local weapon = WeaponConfig.Get(weaponId)
		if weapon then
			state.Slots[slot] = weaponId
			state.Ammo[weaponId] = newAmmo(weaponId)
		end
	end
	if not state.Slots.Primary then
		state.Equipped = "Secondary"
	end
	local equippedWeapon = WeaponConfig.Get(state.Slots[state.Equipped])
	state.EquipReadyAt = now() + (if equippedWeapon then equippedWeapon.EquipTime else 0)
	states[combatant.Id] = state
	attachWorldModel(combatant, state.Slots[state.Equipped])
	WeaponService:SendState(combatant)
end

function WeaponService:ClearLoadout(combatant)
	states[combatant.Id] = nil
	if combatant.Character then
		attachWorldModel(combatant, nil)
	end
	WeaponService:SendState(combatant)
end

-- Loadout a player chose (validated against unlocks at choose time and again here).
function WeaponService:GetPlayerLoadout(player: Player): { [string]: string }
	local data = Services.DataService:Get(player)
	local primary = WeaponConfig.DefaultPrimary
	local secondary = WeaponConfig.DefaultSecondary
	if data then
		if WeaponService:IsWeaponUnlocked(data, data.Equipped.Primary) then
			primary = data.Equipped.Primary
		end
		if WeaponService:IsWeaponUnlocked(data, data.Equipped.Secondary) then
			secondary = data.Equipped.Secondary
		end
	end
	return { Primary = primary, Secondary = secondary }
end

function WeaponService:IsWeaponUnlocked(data, weaponId: string): boolean
	local weapon = WeaponConfig.Get(weaponId)
	return weapon ~= nil and data.Level >= weapon.UnlockLevel
end

local function cancelReload(state: WeaponState)
	if state.Reloading then
		state.Reloading = false
		state.ReloadToken += 1
	end
end

function WeaponService:Equip(combatant, slot: string): boolean
	local state = states[combatant.Id]
	if not state or type(slot) ~= "string" or not state.Slots[slot] then
		return false
	end
	if state.Equipped == slot then
		return true
	end
	cancelReload(state)
	state.ChargeStartedAt = nil
	state.Equipped = slot
	local weapon = WeaponConfig.Get(state.Slots[slot])
	state.EquipReadyAt = now() + weapon.EquipTime
	attachWorldModel(combatant, weapon.Id)
	return true
end

function WeaponService:StartReload(combatant): boolean
	local state = states[combatant.Id]
	if not state or state.Reloading then
		return false
	end
	local weaponId = state.Slots[state.Equipped]
	local weapon = WeaponConfig.Get(weaponId)
	local ammo = state.Ammo[weaponId]
	if not weapon or not ammo or ammo.Mag >= weapon.MagazineSize then
		return false
	end
	if ammo.Reserve <= 0 and not state.InfiniteReserve then
		return false
	end
	state.Reloading = true
	state.ReloadToken += 1
	state.ChargeStartedAt = nil
	local token = state.ReloadToken
	task.delay(weapon.ReloadTime, function()
		-- The state may have been replaced (respawn), switched, or cancelled.
		if states[combatant.Id] ~= state or state.ReloadToken ~= token or not state.Reloading then
			return
		end
		state.Reloading = false
		local needed = weapon.MagazineSize - ammo.Mag
		local taken = if state.InfiniteReserve then needed else math.min(needed, ammo.Reserve)
		ammo.Mag += taken
		if not state.InfiniteReserve then
			ammo.Reserve -= taken
		end
		WeaponService:SendState(combatant)
	end)
	return true
end

function WeaponService:StartCharge(combatant)
	local state = states[combatant.Id]
	if not state then
		return
	end
	local weapon = WeaponConfig.Get(state.Slots[state.Equipped])
	if weapon and weapon.FireMode == "Charge" and not state.Reloading then
		state.ChargeStartedAt = now()
	end
end

-- Charge level measured by the server (0..1). Clears the charge.
function WeaponService:ConsumeCharge(combatant, weapon): number
	local state = states[combatant.Id]
	if not state or not weapon.Charge or not state.ChargeStartedAt then
		return 0
	end
	local elapsed = now() - state.ChargeStartedAt
	state.ChargeStartedAt = nil
	return math.clamp(elapsed / weapon.Charge.Time, 0, 1)
end

--[[
	Validates and consumes one shot. Returns (ok, reason).
	Reasons: "NoState", "NotEquipped", "Equipping", "Reloading", "NoAmmo", "FireRate"
]]
function WeaponService:TryConsumeShot(combatant, weaponId: string): (boolean, string?)
	local state = states[combatant.Id]
	if not state then
		return false, "NoState"
	end
	if state.Slots[state.Equipped] ~= weaponId then
		return false, "NotEquipped"
	end
	local weapon = WeaponConfig.Get(weaponId)
	local time = now()
	if time < state.EquipReadyAt - EQUIP_TOLERANCE then
		return false, "Equipping"
	end
	local ammo = state.Ammo[weaponId]
	if state.Reloading then
		if ammo.Mag > 0 then
			cancelReload(state) -- firing with rounds left interrupts the reload
		else
			return false, "Reloading"
		end
	end
	if ammo.Mag <= 0 then
		return false, "NoAmmo"
	end

	-- Token bucket sized for the weapon's fire pattern.
	local rate = WeaponConfig.GetMaxShotsPerSecond(weapon) * FIRE_RATE_TOLERANCE
	local capacity = if weapon.FireMode == "Burst" then weapon.BurstCount + 0.5 else AUTO_BUCKET_SIZE
	local bucket = state.Buckets[weaponId]
	if not bucket then
		bucket = { Tokens = capacity, Last = time }
		state.Buckets[weaponId] = bucket
	end
	bucket.Tokens = math.min(capacity, bucket.Tokens + (time - bucket.Last) * rate)
	bucket.Last = time
	if bucket.Tokens < 1 then
		return false, "FireRate"
	end
	bucket.Tokens -= 1
	ammo.Mag -= 1
	return true, nil
end

-- Bots: refill instantly-ish without the full reload flow.
function WeaponService:GetAmmo(combatant): AmmoState?
	local state = states[combatant.Id]
	if not state then
		return nil
	end
	return state.Ammo[state.Slots[state.Equipped]]
end

function WeaponService:IsReloading(combatant): boolean
	local state = states[combatant.Id]
	return state ~= nil and state.Reloading
end

function WeaponService:Init(services)
	Services = services

	Net.OnServerEvent("Inventory", "EquipSlot", function(player, slot)
		local combatant = Services.CombatantService:GetByPlayer(player)
		if not combatant or not combatant.Alive then
			return
		end
		if not WeaponService:Equip(combatant, slot) then
			Services.AntiCheatService:Flag(player, "InvalidWeapon", "equip " .. tostring(slot))
			WeaponService:SendState(combatant)
		end
	end, { Rate = 15, Burst = 20 })

	Net.OnServerEvent("Combat", "RequestReload", function(player)
		local combatant = Services.CombatantService:GetByPlayer(player)
		if combatant and combatant.Alive then
			WeaponService:StartReload(combatant)
		end
	end, { Rate = 5, Burst = 8 })

	Net.OnServerEvent("Combat", "ChargeStart", function(player)
		local combatant = Services.CombatantService:GetByPlayer(player)
		if combatant and combatant.Alive then
			WeaponService:StartCharge(combatant)
		end
	end, { Rate = 6, Burst = 8 })

	Net.OnServerInvoke("Inventory", "SetLoadout", function(player, request)
		if type(request) ~= "table" then
			return false, "Invalid request"
		end
		local data = Services.DataService:Get(player)
		if not data then
			return false, "Data not loaded"
		end
		local primary, secondary = request.Primary, request.Secondary
		local movement, tactical = request.Movement, request.Tactical
		local primaryWeapon = type(primary) == "string" and WeaponConfig.Get(primary)
		local secondaryWeapon = type(secondary) == "string" and WeaponConfig.Get(secondary)
		local movementAbility = type(movement) == "string" and AbilityConfig.Get(movement)
		local tacticalAbility = type(tactical) == "string" and AbilityConfig.Get(tactical)
		if not primaryWeapon or primaryWeapon.Slot ~= "Primary" or not WeaponService:IsWeaponUnlocked(data, primary) then
			return false, "Primary weapon locked"
		end
		if not secondaryWeapon or secondaryWeapon.Slot ~= "Secondary" or not WeaponService:IsWeaponUnlocked(data, secondary) then
			return false, "Secondary weapon locked"
		end
		if not movementAbility or movementAbility.Slot ~= "Movement" or data.Level < movementAbility.UnlockLevel then
			return false, "Movement ability locked"
		end
		if not tacticalAbility or tacticalAbility.Slot ~= "Tactical" or data.Level < tacticalAbility.UnlockLevel then
			return false, "Tactical ability locked"
		end
		Services.DataService:Update(player, function(profile)
			profile.Equipped.Primary = primary
			profile.Equipped.Secondary = secondary
			profile.Equipped.Movement = movement
			profile.Equipped.Tactical = tactical
		end)
		local combatant = Services.CombatantService:GetByPlayer(player)
		if combatant then
			Services.AbilityService:ApplyLoadout(combatant)
		end
		return true, if combatant and combatant.InMatch then "Loadout applies on your next spawn" else "Loadout saved"
	end, { Rate = 2, Burst = 5 })
end

function WeaponService:Start() end

WeaponService._states = states

return WeaponService
