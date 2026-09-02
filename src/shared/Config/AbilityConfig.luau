--!nonstrict
--[[
	AbilityConfig.luau
	Three abilities, one job each. They are movement tools first and combat tools
	second - none of them deals damage, so an ability can never trade a duel for you.

	Cooldown design: charges recover independently, so a good player can bank one
	and hold it for a rotation instead of dumping it the moment it lights up.
--]]

local Palette = require(script.Parent.Palette)

local AbilityConfig = {}

AbilityConfig.Slots = { "HyperDash", "PhaseStep", "Overdrive" }

AbilityConfig.Abilities = {
	--------------------------------------------------------------------
	HyperDash = {
		Id = "HyperDash",
		DisplayName = "HYPER DASH",
		Keybind = Enum.KeyCode.Q,
		GamepadBind = Enum.KeyCode.ButtonL1,
		Description = "Directional burst. Keeps its speed on landing - dash into a slide.",

		Cooldown = 5.0,
		Charges = 2,
		ChargeRegenStagger = 0.6, -- second charge starts recovering this late
		Duration = 0.20, -- how long the impulse is driven for
		Speed = 74, -- studs/s during the burst
		VerticalKeep = 0.15, -- fraction of vertical velocity kept (mostly cancels falling)
		AirUses = 1, -- dashes allowed per airtime before touching ground
		ExitSpeedKeep = 0.72, -- momentum handed back to the movement model on exit
		CancelWindow = 0.10, -- can slide/jump out after this much of the dash
		LockAim = false, -- you keep full camera control - it's an aim game

		Fov = 13,
		TrailColor = Palette.NeonCyan,
		TrailColorSecondary = Palette.NeonPurple,
		TrailLife = 0.42,
		BurstParticles = 40,
		Sound = { Id = "rbxassetid://9118823104", Volume = 0.55, Pitch = 1.15 },
	},

	--------------------------------------------------------------------
	PhaseStep = {
		Id = "PhaseStep",
		DisplayName = "PHASE STEP",
		Keybind = Enum.KeyCode.E,
		GamepadBind = Enum.KeyCode.ButtonR1,
		Description = "Short forward blink through space. Leaves a holographic decoy afterimage.",

		Cooldown = 9.0,
		Charges = 1,
		Distance = 16, -- max blink distance
		MinDistance = 3, -- refuses to fire if the path is this blocked
		Duration = 0.12, -- the blink is a fast interpolation, not a teleport pop
		PhaseThroughPlayers = true, -- passes through bodies, never through geometry
		PostSpeed = 26, -- speed you exit the blink with
		InvulnerabilityWindow = 0.0, -- deliberately zero: no free escapes from a won duel
		AfterimageLife = 0.85,
		AfterimageCount = 3,

		Fov = 6,
		TrailColor = Palette.NeonPurple,
		TrailColorSecondary = Palette.NeonMagenta,
		Sound = { Id = "rbxassetid://9125402735", Volume = 0.6, Pitch = 1.0 },
	},

	--------------------------------------------------------------------
	Overdrive = {
		Id = "Overdrive",
		DisplayName = "OVERDRIVE",
		Keybind = Enum.KeyCode.F,
		GamepadBind = Enum.KeyCode.ButtonY,
		Description = "Amps movement, reload and swap speed. You glow - the enemy sees you coming.",

		Cooldown = 26.0,
		Charges = 1,
		Duration = 7.0,

		SpeedMultiplier = 1.22,
		AccelMultiplier = 1.35,
		ReloadMultiplier = 1.45,
		SwapMultiplier = 1.5,
		StaminaDrainMultiplier = 0.45,
		SlideCooldownMultiplier = 0.6,
		DashCooldownMultiplier = 0.7,

		-- Counterplay: while lit up you are trivially trackable. That's the cost.
		BodyGlow = Palette.NeonPurple,
		GlowBrightness = 3.2,
		Fov = 5,
		AuraParticles = 26,
		Sound = { Id = "rbxassetid://9112854440", Volume = 0.6, Pitch = 1.0 },
		EndSound = { Id = "rbxassetid://9112854440", Volume = 0.35, Pitch = 0.8 },
	},
}

--[[ Ability requests are client-predicted and server-authoritative.
	 The server allows a small clock skew before it rejects a request as too early. ]]
AbilityConfig.Validation = {
	CooldownGrace = 0.12, -- seconds of network slack allowed on a cooldown check
	MaxQueuedRequests = 3,
	RejectSpamWindow = 1.0,
}

function AbilityConfig.get(id: string)
	return AbilityConfig.Abilities[id]
end

return AbilityConfig
