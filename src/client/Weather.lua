--!strict
-- Rain showers (the server decides when it rains; see workspace attribute "Raining").
-- Rain streaks follow the camera, the picture goes greyer, and you hear the rain.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.Settings)

local Weather = {}

local camera = workspace.CurrentCamera

local emitterPart = Instance.new("Part")
emitterPart.Name = "RainEmitter"
emitterPart.Anchored = true
emitterPart.CanCollide = false
emitterPart.CanQuery = false
emitterPart.CanTouch = false
emitterPart.Transparency = 1
emitterPart.Size = Vector3.new(160, 1, 160)

local rain = Instance.new("ParticleEmitter")
rain.Texture = "rbxasset://textures/particles/SquareParticle.png"
rain.Color = ColorSequence.new(Color3.fromRGB(200, 215, 235))
rain.Transparency = NumberSequence.new(0.35)
rain.LightInfluence = 1
rain.Size = NumberSequence.new(0.12)
rain.Squash = NumberSequence.new(2.6) -- stretched into streaks
rain.Lifetime = NumberRange.new(0.8, 1)
rain.Speed = NumberRange.new(90, 110)
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Rate = 0
rain.SpreadAngle = Vector2.new(4, 4)
rain.Parent = emitterPart

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "RainGrade"
grade.Enabled = true
grade.Saturation = 0
grade.Brightness = 0
grade.Parent = camera

local sound = Instance.new("Sound")
sound.Name = "Rain"
sound.SoundId = "rbxasset://sounds/action_falling.ogg"
sound.Looped = true
sound.Volume = 0
sound.PlaybackSpeed = 1.6
sound.SoundGroup = Settings.Master
local eq = Instance.new("EqualizerSoundEffect")
eq.LowGain = -30
eq.MidGain = -4
eq.HighGain = 6
eq.Parent = sound
sound.Parent = SoundService
sound:Play()

local raining = false
local function update()
	local now = workspace:GetAttribute("Raining") == true
	if now == raining then
		return
	end
	raining = now
	local info = TweenInfo.new(4)
	TweenService:Create(grade, info, { Saturation = if now then -0.25 else 0, Brightness = if now then -0.04 else 0, Contrast = if now then -0.05 else 0 }):Play()
	TweenService:Create(sound, info, { Volume = if now then 0.35 else 0 }):Play()
end
workspace:GetAttributeChangedSignal("Raining"):Connect(update)
update()

function Weather.IsRaining(): boolean
	return raining
end

RunService.RenderStepped:Connect(function()
	local cf = camera.CFrame
	emitterPart.CFrame = CFrame.new(cf.Position + cf.LookVector * 40 + Vector3.new(0, 45, 0))
	emitterPart.Parent = if raining then camera else nil
	rain.Rate = if raining then (if Settings.Values.performance then 150 else 400) else 0
end)

return Weather
