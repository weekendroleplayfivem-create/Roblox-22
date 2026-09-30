--!strict
-- Full-screen city map (press M): districts, roads, races with names, hiding spots, the
-- safehouse, police and your car.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapDraw = require(script.Parent.MapDraw)
local Drive = require(script.Parent.DriveController)
local Sounds = require(script.Parent.Sounds)
local Scale = require(script.Parent.Scale)

local player = Players.LocalPlayer
local FullMap = {}
FullMap.Open = false

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

local gui = new("ScreenGui", { Name = "WantedUnboundMap", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15, Enabled = false }, player:WaitForChild("PlayerGui"))
new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0 }, gui)

local PANEL = 640
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL, PANEL),
	BackgroundColor3 = Color3.fromRGB(10, 10, 16),
	ClipsDescendants = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, panel)
new("UIStroke", { Color = Color3.fromRGB(255, 40, 160), Thickness = 3 }, panel)
new("UIAspectRatioConstraint", { AspectRatio = 1 }, panel)
new("UISizeConstraint", { MaxSize = Vector2.new(PANEL, PANEL) }, panel)
Scale.Attach(panel)

local canvas: Frame = new("Frame", { Name = "Canvas", BackgroundTransparency = 1 }, panel)
local total = MapDraw.WorldSize + MapDraw.Margin * 2
local px = MapDraw.Draw(canvas, PANEL / total, true)

new("TextLabel", {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.fromOffset(360, 30),
	BackgroundTransparency = 1,
	Text = "NEON BAY",
	TextScaled = true,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(0, 240, 255),
	TextStrokeTransparency = 0.3,
	ZIndex = 10,
}, panel)
new("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -10),
	Size = UDim2.new(1, -32, 0, 18),
	BackgroundTransparency = 1,
	Text = "S safehouse    H hiding spot    R race    red dot = pursuit breaker    gold = Beltway    [M] close",
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(220, 220, 230),
	TextStrokeTransparency = 0.3,
	ZIndex = 10,
}, panel)

local me = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Text = "▲",
	TextScaled = true,
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(0, 240, 255),
	TextStrokeTransparency = 0,
	ZIndex = 12,
}, canvas)
local copDots: { Frame } = {}

function FullMap.Toggle(open: boolean?)
	local want = if open == nil then not FullMap.Open else open
	FullMap.Open = want
	gui.Enabled = want
	Sounds.Tick(if want then 1.1 else 0.9, 0.4)
end

ContextActionService:BindAction("WU_Map", function(_, state)
	if state == Enum.UserInputState.Begin then
		FullMap.Toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.DPadUp)

RunService.RenderStepped:Connect(function()
	if not FullMap.Open then
		return
	end
	local car = Drive.Car
	local root = car and car.PrimaryPart
	if root then
		local p = px(root.Position)
		me.Position = UDim2.fromOffset(p.X, p.Y)
		local look = root.CFrame.LookVector
		me.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end
	local used = 0
	local police = workspace:FindFirstChild("Police")
	if police then
		for _, m in police:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart and m.Name ~= "Roadblock" then
				used += 1
				local d = copDots[used]
				if not d then
					d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, ZIndex = 11 }, canvas)
					copDots[used] = d
				end
				local p = px(m.PrimaryPart.Position)
				d.Position = UDim2.fromOffset(p.X, p.Y)
				d.BackgroundColor3 = if math.floor(os.clock() * 5) % 2 == 0 then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(70, 140, 255)
				d.Visible = true
			end
		end
	end
	for k = used + 1, #copDots do
		copDots[k].Visible = false
	end
end)

local _ = Config
return FullMap
