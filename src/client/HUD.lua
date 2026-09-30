--!strict
-- Heads-up display, racing-game style:
--   top left     wallet card (cash, unbanked, bounty, REP, day/night)
--   top centre   heat stars + pursuit / cooldown / bust meters
--   bottom right analog speedometer with an LED tachometer ring, gear and nitrous
--   bottom left  round radar
--   right        race panel with live standings
--   centre       countdown, drift combo and slide-in notifications
--   bottom       context prompt with a key badge

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapDraw = require(script.Parent.MapDraw)
local Settings = require(script.Parent.Settings)
local Input = require(script.Parent.Input)
local Scale = require(script.Parent.Scale)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local HUD = {}

local C = Theme.Colors
local F = Theme.Fonts
local new = Theme.new
local label = Theme.Label

local gui = new("ScreenGui", { Name = "WantedUnboundHUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
HUD.Gui = gui

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted, k = s, 0
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end
HUD.Commas = commas

local function num(name: string): number
	local v = player:GetAttribute(name)
	return if type(v) == "number" then v else 0
end

---------------------------------------------------------------------------
-- Wallet card (top left, below the Roblox buttons)
---------------------------------------------------------------------------
local wallet = new("Frame", { Position = UDim2.fromOffset(16, 62), Size = UDim2.fromOffset(300, 150) }, gui)
Theme.Panel(wallet, C.Gold)
label({ Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(120, 14), Text = "CASH", FontFace = F.Heading, TextColor3 = C.Dim }, wallet)
local cashLabel = label({ Position = UDim2.fromOffset(14, 24), Size = UDim2.new(1, -28, 0, 34), Text = "$0", FontFace = F.Display, TextColor3 = C.Green }, wallet)
local unbankedChip = new("Frame", { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 24), BackgroundColor3 = Color3.fromRGB(60, 36, 12), BackgroundTransparency = 0.2 }, wallet)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, unbankedChip)
local unbankedLabel = label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -90, 1, -8), Text = "UNBANKED $0", FontFace = F.Heading, TextColor3 = C.Orange }, unbankedChip)
local riskTag = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(70, 16), Text = "AT RISK", FontFace = F.Heading, TextColor3 = C.Red, TextXAlignment = Enum.TextXAlignment.Right }, unbankedChip)
local bountyLabel = label({ Position = UDim2.fromOffset(16, 94), Size = UDim2.new(1, -32, 0, 16), Text = "", FontFace = F.Body, TextColor3 = Color3.fromRGB(255, 140, 140) }, wallet)
local repBadge = new("Frame", { Position = UDim2.fromOffset(14, 118), Size = UDim2.fromOffset(62, 22), BackgroundColor3 = C.Purple }, wallet)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, repBadge)
local repLabel = label({ Size = UDim2.fromScale(1, 1), Text = "REP 1", FontFace = F.Heading, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(20, 12, 40) }, repBadge)
new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, repBadge)
local repFill = Theme.Bar(wallet, { Position = UDim2.fromOffset(84, 126), Size = UDim2.new(1, -196, 0, 7) }, C.Purple)
local timeChip = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 118), Size = UDim2.fromOffset(96, 22), BackgroundColor3 = C.PanelLight }, wallet)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, timeChip)
local timeLabel = label({ Size = UDim2.fromScale(1, 1), Text = "DAY", FontFace = F.Heading, TextXAlignment = Enum.TextXAlignment.Center }, timeChip)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, timeChip)

---------------------------------------------------------------------------
-- Heat (top centre)
---------------------------------------------------------------------------
local heatFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(360, 110), BackgroundTransparency = 1 }, gui)
local starPill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(250, 46) }, heatFrame)
Theme.Panel(starPill, C.Red, 23)
local stars: { TextLabel } = {}
for k = 1, 5 do
	stars[k] = label({
		Position = UDim2.fromOffset(18 + (k - 1) * 44, 4),
		Size = UDim2.fromOffset(40, 38),
		Text = "★",
		FontFace = F.Heading,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(60, 62, 80),
	}, starPill)
