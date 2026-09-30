--!strict
-- Reward screens: the race results card (place, time, cash and REP counting up, final order,
-- confetti when you win) and the daily login reward with its 7-day streak track.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Scale = require(script.Parent.Scale)
local Sounds = require(script.Parent.Sounds)
local HUD = require(script.Parent.HUD)
local Drive = require(script.Parent.DriveController)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local F, C = Theme.Fonts, Theme.Colors
local new = Theme.new
local label = Theme.Label

local Rewards = {}

local gui: ScreenGui = new("ScreenGui", { Name = "WantedUnboundRewards", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 22, Enabled = false }, player:WaitForChild("PlayerGui"))
local backdrop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 4, 10), BackgroundTransparency = 0.5, BorderSizePixel = 0 }, gui)
local confettiLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 }, gui)

local W, H = 560, 470
local holder: CanvasGroup = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W + 10, H + 10), BackgroundTransparency = 1 }, gui)
Scale.Attach(holder)
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H) }, holder)
Theme.Panel(panel, C.Gold, 18)
local stroke = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
local body = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, panel)

local continueButton = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(220, 44), BackgroundColor3 = C.Pink, Text = "CONTINUE", TextScaled = true, FontFace = F.Heading, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, ZIndex = 3 }, panel)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, continueButton)
new("UIPadding", { PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11) }, continueButton)
new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210)), Rotation = 90 }, continueButton)

local isOpen = false
local token = 0
local queue: { () -> () } = {}

local function clearBody()
	for _, c in body:GetChildren() do
		c:Destroy()
	end
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	token += 1
	Theme.Popup(gui, backdrop, holder, false)
	Sounds.Tick(0.9, 0.4)
	-- next queued screen
	task.delay(0.35, function()
		local nextScreen = table.remove(queue, 1)
		if nextScreen then
			nextScreen()
		end
	end)
end
continueButton.Activated:Connect(close)

local function open(accent: Color3, autoClose: number)
	isOpen = true
	token += 1
	local my = token
	stroke.Color = accent
	Theme.Popup(gui, backdrop, holder, true)
	Theme.Pop(continueButton, 0.6)
	task.delay(autoClose, function()
		if token == my then
			close()
		end
	end)
end

-- show now, or after the current screen / menus / cutscenes
local function present(show: () -> ())
	if isOpen then
		table.insert(queue, show)
		return
	end
	task.spawn(function()
		while Drive.MenuOpen or Drive.Cinematic do
			task.wait(0.5)
		end
		if isOpen then
			table.insert(queue, show)
		else
			show()
		end
	end)
end

-- number that counts up from 0
local function countUp(l: TextLabel, target: number, prefix: string, suffix: string, delay: number, time: number)
	l.Text = prefix .. "0" .. suffix
	task.delay(delay, function()
		local t0 = os.clock()
		local ticks = 0
		while l.Parent do
			local k = math.clamp((os.clock() - t0) / time, 0, 1)
			local e = 1 - (1 - k) ^ 3
			l.Text = prefix .. HUD.Commas(math.floor(target * e + 0.5)) .. suffix
			ticks += 1
			if ticks % 3 == 0 and k < 1 then
				Sounds.Tick(1.5 + k * 0.6, 0.12)
			end
			if k >= 1 then
				break
			end
			task.wait()
		end
		Theme.Pop(l, 1.25)
	end)
end

