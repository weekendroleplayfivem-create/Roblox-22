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
local Input = require(script.Parent.Input)
local Scale = require(script.Parent.Scale)
local Theme = require(script.Parent.Theme)
local LeaderboardUI = require(script.Parent.LeaderboardUI)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Menu = {}
Menu.Mode = "title" -- "title" | "pause" | "closed"

local PINK = Color3.fromRGB(255, 40, 140)
local CYAN = Color3.fromRGB(0, 230, 255)
local RED = Color3.fromRGB(255, 50, 60)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	if props.Font ~= nil then
		(inst :: any).FontFace = Theme.FontFor(props.Font)
	end
	for k, v in props do
		if k ~= "Font" and k ~= "FontFace" then
			(inst :: any)[k] = v
		end
	end
	if props.FontFace ~= nil then
		(inst :: any).FontFace = props.FontFace
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local base: { [string]: any } = { BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in props do
		base[k] = v
	end
	if base.Font == nil and base.FontFace == nil then
		base.FontFace = Theme.Fonts.Body
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
local left = new("Frame", { Position = UDim2.new(0, 60, 0, 70), Size = UDim2.new(0, 460, 1, -120), BackgroundTransparency = 1 }, gui)
local logo = new("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1 }, left)
local wantedText = text(logo, { Size = UDim2.new(1, 0, 0, 92), Text = "WANTED", FontFace = Theme.Fonts.Display, TextColor3 = Color3.new(1, 1, 1) })
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 150, 40)), Rotation = 0 }, wantedText)
new("UIStroke", { Color = Color3.fromRGB(40, 0, 10), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, wantedText)
local unboundText = text(logo, { Position = UDim2.fromOffset(4, 88), Size = UDim2.new(1, 0, 0, 46), Text = "U N B O U N D", FontFace = Theme.Fonts.Heading, TextColor3 = Color3.new(1, 1, 1) })
local logoShine = new("UIGradient", { Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, CYAN),
	ColorSequenceKeypoint.new(0.45, CYAN),
	ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.55, PINK),
	ColorSequenceKeypoint.new(1, PINK),
}), Offset = Vector2.new(-1, 0) }, unboundText)
local tagline = text(logo, { Position = UDim2.fromOffset(4, 142), Size = UDim2.new(1, 0, 0, 22), Text = "Race.  Raise your heat.  Escape the cops.  Climb the Blacklist.", FontFace = Theme.Fonts.Light, TextColor3 = Color3.fromRGB(220, 220, 230) })

local list = new("Frame", { Position = UDim2.fromOffset(0, 182), Size = UDim2.new(1, 0, 1, -182), BackgroundTransparency = 1 }, left)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

