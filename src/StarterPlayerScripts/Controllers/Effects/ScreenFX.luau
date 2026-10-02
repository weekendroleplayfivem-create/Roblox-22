--[[
	ScreenFX
	2D / post-processing feedback:
	  * speed lines when moving fast (sprint-slide, dash, jump pads)
	  * edge vignette pulses (damage, shield, kills, abilities)
	  * low-health state: pulsing edges, desaturation, heartbeat
	  * short blur on dash, colour "pop" on eliminations
	  * scope overlay for scoped weapons, phase tint
	  * confetti bursts (level up, victory, purchases)
	Uses one ScreenGui and one render loop.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local FXUtil = require(script.Parent.FXUtil)

local ScreenFX = {}

local player = Players.LocalPlayer

local SPEED_LINE_COUNT = 22
local SPEED_THRESHOLD = 27
local SPEED_FULL = 60
local LOW_HEALTH_FRACTION = 0.35
local HEARTBEAT_INTERVAL = 0.9

local screen: ScreenGui
local vignette: Frame
local vignetteGradient: UIGradient
local tint: Frame
local scopeFrame: Frame
local speedLines: { { Frame: Frame, Angle: number, Offset: number } } = {}
local blur: BlurEffect
local grade: ColorCorrectionEffect
local speedSource = nil
local scoped = false
local lastHeartbeat = 0
local soundPlayer = nil

local function tween(instance: Instance, duration: number, goals)
	TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals):Play()
end

function ScreenFX:SetSpeedSource(source)
	speedSource = source
end

function ScreenFX:SetSoundPlayer(callback: (string) -> ())
	soundPlayer = callback
end

-- Coloured flash around the screen edges.
function ScreenFX:Pulse(color: Color3, strength: number, duration: number)
	vignette.BackgroundColor3 = color
	vignette.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	tween(vignette, duration, { BackgroundTransparency = 1 })
end

function ScreenFX:DashBlur()
	if FXUtil.Reduced() then
		return
	end
	blur.Size = 10
	tween(blur, 0.25, { Size = 0 })
end

-- Brief saturation/brightness pop when you get an elimination.
function ScreenFX:KillPop()
	grade.Saturation = 0.5
	grade.Brightness = 0.06
	tween(grade, 0.35, { Saturation = 0, Brightness = 0 })
end

function ScreenFX:SetScope(enabled: boolean)
	if scoped == enabled then
		return
	end
	scoped = enabled
	scopeFrame.Visible = enabled
end

function ScreenFX:SetPhaseTint(enabled: boolean, color: Color3?)
	tint.BackgroundColor3 = color or Color3.fromRGB(180, 120, 255)
	tween(tint, 0.25, { BackgroundTransparency = if enabled then 0.85 else 1 })
end

-- Colourful confetti falling from the top of the screen.
function ScreenFX:Confetti(count: number?)
	local amount = if FXUtil.Reduced() then 12 else (count or 40)
	for _ = 1, amount do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1)
		piece.Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18))
		piece.Position = UDim2.new(math.random(), 0, -0.05, 0)
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 20
		piece.Parent = screen
		local duration = 1.6 + math.random() * 1.2
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
			BackgroundTransparency = 0.3,
		}):Play()
		task.delay(duration, function()
			piece:Destroy()
		end)
	end
end

local function buildSpeedLines()
	for index = 1, SPEED_LINE_COUNT do
		local angle = (index / SPEED_LINE_COUNT) * math.pi * 2 + math.random() * 0.2
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromOffset(math.random(80, 180), 2)
		frame.Rotation = math.deg(angle)
		frame.Parent = screen
		table.insert(speedLines, { Frame = frame, Angle = angle, Offset = math.random() })
	end
end

