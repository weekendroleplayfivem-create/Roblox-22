--[[
	Notifications
	Toasts (info / warnings) and the level-up celebration. Lives in its own
	ScreenGui above everything else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)

local UIKit = require(script.Parent.UIKit)
local SoundController = require(script.Parent.Parent.SoundController)

local Notifications = {}

local Theme = UIKit.Theme

local toastHolder: Frame
local levelUp: Frame
local levelUpTitle: TextLabel
local levelUpSub: TextLabel
local MAX_TOASTS = 4

function Notifications:Toast(text: string, kind: string?, duration: number?)
	local color = if kind == "Warning" then Theme.Danger elseif kind == "Success" then Theme.Success else Theme.Accent
	local toast = UIKit.Panel({ Size = UDim2.fromOffset(460, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = math.floor(os.clock() * 100), Parent = toastHolder })
	UIKit.Padding(toast, 10)
	local stroke = toast:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Transparency = 0.2
	end
	UIKit.Label({ Text = text, TextSize = 16, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 20), Parent = toast })
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	task.delay(duration or 4, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

function Notifications:LevelUp(data)
	levelUpTitle.Text = "LEVEL " .. tostring(data.Level)
	local lines = { string.format("+%d Credits", data.Credits or 0) }
	if data.Unlocks and #data.Unlocks > 0 then
		table.insert(lines, "Unlocked: " .. table.concat(data.Unlocks, ", "))
	end
	levelUpSub.Text = table.concat(lines, "   •   ")
	levelUp.Visible = true
	local scale = levelUp:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.6
	UIKit.Tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	SoundController:Play("LevelUp")
	task.delay(data.Duration or 3.5, function()
		levelUp.Visible = false
	end)
end

function Notifications:Build()
	local screen = UIKit.GetScreen("Notifications", 50)
	toastHolder = UIKit.Create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(460, 400), BackgroundTransparency = 1, Parent = screen })
	UIKit.List(toastHolder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	UIKit.AutoScale(toastHolder, 0.6, 1.2)

	levelUp = UIKit.Create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(700, 120), BackgroundTransparency = 1, Visible = false, Parent = screen })
	UIKit.Create("UIScale", { Parent = levelUp })
	UIKit.Label({ Text = "LEVEL UP!", Font = UIKit.FontBlack, TextSize = 30, TextColor3 = Theme.Yellow, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 34), Parent = levelUp })
	levelUpTitle = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 60), Parent = levelUp })
	UIKit.Gradient(levelUpTitle, Theme.Accent, Theme.Accent2)
	levelUpSub = UIKit.Label({ Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 26), Parent = levelUp })
end

function Notifications:Start()
	Net.Event("UI", "Notify").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.Kind == "LevelUp" then
			Notifications:LevelUp(data)
		elseif type(data.Text) == "string" then
			Notifications:Toast(data.Text, data.Kind, data.Duration)
		end
	end)
end

return Notifications
