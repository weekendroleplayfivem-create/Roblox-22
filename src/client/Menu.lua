--!strict
-- Main menu and pause menu.
-- Title screen: cinematic camera shots around the safehouse, animated menu buttons, a player card
-- with your stats, settings, how to play, credits and a rotating tips bar.
-- In game: press P (or the ☰ button) for the pause menu.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shop = Remotes:WaitForChild("Shop") :: RemoteFunction
local RedeemCode = Remotes:WaitForChild("RedeemCode") :: RemoteFunction

local Drive = require(script.Parent.DriveController)
local Settings = require(script.Parent.Settings)
local Sounds = require(script.Parent.Sounds)
local Garage = require(script.Parent.Garage)
local FullMap = require(script.Parent.FullMap)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Menu = {}
Menu.Mode = "title" -- "title" | "pause" | "closed"

local PINK = Color3.fromRGB(255, 40, 140)
local CYAN = Color3.fromRGB(0, 230, 255)
local RED = Color3.fromRGB(255, 50, 60)

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

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local base = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local gui = new("ScreenGui", { Name = "WantedUnboundMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, player:WaitForChild("PlayerGui"))

-- cinematic letterbox + gradient
local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, BorderSizePixel = 0 }, gui)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.45, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, shade)
local barTop = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, gui)
local barBottom = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, gui)
local fade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50 }, gui)

-- left column: logo + buttons
local left = new("Frame", { Position = UDim2.new(0, 60, 0, 90), Size = UDim2.new(0, 460, 1, -160), BackgroundTransparency = 1 }, gui)
local logo = new("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1 }, left)
text(logo, { Size = UDim2.new(1, 0, 0, 92), Text = "WANTED", Font = Enum.Font.GothamBlack, TextColor3 = RED, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(40, 0, 10) })
text(logo, { Position = UDim2.fromOffset(4, 86), Size = UDim2.new(1, 0, 0, 50), Text = "U N B O U N D", Font = Enum.Font.GothamBlack, TextColor3 = CYAN, TextStrokeTransparency = 0 })
local tagline = text(logo, { Position = UDim2.fromOffset(4, 142), Size = UDim2.new(1, 0, 0, 22), Text = "Race.  Raise your heat.  Escape the cops.  Climb the Blacklist.", Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(220, 220, 230) })

local list = new("Frame", { Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 1, -200), BackgroundTransparency = 1 }, left)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)

type Button = { frame: TextButton, setLabel: (string) -> () }
local function menuButton(label: string, order: number, onClick: () -> ()): Button
	local b = new("TextButton", {
		Size = UDim2.new(0, 360, 0, 54),
		BackgroundColor3 = Color3.fromRGB(12, 12, 20),
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
	}, list)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	local accent = new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = PINK, BorderSizePixel = 0 }, b)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = PINK, BackgroundTransparency = 0.15, BorderSizePixel = 0 }, b)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, fill)
	local t = text(b, { Position = UDim2.fromOffset(24, 10), Size = UDim2.new(1, -40, 1, -20), Text = label, Font = Enum.Font.GothamBlack, ZIndex = 2 })
	local arrowLbl = text(b, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(24, 26), Text = "›", TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, ZIndex = 2 })
	local quick = TweenInfo.new(0.16, Enum.EasingStyle.Quad)
	b.MouseEnter:Connect(function()
		Sounds.Tick(1.4, 0.25)
		TweenService:Create(fill, quick, { Size = UDim2.new(1, 0, 1, 0) }):Play()
		TweenService:Create(t, quick, { Position = UDim2.fromOffset(34, 10) }):Play()
		TweenService:Create(arrowLbl, quick, { TextTransparency = 0 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(fill, quick, { Size = UDim2.new(0, 0, 1, 0) }):Play()
		TweenService:Create(t, quick, { Position = UDim2.fromOffset(24, 10) }):Play()
		TweenService:Create(arrowLbl, quick, { TextTransparency = 1 }):Play()
	end)
	b.Activated:Connect(function()
		Sounds.Tick(1, 0.5)
		onClick()
	end)
	local _ = accent
	return {
		frame = b,
		setLabel = function(s: string)
			t.Text = s
		end,
	}
end

-- right column: player card
local card = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 110),
	Size = UDim2.fromOffset(340, 300),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.2,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
new("UIStroke", { Color = CYAN, Thickness = 2, Transparency = 0.4 }, card)
local avatar = new("ImageLabel", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(72, 72), BackgroundColor3 = Color3.fromRGB(30, 30, 40) }, card)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)
task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok then
		avatar.Image = img
	end
