--!strict
-- Leaderboard screen (press L / D-pad → or the trophy button): everyone on this server, plus the
-- all-time Most Wanted boards for total bounty and REP.

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Scale = require(script.Parent.Scale)
local Sounds = require(script.Parent.Sounds)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local F, C = Theme.Fonts, Theme.Colors
local new = Theme.new
local label = Theme.Label

local LeaderboardUI = {}
LeaderboardUI.Open = false

local gui: ScreenGui = new("ScreenGui", { Name = "WantedUnboundLeaderboard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 25, Enabled = false }, player:WaitForChild("PlayerGui"))
local backdrop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 4, 10), BackgroundTransparency = 0.4, BorderSizePixel = 0 }, gui)

local W, H = 760, 560
local holder: CanvasGroup = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W + 10, H + 10), BackgroundTransparency = 1 }, gui)
Scale.Attach(holder)
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H) }, holder)
Theme.Panel(panel, C.Gold, 18)

-- header
local title = label({ Position = UDim2.fromOffset(28, 20), Size = UDim2.fromOffset(460, 40), Text = "LEADERBOARD", FontFace = F.Display }, panel)
new("UIGradient", { Color = ColorSequence.new(C.Gold, C.Orange) }, title)
local subtitle = label({ Position = UDim2.fromOffset(30, 62), Size = UDim2.fromOffset(460, 18), Text = "", FontFace = F.Light, TextColor3 = C.Dim }, panel)
local closeButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.PanelLight, Text = "✕", TextScaled = true, FontFace = F.Heading, TextColor3 = C.Text }, panel)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, closeButton)
new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9) }, closeButton)

-- tabs
type Tab = { id: string, name: string, button: TextButton }
local TABS = {
	{ id = "server", name = "THIS SERVER" },
	{ id = "bounty", name = "ALL-TIME BOUNTY" },
	{ id = "rep", name = "ALL-TIME REP" },
}
local tabs: { Tab } = {}
local current = "server"
local tabBar = new("Frame", { Position = UDim2.fromOffset(28, 94), Size = UDim2.new(1, -56, 0, 40), BackgroundColor3 = C.PanelLight, BackgroundTransparency = 0.3 }, panel)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, tabBar)
local highlight = new("Frame", { Size = UDim2.new(1 / #TABS, 0, 1, 0), BackgroundColor3 = C.Gold }, tabBar)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, highlight)
new("UIGradient", { Color = ColorSequence.new(C.Gold, C.Orange) }, highlight)

-- column headers
local head = new("Frame", { Position = UDim2.fromOffset(28, 146), Size = UDim2.new(1, -56, 0, 22), BackgroundTransparency = 1 }, panel)
local headLabels: { TextLabel } = {}
local COLS = { { x = 0.0, w = 0.08 }, { x = 0.09, w = 0.4 }, { x = 0.5, w = 0.14 }, { x = 0.65, w = 0.14 }, { x = 0.8, w = 0.2 } }
for k, col in COLS do
	headLabels[k] = label({ Position = UDim2.fromScale(col.x, 0), Size = UDim2.fromScale(col.w, 1), Text = "", FontFace = F.Heading, TextColor3 = C.Dim, TextXAlignment = if k >= 3 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left }, head)
end

-- rows
local ROWS = 10
type Row = { frame: Frame, cells: { TextLabel }, bar: Frame }
local rows: { Row } = {}
local listFrame = new("Frame", { Position = UDim2.fromOffset(28, 174), Size = UDim2.new(1, -56, 1, -214), BackgroundTransparency = 1 }, panel)
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
for r = 1, ROWS do
	local frame = new("Frame", { Size = UDim2.new(1, 0, 1 / ROWS, -5), BackgroundColor3 = C.PanelLight, BackgroundTransparency = 0.35, LayoutOrder = r }, listFrame)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
	local bar = new("Frame", { Size = UDim2.new(0, 4, 1, -10), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = C.Dim, BorderSizePixel = 0 }, frame)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
	local cellsHolder = new("Frame", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -26, 1, 0), BackgroundTransparency = 1 }, frame)
	local cells: { TextLabel } = {}
	for k, col in COLS do
		cells[k] = label({
			Position = UDim2.fromScale(col.x, 0.2),
			Size = UDim2.fromScale(col.w, 0.6),
			Text = "",
			FontFace = if k == 1 or k == 5 then F.Display else F.Body,
			TextXAlignment = if k >= 3 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		}, cellsHolder)
	end
	rows[r] = { frame = frame, cells = cells, bar = bar }
end
local empty = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 290), Size = UDim2.fromOffset(460, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim }, panel)
label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(500, 16), Text = "All-time boards refresh every minute   ·   [L] close", FontFace = F.Light, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center }, panel)

local RANK_COLORS = { C.Gold, Color3.fromRGB(215, 220, 235), Color3.fromRGB(215, 140, 80) }

local function decode(name: string, fallback: any): any
	local v = ReplicatedStorage:FindFirstChild(name)
	if not v or not v:IsA("StringValue") then
		return fallback
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(v.Value)
	end)
	return if ok and data ~= nil then data else fallback
end

type Line = { id: number, name: string, a: string, b: string, c: string }

