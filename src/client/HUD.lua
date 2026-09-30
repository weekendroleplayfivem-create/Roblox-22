--!strict
-- Heads-up display: speedometer + nitro, heat stars and pursuit meters, cash, race panel,
-- drift combo, minimap, notifications and context prompts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))

local player = Players.LocalPlayer

local HUD = {}

local FONT = Enum.Font.GothamBlack
local FONT2 = Enum.Font.GothamBold
local PINK = Color3.fromRGB(255, 40, 160)
local CYAN = Color3.fromRGB(0, 240, 255)
local RED = Color3.fromRGB(255, 60, 60)
local BLUE = Color3.fromRGB(70, 140, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "WantedUnboundHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
HUD.Gui = gui

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = FONT,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeTransparency = 0.5,
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local function corner(parent: Instance, r: number?)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted, k = s, 0
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end
HUD.Commas = commas

---------------------------------------------------------------------------
-- Speedometer (bottom right)
---------------------------------------------------------------------------
local speedo = new("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(230, 120),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.35,
}, gui)
corner(speedo, 14)
new("UIStroke", { Color = CYAN, Thickness = 2, Transparency = 0.3 }, speedo)
local speedLabel = label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -80, 0, 70), Text = "0", TextXAlignment = Enum.TextXAlignment.Right }, speedo)
label({ Position = UDim2.new(1, -68, 0, 34), Size = UDim2.fromOffset(60, 30), Text = "MPH", TextColor3 = CYAN, Font = FONT2 }, speedo)
local carNameLabel = label({ Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 0, 16), Text = "", Font = FONT2, TextColor3 = Color3.fromRGB(190, 190, 210), TextXAlignment = Enum.TextXAlignment.Left }, speedo)
-- tachometer + gear
local gearLabel = label({ Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(44, 50), Text = "1", TextColor3 = Color3.fromRGB(255, 200, 60), TextXAlignment = Enum.TextXAlignment.Left }, speedo)
local rpmBack = new("Frame", {
	Position = UDim2.new(0, 0, 0, -16),
	Size = UDim2.new(1, 0, 0, 10),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.35,
}, speedo)
corner(rpmBack, 5)
local rpmFill = new("Frame", { Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = Color3.fromRGB(80, 255, 140) }, rpmBack)
corner(rpmFill, 5)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 140)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50)),
	}),
}, rpmFill)

function HUD.SetEngine(gear: number, rpm: number, reversing: boolean)
	gearLabel.Text = if reversing then "R" else tostring(gear)
	rpmFill.Size = UDim2.fromScale(math.clamp(rpm, 0.02, 1), 1)
	gearLabel.TextColor3 = if rpm > 0.9 then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(255, 200, 60)
end

local nitroBack = new("Frame", {
	Position = UDim2.fromOffset(12, 96),
	Size = UDim2.new(1, -24, 0, 14),
	BackgroundColor3 = Color3.fromRGB(40, 40, 55),
}, speedo)
corner(nitroBack, 7)
local nitroFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = CYAN }, nitroBack)
corner(nitroFill, 7)
label({ Size = UDim2.fromScale(1, 1), Text = "NITROUS", TextColor3 = Color3.new(1, 1, 1), Font = FONT2, TextStrokeTransparency = 0.2, ZIndex = 2 }, nitroBack)

---------------------------------------------------------------------------
-- Heat + pursuit (top centre)
---------------------------------------------------------------------------
local heatFrame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(360, 100),
	BackgroundTransparency = 1,
}, gui)
local stars: { TextLabel } = {}
for k = 1, 5 do
	stars[k] = label({
		Position = UDim2.fromOffset(40 + (k - 1) * 58, 0),
		Size = UDim2.fromOffset(52, 44),
		Text = "★",
		TextColor3 = Color3.fromRGB(70, 70, 80),
		Font = Enum.Font.GothamBlack,
	}, heatFrame)
end
local statusLabel = label({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 22), Text = "", Font = FONT2 }, heatFrame)
local meterBack = new("Frame", {
	Position = UDim2.fromOffset(30, 72),
	Size = UDim2.new(1, -60, 0, 12),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40),
	Visible = false,
}, heatFrame)
corner(meterBack, 6)
local meterFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = BLUE }, meterBack)
corner(meterFill, 6)
local bustBack = new("Frame", {
	Position = UDim2.fromOffset(30, 88),
	Size = UDim2.new(1, -60, 0, 8),
	BackgroundColor3 = Color3.fromRGB(30, 30, 40),
	Visible = false,
}, heatFrame)
corner(bustBack, 4)
local bustFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = RED }, bustBack)
corner(bustFill, 4)