local CONFETTI = { C.Gold, C.Pink, C.Cyan, C.Green, C.Orange, C.Purple }
local function confetti(count: number)
	local cam = workspace.CurrentCamera
	local vp = cam.ViewportSize
	for _ = 1, count do
		local size = math.random(6, 12)
		local piece = new("Frame", {
			Position = UDim2.fromOffset(math.random(0, math.floor(vp.X)), -20),
			Size = UDim2.fromOffset(size, size * 0.6),
			BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 20,
		}, confettiLayer)
		local fall = 1.6 + math.random() * 1.4
		local drift = math.random(-120, 120)
		local delay = math.random() * 0.6
		task.delay(delay, function()
			Theme.Tween(piece, fall, {
				Position = UDim2.fromOffset(piece.Position.X.Offset + drift, vp.Y + 30),
				Rotation = piece.Rotation + math.random(-540, 540),
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(fall, function()
				piece:Destroy()
			end)
		end)
	end
end

---------------------------------------------------------------------------
-- Race results
---------------------------------------------------------------------------
local function ordinal(n: number): string
	local suffix = if n == 1 then "ST" elseif n == 2 then "ND" elseif n == 3 then "RD" else "TH"
	return n .. suffix
end

local function showResult(r: any)
	clearBody()
	local win = r.win == true
	local accent = if win then C.Gold else C.Red
	local title = label({ Position = UDim2.fromOffset(28, 22), Size = UDim2.new(1, -56, 0, 34), Text = tostring(r.title), FontFace = F.Display, TextXAlignment = Enum.TextXAlignment.Center }, body)
	new("UIGradient", { Color = if win then ColorSequence.new(C.Gold, C.Orange) else ColorSequence.new(C.Red, C.Pink) }, title)
	label({ Position = UDim2.fromOffset(28, 60), Size = UDim2.new(1, -56, 0, 18), Text = string.upper(tostring(r.event)), FontFace = F.Light, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center }, body)

	-- big place medal (or score for drift / takeover events)
	local medal = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.25, 0, 0, 96), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = accent }, body)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, medal)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 150)), Rotation = 45 }, medal)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 0.3 }, medal)
	local medalText = if r.scored then HUD.Commas(r.score or 0) else ordinal(r.place or 1)
	label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.4), Text = medalText, FontFace = F.Display, TextColor3 = Color3.fromRGB(20, 16, 10), TextXAlignment = Enum.TextXAlignment.Center }, medal)
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(0.7, 0.12), Text = if r.scored then "TARGET " .. HUD.Commas(r.target or 0) else "OF " .. tostring(r.racers or 1), FontFace = F.Heading, TextColor3 = Color3.fromRGB(40, 30, 20), TextXAlignment = Enum.TextXAlignment.Center }, medal)
	Theme.Pop(medal, 0.2)
	medal.Rotation = -25
	Theme.Tween(medal, 0.6, { Rotation = 0 }, Enum.EasingStyle.Back)

	-- stat rows
	local rows = new("Frame", { Position = UDim2.new(0.5, 10, 0, 100), Size = UDim2.new(0.5, -38, 0, 150), BackgroundTransparency = 1 }, body)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rows)
	local function stat(order: number, name: string, color: Color3): TextLabel
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.PanelLight, BackgroundTransparency = 0.3, LayoutOrder = order }, rows)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, row)
		label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(0.5, -10, 1, -12), Text = name, FontFace = F.Heading, TextColor3 = C.Dim }, row)
		local value = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5), Size = UDim2.new(0.5, 0, 1, -10), Text = "", FontFace = F.Display, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right }, row)
		local pad = new("UIPadding", { PaddingLeft = UDim.new(0, 40) }, row)
		row.BackgroundTransparency = 1
		task.delay(0.25 + order * 0.12, function()
			Theme.Tween(pad, 0.4, { PaddingLeft = UDim.new(0, 0) }, Enum.EasingStyle.Back)
			Theme.Tween(row, 0.3, { BackgroundTransparency = 0.3 })
		end)
		return value
	end
	local timeValue = stat(1, "TIME", C.Text)
	timeValue.Text = string.format("%d:%05.2f", math.floor((r.time or 0) / 60), (r.time or 0) % 60)
	countUp(stat(2, "CASH", C.Green), r.cash or 0, "$", "", 0.6, 1.2)
	countUp(stat(3, "REP", C.Purple), r.rep or 0, "+", "", 0.8, 1.0)
	local heatValue = stat(4, "HEAT", C.Red)
	heatValue.Text = string.rep("★", r.heat or 0) .. string.rep("☆", 5 - (r.heat or 0))

	-- final order
	local standings = r.standings or {}
	if #standings > 0 then
		local list = new("Frame", { Position = UDim2.fromOffset(28, 268), Size = UDim2.new(1, -56, 0, 120), BackgroundTransparency = 1 }, body)
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 26), CellPadding = UDim2.fromOffset(12, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		for k, name in standings do
			local mine = name == "YOU"
			local cell = new("Frame", { BackgroundColor3 = if mine then Color3.fromRGB(16, 50, 70) else C.PanelLight, BackgroundTransparency = 0.25, LayoutOrder = k }, list)
			new("UICorner", { CornerRadius = UDim.new(0, 6) }, cell)
			label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = k .. ".  " .. string.upper(tostring(name)), FontFace = if mine then F.Heading else F.Body, TextColor3 = if mine then C.Cyan else C.Text }, cell)
			cell.BackgroundTransparency = 1
			task.delay(0.9 + k * 0.08, function()
				Theme.Tween(cell, 0.25, { BackgroundTransparency = 0.25 })
				Theme.Pop(cell, 0.7)
			end)
		end
	end
	open(accent, 12)
	if win then
		confetti(70)
		Sounds.Play("rbxasset://sounds/action_jump.mp3", 0.5, 1.4)
	end