end
local statusLabel = label({ Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 20), Text = "", FontFace = F.Heading, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 }, heatFrame)
local meterFill = Theme.Bar(heatFrame, { Position = UDim2.fromOffset(40, 78), Size = UDim2.new(1, -80, 0, 9), Visible = false }, C.Gold)
local meterBack = meterFill.Parent :: Frame
local bustFill = Theme.Bar(heatFrame, { Position = UDim2.fromOffset(40, 94), Size = UDim2.new(1, -80, 0, 7), Visible = false }, C.Red)
local bustBack = bustFill.Parent :: Frame

---------------------------------------------------------------------------
-- Speedometer (bottom right): dial with an LED tachometer ring
---------------------------------------------------------------------------
local DIAL = 230
local speedo = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -16), Size = UDim2.fromOffset(DIAL, DIAL + 50), BackgroundTransparency = 1 }, gui)
local dial = new("Frame", { Size = UDim2.fromOffset(DIAL, DIAL), BackgroundTransparency = 0.12 }, speedo)
Theme.Panel(dial, C.Cyan, DIAL)
local TICKS = 32
local ticks: { Frame } = {}
local centre = DIAL / 2
for k = 0, TICKS - 1 do
	local frac = k / (TICKS - 1)
	local angle = math.rad(135 + frac * 270)
	local major = k % 4 == 0
	local r = DIAL / 2 - (if major then 20 else 18)
	local t = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(centre + math.cos(angle) * r, centre + math.sin(angle) * r),
		Size = UDim2.fromOffset(if major then 5 else 3, if major then 18 else 12),
		Rotation = math.deg(angle) + 90,
		BackgroundColor3 = Color3.fromRGB(55, 60, 86),
		BorderSizePixel = 0,
	}, dial)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, t)
	ticks[k + 1] = t
end
local speedLabel = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -6), Size = UDim2.fromOffset(150, 60), Text = "0", FontFace = F.Display, TextXAlignment = Enum.TextXAlignment.Center }, dial)
local unitLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 26), Size = UDim2.fromOffset(80, 16), Text = "MPH", FontFace = F.Heading, TextColor3 = C.Cyan, TextXAlignment = Enum.TextXAlignment.Center }, dial)
local gearCircle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 48), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.PanelLight }, dial)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, gearCircle)
local gearStroke = new("UIStroke", { Color = C.Gold, Thickness = 2 }, gearCircle)
local gearLabel = label({ Size = UDim2.fromScale(1, 1), Text = "1", FontFace = F.Display, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center }, gearCircle)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, gearCircle)
local classChip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(120, 20), BackgroundColor3 = C.PanelLight }, dial)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, classChip)
local classLabel = label({ Size = UDim2.fromScale(1, 1), Text = "", FontFace = F.Heading, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim }, classChip)
new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, classChip)
-- nitrous under the dial
local nitroText = label({ Position = UDim2.fromOffset(4, DIAL + 6), Size = UDim2.fromOffset(150, 14), Text = "NITROUS", FontFace = F.Heading, TextColor3 = C.Cyan }, speedo)
local nitroFill = Theme.Bar(speedo, { Position = UDim2.fromOffset(0, DIAL + 24), Size = UDim2.new(1, 0, 0, 14) }, C.Cyan)
local nitroBack = nitroFill.Parent :: Frame
new("UIStroke", { Color = C.Cyan, Thickness = 1, Transparency = 0.6 }, nitroBack)
local burstMarks: { Frame } = {}
for k = 1, 2 do
	burstMarks[k] = new("Frame", { Position = UDim2.new(k / 3, -2, 0, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ZIndex = 3, Visible = false }, nitroBack)
end

function HUD.SetBurst(on: boolean)
	for _, m in burstMarks do
		m.Visible = on
	end
	nitroText.Text = if on then "BURST NITROUS" else "NITROUS"
end

local rpmNow = 0
function HUD.SetEngine(gear: number, rpm: number, reversing: boolean)
	gearLabel.Text = if reversing then "R" else tostring(gear)
	rpmNow = rpm
	local lit = math.floor(math.clamp(rpm, 0, 1) * TICKS + 0.5)
	for k, t in ticks do
		local frac = (k - 1) / (TICKS - 1)
		if k <= lit then
			t.BackgroundColor3 = if frac > 0.82 then C.Red elseif frac > 0.62 then C.Gold else C.Cyan
		else
			t.BackgroundColor3 = if frac > 0.82 then Color3.fromRGB(90, 34, 44) else Color3.fromRGB(55, 60, 86)
		end
	end
	local redline = rpm > 0.9
	gearLabel.TextColor3 = if redline then C.Red else C.Gold
	gearStroke.Color = if redline then C.Red else C.Gold
end

---------------------------------------------------------------------------
-- Weapon chip (above the speedometer)
---------------------------------------------------------------------------
local weaponFrame = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -(DIAL + 76)), Size = UDim2.fromOffset(DIAL, 44), Visible = false }, gui)
Theme.Panel(weaponFrame, C.Red, 12)
local weaponLabel = label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 16), Text = "", FontFace = F.Heading }, weaponFrame)
local weaponFill = Theme.Bar(weaponFrame, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 7) }, C.Red)

