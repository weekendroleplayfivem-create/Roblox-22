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

-- Natural palette: deep blue night lit by warm sodium street lamps, soft dawn, neutral midday,
-- warm golden hour and a short blue dusk.
local NIGHT: Key = {
	t = 0,
	ambient = rgb(20, 23, 32),
	outdoor = rgb(46, 52, 72),
	brightness = 1,
	exposure = 0.2,
	atmoColor = rgb(120, 132, 158),
	atmoDecay = rgb(48, 56, 80),
	density = 0.34,
	haze = 1.6,
	tint = rgb(222, 228, 255),
	saturation = 0.14,
	sunRays = 0,
	bloom = 0.65,
}

local KEYS: { Key } = {
	NIGHT,
	{ t = 5.3, ambient = rgb(38, 38, 52), outdoor = rgb(88, 86, 106), brightness = 1.3, exposure = 0.12, atmoColor = rgb(190, 165, 170), atmoDecay = rgb(110, 90, 110), density = 0.33, haze = 1.6, tint = rgb(250, 232, 232), saturation = 0.08, sunRays = 0.05, bloom = 0.5 },
	{ t = 7, ambient = rgb(70, 64, 62), outdoor = rgb(150, 130, 118), brightness = 2.2, exposure = 0, atmoColor = rgb(240, 200, 170), atmoDecay = rgb(170, 120, 100), density = 0.3, haze = 1.1, tint = rgb(255, 240, 225), saturation = 0.14, sunRays = 0.14, bloom = 0.35 },
	{ t = 12, ambient = rgb(92, 94, 100), outdoor = rgb(138, 140, 148), brightness = 3, exposure = 0, atmoColor = rgb(199, 212, 230), atmoDecay = rgb(106, 124, 150), density = 0.26, haze = 0.5, tint = rgb(255, 252, 246), saturation = 0.16, sunRays = 0.07, bloom = 0.25 },
	{ t = 17.3, ambient = rgb(84, 70, 62), outdoor = rgb(160, 126, 104), brightness = 2.4, exposure = 0.02, atmoColor = rgb(250, 185, 135), atmoDecay = rgb(180, 110, 85), density = 0.3, haze = 1.2, tint = rgb(255, 230, 205), saturation = 0.22, sunRays = 0.2, bloom = 0.35 },
	{ t = 19, ambient = rgb(40, 40, 60), outdoor = rgb(80, 82, 112), brightness = 1.4, exposure = 0.15, atmoColor = rgb(150, 140, 175), atmoDecay = rgb(80, 70, 110), density = 0.33, haze = 1.6, tint = rgb(232, 228, 255), saturation = 0.14, sunRays = 0.08, bloom = 0.55 },
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

export type Toggle = {
	part: BasePart,
	dayMaterial: Enum.Material,
	dayColor: Color3,
	nightMaterial: Enum.Material,
	nightColor: Color3,
}

function DayNight.Init(nightLights: { Light }, nightNeon: { BasePart }, toggles: { Toggle }?)
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
	cc.Contrast = 0.17
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
		-- building windows light up (not every building, not every colour)
		local list: { Toggle } = toggles or {}
		for _, tg in list do
			tg.part.Material = if on then tg.nightMaterial else tg.dayMaterial
			tg.part.Color = if on then tg.nightColor else tg.dayColor
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