end

---------------------------------------------------------------------------
-- Daily reward
---------------------------------------------------------------------------
local function showDaily(d: any)
	clearBody()
	local title = label({ Position = UDim2.fromOffset(28, 24), Size = UDim2.new(1, -56, 0, 34), Text = "DAILY REWARD", FontFace = F.Display, TextXAlignment = Enum.TextXAlignment.Center }, body)
	new("UIGradient", { Color = ColorSequence.new(C.Cyan, C.Pink) }, title)
	label({ Position = UDim2.fromOffset(28, 62), Size = UDim2.new(1, -56, 0, 18), Text = "Come back every day - the streak pays more", FontFace = F.Light, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center }, body)
	local rewards = d.rewards or {}
	local day = math.min(d.day or 1, #rewards)
	local track = new("Frame", { Position = UDim2.fromOffset(24, 104), Size = UDim2.new(1, -48, 0, 120), BackgroundTransparency = 1 }, body)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, track)
	for k, amount in rewards do
		local past = k < day
		local today = k == day
		local tile = new("Frame", { Size = UDim2.new(1 / #rewards, -6, 1, 0), BackgroundColor3 = if today then C.Gold elseif past then Color3.fromRGB(30, 70, 50) else C.PanelLight, BackgroundTransparency = if today then 0 else 0.25, LayoutOrder = k }, track)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, tile)
		local dark = today
		label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 16), Text = "DAY " .. k, FontFace = F.Heading, TextColor3 = if dark then Color3.fromRGB(30, 20, 5) else C.Dim, TextXAlignment = Enum.TextXAlignment.Center }, tile)
		label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(1, -8, 0, 22), Text = if past then "✓" else "$" .. HUD.Commas(amount), FontFace = F.Display, TextColor3 = if dark then Color3.fromRGB(30, 20, 5) elseif past then C.Green else C.Text, TextXAlignment = Enum.TextXAlignment.Center }, tile)
		if today then
			new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, tile)
			task.delay(0.5, function()
				Theme.Pop(tile, 1.35)
			end)
		end
	end
	local big = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 250), Size = UDim2.fromOffset(360, 60), Text = "", FontFace = F.Display, TextColor3 = C.Green, TextXAlignment = Enum.TextXAlignment.Center }, body)
	countUp(big, d.amount or 0, "+$", "", 0.7, 1.3)
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 316), Size = UDim2.fromOffset(360, 22), Text = "+" .. tostring(d.rep or 0) .. " REP   ·   DAY " .. tostring(d.day or 1) .. " STREAK", FontFace = F.Heading, TextColor3 = C.Purple, TextXAlignment = Enum.TextXAlignment.Center }, body)
	open(C.Cyan, 10)
	confetti(40)
end

local raceResultEvent = Remotes:WaitForChild("RaceResult") :: RemoteEvent
raceResultEvent.OnClientEvent:Connect(function(r: any)
	if type(r) ~= "table" then
		return
	end
	-- let the big banner play first
	task.delay(1.6, function()
		present(function()
			showResult(r)
		end)
	end)
end)

local dailyEvent = Remotes:WaitForChild("DailyReward") :: RemoteEvent
dailyEvent.OnClientEvent:Connect(function(d: any)
	if type(d) == "table" then
		present(function()
			showDaily(d)
		end)
	end
end)

ContextActionService:BindActionAtPriority("WU_RewardsClose", function(_, state)
	if state ~= Enum.UserInputState.Begin or not isOpen then
		return Enum.ContextActionResult.Pass
	end
	close()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Return, Enum.KeyCode.ButtonB)

return Rewards