---------------------------------------------------------------------------
-- Money (top left)
---------------------------------------------------------------------------
local money = new("Frame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.fromOffset(260, 110),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.4,
}, gui)
corner(money, 12)
local bankLabel = label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Text = "$0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 255, 150) }, money)
local unbankedLabel = label({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 20), Text = "", Font = FONT2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 190, 60) }, money)
local bountyLabel = label({ Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 20), Text = "", Font = FONT2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 120, 120) }, money)
local timeLabel = label({ Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -24, 0, 18), Text = "", Font = FONT2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 170, 255) }, money)

---------------------------------------------------------------------------
-- Race panel (right)
---------------------------------------------------------------------------
local racePanel = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 250),
	Size = UDim2.fromOffset(230, 250),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.35,
	Visible = false,
}, gui)
corner(racePanel, 12)
new("UIStroke", { Color = PINK, Thickness = 2 }, racePanel)
local raceName = label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), Text = "", TextColor3 = PINK }, racePanel)
local racePos = label({ Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 50), Text = "" }, racePanel)
local raceInfo = label({ Position = UDim2.fromOffset(10, 84), Size = UDim2.new(1, -20, 0, 22), Text = "", Font = FONT2 }, racePanel)
local raceTime = label({ Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 22), Text = "", Font = FONT2, TextColor3 = Color3.fromRGB(200, 200, 220) }, racePanel)
local standings = label({
	Position = UDim2.fromOffset(14, 140),
	Size = UDim2.new(1, -28, 0, 100),
	Text = "",
	Font = FONT2,
	TextScaled = false,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(230, 230, 240),
}, racePanel)

local countdown = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.38),
	Size = UDim2.fromOffset(400, 160),
	Text = "",
	TextColor3 = PINK,
	TextStrokeTransparency = 0,
	Visible = false,
}, gui)

---------------------------------------------------------------------------
-- Drift combo (centre)
---------------------------------------------------------------------------
local driftLabel = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 130),
	Size = UDim2.fromOffset(360, 40),
	Text = "",
	TextColor3 = Color3.fromRGB(255, 150, 40),
	TextStrokeTransparency = 0.1,
}, gui)

---------------------------------------------------------------------------
-- Notifications (centre left)
---------------------------------------------------------------------------
local notifyFrame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 180),
	Size = UDim2.fromOffset(600, 220),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 4),
}, notifyFrame)
local notifyOrder = 0

function HUD.Notify(text: string, color: Color3?)
	notifyOrder += 1
	local l = label({
		Size = UDim2.new(1, 0, 0, 28),
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.1,
		LayoutOrder = notifyOrder,
	}, notifyFrame)
	local kids = {}
	for _, c in notifyFrame:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(kids, c)
		end
	end
	if #kids > 6 then
		table.sort(kids, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	task.delay(4, function()
		if l.Parent then
			local t = TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
			t:Play()
			t.Completed:Wait()
			l:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Prompt (bottom centre)
---------------------------------------------------------------------------
local promptButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -30),
	Size = UDim2.fromOffset(460, 46),
	BackgroundColor3 = Color3.fromRGB(15, 15, 25),
	BackgroundTransparency = 0.2,
	Font = FONT2,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
	Visible = false,
	AutoButtonColor = true,
}, gui)
corner(promptButton, 10)
new("UIStroke", { Color = PINK, Thickness = 2 }, promptButton)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, promptButton)
HUD.PromptButton = promptButton

function HUD.SetPrompt(text: string?)
	if text then
		promptButton.Text = text
		promptButton.Visible = true
	else
		promptButton.Visible = false
	end
end

local controlsLabel = label({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -250),
	Size = UDim2.fromOffset(300, 16),
	Text = "WASD drive  |  SPACE drift  |  SHIFT nitro  |  R reset  |  G garage",
	Font = FONT2,
	TextColor3 = Color3.fromRGB(200, 200, 220),
	TextXAlignment = Enum.TextXAlignment.Left,
}, gui)
local _ = controlsLabel

---------------------------------------------------------------------------
-- Minimap (bottom left)
---------------------------------------------------------------------------
local MAP_PX = 210
local worldSize = Grid.Half * 2 + Config.Grid.RoadWidth
local scale = MAP_PX / worldSize
local minimap = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -20),
	Size = UDim2.fromOffset(MAP_PX, MAP_PX),
	BackgroundColor3 = Color3.fromRGB(12, 12, 20),
	BackgroundTransparency = 0.2,
	ClipsDescendants = true,
}, gui)
corner(minimap, 12)
new("UIStroke", { Color = PINK, Thickness = 2, Transparency = 0.3 }, minimap)

local function toMap(pos: Vector3): UDim2
	return UDim2.fromOffset((pos.X + worldSize / 2) * scale, (pos.Z + worldSize / 2) * scale)
end

