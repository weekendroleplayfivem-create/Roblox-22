--[[
	SoundController
	Plays sound RECIPES from SoundConfig: each key has one or more layers
	(pitch, delay, SoundEffects). Supports:
	  Play(key)            2D (UI / your own actions)
	  PlayAt(key, pos)     3D positional (other players, explosions)
	  StartLoop(key, parent?) -> handle with SetPitch / SetVolume / Stop
	  SetAmbient(key)      one looping ambience bed
	Master volume comes from Settings. Layer templates are built once and
	cloned, so playing sounds is cheap.

	Layer extras (see SoundConfig):
	  Sweep  { From, To, Time }   pitch glide - lasers "pew", risers, drops
	  Fade   { After, Time }      volume envelope to shorten long samples
	  Region { Start, Stop }      play only part of a sample
	3D sounds get distance muffling (high frequencies roll off with range),
	and SoundConfig.Overrides swaps any recipe for an uploaded asset id.
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundConfig = require(Shared.Config.SoundConfig)
local RaycastUtil = require(Shared.Modules.RaycastUtil)

local ClientState = require(script.Parent.ClientState)

local SoundController = {}

local soundGroup: SoundGroup
type Entry = { Sound: Sound, Delay: number, Layer: { [string]: any } }
local templates: { [string]: { Entry } } = {}
local lastPlayed: { [string]: number } = {}
local MIN_REPEAT_INTERVAL = 0.03
local DEFAULT_LIFETIME = 3

local EFFECT_BUILDERS = {
	Distortion = function(value)
		local effect = Instance.new("DistortionSoundEffect")
		effect.Level = value
		return effect
	end,
	Reverb = function(value)
		local effect = Instance.new("ReverbSoundEffect")
		effect.DecayTime = value.DecayTime or 1
		effect.WetLevel = value.WetLevel or -6
		return effect
	end,
	Echo = function(value)
		local effect = Instance.new("EchoSoundEffect")
		effect.Delay = value.Delay or 0.1
		effect.Feedback = value.Feedback or 0.3
		effect.WetLevel = value.WetLevel or -8
		return effect
	end,
	EQ = function(value)
		local effect = Instance.new("EqualizerSoundEffect")
		effect.LowGain = value.Low or 0
		effect.MidGain = value.Mid or 0
		effect.HighGain = value.High or 0
		return effect
	end,
	Flange = function(value)
		local effect = Instance.new("FlangeSoundEffect")
		effect.Depth = value.Depth or 0.5
		effect.Rate = value.Rate or 2
		effect.Mix = value.Mix or 0.5
		return effect
	end,
	Chorus = function(value)
		local effect = Instance.new("ChorusSoundEffect")
		effect.Depth = value.Depth or 0.4
		effect.Rate = value.Rate or 2
		effect.Mix = value.Mix or 0.5
		return effect
	end,
	Tremolo = function(value)
		local effect = Instance.new("TremoloSoundEffect")
		effect.Depth = value.Depth or 0.5
		effect.Frequency = value.Frequency or 5
		return effect
	end,
	Octave = function(value)
		local effect = Instance.new("PitchShiftSoundEffect")
		effect.Octave = value
		return effect
	end,
}

local function buildLayer(key: string, index: number, layer): Sound?
	if type(layer.Id) ~= "string" or layer.Id == "" then
		return nil -- PLACEHOLDER: no asset configured
	end
	local sound = Instance.new("Sound")
	sound.Name = key .. "_" .. index
	sound.SoundId = layer.Id
	sound.Volume = layer.Volume or 0.5
	sound.PlaybackSpeed = layer.Pitch or 1
	sound.Looped = layer.Looped == true
	sound.SoundGroup = soundGroup
	if layer.Region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(layer.Region.Start or 0, layer.Region.Stop or 60)
	end
	if layer.Effects then
		local priority = 0
		for effectName, value in layer.Effects do
			local builder = EFFECT_BUILDERS[effectName]
			if builder then
				local effect = builder(value)
				priority += 1
				effect.Priority = priority
				effect.Parent = sound
			end
		end
	end
	return sound
end

local function getTemplates(key: string)
	local existing = templates[key]
	if existing then
		return existing
	end
	local list = {}
	local override = SoundConfig.Overrides and SoundConfig.Overrides[key]
	if override and override.Id ~= "" then
		-- An uploaded asset replaces the recipe entirely.
		local sound = buildLayer(key, 1, override)
		if sound then
			table.insert(list, { Sound = sound, Delay = 0, Layer = override })
		end
		templates[key] = list
		return list
	end
	local config = SoundConfig.Sounds[key]
	if config then
		-- Older single-layer form { Id, Volume, Pitch } is also accepted.
		local layers = config.Layers or { config }
		for index, layer in layers do
			local sound = buildLayer(key, index, layer)
			if sound then
				table.insert(list, { Sound = sound, Delay = layer.Delay or 0, Layer = layer })
			end
		end
	end
	templates[key] = list
	return list
end

local function lifetime(sound: Sound, delay: number): number
	local length = if sound.TimeLength > 0 then sound.TimeLength / math.max(sound.PlaybackSpeed, 0.05) else DEFAULT_LIFETIME
	-- Reverb / echo tails need extra time.
	return delay + length + 1
end

-- Starts one cloned layer, applying its pitch sweep and fade envelope.
local function startLayer(sound: Sound, entry: Entry, variance: number)
	local layer = entry.Layer
	local function begin()
		if not sound.Parent then
			return
		end
		local sweep = layer.Sweep
		if sweep then
			sound.PlaybackSpeed = sweep.From * variance
			TweenService:Create(sound, TweenInfo.new(sweep.Time, sweep.Style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				PlaybackSpeed = sweep.To * variance,
			}):Play()
		end
		local fade = layer.Fade
		if fade then
			task.delay(fade.After or 0, function()
				if sound.Parent then
					TweenService:Create(sound, TweenInfo.new(fade.Time or 0.2), { Volume = 0 }):Play()
				end
			end)
		end
		sound:Play()
	end
	if entry.Delay > 0 then
		task.delay(entry.Delay, begin)
	else
		begin()
	end
end

local function spawnLayers(key: string, parent: Instance, pitchVariance: number?, volumeScale: number?)
	local variance = if pitchVariance then 1 + (math.random() * 2 - 1) * pitchVariance else 1
	for _, entry in getTemplates(key) do
		local sound = entry.Sound:Clone()
		sound.PlaybackSpeed *= variance
		sound.Volume *= volumeScale or 1
		sound.Parent = parent
		startLayer(sound, entry, variance)
		local fade = entry.Layer.Fade
		local life = if fade then entry.Delay + (fade.After or 0) + (fade.Time or 0.2) + 0.5 else lifetime(sound, entry.Delay)
		Debris:AddItem(sound, life)
	end
end

local function throttled(key: string): boolean
	local now = os.clock()
	if lastPlayed[key] and now - lastPlayed[key] < MIN_REPEAT_INTERVAL then
		return true
	end
	lastPlayed[key] = now
	return false
end

-- 2D sound (UI, your own actions). `pitchVariance` adds random variation.
function SoundController:Play(key: string, pitchVariance: number?, volumeScale: number?)
	if not key or throttled(key) then
		return
	end
	spawnLayers(key, SoundService, pitchVariance, volumeScale)
end

-- 3D positional sound.
function SoundController:PlayAt(key: string, position: Vector3, pitchVariance: number?, volumeScale: number?)
	if not key or throttled(key .. "@3d") then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.1
	holder.Position = position
	holder.Parent = RaycastUtil.GetContainer(RaycastUtil.Containers.Effects)
	-- Distance muffling: far-away shots lose their crack and sound "distant".
	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - position).Magnitude else 0
	local variance = if pitchVariance then 1 + (math.random() * 2 - 1) * pitchVariance else 1
	for _, entry in getTemplates(key) do
		local sound = entry.Sound:Clone()
		sound.RollOffMaxDistance = 320
		sound.RollOffMinDistance = 14
		sound.PlaybackSpeed *= variance
		sound.Volume *= volumeScale or 1
		if distance > 30 then
			local muffle = Instance.new("EqualizerSoundEffect")
			muffle.HighGain = -math.clamp((distance - 30) / 7, 0, 30)
			muffle.MidGain = -math.clamp((distance - 60) / 25, 0, 8)
			muffle.LowGain = 0
			muffle.Priority = 100
			muffle.Parent = sound
		end
		sound.Parent = holder
		startLayer(sound, entry, variance)
	end
	Debris:AddItem(holder, 4)
end

export type LoopHandle = {
	SetPitch: (self: LoopHandle, multiplier: number) -> (),
	SetVolume: (self: LoopHandle, multiplier: number) -> (),
	Stop: (self: LoopHandle) -> (),
}

-- Starts a looping recipe. `parent` (a BasePart) makes it 3D.
function SoundController:StartLoop(key: string, parent: Instance?)
	local sounds = {}
	for _, entry in getTemplates(key) do
		local sound = entry.Sound:Clone()
		sound.Looped = true
		sound.Parent = parent or SoundService
		sound:Play()
		table.insert(sounds, { Sound = sound, Pitch = sound.PlaybackSpeed, Volume = sound.Volume })
	end
	local handle = {}
	function handle:SetPitch(multiplier: number)
		for _, data in sounds do
			data.Sound.PlaybackSpeed = data.Pitch * multiplier
		end
	end
	function handle:SetVolume(multiplier: number)
		for _, data in sounds do
			data.Sound.Volume = data.Volume * multiplier
		end
	end
	function handle:Stop()
		for _, data in sounds do
			data.Sound:Destroy()
		end
		table.clear(sounds)
	end
	return handle
end

local ambientHandle = nil
local ambientKey: string? = nil

-- Plays (or stops, with nil) the looping ambience bed.
function SoundController:SetAmbient(key: string?)
	if key == ambientKey then
		return
	end
	ambientKey = key
	if ambientHandle then
		ambientHandle:Stop()
		ambientHandle = nil
	end
	if key then
		ambientHandle = SoundController:StartLoop(key)
	end
end

function SoundController:Init()
	soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = "VectorRushSFX"
	soundGroup.Parent = SoundService
end

function SoundController:Start()
	ClientState.Observe("Settings", function(settings)
		soundGroup.Volume = settings.MasterVolume or 0.8
	end)
end

return SoundController
