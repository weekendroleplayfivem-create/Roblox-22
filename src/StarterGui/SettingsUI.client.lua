--[[
	SettingsUI
	Settings menu (brief section 29). Applies changes to ClientState / local
	SoundGroup volumes immediately, and persists them to the player's server
	profile via the UpdateSettings remote (client-side settings changes never
	need server validation for correctness, only storage).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))
local UIState = require(playerScripts:WaitForChild("UIState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateSettings = Remotes:WaitForChild("UpdateSettings")
local RequestPlayerProfile = Remotes:WaitForChild("RequestPlayerProfile")

local function applyAudioSettings()
	local music = SoundService:FindFirstChild("Music")
	local sfx = SoundService:FindFirstChild("SFX")
	local ui = SoundService:FindFirstChild("UI")
	local weapons = SoundService:FindFirstChild("Weapons")
	local vehicles = SoundService:FindFirstChild("Vehicles")
	local environment = SoundService:FindFirstChild("Environment")
	if music then
		music.Volume = ClientState.Settings.MusicVolume
	end
	for _, group in ipairs({ sfx, ui, weapons, vehicles, environment }) do
		if group then
			group.Volume = ClientState.Settings.SFXVolume
		end
	end
end

task.spawn(function()
	local ok, profile = pcall(function()
		return RequestPlayerProfile:InvokeServer()
	end)
	if ok and profile and profile.Settings then
		ClientState.ApplySettings(profile.Settings)
		applyAudioSettings()
	end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SettingsUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Enabled = false
screenGui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.4
dim.Parent = screenGui

local panel = UIHelpers.Panel(screenGui, UDim2.fromOffset(560, 520), UDim2.new(0.5, -280, 0.5, -260), UIHelpers.NeonPurple)
UIHelpers.Label(panel, "SETTINGS", UDim2.fromOffset(300, 40), UDim2.fromOffset(24, 16), 30)

local closeButton = UIHelpers.Button(panel, "X", UDim2.fromOffset(40, 40), UDim2.new(1, -56, 0, 16), Color3.fromRGB(255, 90, 90))
closeButton.MouseButton1Click:Connect(function()
	UIState.Close("Settings")
end)

local list = Instance.new("Frame")
list.Size = UDim2.fromOffset(500, 420)
list.Position = UDim2.fromOffset(30, 70)
list.BackgroundTransparency = 1
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 16)
layout.Parent = list

local pendingSave = {}
local function queueSave(key, value)
	pendingSave[key] = value
end
task.spawn(function()
	while true do
		task.wait(0.5)
		if next(pendingSave) then
			UpdateSettings:FireServer(pendingSave)
			pendingSave = {}
		end
	end
end)

local function makeSlider(name, key, min, max, onChange)
	local container = Instance.new("Frame")
	container.Size = UDim2.fromOffset(500, 50)
	container.BackgroundTransparency = 1
	container.Parent = list

	local label = UIHelpers.Label(container, name, UDim2.fromOffset(240, 24), UDim2.fromOffset(0, 0), 16)

	local valueLabel = UIHelpers.Label(container, "", UDim2.fromOffset(60, 24), UDim2.new(1, -60, 0, 0), 14, UIHelpers.NeonBlue)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(500, 10)
	track.Position = UDim2.fromOffset(0, 30)
	track.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	track.Parent = container
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = UIHelpers.NeonPurple
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local dragging = false
	local function setFromAlpha(alpha)
		alpha = math.clamp(alpha, 0, 1)
		local value = min + (max - min) * alpha
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		valueLabel.Text = tostring(math.floor(value * 100) / 100)
		ClientState.Settings[key] = value
		queueSave(key, value)
		if onChange then
			onChange(value)
		end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			setFromAlpha(alpha)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			setFromAlpha(alpha)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local initialAlpha = (ClientState.Settings[key] - min) / (max - min)
	setFromAlpha(initialAlpha)

	return container, setFromAlpha
end

local function makeToggle(name, key, onChange)
	local container = Instance.new("Frame")
	container.Size = UDim2.fromOffset(500, 40)
	container.BackgroundTransparency = 1
	container.Parent = list

	UIHelpers.Label(container, name, UDim2.fromOffset(300, 30), UDim2.fromOffset(0, 5), 16)

	local button = UIHelpers.Button(container, ClientState.Settings[key] and "ON" or "OFF", UDim2.fromOffset(90, 34), UDim2.new(1, -90, 0, 3), UIHelpers.NeonBlue)
	button.MouseButton1Click:Connect(function()
		ClientState.Settings[key] = not ClientState.Settings[key]
		button.Text = ClientState.Settings[key] and "ON" or "OFF"
		queueSave(key, ClientState.Settings[key])
		if onChange then
			onChange(ClientState.Settings[key])
		end
	end)
end

makeSlider("MUSIC VOLUME", "MusicVolume", 0, 1, applyAudioSettings)
makeSlider("SFX VOLUME", "SFXVolume", 0, 1, applyAudioSettings)
makeSlider("SENSITIVITY", "Sensitivity", 0, 1, function(value)
	ClientState.Camera.Sensitivity = value
end)
makeSlider("FIELD OF VIEW", "FOV", 60, 110, function(value)
	ClientState.Camera.FOVBase = value
end)
makeToggle("CAMERA SHAKE", "CameraShake", function(value)
	ClientState.Camera.CameraShakeEnabled = value
end)
makeToggle("SHOW DAMAGE NUMBERS", "ShowDamageNumbers")
makeToggle("SHOW KILL FEED", "ShowKillFeed")

local function openSettings()
	screenGui.Enabled = true
	ClientState.Camera.InputEnabled = false
end

local function closeSettings()
	screenGui.Enabled = false
	ClientState.Camera.InputEnabled = true
end

UIState.Register("Settings", openSettings, closeSettings)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled then
		UIState.Close("Settings")
	end
end)
