--[[
	ScoreboardScreen
	Hold Tab (Select on controller, button on mobile) during a match.
	Shows name, eliminations, deaths, assists, score and ping for every
	participant. Only public match info is shown.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchConfig = require(Shared.Config.MatchConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)

local ScoreboardScreen = {}

local player = Players.LocalPlayer
local Theme = UIKit.Theme

local root: Frame
local columns: { Frame } = {}

local COLUMNS = {
	{ Key = "Name", Label = "PLAYER", Width = 0.42 },
	{ Key = "Kills", Label = "E", Width = 0.1 },
	{ Key = "Deaths", Label = "D", Width = 0.1 },
	{ Key = "Assists", Label = "A", Width = 0.1 },
	{ Key = "Score", Label = "SCORE", Width = 0.14 },
	{ Key = "Ping", Label = "PING", Width = 0.14 },
}

local function header(parent: Instance)
	local row = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = -1, Parent = parent })
	local x = 0
	for _, column in COLUMNS do
		UIKit.Label({
			Text = column.Label,
			TextSize = 13,
			TextColor3 = Theme.SubText,
			TextXAlignment = if column.Key == "Name" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(column.Width, 1),
			Parent = row,
		})
		x += column.Width
	end
end

local function row(parent: Instance, entry, order: number, mode: string?)
	local banner = CosmeticConfig.Get(entry.Banner or "") or CosmeticConfig.Get(CosmeticConfig.Defaults.Banner)
	local isMe = entry.Id == player.UserId
	local frame = UIKit.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = if isMe then Theme.PanelLight else banner.Color,
		BackgroundTransparency = if isMe then 0 else 0.35,
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.Corner(frame, 6)
	local x = 0
	for _, column in COLUMNS do
		local value = entry[column.Key]
		local text = tostring(value)
		if column.Key == "Name" then
			text = string.format("%s%s  <font size=\"12\" color=\"#A0ACCD\">Lv %s%s</font>", if entry.Alive == false then "✖ " else "", entry.Name, tostring(entry.Level or 1), if entry.IsBot then " • BOT" else "")
			if mode == "GunGame" then
				text ..= string.format("  <font size=\"12\" color=\"#FFD246\">Tier %d</font>", entry.GunGameLevel or 1)
			end
		elseif column.Key == "Ping" then
			text = if entry.IsBot then "-" else tostring(value)
		end
		UIKit.Label({
			Text = text,
			RichText = true,
			TextSize = 15,
			TextXAlignment = if column.Key == "Name" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			Position = UDim2.new(x, if column.Key == "Name" then 8 else 0, 0, 0),
			Size = UDim2.fromScale(column.Width, 1),
			Parent = frame,
		})
		x += column.Width
	end
end

local function render()
	for _, column in columns do
		for _, child in column:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end
	local entries = ClientState.Get("Scoreboard") or {}
	local matchState = ClientState.Get("MatchState") or {}
	if matchState.TeamBased then
		for index, team in MatchConfig.TeamOrder do
			local column = columns[index]
			column.Visible = true
			local title = column:FindFirstChild("Title") :: TextLabel
			title.Text = string.format("%s  •  %d", string.upper(MatchConfig.Teams[team].DisplayName), matchState.TeamScores and matchState.TeamScores[team] or 0)
			title.TextColor3 = MatchConfig.Teams[team].Color
			header(column)
			local order = 0
			for _, entry in entries do
				if entry.Team == team then
					order += 1
					row(column, entry, order, matchState.Mode)
				end
			end
		end
	else
		columns[2].Visible = false
		local column = columns[1]
		local title = column:FindFirstChild("Title") :: TextLabel
		title.Text = if matchState.Mode == "GunGame" then "GUN GAME" else "FREE FOR ALL"
		title.TextColor3 = MatchConfig.FreeForAllColor
		header(column)
		for index, entry in entries do
			row(column, entry, index, matchState.Mode)
		end
	end
end

function ScoreboardScreen:Build()
	local screen = UIKit.GetScreen("Scoreboard", 15)
	root = UIKit.Create("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(1060, 520), BackgroundTransparency = 1, Visible = false, Parent = screen })
	UIKit.AutoScale(root, 0.5, 1.2)
	UIKit.List(root, Enum.FillDirection.Horizontal, 20, Enum.HorizontalAlignment.Center)
	for index = 1, 2 do
		local column = UIKit.Panel({ Size = UDim2.fromOffset(520, 520), LayoutOrder = index, Parent = root })
		UIKit.Padding(column, 12)
		UIKit.List(column, Enum.FillDirection.Vertical, 4)
		UIKit.Label({ Name = "Title", Text = "", Font = UIKit.FontBlack, TextSize = 24, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = -2, Parent = column })
		columns[index] = column
	end
end

function ScoreboardScreen:SetVisible(visible: boolean)
	if visible and not ClientState.IsInMatch() then
		visible = false
	end
	root.Visible = visible
	if visible then
		render()
	end
end

function ScoreboardScreen:Start()
	ClientState.Changed:Connect(function(key)
		if key == "Scoreboard" and root.Visible then
			render()
		end
	end)
end

return ScoreboardScreen
