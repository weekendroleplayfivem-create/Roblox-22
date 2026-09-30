--!strict
-- Shared UI look: fonts, colours and small helpers for glassy panels, so every screen matches.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Fonts = {
	Display = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular), -- racing / sci-fi numbers
	Heading = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
	Body = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold),
	Light = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium),
}

Theme.Colors = {
	Panel = Color3.fromRGB(10, 12, 22),
	PanelLight = Color3.fromRGB(28, 32, 50),
	Text = Color3.fromRGB(240, 242, 250),
	Dim = Color3.fromRGB(150, 156, 180),
	Cyan = Color3.fromRGB(0, 225, 255),
	Pink = Color3.fromRGB(255, 45, 150),
	Red = Color3.fromRGB(255, 60, 70),
	Blue = Color3.fromRGB(70, 140, 255),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(90, 255, 150),
	Orange = Color3.fromRGB(255, 150, 40),
	Purple = Color3.fromRGB(170, 120, 255),
}

-- Maps the old Gotham fonts onto the theme so older screens match the new look.
function Theme.FontFor(font: Enum.Font): Font
	if font == Enum.Font.GothamBlack then
		return Theme.Fonts.Heading
	elseif font == Enum.Font.Gotham then
		return Theme.Fonts.Light
	end
	return Theme.Fonts.Body
end

function Theme.new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Dark glass panel: rounded, subtle top highlight and a thin accent outline.
function Theme.Panel(frame: GuiObject, accent: Color3?, radius: number?)
	frame.BackgroundColor3 = Theme.Colors.Panel
	if frame.BackgroundTransparency >= 1 then
		frame.BackgroundTransparency = 0.18
	end
	Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) }, frame)
	Theme.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(46, 52, 78), Color3.fromRGB(10, 12, 22)),
		Transparency = NumberSequence.new(0, 0.05),
	}, frame)
	Theme.new("UIStroke", {
		Color = accent or Theme.Colors.Cyan,
		Thickness = 1.5,
		Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
end

function Theme.Label(props: { [string]: any }, parent: Instance?): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		base[k] = v
	end
	return Theme.new("TextLabel", base, parent)
end

-- Horizontal progress bar; returns the fill frame.
function Theme.Bar(parent: Instance, props: { [string]: any }, color: Color3): Frame
	local back = Theme.new("Frame", { BackgroundColor3 = Color3.fromRGB(34, 38, 58), BorderSizePixel = 0 }, parent)
	for k, v in props do
		(back :: any)[k] = v
	end
	Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }, back)
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	Theme.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) }, fill)
	return fill
end

function Theme.Tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Background blur while any menu is open (several menus can ask for it at once).
local blur = Instance.new("BlurEffect")
blur.Name = "WU_MenuBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting
local blurUsers: { [string]: true } = {}
function Theme.Blur(key: string, on: boolean)
	if on then
		blurUsers[key] = true
	else
		blurUsers[key] = nil
	end
	local any = next(blurUsers) ~= nil
	if any then
		blur.Enabled = true
	end
	local t = Theme.Tween(blur, 0.3, { Size = if any then 16 else 0 })
	if not any then
		t.Completed:Once(function()
			if next(blurUsers) == nil then
				blur.Enabled = false
			end
		end)
	end
end

-- Animated popup: `holder` is a centred CanvasGroup (so everything inside fades together) and
-- `backdrop` a full-screen dimmer. Opening pops the window up with a little overshoot, closing
-- drops and fades it, then disables the ScreenGui.
local popupTokens: { [Instance]: number } = {}
function Theme.Popup(gui: ScreenGui, backdrop: GuiObject, holder: CanvasGroup, open: boolean)
	local token = (popupTokens[holder] or 0) + 1
	popupTokens[holder] = token
	local dim = backdrop:GetAttribute("Dim")
	if type(dim) ~= "number" then
		dim = backdrop.BackgroundTransparency
		backdrop:SetAttribute("Dim", dim)
	end
	local home = UDim2.fromScale(0.5, 0.5)
	Theme.Blur(gui.Name, open)
	if open then
		gui.Enabled = true
		holder.GroupTransparency = 1
		holder.Position = home + UDim2.fromOffset(0, 60)
		holder.Rotation = -2
		backdrop.BackgroundTransparency = 1
		Theme.Tween(backdrop, 0.25, { BackgroundTransparency = dim })
		Theme.Tween(holder, 0.22, { GroupTransparency = 0 })
		Theme.Tween(holder, 0.45, { Position = home, Rotation = 0 }, Enum.EasingStyle.Back)
	else
		Theme.Tween(backdrop, 0.2, { BackgroundTransparency = 1 })
		Theme.Tween(holder, 0.2, { GroupTransparency = 1, Position = home + UDim2.fromOffset(0, 40), Rotation = 1.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.21, function()
			if popupTokens[holder] == token then
				gui.Enabled = false
			end
		end)
	end
end

return Theme