---------------------------------------------------------------------------
-- Race panel (right)
---------------------------------------------------------------------------
local racePanel = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 120), Size = UDim2.fromOffset(260, 300), Visible = false }, gui)
Theme.Panel(racePanel, C.Pink)
local raceName = label({ Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 18), Text = "", FontFace = F.Heading, TextColor3 = C.Pink }, racePanel)
local racePos = label({ Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -28, 0, 50), Text = "", FontFace = F.Display }, racePanel)
local raceInfo = label({ Position = UDim2.fromOffset(16, 90), Size = UDim2.new(1, -32, 0, 18), Text = "", FontFace = F.Body }, racePanel)
local raceTime = label({ Position = UDim2.fromOffset(16, 112), Size = UDim2.new(1, -32, 0, 16), Text = "", FontFace = F.Light, TextColor3 = C.Dim }, racePanel)
new("Frame", { Position = UDim2.fromOffset(16, 136), Size = UDim2.new(1, -32, 0, 1), BackgroundColor3 = C.Pink, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, racePanel)
local standings = label({ Position = UDim2.fromOffset(16, 144), Size = UDim2.new(1, -32, 0, 100), Text = "", FontFace = F.Body, TextScaled = false, TextSize = 16, TextYAlignment = Enum.TextYAlignment.Top, RichText = true }, racePanel)
local sideBetChip = new("Frame", { Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = Color3.fromRGB(60, 46, 10), BackgroundTransparency = 0.2, Visible = false }, racePanel)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, sideBetChip)
local sideBetLabel = label({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), Text = "", FontFace = F.Body, TextColor3 = C.Gold, TextWrapped = true }, sideBetChip)

---------------------------------------------------------------------------
-- Countdown + drift combo
---------------------------------------------------------------------------
local countdown = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(420, 170), Text = "", FontFace = F.Display, TextColor3 = C.Pink, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, Visible = false }, gui)
local countdownScale = new("UIScale", {}, countdown)
local lastCountdown = -1

local driftLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(420, 42), Text = "", FontFace = F.Display, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3 }, gui)
new("UIGradient", { Color = ColorSequence.new(C.Gold, C.Orange), Rotation = 90 }, driftLabel)

---------------------------------------------------------------------------
-- Notifications: pills that slide in under the heat meter
---------------------------------------------------------------------------
local notifyFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 184), Size = UDim2.fromOffset(560, 240), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }, notifyFrame)
local notifyOrder = 0

