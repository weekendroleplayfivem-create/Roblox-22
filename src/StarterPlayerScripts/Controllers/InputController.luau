--[[
	InputController
	Maps keyboard/mouse, gamepad (Xbox/PlayStation layouts) and touch input to
	game actions. Other controllers listen to ActionBegan/ActionEnded and
	never read raw input directly, so every action works on every device.

	Default bindings
	  Action            Keyboard/Mouse     Gamepad
	  Fire              Mouse1             R2 / RT
	  Aim               Mouse2             L2 / LT
	  Reload            R                  X / Square
	  Sprint            Left Shift         L3 (left stick click)
	  Crouch / Slide    C / Left Ctrl      B / Circle
	  Jump              Space              A / Cross
	  MovementAbility   E                  L1 / LB
	  TacticalAbility   Q                  R1 / RB
	  Weapon1 / 2       1 / 2              DPad Left / Right
	  NextWeapon        Mouse wheel        Y / Triangle
	  Scoreboard        Tab                Select / View
	  Menu              M                  Start / Menu
	  Emote             G                  DPad Down
	  Inspect weapon    F                  DPad Up
	Touch: on-screen buttons (see UI/TouchControls).
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Modules.Signal)

local InputController = {}

InputController.ActionBegan = Signal.new() -- (action)
InputController.ActionEnded = Signal.new() -- (action)
InputController.InputKindChanged = Signal.new() -- ("KeyboardMouse" | "Gamepad" | "Touch")

-- Actions that keep working while a menu is open.
local MENU_SAFE_ACTIONS = { Menu = true, Scoreboard = true, DevConsole = true }

local KeyBindings: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.R] = "Reload",
	[Enum.KeyCode.LeftShift] = "Sprint",
	[Enum.KeyCode.C] = "Crouch",
	[Enum.KeyCode.LeftControl] = "Crouch",
	[Enum.KeyCode.Space] = "Jump",
	[Enum.KeyCode.E] = "MovementAbility",
	[Enum.KeyCode.Q] = "TacticalAbility",
	[Enum.KeyCode.One] = "Weapon1",
	[Enum.KeyCode.Two] = "Weapon2",
	[Enum.KeyCode.Tab] = "Scoreboard",
	[Enum.KeyCode.M] = "Menu",
	[Enum.KeyCode.G] = "Emote",
	[Enum.KeyCode.F] = "Inspect",
	[Enum.KeyCode.F2] = "DevConsole",

	[Enum.KeyCode.ButtonR2] = "Fire",
	[Enum.KeyCode.ButtonL2] = "Aim",
	[Enum.KeyCode.ButtonX] = "Reload",
	[Enum.KeyCode.ButtonL3] = "Sprint",
	[Enum.KeyCode.ButtonB] = "Crouch",
	[Enum.KeyCode.ButtonA] = "Jump",
	[Enum.KeyCode.ButtonL1] = "MovementAbility",
	[Enum.KeyCode.ButtonR1] = "TacticalAbility",
	[Enum.KeyCode.DPadLeft] = "Weapon1",
	[Enum.KeyCode.DPadRight] = "Weapon2",
	[Enum.KeyCode.ButtonY] = "NextWeapon",
	[Enum.KeyCode.ButtonSelect] = "Scoreboard",
	[Enum.KeyCode.ButtonStart] = "Menu",
	[Enum.KeyCode.DPadDown] = "Emote",
	[Enum.KeyCode.DPadUp] = "Inspect",
}

local MouseBindings: { [Enum.UserInputType]: string } = {
	[Enum.UserInputType.MouseButton1] = "Fire",
	[Enum.UserInputType.MouseButton2] = "Aim",
}

local down: { [string]: boolean } = {}
local blocked = false
local inputKind = "KeyboardMouse"

function InputController:IsDown(action: string): boolean
	return down[action] == true
end

function InputController:GetInputKind(): string
	return inputKind
end

-- While blocked (menus open), gameplay actions are released and ignored.
function InputController:SetBlocked(isBlocked: boolean)
	if blocked == isBlocked then
		return
	end
	blocked = isBlocked
	if isBlocked then
		for action in table.clone(down) do
			if not MENU_SAFE_ACTIONS[action] then
				down[action] = nil
				InputController.ActionEnded:Fire(action)
			end
		end
	end
end

function InputController:IsBlocked(): boolean
	return blocked
end

-- Used by touch buttons and any other virtual input source.
function InputController:SetAction(action: string, isDown: boolean)
	if isDown then
		if blocked and not MENU_SAFE_ACTIONS[action] then
			return
		end
		if down[action] then
			return
		end
		down[action] = true
		InputController.ActionBegan:Fire(action)
	else
		if not down[action] then
			return
		end
		down[action] = nil
		InputController.ActionEnded:Fire(action)
	end
end

-- One-shot action (press + release), e.g. mouse wheel.
function InputController:Pulse(action: string)
	InputController:SetAction(action, true)
	InputController:SetAction(action, false)
end

local function setInputKind(kind: string)
	if inputKind ~= kind then
		inputKind = kind
		InputController.InputKindChanged:Fire(kind)
	end
end

local function classify(inputType: Enum.UserInputType)
	if inputType == Enum.UserInputType.Touch then
		setInputKind("Touch")
	elseif string.find(inputType.Name, "Gamepad") then
		setInputKind("Gamepad")
	elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") then
		setInputKind("KeyboardMouse")
	end
end

function InputController:Init()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		inputKind = "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		inputKind = "Gamepad"
	end
end

function InputController:Start()
	UserInputService.LastInputTypeChanged:Connect(classify)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local action = KeyBindings[input.KeyCode] or MouseBindings[input.UserInputType]
		if not action then
			return
		end
		-- Typing in chat / clicking UI buttons should not trigger gameplay.
		if gameProcessed and not MENU_SAFE_ACTIONS[action] then
			return
		end
		InputController:SetAction(action, true)
	end)

	UserInputService.InputEnded:Connect(function(input)
		local action = KeyBindings[input.KeyCode] or MouseBindings[input.UserInputType]
		if action then
			InputController:SetAction(action, false)
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed and not blocked then
			if input.Position.Z > 0 then
				InputController:Pulse("PrevWeapon")
			elseif input.Position.Z < 0 then
				InputController:Pulse("NextWeapon")
			end
		end
	end)

	-- Losing focus (alt-tab) releases everything so nothing sticks "held".
	UserInputService.WindowFocusReleased:Connect(function()
		for action in table.clone(down) do
			InputController:SetAction(action, false)
		end
	end)
end

return InputController