end)
text(card, { Position = UDim2.fromOffset(100, 22), Size = UDim2.new(1, -116, 0, 28), Text = player.DisplayName, Font = Enum.Font.GothamBlack })
local rankLabel = text(card, { Position = UDim2.fromOffset(100, 54), Size = UDim2.new(1, -116, 0, 20), Text = "", TextColor3 = RED })
local statRows: { TextLabel } = {}
for k = 1, 6 do
	statRows[k] = text(card, { Position = UDim2.fromOffset(18, 100 + (k - 1) * 30), Size = UDim2.new(1, -36, 0, 22), Text = "", Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(225, 225, 235) })
end

local function commas(n: number): string
	return HUD.Commas(n)
end

local function refreshCard()
	local ok, _, snap = pcall(function()
		return Shop:InvokeServer("Get")
	end)
	if not ok or type(snap) ~= "table" then
		return
	end
	Settings.Load(snap.settings)
	local beaten = snap.blacklistBeaten or 0
	rankLabel.Text = if beaten >= 5 then "#1 MOST WANTED" else ("Chasing Blacklist #" .. (5 - beaten))
	local car = Config.GetCar(snap.selected)
	local owned = 0
	for _ in snap.owned do
		owned += 1
	end
	local done = 0
	for _ in snap.milestones or {} do
		done += 1
	end
	local rows = {
		"Cash:  $" .. commas(snap.cash),
		"Total bounty:  " .. commas(snap.totalBounty),
		"Races won:  " .. snap.racesWon,
		"Cars owned:  " .. owned,
		"Driving:  " .. (if car then car.name else "?"),
		"Milestones:  " .. done .. " / " .. #Config.Milestones,
	}
	local rep = snap.rep or 0
	local level = 1
	local left = rep
	while level < Config.Rep.MaxLevel and left >= Config.Rep.PerLevel(level) do
		left -= Config.Rep.PerLevel(level)
		level += 1
	end
	rankLabel.Text ..= "   |   REP " .. level
	for k, r in rows do
		statRows[k].Text = r
	end
end

-- panels (settings / how to play / credits) replace the player card
local panel = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 110),
	Size = UDim2.fromOffset(520, 440),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.1,
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
new("UIStroke", { Color = PINK, Thickness = 2 }, panel)
local panelTitle = text(panel, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 32), Text = "", Font = Enum.Font.GothamBlack, TextColor3 = CYAN })
local panelBody = new("Frame", { Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 1, -80), BackgroundTransparency = 1 }, panel)

local function clearPanel()
	for _, c in panelBody:GetChildren() do
		c:Destroy()
	end
end

local function settingRow(order: number, label: string, getValue: () -> string, onClick: () -> ())
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(24, 24, 36), LayoutOrder = order }, panelBody)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, row)
	text(row, { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(0.55, 0, 0, 24), Text = label })
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 32),
		BackgroundColor3 = PINK,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = getValue(),
	}, row)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, b)
	b.Activated:Connect(function()
		Sounds.Tick(1.2, 0.4)
		onClick()
		b.Text = getValue()
	end)
end

local function onOff(v: boolean): string
	return if v then "ON" else "OFF"
end

local function showSettings()
	clearPanel()
	panelTitle.Text = "SETTINGS"
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panelBody)
	local v = Settings.Values
	settingRow(1, "Camera shake", function()
		return onOff(v.shake)
	end, function()
		Settings.Set("shake", not v.shake)
	end)
	settingRow(2, "Speed lines", function()
		return onOff(v.speedLines)
	end, function()
		Settings.Set("speedLines", not v.speedLines)
	end)
	settingRow(3, "Motion blur", function()
		return onOff(v.blur)
	end, function()
		Settings.Set("blur", not v.blur)
	end)
	settingRow(4, "Speed units", function()
		return if v.units == "kmh" then "KM/H" else "MPH"
	end, function()
		Settings.Set("units", if v.units == "kmh" then "mph" else "kmh")
	end)
	settingRow(5, "Volume", function()
		return math.floor(v.volume * 100 + 0.5) .. "%"
	end, function()
		local nextV = v.volume + 0.2
		if nextV > 1.01 then
			nextV = 0
		end
		Settings.Set("volume", nextV)
	end)
	settingRow(6, "Performance mode", function()
		return onOff(v.performance)
	end, function()
		Settings.Set("performance", not v.performance)
	end)
	text(panelBody, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 7, TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(170, 170, 190), Text = "Performance mode turns off shadows, bloom, sun rays and depth of field on this device. Settings are saved to your profile." })
end

