--[[
	UIHelpers
	Shared look-and-feel for every HYPER BLAST menu (brief section 33): dark
	transparent panels, blue/purple neon borders, TweenService-driven
	animations. Every UI script builds on these instead of reinventing style.
]]

local TweenService = game:GetService("TweenService")

local UIHelpers = {}

UIHelpers.NeonBlue = Color3.fromRGB(60, 150, 255)
UIHelpers.NeonPurple = Color3.fromRGB(175, 75, 255)
UIHelpers.PanelColor = Color3.fromRGB(12, 12, 18)
UIHelpers.TextColor = Color3.fromRGB(235, 240, 255)
UIHelpers.Font = Enum.Font.GothamBlack
UIHelpers.BodyFont = Enum.Font.Gotham

function UIHelpers.Tween(instance, duration, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function UIHelpers.Panel(parent, size, position, accentColor)
	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = UIHelpers.PanelColor
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Size = size
	panel.Position = position
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor or UIHelpers.NeonBlue
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = panel

	return panel
end

function UIHelpers.Label(parent, text, size, position, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = UIHelpers.Font
	label.TextColor3 = color or UIHelpers.TextColor
	label.TextSize = textSize or 24
	label.Size = size
	label.Position = position
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function UIHelpers.Button(parent, text, size, position, accentColor)
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = UIHelpers.Font
	button.TextSize = 20
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	button.BackgroundTransparency = 0.1
	button.AutoButtonColor = false
	button.Size = size
	button.Position = position
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor or UIHelpers.NeonBlue
	stroke.Thickness = 2
	stroke.Parent = button

	button.MouseEnter:Connect(function()
		UIHelpers.Tween(button, 0.15, { BackgroundColor3 = accentColor or UIHelpers.NeonBlue, BackgroundTransparency = 0.4 })
	end)
	button.MouseLeave:Connect(function()
		UIHelpers.Tween(button, 0.15, { BackgroundColor3 = Color3.fromRGB(20, 20, 26), BackgroundTransparency = 0.1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIHelpers.Tween(button, 0.08, { Size = size - UDim2.fromOffset(4, 4) })
	end)
	button.MouseButton1Up:Connect(function()
		UIHelpers.Tween(button, 0.08, { Size = size })
	end)

	return button
end

function UIHelpers.ProgressBar(parent, size, position, accentColor)
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	track.Size = size
	track.Position = position
	track.Parent = parent
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = accentColor or UIHelpers.NeonBlue
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return track, fill
end

function UIHelpers.SetProgress(fill, alpha, duration)
	UIHelpers.Tween(fill, duration or 0.2, { Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0) })
end

return UIHelpers