local function buildScope()
	scopeFrame = Instance.new("Frame")
	scopeFrame.Name = "Scope"
	scopeFrame.Size = UDim2.fromScale(1, 1)
	scopeFrame.BackgroundTransparency = 1
	scopeFrame.Visible = false
	scopeFrame.Parent = screen
	-- Dark edges.
	local edges = Instance.new("Frame")
	edges.Size = UDim2.fromScale(1, 1)
	edges.BackgroundColor3 = Color3.new(0, 0, 0)
	edges.BorderSizePixel = 0
	edges.Parent = scopeFrame
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.22, 0.05),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(0.78, 0.05),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Parent = edges
	-- Reticle ring + lines.
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.62, 0.62)
	ring.BackgroundTransparency = 1
	ring.Parent = scopeFrame
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 225, 255)
	stroke.Transparency = 0.2
	stroke.Parent = ring
	for _, data in { { UDim2.new(0, 2, 0.62, 0) }, { UDim2.new(0.62, 0, 0, 2) } } do
		local lineFrame = Instance.new("Frame")
		lineFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		lineFrame.Position = UDim2.fromScale(0.5, 0.5)
		lineFrame.Size = data[1]
		lineFrame.BackgroundColor3 = Color3.fromRGB(40, 225, 255)
		lineFrame.BackgroundTransparency = 0.4
		lineFrame.BorderSizePixel = 0
		lineFrame.Parent = scopeFrame
	end
end

local function update(deltaTime: number)
	-- Speed lines.
	local speed = if speedSource then speedSource:GetHorizontalSpeed() else 0
	local alpha = math.clamp((speed - SPEED_THRESHOLD) / (SPEED_FULL - SPEED_THRESHOLD), 0, 1)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local radius = math.max(viewport.X, viewport.Y) * 0.5
	for _, data in speedLines do
		if alpha <= 0 or FXUtil.Reduced() then
			data.Frame.BackgroundTransparency = 1
		else
			data.Offset = (data.Offset + deltaTime * (1.5 + alpha * 2)) % 1
			local distance = radius * (0.55 + data.Offset * 0.5)
			data.Frame.Position = UDim2.new(0.5, math.cos(data.Angle) * distance, 0.5, math.sin(data.Angle) * distance)
			data.Frame.BackgroundTransparency = 1 - alpha * 0.55 * (1 - data.Offset)
		end
	end

	-- Low health state.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local lowHealth = humanoid ~= nil and humanoid.Health > 0 and humanoid.Health / humanoid.MaxHealth <= LOW_HEALTH_FRACTION
	if lowHealth then
		local beat = (math.sin(os.clock() * 7) + 1) / 2
		vignetteGradient.Enabled = true
		if vignette.BackgroundTransparency > 0.6 then
			vignette.BackgroundColor3 = Color3.fromRGB(255, 70, 140)
			vignette.BackgroundTransparency = 0.75 - beat * 0.12
		end
		grade.Saturation = math.min(grade.Saturation, -0.35)
		if os.clock() - lastHeartbeat > HEARTBEAT_INTERVAL and soundPlayer then
			lastHeartbeat = os.clock()
			soundPlayer("LowHealth")
		end
	elseif grade.Saturation < 0 then
		grade.Saturation = math.min(0, grade.Saturation + deltaTime)
	end
end

function ScreenFX:Init()
	local playerGui = player:WaitForChild("PlayerGui")
	screen = Instance.new("ScreenGui")
	screen.Name = "ScreenFX"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 4
	screen.Parent = playerGui

	vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Parent = screen
	vignetteGradient = Instance.new("UIGradient")
	vignetteGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.8),
		NumberSequenceKeypoint.new(0.8, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	vignetteGradient.Parent = vignette

	tint = Instance.new("Frame")
	tint.Name = "Tint"
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundTransparency = 1
	tint.BorderSizePixel = 0
	tint.Parent = screen

	buildSpeedLines()
	buildScope()

	blur = Instance.new("BlurEffect")
	blur.Name = "VectorRushBlur"
	blur.Size = 0
	blur.Parent = Lighting
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "VectorRushFeedback"
	grade.Parent = Lighting
end

function ScreenFX:Start()
	RunService.RenderStepped:Connect(update)
end

return ScreenFX
