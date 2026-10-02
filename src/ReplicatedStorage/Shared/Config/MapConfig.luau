--[[
	MapConfig
	Metadata for each arena. Geometry is built by the matching ModuleScript in
	ServerStorage/Maps (procedural placeholder geometry - replace with
	hand-built models later; see README "Placeholder assets").
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local MapConfig = {
	Maps = {
		NeonDistrict = {
			DisplayName = "Neon District",
			Description = "Rooftops, alleys and a glowing central plaza.",
			Modes = { "TeamDeathmatch", "FreeForAll", "GunGame" },
			Ambient = "AmbientNeon", -- SoundConfig key (PLACEHOLDER: empty id = silent)
			Lighting = {
				ClockTime = 20.5,
				Ambient = Color3.fromRGB(40, 30, 70),
				OutdoorAmbient = Color3.fromRGB(70, 50, 110),
				FogColor = Color3.fromRGB(30, 15, 60),
				FogEnd = 900,
				Brightness = 1.5,
				Atmosphere = { Density = 0.32, Offset = 0.15, Color = Color3.fromRGB(160, 100, 230), Decay = Color3.fromRGB(80, 40, 140), Glare = 0.2, Haze = 1.6 },
				Grade = { TintColor = Color3.fromRGB(255, 240, 255), Saturation = 0.2, Contrast = 0.1, Brightness = 0 },
				Bloom = { Intensity = 0.9, Size = 26, Threshold = 1.05 },
				SunRays = { Intensity = 0 },
			},
		},
		SkyLab = {
			DisplayName = "Sky Lab",
			Description = "Floating research platforms linked by bridges and jump pads.",
			Modes = { "TeamDeathmatch", "FreeForAll", "GunGame" },
			Ambient = "AmbientSky",
			Lighting = {
				ClockTime = 14,
				Ambient = Color3.fromRGB(90, 110, 140),
				OutdoorAmbient = Color3.fromRGB(140, 160, 190),
				FogColor = Color3.fromRGB(170, 210, 255),
				FogEnd = 1200,
				Brightness = 2.5,
				Atmosphere = { Density = 0.22, Offset = 0.05, Color = Color3.fromRGB(200, 225, 255), Decay = Color3.fromRGB(120, 160, 230), Glare = 0.6, Haze = 1 },
				Grade = { TintColor = Color3.fromRGB(245, 250, 255), Saturation = 0.1, Contrast = 0.05, Brightness = 0.02 },
				Bloom = { Intensity = 0.5, Size = 20, Threshold = 1.4 },
				SunRays = { Intensity = 0.12, Spread = 0.6 },
			},
		},
		CoreStation = {
			DisplayName = "Core Station",
			Description = "Circular corridors around a pulsing energy reactor.",
			Modes = { "TeamDeathmatch", "FreeForAll", "GunGame" },
			Ambient = "AmbientCore",
			Lighting = {
				ClockTime = 0,
				Ambient = Color3.fromRGB(30, 50, 60),
				OutdoorAmbient = Color3.fromRGB(40, 70, 80),
				FogColor = Color3.fromRGB(10, 30, 40),
				FogEnd = 700,
				Brightness = 1,
				Atmosphere = { Density = 0.35, Offset = 0, Color = Color3.fromRGB(60, 140, 130), Decay = Color3.fromRGB(20, 60, 70), Glare = 0, Haze = 2 },
				Grade = { TintColor = Color3.fromRGB(225, 255, 250), Saturation = 0.15, Contrast = 0.12, Brightness = -0.02 },
				Bloom = { Intensity = 1, Size = 28, Threshold = 1 },
				SunRays = { Intensity = 0 },
			},
		},
	},
	Order = { "NeonDistrict", "SkyLab", "CoreStation" },

	-- Arenas are built far from the lobby so the two never overlap.
	ArenaOrigin = Vector3.new(0, 0, 2000),
	LobbyOrigin = Vector3.new(0, 0, 0),
	LobbyLighting = {
		ClockTime = 18,
		Ambient = Color3.fromRGB(60, 50, 90),
		OutdoorAmbient = Color3.fromRGB(100, 80, 140),
		FogColor = Color3.fromRGB(60, 40, 100),
		FogEnd = 1500,
		Brightness = 2,
		Atmosphere = { Density = 0.28, Offset = 0.1, Color = Color3.fromRGB(150, 110, 220), Decay = Color3.fromRGB(90, 50, 150), Glare = 0.1, Haze = 1.2 },
		Grade = { TintColor = Color3.fromRGB(255, 245, 255), Saturation = 0.15, Contrast = 0.08, Brightness = 0 },
		Bloom = { Intensity = 0.8, Size = 24, Threshold = 1.1 },
		SunRays = { Intensity = 0 },
	},
}

function MapConfig.Get(id: string)
	return MapConfig.Maps[id]
end

function MapConfig.SupportsMode(mapId: string, modeId: string): boolean
	local map = MapConfig.Maps[mapId]
	return map ~= nil and table.find(map.Modes, modeId) ~= nil
end

return TableUtil.DeepFreeze(MapConfig)
