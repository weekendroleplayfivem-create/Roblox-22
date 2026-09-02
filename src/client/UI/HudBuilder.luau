--!nonstrict
--[[
	HudBuilder.luau
	Constructs the HUD's instance tree. Kept separate from HUDController so the
	controller file is about BEHAVIOUR and this one is about LAYOUT.

	Competitive HUD principles applied throughout:
		* The centre of the screen stays clean. Nothing but the crosshair and the
		  hitmarker is allowed near the point the player is actually looking at.
		* Information sits in the corners, sorted by how often you need it:
		  health + abilities bottom-left (glanceable), ammo bottom-right (glanceable),
		  score top-centre (occasional), minimap top-left (situational).
		* No animation on anything that isn't changing. Idle HUD motion is noise
		  competing with enemy motion.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Palette = require(Root.Config.Palette)

local HudBuilder = {}

local FONT = Enum.Font.GothamBold
local FONT_LIGHT = Enum.Font.Gotham

local function new(className: string, props, children)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

HudBuilder.new = new

local function label(props)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Font = props.Font or FONT,
		TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
		TextSize = props.TextSize or 18,
		Text = props.Text or "",
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Name = props.Name or "Label",
		ZIndex = props.ZIndex or 2,
		TextTransparency = props.TextTransparency or 0,
		Visible = props.Visible ~= false,
	})
end

HudBuilder.label = label

local function bar(name: string, color: Color3, size: UDim2, position: UDim2, anchor: Vector2)
	local container = new("Frame", {
		Name = name,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		BackgroundColor3 = Color3.fromRGB(10, 10, 18),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 3), Parent = container })

	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = container,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 3), Parent = fill })

	local stroke = new("UIStroke", {
		Color = color,
		Transparency = 0.6,
		Thickness = 1,
		Parent = container,
	})
	local _ = stroke

	return container, fill
end

----------------------------------------------------------------------
-- Root
----------------------------------------------------------------------

