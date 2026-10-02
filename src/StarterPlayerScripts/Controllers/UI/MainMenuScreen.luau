--[[
	MainMenuScreen
	Lobby menu (StarterGui/MainMenu): PLAY, LOADOUT, CUSTOMIZE, SHOP,
	SETTINGS, STATS, plus the player card and queue status. In a match the
	same ScreenGui shows a compact pause menu (RESUME / LOADOUT / SETTINGS /
	LEAVE MATCH).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local MatchConfig = require(Shared.Config.MatchConfig)
local MapConfig = require(Shared.Config.MapConfig)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.SoundController)

local MainMenuScreen = {}

local player = Players.LocalPlayer
local Theme = UIKit.Theme

local screen: ScreenGui
local lobbyRoot: Frame
local pauseRoot: Frame
local ui: { [string]: any } = {}
local UIController = nil
local activePanel = "Play"

local function formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

--[[ Panels ]]

local function buildPlayPanel(parent: Frame)
	local panel = UIKit.Create("Frame", { Name = "Play", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })
	UIKit.Label({ Text = "SELECT MODE", Font = UIKit.FontBlack, TextSize = 28, Size = UDim2.new(1, 0, 0, 34), Parent = panel })
	ui.MatchInfo = UIKit.Label({ Text = "", TextSize = 16, TextColor3 = Theme.Yellow, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 22), Parent = panel })
	local cards = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, Parent = panel })
	UIKit.List(cards, Enum.FillDirection.Horizontal, 12)
	ui.ModeCards = {}
	for index, modeId in MatchConfig.ModeOrder do
		local mode = MatchConfig.Modes[modeId]
		local card = UIKit.Button({
			Text = "",
			Size = UDim2.fromOffset(200, 220),
			LayoutOrder = index,
			OnClick = function()
				SoundController:Play("QueueJoin")
				Net.Event("Match", "QueueRequest"):FireServer("Join", modeId)
			end,
			Parent = cards,
		})
		UIKit.Padding(card, 12)
		UIKit.Label({ Text = mode.ShortName, Font = UIKit.FontBlack, TextSize = 40, TextColor3 = if index == 1 then Theme.Accent elseif index == 2 then Theme.Yellow else Theme.Accent2, Size = UDim2.new(1, 0, 0, 44), Parent = card })
		UIKit.Label({ Text = string.upper(mode.DisplayName), TextSize = 16, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 20), Parent = card })
		UIKit.Label({ Text = mode.Description, TextSize = 14, Font = UIKit.FontRegular, TextColor3 = Theme.SubText, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 90), Parent = card })
		local votes = UIKit.Label({ Text = "", TextSize = 14, TextColor3 = Theme.Yellow, Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 20), Parent = card })
		ui.ModeCards[modeId] = { Card = card, Votes = votes }
	end
	ui.QuickPlay = UIKit.Button({
		Text = "QUICK PLAY",
		Font = UIKit.FontBlack,
		TextSize = 24,
		Color = Color3.fromRGB(20, 120, 150),
		Position = UDim2.fromOffset(0, 300),
		Size = UDim2.fromOffset(624, 60),
		OnClick = function()
			SoundController:Play("QueueJoin")
			Net.Event("Match", "QueueRequest"):FireServer("Join", nil)
		end,
		Parent = panel,
	})
	UIKit.Label({
		Text = "Tip: Sprint + Crouch to slide, jump mid-slide to keep your speed. Press Space in the air to double jump or bounce off walls.",
		TextSize = 14,
		Font = UIKit.FontRegular,
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 372),
		Size = UDim2.fromOffset(624, 40),
		Parent = panel,
	})
	return panel
end

local function buildStatsPanel(parent: Frame)
	local panel = UIKit.Create("Frame", { Name = "Stats", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = parent })
	UIKit.Label({ Text = "YOUR STATS", Font = UIKit.FontBlack, TextSize = 28, Size = UDim2.new(0.5, 0, 0, 34), Parent = panel })
	ui.StatsList = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(0.48, 0, 1, -44), BackgroundTransparency = 1, Parent = panel })
	UIKit.List(ui.StatsList, Enum.FillDirection.Vertical, 6)
	UIKit.Label({ Text = "TOP ELIMINATORS", Font = UIKit.FontBlack, TextSize = 28, Position = UDim2.fromScale(0.52, 0), Size = UDim2.new(0.48, 0, 0, 34), Parent = panel })
	ui.GlobalList = UIKit.Create("Frame", { Position = UDim2.new(0.52, 0, 0, 44), Size = UDim2.new(0.48, 0, 1, -44), BackgroundTransparency = 1, Parent = panel })
	UIKit.List(ui.GlobalList, Enum.FillDirection.Vertical, 4)
	return panel
