--!strict
-- Title screen: a slow camera flight over Neon Bay with the logo, PLAY and HOW TO PLAY.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Drive = require(script.Parent.DriveController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Menu = {}

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

local gui = new("ScreenGui", { Name = "WantedUnboundMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, player:WaitForChild("PlayerGui"))
local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0 }, gui)
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 0.1),
	}),
}, shade)

local logo = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(820, 220),
	BackgroundTransparency = 1,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(820, 220) }, logo)
new("UIAspectRatioConstraint", { AspectRatio = 820 / 220 }, logo)
new("TextLabel", {
	Size = UDim2.fromScale(1, 0.52),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	Text = "WANTED",
	TextColor3 = Color3.fromRGB(255, 50, 60),
	TextStrokeTransparency = 0,
	TextStrokeColor3 = Color3.fromRGB(40, 0, 10),
}, logo)
new("TextLabel", {
	Position = UDim2.fromScale(0, 0.48),
	Size = UDim2.fromScale(1, 0.38),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	Text = "U N B O U N D",
	TextColor3 = Color3.fromRGB(0, 240, 255),
	TextStrokeTransparency = 0,
	TextStrokeColor3 = Color3.fromRGB(0, 30, 50),
}, logo)
new("TextLabel", {
	Position = UDim2.fromScale(0, 0.88),
	Size = UDim2.fromScale(1, 0.12),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	Text = "Race.  Raise your heat.  Escape the cops.  Climb the Blacklist.",
	TextColor3 = Color3.fromRGB(230, 230, 240),
}, logo)

local buttons = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.fromOffset(320, 130),
	BackgroundTransparency = 1,
}, gui)
new("UIListLayout", { Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }, buttons)

local function button(text: string, color: Color3): TextButton
	local b = new("TextButton", {
		Size = UDim2.fromOffset(320, 58),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
	}, buttons)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, b)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end

local playButton = button("PLAY", Color3.fromRGB(255, 40, 120))
local helpButton = button("HOW TO PLAY", Color3.fromRGB(40, 40, 70))

local help = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(640, 400),
	BackgroundColor3 = Color3.fromRGB(12, 12, 22),
	BackgroundTransparency = 0.05,
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 14) }, help)
new("UIStroke", { Color = Color3.fromRGB(0, 240, 255), Thickness = 2 }, help)
new("UISizeConstraint", { MaxSize = Vector2.new(640, 400) }, help)
new("TextLabel", {
	Position = UDim2.fromOffset(24, 16),
	Size = UDim2.new(1, -48, 1, -80),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 17,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(230, 230, 240),
	RichText = true,
	Text = table.concat({
		"<b>CONTROLS</b>",
		"WASD / arrows: drive     SPACE: drift     SHIFT: nitro",
		"R: reset car     E: interact     G: garage",
		"",
		"<b>THE LOOP</b>",
		"1. <b>Race</b> at the pink markers. Winnings grow with your heat and at night.",
		"2. <b>Weave through traffic</b> for near misses: cash + nitro.",
		"3. <b>Escape the cops</b>: break line of sight, then hide until cooldown ends. Hiding spots cool you down 3x faster. Watch out for roadblocks and spike strips.",
		"4. <b>Bank your cash</b> at the safehouse. If you get busted you lose everything unbanked.",
		"5. <b>Tune your car</b> in the garage and <b>climb the Blacklist</b> to win pink slips.",
		"",
		"Follow the floating arrow: it always points to what matters next.",
	}, "\n"),
}, help)
local closeHelp = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(200, 44),
	BackgroundColor3 = Color3.fromRGB(0, 180, 200),
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	Text = "GOT IT",
	TextColor3 = Color3.new(1, 1, 1),
}, help)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, closeHelp)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, closeHelp)

helpButton.Activated:Connect(function()
	help.Visible = true
	buttons.Visible = false
end)
closeHelp.Activated:Connect(function()
	help.Visible = false
	buttons.Visible = true
end)

new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(500, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextScaled = true,
	Text = Config.GameName .. "  -  a street racing fan game",
	TextColor3 = Color3.fromRGB(160, 160, 180),
}, gui)

-- camera flight
Drive.MenuOpen = true
local angle = math.random() * math.pi * 2
local conn = RunService.RenderStepped:Connect(function(dt: number)
	angle += dt * 0.05
	camera.CameraType = Enum.CameraType.Scriptable
	local radius = 900
	local pos = Vector3.new(math.cos(angle) * radius, 320, math.sin(angle) * radius)
	local look = Vector3.new(math.cos(angle + 0.9) * 250, 40, math.sin(angle + 0.9) * 250)
	camera.CFrame = CFrame.lookAt(pos, look)
	camera.FieldOfView = 60
end)

playButton.Activated:Connect(function()
	conn:Disconnect()
	Drive.MenuOpen = false
	local fade = TweenInfo.new(0.5)
	TweenService:Create(shade, fade, { BackgroundTransparency = 1 }):Play()
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			TweenService:Create(d, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		if d:IsA("TextButton") or (d:IsA("Frame") and d.BackgroundTransparency < 1) then
			TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
		end
	end
	task.delay(0.55, function()
		gui:Destroy()
	end)
end)

return Menu
