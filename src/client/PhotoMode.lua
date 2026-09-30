--!strict
-- Photo mode (C / View button / 📷): the controls lock, the HUD hides and you orbit a free camera
-- around your car. Filters, zoom, tilt, depth of field and a hide-UI toggle for clean shots.

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Drive = require(script.Parent.DriveController)
local Theme = require(script.Parent.Theme)
local Sounds = require(script.Parent.Sounds)
local HUD = require(script.Parent.HUD)
local Input = require(script.Parent.Input)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local F, C = Theme.Fonts, Theme.Colors

local PhotoMode = {}
PhotoMode.Active = false

type Filter = { name: string, saturation: number, contrast: number, brightness: number, tint: Color3 }
local FILTERS: { Filter } = {
	{ name = "NATURAL", saturation = 0, contrast = 0, brightness = 0, tint = Color3.new(1, 1, 1) },
	{ name = "VIVID", saturation = 0.45, contrast = 0.15, brightness = 0.02, tint = Color3.new(1, 1, 1) },
	{ name = "NEON NIGHTS", saturation = 0.3, contrast = 0.2, brightness = 0, tint = Color3.fromRGB(235, 200, 255) },
	{ name = "GOLDEN", saturation = 0.15, contrast = 0.08, brightness = 0.03, tint = Color3.fromRGB(255, 225, 180) },
	{ name = "ICE", saturation = -0.1, contrast = 0.12, brightness = 0.02, tint = Color3.fromRGB(200, 225, 255) },
	{ name = "NOIR", saturation = -1, contrast = 0.35, brightness = -0.02, tint = Color3.new(1, 1, 1) },
	{ name = "VINTAGE", saturation = -0.35, contrast = -0.05, brightness = 0.04, tint = Color3.fromRGB(255, 235, 200) },
}

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "WU_PhotoGrade"
grade.Enabled = false
grade.Parent = Lighting
local dof = Instance.new("DepthOfFieldEffect")
dof.Name = "WU_PhotoDOF"
dof.Enabled = false
dof.FarIntensity = 0.45
dof.NearIntensity = 0.2
dof.InFocusRadius = 14
dof.Parent = Lighting

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local gui: ScreenGui = Theme.new("ScreenGui", { Name = "WantedUnboundPhoto", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 18, Enabled = false }, player:WaitForChild("PlayerGui"))
local bar = Theme.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(640, 86) }, gui)
Theme.Panel(bar, C.Cyan, 16)
local tag = Theme.Label({ Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(200, 22), Text = "PHOTO MODE", FontFace = F.Display }, bar)
Theme.new("UIGradient", { Color = ColorSequence.new(C.Cyan, C.Pink) }, tag)
local filterLabel = Theme.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(220, 26), Text = "NATURAL", FontFace = F.Heading, TextXAlignment = Enum.TextXAlignment.Center }, bar)
local hint = Theme.Label({ Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 0, 18), Text = "", FontFace = F.Light, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Center }, bar)

local function smallButton(text: string, x: UDim2, onClick: () -> ()): TextButton
	local b = Theme.new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = x, Size = UDim2.fromOffset(40, 30), BackgroundColor3 = C.PanelLight, Text = text, TextScaled = true, FontFace = F.Heading, TextColor3 = C.Text }, bar)
	Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	Theme.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
	b.Activated:Connect(function()
		Theme.Pop(b, 0.8)
		onClick()
	end)
	return b
end

local filterIndex = 1
local function setFilter(i: number)
	filterIndex = (i - 1) % #FILTERS + 1
	local f = FILTERS[filterIndex]
	Theme.Tween(grade, 0.35, { Saturation = f.saturation, Contrast = f.contrast, Brightness = f.brightness, TintColor = f.tint })
	filterLabel.Text = f.name
	Theme.Pop(filterLabel, 1.25)
	Sounds.Tick(1.3, 0.3)
end
smallButton("‹", UDim2.new(0.5, -140, 0, 6), function()
	setFilter(filterIndex - 1)
end)
smallButton("›", UDim2.new(0.5, 140, 0, 6), function()
	setFilter(filterIndex + 1)
end)
local zoomOut = smallButton("−", UDim2.new(1, -124, 0, 8), function() end)
local zoomIn = smallButton("+", UDim2.new(1, -78, 0, 8), function() end)
local closeButton = Theme.new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = C.PanelLight, Text = "✕", TextScaled = true, FontFace = F.Heading, TextColor3 = C.Text }, bar)
Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }, closeButton)
Theme.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, closeButton)

local function updateHint()
	if Input.Device == "gamepad" then
		hint.Text = "Right stick orbit · LT/RT zoom · LB/RB filter · Y hide UI · B exit"
	elseif Input.Device == "touch" then
		hint.Text = "Drag to orbit · − / + zoom · ‹ › filters · ✕ exit"
	else
		hint.Text = "Drag mouse to orbit · wheel zoom · Q/E filter · Z/X tilt · H hide UI · C exit"
	end
end
Input.OnChanged(function()
	updateHint()
end)