local function showHelp()
	clearPanel()
	panelTitle.Text = "HOW TO PLAY"
	text(panelBody, {
		Size = UDim2.fromScale(1, 1),
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		RichText = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		Text = table.concat({
			"<b>CONTROLS</b>   WASD drive · SPACE drift · SHIFT nitro · F fire weapon · R reset · E interact · G garage · M map · P pause",
			"",
			"<b>RACE</b>  at the pink R markers. Winnings grow with your heat and at night.",
			"<b>DRIFT</b>  with the handbrake, or tap the brake and get back on the gas while steering. Hold the throttle to keep the slide going.",
			"<b>TRAFFIC</b>  Pass cars close and fast for near misses: cash and nitro.",
			"<b>COPS</b>  Break line of sight, then stay hidden until cooldown ends. Hiding spots (H) cool you down 3x faster. Watch for roadblocks and spike strips.",
			"<b>BANK</b>  your cash at the safehouse (S). Get busted and you lose everything unbanked.",
			"<b>GARAGE</b>  Press E at the safehouse to drive in: buy cars, tune parts, handling and looks.",
			"<b>BLACKLIST</b>  Earn bounty and wins, then beat the five rivals to win their cars.",
			"<b>WEAPONS</b>  Buy roof weapons at the Black Market (B) at the docks. Fire with F - they only hit cops and rivals.",
			"<b>UNBOUND</b>  Takeovers (score style in a zone), side bets in races, burst nitrous (tuning), REP levels and 40 street art pieces to find.",
			"",
			"Neon Bay is huge: downtown towers, midtown, suburbs, the docks and the Beltway ring road. Press M for the city map.",
		}, "\n"),
	})
end

local function showCodes()
	clearPanel()
	panelTitle.Text = "CODES"
	text(panelBody, { Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 200, 215), Text = "Enter a code for free cash, cars and weapons. Each code works once per player." })
	local box = new("TextBox", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, -170, 0, 50),
		BackgroundColor3 = Color3.fromRGB(24, 24, 36),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Color3.fromRGB(120, 120, 140),
		Text = "",
		ClearTextOnFocus = false,
	}, panelBody)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, box)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, box)
	local result = text(panelBody, { Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 26), Text = "", TextXAlignment = Enum.TextXAlignment.Center })
	local redeem = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 56),
		Size = UDim2.fromOffset(150, 50),
		BackgroundColor3 = PINK,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "REDEEM",
	}, panelBody)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, redeem)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, redeem)
	local busy = false
	local function submit()
		if busy or box.Text == "" then
			return
		end
		busy = true
		local ok, msg = RedeemCode:InvokeServer(box.Text)
		result.Text = tostring(msg)
		result.TextColor3 = if ok then Color3.fromRGB(120, 255, 150) else Color3.fromRGB(255, 100, 100)
		Sounds.Tick(if ok then 1.4 else 0.6, 0.5)
		if ok then
			box.Text = ""
			refreshCard()
		end
		busy = false
	end
	redeem.Activated:Connect(submit)
	box.FocusLost:Connect(function(enter)
		if enter then
			submit()
		end
	end)
	text(panelBody, { Position = UDim2.fromOffset(0, 170), Size = UDim2.new(1, 0, 0, 22), Text = "Tip: follow the game for new codes!", Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(160, 160, 180), TextXAlignment = Enum.TextXAlignment.Center })
end

local function showCredits()
	clearPanel()
	panelTitle.Text = "CREDITS"
	text(panelBody, {
		Size = UDim2.fromScale(1, 1),
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham,
		Text = Config.GameName .. "\n\nA fan-made street racing game inspired by classic cops-and-racers games.\n\nEverything (the city, cars, sound design and UI) is generated in code from Roblox parts and built-in sounds.\n\nThanks for playing!",
	})
end

local activePanel = ""
local function togglePanel(name: string, show: () -> ())
	if activePanel == name and panel.Visible then
		panel.Visible = false
		card.Visible = true
		activePanel = ""
		return
	end
	activePanel = name
	show()
	panel.Visible = true
	card.Visible = false
end

-- tips bar
local tipLabel = text(barBottom, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(200, 200, 215), Text = "" })
local TIPS = {
	"CODES: try WANTED, UNBOUND and NEONBAY in the CODES menu for free cash!",
	"TIP: Weapons from the Black Market (B) mount on your roof. Fire with F.",
	"TIP: Set Nitrous Type to BURST in Handling for short, hard boosts.",
	"TIP: 40 pieces of street art are hidden around the city. Find them all!",
	"TIP: Night doubles the danger - and pays x" .. Config.NightMultiplier .. ".",
	"TIP: Drive through a pursuit breaker (red ring) to drop it on the cops behind you.",
	"TIP: Near misses fill your nitro. Weave through traffic!",
	"TIP: Tune the handling slider towards DRIFT for longer slides.",
	"TIP: Traffic stops at red lights. Cops don't.",
	"TIP: The Beltway ring road is the fastest way across the city.",
	"TIP: The floating arrow always points to your next goal.",
}

