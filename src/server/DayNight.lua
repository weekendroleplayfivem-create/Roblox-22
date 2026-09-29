--!strict
-- Realistic day/night lighting: sky, clouds, sun rays, depth of field and colour grading that
-- blends between night, dawn, day, golden hour and dusk. Street lamps and window lights switch
-- on at night.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DayNight = {}

type Key = {
	t: number,
	ambient: Color3,
	outdoor: Color3,
	brightness: number,
	exposure: number,
	atmoColor: Color3,
	atmoDecay: Color3,
	density: number,
	haze: number,
	tint: Color3,
	saturation: number,
	sunRays: number,
	bloom: number,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local NIGHT: Key = {
	t = 0,
	ambient = rgb(28, 28, 48),
	outdoor = rgb(62, 64, 105),
	brightness = 1.1,
	exposure = 0.25,
	atmoColor = rgb(120, 110, 190),
	atmoDecay = rgb(55, 40, 105),
	density = 0.36,
	haze = 1.9,
	tint = rgb(215, 215, 255),
	saturation = 0.28,
	sunRays = 0,
	bloom = 0.9,
}

local KEYS: { Key } = {
	NIGHT,
	{ t = 5.3, ambient = rgb(40, 36, 62), outdoor = rgb(92, 82, 122), brightness = 1.3, exposure = 0.15, atmoColor = rgb(200, 150, 175), atmoDecay = rgb(120, 70, 110), density = 0.34, haze = 1.7, tint = rgb(255, 228, 230), saturation = 0.2, sunRays = 0.05, bloom = 0.7 },
	{ t = 7, ambient = rgb(72, 62, 62), outdoor = rgb(155, 125, 112), brightness = 2.2, exposure = 0, atmoColor = rgb(255, 190, 150), atmoDecay = rgb(180, 110, 90), density = 0.3, haze = 1.2, tint = rgb(255, 236, 220), saturation = 0.15, sunRays = 0.16, bloom = 0.5 },
	{ t = 12, ambient = rgb(92, 92, 102), outdoor = rgb(142, 142, 152), brightness = 3, exposure = 0, atmoColor = rgb(199, 210, 230), atmoDecay = rgb(106, 120, 150), density = 0.27, haze = 0.6, tint = rgb(255, 255, 255), saturation = 0.1, sunRays = 0.08, bloom = 0.35 },
	{ t = 17.3, ambient = rgb(82, 66, 60), outdoor = rgb(165, 122, 100), brightness = 2.4, exposure = 0.02, atmoColor = rgb(255, 170, 120), atmoDecay = rgb(190, 100, 80), density = 0.3, haze = 1.3, tint = rgb(255, 226, 200), saturation = 0.2, sunRays = 0.22, bloom = 0.5 },
	{ t = 19, ambient = rgb(50, 40, 72), outdoor = rgb(102, 80, 132), brightness = 1.5, exposure = 0.15, atmoColor = rgb(220, 120, 170), atmoDecay = rgb(120, 60, 120), density = 0.34, haze = 1.8, tint = rgb(240, 215, 255), saturation = 0.25, sunRays = 0.1, bloom = 0.75 },
	{ t = 20.5, ambient = NIGHT.ambient, outdoor = NIGHT.outdoor, brightness = NIGHT.brightness, exposure = NIGHT.exposure, atmoColor = NIGHT.atmoColor, atmoDecay = NIGHT.atmoDecay, density = NIGHT.density, haze = NIGHT.haze, tint = NIGHT.tint, saturation = NIGHT.saturation, sunRays = NIGHT.sunRays, bloom = NIGHT.bloom },
}

local atmosphere: Atmosphere
local bloom: BloomEffect
local sunRays: SunRaysEffect
local cc: ColorCorrectionEffect

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function sample(time: number): (Key, Key, number)
	for k = 1, #KEYS do
		local a = KEYS[k]
		local b = KEYS[k + 1]
		if not b then
			-- wrap from the last key to midnight (next day)
			local span = 24 - a.t
			return a, KEYS[1], math.clamp((time - a.t) / span, 0, 1)
		end
		if time >= a.t and time < b.t then
			return a, b, (time - a.t) / (b.t - a.t)
		end
	end
	return KEYS[1], KEYS[1], 0
end

local function apply(time: number)
	local a, b, t = sample(time)
	-- smoothstep so transitions ease in and out
	t = t * t * (3 - 2 * t)
	Lighting.Ambient = a.ambient:Lerp(b.ambient, t)
	Lighting.OutdoorAmbient = a.outdoor:Lerp(b.outdoor, t)
	Lighting.Brightness = lerp(a.brightness, b.brightness, t)
	Lighting.ExposureCompensation = lerp(a.exposure, b.exposure, t)
	atmosphere.Color = a.atmoColor:Lerp(b.atmoColor, t)
	atmosphere.Decay = a.atmoDecay:Lerp(b.atmoDecay, t)
	atmosphere.Density = lerp(a.density, b.density, t)
	atmosphere.Haze = lerp(a.haze, b.haze, t)
	cc.TintColor = a.tint:Lerp(b.tint, t)
	cc.Saturation = lerp(a.saturation, b.saturation, t)
	sunRays.Intensity = lerp(a.sunRays, b.sunRays, t)
	bloom.Intensity = lerp(a.bloom, b.bloom, t)
end

local function clear(className: string)
	for _, c in Lighting:GetChildren() do
		if c.ClassName == className then
			c:Destroy()
		end
	end
end

function DayNight.Init(nightLights: { Light }, nightNeon: { BasePart })
	for _, cls in { "Atmosphere", "BloomEffect", "SunRaysEffect", "ColorCorrectionEffect", "DepthOfFieldEffect", "Sky" } do
		clear(cls)
	end
	Lighting.ClockTime = 20.5
	Lighting.GeographicLatitude = 35
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	local sky = Instance.new("Sky")
	sky.StarCount = 4000
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	atmosphere = Instance.new("Atmosphere")
	atmosphere.Offset = 0.1
	atmosphere.Glare = 0.4
	atmosphere.Parent = Lighting

	bloom = Instance.new("BloomEffect")
	bloom.Size = 28
	bloom.Threshold = 1.3
	bloom.Parent = Lighting

	sunRays = Instance.new("SunRaysEffect")
	sunRays.Spread = 0.6
	sunRays.Parent = Lighting

	cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.12
	cc.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 120
	dof.InFocusRadius = 220
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(220, 215, 235)
	clouds.Parent = terrain

	local lampsOn: boolean? = nil
	local function setNight(on: boolean)
		if lampsOn == on then
			return
		end
		lampsOn = on
		for _, l in nightLights do
			l.Enabled = on
		end
		for _, p in nightNeon do
			p.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			p.Transparency = if on then 0.25 else 0.55
		end
	end

	apply(Lighting.ClockTime)
	-- lamps come on a little before full night and stay on until after sunrise
	setNight(Lighting.ClockTime >= 18.3 or Lighting.ClockTime < 6.5)

	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / Config.DayLengthSeconds) % 24
			local time = Lighting.ClockTime
			apply(time)
			setNight(time >= 18.3 or time < 6.5)
		end
	end)
end

return DayNight
