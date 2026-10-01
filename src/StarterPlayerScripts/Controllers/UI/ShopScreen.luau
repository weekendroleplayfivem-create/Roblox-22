--[[
	ShopScreen
	Two modes on the StarterGui/Shop ScreenGui:
	  * SHOP      - buy cosmetics with earned Credits. Fixed, visible prices.
	                No random rewards / loot boxes. Cosmetics never change stats.
	  * CUSTOMIZE - equip cosmetics you own (free items are always owned).
	All purchases/equips are validated by the server (ShopService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.SoundController)

local ShopScreen = {}

local Theme = UIKit.Theme

local root: Frame
local content: Frame
local titleLabel: TextLabel
local creditsLabel: TextLabel
local statusLabel: TextLabel
local grid: ScrollingFrame
local tabButtons = {}
local mode = "Shop"
local category = CosmeticConfig.Categories[1]

local function owns(profile, itemId: string): boolean
	return CosmeticConfig.IsFree(itemId) or (profile and profile.OwnedCosmetics[itemId] == true)
end

local function sortedItems(categoryName: string)
	local list = {}
	for _, item in CosmeticConfig.Items do
		if item.Category == categoryName then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		if a.Price ~= b.Price then
			return a.Price < b.Price
		end
		return a.Name < b.Name
	end)
	return list
end

local function setStatus(text: string, good: boolean)
	statusLabel.Text = text
	statusLabel.TextColor3 = if good then Theme.Success else Theme.Danger
end

local function render()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local profile = ClientState.Get("Profile")
	titleLabel.Text = if mode == "Shop" then "SHOP" else "CUSTOMIZE"
	creditsLabel.Text = string.format("%d CREDITS", profile and profile.Credits or 0)
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == category then Color3.fromRGB(20, 110, 140) else Theme.PanelLight
	end

	for index, item in sortedItems(category) do
		local owned = owns(profile, item.Id)
		if mode == "Customize" and not owned then
			continue
		end
		local equipped = profile and profile.Equipped[item.Category] == item.Id
		local card = UIKit.Panel({ LayoutOrder = index, Parent = grid })
		UIKit.Padding(card, 10)
		local swatch = UIKit.Create("Frame", {
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundColor3 = item.Color or Theme.PanelLight,
			Parent = card,
		})
		UIKit.Corner(swatch, 8)
		if item.Rainbow then
			UIKit.Create("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 140)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
				}),
				Parent = swatch,
			})
		end
		local preview = item.Style or item.Motion or (if item.Material then item.Material else "")
		UIKit.Label({ Text = preview, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.5, Parent = swatch })
		UIKit.Label({ Text = item.Name, TextSize = 17, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 22), Parent = card })
		local priceText = if item.Price == 0 then "FREE" else string.format("%d Credits", item.Price)
		if item.RequiredLevel > 1 then
			priceText ..= string.format("  •  Lv %d", item.RequiredLevel)
		end
		UIKit.Label({ Text = priceText, TextSize = 13, TextColor3 = Theme.Yellow, Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 18), Parent = card })

		local actionText, actionColor, action
		if equipped then
			actionText, actionColor = "EQUIPPED", Color3.fromRGB(30, 90, 60)
		elseif owned then
			actionText, actionColor = "EQUIP", Theme.PanelLight
			action = function()
				local ok, success, message = pcall(function()
					return Net.Function("UI", "EquipCosmetic"):InvokeServer(item.Id)
				end)
				setStatus(if ok then message else "Could not reach the server", ok and success)
			end
		else
			actionText, actionColor = "BUY", Color3.fromRGB(20, 120, 150)
			action = function()
				local ok, success, message = pcall(function()
					return Net.Function("UI", "PurchaseItem"):InvokeServer(item.Id)
				end)
				setStatus(if ok then message else "Could not reach the server", ok and success)
				if ok and success then
					SoundController:Play("LevelUp")
				end
			end
		end
		UIKit.Button({
			Text = actionText,
			TextSize = 15,
			Color = actionColor,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 34),
			OnClick = action,
			Parent = card,
		})
	end
end

function ShopScreen:Build(controller)
	local screen = UIKit.GetScreen("Shop", 25)
	root, content = UIKit.MenuFrame(screen, "SHOP", function()
		controller:CloseMenu()
	end)
	titleLabel = root:FindFirstChild("Holder"):FindFirstChildOfClass("TextLabel") :: TextLabel
	creditsLabel = UIKit.Label({ Text = "", TextSize = 20, TextColor3 = Theme.Yellow, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, -140, 0, -50), Size = UDim2.new(0.5, 0, 0, 30), Parent = content })

	local tabs = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	UIKit.List(tabs, Enum.FillDirection.Horizontal, 8)
	for index, categoryName in CosmeticConfig.Categories do
		tabButtons[categoryName] = UIKit.Button({
			Text = CosmeticConfig.CategoryNames[categoryName],
			TextSize = 15,
			Size = UDim2.fromOffset(170, 38),
			LayoutOrder = index,
			OnClick = function()
				category = categoryName
				render()
			end,
			Parent = tabs,
		})
	end

	grid = UIKit.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(200, 170), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	statusLabel = UIKit.Label({ Text = "", TextSize = 16, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 36), Parent = content })
end

function ShopScreen:SetVisible(visible: boolean, newMode: string?)
	if newMode then
		mode = newMode
	end
	if visible then
		statusLabel.Text = ""
		render()
	end
	UIKit.SetOpen(root, visible)
end

function ShopScreen:Start()
	ClientState.Changed:Connect(function(key)
		if key == "Profile" and root.Visible then
			render()
		end
	end)
end

return ShopScreen
