--!strict
-- Shared visual language for every screen in Depths. Every UI script must pull
-- colors/fonts/spacing/motion from here rather than hardcoding literals - this
-- is what keeps the HUD, menus, and hub UI reading as one coherent game instead
-- of a stack of independently-styled screens.
--
-- Visual identity: "torchlit stone and old brass." The base palette is warm
-- charcoal stone with oxidized-brass accents (not the default Roblox
-- purple-blue gradient anywhere). Each biome then tints that base with its own
-- accent (see Data/Biomes/*) so the HUD subtly shifts hue as you descend
-- without ever breaking legibility - biome color is a tint on top of the base
-- readability palette, never a replacement for it.

local UIStyle = {}

UIStyle.Color = {
	-- Base surfaces - warm dark stone, never neutral/flat grey
	SurfaceDeep = Color3.fromRGB(21, 18, 16),
	SurfaceMid = Color3.fromRGB(34, 29, 25),
	SurfaceRaised = Color3.fromRGB(48, 41, 34),
	SurfaceBorder = Color3.fromRGB(74, 61, 46), -- oxidized brass edge, replaces default UIStroke grey

	-- Text
	TextPrimary = Color3.fromRGB(236, 226, 208),
	TextSecondary = Color3.fromRGB(176, 160, 138),
	TextMuted = Color3.fromRGB(120, 108, 94),

	-- Functional (semantic, biome-independent so health always reads as health)
	Health = Color3.fromRGB(196, 58, 52),
	HealthTrail = Color3.fromRGB(224, 138, 96), -- fading damage-trail segment, warmer/lighter than the health bar itself
	Resource = Color3.fromRGB(78, 142, 196),
	Experience = Color3.fromRGB(196, 158, 64),
	DangerTelegraph = Color3.fromRGB(224, 48, 48),
	Positive = Color3.fromRGB(120, 186, 96),

	-- Brass accent family - primary interactive color, replaces the generic
	-- purple/blue gradient ban from the anti-slop rules
	BrassBright = Color3.fromRGB(206, 158, 86),
	BrassDim = Color3.fromRGB(132, 98, 54),
}

-- Per-biome accent overlays. UI elements tagged with a biome context (floor
-- indicator, minimap frame, floor-transition banner) blend toward these rather
-- than swapping the whole palette, so cross-biome screens like the hub still
-- look like the same game.
UIStyle.BiomeAccent = {
	Crypt = Color3.fromRGB(122, 150, 168), -- cold crypt-blue
	FungalDepths = Color3.fromRGB(148, 92, 176), -- fungal green-violet
	MoltenForge = Color3.fromRGB(214, 96, 42), -- forge-orange
}

UIStyle.Rarity = require(script.Parent.Parent.Data.Rarity)

-- Fonts. Two-family system: a serif display face for headers/diegetic text
-- (reads as "carved/inscribed") and a clean grotesque for dense body/stat text
-- (inventory tooltips, damage numbers) where the display face would hurt
-- legibility at small sizes. Never the default Roblox system font throughout.
UIStyle.Font = {
	Display = Font.new("rbxasset://fonts/families/AccanthisADFStd.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
	BodyBold = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
	Numeric = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold), -- damage numbers, timers
}

-- 4px base spacing scale. Every UDim2/padding in the UI should be a multiple
-- of Unit, not an arbitrary literal, so spacing stays visually consistent
-- across screens authored by different passes.
UIStyle.Spacing = {
	Unit = 4,
	XS = 4,
	S = 8,
	M = 16,
	L = 24,
	XL = 40,
}

UIStyle.CornerRadius = {
	Small = UDim.new(0, 4),
	Medium = UDim.new(0, 8),
	-- Deliberately no "pill"/full-round default button shape - the anti-slop
	-- brief bans rounded-corner-frame as the default menu language, and a
	-- sharper corner reads more "carved stone panel" than "mobile app card."
}

-- Motion presets. Every tween in the game should reference one of these
-- rather than inlining EasingStyle/EasingDirection/Time, and nothing in the
-- game should use Enum.EasingStyle.Linear - it reads as an untuned prototype.
UIStyle.Motion = {
	PanelIn = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	PanelOut = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	ButtonHover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	ButtonPress = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	NumberPop = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), -- damage number pop/arc
	BarFill = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), -- health/resource bar catch-up
	BarTrailFill = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0.15), -- delayed trail chase
	CameraPunch = TweenInfo.new(0.15, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
}

-- Returns the biome-tinted variant of a base surface color for biome-context
-- UI elements. Blend factor kept low (0.12) so it reads as a tint, not a
-- palette swap - legibility (contrast against TextPrimary) always wins.
function UIStyle.TintForBiome(baseColor: Color3, biomeId: string): Color3
	local accent = UIStyle.BiomeAccent[biomeId]
	if not accent then
		return baseColor
	end
	return baseColor:Lerp(accent, 0.12)
end

return UIStyle
