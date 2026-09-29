--!strict
-- Safehouse garage: buy / select cars, upgrades, paint, driving effects and the Blacklist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Shop = Remotes:WaitForChild("Shop") :: RemoteFunction
local ChallengeRival = Remotes:WaitForChild("ChallengeRival") :: RemoteEvent

local HUD = require(script.Parent.HUD)

local Garage = {}
Garage.Open = false
Garage.Toggle = function(_open: boolean?) end

local PINK = Color3.fromRGB(255, 40, 160)
local CYAN = Color3.fromRGB(0, 240, 255)
local PANEL = Color3.fromRGB(16, 16, 26)
local CARD = Color3.fromRGB(28, 28, 44)

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

local function corner(parent: Instance, r: number?)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		base[k] = v
	end
	return new("TextLabel", base, parent)
end

local function button(parent: Instance, props: { [string]: any }, onClick: () -> ()): TextButton
	local base = {
		BackgroundColor3 = PINK,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
	}
	for k, v in props do
		base[k] = v
	end
	local b = new("TextButton", base, parent)
	corner(b, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	b.Activated:Connect(onClick)
	return b
end

local window = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.8, 0, 0.75, 0),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 10,
}, HUD.Gui)
corner(window, 16)
new("UIStroke", { Color = PINK, Thickness = 3 }, window)
new("UISizeConstraint", { MaxSize = Vector2.new(900, 600), MinSize = Vector2.new(320, 300) }, window)

text(window, { Position = UDim2.fromOffset(20, 10), Size = UDim2.new(0.5, 0, 0, 36), Text = "SAFEHOUSE GARAGE", Font = Enum.Font.GothamBlack, TextColor3 = CYAN })
local cashText = text(window, { Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.5, -70, 0, 28), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(120, 255, 150) })
button(window, { Position = UDim2.new(1, -56, 0, 10), Size = UDim2.fromOffset(44, 36), Text = "X", BackgroundColor3 = Color3.fromRGB(80, 30, 50) }, function()
	Garage.Toggle(false)
end)

local tabs = new("Frame", { Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -40, 0, 36), BackgroundTransparency = 1 }, window)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, tabs)

local content = new("ScrollingFrame", {
	Position = UDim2.fromOffset(20, 102),
	Size = UDim2.new(1, -40, 1, -150),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BorderSizePixel = 0,
}, window)

local statusText = text(window, { Position = UDim2.new(0, 20, 1, -40), Size = UDim2.new(1, -40, 0, 26), Text = "", TextColor3 = Color3.fromRGB(255, 200, 80) })

local data: any = nil
local currentTab = "Cars"
local render: () -> ()

local function refresh()
	local ok, _, snap = Shop:InvokeServer("Get")
	if ok then
		data = snap
	end
end

local function act(action: string, a: any?, b: any?)
	local ok, msg, snap = Shop:InvokeServer(action, a, b)
	if snap then
		data = snap
	end
	statusText.Text = msg or ""
	statusText.TextColor3 = if ok then Color3.fromRGB(120, 255, 150) else Color3.fromRGB(255, 100, 100)
	render()
end

local function clear()
	for _, c in content:GetChildren() do
		c:Destroy()
	end
end

local function card(height: number): Frame
	local f = new("Frame", { Size = UDim2.new(1, -10, 0, height), BackgroundColor3 = CARD }, content)
	corner(f, 10)
	return f
end

local function statBar(parent: Instance, y: number, name: string, value: number, max: number)
	text(parent, { Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(80, 14), Text = name, TextColor3 = Color3.fromRGB(180, 180, 200) })
	local back = new("Frame", { Position = UDim2.fromOffset(96, y + 2), Size = UDim2.new(0.45, -96, 0, 10), BackgroundColor3 = Color3.fromRGB(50, 50, 70) }, parent)
	corner(back, 5)
	local fill = new("Frame", { Size = UDim2.fromScale(math.clamp(value / max, 0, 1), 1), BackgroundColor3 = CYAN }, back)
	corner(fill, 5)
end

local function renderCars()
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	for idx, car in Config.Cars do
		local owned = data.owned[car.id] == true
		if car.blacklistOnly and not owned then
			continue
		end
		local f = card(92)
		f.LayoutOrder = idx
		local swatch = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(12, 68), BackgroundColor3 = car.color }, f)
		corner(swatch, 4)
		text(f, { Position = UDim2.fromOffset(34, 8), Size = UDim2.new(0.5, 0, 0, 24), Text = car.name .. "   [" .. car.class .. "]", Font = Enum.Font.GothamBlack })
		local stats = Config.ComputeStats(car, data.upgrades[car.id])
		local holder = new("Frame", { Position = UDim2.fromOffset(22, 34), Size = UDim2.new(1, -22, 0, 56), BackgroundTransparency = 1 }, f)
		statBar(holder, 0, "Top speed", stats.maxSpeed, 240)
		statBar(holder, 18, "Accel", stats.accel, 90)
		statBar(holder, 36, "Handling", stats.turn * stats.grip, 21)
		local label, color, action
		if data.selected == car.id then
			label, color = "DRIVING", Color3.fromRGB(60, 60, 80)
		elseif owned then
			label, color, action = "SELECT", CYAN, function()
				act("SelectCar", car.id)
			end
		else
			label, color, action = "BUY $" .. HUD.Commas(car.price), PINK, function()
				act("BuyCar", car.id)
			end
		end
		button(f, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 40), Text = label, BackgroundColor3 = color }, action or function() end)
	end
end

