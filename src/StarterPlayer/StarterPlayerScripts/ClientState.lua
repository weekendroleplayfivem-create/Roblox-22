--[[
	ClientState
	Shared runtime state between the client controllers (Scooter, Camera,
	Weapon, UI) so they can react to each other without a tangle of
	BindableEvents. Local-only, cosmetic/prediction data — never authoritative.
]]

local ClientState = {}

ClientState.Camera = {
	Sensitivity = 0.5,
	FOVBase = 80,
	RecoilPitch = 0,
	RecoilYaw = 0,
	CameraShakeEnabled = true,
	ShakeMagnitude = 0,
	ShakeDuration = 0,
}

ClientState.Scooter = {
	Speed = 0,
	MaxSpeed = 85,
	Boosting = false,
	BoostMeter = 100,
	Drifting = false,
}

ClientState.Weapon = {
	EquippedSlot = "Primary",
	EquippedWeaponId = nil,
	ADS = false,
	FiringHeld = false,
	Ammo = {},
	Reloading = {},
}

-- Populated by WeaponController/ScooterController so MobileControls (and any
-- other UI) can trigger the same actions as keyboard input without reaching
-- into another script's closures.
ClientState.Actions = {
	FireDown = function() end,
	FireUp = function() end,
	Reload = function() end,
	SwitchWeapon = function(_slot) end,
	SetBoost = function(_active) end,
	SetADS = function(_active) end,
	Jump = function() end,
}

ClientState.Settings = {
	GraphicsQuality = "Auto",
	MusicVolume = 0.5,
	SFXVolume = 0.7,
	Sensitivity = 0.5,
	CameraShake = true,
	FOV = 80,
	ShowDamageNumbers = true,
	ShowKillFeed = true,
}

function ClientState.AddRecoil(pitch, yaw)
	ClientState.Camera.RecoilPitch += pitch
	ClientState.Camera.RecoilYaw += yaw
end

function ClientState.Shake(magnitude, duration)
	if not ClientState.Settings.CameraShake then
		return
	end
	ClientState.Camera.ShakeMagnitude = math.max(ClientState.Camera.ShakeMagnitude, magnitude)
	ClientState.Camera.ShakeDuration = math.max(ClientState.Camera.ShakeDuration, duration)
end

function ClientState.ApplySettings(settings)
	for key, value in pairs(settings) do
		ClientState.Settings[key] = value
	end
	ClientState.Camera.Sensitivity = ClientState.Settings.Sensitivity
	ClientState.Camera.FOVBase = ClientState.Settings.FOV
	ClientState.Camera.CameraShakeEnabled = ClientState.Settings.CameraShake
end

return ClientState
