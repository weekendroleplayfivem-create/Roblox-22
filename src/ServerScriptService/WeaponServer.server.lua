--[[
	WeaponServer
	Server-authoritative weapon state machine. The client only ever *requests*
	fire/reload/switch; this script is the sole place ammo, cooldowns, and
	damage get decided. See section 13/37 of the design brief: never trust
	client damage, ammo, or fire rate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local PlayerData = require(script.Parent.PlayerData)
local DamageService = require(script.Parent.DamageService)
local AntiExploit = require(script.Parent.AntiExploit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireWeapon = Remotes:WaitForChild("FireWeapon")
local ReloadWeapon = Remotes:WaitForChild("ReloadWeapon")
local SwitchWeapon = Remotes:WaitForChild("SwitchWeapon")
local WeaponFired = Remotes:WaitForChild("WeaponFired")
local HitConfirmed = Remotes:WaitForChild("HitConfirmed")
local WeaponEquipped = Remotes:WaitForChild("WeaponEquipped")

-- [player] = { EquippedSlot, Ammo = {[weaponId] = count}, Reloading = {[weaponId] = bool}, LastFire = {[weaponId] = clock} }
local weaponState = {}

local function stateFor(player)
	local s = weaponState[player]
	if not s then
		s = { EquippedSlot = "Primary", Ammo = {}, Reloading = {}, LastFire = {} }
		weaponState[player] = s
	end
	return s
end

local function equippedWeaponId(player)
	local profile = PlayerData.Get(player)
	local state = stateFor(player)
	if not profile then
		return nil
	end
	return profile.Loadout[state.EquippedSlot]
end

local function ensureAmmo(player, weaponId)
	local state = stateFor(player)
	local weapon = WeaponData.Get(weaponId)
	if weapon and state.Ammo[weaponId] == nil then
		state.Ammo[weaponId] = weapon.Magazine
	end
end

Players.PlayerAdded:Connect(function(player)
	weaponState[player] = { EquippedSlot = "Primary", Ammo = {}, Reloading = {}, LastFire = {} }
	player.CharacterAdded:Connect(function()
		local state = stateFor(player)
		state.Reloading = {}
		local profile = PlayerData.Get(player)
		if profile then
			for _, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
				local weaponId = profile.Loadout[slot]
				if weaponId then
					ensureAmmo(player, weaponId)
				end
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	weaponState[player] = nil
end)

SwitchWeapon.OnServerEvent:Connect(function(player, slot)
	if slot ~= "Primary" and slot ~= "Secondary" and slot ~= "Melee" then
		return
	end
	local profile = PlayerData.Get(player)
	if not profile or not profile.Loadout[slot] then
		return
	end
	local state = stateFor(player)
	state.EquippedSlot = slot
	local weaponId = profile.Loadout[slot]
	ensureAmmo(player, weaponId)
	WeaponEquipped:FireAllClients(player, weaponId, slot)
end)

ReloadWeapon.OnServerEvent:Connect(function(player)
	local weaponId = equippedWeaponId(player)
	if not weaponId then
		return
	end
	local weapon = WeaponData.Get(weaponId)
	if not weapon or weapon.Slot == "Melee" then
		return
	end
	local state = stateFor(player)
	ensureAmmo(player, weaponId)
	if state.Reloading[weaponId] then
		return
	end
	if state.Ammo[weaponId] >= weapon.Magazine then
		return
	end

	state.Reloading[weaponId] = true
	task.delay(weapon.ReloadTime, function()
		if weaponState[player] then
			state.Ammo[weaponId] = weapon.Magazine
			state.Reloading[weaponId] = false
		end
	end)
end)

-- payload: { Origin, Direction, TargetPosition }
FireWeapon.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	local origin, direction = payload.Origin, payload.Direction
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local weaponId = equippedWeaponId(player)
	local weapon = weaponId and WeaponData.Get(weaponId)
	if not weapon then
		return
	end

	local state = stateFor(player)
	direction = direction.Unit

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local function resolveHit(hitResult, isHeadshot, damage)
		if not hitResult or not hitResult.Instance then
			return
		end
		local hitCharacter = hitResult.Instance:FindFirstAncestorOfClass("Model")
		local hitHumanoid = hitCharacter and hitCharacter:FindFirstChildOfClass("Humanoid")
		local hitPlayer = hitCharacter and Players:GetPlayerFromCharacter(hitCharacter)
		if hitHumanoid and hitPlayer and hitPlayer ~= player then
			DamageService.ApplyDamage(player, hitPlayer, damage, weaponId, isHeadshot)
			HitConfirmed:FireClient(player, isHeadshot)
		end
	end

	if weapon.Slot == "Melee" then
		-- Melee: no ammo, cooldown gated purely by FireRate (swings/sec).
		local minInterval = 1 / weapon.FireRate
		local last = state.LastFire[weaponId] or 0
		if os.clock() - last < minInterval * 0.85 then
			AntiExploit.Flag(player, "FireRate")
			return
		end
		state.LastFire[weaponId] = os.clock()

		local result = Workspace:Raycast(origin, direction * weapon.Range, raycastParams)
		WeaponFired:FireAllClients(player, weaponId, origin, direction, result and result.Position or (origin + direction * weapon.Range))
		if result then
			local isHeadshot = result.Instance.Name == "Head"
			resolveHit(result, isHeadshot, weapon.Damage * (isHeadshot and 1.5 or 1))
		end
		return
	end

	ensureAmmo(player, weaponId)
	if state.Reloading[weaponId] then
		return
	end

	-- Fire-rate enforcement: server clock is the only clock that matters.
	local minInterval = 1 / weapon.FireRate
	local last = state.LastFire[weaponId] or 0
	if os.clock() - last < minInterval * 0.92 then
		AntiExploit.Flag(player, "FireRate")
		return
	end
	if not AntiExploit.CheckFireRate(player, weaponId, minInterval) then
		return
	end
	state.LastFire[weaponId] = os.clock()

	if state.Ammo[weaponId] <= 0 then
		return
	end
	state.Ammo[weaponId] -= 1

	-- Server-side hit validation: raycast from the client-reported origin
	-- (close to the camera) along the reported direction, capped to the
	-- weapon's declared range so no weapon can out-range its own stats.
	if weapon.Pellets then
		-- Shotgun: several independent pellet rays with a small spread cone.
		local lastHitPos = origin + direction * weapon.Range
		for _ = 1, weapon.Pellets do
			local spreadRad = math.rad(weapon.Spread)
			local jitter = CFrame.Angles(
				(math.random() - 0.5) * spreadRad,
				(math.random() - 0.5) * spreadRad,
				0
			)
			local pelletDirection = (CFrame.new(Vector3.zero, direction) * jitter).LookVector
			local result = Workspace:Raycast(origin, pelletDirection * weapon.Range, raycastParams)
			if result then
				lastHitPos = result.Position
				local isHeadshot = result.Instance.Name == "Head"
				resolveHit(result, isHeadshot, weapon.DamagePerPellet * (isHeadshot and (weapon.HeadshotMultiplier or 1) or 1))
			end
		end
		WeaponFired:FireAllClients(player, weaponId, origin, direction, lastHitPos)
	else
		local result = Workspace:Raycast(origin, direction * weapon.Range, raycastParams)
		WeaponFired:FireAllClients(player, weaponId, origin, direction, result and result.Position or (origin + direction * weapon.Range))
		if result then
			local isHeadshot = result.Instance.Name == "Head"
			resolveHit(result, isHeadshot, weapon.Damage * (isHeadshot and (weapon.HeadshotMultiplier or 1) or 1))
		end
	end
end)