local function renderUpgrades()
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local car = Config.GetCar(data.selected)
	if not car then
		return
	end
	local levels = data.upgrades[car.id] or {}
	local head = card(40)
	head.LayoutOrder = 0
	text(head, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), Text = "Tuning: " .. car.name, Font = Enum.Font.GothamBlack, TextColor3 = CYAN })
	for idx, kind in Config.UpgradeOrder do
		local up = (Config.Upgrades :: any)[kind]
		local lvl = levels[kind] or 0
		local f = card(64)
		f.LayoutOrder = idx
		text(f, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(0.5, 0, 0, 24), Text = up.name, Font = Enum.Font.GothamBlack })
		local pips = ""
		for k = 1, up.maxLevel do
			pips ..= if k <= lvl then "■ " else "□ "
		end
		text(f, { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(0.5, 0, 0, 20), Text = pips, TextColor3 = PINK })
		if lvl >= up.maxLevel then
			button(f, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 40), Text = "MAXED", BackgroundColor3 = Color3.fromRGB(60, 60, 80) }, function() end)
		else
			local cost = math.floor(up.cost[lvl + 1] * (Config.ClassCostMult[car.class] or 1))
			button(f, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 40), Text = "UPGRADE $" .. HUD.Commas(cost) }, function()
				act("Upgrade", car.id, kind)
			end)
		end
	end
end

local function renderPaint()
	new("UIGridLayout", { CellSize = UDim2.fromOffset(90, 90), CellPadding = UDim2.fromOffset(10, 10) }, content)
	for idx, color in Config.PaintColors do
		local b = button(content, { Text = "", BackgroundColor3 = color }, function()
			act("Paint", idx)
		end)
		b.LayoutOrder = idx
		new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = if data.paint[data.selected] == idx then 4 else 0 }, b)
	end
end

local function renderEffects()
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	for idx, e in Config.DrivingEffects do
		local f = card(56)
		f.LayoutOrder = idx
		local sw = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = e.color }, f)
		corner(sw, 16)
		text(f, { Position = UDim2.fromOffset(56, 14), Size = UDim2.new(0.5, 0, 0, 26), Text = e.name, Font = Enum.Font.GothamBlack })
		local label, color = "", PINK
		if data.effect == e.id then
			label, color = "EQUIPPED", Color3.fromRGB(60, 60, 80)
		elseif data.effects[e.id] then
			label, color = "EQUIP", CYAN
		else
			label = "BUY $" .. HUD.Commas(e.price)
		end
		button(f, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 38), Text = label, BackgroundColor3 = color }, function()
			act("Effect", e.id)
		end)
	end
end

local function renderBlacklist()
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local head = card(50)
	head.LayoutOrder = 0
	text(head, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 38),
		Text = string.format("THE BLACKLIST   -   Your bounty: %s   |   Race wins: %d", HUD.Commas(data.totalBounty), data.racesWon),
		TextColor3 = Color3.fromRGB(255, 90, 90),
		Font = Enum.Font.GothamBlack,
	})
	local nextRank = 5 - data.blacklistBeaten
	for idx, rival in Config.Blacklist do
		local beaten = rival.rank > nextRank
		local f = card(96)
		f.LayoutOrder = idx
		text(f, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.6, 0, 0, 28), Text = "#" .. rival.rank .. "  " .. string.upper(rival.name), Font = Enum.Font.GothamBlack, TextColor3 = if beaten then Color3.fromRGB(120, 255, 150) else Color3.new(1, 1, 1) })
		text(f, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(0.65, 0, 0, 18), Text = rival.bio, TextColor3 = Color3.fromRGB(190, 190, 210), Font = Enum.Font.Gotham })
		local car = Config.GetCar(rival.carId)
		text(f, {
			Position = UDim2.fromOffset(12, 60),
			Size = UDim2.new(0.65, 0, 0, 18),
			Text = string.format("Needs %s bounty + %d wins   |   Pink slip: %s   |   $%s", HUD.Commas(rival.bountyReq), rival.winsReq, if car then car.name else "?", HUD.Commas(rival.reward)),
			TextColor3 = Color3.fromRGB(255, 200, 80),
			Font = Enum.Font.Gotham,
		})
		local label, color = "LOCKED", Color3.fromRGB(60, 60, 80)
		local canRace = false
		if beaten then
			label, color = "DEFEATED", Color3.fromRGB(40, 120, 70)
		elseif rival.rank == nextRank then
			if data.totalBounty >= rival.bountyReq and data.racesWon >= rival.winsReq then
				label, color, canRace = "CHALLENGE", Color3.fromRGB(255, 60, 60), true
			else
				label = "NEED MORE REP"
			end
		end
		button(f, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 40), Text = label, BackgroundColor3 = color }, function()
			if canRace then
				ChallengeRival:FireServer(rival.rank)
				Garage.Toggle(false)
			end
		end)
	end
end

local TAB_RENDER = {
	Cars = renderCars,
	Upgrades = renderUpgrades,
	Paint = renderPaint,
	Effects = renderEffects,
	Blacklist = renderBlacklist,
}
local tabButtons: { [string]: TextButton } = {}

render = function()
	clear()
	if not data then
		return
	end
	cashText.Text = "$" .. HUD.Commas(data.cash)
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then PINK else Color3.fromRGB(45, 45, 65)
	end
	TAB_RENDER[currentTab]()
end

for _, name in { "Cars", "Upgrades", "Paint", "Effects", "Blacklist" } do
	tabButtons[name] = button(tabs, { Size = UDim2.fromOffset(120, 34), Text = string.upper(name), BackgroundColor3 = Color3.fromRGB(45, 45, 65) }, function()
		currentTab = name
		render()
	end)
end

function Garage.Toggle(open: boolean?)
	local want = if open == nil then not window.Visible else open
	window.Visible = want
	Garage.Open = want
	if want then
		statusText.Text = ""
		refresh()
		render()
	end
end

return Garage
