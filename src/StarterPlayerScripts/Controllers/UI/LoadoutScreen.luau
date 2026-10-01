--[[
	LoadoutScreen
	Choose primary weapon, secondary weapon, movement ability and tactical
	ability. Locked items show their unlock level. The server validates the
	choice against your level (SetLoadout) before saving it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)

local UIKit = require(script.Parent.UIKit)
local ClientState = require(script.Parent.Parent.ClientState)

local LoadoutScreen = {}

local Theme = UIKit.Theme

local root: Frame
local content: Frame
local selection = {}
local tiles = {}
local detail = {}
local statusLabel: TextLabel

local function level(): number
	local profile = ClientState.Get("Profile")
	return profile and profile.Level or 1
end

local function statBar(parent: Instance, label: string, value: number, order: number)
	local holder = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	UIKit.Label({ Text = label, TextSize = 13, TextColor3 = Theme.SubText, Size = UDim2.new(0.35, 0, 1, 0), Parent = holder })
	local bar = UIKit.Bar({ Position = UDim2.new(0.37, 0, 0.5, -4), Size = UDim2.new(0.63, 0, 0, 8), Parent = holder })
	bar.Set(value)
end

local function showDetail(kind: string, id: string)
	for _, child in detail.Stats:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if kind == "Weapon" then
		local weapon = WeaponConfig.Get(id)
		detail.Name.Text = string.upper(weapon.DisplayName)
		detail.Category.Text = string.upper(weapon.Category) .. "  •  " .. weapon.FireMode
		detail.Description.Text = weapon.Description
		local dps = weapon.Damage * weapon.Pellets * WeaponConfig.GetMaxShotsPerSecond(weapon) * WeaponConfig.GetChargeMultiplier(weapon, 1)
		statBar(detail.Stats, "Damage", math.clamp(weapon.Damage * weapon.Pellets / 100, 0.05, 1), 1)
		statBar(detail.Stats, "Fire rate", math.clamp(WeaponConfig.GetMaxShotsPerSecond(weapon) / 15, 0.05, 1), 2)
		statBar(detail.Stats, "Power", math.clamp(dps / 200, 0.05, 1), 3)
		statBar(detail.Stats, "Range", math.clamp(weapon.Range / 600, 0.05, 1), 4)
		statBar(detail.Stats, "Accuracy", math.clamp(1 - weapon.Spread.Hip / 6, 0.05, 1), 5)
		statBar(detail.Stats, "Mobility", math.clamp((weapon.MovementPenalty - 0.85) / 0.15, 0.05, 1), 6)
		statBar(detail.Stats, "Handling", math.clamp(1 - weapon.EquipTime / 0.5, 0.05, 1), 7)
	else
		local ability = AbilityConfig.Get(id)
		detail.Name.Text = string.upper(ability.DisplayName)
		detail.Category.Text = string.upper(ability.Slot) .. " ABILITY  •  " .. ability.Cooldown .. "s cooldown"
		detail.Description.Text = ability.Description
	end
end

local function refreshTiles()
	local currentLevel = level()
	for _, tile in tiles do
		local unlocked = currentLevel >= tile.UnlockLevel
		local selected = selection[tile.Slot] == tile.Id
		tile.Button.BackgroundColor3 = if selected then Color3.fromRGB(20, 110, 140) elseif unlocked then Theme.PanelLight else Theme.Panel
		tile.Button.TextColor3 = if unlocked then Theme.Text else Theme.Locked
		tile.Button.Text = if unlocked then tile.Name else string.format("%s\nLv %d", tile.Name, tile.UnlockLevel)
	end
end

local function addSection(title: string, slot: string, ids: { string }, getConfig, order: number, kind: string)
	local section = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = content:FindFirstChild("Left") })
	UIKit.Label({ Text = title, TextSize = 16, TextColor3 = Theme.Accent, Size = UDim2.new(1, 0, 0, 22), Parent = section })
	local grid = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = section })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 50), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for index, id in ids do
		local config = getConfig(id)
		local tile = {
			Id = id,
			Slot = slot,
			Name = config.DisplayName,
			UnlockLevel = config.UnlockLevel,
		}
		tile.Button = UIKit.Button({
			Text = config.DisplayName,
			TextSize = 15,
			TextWrapped = true,
			LayoutOrder = index,
			OnClick = function()
				showDetail(kind, id)
				if level() >= config.UnlockLevel then
					selection[slot] = id
					refreshTiles()
				end
			end,
			Parent = grid,
		})
		table.insert(tiles, tile)
	end
