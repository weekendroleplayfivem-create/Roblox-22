--[[
	SettingsConfig
	Schema for player settings. The client UI is generated from this schema
	and the server sanitizes every incoming settings update with it, so a
	client can never save unexpected keys or out-of-range values.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local CrosshairColors = {
	White = Color3.fromRGB(255, 255, 255),
	Cyan = Color3.fromRGB(60, 230, 255),
	Green = Color3.fromRGB(120, 255, 140),
	Yellow = Color3.fromRGB(255, 230, 80),
	Pink = Color3.fromRGB(255, 110, 210),
	Red = Color3.fromRGB(255, 90, 90),
}

local Schema = {
	{ Key = "MouseSensitivity", Label = "Mouse Sensitivity", Type = "number", Min = 0.1, Max = 3, Step = 0.05, Default = 1 },
	{ Key = "GamepadSensitivity", Label = "Controller Sensitivity", Type = "number", Min = 0.2, Max = 3, Step = 0.1, Default = 1 },
	{ Key = "FieldOfView", Label = "Field of View", Type = "number", Min = 70, Max = 100, Step = 1, Default = 80 },
	{ Key = "CameraShake", Label = "Camera Shake", Type = "number", Min = 0, Max = 1, Step = 0.1, Default = 1 },
	{ Key = "ToggleSprint", Label = "Toggle Sprint", Type = "boolean", Default = false },
	{ Key = "ToggleAim", Label = "Toggle Aim", Type = "boolean", Default = false },
	{ Key = "CrosshairStyle", Label = "Crosshair Style", Type = "enum", Options = { "Cross", "Dot" }, Default = "Cross" }, -- Halo/Chevron are Shop cosmetics
	{ Key = "CrosshairColor", Label = "Crosshair Color", Type = "enum", Options = { "White", "Cyan", "Green", "Yellow", "Pink", "Red" }, Default = "White" },
	{ Key = "CrosshairSize", Label = "Crosshair Size", Type = "number", Min = 0.5, Max = 2, Step = 0.1, Default = 1 },
	{ Key = "MasterVolume", Label = "Master Volume", Type = "number", Min = 0, Max = 1, Step = 0.05, Default = 0.8 },
	{ Key = "ShowDamageNumbers", Label = "Damage Numbers", Type = "boolean", Default = true },
	{ Key = "ReducedEffects", Label = "Reduced Effects (performance)", Type = "boolean", Default = false },
	{ Key = "MobileButtonScale", Label = "Mobile Button Size", Type = "number", Min = 0.7, Max = 1.4, Step = 0.05, Default = 1 },
}

local SettingsConfig = {
	Schema = Schema,
	CrosshairColors = CrosshairColors,
}

function SettingsConfig.GetDefaults(): { [string]: any }
	local defaults = {}
	for _, entry in Schema do
		defaults[entry.Key] = entry.Default
	end
	return defaults
end

function SettingsConfig.GetEntry(key: string)
	for _, entry in Schema do
		if entry.Key == key then
			return entry
		end
	end
	return nil
end

-- Returns a sanitized value for `key` or nil when the input is invalid.
function SettingsConfig.SanitizeValue(key: string, value: any): any
	local entry = SettingsConfig.GetEntry(key)
	if not entry then
		return nil
	end
	if entry.Type == "number" then
		if type(value) ~= "number" or value ~= value then
			return nil
		end
		local clamped = math.clamp(value, entry.Min, entry.Max)
		return math.floor(clamped / entry.Step + 0.5) * entry.Step
	elseif entry.Type == "boolean" then
		if type(value) ~= "boolean" then
			return nil
		end
		return value
	elseif entry.Type == "enum" then
		if type(value) ~= "string" or not table.find(entry.Options, value) then
			return nil
		end
		return value
	end
	return nil
end

-- Sanitizes a whole settings table, dropping unknown keys and filling defaults.
function SettingsConfig.Sanitize(input: any): { [string]: any }
	local result = SettingsConfig.GetDefaults()
	if type(input) ~= "table" then
		return result
	end
	for key, value in input do
		if type(key) == "string" then
			local clean = SettingsConfig.SanitizeValue(key, value)
			if clean ~= nil then
				result[key] = clean
			end
		end
	end
	return result
end

return TableUtil.DeepFreeze(SettingsConfig)
