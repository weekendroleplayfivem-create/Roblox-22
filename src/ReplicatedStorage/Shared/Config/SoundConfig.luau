--[[
	SoundConfig
	PLACEHOLDER AUDIO. These use sounds that ship with the Roblox client
	(rbxasset://sounds/...). Replace each `Id` with your own original or
	properly licensed uploaded audio (rbxassetid://<id>) before publishing.
	Pitch variations make the shared placeholder files sound distinct.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local PING = "rbxasset://sounds/electronicpingshort.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local SNAP = "rbxasset://sounds/snap.wav"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"

local SoundConfig = {
	Sounds = {
		-- Weapons
		PulseFire = { Id = SNAP, Volume = 0.45, Pitch = 1.6 },
		BurstFire = { Id = SNAP, Volume = 0.45, Pitch = 1.9 },
		ScatterFire = { Id = SNAP, Volume = 0.6, Pitch = 0.8 },
		PrecisionFire = { Id = SNAP, Volume = 0.6, Pitch = 0.6 },
		RapidFire = { Id = CLICK, Volume = 0.35, Pitch = 1.4 },
		PlasmaFire = { Id = SWOOSH, Volume = 0.6, Pitch = 0.7 },
		ChargeFire = { Id = PING, Volume = 0.5, Pitch = 0.6 },
		ArcFire = { Id = PING, Volume = 0.35, Pitch = 1.8 },
		BeamFire = { Id = CLICK, Volume = 0.2, Pitch = 2.2 },
		SidearmFire = { Id = SNAP, Volume = 0.4, Pitch = 2.1 },
		Charge = { Id = PING, Volume = 0.25, Pitch = 0.5 },
		Reload = { Id = CLICK, Volume = 0.4, Pitch = 0.8 },
		Equip = { Id = BUTTON, Volume = 0.3, Pitch = 1.3 },
		DryFire = { Id = CLICK, Volume = 0.3, Pitch = 0.5 },
		Explosion = { Id = SWOOSH, Volume = 0.7, Pitch = 0.45 },

		-- Feedback
		Hit = { Id = PING, Volume = 0.35, Pitch = 1.5 },
		Headshot = { Id = PING, Volume = 0.45, Pitch = 2.2 },
		Elimination = { Id = PING, Volume = 0.6, Pitch = 1.1 },
		Damaged = { Id = BUTTON, Volume = 0.35, Pitch = 0.6 },
		ShieldBreak = { Id = PING, Volume = 0.4, Pitch = 0.7 },
		LevelUp = { Id = PING, Volume = 0.7, Pitch = 0.9 },
		XP = { Id = BUTTON, Volume = 0.2, Pitch = 1.8 },

		-- Abilities
		Dash = { Id = SWOOSH, Volume = 0.5, Pitch = 1.4 },
		Phase = { Id = SWOOSH, Volume = 0.45, Pitch = 0.8 },
		Shield = { Id = PING, Volume = 0.45, Pitch = 0.8 },
		Decoy = { Id = PING, Volume = 0.4, Pitch = 1.3 },
		Pulse = { Id = PING, Volume = 0.55, Pitch = 0.5 },
		Gravity = { Id = SWOOSH, Volume = 0.5, Pitch = 0.5 },
		JumpPad = { Id = SWOOSH, Volume = 0.5, Pitch = 1.1 },

		-- Movement
		Jump = { Id = JUMP, Volume = 0.25, Pitch = 1.1 },
		DoubleJump = { Id = SWOOSH, Volume = 0.3, Pitch = 1.7 },
		Land = { Id = LAND, Volume = 0.3, Pitch = 1 },
		Slide = { Id = SWOOSH, Volume = 0.35, Pitch = 0.9 },
		Footstep = { Id = STEP, Volume = 0.15, Pitch = 1 },

		-- UI
		UIHover = { Id = CLICK, Volume = 0.15, Pitch = 1.6 },
		UIClick = { Id = BUTTON, Volume = 0.3, Pitch = 1.2 },
		Countdown = { Id = PING, Volume = 0.4, Pitch = 1 },
		MatchStart = { Id = PING, Volume = 0.6, Pitch = 1.4 },

		-- Ambient (PLACEHOLDER: no looping ambience shipped; leave empty to skip)
		AmbientNeon = { Id = "", Volume = 0.2, Pitch = 1, Looped = true },
	},
}

return TableUtil.DeepFreeze(SoundConfig)
