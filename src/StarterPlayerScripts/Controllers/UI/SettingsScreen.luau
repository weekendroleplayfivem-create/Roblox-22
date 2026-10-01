--[[
	SettingsScreen
	Generated from SettingsConfig.Schema so new settings appear automatically.
	Changes apply instantly on this client and are saved (sanitized) by the
	server in batches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsConfig = require(Shared.Config.SettingsConfig)

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)

local SettingsScreen = {}

local Theme = UIKit.Theme

local root: Frame
local refreshers: { () -> () } = {}

local function formatValue(entry, value): string
	if entry.Type == "number" then
		if entry.Max <= 3 then
			return string.format("%.2f", value)
		end
		return tostring(math.floor(value + 0.5))
	elseif entry.Type == "boolean" then
		return if value then "ON" else "OFF"
	end
	return tostring(value)
end

-- Every control is a "◀ value ▶" stepper: works with mouse, touch and gamepad.
local function buildRow(parent: Instance, entry, order: number)
	local row = UIKit.Create("Frame", { Size = UDim2.new(1, -12, 0, 46), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.15, LayoutOrder = order, Parent = parent })
	UIKit.Corner(row, 8)
	UIKit.Padding(row, 8)
	UIKit.Label({ Text = entry.Label, TextSize = 17, Size = UDim2.new(0.5, 0, 1, 0), Parent = row })
	local valueLabel = UIKit.Label({ Text = "", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(1, -190, 0, 0), Size = UDim2.new(0, 130, 1, 0), Parent = row })

	local function change(direction: number)
		local current = ClientState.GetSetting(entry.Key)
		local nextValue = current
		if entry.Type == "number" then
			nextValue = current + entry.Step * direction
		elseif entry.Type == "boolean" then
			nextValue = not current
		elseif entry.Type == "enum" then
			local index = table.find(entry.Options, current) or 1
			nextValue = entry.Options[((index - 1 + direction) % #entry.Options) + 1]
		end
		ClientState.SetSetting(entry.Key, nextValue)
	end

	UIKit.Button({ Text = "◀", TextSize = 16, Position = UDim2.new(1, -230, 0, 0), Size = UDim2.new(0, 40, 1, 0), OnClick = function()
		change(-1)
	end, Parent = row })
	UIKit.Button({ Text = "▶", TextSize = 16, Position = UDim2.new(1, -40, 0, 0), Size = UDim2.new(0, 40, 1, 0), OnClick = function()
		change(1)
	end, Parent = row })

	table.insert(refreshers, function()
		valueLabel.Text = formatValue(entry, ClientState.GetSetting(entry.Key))
		if entry.Key == "CrosshairColor" then
			valueLabel.TextColor3 = SettingsConfig.CrosshairColors[ClientState.GetSetting(entry.Key)] or Theme.Text
		end
	end)
end

function SettingsScreen:Build(controller)
	local screen = UIKit.GetScreen("Settings", 35)
	local content
	root, content = UIKit.MenuFrame(screen, "SETTINGS", function()
		controller:CloseMenu()
	end)
	local list = UIKit.Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	UIKit.List(list, Enum.FillDirection.Vertical, 6)
	for index, entry in SettingsConfig.Schema do
		buildRow(list, entry, index)
	end
	UIKit.Label({
		Text = "Halo and Chevron crosshairs can be unlocked in the Shop. Sensitivity applies to mouse and controller.",
		TextSize = 14,
		Font = UIKit.FontRegular,
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		Size = UDim2.new(1, -12, 0, 40),
		LayoutOrder = 999,
		Parent = list,
	})
end

function SettingsScreen:SetVisible(visible: boolean)
	if visible then
		for _, refresh in refreshers do
			refresh()
		end
	end
	UIKit.SetOpen(root, visible)
end

function SettingsScreen:Start()
	ClientState.Changed:Connect(function(key)
		if key == "Settings" then
			for _, refresh in refreshers do
				refresh()
			end
		end
	end)
end

return SettingsScreen
