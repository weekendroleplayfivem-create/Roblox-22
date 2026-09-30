--!strict
-- Mobile driving controls: an analog steering pad on the left, GAS / BRAKE pedals on the right,
-- and NOS, DRIFT, FIRE and RESET buttons. Shown only on touch devices while driving; the
-- default thumbstick is switched off meanwhile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RespawnCar = Remotes:WaitForChild("RespawnCar") :: RemoteEvent

local Drive = require(script.Parent.DriveController)
local Input = require(script.Parent.Input)
local Scale = require(script.Parent.Scale)
local HUD = require(script.Parent.HUD)
local BlackMarket = require(script.Parent.BlackMarket)
local Garage = require(script.Parent.Garage)

local player = Players.LocalPlayer
local TouchControls = {}

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

local gui = new("ScreenGui", { Name = "WantedUnboundTouch", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3, Enabled = false }, player:WaitForChild("PlayerGui"))

---------------------------------------------------------------------------
-- Steering pad (drag left / right, analog)
---------------------------------------------------------------------------
local pad = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -24),
	Size = UDim2.fromOffset(300, 150),
	BackgroundColor3 = Color3.fromRGB(10, 10, 18),
	BackgroundTransparency = 0.5,
	Active = true,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 75) }, pad)
new("UIStroke", { Color = Color3.fromRGB(0, 230, 255), Thickness = 2, Transparency = 0.4 }, pad)
Scale.Attach(pad)
new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "◀   STEER   ▶", TextScaled = false, TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(200, 220, 235), TextTransparency = 0.4 }, pad)
local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = Color3.fromRGB(0, 230, 255), BackgroundTransparency = 0.25 }, pad)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)

local steerTouch: InputObject? = nil
local function updateSteer(pos: Vector3)
	local absPos, absSize = pad.AbsolutePosition, pad.AbsoluteSize
	local rel = (pos.X - (absPos.X + absSize.X / 2)) / (absSize.X / 2 - 30)
	local s = math.clamp(rel, -1, 1)
	if math.abs(s) < 0.08 then
		s = 0
	end
	Drive.TouchSteer = s
	knob.Position = UDim2.new(0.5 + s * 0.38, 0, 0.5, 0)
end
pad.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		steerTouch = input
		updateSteer(input.Position)
	end
end)
pad.InputChanged:Connect(function(input)
	if input == steerTouch or (steerTouch and input.UserInputType == Enum.UserInputType.MouseMovement) then
		updateSteer(input.Position)
	end
end)
local function releaseSteer(input: InputObject)
	if input == steerTouch or (steerTouch and input.UserInputType == Enum.UserInputType.MouseButton1) then
		steerTouch = nil
		Drive.TouchSteer = 0
		knob.Position = UDim2.fromScale(0.5, 0.5)
	end
end
pad.InputEnded:Connect(releaseSteer)

---------------------------------------------------------------------------
-- Buttons (hold-to-press, multi-touch)
---------------------------------------------------------------------------
local right = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(330, 290), BackgroundTransparency = 1 }, gui)
Scale.Attach(right)

local function holdButton(text: string, color: Color3, pos: UDim2, size: UDim2, onDown: () -> (), onUp: () -> ()): TextButton
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = pos,
		Size = size,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.25,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
	}, right)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, b)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.5 }, b)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	local down = 0
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			down += 1
			b.BackgroundTransparency = 0.05
			onDown()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			down = math.max(0, down - 1)
			if down == 0 then
				b.BackgroundTransparency = 0.25
				onUp()
			end
		end
	end)
	return b
end

holdButton("GAS", Color3.fromRGB(40, 190, 90), UDim2.fromScale(1, 1), UDim2.fromOffset(120, 170), function()
	Drive.TouchThrottle = 1
end, function()
	Drive.TouchThrottle = 0
end)
holdButton("BRAKE", Color3.fromRGB(200, 50, 50), UDim2.new(1, -132, 1, 0), UDim2.fromOffset(100, 120), function()
	Drive.TouchThrottle = -1
end, function()
	Drive.TouchThrottle = 0
end)
holdButton("NOS", Color3.fromRGB(0, 170, 230), UDim2.new(1, 0, 1, -182), UDim2.fromOffset(96, 72), function()
	Drive.SetNitroHeld(true)
end, function()
	Drive.SetNitroHeld(false)
end)
holdButton("DRIFT", Color3.fromRGB(230, 140, 20), UDim2.new(1, -108, 1, -132), UDim2.fromOffset(96, 72), function()
	Drive.SetHandbrake(true)
end, function()
	Drive.SetHandbrake(false)
end)
local fireButton = holdButton("FIRE", Color3.fromRGB(200, 30, 60), UDim2.new(1, -212, 1, -132), UDim2.fromOffset(90, 64), function()
	BlackMarket.Fire()
end, function() end)
holdButton("RESET", Color3.fromRGB(60, 60, 80), UDim2.new(1, -212, 1, -206), UDim2.fromOffset(90, 50), function()
	RespawnCar:FireServer()
end, function() end)

---------------------------------------------------------------------------
-- Show only while driving on a touch screen; switch the default thumbstick off meanwhile
---------------------------------------------------------------------------
local controls: any = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	if ok and module then
		controls = module:GetControls()
	end
end)

local shown = false
RunService.RenderStepped:Connect(function()
	local want = Input.IsTouch() and Drive.Car ~= nil and not Drive.MenuOpen and not Garage.InGarage() and not BlackMarket.Open
	if want ~= shown then
		shown = want
		gui.Enabled = want
		HUD.SetTouchLayout(want)
		if controls then
			pcall(function()
				if want then
					controls:Disable()
				else
					controls:Enable()
				end
			end)
		end
		if not want then
			Drive.TouchThrottle = 0
			Drive.TouchSteer = 0
			Drive.SetNitroHeld(false)
			Drive.SetHandbrake(false)
		end
	end
	local w = player:GetAttribute("Weapon")
	fireButton.Visible = type(w) == "string" and w ~= ""
end)

return TouchControls