end

local function statRow(parent: Instance, label: string, value: string, order: number)
	local row = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.2, LayoutOrder = order, Parent = parent })
	UIKit.Corner(row, 6)
	UIKit.Padding(row, 6)
	UIKit.Label({ Text = label, TextSize = 16, TextColor3 = Theme.SubText, Size = UDim2.fromScale(0.6, 1), Parent = row })
	UIKit.Label({ Text = value, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromScale(0.6, 0), Size = UDim2.fromScale(0.4, 1), Parent = row })
end

local function refreshStats()
	for _, child in ui.StatsList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local profile = ClientState.Get("Profile")
	if not profile then
		return
	end
	local stats = profile.Stats
	local kd = stats.Eliminations / math.max(1, stats.Deaths)
	local rows = {
		{ "Level", tostring(profile.Level) },
		{ "Eliminations", formatNumber(stats.Eliminations) },
		{ "Assists", formatNumber(stats.Assists) },
		{ "Deaths", formatNumber(stats.Deaths) },
		{ "Elim / Death", string.format("%.2f", kd) },
		{ "Headshots", formatNumber(stats.Headshots) },
		{ "Damage Dealt", formatNumber(stats.DamageDealt) },
		{ "Matches", formatNumber(stats.MatchesPlayed) },
		{ "Wins", formatNumber(stats.Wins) },
		{ "Best Streak", tostring(stats.BestStreak) },
		{ "Play Time", string.format("%dh %dm", stats.PlayTimeSeconds // 3600, (stats.PlayTimeSeconds % 3600) // 60) },
	}
	for index, row in rows do
		statRow(ui.StatsList, row[1], row[2], index)
	end

	task.spawn(function()
		local ok, entries = pcall(function()
			return Net.Function("UI", "GetLeaderboard"):InvokeServer()
		end)
		for _, child in ui.GlobalList:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		if not ok or type(entries) ~= "table" or #entries == 0 then
			UIKit.Label({ Text = "Leaderboard unavailable right now.", TextColor3 = Theme.SubText, TextSize = 16, Parent = ui.GlobalList })
			return
		end
		for index, entry in entries do
			statRow(ui.GlobalList, string.format("#%d  %s", entry.Rank, entry.Name), formatNumber(entry.Value), index)
		end
	end)
end

local function showPanel(name: string)
	activePanel = name
	ui.PlayPanel.Visible = name == "Play"
	ui.StatsPanel.Visible = name == "Stats"
	if name == "Stats" then
		refreshStats()
	end
end

--[[ Player card + queue bar ]]

local function buildPlayerCard(parent: Frame)
	local card = UIKit.Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 30), Size = UDim2.fromOffset(320, 112), Parent = parent })
	UIKit.Padding(card, 12)
	UIKit.Label({ Text = player.DisplayName, Font = UIKit.FontBlack, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), Parent = card })
	ui.LevelLabel = UIKit.Label({ Text = "LEVEL 1", TextSize = 16, TextColor3 = Theme.Accent, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 20), Parent = card })
	ui.XPBar = UIKit.Bar({ Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 8), Color = Theme.Accent, Parent = card })
	ui.XPLabel = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 16), Parent = card })
	ui.Credits = UIKit.Label({ Text = "", TextSize = 16, TextColor3 = Theme.Yellow, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 20), Parent = card })
	ui.TempWarning = UIKit.Label({ Text = "Progress won't save this session", Visible = false, TextSize = 12, TextColor3 = Theme.Danger, Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 14), Parent = card })
	UIKit.AutoScale(card, 0.6, 1.2)
end