function HudBuilder.build(playerGui: PlayerGui)
	local gui = new("ScreenGui", {
		Name = "HyperBlastHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Parent = playerGui,
	})

	local refs = { Gui = gui }

	----------------------------------------------------------------
	-- Crosshair: four ticks + a centre dot. The gap is driven by the
	-- weapon's live spread, so the crosshair IS the spread readout.
	----------------------------------------------------------------
	local crosshair = new("Frame", {
		Name = "Crosshair",
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.Crosshair = crosshair
	refs.CrosshairTicks = {}

	local directions = {
		{ name = "Up", size = UDim2.fromOffset(2, 8), anchor = Vector2.new(0.5, 1), axis = Vector2.new(0, -1) },
		{ name = "Down", size = UDim2.fromOffset(2, 8), anchor = Vector2.new(0.5, 0), axis = Vector2.new(0, 1) },
		{ name = "Left", size = UDim2.fromOffset(8, 2), anchor = Vector2.new(1, 0.5), axis = Vector2.new(-1, 0) },
		{ name = "Right", size = UDim2.fromOffset(8, 2), anchor = Vector2.new(0, 0.5), axis = Vector2.new(1, 0) },
	}
	for _, direction in directions do
		local tick = new("Frame", {
			Name = direction.name,
			Size = direction.size,
			AnchorPoint = direction.anchor,
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = crosshair,
		})
		table.insert(refs.CrosshairTicks, { frame = tick, axis = direction.axis })
	end

	refs.CrosshairDot = new("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(2, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = crosshair,
	})

	----------------------------------------------------------------
	-- Hitmarker
	----------------------------------------------------------------
	local hitmarker = new("Frame", {
		Name = "Hitmarker",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.Hitmarker = hitmarker
	refs.HitmarkerStrokes = {}
	for index, rotation in { 45, -45, 135, -135 } do
		local stroke = new("Frame", {
			Name = `Mark{index}`,
			Size = UDim2.fromOffset(2, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = hitmarker,
		})
		-- Push each mark out along its own diagonal.
		stroke.Position = UDim2.new(0.5, math.cos(math.rad(rotation - 90)) * 9, 0.5, math.sin(math.rad(rotation - 90)) * 9)
		table.insert(refs.HitmarkerStrokes, stroke)
	end

	----------------------------------------------------------------
	-- Low-health vignette
	----------------------------------------------------------------
	refs.Vignette = new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.State.HealthLow,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = gui,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Palette.State.HealthLow),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.65, 1),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
		Parent = refs.Vignette,
	})

	----------------------------------------------------------------
	-- Bottom-left: health, stamina, abilities
	----------------------------------------------------------------
	local leftPanel = new("Frame", {
		Name = "LeftPanel",
		Size = UDim2.fromOffset(320, 130),
		Position = UDim2.new(0, 36, 1, -36),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	refs.HealthText = label({
		Name = "HealthText",
		Text = "100",
		TextSize = 34,
		TextColor3 = Palette.State.Health,
		Size = UDim2.fromOffset(90, 34),
		Position = UDim2.fromOffset(0, 42),
		Parent = leftPanel,
	})
	refs.HealthText.Parent = leftPanel

	local healthBar, healthFill = bar(
		"HealthBar",
		Palette.State.Health,
		UDim2.fromOffset(240, 10),
		UDim2.fromOffset(0, 84),
		Vector2.zero
	)
	healthBar.Parent = leftPanel
	refs.HealthBar, refs.HealthFill = healthBar, healthFill

	local staminaBar, staminaFill = bar(
		"StaminaBar",
		Palette.State.Stamina,
		UDim2.fromOffset(240, 5),
		UDim2.fromOffset(0, 100),
		Vector2.zero
	)
	staminaBar.Parent = leftPanel
	refs.StaminaBar, refs.StaminaFill = staminaBar, staminaFill

	-- Momentum readout. In a movement shooter your current speed is genuinely
	-- tactical information, so it gets real estate next to health.
	local momentumBar, momentumFill = bar(
		"MomentumBar",
		Palette.NeonPurple,
		UDim2.fromOffset(240, 3),
		UDim2.fromOffset(0, 110),
		Vector2.zero
	)
	momentumBar.Parent = leftPanel
	refs.MomentumBar, refs.MomentumFill = momentumBar, momentumFill

	refs.SpeedText = label({
		Name = "SpeedText",
		Text = "0",
		TextSize = 13,
		Font = FONT_LIGHT,
		TextColor3 = Palette.NeonPurple,
		Size = UDim2.fromOffset(120, 14),
		Position = UDim2.fromOffset(248, 104),
		Parent = leftPanel,
	})
	refs.SpeedText.Parent = leftPanel

	-- Ability row
	local abilityRow = new("Frame", {
		Name = "Abilities",
		Size = UDim2.fromOffset(240, 40),
		Position = UDim2.fromOffset(0, -6),
		BackgroundTransparency = 1,
		Parent = leftPanel,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = abilityRow,
	})
	refs.AbilitySlots = {}

	local abilityMeta = {
		{ id = "HyperDash", key = "Q", color = Palette.NeonCyan },
		{ id = "PhaseStep", key = "E", color = Palette.NeonPurple },
		{ id = "Overdrive", key = "F", color = Palette.NeonMagenta },
	}
	for order, meta in abilityMeta do
		local slot = new("Frame", {
			Name = meta.id,
			Size = UDim2.fromOffset(40, 40),
			LayoutOrder = order,
			BackgroundColor3 = Color3.fromRGB(12, 12, 22),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Parent = abilityRow,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = slot })
		local stroke = new("UIStroke", { Color = meta.color, Thickness = 1.5, Transparency = 0.2, Parent = slot })

		-- Cooldown "shade" fills from the bottom: readable at a glance in
		-- peripheral vision, which is where this HUD element actually lives.
		local shade = new("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 0),
			Position = UDim2.fromScale(0, 1),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromRGB(4, 4, 10),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = slot,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = shade })

		local keyLabel = label({
			Name = "Key",
			Text = meta.key,
			TextSize = 16,
			TextColor3 = meta.color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = slot,
		})
		keyLabel.Parent = slot

		local charges = label({
			Name = "Charges",
			Text = "",
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(34, 12),
			Position = UDim2.fromOffset(2, 24),
			ZIndex = 4,
			Parent = slot,
		})
		charges.Parent = slot

		refs.AbilitySlots[meta.id] = { frame = slot, shade = shade, stroke = stroke, charges = charges, color = meta.color }
	end

	----------------------------------------------------------------
	-- Bottom-right: ammo + weapon
	----------------------------------------------------------------
	local rightPanel = new("Frame", {
		Name = "RightPanel",
		Size = UDim2.fromOffset(260, 110),
		Position = UDim2.new(1, -36, 1, -36),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	refs.AmmoText = label({
		Name = "Ammo",
		Text = "30",
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(160, 46),
		Position = UDim2.fromOffset(60, 34),
		Parent = rightPanel,
	})
	refs.AmmoText.Parent = rightPanel

	refs.ReserveText = label({
		Name = "Reserve",
		Text = "/ 150",
		TextSize = 18,
		Font = FONT_LIGHT,
		TextColor3 = Color3.fromRGB(170, 175, 200),
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(60, 20),
		Position = UDim2.fromOffset(200, 58),
		Parent = rightPanel,
	})
	refs.ReserveText.Parent = rightPanel

	refs.WeaponText = label({
		Name = "WeaponName",
		Text = "PULSE-7",
		TextSize = 16,
		TextColor3 = Palette.NeonCyan,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(260, 18),
		Position = UDim2.fromOffset(0, 84),
		Parent = rightPanel,
	})
	refs.WeaponText.Parent = rightPanel

	local reloadBar, reloadFill = bar(
		"ReloadBar",
		Palette.NeonAmber,
		UDim2.fromOffset(160, 4),
		UDim2.fromOffset(100, 106),
		Vector2.zero
	)
	reloadBar.Visible = false
	reloadBar.Parent = rightPanel
	refs.ReloadBar, refs.ReloadFill = reloadBar, reloadFill

	----------------------------------------------------------------
	-- Top-centre: score + timer
	----------------------------------------------------------------
	local topPanel = new("Frame", {
		Name = "TopPanel",
		Size = UDim2.fromOffset(420, 56),
		Position = UDim2.new(0.5, 0, 0, 18),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	refs.TimerText = label({
		Name = "Timer",
		Text = "8:00",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(120, 26),
		Position = UDim2.fromOffset(150, 0),
		Parent = topPanel,
	})
	refs.TimerText.Parent = topPanel

	refs.ModeText = label({
		Name = "Mode",
		Text = "HYPER TEAM DEATHMATCH",
		TextSize = 12,
		Font = FONT_LIGHT,
		TextColor3 = Color3.fromRGB(150, 155, 185),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(420, 14),
		Position = UDim2.fromOffset(0, 28),
		Parent = topPanel,
	})
	refs.ModeText.Parent = topPanel

	refs.ScoreLeft = label({
		Name = "ScoreLeft",
		Text = "0",
		TextSize = 30,
		TextColor3 = Palette.Teams.Cyan.Color,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(130, 32),
		Position = UDim2.fromOffset(10, 0),
		Parent = topPanel,
	})
	refs.ScoreLeft.Parent = topPanel

	refs.ScoreRight = label({
		Name = "ScoreRight",
		Text = "0",
		TextSize = 30,
		TextColor3 = Palette.Teams.Magenta.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(130, 32),
		Position = UDim2.fromOffset(280, 0),
		Parent = topPanel,
	})
	refs.ScoreRight.Parent = topPanel

	----------------------------------------------------------------
	-- Objective strip (zones / core), under the score
	----------------------------------------------------------------
	refs.ObjectiveStrip = new("Frame", {
		Name = "Objectives",
		Size = UDim2.fromOffset(420, 26),
		Position = UDim2.new(0.5, 0, 0, 78),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = refs.ObjectiveStrip,
	})

	----------------------------------------------------------------
	-- Minimap (top-left)
	----------------------------------------------------------------
	local minimap = new("Frame", {
		Name = "Minimap",
		Size = UDim2.fromOffset(190, 190),
		Position = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.fromRGB(8, 8, 16),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = minimap })
	new("UIStroke", { Color = Palette.NeonPurple, Thickness = 1.5, Transparency = 0.35, Parent = minimap })
	refs.Minimap = minimap

	refs.MinimapWorld = new("Frame", {
		Name = "World",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = minimap,
	})

	refs.MinimapSelf = new("Frame", {
		Name = "Self",
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = minimap,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = refs.MinimapSelf })

	----------------------------------------------------------------
	-- Kill feed (top-right)
	----------------------------------------------------------------
	refs.KillFeed = new("Frame", {
		Name = "KillFeed",
		Size = UDim2.fromOffset(330, 140),
		Position = UDim2.new(1, -30, 0, 30),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = refs.KillFeed,
	})

	----------------------------------------------------------------
	-- Centre announcements + damage indicators + death overlay
	----------------------------------------------------------------
	refs.Announce = label({
		Name = "Announce",
		Text = "",
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(800, 48),
		Position = UDim2.fromScale(0.5, 0.32),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextTransparency = 1,
		Parent = gui,
	})
	refs.Announce.Parent = gui

	refs.DamageIndicators = new("Frame", {
		Name = "DamageIndicators",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	refs.DamageNumbers = new("Frame", {
		Name = "DamageNumbers",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	refs.DeathOverlay = new("Frame", {
		Name = "DeathOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 4, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	refs.DeathText = label({
		Name = "DeathText",
		Text = "",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(700, 30),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 21,
		Parent = refs.DeathOverlay,
	})
	refs.DeathText.Parent = refs.DeathOverlay

	----------------------------------------------------------------
	-- Scoreboard (Tab)
	----------------------------------------------------------------
	refs.Scoreboard = new("Frame", {
		Name = "Scoreboard",
		Size = UDim2.fromOffset(720, 460),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 8, 16),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = refs.Scoreboard })
	new("UIStroke", { Color = Palette.NeonPurple, Thickness = 1.5, Transparency = 0.4, Parent = refs.Scoreboard })

	refs.ScoreboardList = new("Frame", {
		Name = "List",
		Size = UDim2.new(1, -40, 1, -90),
		Position = UDim2.fromOffset(20, 70),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = refs.Scoreboard,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = refs.ScoreboardList,
	})

	local scoreboardTitle = label({
		Name = "Title",
		Text = "HYPER BLAST",
		TextSize = 22,
		TextColor3 = Palette.NeonCyan,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 22),
		ZIndex = 31,
		Parent = refs.Scoreboard,
	})
	scoreboardTitle.Parent = refs.Scoreboard

	return refs
end

return HudBuilder