function HUD.Notify(text: string, color: Color3?)
	notifyOrder += 1
	local accent = color or C.Text
	local pill = new("Frame", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Panel, BackgroundTransparency = 0.15, LayoutOrder = notifyOrder }, notifyFrame)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
	new("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.4 }, pill)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, pill)
	local t = label({ Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextScaled = false, TextSize = 16, FontFace = F.Heading, TextColor3 = accent }, pill)
	local s = new("UIScale", { Scale = 0.6 }, pill)
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local kids = {}
	for _, c in notifyFrame:GetChildren() do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids > 5 then
		table.sort(kids, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	task.delay(4, function()
		if pill.Parent then
			local info = TweenInfo.new(0.5)
			TweenService:Create(pill, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(t, info, { TextTransparency = 1 }):Play()
			task.wait(0.5)
			pill:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Prompt with a key badge (bottom centre)
---------------------------------------------------------------------------
local promptButton = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = true, Visible = false }, gui)
Theme.Panel(promptButton, C.Pink, 25)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 22) }, promptButton)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12) }, promptButton)
local keyBadge = new("Frame", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Pink, LayoutOrder = 1 }, promptButton)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, keyBadge)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, keyBadge)
local keyText = label({ Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Text = "E", TextScaled = false, TextSize = 18, FontFace = F.Display, TextXAlignment = Enum.TextXAlignment.Center }, keyBadge)
local promptText = label({ Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextScaled = false, TextSize = 18, FontFace = F.Heading, LayoutOrder = 2 }, promptButton)
local promptStroke = promptButton:FindFirstChildOfClass("UIStroke") :: UIStroke
HUD.PromptButton = promptButton

function HUD.SetPrompt(text: string?)
	if not text then
		promptButton.Visible = false
		return
	end
	-- split a leading key label like "[E]", "(B)" or "TAP" into the badge
	local key, rest = string.match(text, "^([%[%(].-[%]%)])%s+(.*)$")
	if not key then
		key, rest = string.match(text, "^(TAP)%s+(.*)$")
	end
	if key and rest then
		keyText.Text = (string.gsub(key, "[%[%]%(%)]", ""))
		promptText.Text = rest
		keyBadge.Visible = true
	else
		promptText.Text = text
		keyBadge.Visible = false
	end
	promptButton.Visible = true
end

-- device hint, bottom centre, fades after a while
local controlsLabel = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(900, 16), Text = "", TextScaled = false, TextSize = 13, FontFace = F.Light, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6 }, gui)
local hintToken = 0
local function refreshHint()
	hintToken += 1
	local token = hintToken
	controlsLabel.Text = Input.ControlsHint()
	controlsLabel.TextTransparency = 0
	task.delay(15, function()
		if token == hintToken then
			TweenService:Create(controlsLabel, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
		end
	end)
end
Input.OnChanged(refreshHint)
refreshHint()

---------------------------------------------------------------------------
-- Radar (bottom left). A CanvasGroup clips its content to the rounded corner.
---------------------------------------------------------------------------
local MAP_PX = 210
local RADAR_RANGE = 1200
local scale = MAP_PX / RADAR_RANGE
local radarHolder = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -24), Size = UDim2.fromOffset(MAP_PX, MAP_PX), BackgroundTransparency = 1 }, gui)
local minimap = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 12, 20) }, radarHolder)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, minimap)
local canvas: Frame = new("Frame", { Name = "Canvas", BackgroundTransparency = 1 }, minimap)
local canvasPx = MapDraw.Draw(canvas, scale, false)
-- ring + compass on top (outside the CanvasGroup so they stay crisp)
local ring = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, radarHolder)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
new("UIStroke", { Color = C.Pink, Thickness = 3, Transparency = 0.15 }, ring)
local vignette = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 8 }, minimap)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 0.5) }), Rotation = 90 }, vignette)
local northBadge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.Pink }, radarHolder)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, northBadge)
label({ Size = UDim2.fromScale(1, 1), Text = "N", FontFace = F.Heading, TextXAlignment = Enum.TextXAlignment.Center }, northBadge)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, northBadge)

