--[[
	TouchControls
	Mobile buttons for every action: Fire (drag to aim while firing), Jump,
	Crouch/Slide, Sprint (toggle), Aim (toggle), Reload, Movement + Tactical
	abilities, Weapon swap, Scoreboard and Menu. Movement uses Roblox's
	standard thumbstick. Buttons scale with screen size and the
	"Mobile Button Size" setting. Only shown on touch devices in matches.
]]

local Players = game:GetService("Players")

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)
local InputController = require(script.Parent.Parent.InputController)
local CameraController = require(script.Parent.Parent.CameraController)

local TouchControls = {}

local player = Players.LocalPlayer
local Theme = UIKit.Theme

local TOUCH_LOOK_SPEED = 0.006 -- radians per pixel while dragging the fire button

local root: Frame
local scale: UIScale
local toggles = { Sprint = false, Aim = false }

-- Offsets are from the bottom-right corner (centre of each button).
local LAYOUT = {
	{ Action = "Fire", Text = "FIRE", Size = 116, Offset = Vector2.new(-150, -150), Color = Color3.fromRGB(200, 50, 110), Kind = "Hold" },
	{ Action = "Jump", Text = "JUMP", Size = 80, Offset = Vector2.new(-55, -70), Kind = "Hold" },
	{ Action = "Crouch", Text = "SLIDE", Size = 70, Offset = Vector2.new(-250, -60), Kind = "Hold" },
	{ Action = "Sprint", Text = "SPRINT", Size = 64, Offset = Vector2.new(-55, -175), Kind = "Toggle" },
	{ Action = "Aim", Text = "AIM", Size = 64, Offset = Vector2.new(-150, -265), Kind = "Toggle" },
	{ Action = "Reload", Text = "R", Size = 58, Offset = Vector2.new(-250, -150), Kind = "Tap" },
	{ Action = "MovementAbility", Text = "DASH", Size = 70, Offset = Vector2.new(-345, -75), Color = Color3.fromRGB(30, 120, 160), Kind = "Tap" },
	{ Action = "TacticalAbility", Text = "TAC", Size = 70, Offset = Vector2.new(-345, -165), Color = Color3.fromRGB(150, 90, 30), Kind = "Tap" },
	{ Action = "NextWeapon", Text = "SWAP", Size = 58, Offset = Vector2.new(-55, -265), Kind = "Tap" },
}

local TOP_LAYOUT = {
	{ Action = "Menu", Text = "≡", Offset = Vector2.new(-45, 45) },
	{ Action = "Scoreboard", Text = "TAB", Offset = Vector2.new(-105, 45) },
}

local function makeButton(spec, anchorCorner: Vector2, parent: Instance): TextButton
	local size = spec.Size or 50
	local button = UIKit.Create("TextButton", {
		Name = spec.Action,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(anchorCorner.X, spec.Offset.X, anchorCorner.Y, spec.Offset.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = spec.Color or Theme.PanelLight,
		BackgroundTransparency = 0.25,
		Text = spec.Text,
		TextColor3 = Theme.Text,
		Font = UIKit.Font,
		TextSize = math.floor(size / 4.2),
		AutoButtonColor = false,
		Parent = parent,
	})
	UIKit.Corner(button, 999)
	UIKit.Stroke(button, Theme.Accent, 2, 0.5)
	return button
end

local function hook(button: TextButton, spec)
	local activeInput: InputObject? = nil
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch or activeInput then
			return
		end
		activeInput = input
		button.BackgroundTransparency = 0
		if spec.Kind == "Hold" then
			InputController:SetAction(spec.Action, true)
		elseif spec.Kind == "Toggle" then
			toggles[spec.Action] = not toggles[spec.Action]
			button.BackgroundColor3 = if toggles[spec.Action] then Color3.fromRGB(20, 120, 150) else Theme.PanelLight
			if spec.Action == "Aim" and ClientState.GetSetting("ToggleAim") then
				InputController:Pulse("Aim")
			else
				InputController:SetAction(spec.Action, toggles[spec.Action])
			end
		else
			InputController:Pulse(spec.Action)
		end
	end)
	button.InputChanged:Connect(function(input)
		-- Dragging the fire button also turns the camera (aim while shooting).
		if spec.Action == "Fire" and input == activeInput then
			local delta = input.Delta
			CameraController:AddLookDelta(-delta.X * TOUCH_LOOK_SPEED, -delta.Y * TOUCH_LOOK_SPEED)
		end
	end)
	button.InputEnded:Connect(function(input)
		if input ~= activeInput then
			return
		end
		activeInput = nil
		button.BackgroundTransparency = 0.25
		if spec.Kind == "Hold" then
			InputController:SetAction(spec.Action, false)
		end
	end)
end

-- Our Jump button supports double/wall jumps, so the default one is hidden.
local function hideDefaultJump()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") then
		jump.Visible = false
	end
end

local function updateVisibility()
	local visible = InputController:GetInputKind() == "Touch" and ClientState.IsInMatch()
	root.Visible = visible
	if visible then
		hideDefaultJump()
	end
end

function TouchControls:Build(screen: ScreenGui)
	root = UIKit.Create("Frame", { Name = "TouchControls", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = screen })
	-- Scale from the bottom-right so the cluster stays thumb-reachable.
	local cluster = UIKit.Create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(420, 340), BackgroundTransparency = 1, Parent = root })
	scale = UIKit.Create("UIScale", { Parent = cluster })
	for _, spec in LAYOUT do
		hook(makeButton(spec, Vector2.new(1, 1), cluster), spec)
	end
	for _, spec in TOP_LAYOUT do
		local topSpec = { Action = spec.Action, Text = spec.Text, Size = 48, Offset = spec.Offset, Kind = if spec.Action == "Scoreboard" then "Hold" else "Tap" }
		hook(makeButton(topSpec, Vector2.new(1, 0), root), topSpec)
	end
end

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local base = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720) * 1.6, 0.6, 1.3)
	scale.Scale = base * ClientState.GetSetting("MobileButtonScale")
end

function TouchControls:Start()
	InputController.InputKindChanged:Connect(updateVisibility)
	ClientState.Observe("Location", updateVisibility)
	ClientState.Observe("Settings", updateScale)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		updateVisibility()
	end)
end

return TouchControls
