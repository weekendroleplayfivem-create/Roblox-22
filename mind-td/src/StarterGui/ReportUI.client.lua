--[[
	ReportUI
	Two pieces of theatre, both owned here because they're the same idea:
	the enemy telling you what it worked out about you.

	  * THE LEARNER's dialogue lines during the boss fight.
	  * The Enemy Intelligence Report at the end of a run (brief section 25).

	The report is typed out line by line rather than appearing at once — the
	point is for the player to read their own habit being described back to
	them, and a wall of text arriving instantly doesn't land that way.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utility = require(ReplicatedStorage.Shared.Utility)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))

local Signals = ClientState.Signals

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ReportUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

--============================================================
-- Boss dialogue
--============================================================

local bossPanel = UIHelpers.MakePanel(screenGui, UDim2.fromOffset(680, 66), UDim2.new(0.5, -340, 0, 108), UIHelpers.Red)
bossPanel.Visible = false
bossPanel.BackgroundTransparency = 0.06

local bossSpeaker = UIHelpers.MakeLabel(bossPanel, "THE LEARNER", UDim2.new(1, -24, 0, 16), UDim2.fromOffset(16, 8), 11, UIHelpers.Red, UIHelpers.TitleFont)
local bossLine = UIHelpers.MakeLabel(bossPanel, "", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(16, 28), 18, UIHelpers.Text, UIHelpers.MonoFont)

local bossToken = 0

Signals.BossLine.Event:Connect(function(text: string)
	bossToken += 1
	local myToken = bossToken

	bossPanel.Visible = true
	bossPanel.BackgroundTransparency = 0.06
	bossSpeaker.TextTransparency = 0
	bossLine.TextTransparency = 0
	UIHelpers.Typewriter(bossLine, text, 38)

	task.delay(5.5, function()
		if myToken ~= bossToken then
			return -- a newer line replaced this one
		end
		UIHelpers.Tween(bossPanel, 0.6, { BackgroundTransparency = 1 })
		UIHelpers.Tween(bossLine, 0.6, { TextTransparency = 1 })
		UIHelpers.Tween(bossSpeaker, 0.6, { TextTransparency = 1 })
		task.wait(0.65)
		if myToken == bossToken then
			bossPanel.Visible = false
		end
	end)
end)

Signals.BossPhase.Event:Connect(function(phase: number)
	-- A quick red flash to punctuate a phase change.
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = UIHelpers.Red
	flash.BackgroundTransparency = 0.75
	flash.BorderSizePixel = 0
	flash.ZIndex = 0
	flash.Parent = screenGui
	UIHelpers.Tween(flash, 0.7, { BackgroundTransparency = 1 })
	task.delay(0.8, function()
		flash:Destroy()
	end)
	bossSpeaker.Text = string.format("THE LEARNER — PHASE %d", phase)
end)

--============================================================
-- End-of-run report
--============================================================

local reportGui = Instance.new("Frame")
reportGui.Size = UDim2.fromScale(1, 1)
reportGui.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
reportGui.BackgroundTransparency = 1
reportGui.BorderSizePixel = 0
reportGui.Visible = false
reportGui.Parent = screenGui

local reportPanel = UIHelpers.MakePanel(reportGui, UDim2.fromOffset(560, 520), UDim2.new(0.5, -280, 0.5, -260), UIHelpers.Violet)

local outcomeLabel = UIHelpers.MakeLabel(reportPanel, "", UDim2.new(1, -40, 0, 44), UDim2.fromOffset(20, 20), 34, UIHelpers.Text, UIHelpers.TitleFont)
outcomeLabel.TextXAlignment = Enum.TextXAlignment.Center

local headerLabel = UIHelpers.MakeLabel(reportPanel, "", UDim2.new(1, -40, 0, 24), UDim2.fromOffset(20, 64), 14, UIHelpers.Dim, UIHelpers.MonoFont)
headerLabel.TextXAlignment = Enum.TextXAlignment.Center

local reportBody = UIHelpers.MakeLabel(reportPanel, "", UDim2.new(1, -48, 1, -180), UDim2.fromOffset(24, 100), 15, UIHelpers.Text, UIHelpers.MonoFont)
reportBody.TextYAlignment = Enum.TextYAlignment.Top
reportBody.TextXAlignment = Enum.TextXAlignment.Left

local verdictLabel = UIHelpers.MakeLabel(reportPanel, "", UDim2.new(1, -40, 0, 30), UDim2.new(0, 20, 1, -56), 20, UIHelpers.Violet, UIHelpers.TitleFont)
verdictLabel.TextXAlignment = Enum.TextXAlignment.Center

local reportToken = 0

local function buildReportText(report): string
	return table.concat({
		"STRATEGY DETECTED",
		"  " .. tostring(report.DetectedStrategy),
		"",
		"MOST USED TOWER",
		"  " .. tostring(report.MostUsedTower),
		"",
		"SLOW USAGE          " .. Utility.Percent(report.SlowUsage or 0),
		"LONG-RANGE USAGE    " .. Utility.Percent(report.LongRangeUsage or 0),
		"",
		"ENEMY ADAPTATION",
		"  " .. tostring(report.AdaptationLabel) .. "  (" .. Utility.Percent(report.Adaptation or 0) .. ")",
		"",
		"WEAKNESS DETECTED",
		"  " .. tostring(report.WeakSide),
		"",
		"COUNTER STRATEGY",
		"  " .. tostring(report.CounterStrategy) .. "  →  " .. tostring(report.CounterUnit),
		"",
		"TOWERS BUILT " .. tostring(report.TowersBuilt) .. "   UPGRADES " .. tostring(report.Upgrades) .. "   LEAKS " .. tostring(report.Leaks),
	}, "\n")
end

Signals.RunEnded.Event:Connect(function(payload)
	reportToken += 1
	local myToken = reportToken

	local report = payload.Report
	if not report then
		return
	end

	reportGui.Visible = true
	UIHelpers.Tween(reportGui, 0.5, { BackgroundTransparency = 0.15 })

	outcomeLabel.Text = if payload.Victory then "OUTPOST HELD" else "OUTPOST LOST"
	outcomeLabel.TextColor3 = if payload.Victory then UIHelpers.Green else UIHelpers.Red

	headerLabel.Text = string.format("ENEMY REPORT  —  REACHED WAVE %d / %d", payload.Wave, payload.TotalWaves)

	reportBody.Text = ""
	verdictLabel.Text = ""

	-- Let the panel land, then type the body out.
	task.delay(0.5, function()
		if myToken ~= reportToken then
			return
		end
		UIHelpers.Typewriter(reportBody, buildReportText(report), 220)
	end)

	task.delay(3.6, function()
		if myToken ~= reportToken then
			return
		end
		verdictLabel.Text = "THE ENEMY HAS LEARNED."
		verdictLabel.TextTransparency = 1
		UIHelpers.Tween(verdictLabel, 0.9, { TextTransparency = 0 })
	end)

	-- The server restarts the run 20s after it ends; clear a little before
	-- that so the player sees the new prep phase begin.
	task.delay(17, function()
		if myToken ~= reportToken then
			return
		end
		UIHelpers.Tween(reportGui, 0.6, { BackgroundTransparency = 1 })
		task.wait(0.65)
		if myToken == reportToken then
			reportGui.Visible = false
		end
	end)
end)
