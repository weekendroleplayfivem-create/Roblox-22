--[[
	PlayerConfig
	Every movement, camera and health tuning value lives here. Never hardcode
	these numbers in systems; read them from this module.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local PlayerConfig = {
	Movement = {
		WalkSpeed = 16,
		SprintSpeed = 24,
		SlideSpeed = 30,
		CrouchSpeed = 9,
		JumpPower = 50,

		-- Studs/second gained per second while speeding up / slowing down.
		Acceleration = 90,
		Deceleration = 60,
		-- Momentum above the current target speed bleeds off at this rate
		-- (slower in the air so slide-jumps and dashes carry).
		GroundMomentumDecay = 26,
		AirMomentumDecay = 8,

		-- Sprinting only works while moving mostly forward.
		SprintForwardDot = 0.2,
		ToggleSprintDefault = false,

		Slide = {
			Duration = 0.7,
			Cooldown = 0.9,
			-- Must be at least this fast to start a slide.
			MinStartSpeed = 20,
			EndSpeed = 18,
			CameraOffsetY = -1.6,
			HipHeightScale = 0.55,
			-- A jump during a slide keeps this fraction of slide speed.
			JumpCarry = 0.95,
		},

		DoubleJump = {
			Enabled = true,
			MaxPerAirtime = 1,
			Power = 46,
			-- Minimum time after leaving the ground before a double jump.
			MinAirTime = 0.12,
		},

		-- WallJump is implemented in Shared/Modules/WallMovement and can be
		-- switched off here without touching any other code.
		WallJump = {
			Enabled = true,
			DetectDistance = 3.2,
			UpPower = 44,
			PushSpeed = 34,
			MaxPerAirtime = 2,
			-- Can't jump off the same wall twice within this many seconds.
			SameWallCooldown = 0.9,
			MinAirTime = 0.1,
		},

		Dash = {
			Speed = 72,
			Duration = 0.16,
			-- Fraction of dash speed kept as momentum afterwards.
			MomentumCarry = 0.45,
			-- Dash stops this many studs before a wall (never passes through).
			WallBuffer = 2.5,
		},

		JumpPad = {
			Cooldown = 0.6,
		},
	},

	Camera = {
		DefaultFov = 80,
		SprintFov = 86,
		SlideFov = 90,
		DashFovKick = 8,
		MinFovSetting = 70,
		MaxFovSetting = 100,
		FovStiffness = 90,
		FovDamping = 16,

		Bob = {
			WalkFrequency = 9,
			SprintFrequency = 12,
			Amplitude = 0.06,
			RollAmplitude = 0.25, -- degrees
		},

		LandingShake = {
			MinFallSpeed = 30,
			MaxFallSpeed = 120,
			MaxDip = 0.45,
		},

		Shake = {
			Damage = 0.35,
			Explosion = 0.8,
			MaxIntensity = 1.2,
		},

		SlideTilt = 4, -- degrees of roll while sliding
	},

	Health = {
		MaxHealth = 100,
		MaxShield = 50,
		ShieldRegenDelay = 4,
		ShieldRegenRate = 25, -- per second
		HealthRegenDelay = 6,
		HealthRegenRate = 12, -- per second
		FallOutOfWorldY = -60,
	},

	Respawn = {
		Delay = 3,
		SpawnProtection = 1.5,
	},

	Character = {
		-- Default Roblox characters are used; these values apply to them.
		HeadOffset = Vector3.new(0, 1.5, 0),
	},
}

return TableUtil.DeepFreeze(PlayerConfig)
