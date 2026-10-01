--[[
	ResultsScreen
	End-of-match summary: win/lose banner, your stats, XP + Credits breakdown
	(all computed by the server), level progress and the top of the
	scoreboard. Closes automatically when you return to the lobby.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local MapConfig = require(Shared.Config.MapConfig)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.SoundController)

local ResultsScreen = {}

local player = Players.LocalPlayer
local Theme = UIKit.Theme

local root: Frame
local ui: { [string]: any } = {}
local closesAt = 0

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function ResultsScreen:Build()
	local screen = UIKit.GetScreen("Results", 30)
	root = UIKit.Create("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.2, Visible = false, Parent = screen })
	local holder = UIKit.Create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 600), BackgroundTransparency = 1, Parent = root })
	UIKit.AutoScale(holder, 0.5, 1.3)
	ui.Banner = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 72, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 80), Parent = holder })
	ui.BannerGradient = UIKit.Gradient(ui.Banner, Theme.Accent, Theme.Accent2)
	ui.Sub = UIKit.Label({ Text = "", TextSize = 20, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 26), Parent = holder })

	local left = UIKit.Panel({ Position = UDim2.fromOffset(0, 124), Size = UDim2.fromOffset(480, 430), Parent = holder })
	UIKit.Padding(left, 16)
	ui.StatsLine = UIKit.Label({ Text = "", TextSize = 22, RichText = true, Size = UDim2.new(1, 0, 0, 30), Parent = left })
	ui.Rewards = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 250), BackgroundTransparency = 1, Parent = left })
	UIKit.List(ui.Rewards, Enum.FillDirection.Vertical, 4)
	ui.Totals = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 22, TextColor3 = Theme.Yellow, Position = UDim2.new(0, 0, 1, -70), Size = UDim2.new(1, 0, 0, 26), Parent = left })
	ui.LevelBar = UIKit.Bar({ Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 12), Parent = left })
	ui.LevelLabel = UIKit.Label({ Text = "", TextSize = 14, TextColor3 = Theme.SubText, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), Parent = left })

	local right = UIKit.Panel({ Position = UDim2.fromOffset(500, 124), Size = UDim2.fromOffset(500, 430), Parent = holder })
	UIKit.Padding(right, 16)
	UIKit.Label({ Text = "TOP PLAYERS", Font = UIKit.FontBlack, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), Parent = right })
	ui.Top = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), BackgroundTransparency = 1, Parent = right })
	UIKit.List(ui.Top, Enum.FillDirection.Vertical, 4)

	ui.Countdown = UIKit.Label({ Text = "", TextSize = 16, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 566), Size = UDim2.new(1, 0, 0, 24), Parent = holder })
end

function ResultsScreen:Show(data)
	local mode = MatchConfig.Modes[data.Mode]
	local map = MapConfig.Get(data.Map)
	if data.Reason == "Aborted" then
		ui.Banner.Text = "MATCH ENDED"
	elseif data.Draw then
		ui.Banner.Text = "DRAW"
	elseif data.Won then
		ui.Banner.Text = "VICTORY!"
	else
		ui.Banner.Text = "GOOD GAME"
	end
	ui.BannerGradient.Color = if data.Won
		then ColorSequence.new(Theme.Yellow, Theme.Accent2)
		else ColorSequence.new(Theme.Accent, Theme.Accent2)
	local winner = if data.WinnerName then string.format("%s wins", data.WinnerName) else ""
	ui.Sub.Text = string.format("%s  •  %s  •  %s", mode and mode.DisplayName or "", map and map.DisplayName or "", winner)

	local stats = data.Stats or {}
	ui.StatsLine.Text = string.format(
		'E <b>%d</b>   D <b>%d</b>   A <b>%d</b>   SCORE <b>%d</b>',
		stats.Kills or 0, stats.Deaths or 0, stats.Assists or 0, stats.Score or 0
	)

	clear(ui.Rewards)
	local rewards = data.Rewards
	if rewards then
		for index, line in rewards.Breakdown do
			local label = UIKit.Label({ Text = string.format("+%d XP   %s", line.XP, line.Label), TextSize = 17, TextTransparency = 1, LayoutOrder = index, Parent = ui.Rewards })
			task.delay(0.25 * index, function()
				UIKit.Tween(label, 0.25, { TextTransparency = 0 })
				SoundController:Play("XP")
			end)
		end
		ui.Totals.Text = string.format("+%d XP    +%d CREDITS", rewards.XP, rewards.Credits)
	else
		ui.Totals.Text = "No rewards (match ended early)"
	end

	local profile = ClientState.Get("Profile")
	if profile then
		local level, into, needed = ProgressionConfig.LevelFromXP(profile.XP)
		ui.LevelBar.Set(0)
		task.delay(0.4, function()
			ui.LevelBar.Set(if needed > 0 then into / needed else 1, true)
		end)
		ui.LevelLabel.Text = string.format("LEVEL %d  •  %d / %d XP", level, into, needed)
	end

	clear(ui.Top)
	for index, entry in data.Scoreboard or {} do
		if index > 8 then
			break
		end
		local teamColor = if entry.Team and MatchConfig.Teams[entry.Team] then MatchConfig.Teams[entry.Team].Color else Theme.Text
		local row = UIKit.Label({
			Text = string.format("%d.  %s%s   —   %d / %d / %d   (%d)", index, entry.Name, if entry.IsBot then " [BOT]" else "", entry.Kills, entry.Deaths, entry.Assists, entry.Score),
			TextSize = 17,
			TextColor3 = if entry.Id == player.UserId then Theme.Yellow else teamColor,
			LayoutOrder = index,
			Parent = ui.Top,
		})
		row.BackgroundTransparency = 1
	end

	closesAt = os.clock() + (data.Duration or 10)
	UIKit.SetOpen(root, true)
	SoundController:Play(if data.Won then "LevelUp" else "MatchStart")
	task.spawn(function()
		while root.Visible do
			ui.Countdown.Text = string.format("Returning to lobby in %d...", math.max(0, math.ceil(closesAt - os.clock())))
			task.wait(0.25)
		end
	end)
end

function ResultsScreen:Hide()
	UIKit.SetOpen(root, false)
end

function ResultsScreen:IsVisible(): boolean
	return root.Visible
end

function ResultsScreen:Start() end

return ResultsScreen
