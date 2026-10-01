--[[
	CosmeticConfig
	Purely visual items bought with earned Credits. Cosmetics never change
	stats. Prices are always shown up-front; there are no random rewards.
]]

local TableUtil = require(script.Parent.Parent.Modules.TableUtil)

local Items = {
	-- Weapon skins (recolour the placeholder weapon model).
	Skin_Default = { Name = "Factory", Category = "WeaponSkin", Price = 0, Color = nil, Material = "SmoothPlastic" },
	Skin_Midnight = { Name = "Midnight", Category = "WeaponSkin", Price = 300, Color = Color3.fromRGB(30, 30, 50), Material = "SmoothPlastic" },
	Skin_Sunburst = { Name = "Sunburst", Category = "WeaponSkin", Price = 450, Color = Color3.fromRGB(255, 170, 40), Material = "SmoothPlastic" },
	Skin_NeonGlow = { Name = "Neon Glow", Category = "WeaponSkin", Price = 800, Color = Color3.fromRGB(80, 255, 220), Material = "Neon" },
	Skin_Glacier = { Name = "Glacier", Category = "WeaponSkin", Price = 600, Color = Color3.fromRGB(180, 230, 255), Material = "Glass", RequiredLevel = 5 },

	-- Movement trails (dash / slide).
	Trail_Default = { Name = "Cyan Streak", Category = "Trail", Price = 0, Color = Color3.fromRGB(60, 230, 255) },
	Trail_Ember = { Name = "Ember", Category = "Trail", Price = 350, Color = Color3.fromRGB(255, 120, 40) },
	Trail_Rainbow = { Name = "Prism", Category = "Trail", Price = 900, Color = Color3.fromRGB(255, 80, 220), Rainbow = true, RequiredLevel = 8 },
	Trail_Lime = { Name = "Lime Zip", Category = "Trail", Price = 350, Color = Color3.fromRGB(150, 255, 80) },

	-- Elimination effects (colour of the dissolve burst on your eliminations).
	Elim_Default = { Name = "Pixel Pop", Category = "EliminationEffect", Price = 0, Color = Color3.fromRGB(255, 255, 255) },
	Elim_Confetti = { Name = "Confetti", Category = "EliminationEffect", Price = 500, Color = Color3.fromRGB(255, 200, 60), Rainbow = true },
	Elim_Void = { Name = "Void Fade", Category = "EliminationEffect", Price = 650, Color = Color3.fromRGB(150, 80, 255) },

	-- Player banners (shown on scoreboard rows and results).
	Banner_Default = { Name = "Standard", Category = "Banner", Price = 0, Color = Color3.fromRGB(40, 45, 70) },
	Banner_Aurora = { Name = "Aurora", Category = "Banner", Price = 250, Color = Color3.fromRGB(40, 140, 120) },
	Banner_Sunset = { Name = "Sunset", Category = "Banner", Price = 250, Color = Color3.fromRGB(170, 70, 90) },
	Banner_Royal = { Name = "Royal", Category = "Banner", Price = 400, Color = Color3.fromRGB(90, 60, 170), RequiredLevel = 3 },

	-- Crosshair styles (also selectable in Settings for free; these add colours).
	Cross_Default = { Name = "Classic", Category = "Crosshair", Price = 0, Style = "Cross", Color = Color3.fromRGB(255, 255, 255) },
	Cross_Dot = { Name = "Pinpoint", Category = "Crosshair", Price = 0, Style = "Dot", Color = Color3.fromRGB(120, 255, 160) },
	Cross_Circle = { Name = "Halo", Category = "Crosshair", Price = 200, Style = "Circle", Color = Color3.fromRGB(255, 220, 80) },
	Cross_Chevron = { Name = "Chevron", Category = "Crosshair", Price = 200, Style = "Chevron", Color = Color3.fromRGB(255, 120, 220) },

	-- Emotes (PLACEHOLDER: procedural spin/hop until animation assets exist).
	Emote_Wave = { Name = "Wave", Category = "Emote", Price = 0, Motion = "Hop" },
	Emote_Spin = { Name = "Spin", Category = "Emote", Price = 300, Motion = "Spin" },
}

local Categories = { "WeaponSkin", "Trail", "EliminationEffect", "Banner", "Crosshair", "Emote" }

local CategoryNames = {
	WeaponSkin = "Weapon Skins",
	Trail = "Trails",
	EliminationEffect = "Elimination FX",
	Banner = "Banners",
	Crosshair = "Crosshairs",
	Emote = "Emotes",
}

local Defaults = {
	WeaponSkin = "Skin_Default",
	Trail = "Trail_Default",
	EliminationEffect = "Elim_Default",
	Banner = "Banner_Default",
	Crosshair = "Cross_Default",
	Emote = "Emote_Wave",
}

for id, item in Items do
	item.Id = id
	item.RequiredLevel = item.RequiredLevel or 1
end

local CosmeticConfig = {
	Items = Items,
	Categories = Categories,
	CategoryNames = CategoryNames,
	Defaults = Defaults,
}

function CosmeticConfig.Get(id: string)
	return Items[id]
end

function CosmeticConfig.IsFree(id: string): boolean
	local item = Items[id]
	return item ~= nil and item.Price == 0
end

return TableUtil.DeepFreeze(CosmeticConfig)
