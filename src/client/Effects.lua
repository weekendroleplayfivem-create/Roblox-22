--!strict
-- Screen and audio effects: big animated banners, speed lines, nitro blur / colour grading,
-- near-miss popups, crash flashes, checkpoint pings, engine + siren loops and a GPS arrow
-- that points to your next checkpoint, the nearest hiding spot or the safehouse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BannerEvent = Remotes:WaitForChild("Banner") :: RemoteEvent

local Drive = require(script.Parent.DriveController)
local HUD = require(script.Parent.HUD)
local Sounds = require(script.Parent.Sounds)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Effects = {}

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

---------------------------------------------------------------------------
-- Banners (BUSTED / ESCAPED / 1ST PLACE ...)
---------------------------------------------------------------------------
local fxGui = new("ScreenGui", { Name = "WantedUnboundFX", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

local banner = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(760, 150),
	BackgroundTransparency = 1,
	Visible = false,
}, fxGui)
local bannerScale = new("UIScale", { Scale = 1 }, banner)
local bannerBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1.2, 0, 0, 110),
	BackgroundColor3 = Color3.fromRGB(8, 8, 14),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, banner)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, bannerBar)
local bannerLine = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 52),
	Size = UDim2.new(0.8, 0, 0, 4),
	BorderSizePixel = 0,
}, banner)
local bannerTitle = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -12),
	Size = UDim2.new(1, 0, 0, 78),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextStrokeTransparency = 0.2,
	Text = "",
}, banner)
local bannerSub = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 36),
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(230, 230, 240),
	TextStrokeTransparency = 0.4,
	Text = "",
}, banner)
new("UISizeConstraint", { MaxSize = Vector2.new(760, 150) }, banner)

local bannerToken = 0
function Effects.Banner(title: string, subtitle: string, color: Color3)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSub.Text = subtitle
	bannerLine.BackgroundColor3 = color
	banner.Visible = true
	bannerScale.Scale = 1.8
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	local info = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(bannerScale, info, { Scale = 1 }):Play()
	TweenService:Create(bannerTitle, info, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	Sounds.Tick(0.7, 0.6)
	task.delay(0.12, Sounds.Tick, 1.05, 0.6)
	task.delay(2.6, function()
		if token ~= bannerToken then
			return
		end
		local out = TweenInfo.new(0.4)
		TweenService:Create(bannerTitle, out, { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, out, { TextTransparency = 1 }):Play()
		task.wait(0.4)
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

BannerEvent.OnClientEvent:Connect(function(title: string, subtitle: string, color: Color3)
	Effects.Banner(title, subtitle, color)
end)

---------------------------------------------------------------------------
-- Near miss popup + crash flash
---------------------------------------------------------------------------
local nearLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.64),
	Size = UDim2.fromOffset(420, 46),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(0, 240, 255),
	TextStrokeTransparency = 0.1,
	Text = "",
	TextTransparency = 1,
}, fxGui)
local nearScale = new("UIScale", {}, nearLabel)

table.insert(Drive.OnNearMiss, function(combo: number)
	nearLabel.Text = if combo > 1 then ("NEAR MISS  x" .. combo) else "NEAR MISS"
	nearLabel.TextTransparency = 0
	nearScale.Scale = 1.5
	TweenService:Create(nearScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local token = combo
	task.delay(1.2, function()
		if Drive.NearMissCombo == token then
			TweenService:Create(nearLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end)

local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 }, fxGui)
table.insert(Drive.OnCrash, function(strength: number)
	flash.BackgroundTransparency = 1 - strength * 0.35
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end)


---------------------------------------------------------------------------
-- Speed lines
---------------------------------------------------------------------------
local lineHolder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, fxGui)
type Line = { frame: Frame, angle: number, r: number, len: number }
local lines: { Line } = {}
for _ = 1, 32 do
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
	}, lineHolder)
	table.insert(lines, { frame = f, angle = math.random() * math.pi * 2, r = math.random(), len = math.random(60, 200) })
end

---------------------------------------------------------------------------
-- Post effects (local, parented to the camera)
---------------------------------------------------------------------------
local blur = new("BlurEffect", { Size = 0 }, camera)
local grade = new("ColorCorrectionEffect", { Saturation = 0, Contrast = 0 }, camera)

---------------------------------------------------------------------------
-- GPS arrow
---------------------------------------------------------------------------
local arrow = new("Model", { Name = "GPSArrow" })
local shaft = new("Part", {
	Name = "Shaft",
	Size = Vector3.new(0.7, 0.25, 3.2),
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(0, 240, 255),
	Transparency = 0.15,
}, arrow)
local head = new("Part", {
	Name = "Head",
	Size = Vector3.new(2, 0.25, 2),
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(0, 240, 255),
	Transparency = 0.15,
}, arrow)
local gpsGui = new("BillboardGui", { Size = UDim2.fromOffset(220, 30), StudsOffset = Vector3.new(0, 1.6, 0), AlwaysOnTop = true, LightInfluence = 0 }, shaft)
local gpsText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.2,
}, gpsGui)

