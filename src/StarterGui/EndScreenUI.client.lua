--[[
	EndScreenUI
	Victory/Defeat summary (brief section 26). Shown when MatchManager
	reports State == "PostMatch"; the match auto-restarts on the server after
	MatchData.IntermissionTime, so "PLAY AGAIN" just clears this screen and
	returns to the main menu — the next match is already on its way.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))
local UIState = require(playerScripts:WaitForChild("UIState"))
local MatchData = require(ReplicatedStorage.Shared.MatchData)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStateChanged = Remotes:WaitForChild("MatchStateChanged")
local RequestPlayerProfile = Remotes:WaitForChild("RequestPlayerProfile")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EndScreenUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 30
screenGui.Enabled = false
screenGui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(4, 4, 8)
background.BackgroundTransparency = 0.05
background.Parent = screenGui

local resultLabel = UIHelpers.Label(background, "VICTORY", UDim2.fromOffset(700, 90), UDim2.new(0.5, -350, 0.14, 0), 72)
resultLabel.TextXAlignment = Enum.TextXAlignment.Center
resultLabel.TextColor3 = Color3.new(1, 1, 1)

local subResultLabel = UIHelpers.Label(background, "BLUE TEAM WINS", UDim2.fromOffset(700, 40), UDim2.new(0.5, -350, 0.28, 0), 26)
subResultLabel.TextXAlignment = Enum.TextXAlignment.Center

local statsPanel = UIHelpers.Panel(background, UDim2.fromOffset(560, 260), UDim2.new(0.5, -280, 0.42, 0), UIHelpers.NeonBlue)

local mvpLabel = UIHelpers.Label(statsPanel, "MVP\n-", UDim2.fromOffset(520, 50), UDim2.fromOffset(20, 16), 20, UIHelpers.NeonPurple)
mvpLabel.TextXAlignment = Enum.TextXAlignment.Center

local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.fromOffset(520, 130)
statsRow.Position = UDim2.fromOffset(20, 90)
statsRow.BackgroundTransparency = 1
statsRow.Parent = statsPanel

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsLayout.Padding = UDim.new(0, 30)
statsLayout.Parent = statsRow

local function statBlock(title)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(150, 130)
	frame.BackgroundTransparency = 1
	frame.Parent = statsRow

	UIHelpers.Label(frame, title, UDim2.fromOffset(150, 24), UDim2.fromOffset(0, 0), 15, Color3.fromRGB(180, 180, 195)).TextXAlignment = Enum.TextXAlignment.Center
	local value = UIHelpers.Label(frame, "0", UDim2.fromOffset(150, 60), UDim2.fromOffset(0, 30), 40)
	value.TextXAlignment = Enum.TextXAlignment.Center
	return value
end

local killsValue = statBlock("ELIMINATIONS")
local deathsValue = statBlock("DEATHS")
local scoreValue = statBlock("SCORE")

local buttonRow = Instance.new("Frame")
buttonRow.Size = UDim2.fromOffset(420, 56)
buttonRow.AnchorPoint = Vector2.new(0.5, 0)
buttonRow.Position = UDim2.new(0.5, 0, 0.82, 0)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = background

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.Padding = UDim.new(0, 20)
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Parent = buttonRow

local function closeEndScreen()
	screenGui.Enabled = false
	ClientState.Camera.InputEnabled = true
end

UIHelpers.Button(buttonRow, "PLAY AGAIN", UDim2.fromOffset(200, 50), UDim2.fromOffset(0, 0), UIHelpers.NeonBlue).MouseButton1Click:Connect(function()
	closeEndScreen()
	Remotes:WaitForChild("PlayClicked"):FireServer()
end)

UIHelpers.Button(buttonRow, "MAIN MENU", UDim2.fromOffset(200, 50), UDim2.fromOffset(0, 0), UIHelpers.NeonPurple).MouseButton1Click:Connect(function()
	closeEndScreen()
	UIState.Open("MainMenu")
end)

MatchStateChanged.OnClientEvent:Connect(function(data)
	if data.State ~= "PostMatch" then
		return
	end

	local won = false
	if data.WinningPlayer then
		won = data.WinningPlayer == player.Name
		subResultLabel.Text = data.WinningPlayer:upper() .. " WINS"
	elseif data.WinningTeam then
		local winningTeamName = MatchData.Teams[data.WinningTeam] and MatchData.Teams[data.WinningTeam].Name
		won = player.Team ~= nil and player.Team.Name == winningTeamName
		subResultLabel.Text = data.WinningTeam:upper() .. " TEAM WINS"
	end

	resultLabel.Text = won and "VICTORY" or "DEFEAT"
	resultLabel.TextColor3 = won and UIHelpers.NeonBlue or Color3.fromRGB(255, 90, 90)
	mvpLabel.Text = "MVP\n" .. (data.MVP or "-")

	task.spawn(function()
		local ok, profile = pcall(function()
			return RequestPlayerProfile:InvokeServer()
		end)
		if ok and profile then
			killsValue.Text = tostring(profile.Kills)
			deathsValue.Text = tostring(profile.Deaths)
			scoreValue.Text = tostring(profile.Kills * MatchData.KillScore)
		end
	end)

	screenGui.Enabled = true
	ClientState.Camera.InputEnabled = false
end)
