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