-- camera shots near the safehouse (always inside the streamed area)
local sh = Config.Blocks.Safehouse
local SAFE = Grid.BlockCenter(sh[1], sh[2])
type Shot = { from: CFrame, to: CFrame }
local function shots(): { Shot }
	local s = SAFE
	local road = Vector3.new(s.X, 0, s.Z - Config.Grid.Cell / 2)
	return {
		{ from = CFrame.lookAt(s + Vector3.new(-260, 150, -200), s), to = CFrame.lookAt(s + Vector3.new(200, 120, -260), s) },
		{ from = CFrame.lookAt(road + Vector3.new(-160, 5, 8), road + Vector3.new(0, 4, 0)), to = CFrame.lookAt(road + Vector3.new(60, 5, 8), road + Vector3.new(220, 6, 0)) },
		{ from = CFrame.lookAt(s + Vector3.new(0, 420, 300), s + Vector3.new(0, 0, -300)), to = CFrame.lookAt(s + Vector3.new(0, 380, -100), s + Vector3.new(0, 0, -600)) },
		{ from = CFrame.lookAt(s + Vector3.new(90, 12, 90), s + Vector3.new(0, 20, 0)), to = CFrame.lookAt(s + Vector3.new(-90, 22, 110), s + Vector3.new(0, 25, 0)) },
	}
end
local SHOT_TIME = 7
local shotClock = 0
local shotIndex = 1
local tipClock = 0
local tipIndex = 1

-- buttons
local playButton: Button
local function closeMenu()
	if Menu.Mode == "closed" then
		return
	end
	Menu.Mode = "closed"
	Drive.MenuOpen = false
	TweenService:Create(fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
	task.delay(0.28, function()
		gui.Enabled = false
		fade.BackgroundTransparency = 1
	end)
end

local function openMenu(mode: string)
	Menu.Mode = mode
	gui.Enabled = true
	panel.Visible = false
	card.Visible = true
	activePanel = ""
	Drive.MenuOpen = mode == "title"
	playButton.setLabel(if mode == "title" then "PLAY" else "RESUME")
	barTop.Visible = mode == "title"
	barBottom.Visible = true
	tagline.Visible = mode == "title"
	shade.BackgroundTransparency = if mode == "title" then 0.2 else 0.05
	shotClock = 0
	refreshCard()
end
Menu.Open = openMenu

playButton = menuButton("PLAY", 1, closeMenu)
menuButton("GARAGE", 2, function()
	closeMenu()
	task.delay(0.3, function()
		if player:GetAttribute("AtSafehouse") then
			Garage.Enter()
		else
			HUD.Notify("The garage is at the safehouse (S on the map)", Color3.fromRGB(0, 255, 200))
		end
	end)
end)
menuButton("CITY MAP", 3, function()
	FullMap.Toggle(true)
end)
menuButton("CODES", 4, function()
	togglePanel("codes", showCodes)
end)
menuButton("SETTINGS", 5, function()
	togglePanel("settings", showSettings)
end)
menuButton("HOW TO PLAY", 6, function()
	togglePanel("help", showHelp)
end)
menuButton("CREDITS", 7, function()
	togglePanel("credits", showCredits)
end)

-- pause: P key or the ☰ button on the HUD
ContextActionService:BindAction("WU_Pause", function(_, state)
	if state == Enum.UserInputState.Begin then
		if Menu.Mode == "closed" then
			openMenu("pause")
		elseif Menu.Mode == "pause" then
			closeMenu()
		end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.P)

local pauseButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 60),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(12, 12, 20),
	BackgroundTransparency = 0.25,
	Text = "☰",
	TextScaled = true,
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.new(1, 1, 1),
}, HUD.Gui)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, pauseButton)
pauseButton.Activated:Connect(function()
	Sounds.Tick(1, 0.4)
	if Menu.Mode == "closed" then
		openMenu("pause")
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	if Menu.Mode == "closed" then
		return
	end
	tipClock += dt
	if tipClock > 5 or tipLabel.Text == "" then
		tipClock = 0
		tipIndex = tipIndex % #TIPS + 1
		tipLabel.Text = TIPS[tipIndex]
	end
	if Menu.Mode ~= "title" then
		return
	end
	-- cinematic camera: slow moves between shots with a dip to black
	shotClock += dt
	local list_ = shots()
	if shotClock > SHOT_TIME then
		shotClock = 0
		shotIndex = shotIndex % #list_ + 1
	end
	local shot = list_[shotIndex]
	local t = shotClock / SHOT_TIME
	t = t * t * (3 - 2 * t)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = shot.from:Lerp(shot.to, t)
	camera.FieldOfView = 55
	local edge = math.min(shotClock, SHOT_TIME - shotClock)
	fade.BackgroundTransparency = math.clamp(edge / 0.5, 0, 1)
end)

openMenu("title")
return Menu