local function refreshPlayerCard(profile)
	if not profile then
		return
	end
	local level, into, needed = ProgressionConfig.LevelFromXP(profile.XP)
	ui.LevelLabel.Text = "LEVEL " .. tostring(level)
	ui.XPBar.Set(if needed > 0 then into / needed else 1, true)
	ui.XPLabel.Text = if needed > 0 then string.format("%s / %s XP", formatNumber(into), formatNumber(needed)) else "MAX LEVEL"
	ui.Credits.Text = formatNumber(profile.Credits) .. " CREDITS"
	ui.TempWarning.Visible = ClientState.Get("TemporaryProfile") == true
	if activePanel == "Stats" and lobbyRoot.Visible then
		refreshStats()
	end
end

local function buildQueueBar(parent: Instance)
	local bar = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(560, 64), Visible = false, Parent = parent })
	UIKit.Padding(bar, 10)
	ui.QueueText = UIKit.Label({ Text = "", TextSize = 20, Size = UDim2.new(1, -150, 0, 24), Parent = bar })
	ui.QueueSub = UIKit.Label({ Text = "", TextSize = 14, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -150, 0, 20), Parent = bar })
	UIKit.Button({
		Text = "LEAVE QUEUE",
		TextSize = 16,
		Color = Color3.fromRGB(90, 30, 50),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(140, 40),
		OnClick = function()
			Net.Event("Match", "QueueRequest"):FireServer("Leave")
		end,
		Parent = bar,
	})
	ui.QueueBar = bar
	UIKit.AutoScale(bar, 0.6, 1.2)
end

local function refreshQueue(state)
	if not state then
		return
	end
	ui.QueueBar.Visible = state.Queued == true and ClientState.Get("Location") == "Lobby"
	if state.Queued then
		local modeName = if state.Mode and MatchConfig.Modes[state.Mode] then MatchConfig.Modes[state.Mode].DisplayName else "Any mode"
		ui.QueueText.Text = "IN QUEUE  •  " .. string.upper(modeName)
		local sub = string.format("%d player(s) queued", state.Count or 0)
		if state.StartsAt then
			sub ..= string.format("  •  starting in %ds", math.max(0, math.ceil(state.StartsAt - workspace:GetServerTimeNow())))
		elseif state.MatchPhase ~= "Lobby" then
			sub ..= "  •  waiting for the current match to finish"
		else
			sub ..= string.format("  •  need %d to start (bots fill the rest)", state.MinPlayers or 1)
		end
		ui.QueueSub.Text = sub
	end
	for modeId, widgets in ui.ModeCards do
		local votes = state.Votes and state.Votes[modeId] or 0
		widgets.Votes.Text = if votes > 0 then string.format("%d vote%s", votes, if votes == 1 then "" else "s") else ""
	end
	if state.CanJoinInProgress and state.MatchMode then
		local mode = MatchConfig.Modes[state.MatchMode]
		local map = state.MatchMap and MapConfig.Get(state.MatchMap)
		ui.MatchInfo.Text = string.format("Match in progress: %s on %s — pick any mode to jump in!", mode and mode.DisplayName or "?", map and map.DisplayName or "?")
		ui.QuickPlay.Text = "JOIN MATCH IN PROGRESS"
	else
		ui.MatchInfo.Text = if state.MatchPhase and state.MatchPhase ~= "Lobby" then "A match is finishing — you'll be first in line." else ""
		ui.QuickPlay.Text = "QUICK PLAY"
	end
end

--[[ Build ]]

local function navButton(parent: Instance, text: string, order: number, onClick: () -> ())
	return UIKit.Button({
		Text = text,
		Font = UIKit.FontBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(300, 50),
		LayoutOrder = order,
		OnClick = onClick,
		Parent = parent,
	})
end