local roadPx = math.max(2, Config.Grid.RoadWidth * scale)
for i = 0, Grid.Size do
	local p = Grid.Intersection(i, 0)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset((p.X + worldSize / 2) * scale, 0),
		Size = UDim2.new(0, roadPx, 1, 0),
		BackgroundColor3 = Color3.fromRGB(70, 70, 90),
		BorderSizePixel = 0,
	}, minimap)
	local q = Grid.Intersection(0, i)
	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(0, (q.Z + worldSize / 2) * scale),
		Size = UDim2.new(1, 0, 0, roadPx),
		BackgroundColor3 = Color3.fromRGB(70, 70, 90),
		BorderSizePixel = 0,
	}, minimap)
end

local function staticDot(pos: Vector3, color: Color3, size: number, text: string?)
	local d = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(pos),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		ZIndex = 2,
	}, minimap)
	corner(d, size)
	if text then
		label({ Size = UDim2.fromScale(1, 1), Text = text, ZIndex = 3, TextStrokeTransparency = 1, TextColor3 = Color3.new(0, 0, 0) }, d)
	end
end

local sh = Config.Blocks.Safehouse
staticDot(Grid.BlockCenter(sh[1], sh[2]), Color3.fromRGB(0, 255, 200), 14, "S")
for _, h in Config.Blocks.HidingSpots do
	staticDot(Grid.BlockCenter(h[1], h[2]), Color3.fromRGB(80, 255, 120), 9, "H")
end
for _, b in Config.PursuitBreakers do
	staticDot(Grid.Intersection(b[1], b[2]) + Vector3.new(36, 0, 36), Color3.fromRGB(255, 70, 70), 7)
end
for _, r in Config.Races do
	local p = r.route[1]
	staticDot(Grid.Intersection(p[1], p[2]), if r.kind == "drift" then Color3.fromRGB(255, 140, 0) else PINK, 10, "R")
end

local dynamic = new("Folder", { Name = "Dynamic" }, minimap)
local dotPool: { Frame } = {}
local dotsUsed = 0

local function dot(pos: Vector3, color: Color3, size: number)
	dotsUsed += 1
	local d = dotPool[dotsUsed]
	if not d then
		local nd: Frame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 }, dynamic)
		corner(nd, 10)
		dotPool[dotsUsed] = nd
		d = nd
	end
	d.Visible = true
	d.Position = toMap(pos)
	d.Size = UDim2.fromOffset(size, size)
	d.BackgroundColor3 = color
end

local arrow = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(18, 18),
	Text = "▲",
	TextColor3 = CYAN,
	ZIndex = 6,
	TextStrokeTransparency = 0,
}, minimap)

---------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------
local function num(name: string): number
	local v = player:GetAttribute(name)
	return if type(v) == "number" then v else 0
end

