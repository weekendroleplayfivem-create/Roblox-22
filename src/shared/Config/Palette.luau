--!nonstrict
--[[
	Palette.luau
	The single source of truth for HYPER BLAST's colour language.

	Art direction rule that everything else follows:
		The WORLD is deep violet/indigo with cyan + magenta accents.
		PLAYERS are lit in high-contrast team colours that never appear in the
		environment, so an enemy silhouette can never be confused with a wall.

	If you add a new environment colour, keep it inside the `Environment` block
	and keep its value dark. Readability of enemies beats mood lighting.
--]]

local Palette = {}

-- Signature neon accents (used by abilities, trails, UI).
Palette.NeonCyan = Color3.fromRGB(0, 225, 255)
Palette.NeonBlue = Color3.fromRGB(60, 130, 255)
Palette.NeonPurple = Color3.fromRGB(170, 70, 255)
Palette.NeonMagenta = Color3.fromRGB(255, 60, 190)
Palette.NeonLime = Color3.fromRGB(120, 255, 160)
Palette.NeonAmber = Color3.fromRGB(255, 190, 60)

-- Environment: intentionally desaturated and dark so players pop.
Palette.Environment = {
	FloorBase = Color3.fromRGB(18, 16, 30),
	FloorAccent = Color3.fromRGB(26, 22, 44),
	Wall = Color3.fromRGB(22, 20, 36),
	WallTrim = Color3.fromRGB(34, 30, 56),
	Platform = Color3.fromRGB(28, 26, 46),
	Cover = Color3.fromRGB(32, 30, 52),
	Glass = Color3.fromRGB(90, 120, 190),
	Fog = Color3.fromRGB(10, 8, 22),
}

-- Team identity. Deliberately far apart in hue AND luminance.
Palette.Teams = {
	Cyan = {
		Name = "VOLT",
		Color = Color3.fromRGB(0, 220, 255),
		Accent = Color3.fromRGB(140, 245, 255),
		TeamColor = BrickColor.new("Electric blue"),
	},
	Magenta = {
		Name = "HEX",
		Color = Color3.fromRGB(255, 55, 170),
		Accent = Color3.fromRGB(255, 160, 220),
		TeamColor = BrickColor.new("Magenta"),
	},
}

-- Gameplay-state colours used by HUD + feedback systems.
Palette.State = {
	Health = Color3.fromRGB(90, 250, 210),
	HealthLow = Color3.fromRGB(255, 70, 90),
	Shield = Color3.fromRGB(90, 170, 255),
	Stamina = Color3.fromRGB(120, 210, 255),
	StaminaDrained = Color3.fromRGB(255, 120, 90),
	Ready = Color3.fromRGB(0, 235, 255),
	Cooldown = Color3.fromRGB(90, 95, 130),
	Hitmarker = Color3.fromRGB(255, 255, 255),
	HitmarkerHeadshot = Color3.fromRGB(255, 210, 80),
	HitmarkerKill = Color3.fromRGB(255, 70, 110),
	Objective = Color3.fromRGB(190, 120, 255),
}

--[[ Returns the team table for a Roblox Team instance, defaulting to Cyan. ]]
function Palette.forTeam(team: Team?)
	if team then
		for _, data in Palette.Teams do
			if data.Name == team.Name then
				return data
			end
		end
	end
	return Palette.Teams.Cyan
end

return Palette
