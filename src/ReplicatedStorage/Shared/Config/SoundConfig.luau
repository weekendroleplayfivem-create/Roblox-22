--[[
	SoundConfig
	Every sound in the game is a RECIPE: one or more layers, each built from a
	sound that ships with the Roblox client (rbxasset://sounds/...) and shaped
	with pitch, delay and Roblox SoundEffects (distortion, reverb, echo,
	flange, chorus, tremolo, EQ). Layering + processing turns a handful of
	built-in sounds into distinct sci-fi weapons, abilities and UI sounds.

	PLACEHOLDER AUDIO: for a published game, upload original audio and swap a
	recipe for a single layer, e.g. Fire = { Layers = { L("rbxassetid://123", 0.5, 1) } }.

	Layer fields: Id, Volume, Pitch, Delay (seconds), Looped, Effects,
	Sweep {From, To, Time} (pitch glide), Fade {After, Time}, Region {Start, Stop}
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
local CRUNCH = { Low = 6, Mid = 3, High = -2 }
local AIR = { Low = -8, Mid = -2, High = 6 }

-- Laser "pew": a ping gliding down in pitch.
local function pew(volume: number, from: number, to: number, time: number, extra: { [string]: any }?)
	local layer = L(PING, volume, from, { Sweep = { From = from, To = to, Time = time }, Fade = { After = time * 0.6, Time = time * 0.6 } })
	if extra then
		for key, value in extra do
			layer[key] = value
		end
	end
	return layer
end

-- Short burst of wind noise (whooshes, whizzes, rumbles).
local function whoosh(volume: number, from: number, to: number, time: number, extra: { [string]: any }?)
	local layer = L(WIND, volume, from, { Sweep = { From = from, To = to, Time = time }, Fade = { After = time * 0.5, Time = time * 0.6 } })
	if extra then
		for key, value in extra do
			layer[key] = value
		end
	end
	return layer
end

local SoundConfig = {
	Sounds = {
		--[[ Weapons: transient crack + body + energy "pew" + tail + mechanics ]]
		PulseFire = recipe(
			L(SNAP, 0.45, 1.7),
			L(SNAP, 0.28, 0.7, { Effects = { EQ = CRUNCH, Distortion = 0.35 } }),
			pew(0.16, 2.6, 1.1, 0.09, { Effects = { Distortion = 0.25 } }),
			whoosh(0.08, 1.4, 0.6, 0.25, { Effects = { Reverb = SMALL_ROOM } }),
			L(CLICK, 0.05, 2.6, { Delay = 0.035 })
		),
		BurstFire = recipe(
			L(SNAP, 0.4, 2),
			L(SNAP, 0.2, 0.9, { Effects = { EQ = CRUNCH } }),
			pew(0.14, 3.2, 1.5, 0.07, { Effects = { EQ = THIN } }),
			L(CLICK, 0.04, 3, { Delay = 0.03 })
		),
		ScatterFire = recipe(
			L(SNAP, 0.65, 0.6, { Effects = { Distortion = 0.7, EQ = LOW_BOOST } }),
			L(SPLASH, 0.3, 0.7, { Effects = { Distortion = 0.6 }, Fade = { After = 0.08, Time = 0.2 } }),
			whoosh(0.25, 1, 0.35, 0.4, { Effects = { Reverb = BIG_ROOM } }),
			L(SNAP, 0.25, 0.45, { Delay = 0.025, Effects = { Reverb = SMALL_ROOM } }),
			L(CLICK, 0.22, 0.9, { Delay = 0.32 }),
			L(BUTTON, 0.18, 0.7, { Delay = 0.42 })
		),
		AutoScatterFire = recipe(
			L(SNAP, 0.48, 0.8, { Effects = { Distortion = 0.55, EQ = LOW_BOOST } }),
			L(SPLASH, 0.15, 0.9, { Fade = { After = 0.05, Time = 0.12 } }),
			whoosh(0.12, 1.1, 0.5, 0.2)
		),
		PrecisionFire = recipe(
			L(SNAP, 0.6, 0.5, { Effects = { Reverb = BIG_ROOM, EQ = LOW_BOOST } }),
			pew(0.32, 1.8, 0.3, 0.45, { Effects = { Echo = SLAP, Distortion = 0.3 } }),
			whoosh(0.22, 2.2, 0.4, 0.6, { Effects = { Reverb = BIG_ROOM } }),
			L(CLICK, 0.16, 1.1, { Delay = 0.5 }),
			L(SNAP, 0.12, 1.6, { Delay = 0.62 })
		),
		MarksmanFire = recipe(
			L(SNAP, 0.5, 0.9, { Effects = { EQ = LOW_BOOST } }),
			pew(0.2, 2.1, 0.8, 0.14, { Effects = { Echo = SLAP } }),
			whoosh(0.1, 1.6, 0.5, 0.3)
		),
		RapidFire = recipe(L(CLICK, 0.28, 1.6), L(SNAP, 0.16, 2.5), pew(0.08, 3.4, 2.2, 0.04)),
		PlasmaFire = recipe(
			whoosh(0.5, 2.2, 0.5, 0.3, { Effects = { Flange = WOBBLE } }),
			pew(0.3, 1.2, 0.3, 0.3, { Effects = { Distortion = 0.5 } }),
			L(BUTTON, 0.22, 0.4),
			L(SNAP, 0.25, 0.4, { Effects = { EQ = LOW_BOOST } })
		),
		ChargeFire = recipe(
			pew(0.5, 2.8, 0.35, 0.35, { Effects = { Distortion = 0.75 } }),
			L(SNAP, 0.35, 0.4, { Effects = { EQ = LOW_BOOST, Reverb = BIG_ROOM } }),
			whoosh(0.35, 2.5, 0.4, 0.5)
		),
		ArcFire = recipe(
			pew(0.24, 3.5, 1.6, 0.06, { Effects = { Distortion = 0.85, Tremolo = { Depth = 1, Frequency = 40 } } }),
			L(CLICK, 0.12, 3),
			L(CLICK, 0.08, 2.4, { Delay = 0.03 })
		),
		BeamFire = recipe(L(CLICK, 0.1, 2.2, { Effects = { Flange = WOBBLE } })),
		SidearmFire = recipe(L(SNAP, 0.4, 2.1), L(SNAP, 0.14, 1.1, { Effects = { EQ = CRUNCH } }), pew(0.12, 2.8, 1.5, 0.06)),
		CometFire = recipe(
			L(SNAP, 0.55, 0.6, { Effects = { Distortion = 0.35, Reverb = SMALL_ROOM, EQ = LOW_BOOST } }),
			pew(0.2, 1.9, 0.6, 0.16),
			whoosh(0.12, 1.4, 0.4, 0.35, { Effects = { Reverb = BIG_ROOM } })
		),
		FlickFire = recipe(L(CLICK, 0.26, 1.8), L(SNAP, 0.14, 2.7), pew(0.07, 3.2, 2, 0.04)),

		-- Loops (started/stopped by WeaponController).
		BeamLoop = recipe(
			L(CLICK, 0.12, 2.6, { Looped = true, Effects = { Flange = WOBBLE } }),
			L(WIND, 0.14, 2.2, { Looped = true, Effects = { Tremolo = { Depth = 0.6, Frequency = 14 } } }),
			L(PING, 0.05, 0.6, { Looped = true, Effects = { Chorus = SHIMMER } })
		),
		ChargeLoop = recipe(
			L(PING, 0.16, 0.5, { Looped = true, Effects = { Chorus = SHIMMER } }),
			L(WIND, 0.1, 1, { Looped = true, Effects = { EQ = AIR } })
		),
		ChargeReady = recipe(L(PING, 0.35, 2), L(PING, 0.2, 2.6, { Delay = 0.05 })),

		-- Reload stages (played in sync with the viewmodel animation).
		Reload = recipe(L(CLICK, 0.2, 0.9), whoosh(0.06, 1.5, 1, 0.15)),
		MagOut = recipe(L(CLICK, 0.35, 0.8), L(BUTTON, 0.2, 0.55, { Delay = 0.03 })),
		MagIn = recipe(L(SNAP, 0.32, 1.3), L(CLICK, 0.28, 1.05, { Delay = 0.04 })),
		ReloadIn = recipe(L(SNAP, 0.25, 1.6), L(CLICK, 0.3, 1.4, { Delay = 0.06 }), L(BUTTON, 0.15, 1.6, { Delay = 0.12 })),
		Equip = recipe(L(BUTTON, 0.24, 1.3), whoosh(0.1, 1.2, 2, 0.2), L(CLICK, 0.18, 1.6, { Delay = 0.12 })),
		DryFire = recipe(L(CLICK, 0.3, 0.5)),
		Inspect = recipe(whoosh(0.12, 0.9, 1.5, 0.4), L(CLICK, 0.12, 1.2, { Delay = 0.35 }), L(CLICK, 0.1, 1.5, { Delay = 1.2 })),
		Casing = recipe(L(CLICK, 0.06, 3.2, { Delay = 0.35 }), L(CLICK, 0.04, 3.6, { Delay = 0.48 })),

		-- Impacts / explosions.
		Explosion = recipe(
			L(SNAP, 0.6, 0.3, { Effects = { EQ = LOW_BOOST, Distortion = 0.5 } }),
			L(SPLASH, 0.45, 0.55, { Effects = { Distortion = 0.6 } }),
			whoosh(0.5, 1.6, 0.25, 1.0, { Effects = { Reverb = BIG_ROOM, EQ = LOW_BOOST } }),
			pew(0.2, 0.9, 0.2, 0.6, { Effects = { Distortion = 0.6 } })
		),
		Impact = recipe(L(CLICK, 0.08, 2.2), L(SNAP, 0.04, 2.8)),
		Whiz = recipe(whoosh(0.3, 3, 1.1, 0.18, { Effects = { EQ = AIR } })),
		ProjectileHum = recipe(L(WIND, 0.25, 1.6, { Looped = true, Effects = { Flange = WOBBLE } })),

		--[[ Hit feedback ]]
		Hit = recipe(L(PING, 0.3, 1.55, { Fade = { After = 0.04, Time = 0.08 } }), L(CLICK, 0.12, 2.2)),
		Headshot = recipe(L(PING, 0.4, 2.3, { Fade = { After = 0.05, Time = 0.1 } }), L(PING, 0.25, 3, { Delay = 0.035 }), L(CLICK, 0.14, 3.2)),
		Elimination = {
			Layers = {
				L(SNAP, 0.25, 0.5, { Effects = { EQ = LOW_BOOST } }),
				L(PING, 0.38, 1.1),
				L(PING, 0.38, 1.4, { Delay = 0.07 }),
				L(PING, 0.42, 1.65, { Delay = 0.14, Effects = { Reverb = SMALL_ROOM } }),
			},
		},
		MultiElimination = arpeggio({ 1.4, 1.65, 2.1, 2.8 }, 0.4, 0.06),
		ShieldHit = recipe(L(PING, 0.2, 2.6, { Effects = { Chorus = SHIMMER }, Fade = { After = 0.05, Time = 0.1 } })),
		ShieldBreak = recipe(
			pew(0.4, 3.2, 0.9, 0.25, { Effects = { Chorus = SHIMMER } }),
			L(CLICK, 0.2, 2.6),
			L(CLICK, 0.16, 3.1, { Delay = 0.04 }),
			L(CLICK, 0.12, 2.2, { Delay = 0.08 })
		),
		Damaged = recipe(L(BUTTON, 0.35, 0.6, { Effects = { EQ = LOW_BOOST } }), L(SNAP, 0.12, 0.7)),
		LowHealth = recipe(L(BUTTON, 0.3, 0.4, { Effects = { EQ = LOW_BOOST } }), L(BUTTON, 0.22, 0.38, { Delay = 0.16, Effects = { EQ = LOW_BOOST } })),
		ShieldRecharge = recipe(whoosh(0.15, 0.8, 2, 0.5, { Effects = { Chorus = SHIMMER } }), L(PING, 0.15, 1.9, { Delay = 0.3 })),
		Respawn = recipe(whoosh(0.35, 0.5, 1.6, 0.6, { Effects = { Reverb = BIG_ROOM } }), L(PING, 0.25, 1.6, { Delay = 0.25 })),
		ProtectionEnd = recipe(L(PING, 0.15, 0.9)),

		--[[ Movement ]]
		Jump = recipe(L(JUMP, 0.22, 1.1), whoosh(0.05, 1, 1.5, 0.15)),
		DoubleJump = recipe(whoosh(0.28, 1, 2.4, 0.22), pew(0.08, 1.5, 2.5, 0.12)),
		WallJump = recipe(L(SNAP, 0.25, 1.2), whoosh(0.28, 1.2, 2.2, 0.2)),
		Land = recipe(L(LAND, 0.3, 1)),
		HeavyLand = recipe(L(LAND, 0.45, 0.7), L(SNAP, 0.22, 0.45, { Effects = { EQ = LOW_BOOST } }), whoosh(0.1, 0.8, 0.4, 0.3)),
		Slide = recipe(whoosh(0.3, 1.4, 0.8, 0.7), L(SPLASH, 0.08, 1.8, { Effects = { Flange = WOBBLE }, Fade = { After = 0.3, Time = 0.3 } })),
		Footstep = recipe(L(STEP, 0.14, 1)),
		Dash = recipe(whoosh(0.5, 0.8, 2.6, 0.25), L(SWOOSH, 0.25, 1.5), pew(0.06, 1.2, 2.4, 0.15)),
		JumpPad = recipe(whoosh(0.45, 0.6, 2.2, 0.45), L(PING, 0.22, 0.8, { Effects = { Echo = SPACE } })),
		GravityEnter = recipe(whoosh(0.25, 0.9, 0.4, 0.5, { Effects = { Chorus = SHIMMER } })),

		--[[ Abilities ]]
		Phase = recipe(whoosh(0.35, 1.8, 0.6, 0.5, { Effects = { Chorus = SHIMMER, Flange = WOBBLE } }), L(PING, 0.18, 0.6)),
		PhaseEnd = recipe(whoosh(0.18, 0.6, 1.4, 0.3)),
		Shield = recipe(L(PING, 0.4, 0.8, { Effects = { Reverb = BIG_ROOM } }), whoosh(0.25, 0.5, 1.2, 0.35), L(SNAP, 0.15, 0.6)),
		Decoy = recipe(L(PING, 0.35, 1.3), L(PING, 0.2, 1.8, { Delay = 0.06, Effects = { Chorus = SHIMMER } }), whoosh(0.12, 1.6, 0.8, 0.3)),
		DecoyPop = recipe(pew(0.28, 3, 1.4, 0.1), L(CLICK, 0.2, 1.5)),
		Pulse = recipe(pew(0.45, 1.2, 0.35, 0.8, { Effects = { Echo = SPACE } }), whoosh(0.3, 0.4, 1.4, 0.8)),
		PulseReveal = recipe(L(PING, 0.25, 2, { Effects = { Echo = SLAP } })),
		Gravity = recipe(whoosh(0.45, 1.6, 0.35, 0.8, { Effects = { Flange = WOBBLE } }), L(PING, 0.2, 0.3, { Effects = { Tremolo = { Depth = 0.8, Frequency = 6 } } })),
		AbilityReady = recipe(L(PING, 0.18, 1.8), L(PING, 0.12, 2.4, { Delay = 0.05 })),

		--[[ UI ]]
		UIHover = recipe(L(CLICK, 0.12, 1.7)),
		UIClick = recipe(L(BUTTON, 0.28, 1.2), L(CLICK, 0.08, 2)),
		UIBack = recipe(L(BUTTON, 0.3, 0.9)),
		Purchase = arpeggio({ 1.2, 1.6, 2.4 }, 0.38, 0.07),
		Error = recipe(L(BUTTON, 0.35, 0.5, { Effects = { Distortion = 0.3 } })),
		CosmeticEquip = recipe(L(PING, 0.3, 1.4), whoosh(0.08, 1, 1.8, 0.2)),
		LevelUp = {
			Layers = {
				L(PING, 0.45, 1.0),
				L(PING, 0.45, 1.25, { Delay = 0.08 }),
				L(PING, 0.45, 1.5, { Delay = 0.16 }),
				L(PING, 0.5, 2.0, { Delay = 0.24, Effects = { Reverb = BIG_ROOM } }),
				whoosh(0.3, 0.6, 1.8, 0.6, { Delay = 0.2 }),
			},
		},
		XP = recipe(L(BUTTON, 0.2, 1.8)),
		Countdown = recipe(L(PING, 0.4, 1, { Fade = { After = 0.15, Time = 0.2 } })),
		MatchStart = recipe(L(PING, 0.5, 1.4), L(PING, 0.4, 2.1, { Delay = 0.1 }), whoosh(0.35, 0.5, 2, 0.6, { Effects = { Reverb = BIG_ROOM } })),
		Victory = arpeggio({ 1, 1.25, 1.5, 2 }, 0.45, 0.12),
		Defeat = arpeggio({ 1.2, 1, 0.8 }, 0.35, 0.15),
		QueueJoin = recipe(L(PING, 0.3, 1.2), L(PING, 0.2, 1.6, { Delay = 0.06 })),
		Notify = recipe(L(PING, 0.25, 1.3)),

		--[[ Ambient loops per map ]]
		AmbientLobby = recipe(L(WIND, 0.05, 0.4, { Looped = true, Effects = { EQ = LOW_BOOST } })),
		AmbientNeon = recipe(L(WIND, 0.08, 0.35, { Looped = true, Effects = { EQ = LOW_BOOST, Flange = { Depth = 0.3, Rate = 0.2, Mix = 0.4 } } })),
		AmbientSky = recipe(L(WIND, 0.14, 0.6, { Looped = true })),
		AmbientCore = recipe(L(WIND, 0.1, 0.25, { Looped = true, Effects = { EQ = LOW_BOOST, Tremolo = { Depth = 0.5, Frequency = 1.2 } } })),
	},

	--[[
		Overrides: paste uploaded / Creator Store sound ids here to replace a
		recipe entirely, e.g.
		  PulseFire = { Id = "rbxassetid://123456789", Volume = 0.5, Pitch = 1 },
		Suggested Creator Store searches (Audio, filter "Roblox" or licensed SFX):
		  *Fire  -> "laser gun shot", "sci-fi blaster", "energy weapon"
		  Explosion -> "sci-fi explosion", Hit -> "hit marker", Elimination -> "kill confirm"
		  Dash -> "whoosh", Reload/MagOut/MagIn -> "gun reload", "magazine insert"
		  Ambient* -> "sci-fi city ambience", "wind loop", "reactor hum"
	]]
	Overrides = {},
}

return TableUtil.DeepFreeze(SoundConfig)