local blink = 0
function HUD.Update(dt: number, speed: number, nitro: number, capacity: number, nitroOn: boolean, car: Model?)
	blink += dt
	speedLabel.Text = tostring(math.floor(speed * Config.MphPerStud))
	nitroFill.Size = UDim2.fromScale(math.clamp(nitro / math.max(capacity, 0.01), 0, 1), 1)
	nitroFill.BackgroundColor3 = if nitroOn then Color3.fromRGB(255, 255, 255) else CYAN
	if car then
		local rating = car:GetAttribute("rating")
		local class = car:GetAttribute("RatingClass")
		carNameLabel.Text = tostring(car:GetAttribute("CarName") or "") .. (if class then "   " .. tostring(class) .. " " .. tostring(rating) else "")
	else
		carNameLabel.Text = ""
	end

	-- heat
	local heat = num("Heat")
	local mode = player:GetAttribute("PursuitMode") or "idle"
	local level = math.floor(heat)
	for k = 1, 5 do
		local lit = k <= level
		local color = Color3.fromRGB(70, 70, 80)
		if lit then
			if mode ~= "idle" then
				color = if (math.floor(blink * 4) + k) % 2 == 0 then RED else BLUE
			else
				color = Color3.fromRGB(255, 80, 80)
			end
		end
		stars[k].TextColor3 = color
	end

	if mode == "pursuit" then
		statusLabel.Text = "PURSUIT  -  lose them!"
		statusLabel.TextColor3 = RED
		meterBack.Visible = true
		meterFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		meterFill.Size = UDim2.fromScale(num("Evade"), 1)
	elseif mode == "cooldown" then
		statusLabel.Text = if player:GetAttribute("Hiding") then "COOLDOWN  -  hiding (x3)" else "COOLDOWN  -  stay out of sight"
		statusLabel.TextColor3 = BLUE
		meterBack.Visible = true
		meterFill.BackgroundColor3 = BLUE
		meterFill.Size = UDim2.fromScale(num("Cooldown"), 1)
	else
		statusLabel.Text = if level > 0 then "HEAT " .. level .. "  -  bank at the safehouse to clear it" else ""
		statusLabel.TextColor3 = Color3.fromRGB(255, 160, 160)
		meterBack.Visible = false
	end
	local bust = num("Bust")
	bustBack.Visible = bust > 0.01
	bustFill.Size = UDim2.fromScale(bust, 1)

	-- money
	bankLabel.Text = "$" .. commas(num("Cash"))
	local unbanked = num("Unbanked")
	unbankedLabel.Text = if unbanked > 0 then "Unbanked: $" .. commas(unbanked) .. "  (at risk!)" else "Unbanked: $0"
	local bounty = num("Bounty")
	bountyLabel.Text = if mode ~= "idle" then "Pursuit bounty: " .. commas(bounty) else "Total bounty: " .. commas(num("TotalBounty"))
	timeLabel.Text = if player:GetAttribute("Night") then "NIGHT  -  x" .. Config.NightMultiplier .. " payouts" else "DAY"

	-- drift combo
	local combo = num("DriftCombo")
	driftLabel.Text = if combo > 50 then "DRIFT  " .. commas(combo) else ""

	-- race
	local racing = player:GetAttribute("RaceActive") == true
	racePanel.Visible = racing
	if racing then
		raceName.Text = tostring(player:GetAttribute("RaceName") or "")
		local kind = player:GetAttribute("RaceKind")
		if kind == "drift" then
			racePos.Text = commas(num("RaceScore"))
			raceInfo.Text = "Target: " .. commas(num("RaceTarget"))
			raceTime.Text = string.format("Time left: %.1fs", math.max(0, num("RaceTimeLeft")))
			standings.Text = ""
		else
			racePos.Text = string.format("%d / %d", num("RacePos"), num("RaceRacers"))
			local laps = num("RaceLaps")
			raceInfo.Text = if laps > 1
				then string.format("Lap %d/%d   CP %d/%d", num("RaceLap"), laps, num("RaceCP"), num("RaceCPTotal"))
				else string.format("Checkpoint %d/%d", num("RaceCP"), num("RaceCPTotal"))
			raceTime.Text = string.format("Time: %.1fs", num("RaceTime"))
			standings.Text = tostring(player:GetAttribute("RaceStandings") or "")
		end
	end
	local cd = num("RaceCountdown")
	if racing and player:GetAttribute("RaceCountdown") ~= nil and cd >= 0 then
		countdown.Visible = true
		countdown.Text = if cd == 0 then "GO!" else tostring(cd)
	else
		countdown.Visible = false
	end

	-- minimap dynamic dots
	dotsUsed = 0
	local blinkOn = math.floor(blink * 5) % 2 == 0
	local police = workspace:FindFirstChild("Police")
	if police then
		for _, m in police:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart and m.Name ~= "Roadblock" then
				dot(m.PrimaryPart.Position, if blinkOn then RED else BLUE, if m.Name == "PoliceHeli" then 10 else 7)
			elseif m:IsA("Model") and m.Name == "Roadblock" then
				local p = m:GetPivot().Position
				dot(p, Color3.fromRGB(255, 120, 0), 9)
			end
		end
	end
	local cars = workspace:FindFirstChild("Cars")
	if cars then
		for _, m in cars:GetChildren() do
			if m:IsA("Model") and m ~= car and m.PrimaryPart then
				dot(m.PrimaryPart.Position, Color3.new(1, 1, 1), 7)
			end
		end
	end
	local traffic = workspace:FindFirstChild("Traffic")
	if traffic then
		for _, m in traffic:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart then
				dot(m.PrimaryPart.Position, Color3.fromRGB(130, 130, 145), 4)
			end
		end
	end
	local races = workspace:FindFirstChild("Races")
	if races then
		for _, f in races:GetChildren() do
			for _, m in f:GetChildren() do
				if m:IsA("Model") and m.PrimaryPart then
					dot(m.PrimaryPart.Position, Color3.fromRGB(255, 220, 60), 6)
				end
			end
		end
	end
	if racing then
		local nextCp = player:GetAttribute("RaceNext")
		if typeof(nextCp) == "Vector3" and nextCp.Magnitude > 0 then
			dot(nextCp, Color3.fromRGB(255, 255, 0), 11)
		end
	end
	for k = dotsUsed + 1, #dotPool do
		dotPool[k].Visible = false
	end
	if car and car.PrimaryPart then
		local cf = car.PrimaryPart.CFrame
		arrow.Position = toMap(cf.Position)
		local look = cf.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		arrow.Visible = true
	else
		arrow.Visible = false
	end
end

return HUD
