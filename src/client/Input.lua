--!strict
-- Knows which device the player is using right now (keyboard, gamepad or touch) so prompts
-- and hints can show the right button.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Input = {}

local function classify(t: Enum.UserInputType): string?
	if t == Enum.UserInputType.Touch then
		return "touch"
	elseif t.Name:match("^Gamepad") then
		return "gamepad"
	elseif t == Enum.UserInputType.Keyboard or t.Name:match("^Mouse") then
		return "keyboard"
	end
	return nil
end

local initial = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then "touch"
	elseif GuiService:IsTenFootInterface() or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled)
	then "gamepad"
	else "keyboard"
Input.Device = initial

local listeners: { (string) -> () } = {}
function Input.OnChanged(fn: (string) -> ())
	table.insert(listeners, fn)
end

UserInputService.LastInputTypeChanged:Connect(function(t)
	local d = classify(t)
	if d and d ~= Input.Device then
		Input.Device = d
		for _, fn in listeners do
			task.spawn(fn, d)
		end
	end
end)

local LABELS: { [string]: { keyboard: string, gamepad: string, touch: string } } = {
	interact = { keyboard = "[E]", gamepad = "(B)", touch = "TAP" },
	garage = { keyboard = "[G]", gamepad = "(D-pad ←)", touch = "TAP" },
	map = { keyboard = "[M]", gamepad = "(D-pad ↑)", touch = "MAP" },
	pause = { keyboard = "[P]", gamepad = "(D-pad ↓)", touch = "☰" },
	fire = { keyboard = "[F]", gamepad = "(RB)", touch = "FIRE" },
	nitro = { keyboard = "SHIFT", gamepad = "(A)", touch = "NOS" },
	drift = { keyboard = "SPACE", gamepad = "(X)", touch = "DRIFT" },
	reset = { keyboard = "[R]", gamepad = "(Y)", touch = "RESET" },
}

function Input.Label(action: string): string
	local l = LABELS[action]
	if not l then
		return ""
	end
	return (l :: any)[Input.Device] or l.keyboard
end

function Input.ControlsHint(): string
	if Input.Device == "gamepad" then
		return "RT gas · LT brake · Left stick steer · X drift · A nitro · RB fire · Y reset · B interact · D-pad: ↑ map ↓ pause ← garage"
	elseif Input.Device == "touch" then
		return "Steer on the left · GAS / BRAKE on the right · DRIFT · NOS · FIRE"
	end
	return "WASD drive · SPACE drift · SHIFT nitro · F fire · R reset · E interact · G garage · M map · P pause"
end

function Input.IsTouch(): boolean
	return Input.Device == "touch"
end

function Input.IsGamepad(): boolean
	return Input.Device == "gamepad"
end

-- For gamepads: highlight a button so the D-pad / stick can navigate the menu.
function Input.Select(obj: GuiObject?)
	if Input.Device == "gamepad" then
		GuiService.SelectedObject = obj
	end
end

function Input.ClearSelection()
	GuiService.SelectedObject = nil
end

return Input