type Button = { frame: TextButton, setLabel: (string) -> (), slide: UIPadding }
local buttons: { Button } = {}
local function menuButton(label: string, order: number, onClick: () -> ()): Button
	local b = new("TextButton", {
		Size = UDim2.new(0, 360, 0, 44),
		BackgroundColor3 = Color3.fromRGB(12, 12, 20),
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
	}, list)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 170)), Rotation = 90 }, b)
	local slide = new("UIPadding", {}, b)
	local accent = new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = PINK, BorderSizePixel = 0 }, b)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = PINK, BackgroundTransparency = 0.15, BorderSizePixel = 0 }, b)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, fill)
	local t = text(b, { Position = UDim2.fromOffset(24, 11), Size = UDim2.new(1, -40, 1, -22), Text = label, FontFace = Theme.Fonts.Heading, ZIndex = 2 })
	local arrowLbl = text(b, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 9), Size = UDim2.fromOffset(24, 26), Text = "›", TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, ZIndex = 2 })
	local quick = TweenInfo.new(0.16, Enum.EasingStyle.Quad)
	b.MouseEnter:Connect(function()
		Sounds.Tick(1.4, 0.25)
		TweenService:Create(fill, quick, { Size = UDim2.new(1, 0, 1, 0) }):Play()
		TweenService:Create(t, quick, { Position = UDim2.fromOffset(34, 11) }):Play()
		TweenService:Create(arrowLbl, quick, { TextTransparency = 0 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(fill, quick, { Size = UDim2.new(0, 0, 1, 0) }):Play()
		TweenService:Create(t, quick, { Position = UDim2.fromOffset(24, 11) }):Play()
		TweenService:Create(arrowLbl, quick, { TextTransparency = 1 }):Play()
	end)
	b.Activated:Connect(function()
		Sounds.Tick(1, 0.5)
		onClick()
	end)
	local _ = accent
	local made: Button
	made = {
		frame = b,
		setLabel = function(s: string)
			t.Text = s
		end,
		slide = slide,
	}
	table.insert(buttons, made)
	return made
end

Scale.Attach(left)

-- right column: player card
local card = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -60, 0, 110),
	Size = UDim2.fromOffset(340, 300),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.2,
}, gui)
Theme.Panel(card, CYAN, 16)
Scale.Attach(card)
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
text(card, { Position = UDim2.fromOffset(100, 22), Size = UDim2.new(1, -116, 0, 28), Text = player.DisplayName, FontFace = Theme.Fonts.Heading })
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
		-- the server may still be loading the profile right after joining
		task.delay(1.5, refreshCard)
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
Theme.Panel(panel, PINK, 16)
Scale.Attach(panel)
local panelTitle = text(panel, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 32), Text = "", FontFace = Theme.Fonts.Display, TextColor3 = CYAN })
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
		Theme.Show(panel, false, UDim2.fromOffset(640, 0))
		Theme.Show(card, true, UDim2.fromOffset(460, 0))
		activePanel = ""
		return
	end
	activePanel = name
	show()
	-- slide the new panel in (again, when switching between panels)
	panel:SetAttribute("Shown", false)
	Theme.Show(panel, true, UDim2.fromOffset(640, 0))
	Theme.Show(card, false, UDim2.fromOffset(460, 0))
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
local menuToken = 0
local LEFT_HOME = left.Position
local CARD_HOME = card.Position
card:SetAttribute("Home", CARD_HOME)
panel:SetAttribute("Home", CARD_HOME)
local function closeMenu()
	if Menu.Mode == "closed" then
		return
	end
	local wasTitle = Menu.Mode == "title"
	Menu.Mode = "closed"
	Drive.MenuOpen = false
	Input.ClearSelection()
	Theme.Blur("menu", false)
	menuToken += 1
	local token = menuToken
	-- slide everything off screen; from the title screen also dip to black
	local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(left, out, { Position = LEFT_HOME - UDim2.fromOffset(560, 0) }):Play()
	TweenService:Create(card, out, { Position = CARD_HOME + UDim2.fromOffset(460, 0) }):Play()
	TweenService:Create(panel, out, { Position = CARD_HOME + UDim2.fromOffset(640, 0) }):Play()
	TweenService:Create(shade, out, { BackgroundTransparency = 1 }):Play()
	if wasTitle then
		TweenService:Create(fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
	end
	task.delay(0.28, function()
		if menuToken ~= token then
			return
		end
		gui.Enabled = false
		fade.BackgroundTransparency = 1
		HUD.Intro()
	end)
end

local function openMenu(mode: string)
	Menu.Mode = mode
	menuToken += 1
	gui.Enabled = true
	Theme.Blur("menu", mode == "pause")
	-- animate in: columns slide from the sides, buttons cascade, shade fades up
	left.Position = LEFT_HOME - UDim2.fromOffset(560, 0)
	local back = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(left, back, { Position = LEFT_HOME }):Play()
	card:SetAttribute("Shown", false)
	Theme.Show(card, true, UDim2.fromOffset(460, 0))
	if panel:GetAttribute("Shown") == true then
		Theme.Show(panel, false, UDim2.fromOffset(640, 0))
	else
		panel.Visible = false
	end
	for k, btn in buttons do
		btn.slide.PaddingLeft = UDim.new(0, -120)
		btn.frame.BackgroundTransparency = 1
		local info = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.1 + k * 0.045)
		TweenService:Create(btn.slide, info, { PaddingLeft = UDim.new(0, 0) }):Play()
		TweenService:Create(btn.frame, info, { BackgroundTransparency = 0.25 }):Play()
	end
	logoShine.Offset = Vector2.new(-1, 0)
	TweenService:Create(logoShine, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0.3), { Offset = Vector2.new(1, 0) }):Play()
	activePanel = ""
	Drive.MenuOpen = mode == "title"
	playButton.setLabel(if mode == "title" then "PLAY" else "RESUME")
	barTop.Visible = mode == "title"
	barBottom.Visible = true
	tagline.Visible = mode == "title"
	shade.BackgroundTransparency = 1
	TweenService:Create(shade, TweenInfo.new(0.35), { BackgroundTransparency = if mode == "title" then 0.2 else 0.15 }):Play()
	shotClock = 0
	refreshCard()
	Input.Select(playButton.frame)
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
menuButton("LEADERBOARD", 4, function()
	LeaderboardUI.Toggle(true)
end)
menuButton("CODES", 5, function()
	togglePanel("codes", showCodes)
end)
menuButton("SETTINGS", 6, function()
	togglePanel("settings", showSettings)
end)
menuButton("HOW TO PLAY", 7, function()
	togglePanel("help", showHelp)
end)
menuButton("CREDITS", 8, function()
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
end, false, Enum.KeyCode.P, Enum.KeyCode.DPadDown)

-- round glass buttons, top right of the HUD
local function hudButton(icon: string, slot: number, accent: Color3): TextButton
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16 - (slot - 1) * 52, 0, 60),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		AutoButtonColor = false,
		Text = icon,
		TextScaled = true,
		FontFace = Theme.Fonts.Heading,
		TextColor3 = Color3.new(1, 1, 1),
	}, HUD.Gui)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, btn)
	local stroke = new("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
	new("UIPadding", { PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, btn)
	local scale = new("UIScale", {}, btn)
	btn.MouseEnter:Connect(function()
		Theme.Tween(scale, 0.15, { Scale = 1.1 })
		Theme.Tween(stroke, 0.15, { Transparency = 0 })
	end)
	btn.MouseLeave:Connect(function()
		Theme.Tween(scale, 0.15, { Scale = 1 })
		Theme.Tween(stroke, 0.15, { Transparency = 0.4 })
	end)
	btn.Activated:Connect(function()
		scale.Scale = 0.85
		Theme.Tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	return btn
end
local pauseButton = hudButton("☰", 1, PINK)
local mapButton = hudButton("MAP", 2, CYAN)
local boardButton = hudButton("🏆", 3, Theme.Colors.Gold)
boardButton.Activated:Connect(function()
	LeaderboardUI.Toggle()
end)
mapButton.Activated:Connect(function()
	FullMap.Toggle()
end)

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
