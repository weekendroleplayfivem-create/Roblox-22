--[[
	UIKit
	Shared look and helpers for every screen: theme colours, fonts, panels,
	buttons with hover/press animation and click sounds, progress bars,
	automatic UI scaling for phones -> 4K, and open/close transitions.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local SoundController = require(script.Parent.Parent.SoundController)

local UIKit = {}

UIKit.Theme = {
	Background = Color3.fromRGB(10, 12, 26),
	Panel = Color3.fromRGB(20, 24, 44),
	PanelLight = Color3.fromRGB(34, 40, 70),
	Accent = Color3.fromRGB(40, 225, 255),
	Accent2 = Color3.fromRGB(255, 80, 200),
	Yellow = Color3.fromRGB(255, 210, 70),
	Text = Color3.fromRGB(245, 248, 255),
	SubText = Color3.fromRGB(160, 172, 205),
	Danger = Color3.fromRGB(255, 90, 105),
	Success = Color3.fromRGB(90, 255, 160),
	Locked = Color3.fromRGB(85, 90, 115),
}

UIKit.Font = Enum.Font.GothamBold
UIKit.FontBlack = Enum.Font.GothamBlack
UIKit.FontRegular = Enum.Font.Gotham

local DESIGN_SIZE = Vector2.new(1280, 720)

function UIKit.Create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.Corner(parent: Instance, radius: number?): UICorner
	return UIKit.Create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.Create("UIStroke", {
		Color = color or UIKit.Theme.Accent,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return UIKit.Create("UIPadding", { PaddingTop = amount, PaddingBottom = amount, PaddingLeft = amount, PaddingRight = amount, Parent = parent })
end

function UIKit.List(parent: Instance, direction: Enum.FillDirection?, padding: number?, alignment: Enum.HorizontalAlignment?): UIListLayout
	return UIKit.Create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UIKit.Gradient(parent: Instance, from: Color3, to: Color3, rotation: number?): UIGradient
	return UIKit.Create("UIGradient", { Color = ColorSequence.new(from, to), Rotation = rotation or 0, Parent = parent })
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in props do
		defaults[key] = value
	end
	return UIKit.Create("TextLabel", defaults)
end

function UIKit.Panel(props: { [string]: any }): Frame
	local defaults = {
		BackgroundColor3 = UIKit.Theme.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	local frame = UIKit.Create("Frame", defaults)
	UIKit.Corner(frame, 12)
	UIKit.Stroke(frame, UIKit.Theme.Accent, 1, 0.75)
	return frame
end

function UIKit.Tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

-- Button with hover/press feedback and a click sound.
function UIKit.Button(props: { [string]: any }): TextButton
	local onClick = props.OnClick
	local color = props.Color or UIKit.Theme.PanelLight
	local defaults = {
		BackgroundColor3 = color,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = UIKit.Font,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 20,
		Size = UDim2.new(0, 220, 0, 48),
		Selectable = true,
	}
	for key, value in props do
		if key ~= "OnClick" and key ~= "Color" then
			defaults[key] = value
		end
	end
	local button = UIKit.Create("TextButton", defaults)
	UIKit.Corner(button, 10)
	local stroke = UIKit.Stroke(button, UIKit.Theme.Accent, 1.5, 0.7)
	local scale = UIKit.Create("UIScale", { Parent = button })

	button.MouseEnter:Connect(function()
		UIKit.Tween(stroke, 0.12, { Transparency = 0 })
		UIKit.Tween(scale, 0.12, { Scale = 1.03 })
		SoundController:Play("UIHover")
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(stroke, 0.15, { Transparency = 0.7 })
		UIKit.Tween(scale, 0.15, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		UIKit.Tween(stroke, 0.12, { Transparency = 0 })
	end)
	button.SelectionLost:Connect(function()
		UIKit.Tween(stroke, 0.15, { Transparency = 0.7 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.06, { Scale = 0.97 })
	end)
	button.Activated:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1 })
		SoundController:Play("UIClick")
		if onClick then
			onClick()
		end
	end)
	return button
end

-- Horizontal progress bar. Returns { Frame, Fill, Set(alpha, animate?) }.
function UIKit.Bar(props: { [string]: any })
	local frame = UIKit.Create("Frame", {
		Size = props.Size or UDim2.new(1, 0, 0, 10),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.BackgroundColor or Color3.fromRGB(30, 34, 58),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(frame, 6)
	local fill = UIKit.Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or UIKit.Theme.Accent,
		BorderSizePixel = 0,
		Parent = frame,
	})
	UIKit.Corner(fill, 6)
	local bar = { Frame = frame, Fill = fill }
	function bar.Set(alpha: number, animate: boolean?)
		local goal = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		if animate then
			UIKit.Tween(fill, 0.25, { Size = goal })
		else
			fill.Size = goal
		end
	end
	return bar
end

local ownedScreens: { [string]: ScreenGui } = {}
local watchingDuplicates = false

-- Returns this player's ScreenGui for `name`. The containers also exist in
-- StarterGui (see default.project.json), but StarterGui is only copied when a
-- character first spawns, so we clone/create immediately and remove the empty
-- duplicate Roblox copies in later.
function UIKit.GetScreen(name: string, displayOrder: number?): ScreenGui
	local existing = ownedScreens[name]
	if existing then
		return existing
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = playerGui:FindFirstChild(name)
	if not screen or not screen:IsA("ScreenGui") then
		local template = game:GetService("StarterGui"):FindFirstChild(name)
		if template and template:IsA("ScreenGui") then
			screen = template:Clone()
		else
			screen = UIKit.Create("ScreenGui", {
				Name = name,
				ResetOnSpawn = false,
				IgnoreGuiInset = true,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
				DisplayOrder = displayOrder or 10,
			})
		end
		screen.Parent = playerGui
	end
	ownedScreens[name] = screen :: ScreenGui
	if not watchingDuplicates then
		watchingDuplicates = true
		playerGui.ChildAdded:Connect(function(child)
			if child:IsA("ScreenGui") and ownedScreens[child.Name] and ownedScreens[child.Name] ~= child and #child:GetChildren() == 0 then
				task.defer(child.Destroy, child)
			end
		end)
	end
	return screen :: ScreenGui
end

-- Keeps UI readable on every screen size by scaling from a 1280x720 design.
function UIKit.AutoScale(target: Instance, minScale: number?, maxScale: number?)
	local scale = UIKit.Create("UIScale", { Parent = target })
	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local value = math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y)
		scale.Scale = math.clamp(value, minScale or 0.55, maxScale or 1.5)
	end
	update()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

-- Smooth open/close for a full panel (fade + small scale pop).
function UIKit.SetOpen(frame: GuiObject, open: boolean)
	local scale = frame:FindFirstChild("OpenScale") :: UIScale?
	if not scale then
		scale = UIKit.Create("UIScale", { Name = "OpenScale", Parent = frame })
	end
	local openScale = scale :: UIScale
	if open then
		frame.Visible = true
		openScale.Scale = 0.94
		UIKit.Tween(openScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		if GuiService.GamepadEnabled then
			local first = frame:FindFirstChildWhichIsA("GuiButton", true)
			if first then
				GuiService.SelectedObject = first
			end
		end
	else
		frame.Visible = false
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(frame) then
			GuiService.SelectedObject = nil
		end
	end
end

-- Standard full-screen menu container with title and close button.
function UIKit.MenuFrame(screen: ScreenGui, title: string, onClose: () -> ()): (Frame, Frame)
	local root = UIKit.Create("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIKit.Theme.Background,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = screen,
	})
	local holder = UIKit.Create("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1100, 620),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.AutoScale(holder)
	UIKit.Label({
		Text = title,
		Font = UIKit.FontBlack,
		TextSize = 40,
		Size = UDim2.new(1, -140, 0, 50),
		Parent = holder,
	})
	UIKit.Button({
		Text = "BACK",
		Size = UDim2.fromOffset(120, 44),
		Position = UDim2.new(1, -120, 0, 2),
		OnClick = onClose,
		Parent = holder,
	})
	local content = UIKit.Create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	return root, content
end

return UIKit
