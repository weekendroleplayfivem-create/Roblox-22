--[[
	MobileControls
	Touch controls for phones/tablets (brief section 4). Movement rides the
	Humanoid, so Roblox's own on-screen thumbstick already drives the scooter
	on touch devices — this module adds the buttons that aren't covered by it:
	fire, ADS, boost, jump, reload, and weapon switch.
]]

local Players = game:GetService("Players")

local ClientState = require(script.Parent:WaitForChild("ClientState"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NEON_BLUE = Color3.fromRGB(60, 140, 255)
local NEON_PURPLE = Color3.fromRGB(170, 70, 255)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileControls"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function makeButton(name, text, position, size, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.35
	button.Size = size
	button.Position = position
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = button

	button.Parent = screenGui
	return button
end

-- Fire (hold).
local fireButton = makeButton("FireButton", "FIRE", UDim2.new(1, -140, 1, -160), UDim2.fromOffset(110, 110), Color3.fromRGB(255, 70, 70))
fireButton.MouseButton1Down:Connect(function()
	ClientState.Actions.FireDown()
end)
fireButton.MouseButton1Up:Connect(function()
	ClientState.Actions.FireUp()
end)

-- ADS (tap to toggle; simplest touch-friendly behavior).
local adsButton = makeButton("ADSButton", "ADS", UDim2.new(1, -260, 1, -140), UDim2.fromOffset(90, 90), NEON_BLUE)
local adsActive = false
adsButton.MouseButton1Click:Connect(function()
	adsActive = not adsActive
	ClientState.Actions.SetADS(adsActive)
end)

-- Reload.
local reloadButton = makeButton("ReloadButton", "RLD", UDim2.new(1, -140, 1, -280), UDim2.fromOffset(80, 80), Color3.fromRGB(255, 200, 60))
reloadButton.MouseButton1Click:Connect(function()
	ClientState.Actions.Reload()
end)

-- Boost (hold).
local boostButton = makeButton("BoostButton", "BOOST", UDim2.new(0, 30, 1, -160), UDim2.fromOffset(110, 110), NEON_PURPLE)
boostButton.MouseButton1Down:Connect(function()
	ClientState.Actions.SetBoost(true)
end)
boostButton.MouseButton1Up:Connect(function()
	ClientState.Actions.SetBoost(false)
end)

-- Jump.
local jumpButton = makeButton("JumpButton", "JUMP", UDim2.new(0, 150, 1, -140), UDim2.fromOffset(90, 90), NEON_BLUE)
jumpButton.MouseButton1Click:Connect(function()
	ClientState.Actions.Jump()
end)

-- Weapon switch row.
local switchFrame = Instance.new("Frame")
switchFrame.Name = "WeaponSwitch"
switchFrame.BackgroundTransparency = 1
switchFrame.Size = UDim2.new(0, 210, 0, 60)
switchFrame.Position = UDim2.new(1, -220, 1, -350)
switchFrame.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 8)
layout.Parent = switchFrame

for i, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
	local button = Instance.new("TextButton")
	button.Name = slot .. "Button"
	button.Text = tostring(i)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	button.BackgroundTransparency = 0.3
	button.Size = UDim2.fromOffset(60, 60)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = button
	button.Parent = switchFrame
	button.MouseButton1Click:Connect(function()
		ClientState.Actions.SwitchWeapon(slot)
	end)
end

return true
