--[[
	SoundController
	Plays sounds by key from SoundConfig. 2D UI/feedback sounds share a small
	pool; 3D sounds are attached to a temporary part at a world position.
	Master volume comes from Settings.
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
local templates: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local MIN_REPEAT_INTERVAL = 0.03

local function template(key: string): Sound?
	local existing = templates[key]
	if existing then
		return existing
	end
	local config = SoundConfig.Sounds[key]
	if not config or config.Id == "" then
		return nil -- PLACEHOLDER: no asset configured for this key
	end
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = config.Id
	sound.Volume = config.Volume
	sound.PlaybackSpeed = config.Pitch or 1
	sound.Looped = config.Looped == true
	sound.SoundGroup = soundGroup
	templates[key] = sound
	return sound
end

-- 2D sound (UI, local feedback). `pitchVariance` adds small random variation.
function SoundController:Play(key: string, pitchVariance: number?)
	local now = os.clock()
	if lastPlayed[key] and now - lastPlayed[key] < MIN_REPEAT_INTERVAL then
		return
	end
	lastPlayed[key] = now
	local base = template(key)
	if not base then
		return
	end
	local sound = base:Clone()
	if pitchVariance then
		sound.PlaybackSpeed *= 1 + (math.random() * 2 - 1) * pitchVariance
	end
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, sound.TimeLength > 0 and sound.TimeLength / sound.PlaybackSpeed + 0.1 or 3)
end

-- 3D positional sound.
function SoundController:PlayAt(key: string, position: Vector3, pitchVariance: number?)
	local base = template(key)
	if not base then
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
	local sound = base:Clone()
	sound.RollOffMaxDistance = 250
	sound.RollOffMinDistance = 10
	if pitchVariance then
		sound.PlaybackSpeed *= 1 + (math.random() * 2 - 1) * pitchVariance
	end
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 3)
end

local ambient: Sound? = nil
local ambientKey: string? = nil

-- Plays (or stops, with nil) a looping ambience track.
function SoundController:SetAmbient(key: string?)
	if key == ambientKey then
		return
	end
	ambientKey = key
	if ambient then
		ambient:Destroy()
		ambient = nil
	end
	local base = key and template(key)
	if base then
		local sound = base:Clone()
		sound.Looped = true
		sound.Parent = SoundService
		sound:Play()
		ambient = sound
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
