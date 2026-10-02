--[[
	SoundConfig
	Every sound in the game is a RECIPE: one or more layers, each built from a
	sound that ships with the Roblox client (rbxasset://sounds/...) and shaped
	with pitch, delay and Roblox SoundEffects (distortion, reverb, echo,
	flange, chorus, tremolo, EQ). Layering + processing turns a handful of
	built-in sounds into distinct sci-fi weapons, abilities and UI sounds.

	PLACEHOLDER AUDIO: for a published game, upload original audio and swap a
	recipe for a single layer, e.g. Fire = { Layers = { L("rbxassetid://123", 0.5, 1) } }.

	Layer fields: Id, Volume, Pitch, Delay (seconds), Looped, Effects
	Effects keys: Distortion (0..1), Reverb {DecayTime, WetLevel},
	Echo {Delay, Feedback, WetLevel}, EQ {Low, Mid, High} (dB),
	Flange {Depth, Rate, Mix}, Chorus {Depth, Rate, Mix},
	Tremolo {Depth, Frequency}, Octave (pitch-shift factor 0.5..2)
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

-- Built-in client sounds (always available, licensed for Roblox experiences).
local PING = "rbxasset://sounds/electronicpingshort.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local SNAP = "rbxasset://sounds/snap.wav"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local WIND = "rbxasset://sounds/action_falling.mp3"

local function L(id: string, volume: number, pitch: number, extra: { [string]: any }?)
	local layer = { Id = id, Volume = volume, Pitch = pitch }
	if extra then
		for key, value in extra do
			layer[key] = value
		end
	end
	return layer
end

local function recipe(...)
	return { Layers = { ... } }
end

-- Quick musical arpeggio (used for rewards / eliminations).
local function arpeggio(pitches: { number }, volume: number, step: number)
	local layers = {}
	for index, pitch in pitches do
		table.insert(layers, L(PING, volume, pitch, { Delay = (index - 1) * step }))
	end
	return { Layers = layers }
end

local SMALL_ROOM = { DecayTime = 0.6, WetLevel = -10 }
local BIG_ROOM = { DecayTime = 1.8, WetLevel = -6 }
local SLAP = { Delay = 0.09, Feedback = 0.25, WetLevel = -10 }
local SPACE = { Delay = 0.18, Feedback = 0.45, WetLevel = -6 }
local LOW_BOOST = { Low = 8, Mid = 0, High = -6 }
local THIN = { Low = -12, Mid = 0, High = 4 }
local WOBBLE = { Depth = 0.6, Rate = 4, Mix = 0.6 }
local SHIMMER = { Depth = 0.5, Rate = 3, Mix = 0.5 }

local SoundConfig = {
	Sounds = {
		--[[ Weapons ]]
		PulseFire = recipe(L(SNAP, 0.42, 1.6), L(PING, 0.12, 2.6, { Effects = { Distortion = 0.5 } }), L(SWOOSH, 0.07, 2.6)),
		BurstFire = recipe(L(SNAP, 0.38, 1.95), L(PING, 0.09, 3.1, { Effects = { EQ = THIN } })),
		ScatterFire = recipe(
			L(SNAP, 0.6, 0.7, { Effects = { Distortion = 0.6, EQ = LOW_BOOST } }),
			L(SWOOSH, 0.25, 0.6),
			L(SNAP, 0.3, 0.5, { Delay = 0.03, Effects = { Reverb = SMALL_ROOM } })
		),
		AutoScatterFire = recipe(L(SNAP, 0.45, 0.85, { Effects = { Distortion = 0.5 } }), L(SWOOSH, 0.14, 0.85)),
		PrecisionFire = recipe(
			L(SNAP, 0.6, 0.55, { Effects = { Reverb = BIG_ROOM, EQ = LOW_BOOST } }),
			L(PING, 0.25, 0.45, { Effects = { Echo = SLAP } }),
			L(SWOOSH, 0.2, 0.4)
		),
		MarksmanFire = recipe(L(SNAP, 0.5, 0.9, { Effects = { EQ = LOW_BOOST } }), L(PING, 0.14, 1.2, { Effects = { Echo = SLAP } })),
		RapidFire = recipe(L(CLICK, 0.3, 1.5), L(SNAP, 0.14, 2.4)),
		PlasmaFire = recipe(
			L(SWOOSH, 0.5, 0.55, { Effects = { Flange = WOBBLE } }),
			L(PING, 0.3, 0.35, { Effects = { Distortion = 0.4 } }),
			L(BUTTON, 0.2, 0.4)
		),
		ChargeFire = recipe(
			L(PING, 0.45, 0.5, { Effects = { Distortion = 0.7, EQ = LOW_BOOST } }),
			L(SWOOSH, 0.35, 0.45),
			L(SNAP, 0.3, 0.4, { Effects = { Reverb = BIG_ROOM } })
		),
		ArcFire = recipe(L(PING, 0.25, 1.9, { Effects = { Distortion = 0.8, Tremolo = { Depth = 1, Frequency = 30 } } }), L(CLICK, 0.1, 3)),
		BeamFire = recipe(L(CLICK, 0.12, 2.2, { Effects = { Flange = WOBBLE } })),
		SidearmFire = recipe(L(SNAP, 0.38, 2.1), L(PING, 0.08, 2.8)),
		CometFire = recipe(L(SNAP, 0.5, 0.65, { Effects = { Distortion = 0.3, Reverb = SMALL_ROOM } }), L(PING, 0.15, 0.9)),
		FlickFire = recipe(L(CLICK, 0.28, 1.8), L(SNAP, 0.12, 2.7)),

		-- Loops (started/stopped by WeaponController).
		BeamLoop = recipe(
			L(CLICK, 0.12, 2.6, { Looped = true, Effects = { Flange = WOBBLE } }),
			L(WIND, 0.12, 2.2, { Looped = true, Effects = { Tremolo = { Depth = 0.6, Frequency = 12 } } })
		),
		ChargeLoop = recipe(L(PING, 0.16, 0.5, { Looped = true, Effects = { Chorus = SHIMMER } })),
		ChargeReady = recipe(L(PING, 0.35, 2), L(PING, 0.2, 2.6, { Delay = 0.05 })),

		Reload = recipe(L(CLICK, 0.35, 0.8), L(BUTTON, 0.2, 0.6, { Delay = 0.04 })),
		ReloadIn = recipe(L(SNAP, 0.3, 1.4), L(CLICK, 0.25, 1.1, { Delay = 0.05 })),
		Equip = recipe(L(BUTTON, 0.28, 1.3), L(SWOOSH, 0.12, 2)),
		DryFire = recipe(L(CLICK, 0.3, 0.5)),
		Inspect = recipe(L(SWOOSH, 0.15, 1.4), L(CLICK, 0.12, 1.2, { Delay = 0.3 })),
		Explosion = recipe(
			L(SWOOSH, 0.7, 0.35, { Effects = { Distortion = 0.6, Reverb = BIG_ROOM } }),
			L(SPLASH, 0.4, 0.6, { Effects = { Distortion = 0.5 } }),
			L(SNAP, 0.5, 0.3, { Effects = { EQ = LOW_BOOST } })
		),
		Impact = recipe(L(CLICK, 0.08, 2.2)),
		ProjectileHum = recipe(L(WIND, 0.25, 1.6, { Looped = true, Effects = { Flange = WOBBLE } })),

		--[[ Hit feedback ]]
		Hit = recipe(L(PING, 0.32, 1.5), L(CLICK, 0.1, 2)),
		Headshot = recipe(L(PING, 0.42, 2.2), L(PING, 0.22, 2.9, { Delay = 0.04 })),
		Elimination = arpeggio({ 1.1, 1.4, 1.65 }, 0.4, 0.07),
		MultiElimination = arpeggio({ 1.4, 1.65, 2.1, 2.8 }, 0.4, 0.06),
		ShieldHit = recipe(L(PING, 0.2, 2.6, { Effects = { Chorus = SHIMMER } })),
		ShieldBreak = recipe(L(PING, 0.45, 0.7, { Effects = { Distortion = 0.4 } }), L(SWOOSH, 0.25, 1.5)),
		Damaged = recipe(L(BUTTON, 0.35, 0.6, { Effects = { EQ = LOW_BOOST } })),
		LowHealth = recipe(L(BUTTON, 0.3, 0.4, { Effects = { EQ = LOW_BOOST } }), L(BUTTON, 0.22, 0.38, { Delay = 0.16, Effects = { EQ = LOW_BOOST } })),
		ShieldRecharge = recipe(L(SWOOSH, 0.2, 1.8, { Effects = { Chorus = SHIMMER } }), L(PING, 0.15, 1.9, { Delay = 0.1 })),
		Respawn = recipe(L(SWOOSH, 0.35, 0.8, { Effects = { Reverb = BIG_ROOM } }), L(PING, 0.25, 1.6, { Delay = 0.1 })),
		ProtectionEnd = recipe(L(PING, 0.15, 0.9)),

		--[[ Movement ]]
		Jump = recipe(L(JUMP, 0.25, 1.1)),
		DoubleJump = recipe(L(SWOOSH, 0.3, 1.7), L(PING, 0.08, 2.5)),
		WallJump = recipe(L(SNAP, 0.25, 1.2), L(SWOOSH, 0.3, 1.4)),
		Land = recipe(L(LAND, 0.3, 1)),
		HeavyLand = recipe(L(LAND, 0.45, 0.7), L(SNAP, 0.2, 0.5, { Effects = { EQ = LOW_BOOST } })),
		Slide = recipe(L(SWOOSH, 0.35, 0.9), L(SPLASH, 0.1, 1.6, { Effects = { Flange = WOBBLE } })),
		Footstep = recipe(L(STEP, 0.15, 1)),
		Dash = recipe(L(SWOOSH, 0.5, 1.4), L(SWOOSH, 0.2, 0.7, { Delay = 0.05, Effects = { Flange = WOBBLE } })),
		JumpPad = recipe(L(SWOOSH, 0.5, 1.1), L(PING, 0.25, 0.8, { Effects = { Echo = SPACE } })),
		GravityEnter = recipe(L(SWOOSH, 0.3, 0.4, { Effects = { Chorus = SHIMMER } })),

		--[[ Abilities ]]
		Phase = recipe(L(SWOOSH, 0.4, 0.8, { Effects = { Chorus = SHIMMER, Flange = WOBBLE } }), L(PING, 0.2, 0.6)),
		PhaseEnd = recipe(L(SWOOSH, 0.2, 1.2)),
		Shield = recipe(L(PING, 0.45, 0.8, { Effects = { Reverb = BIG_ROOM } }), L(SWOOSH, 0.25, 0.6)),
		Decoy = recipe(L(PING, 0.35, 1.3), L(PING, 0.2, 1.8, { Delay = 0.06, Effects = { Chorus = SHIMMER } })),
		DecoyPop = recipe(L(PING, 0.3, 2.4), L(CLICK, 0.2, 1.5)),
		Pulse = recipe(L(PING, 0.5, 0.5, { Effects = { Echo = SPACE } }), L(SWOOSH, 0.3, 0.3)),
		PulseReveal = recipe(L(PING, 0.25, 2, { Effects = { Echo = SLAP } })),
		Gravity = recipe(L(SWOOSH, 0.5, 0.5, { Effects = { Flange = WOBBLE } }), L(PING, 0.2, 0.3, { Effects = { Tremolo = { Depth = 0.8, Frequency = 6 } } })),
		AbilityReady = recipe(L(PING, 0.18, 1.8)),

		--[[ UI ]]
		UIHover = recipe(L(CLICK, 0.15, 1.6)),
		UIClick = recipe(L(BUTTON, 0.3, 1.2)),
		UIBack = recipe(L(BUTTON, 0.3, 0.9)),
		Purchase = arpeggio({ 1.2, 1.6, 2.4 }, 0.38, 0.07),
		Error = recipe(L(BUTTON, 0.35, 0.5, { Effects = { Distortion = 0.3 } })),
		CosmeticEquip = recipe(L(PING, 0.3, 1.4)),
		LevelUp = {
			Layers = {
				L(PING, 0.45, 1.0),
				L(PING, 0.45, 1.25, { Delay = 0.08 }),
				L(PING, 0.45, 1.5, { Delay = 0.16 }),
				L(PING, 0.5, 2.0, { Delay = 0.24, Effects = { Reverb = BIG_ROOM } }),
				L(SWOOSH, 0.3, 0.8, { Delay = 0.24 }),
			},
		},
		XP = recipe(L(BUTTON, 0.2, 1.8)),
		Countdown = recipe(L(PING, 0.4, 1)),
		MatchStart = recipe(L(PING, 0.5, 1.4), L(PING, 0.4, 2.1, { Delay = 0.1 }), L(SWOOSH, 0.3, 0.6, { Effects = { Reverb = BIG_ROOM } })),
		Victory = arpeggio({ 1, 1.25, 1.5, 2 }, 0.45, 0.12),
		Defeat = arpeggio({ 1.2, 1, 0.8 }, 0.35, 0.15),
		QueueJoin = recipe(L(PING, 0.3, 1.2)),
		Notify = recipe(L(PING, 0.25, 1.3)),

		--[[ Ambient loops per map ]]
		AmbientLobby = recipe(L(WIND, 0.05, 0.4, { Looped = true, Effects = { EQ = LOW_BOOST } })),
		AmbientNeon = recipe(L(WIND, 0.08, 0.35, { Looped = true, Effects = { EQ = LOW_BOOST, Flange = { Depth = 0.3, Rate = 0.2, Mix = 0.4 } } })),
		AmbientSky = recipe(L(WIND, 0.14, 0.6, { Looped = true })),
		AmbientCore = recipe(L(WIND, 0.1, 0.25, { Looped = true, Effects = { EQ = LOW_BOOST, Tremolo = { Depth = 0.5, Frequency = 1.2 } } })),
	},
}

return TableUtil.DeepFreeze(SoundConfig)