local function toMap(pos: Vector3): UDim2
	local p = canvasPx(pos)
	return UDim2.fromOffset(p.X, p.Y)
end

local dotPool: { Frame } = {}
local dotsUsed = 0
local function dot(pos: Vector3, color: Color3, size: number)
	dotsUsed += 1
	local d = dotPool[dotsUsed]
	if not d then
		local nd: Frame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7, BorderSizePixel = 0 }, canvas)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, nd)
		dotPool[dotsUsed] = nd
		d = nd
	end
	d.Visible = true
	d.Position = toMap(pos)
	d.Size = UDim2.fromOffset(size, size)
	d.BackgroundColor3 = color
end

local arrow = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), Text = "▲", FontFace = F.Heading, TextColor3 = C.Cyan, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9, TextStrokeTransparency = 0 }, radarHolder)

---------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------
local blink = 0
function HUD.Update(dt: number, speed: number, nitro: number, capacity: number, nitroOn: boolean, car: Model?)
	blink += dt
	local shown, unit = Settings.Speed(speed, Config.MphPerStud)
	speedLabel.Text = tostring(math.floor(shown))
	unitLabel.Text = unit
	speedLabel.TextColor3 = if nitroOn then C.Cyan elseif rpmNow > 0.9 then Color3.fromRGB(255, 200, 200) else C.Text
	nitroFill.Size = UDim2.fromScale(math.clamp(nitro / math.max(capacity, 0.01), 0, 1), 1)
	nitroFill.BackgroundColor3 = if nitroOn then Color3.new(1, 1, 1) else C.Cyan
	if car then
		local rating = car:GetAttribute("rating")
		local class = car:GetAttribute("RatingClass")
		classLabel.Text = string.upper(tostring(car:GetAttribute("CarName") or "")) .. (if class then "  ·  " .. tostring(class) .. " " .. tostring(rating) else "")
	else
		classLabel.Text = ""
	end

	-- heat
	local heat = num("Heat")
	local mode = player:GetAttribute("PursuitMode") or "idle"
	local level = math.floor(heat)
	for k = 1, 5 do
		local lit = k <= level
		local color = Color3.fromRGB(60, 62, 80)
		if lit then
			if mode ~= "idle" then
				color = if (math.floor(blink * 4) + k) % 2 == 0 then C.Red else C.Blue
			else
				color = Color3.fromRGB(255, 90, 90)
			end
		end
		stars[k].TextColor3 = color
	end
	if mode == "pursuit" then
		statusLabel.Text = "PURSUIT  ·  LOSE THEM"
		statusLabel.TextColor3 = C.Red
		meterBack.Visible = true
		meterFill.BackgroundColor3 = C.Gold
		meterFill.Size = UDim2.fromScale(num("Evade"), 1)
	elseif mode == "cooldown" then
		statusLabel.Text = if player:GetAttribute("Hiding") then "COOLDOWN  ·  HIDING x3" else "COOLDOWN  ·  STAY OUT OF SIGHT"
		statusLabel.TextColor3 = C.Blue
		meterBack.Visible = true
		meterFill.BackgroundColor3 = C.Blue
		meterFill.Size = UDim2.fromScale(num("Cooldown"), 1)
	else
		statusLabel.Text = if level > 0 then "HEAT " .. level .. "  ·  BANK AT THE SAFEHOUSE TO CLEAR IT" else ""
		statusLabel.TextColor3 = Color3.fromRGB(255, 160, 160)
		meterBack.Visible = false
	end
	local bust = num("Bust")
	bustBack.Visible = bust > 0.01
	bustFill.Size = UDim2.fromScale(bust, 1)
	starPill.Visible = level > 0 or mode ~= "idle"

	-- wallet
	cashLabel.Text = "$" .. commas(num("Cash"))
	local unbanked = num("Unbanked")
	unbankedLabel.Text = "UNBANKED  $" .. commas(unbanked)
	riskTag.Visible = unbanked > 0 and math.floor(blink * 2) % 2 == 0
	local bounty = num("Bounty")
	bountyLabel.Text = if mode ~= "idle" then "Pursuit bounty  " .. commas(bounty) else "Total bounty  " .. commas(num("TotalBounty"))
	repLabel.Text = "REP " .. math.floor(num("RepLevel"))
	repFill.Size = UDim2.fromScale(math.clamp(num("RepProgress"), 0, 1), 1)
	local night = player:GetAttribute("Night") == true
	timeLabel.Text = if night then "☾ NIGHT x" .. Config.NightMultiplier else "☀ DAY"
	timeLabel.TextColor3 = if night then C.Purple else C.Gold

	-- weapon
	local weaponId = player:GetAttribute("Weapon")
	local weaponDef = if type(weaponId) == "string" and weaponId ~= "" then Config.GetWeapon(weaponId) else nil
	weaponFrame.Visible = weaponDef ~= nil
	if weaponDef then
		local left = num("WeaponReadyAt") - workspace:GetServerTimeNow()
		local ready = left <= 0
		weaponLabel.Text = string.upper(weaponDef.name) .. (if ready then "   ·   " .. Input.Label("fire") .. " READY" else string.format("   ·   %.1fs", left))
		weaponFill.Size = UDim2.fromScale(if ready then 1 else math.clamp(1 - left / weaponDef.cooldown, 0, 1), 1)
		weaponFill.BackgroundColor3 = if ready then weaponDef.color else Color3.fromRGB(120, 60, 60)
	end

	-- drift combo
	local combo = num("DriftCombo")
	driftLabel.Text = if combo > 50 then "DRIFT  " .. commas(combo) else ""

	-- race
	local racing = player:GetAttribute("RaceActive") == true
	racePanel.Visible = racing
	if racing then
		raceName.Text = string.upper(tostring(player:GetAttribute("RaceName") or ""))
		local kind = player:GetAttribute("RaceKind")
		local bet = tostring(player:GetAttribute("RaceSideBet") or "")
		sideBetLabel.Text = bet
		sideBetChip.Visible = bet ~= ""
		if kind == "drift" or kind == "takeover" then
			racePos.Text = commas(num("RaceScore"))
			raceInfo.Text = if player:GetAttribute("RaceInZone") == false then "LEAVING THE ZONE!" else "Target  " .. commas(num("RaceTarget"))
			raceInfo.TextColor3 = if player:GetAttribute("RaceInZone") == false then C.Red else C.Text
			raceTime.Text = string.format("Time left  %.1fs", math.max(0, num("RaceTimeLeft")))
			standings.Text = ""
		else
			racePos.Text = string.format("%d<font size=\"24\"> / %d</font>", num("RacePos"), num("RaceRacers"))
			racePos.RichText = true
			local laps = num("RaceLaps")
			raceInfo.Text = if laps > 1
				then string.format("Lap %d/%d   ·   CP %d/%d", num("RaceLap"), laps, num("RaceCP"), num("RaceCPTotal"))
				else string.format("Checkpoint %d / %d", num("RaceCP"), num("RaceCPTotal"))
			raceInfo.TextColor3 = C.Text
			raceTime.Text = string.format("Time  %.1fs", num("RaceTime"))
			local raw = tostring(player:GetAttribute("RaceStandings") or "")
			standings.Text = (string.gsub(raw, "(%d+%.%s+YOU)", "<font color=\"#00E1FF\"><b>%1</b></font>"))
		end
	end
	local cdAttr = player:GetAttribute("RaceCountdown")
	local cd = num("RaceCountdown")
	if racing and cdAttr ~= nil and cd >= 0 then
		countdown.Visible = true
		countdown.Text = if cd == 0 then "GO!" else tostring(cd)
		countdown.TextColor3 = if cd == 0 then C.Green else C.Pink
		if cd ~= lastCountdown then
			lastCountdown = cd
			countdownScale.Scale = 1.8
			TweenService:Create(countdownScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	else
		countdown.Visible = false
		lastCountdown = -1
	end

	-- radar dots
	dotsUsed = 0
	local blinkOn = math.floor(blink * 5) % 2 == 0
	local police = workspace:FindFirstChild("Police")
	if police then
		for _, m in police:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart and m.Name ~= "Roadblock" then
				dot(m.PrimaryPart.Position, if blinkOn then C.Red else C.Blue, if m.Name == "PoliceHeli" then 11 else 8)
			elseif m:IsA("Model") and m.Name == "Roadblock" then
				dot(m:GetPivot().Position, C.Orange, 10)
			end
		end
	end
	local cars = workspace:FindFirstChild("Cars")
	if cars then
		for _, m in cars:GetChildren() do
			if m:IsA("Model") and m ~= car and m.PrimaryPart then
				dot(m.PrimaryPart.Position, Color3.new(1, 1, 1), 8)
			end
		end
	end
	local traffic = workspace:FindFirstChild("Traffic")
	if traffic then
		for _, m in traffic:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart then
				dot(m.PrimaryPart.Position, Color3.fromRGB(130, 134, 150), 4)
			end
		end
	end
	local races = workspace:FindFirstChild("Races")
	if races then
		for _, f in races:GetChildren() do
			for _, m in f:GetChildren() do
				if m:IsA("Model") and m.PrimaryPart then
					dot(m.PrimaryPart.Position, C.Gold, 7)
				end
			end
		end
	end
	if racing then
		local nextCp = player:GetAttribute("RaceNext")
		if typeof(nextCp) == "Vector3" and nextCp.Magnitude > 0 then
			dot(nextCp, Color3.fromRGB(255, 255, 0), 12)
		end
	end
	for k = dotsUsed + 1, #dotPool do
		dotPool[k].Visible = false
	end
	if car and car.PrimaryPart then
		local cf = car.PrimaryPart.CFrame
		local p = canvasPx(cf.Position)
		canvas.Position = UDim2.fromOffset(MAP_PX / 2 - p.X, MAP_PX / 2 - p.Y)
		local look = cf.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		arrow.Visible = true
	else
		arrow.Visible = false
	end
end

---------------------------------------------------------------------------
-- Screen scaling + device layouts (keyboard / gamepad / touch)
---------------------------------------------------------------------------
for _, f in { speedo, heatFrame, wallet, weaponFrame, racePanel, radarHolder, promptButton } :: { GuiObject } do
	Scale.Attach(f)
end

local defaults: { [GuiObject]: { pos: UDim2, anchor: Vector2 } } = {}
for _, f in { speedo, weaponFrame, radarHolder, racePanel, promptButton } :: { GuiObject } do
	defaults[f] = { pos = f.Position, anchor = f.AnchorPoint }
end
local TOUCH: { [GuiObject]: { pos: UDim2, anchor: Vector2 } } = {
	-- the pedals take the bottom right, the steering pad the bottom left
	[speedo] = { pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1) },
	[weaponFrame] = { pos = UDim2.new(0.5, 0, 1, -300), anchor = Vector2.new(0.5, 1) },
	[radarHolder] = { pos = UDim2.new(1, -20, 0, 116), anchor = Vector2.new(1, 0) },
	[racePanel] = { pos = UDim2.new(1, -20, 0, 340), anchor = Vector2.new(1, 0) },
	[promptButton] = { pos = UDim2.new(0.5, 0, 1, -330), anchor = Vector2.new(0.5, 1) },
}

function HUD.SetTouchLayout(on: boolean)
	for f, d in defaults do
		local t = if on then TOUCH[f] else d
		if t then
			f.Position = t.pos
			f.AnchorPoint = t.anchor
		end
	end
	controlsLabel.Visible = not on
end

local _ = promptStroke
return HUD
