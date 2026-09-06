--[[
	LoadingScreen
	First thing the player sees (brief section 24 + 40). Waits on the real
	things the game needs — remotes wired up, the map built, default Roblox
	asset loading finished — and disappears the moment they're ready rather
	than faking a fixed-length wait.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIHelpers = require(player:WaitForChild("PlayerScripts"):WaitForChild("UIHelpers"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
background.Parent = screenGui

-- Slowly drifting neon glow blobs for a "living" background.
for i, color in ipairs({ UIHelpers.NeonBlue, UIHelpers.NeonPurple }) do
	local glow = Instance.new("Frame")
	glow.Size = UDim2.fromOffset(700, 700)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(i == 1 and 0.2 or 0.8, 0, 0.5, 0)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.85
	glow.BorderSizePixel = 0
	glow.ZIndex = 0
	glow.Parent = background
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = glow

	task.spawn(function()
		while glow.Parent do
			UIHelpers.Tween(glow, 4, { Position = UDim2.new(i == 1 and 0.3 or 0.7, 0, 0.6, 0) }, Enum.EasingStyle.Sine)
			task.wait(4)
			UIHelpers.Tween(glow, 4, { Position = UDim2.new(i == 1 and 0.2 or 0.8, 0, 0.4, 0) }, Enum.EasingStyle.Sine)
			task.wait(4)
		end
	end)
end

local title = UIHelpers.Label(background, "HYPER BLAST", UDim2.fromOffset(600, 90), UDim2.new(0.5, -300, 0.32, 0), 64)
title.TextXAlignment = Enum.TextXAlignment.Center
title.TextColor3 = Color3.new(1, 1, 1)

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = UIHelpers.NeonBlue
titleStroke.Thickness = 2
titleStroke.Parent = title

-- Rotating futuristic loading symbol.
local symbol = Instance.new("Frame")
symbol.Size = UDim2.fromOffset(64, 64)
symbol.AnchorPoint = Vector2.new(0.5, 0.5)
symbol.Position = UDim2.new(0.5, 0, 0.5, 0)
symbol.BackgroundTransparency = 1
symbol.Parent = background

local ring = Instance.new("UICorner")
ring.CornerRadius = UDim.new(1, 0)

local symbolStroke = Instance.new("Frame")
symbolStroke.Size = UDim2.fromScale(1, 1)
symbolStroke.BackgroundTransparency = 1
symbolStroke.Parent = symbol
local stroke = Instance.new("UIStroke")
stroke.Color = UIHelpers.NeonPurple
stroke.Thickness = 4
stroke.Parent = symbolStroke
ring:Clone().Parent = symbolStroke

task.spawn(function()
	while symbol.Parent do
		symbol.Rotation = (symbol.Rotation + 6) % 360
		task.wait()
	end
end)

local statusLabel = UIHelpers.Label(background, "INITIALIZING HYPER SYSTEM...", UDim2.fromOffset(600, 30), UDim2.new(0.5, -300, 0.58, 0), 18)
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Font = UIHelpers.BodyFont
statusLabel.TextColor3 = UIHelpers.NeonBlue

local track, fill = UIHelpers.ProgressBar(background, UDim2.fromOffset(500, 14), UDim2.new(0.5, -250, 0.63, 0), UIHelpers.NeonBlue)
track.Parent = background

local subLabel = UIHelpers.Label(background, "", UDim2.fromOffset(600, 24), UDim2.new(0.5, -300, 0.67, 0), 14)
subLabel.TextXAlignment = Enum.TextXAlignment.Center
subLabel.Font = UIHelpers.BodyFont
subLabel.TextColor3 = Color3.fromRGB(180, 180, 200)

local STAGES = {
	{ text = "LOADING MAP...", weight = 0.35 },
	{ text = "LOADING WEAPONS...", weight = 0.25 },
	{ text = "CALIBRATING SCOOTER...", weight = 0.2 },
	{ text = "CONNECTING TO ARENA...", weight = 0.2 },
}

local function setProgress(alpha)
	UIHelpers.SetProgress(fill, alpha, 0.3)
end

task.spawn(function()
	local accumulated = 0
	for _, stage in ipairs(STAGES) do
		subLabel.Text = stage.text
		local target = accumulated + stage.weight
		-- Animate smoothly toward this stage's share of the bar while we wait
		-- on the real condition below, so the bar never looks stuck.
		task.spawn(function()
			local start = accumulated
			local t = 0
			while t < 1 and fill.Parent do
				t = math.min(1, t + 0.05)
				setProgress(start + (target - start) * t)
				task.wait(0.05)
			end
		end)
		task.wait(0.3)
		accumulated = target
	end
end)

-- Real readiness gate: remotes wired, map generated, default content loaded.
ReplicatedStorage:WaitForChild("Remotes", 30)
Workspace:WaitForChild("HyperBlastMap", 30)
if not game:IsLoaded() then
	game.Loaded:Wait()
end

setProgress(1)
statusLabel.Text = "READY"
task.wait(0.4)

UIHelpers.Tween(background, 0.6, { BackgroundTransparency = 1 })
for _, descendant in ipairs(background:GetDescendants()) do
	if descendant:IsA("TextLabel") or descendant:IsA("Frame") then
		pcall(function()
			UIHelpers.Tween(descendant, 0.6, { TextTransparency = 1, BackgroundTransparency = 1 })
		end)
	end
end
task.wait(0.65)
screenGui:Destroy()
