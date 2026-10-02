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
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundConfig = require(Shared.Config.SoundConfig)
local RaycastUtil = require(Shared.Modules.RaycastUtil)

local ClientState = require(script.Parent.ClientState)

local SoundController = {}

local soundGroup: SoundGroup
local templates: { [string]: { { Sound: Sound, Delay: number } } } = {}
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
	local config = SoundConfig.Sounds[key]
	local list = {}
	if config then
		-- Older single-layer form { Id, Volume, Pitch } is also accepted.
		local layers = config.Layers or { config }
		for index, layer in layers do
			local sound = buildLayer(key, index, layer)
			if sound then
				table.insert(list, { Sound = sound, Delay = layer.Delay or 0 })
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

local function spawnLayers(key: string, parent: Instance, pitchVariance: number?, volumeScale: number?)
	local variance = if pitchVariance then 1 + (math.random() * 2 - 1) * pitchVariance else 1
	for _, entry in getTemplates(key) do
		local sound = entry.Sound:Clone()
		sound.PlaybackSpeed *= variance
		sound.Volume *= volumeScale or 1
		sound.Parent = parent
		if entry.Delay > 0 then
			task.delay(entry.Delay, function()
				if sound.Parent then
					sound:Play()
				end
			end)
		else
			sound:Play()
		end
		Debris:AddItem(sound, lifetime(sound, entry.Delay))
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
	for _, entry in getTemplates(key) do
		local sound = entry.Sound:Clone()
		sound.RollOffMaxDistance = 260
		sound.RollOffMinDistance = 12
		sound.PlaybackSpeed *= if pitchVariance then 1 + (math.random() * 2 - 1) * pitchVariance else 1
		sound.Volume *= volumeScale or 1
		sound.Parent = holder
		if entry.Delay > 0 then
			task.delay(entry.Delay, function()
				if sound.Parent then
					sound:Play()
				end
			end)
		else
			sound:Play()
		end
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