local sh = Config.Blocks.Safehouse
local SAFEHOUSE = Grid.BlockCenter(sh[1], sh[2])

local function gpsTarget(pos: Vector3): (Vector3?, string, Color3)
	local nextCp = player:GetAttribute("RaceNext")
	if player:GetAttribute("RaceActive") and player:GetAttribute("RaceKind") ~= "drift" and typeof(nextCp) == "Vector3" and nextCp.Magnitude > 0 then
		return nextCp, "CHECKPOINT", Color3.fromRGB(255, 230, 40)
	end
	local mode = player:GetAttribute("PursuitMode")
	if mode == "cooldown" and not player:GetAttribute("Hiding") then
		local best, bestD = nil, math.huge
		for _, h in Config.Blocks.HidingSpots do
			local p = Grid.BlockCenter(h[1], h[2])
			local d = (p - pos).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
		return best, "HIDING SPOT", Color3.fromRGB(80, 255, 120)
	end
	local unbanked = player:GetAttribute("Unbanked")
	if mode == "idle" and not player:GetAttribute("AtSafehouse") and type(unbanked) == "number" and unbanked > 0 then
		return SAFEHOUSE, "SAFEHOUSE - bank $" .. HUD.Commas(unbanked), Color3.fromRGB(0, 255, 200)
	end
	return nil, "", Color3.new(1, 1, 1)
end

local function updateArrow()
	local car = Drive.Car
	local root = car and car.PrimaryPart
	if not root or Drive.MenuOpen then
		arrow.Parent = nil
		return
	end
	local pos = root.Position
	local target, label, color = gpsTarget(pos)
	if not target then
		arrow.Parent = nil
		return
	end
	local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	local dist = flat.Magnitude
	if dist < 30 then
		arrow.Parent = nil
		return
	end
	local bob = math.sin(os.clock() * 3) * 0.3
	local base = pos + Vector3.new(0, 7.5 + bob, 0)
	local cf = CFrame.lookAt(base, base + flat.Unit)
	shaft.CFrame = cf
	head.CFrame = cf * CFrame.new(0, 0, -2.1) * CFrame.Angles(0, math.rad(45), 0)
	shaft.Color = color
	head.Color = color
	gpsText.Text = string.format("%s  %dm", label, math.floor(dist * 0.35))
	gpsText.TextColor3 = color
	arrow.Parent = camera
end

---------------------------------------------------------------------------
-- Per-frame
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt: number)
	local speed = Drive.Speed
	local nitro = Drive.NitroOn
	local intensity = math.clamp((speed - 130) / 90, 0, 1)
	if nitro then
		intensity = math.max(intensity, 0.8)
	end
	if Drive.MenuOpen then
		intensity = 0
	end

	-- speed lines stream outward from the screen centre
	local size = fxGui.AbsoluteSize
	local cx, cy = size.X / 2, size.Y / 2
	local maxR = math.sqrt(cx * cx + cy * cy)
	for _, l in lines do
		l.r += dt * (0.6 + intensity * 2.2)
		if l.r > 1 then
			l.r = 0.35 + math.random() * 0.2
			l.angle = math.random() * math.pi * 2
			l.len = math.random(60, 220)
		end
		local r = l.r * maxR
		l.frame.Position = UDim2.fromOffset(cx + math.cos(l.angle) * r, cy + math.sin(l.angle) * r)
		l.frame.Size = UDim2.fromOffset(l.len * (0.5 + intensity), 2)
		l.frame.Rotation = math.deg(l.angle)
		l.frame.BackgroundTransparency = 1 - intensity * 0.55 * l.r
		l.frame.BackgroundColor3 = if nitro then Color3.fromRGB(170, 240, 255) else Color3.new(1, 1, 1)
	end

	-- nitro blur + grading
	local blurTarget = if nitro then 5 else intensity * 2
	blur.Size += (blurTarget - blur.Size) * math.min(1, dt * 6)
	local satTarget = if nitro then 0.3 else 0
	grade.Saturation += (satTarget - grade.Saturation) * math.min(1, dt * 5)
	grade.Contrast += ((if nitro then 0.12 else 0) - grade.Contrast) * math.min(1, dt * 5)
	grade.TintColor = (grade.TintColor :: Color3):Lerp(if Drive.Flat then Color3.fromRGB(255, 225, 215) elseif nitro then Color3.fromRGB(225, 245, 255) else Color3.new(1, 1, 1), math.min(1, dt * 5))

	updateArrow()
end)

return Effects
