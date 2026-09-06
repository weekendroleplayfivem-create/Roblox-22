--[[
	UIHelpers
	Shared visual language for the whole HUD (brief section 24): dark panels,
	thin cyan borders, monospaced readouts. Every UI script builds from these
	so the interface reads as one system.
]]

local TweenService = game:GetService("TweenService")

local UIHelpers = {}

UIHelpers.Cyan = Color3.fromRGB(120, 235, 235)
UIHelpers.Blue = Color3.fromRGB(70, 170, 255)
UIHelpers.Violet = Color3.fromRGB(180, 130, 255)
UIHelpers.Amber = Color3.fromRGB(255, 185, 70)
UIHelpers.Red = Color3.fromRGB(255, 90, 90)
UIHelpers.Green = Color3.fromRGB(120, 235, 150)
UIHelpers.Panel = Color3.fromRGB(10, 13, 18)
UIHelpers.PanelLight = Color3.fromRGB(20, 25, 32)
UIHelpers.Text = Color3.fromRGB(226, 236, 245)
UIHelpers.Dim = Color3.fromRGB(130, 145, 160)

UIHelpers.TitleFont = Enum.Font.GothamBlack
UIHelpers.BodyFont = Enum.Font.Gotham
UIHelpers.MonoFont = Enum.Font.Code

function UIHelpers.Tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function UIHelpers.Corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
	return corner
end

function UIHelpers.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or UIHelpers.Cyan
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.35
	stroke.Parent = parent
	return stroke
end

function UIHelpers.MakePanel(parent: Instance, size: UDim2, position: UDim2, accent: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = UIHelpers.Panel
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIHelpers.Corner(frame, 8)
	UIHelpers.Stroke(frame, accent or UIHelpers.Cyan, 1.4)
	return frame
end

function UIHelpers.MakeLabel(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	textSize: number?,
	color: Color3?,
	font: Enum.Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font or UIHelpers.BodyFont
	label.TextColor3 = color or UIHelpers.Text
	label.TextSize = textSize or 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

function UIHelpers.MakeButton(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	accent: Color3?
): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = UIHelpers.PanelLight
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = UIHelpers.TitleFont
	button.TextColor3 = UIHelpers.Text
	button.TextSize = 14
	button.Parent = parent

	UIHelpers.Corner(button, 6)
	local stroke = UIHelpers.Stroke(button, accent or UIHelpers.Cyan, 1.2)

	button.MouseEnter:Connect(function()
		UIHelpers.Tween(button, 0.12, { BackgroundColor3 = accent or UIHelpers.Cyan, BackgroundTransparency = 0.7 })
		UIHelpers.Tween(stroke, 0.12, { Transparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		UIHelpers.Tween(button, 0.12, { BackgroundColor3 = UIHelpers.PanelLight, BackgroundTransparency = 0.1 })
		UIHelpers.Tween(stroke, 0.12, { Transparency = 0.35 })
	end)

	return button
end

function UIHelpers.MakeBar(parent: Instance, size: UDim2, position: UDim2, color: Color3): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Size = size
	track.Position = position
	track.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	track.BorderSizePixel = 0
	track.Parent = parent
	UIHelpers.Corner(track, 3)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track
	UIHelpers.Corner(fill, 3)

	return track, fill
end

-- Types text out one character at a time. Used by the end-of-run report so
-- the enemy's readout of your habits lands line by line instead of all at once.
function UIHelpers.Typewriter(label: TextLabel, text: string, charactersPerSecond: number?): thread
	local rate = charactersPerSecond or 45
	return task.spawn(function()
		label.Text = ""
		for index = 1, #text do
			if not label.Parent then
				return
			end
			label.Text = text:sub(1, index)
			task.wait(1 / rate)
		end
	end)
end

return UIHelpers
