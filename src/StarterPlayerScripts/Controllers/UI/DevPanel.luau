--[[
	DevPanel
	Studio/private-test developer console (toggle with F2). This is only a
	convenience UI: every command is authorized and executed by the server's
	DevCommandService, which refuses them in public live servers.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local DevConfig = require(Shared.Config.DevConfig)

local UIKit = require(script.Parent.UIKit)

local DevPanel = {}

local Theme = UIKit.Theme

local root: Frame? = nil
local output: TextLabel
local input: TextBox

local QUICK_COMMANDS = {
	"startmatch TeamDeathmatch",
	"startmatch FreeForAll",
	"startmatch GunGame",
	"endmatch",
	"resetround",
	"bots 4 Hard",
	"give PlasmaLauncher",
	"give ChargeBlaster",
	"health 25",
	"god",
	"xp 2500",
	"credits 1000",
	"runtests",
	"help",
}

function DevPanel:IsAvailable(): boolean
	return RunService:IsStudio() or table.find(DevConfig.AuthorizedUserIds, Players.LocalPlayer.UserId) ~= nil
end

local function run(command: string)
	output.Text = "> " .. command
	local ok, success, message = pcall(function()
		return Net.Function("UI", "DevCommand"):InvokeServer(command)
	end)
	if not ok then
		output.Text = "Request failed: " .. tostring(success)
		output.TextColor3 = Theme.Danger
		return
	end
	output.Text = "> " .. command .. "\n" .. tostring(message)
	output.TextColor3 = if success then Theme.Success else Theme.Danger
end

function DevPanel:Build()
	if not DevPanel:IsAvailable() then
		return
	end
	local screen = UIKit.GetScreen("DevPanel", 60)
	local panel = UIKit.Panel({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.5, 0), Size = UDim2.fromOffset(420, 560), Visible = false, Parent = screen })
	root = panel
	UIKit.Padding(panel, 12)
	UIKit.Label({ Text = "DEV CONSOLE (F2)", Font = UIKit.FontBlack, TextSize = 20, TextColor3 = Theme.Yellow, Size = UDim2.new(1, 0, 0, 24), Parent = panel })
	input = UIKit.Create("TextBox", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, -80, 0, 36),
		BackgroundColor3 = Theme.PanelLight,
		TextColor3 = Theme.Text,
		PlaceholderText = "command (e.g. bots 4 Hard)",
		Font = UIKit.FontRegular,
		TextSize = 16,
		ClearTextOnFocus = false,
		Text = "",
		Parent = panel,
	})
	UIKit.Corner(input, 6)
	UIKit.Button({ Text = "RUN", TextSize = 16, Position = UDim2.new(1, -72, 0, 30), Size = UDim2.fromOffset(72, 36), OnClick = function()
		run(input.Text)
	end, Parent = panel })
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed and input.Text ~= "" then
			run(input.Text)
		end
	end)
	local grid = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 290), BackgroundTransparency = 1, Parent = panel })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(194, 34), CellPadding = UDim2.fromOffset(8, 6), Parent = grid })
	for _, command in QUICK_COMMANDS do
		UIKit.Button({ Text = command, TextSize = 13, OnClick = function()
			run(command)
		end, Parent = grid })
	end
	output = UIKit.Label({
		Text = "",
		TextSize = 13,
		Font = UIKit.FontRegular,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 372),
		Size = UDim2.new(1, 0, 1, -372),
		Parent = panel,
	})
end

function DevPanel:Toggle(): boolean
	if not root then
		return false
	end
	root.Visible = not root.Visible
	return root.Visible
end

function DevPanel:IsOpen(): boolean
	return root ~= nil and root.Visible
end

function DevPanel:Start() end

return DevPanel
