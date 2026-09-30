--!strict
-- All game audio. Roblox only ships a handful of built-in sounds, so the engine and tyre sounds
-- are synthesized from its wind-noise loop: pitched down, bass boosted, distorted and pulsed by a
-- tremolo at the engine's firing rate (it follows the simulated RPM and gear shifts). If you put
-- real audio ids in Config.Sounds (Engine / Skid / Siren), those are used instead.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Drive = require(script.Parent.DriveController)

local player = Players.LocalPlayer
local Sounds = {}
local S = Config.Sounds
local B = S.Builtin

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- One-shot sound. With a BasePart / Attachment parent it plays in 3D at that spot.
function Sounds.Play(id: string, volume: number?, pitch: number?, parent: Instance?): Sound?
	if id == "" then
		return nil
	end
	local s: Sound = new("Sound", { SoundId = id, Volume = volume or 0.5, PlaybackSpeed = pitch or 1, RollOffMaxDistance = 400 }, parent or SoundService)
	s:Play()
	Debris:AddItem(s, 5)
	return s
end

function Sounds.Tick(pitch: number?, volume: number?)
	Sounds.Play(B.Tick, volume or 0.45, pitch or 1)
end

-- Short burst of pitched-up wind: a whoosh.
function Sounds.Whoosh(pitch: number?, volume: number?)
	local s = Sounds.Play(B.Wind, volume or 0.8, pitch or 2.2)
	if s then
		task.delay(0.25, function()
			TweenService:Create(s, TweenInfo.new(0.3), { Volume = 0 }):Play()
		end)
	end
end

function Sounds.Explosion(position: Vector3, volume: number?, pitch: number?)
	local att = new("Attachment", { WorldPosition = position }, workspace.Terrain)
	Sounds.Play(B.Explosion, volume or 1, pitch or 1, att)
	Debris:AddItem(att, 5)
end

---------------------------------------------------------------------------
-- Engine synth
---------------------------------------------------------------------------
type Engine = {
	rumble: Sound,
	tremolo: TremoloSoundEffect?,
	distortion: DistortionSoundEffect?,
	whine: Sound?,
	synth: boolean,
}

local function makeEngine(parent: Instance, volume: number, withWhine: boolean): Engine
	local synth = S.Engine == ""
	local rumble: Sound = new("Sound", {
		Name = "EngineRumble",
		SoundId = if synth then B.Wind else S.Engine,
		Looped = true,
		Volume = volume,
		RollOffMaxDistance = 180,
		RollOffMinDistance = 12,
	}, parent)
	local e: Engine = { rumble = rumble, synth = synth }
	if synth then
		new("EqualizerSoundEffect", { LowGain = 10, MidGain = -3, HighGain = -32, Priority = 1 }, rumble)
		e.distortion = new("DistortionSoundEffect", { Level = 0.45, Priority = 2 }, rumble)
		e.tremolo = new("TremoloSoundEffect", { Depth = 0.75, Duty = 0.45, Frequency = 8, Priority = 3 }, rumble)
	end
	if withWhine then
		local whine: Sound = new("Sound", { Name = "EngineWhine", SoundId = B.Wind, Looped = true, Volume = 0, RollOffMaxDistance = 120 }, parent)
		new("EqualizerSoundEffect", { LowGain = -35, MidGain = 6, HighGain = -8 }, whine)
		e.whine = whine
		whine:Play()
	end
	rumble:Play()
	return e
end

local function setEngine(e: Engine, rpm: number, load: number, boost: boolean)
	if e.synth then
		e.rumble.PlaybackSpeed = 0.3 + rpm * 0.78
		e.rumble.Volume = (0.5 + 0.35 * load) * (if boost then 1.15 else 1)
		local trem = e.tremolo
		if trem then
			trem.Frequency = math.clamp(6 + rpm * 14, 0.1, 20)
			trem.Depth = 0.55 + 0.3 * (1 - rpm)
		end
		local dist = e.distortion
		if dist then
			dist.Level = 0.35 + 0.35 * load + (if boost then 0.15 else 0)
		end
	else
		e.rumble.PlaybackSpeed = 0.6 + rpm * 1.1
		e.rumble.Volume = 0.35 + 0.35 * load
	end
	local whine = e.whine
	if whine then
		whine.PlaybackSpeed = 0.9 + rpm * 1.4
		whine.Volume = 0.04 + 0.22 * rpm * load + (if boost then 0.15 else 0)
	end