local function render()
	local lines: { Line } = {}
	if current == "server" then
		subtitle.Text = "Everyone racing in Neon Bay right now"
		local heads = { "#", "RACER", "REP", "WINS", "BOUNTY" }
		for k, h in heads do
			headLabels[k].Text = h
		end
		local list = decode("LeaderboardServer", {})
		table.sort(list, function(x: any, y: any)
			return (x.bounty or 0) > (y.bounty or 0)
		end)
		for _, e in list do
			table.insert(lines, { id = e.id or 0, name = tostring(e.name), a = "LV " .. tostring(e.level or 1), b = tostring(e.races or 0), c = HUD.Commas(e.bounty or 0) })
		end
	else
		local data = decode("LeaderboardAllTime", {})
		local global = data.global == true
		subtitle.Text = if global then "The most wanted racers across every server" else "Global boards need API access - showing this server"
		local heads = { "#", "RACER", "", "", if current == "bounty" then "TOTAL BOUNTY" else "REP" }
		for k, h in heads do
			headLabels[k].Text = h
		end
		for _, e in data[current] or {} do
			local v = e.value or 0
			table.insert(lines, { id = e.id or 0, name = tostring(e.name), a = "", b = "", c = (if current == "bounty" then "$" else "") .. HUD.Commas(v) })
		end
	end
	for r, row in rows do
		local line = lines[r]
		row.frame.Visible = line ~= nil
		if line then
			local mine = line.id == player.UserId
			local rankColor = RANK_COLORS[r] or C.Dim
			row.cells[1].Text = tostring(r)
			row.cells[1].TextColor3 = rankColor
			row.cells[2].Text = string.upper(line.name) .. (if mine then "  (YOU)" else "")
			row.cells[2].TextColor3 = if mine then C.Cyan else C.Text
			row.cells[3].Text = line.a
			row.cells[4].Text = line.b
			row.cells[5].Text = line.c
			row.cells[5].TextColor3 = if r <= 3 then rankColor else C.Text
			row.bar.BackgroundColor3 = if mine then C.Cyan else rankColor
			row.frame.BackgroundColor3 = if mine then Color3.fromRGB(16, 50, 70) else C.PanelLight
		end
	end
	empty.Text = if #lines == 0 then "No scores yet - go earn some bounty!" else ""
end

local function selectTab(id: string, animate: boolean)
	current = id
	for k, t in tabs do
		local on = t.id == id
		t.button.TextColor3 = if on then Color3.fromRGB(20, 14, 4) else C.Dim
		if on then
			local pos = UDim2.new((k - 1) / #TABS, 0, 0, 0)
			if animate then
				Theme.Tween(highlight, 0.3, { Position = pos }, Enum.EasingStyle.Back)
			else
				highlight.Position = pos
			end
		end
	end
	-- rows cascade in
	render()
	if animate then
		for r, row in rows do
			row.frame.BackgroundTransparency = 1
			task.delay(r * 0.025, function()
				Theme.Tween(row.frame, 0.2, { BackgroundTransparency = 0.35 })
			end)
		end
	end
end

for k, def in TABS do
	local b = new("TextButton", {
		Position = UDim2.fromScale((k - 1) / #TABS, 0),
		Size = UDim2.fromScale(1 / #TABS, 1),
		BackgroundTransparency = 1,
		Text = def.name,
		TextScaled = true,
		FontFace = F.Heading,
		TextColor3 = C.Dim,
		ZIndex = 2,
	}, tabBar)
	new("UIPadding", { PaddingTop = UDim.new(0, 11), PaddingBottom = UDim.new(0, 11) }, b)
	b.Activated:Connect(function()
		Sounds.Tick(1.3, 0.35)
		selectTab(def.id, true)
	end)
	table.insert(tabs, { id = def.id, name = def.name, button = b })
end
selectTab("server", false)

function LeaderboardUI.Toggle(open: boolean?)
	local want = if open == nil then not LeaderboardUI.Open else open
	if want == LeaderboardUI.Open then
		return
	end
	LeaderboardUI.Open = want
	Sounds.Tick(if want then 1.2 else 0.9, 0.4)
	if want then
		selectTab(current, true)
	end
	Theme.Popup(gui, backdrop, holder, want)
end

closeButton.Activated:Connect(function()
	LeaderboardUI.Toggle(false)
end)

-- live refresh while open
for _, name in { "LeaderboardServer", "LeaderboardAllTime" } do
	task.spawn(function()
		local v = ReplicatedStorage:WaitForChild(name, 30)
		if v and v:IsA("StringValue") then
			v.Changed:Connect(function()
				if LeaderboardUI.Open then
					render()
				end
			end)
		end
	end)
end

ContextActionService:BindAction("WU_Leaderboard", function(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	LeaderboardUI.Toggle()
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.L, Enum.KeyCode.DPadRight)

-- ButtonL1/R1 only while open (RB is also fire), so bind them separately at a higher priority
ContextActionService:BindActionAtPriority("WU_LeaderboardTabs", function(_, state, input)
	if state ~= Enum.UserInputState.Begin or not LeaderboardUI.Open then
		return Enum.ContextActionResult.Pass
	end
	local idx = 1
	for k, t in tabs do
		if t.id == current then
			idx = k
		end
	end
	idx = (idx - 1 + (if input.KeyCode == Enum.KeyCode.ButtonR1 then 1 else -1)) % #tabs + 1
	selectTab(tabs[idx].id, true)
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)

return LeaderboardUI