end

local function save()
	statusLabel.Text = "Saving..."
	local ok, success, message = pcall(function()
		return Net.Function("Inventory", "SetLoadout"):InvokeServer({
			Primary = selection.Primary,
			Secondary = selection.Secondary,
			Movement = selection.Movement,
			Tactical = selection.Tactical,
		})
	end)
	if ok then
		statusLabel.Text = message or (if success then "Saved" else "Could not save")
		statusLabel.TextColor3 = if success then Theme.Success else Theme.Danger
	else
		statusLabel.Text = "Could not reach the server"
		statusLabel.TextColor3 = Theme.Danger
	end
end

function LoadoutScreen:Build(controller)
	local screen = UIKit.GetScreen("Loadout", 25)
	root, content = UIKit.MenuFrame(screen, "LOADOUT", function()
		controller:CloseMenu()
	end)
	local left = UIKit.Create("ScrollingFrame", {
		Name = "Left",
		Size = UDim2.new(0.62, 0, 1, -60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	UIKit.List(left, Enum.FillDirection.Vertical, 14)

	local primaries, secondaries, movement, tactical = {}, {}, {}, {}
	for _, id in WeaponConfig.Order do
		table.insert(if WeaponConfig.Get(id).Slot == "Primary" then primaries else secondaries, id)
	end
	for _, id in AbilityConfig.Order do
		table.insert(if AbilityConfig.Get(id).Slot == "Movement" then movement else tactical, id)
	end
	addSection("PRIMARY", "Primary", primaries, WeaponConfig.Get, 1, "Weapon")
	addSection("SECONDARY", "Secondary", secondaries, WeaponConfig.Get, 2, "Weapon")
	addSection("MOVEMENT ABILITY", "Movement", movement, AbilityConfig.Get, 3, "Ability")
	addSection("TACTICAL ABILITY", "Tactical", tactical, AbilityConfig.Get, 4, "Ability")

	local panel = UIKit.Panel({ Position = UDim2.fromScale(0.64, 0), Size = UDim2.new(0.36, 0, 1, -60), Parent = content })
	UIKit.Padding(panel, 14)
	detail.Name = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 26, Size = UDim2.new(1, 0, 0, 30), Parent = panel })
	detail.Category = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = Theme.Accent, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 18), Parent = panel })
	detail.Description = UIKit.Label({ Text = "", TextSize = 15, Font = UIKit.FontRegular, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Theme.SubText, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 60), Parent = panel })
	detail.Stats = UIKit.Create("Frame", { Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 1, -124), BackgroundTransparency = 1, Parent = panel })
	UIKit.List(detail.Stats, Enum.FillDirection.Vertical, 6)

	UIKit.Button({
		Text = "SAVE LOADOUT",
		Font = UIKit.FontBlack,
		Color = Color3.fromRGB(20, 120, 150),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(260, 50),
		OnClick = save,
		Parent = content,
	})
	statusLabel = UIKit.Label({ Text = "", TextSize = 16, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(0.6, 0, 0, 40), Parent = content })
end

function LoadoutScreen:SetVisible(visible: boolean)
	if visible then
		local profile = ClientState.Get("Profile")
		if profile then
			selection = {
				Primary = profile.Equipped.Primary,
				Secondary = profile.Equipped.Secondary,
				Movement = profile.Equipped.Movement,
				Tactical = profile.Equipped.Tactical,
			}
			showDetail("Weapon", selection.Primary)
		end
		statusLabel.Text = ""
		refreshTiles()
	end
	UIKit.SetOpen(root, visible)
end

function LoadoutScreen:Start()
	ClientState.Changed:Connect(function(key)
		if key == "Profile" and root.Visible then
			refreshTiles()
		end
	end)
end

return LoadoutScreen