end

local own: Engine? = nil
local ownCar: Model? = nil
local shiftDip = 0

-- wind, tyres and flat-tyre rattle are 2D (they belong to the listener's car)
local wind: Sound = new("Sound", { Name = "Wind", SoundId = B.Wind, Looped = true, Volume = 0 }, SoundService)
wind:Play()
local skid: Sound = new("Sound", { Name = "Skid", SoundId = if S.Skid ~= "" then S.Skid else B.Wind, Looped = true, Volume = 0, PlaybackSpeed = if S.Skid ~= "" then 1 else 2.6 }, SoundService)
if S.Skid == "" then
	new("EqualizerSoundEffect", { LowGain = -40, MidGain = -4, HighGain = 9 }, skid)
end
skid:Play()
local rattle: Sound = new("Sound", { Name = "FlatRattle", SoundId = B.Rattle, Looped = true, Volume = 0 }, SoundService)
rattle:Play()

table.insert(Drive.OnShift, function(_gear: number)
	shiftDip = 0.14
	Sounds.Play(B.Explosion, 0.06, 3.2)
end)

table.insert(Drive.OnBackfire, function()
	local car = Drive.Car
	local root = car and car.PrimaryPart
	local exhaust = root and root:FindFirstChild("Exhaust")
	for k = 1, math.random(1, 3) do
		task.delay((k - 1) * 0.09, function()
			Sounds.Play(B.Explosion, 0.14, 2.6 + math.random() * 0.8, exhaust)
			local flame = exhaust and exhaust:FindFirstChild("NitroFlame")
			if flame and flame:IsA("ParticleEmitter") then
				flame:Emit(6)
			end
		end)
	end
end)

table.insert(Drive.OnCrash, function(strength: number)
	Sounds.Play(B.Thud, 0.6 + strength * 0.8, 0.55 + math.random() * 0.15)
	if strength > 0.75 then
		Sounds.Play(B.Explosion, 0.25, 1.8)
	end
end)

table.insert(Drive.OnNearMiss, function(combo: number)
	Sounds.Whoosh(2 + math.min(combo, 8) * 0.08, 0.9)
end)

-- wrecked cops, pursuit breakers: any explosion in the world makes a bang
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Explosion") then
		Sounds.Explosion(child.Position, 1, 0.9 + math.random() * 0.2)
	end
end)

player:GetAttributeChangedSignal("RaceCP"):Connect(function()
	local cp = player:GetAttribute("RaceCP")
	if type(cp) == "number" and cp > 0 then
		Sounds.Tick(1.6, 0.6)
		task.delay(0.1, Sounds.Tick, 2, 0.6)
	end
end)

---------------------------------------------------------------------------
-- Other cars nearby get a 3D engine (the closest few only)
---------------------------------------------------------------------------
local others: { [Model]: Engine } = {}
local MAX_OTHERS = 8
local scanTimer = 0

