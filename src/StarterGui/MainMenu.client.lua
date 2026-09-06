--[[
	MainMenu
	First interactive screen after loading (brief section 23). PLAY drops the
	player into whatever match is currently running/starting; the other
	buttons open the Inventory/Loadout/Settings screens via UIState.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))
local UIState = require(playerScripts:WaitForChild("UIState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlayClicked = Remotes:WaitForChild("PlayClicked")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainMenu"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(4, 4, 8)
background.Parent = screenGui

for i, color in ipairs({ UIHelpers.NeonBlue, UIHelpers.NeonPurple }) do
	local glow = Instance.new("Frame")
	glow.Size = UDim2.fromOffset(900, 900)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(i == 1 and 0.15 or 0.85, 0, 0.5, 0)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.88
	glow.BorderSizePixel = 0
	glow.Parent = background
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = glow
end

-- A parked scooter silhouette hint (simple neon-outlined shape) sits behind the title.
local scooterHint = Instance.new("Frame")
scooterHint.Size = UDim2.fromOffset(320, 140)
scooterHint.AnchorPoint = Vector2.new(0.5, 0.5)
scooterHint.Position = UDim2.new(0.5, 0, 0.78, 0)
scooterHint.BackgroundTransparency = 1
scooterHint.Parent = background
local hintStroke = Instance.new("UIStroke")
hintStroke.Color = UIHelpers.NeonPurple
hintStroke.Thickness = 2
hintStroke.Transparency = 0.5
hintStroke.Parent = scooterHint

local titleFrame = Instance.new("Frame")
titleFrame.Size = UDim2.fromOffset(700, 160)
titleFrame.AnchorPoint = Vector2.new(0.5, 0)
titleFrame.Position = UDim2.new(0.5, 0, 0.12, 0)
titleFrame.BackgroundTransparency = 1
titleFrame.Parent = background

local title = UIHelpers.Label(titleFrame, "HYPER BLAST", UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0), 80)
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextColor3 = Color3.new(1, 1, 1)
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = UIHelpers.NeonBlue
titleStroke.Thickness = 3
titleStroke.Parent = title

local subtitle = UIHelpers.Label(titleFrame, "RIDE. AIM. BLAST.", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.62), 22)
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.Font = UIHelpers.BodyFont
subtitle.TextColor3 = UIHelpers.NeonPurple

task.spawn(function()
	while title.Parent do
		UIHelpers.Tween(title, 2, { TextTransparency = 0.15 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(2)
		UIHelpers.Tween(title, 2, { TextTransparency = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(2)
	end
end)

local buttonPanel = Instance.new("Frame")
buttonPanel.Size = UDim2.fromOffset(260, 380)
buttonPanel.AnchorPoint = Vector2.new(0, 0.5)
buttonPanel.Position = UDim2.new(0, 60, 0.55, 0)
buttonPanel.BackgroundTransparency = 1
buttonPanel.Parent = background

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 14)
buttonLayout.Parent = buttonPanel

local statusLabel = UIHelpers.Label(background, "", UDim2.fromOffset(500, 60), UDim2.new(0.5, -250, 0.9, 0), 22)
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.TextColor3 = UIHelpers.NeonBlue
statusLabel.Visible = false

local function setMenuVisible(visible)
	screenGui.Enabled = visible
	ClientState.Camera.InputEnabled = not visible
end

local function playSearchSequence()
	statusLabel.Visible = true
	local playerCount = #Players:GetPlayers()
	statusLabel.Text = "SEARCHING FOR MATCH..."
	task.wait(0.6)
	statusLabel.Text = string.format("PLAYERS FOUND: %d/8", math.min(playerCount, 8))
	task.wait(0.6)
	statusLabel.Text = "MATCH STARTING..."
	task.wait(0.5)
	statusLabel.Visible = false
end

local playButton = UIHelpers.Button(buttonPanel, "PLAY", UDim2.fromOffset(260, 56), UDim2.fromOffset(0, 0), UIHelpers.NeonBlue)
playButton.MouseButton1Click:Connect(function()
	task.spawn(playSearchSequence)
	PlayClicked:FireServer()
	setMenuVisible(false)
end)

UIHelpers.Button(buttonPanel, "LOADOUT", UDim2.fromOffset(260, 48), UDim2.fromOffset(0, 0), UIHelpers.NeonPurple).MouseButton1Click:Connect(function()
	UIState.Open("Inventory", "Loadout")
end)

UIHelpers.Button(buttonPanel, "INVENTORY", UDim2.fromOffset(260, 48), UDim2.fromOffset(0, 0), UIHelpers.NeonPurple).MouseButton1Click:Connect(function()
	UIState.Open("Inventory", "Weapons")
end)

UIHelpers.Button(buttonPanel, "SCOOTERS", UDim2.fromOffset(260, 48), UDim2.fromOffset(0, 0), UIHelpers.NeonPurple).MouseButton1Click:Connect(function()
	UIState.Open("Inventory", "Scooters")
end)

UIHelpers.Button(buttonPanel, "SHOP", UDim2.fromOffset(260, 48), UDim2.fromOffset(0, 0), UIHelpers.NeonBlue).MouseButton1Click:Connect(function()
	UIState.Open("Inventory", "Skins")
end)

UIHelpers.Button(buttonPanel, "SETTINGS", UDim2.fromOffset(260, 48), UDim2.fromOffset(0, 0), UIHelpers.NeonBlue).MouseButton1Click:Connect(function()
	UIState.Open("Settings")
end)

UIState.Register("MainMenu", function()
	setMenuVisible(true)
end, function()
	setMenuVisible(false)
end)

setMenuVisible(true)
