--[[
	DebugUI
	Developer overlay (brief section 35). Disabled by default; F9 toggles it.

	It only mirrors what this client has already legitimately received, so it
	exposes nothing a player couldn't already see — the redaction on the live
	Enemy Intelligence panel is applied server-side in AdaptiveAI.GetSnapshot
	before anything is sent, so toggling this on cannot reveal a strategy the
	player hasn't earned with Analyzer coverage.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Enabled = false
screenGui.Parent = playerGui

local panel = UIHelpers.MakePanel(screenGui, UDim2.fromOffset(280, 240), UDim2.fromOffset(16, 124), UIHelpers.Amber)

UIHelpers.MakeLabel(panel, "DEBUG  [F9]", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(12, 8), 12, UIHelpers.Amber, UIHelpers.TitleFont)

local readout = UIHelpers.MakeLabel(panel, "", UDim2.new(1, -24, 1, -36), UDim2.fromOffset(12, 28), 12, UIHelpers.Text, UIHelpers.MonoFont)
readout.TextYAlignment = Enum.TextYAlignment.Top

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F9 then
		screenGui.Enabled = not screenGui.Enabled
	end
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if not screenGui.Enabled then
		return
	end
	-- 4Hz is plenty for a text readout, and keeps this off the hot path.
	accumulator += dt
	if accumulator < 0.25 then
		return
	end
	accumulator = 0

	local game = ClientState.Game
	local ai = ClientState.AI

	local towerCount = 0
	for _ in pairs(ClientState.Towers) do
		towerCount += 1
	end

	readout.Text = table.concat({
		string.format("FPS          %d", math.floor(1 / math.max(dt, 0.0001))),
		string.format("PING         %d ms", math.floor(player:GetNetworkPing() * 1000)),
		"",
		string.format("STATE        %s", game.State),
		string.format("WAVE         %d / %d", game.Wave, game.TotalWaves),
		string.format("ENEMIES      %d", game.EnemiesAlive),
		string.format("CORE HP      %d / %d", math.floor(game.CoreHP), game.MaxCoreHP),
		"",
		string.format("STRATEGY     %s", tostring(ai.StrategyName)),
		string.format("ADAPTATION   %.2f", ai.Adaptation or 0),
		string.format("ANALYSIS     %.2f", ai.AnalysisRate or 0),
		string.format("LEFT / RIGHT %.2f / %.2f", ai.LeftUsage or 0, ai.RightUsage or 0),
		string.format("SLOW USAGE   %.2f", ai.SlowUsage or 0),
		string.format("WEAK SIDE    %s", tostring(ai.WeakSide)),
		"",
		string.format("TOWERS       %d", towerCount),
		string.format("FUNDS        %d", ClientState.Money),
	}, "\n")
end)