local function buildLobby()
	lobbyRoot = UIKit.Create("Frame", { Name = "Lobby", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = screen })
	local shade = UIKit.Create("Frame", { Size = UDim2.fromScale(0.75, 1), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = lobbyRoot })
	UIKit.Create("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Parent = shade,
	})

	local left = UIKit.Create("Frame", { Position = UDim2.fromOffset(50, 40), Size = UDim2.fromOffset(340, 640), BackgroundTransparency = 1, Parent = lobbyRoot })
	UIKit.AutoScale(left, 0.55, 1.2)
	local title = UIKit.Label({ Text = "VECTOR RUSH", Font = UIKit.FontBlack, TextSize = 52, Size = UDim2.new(1, 60, 0, 60), Parent = left })
	UIKit.Gradient(title, Theme.Accent, Theme.Accent2)
	UIKit.Label({ Text = "ARENA SHOOTER  •  PROTOTYPE", TextSize = 14, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(2, 58), Size = UDim2.new(1, 0, 0, 18), Parent = left })
	local nav = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 1, -100), BackgroundTransparency = 1, Parent = left })
	UIKit.List(nav, Enum.FillDirection.Vertical, 10)
	navButton(nav, "  PLAY", 1, function()
		showPanel("Play")
	end)
	navButton(nav, "  LOADOUT", 2, function()
		UIController:OpenMenu("Loadout")
	end)
	navButton(nav, "  CUSTOMIZE", 3, function()
		UIController:OpenMenu("Customize")
	end)
	navButton(nav, "  SHOP", 4, function()
		UIController:OpenMenu("Shop")
	end)
	navButton(nav, "  SETTINGS", 5, function()
		UIController:OpenMenu("Settings")
	end)
	navButton(nav, "  STATS", 6, function()
		showPanel("Stats")
	end)
	local explore = navButton(nav, "  EXPLORE LOBBY  (M)", 7, function()
		UIController:SetMainMenuVisible(false)
	end)
	explore.TextSize = 16
	explore.TextColor3 = Theme.SubText

	local content = UIKit.Panel({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 420, 0.5, 20), Size = UDim2.fromOffset(660, 440), Parent = lobbyRoot })
	UIKit.Padding(content, 18)
	UIKit.AutoScale(content, 0.55, 1.2)
	ui.PlayPanel = buildPlayPanel(content)
	ui.StatsPanel = buildStatsPanel(content)

	buildPlayerCard(lobbyRoot)
	-- Queue status stays visible even while exploring the lobby.
	buildQueueBar(screen)
end

local function buildPause()
	pauseRoot = UIKit.Create("Frame", { Name = "Pause", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Background, BackgroundTransparency = 0.35, Visible = false, Parent = screen })
	local panel = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 330), Parent = pauseRoot })
	UIKit.Padding(panel, 20)
	UIKit.AutoScale(panel, 0.6, 1.2)
	UIKit.List(panel, Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center)
	UIKit.Label({ Text = "PAUSED", Font = UIKit.FontBlack, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 0, Parent = panel })
	UIKit.Button({ Text = "RESUME", Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 1, OnClick = function()
		UIController:CloseAll()
	end, Parent = panel })
	UIKit.Button({ Text = "LOADOUT", Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 2, OnClick = function()
		UIController:OpenMenu("Loadout")
	end, Parent = panel })
	UIKit.Button({ Text = "SETTINGS", Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 3, OnClick = function()
		UIController:OpenMenu("Settings")
	end, Parent = panel })
	local leave
	leave = UIKit.Button({ Text = "LEAVE MATCH", Color = Color3.fromRGB(110, 30, 60), Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 4, OnClick = function()
		if leave.Text == "LEAVE MATCH" then
			leave.Text = "TAP AGAIN TO CONFIRM"
			task.delay(3, function()
				leave.Text = "LEAVE MATCH"
			end)
			return
		end
		leave.Text = "LEAVE MATCH"
		Net.Event("Match", "QueueRequest"):FireServer("LeaveMatch")
		UIController:CloseAll()
	end, Parent = panel })
end

function MainMenuScreen:Build(controller)
	UIController = controller
	screen = UIKit.GetScreen("MainMenu", 20)
	buildLobby()
	buildPause()
end

function MainMenuScreen:ShowLobby(visible: boolean)
	if visible then
		UIKit.SetOpen(lobbyRoot, true)
		showPanel(activePanel)
	else
		lobbyRoot.Visible = false
	end
end

function MainMenuScreen:ShowPause(visible: boolean)
	UIKit.SetOpen(pauseRoot, visible)
end

function MainMenuScreen:IsLobbyVisible(): boolean
	return lobbyRoot.Visible
end

function MainMenuScreen:IsPauseVisible(): boolean
	return pauseRoot.Visible
end

function MainMenuScreen:Start()
	ClientState.Observe("Profile", refreshPlayerCard)
	ClientState.Observe("QueueState", refreshQueue)
	-- Keep the "starting in" countdown ticking.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if lobbyRoot.Visible or ui.QueueBar.Visible then
				refreshQueue(ClientState.Get("QueueState"))
			end
		end
	end)
	task.defer(function()
		Net.Event("Match", "QueueRequest"):FireServer("Refresh")
	end)
end

return MainMenuScreen