---------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------
local yaw, pitch, dist, roll, fov = 0, 0.25, 22, 0, 50
zoomOut.Activated:Connect(function()
	dist = math.clamp(dist + 5, 7, 70)
end)
zoomIn.Activated:Connect(function()
	dist = math.clamp(dist - 5, 7, 70)
end)
local dragging = false
local uiHidden = false

local function setUiHidden(on: boolean)
	uiHidden = on
	Theme.Show(bar, not on, UDim2.fromOffset(0, 140))
end

function PhotoMode.Toggle(on: boolean?)
	local want = if on == nil then not PhotoMode.Active else on
	if want == PhotoMode.Active then
		return
	end
	if want then
		local car = Drive.Car
		if not car or not car.PrimaryPart or Drive.Cinematic or Drive.MenuOpen or player:GetAttribute("InGarage") then
			return
		end
		local look = car.PrimaryPart.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z) + math.pi * 0.8
		pitch, dist, roll, fov = 0.22, 22, 0, 50
	end
	PhotoMode.Active = want
	Drive.Cinematic = want
	gui.Enabled = true
	grade.Enabled = want
	dof.Enabled = want
	Theme.Blur("photo", false)
	if want then
		updateHint()
		setFilter(filterIndex)
		bar:SetAttribute("Shown", false)
		setUiHidden(false)
		Sounds.Play("rbxasset://sounds/volume_slider.ogg", 0.6, 0.6)
	else
		setUiHidden(true)
		task.delay(0.25, function()
			if not PhotoMode.Active then
				gui.Enabled = false
			end
		end)
		HUD.Intro()
	end
end
closeButton.Activated:Connect(function()
	PhotoMode.Toggle(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not PhotoMode.Active or processed then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
		dragging = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input: InputObject)
	if not PhotoMode.Active then
		return
	end
	local t = input.UserInputType
	if (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) and dragging then
		yaw -= input.Delta.X * 0.008
		pitch = math.clamp(pitch + input.Delta.Y * 0.006, -0.05, 1.3)
	elseif t == Enum.UserInputType.MouseWheel then
		dist = math.clamp(dist - input.Position.Z * 2.5, 7, 70)
	end
end)

ContextActionService:BindActionAtPriority("WU_PhotoKeys", function(_, state, input)
	if not PhotoMode.Active then
		return Enum.ContextActionResult.Pass
	end
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonL1 then
		setFilter(filterIndex - 1)
	elseif k == Enum.KeyCode.E or k == Enum.KeyCode.ButtonR1 then
		setFilter(filterIndex + 1)
	elseif k == Enum.KeyCode.H or k == Enum.KeyCode.ButtonY then
		setUiHidden(not uiHidden)
	elseif k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.Escape then
		PhotoMode.Toggle(false)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.H, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB, Enum.KeyCode.F, Enum.KeyCode.R, Enum.KeyCode.G, Enum.KeyCode.M, Enum.KeyCode.L, Enum.KeyCode.P)

ContextActionService:BindAction("WU_PhotoToggle", function(_, state)
	if state == Enum.UserInputState.Begin then
		PhotoMode.Toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonSelect)

RunService:BindToRenderStep("WU_PhotoCam", Enum.RenderPriority.Camera.Value + 3, function(dt: number)
	if not PhotoMode.Active then
		return
	end
	local car = Drive.Car
	local root = car and car.PrimaryPart
	if not root then
		PhotoMode.Toggle(false)
		return
	end
	-- gamepad: right stick orbits, triggers zoom
	for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
		if state.KeyCode == Enum.KeyCode.Thumbstick2 and state.Position.Magnitude > 0.15 then
			yaw -= state.Position.X * dt * 2.2
			pitch = math.clamp(pitch - state.Position.Y * dt * 1.6, -0.05, 1.3)
		elseif state.KeyCode == Enum.KeyCode.ButtonR2 and state.Position.Z > 0.1 then
			dist = math.clamp(dist - state.Position.Z * dt * 30, 7, 70)
		elseif state.KeyCode == Enum.KeyCode.ButtonL2 and state.Position.Z > 0.1 then
			dist = math.clamp(dist + state.Position.Z * dt * 30, 7, 70)
		end
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Z) then
		roll = math.clamp(roll - dt * 0.6, -0.5, 0.5)
	elseif UserInputService:IsKeyDown(Enum.KeyCode.X) then
		roll = math.clamp(roll + dt * 0.6, -0.5, 0.5)
	end
	local center = root.Position + Vector3.new(0, 1.6, 0)
	local offset = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)) * dist
	local pos = center + offset
	if pos.Y < center.Y - 1 then
		pos = Vector3.new(pos.X, center.Y - 1, pos.Z)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(pos, center) * CFrame.Angles(0, 0, roll)
	fov += (50 - fov) * math.min(1, dt * 4)
	camera.FieldOfView = fov
	dof.FocusDistance = dist
end)

-- leave photo mode automatically if something else takes over (pursuit, race start, garage)
player:GetAttributeChangedSignal("RaceActive"):Connect(function()
	PhotoMode.Toggle(false)
end)
player:GetAttributeChangedSignal("PursuitMode"):Connect(function()
	if player:GetAttribute("PursuitMode") ~= "idle" then
		PhotoMode.Toggle(false)
	end
end)

return PhotoMode