local function scanOthers(camPos: Vector3)
	local list: { { model: Model, dist: number } } = {}
	for _, folderName in { "Cars", "Police", "Traffic", "Races" } do
		local folder = workspace:FindFirstChild(folderName)
		if not folder then
			continue
		end
		local function consider(m: Instance)
			if m:IsA("Model") and m.PrimaryPart and m ~= Drive.Car and m:FindFirstChild("BodyRoot") then
				local d = (m.PrimaryPart.Position - camPos).Magnitude
				if d < 170 then
					table.insert(list, { model = m, dist = d })
				end
			end
		end
		for _, m in folder:GetChildren() do
			if m:IsA("Folder") then
				for _, inner in m:GetChildren() do
					consider(inner)
				end
			else
				consider(m)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.dist < b.dist
	end)
	local keep: { [Model]: boolean } = {}
	for k = 1, math.min(MAX_OTHERS, #list) do
		keep[list[k].model] = true
	end
	for m, e in others do
		if not keep[m] or not m.Parent then
			e.rumble:Destroy()
			others[m] = nil
		end
	end
	for m in keep do
		if not others[m] then
			local root = m.PrimaryPart :: BasePart
			others[m] = makeEngine(root, 0.3, false)
		end
	end
end

---------------------------------------------------------------------------
-- Police sirens (only with a configured audio id)
---------------------------------------------------------------------------
local sirenTimer = 0
local function updateSirens()
	if S.Siren == "" then
		return
	end
	local police = workspace:FindFirstChild("Police")
	if not police then
		return
	end
	for _, m in police:GetChildren() do
		if m:IsA("Model") and m.PrimaryPart and m:GetAttribute("Police") then
			local snd = m.PrimaryPart:FindFirstChild("SirenLoop") :: Sound?
			if not snd then
				snd = new("Sound", { Name = "SirenLoop", SoundId = S.Siren, Looped = true, Volume = 0.4, RollOffMaxDistance = 350 }, m.PrimaryPart)
			end
			local s = snd :: Sound
			local on = m:GetAttribute("Siren") == true
			if on and not s.IsPlaying then
				s:Play()
			elseif not on and s.IsPlaying then
				s:Stop()
			end
		end
	end
end

---------------------------------------------------------------------------
-- Per frame
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt: number)
	local car = Drive.Car
	local root = car and car.PrimaryPart
	local inMenu = Drive.MenuOpen

	-- own engine follows the car you're driving
	if car ~= ownCar then
		if own then
			own.rumble:Destroy()
			if own.whine then
				(own.whine :: Sound):Destroy()
			end
			own = nil
		end
		ownCar = car
		if root then
			own = makeEngine(root, 0.6, true)
		end
	end

	local speed = Drive.Speed
	local e = own
	if e then
		shiftDip = math.max(0, shiftDip - dt)
		local load = math.max(Drive.Throttle, 0)
		setEngine(e, Drive.Rpm, load, Drive.NitroOn)
		if shiftDip > 0 then
			e.rumble.Volume *= 0.35
		end
		if inMenu then
			e.rumble.Volume *= 0.3
		end
	end

	-- wind rush grows with speed
	local windTarget = if inMenu or not root then 0 else math.clamp((speed - 40) / 220, 0, 0.55) + (if Drive.NitroOn then 0.15 else 0)
	wind.Volume += (windTarget - wind.Volume) * math.min(1, dt * 4)
	wind.PlaybackSpeed = 0.8 + math.clamp(speed / 300, 0, 0.6)

	-- tyre screech while sliding
	local slip = 0
	local state = Drive.State
	if state and state.grounded and root then
		slip = math.clamp((math.abs(state.lateral) - 10) / 30, 0, 1)
		if Drive.Handbrake and speed > 25 then
			slip = math.max(slip, 0.6)
		end
	end
	local skidTarget = slip * 0.5
	skid.Volume += (skidTarget - skid.Volume) * math.min(1, dt * 10)

	-- flat tyres rattle
	local flat = Drive.Flat and speed > 10
	rattle.Volume = if flat then 0.5 else 0
	rattle.PlaybackSpeed = 1 + math.clamp(speed / 60, 0, 3)

	-- nearby cars
	local camPos = workspace.CurrentCamera.CFrame.Position
	scanTimer += dt
	sirenTimer += dt
	if scanTimer > 0.5 then
		scanTimer = 0
		scanOthers(camPos)
	end
	if sirenTimer > 0.5 then
		sirenTimer = 0
		updateSirens()
	end
	for m, oe in others do
		local r = m.PrimaryPart
		if r then
			local spd = r.AssemblyLinearVelocity.Magnitude
			local max = m:GetAttribute("maxSpeed")
			local frac = math.clamp(spd / (if type(max) == "number" then max else 150), 0, 1)
			local band = (frac * 6) % 1
			setEngine(oe, 0.22 + 0.7 * band, if spd > 5 then 0.7 else 0.2, false)
			oe.rumble.Volume *= 0.45
		end
	end
end)

return Sounds
