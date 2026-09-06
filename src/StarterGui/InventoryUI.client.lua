--[[
	InventoryUI
	Combined Inventory / Loadout / Scooters / Shop screen (brief sections
	16-17, 26 "SHOP" button). Everything here only *requests* changes —
	InventoryService on the server re-validates ownership before anything
	actually changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local SkinData = require(ReplicatedStorage.Shared.SkinData)
local ScooterData = require(ReplicatedStorage.Shared.ScooterData)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))
local UIState = require(playerScripts:WaitForChild("UIState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ChangeLoadout = Remotes:WaitForChild("ChangeLoadout")
local EquipCosmetic = Remotes:WaitForChild("EquipCosmetic")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")

local inventory = { OwnedWeapons = {}, OwnedWeaponSkins = {}, OwnedScooterSkins = {}, Loadout = { WeaponSkins = {} } }

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Enabled = false
screenGui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.4
dim.Parent = screenGui

local panel = UIHelpers.Panel(screenGui, UDim2.fromOffset(820, 560), UDim2.new(0.5, -410, 0.5, -280), UIHelpers.NeonBlue)

local titleLabel = UIHelpers.Label(panel, "INVENTORY", UDim2.fromOffset(400, 40), UDim2.fromOffset(24, 16), 30)

local closeButton = UIHelpers.Button(panel, "X", UDim2.fromOffset(40, 40), UDim2.new(1, -56, 0, 16), Color3.fromRGB(255, 90, 90))
closeButton.MouseButton1Click:Connect(function()
	UIState.Close("Inventory")
end)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.fromOffset(180, 460)
tabBar.Position = UDim2.fromOffset(24, 70)
tabBar.BackgroundTransparency = 1
tabBar.Parent = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabBar

local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.fromOffset(580, 460)
contentFrame.Position = UDim2.fromOffset(220, 70)
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.CanvasSize = UDim2.fromOffset(0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.ScrollBarThickness = 6
contentFrame.Parent = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.Parent = contentFrame

local currentTab = "Loadout"

local function clearContent()
	for _, child in ipairs(contentFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function row(text, subtext, locked, selected, accentColor)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(560, 56)
	frame.BackgroundColor3 = selected and (accentColor or UIHelpers.NeonBlue) or Color3.fromRGB(18, 18, 24)
	frame.BackgroundTransparency = selected and 0.55 or 0.15
	frame.Parent = contentFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = selected and (accentColor or UIHelpers.NeonBlue) or Color3.fromRGB(50, 50, 60)
	stroke.Thickness = selected and 2 or 1
	stroke.Parent = frame

	local nameLabel = UIHelpers.Label(frame, text, UDim2.fromOffset(360, 26), UDim2.fromOffset(16, 6), 18)
	nameLabel.TextColor3 = locked and Color3.fromRGB(120, 120, 130) or UIHelpers.TextColor

	local subLabel = UIHelpers.Label(frame, subtext or "", UDim2.fromOffset(360, 20), UDim2.fromOffset(16, 30), 13, Color3.fromRGB(160, 160, 175))
	subLabel.Font = UIHelpers.BodyFont

	if locked then
		local lockLabel = UIHelpers.Label(frame, "LOCKED", UDim2.fromOffset(100, 30), UDim2.new(1, -116, 0, 13), 14, Color3.fromRGB(255, 120, 120))
		lockLabel.TextXAlignment = Enum.TextXAlignment.Right
	end

	return frame
end

local function makeClickable(frame, callback)
	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.Parent = frame
	button.MouseButton1Click:Connect(callback)
end

--============================================================
-- Tab: Loadout
--============================================================

local function renderLoadout()
	clearContent()
	UIHelpers.Label(contentFrame, "CURRENT LOADOUT", UDim2.fromOffset(500, 26), UDim2.fromOffset(0, 0), 18, UIHelpers.NeonPurple)

	for _, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
		local weaponId = inventory.Loadout[slot]
		local weapon = weaponId and WeaponData.Get(weaponId)
		row(slot:upper() .. ":  " .. (weapon and weapon.DisplayName or "None"), "Open the Weapons tab to change this slot", false, false)
	end

	local scooterId = inventory.Loadout.ScooterSkin
	local scooter = scooterId and ScooterData.Skins[scooterId]
	row("SCOOTER:  " .. (scooter and scooter.DisplayName or "Neon Ghost"), "Open the Scooters tab to change this", false, false)
end

--============================================================
-- Tab: Weapons
--============================================================

local function renderWeapons()
	clearContent()
	for _, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
		UIHelpers.Label(contentFrame, slot:upper(), UDim2.fromOffset(500, 24), UDim2.fromOffset(0, 0), 16, UIHelpers.NeonPurple)
		for id, weapon in pairs(WeaponData.Weapons) do
			if weapon.Slot == slot then
				local owned = inventory.OwnedWeapons[id] == true
				local selected = inventory.Loadout[slot] == id
				local subtext = weapon.Slot == "Melee" and ("Damage " .. weapon.Damage) or string.format("DMG %d  |  MAG %d  |  RANGE %d", weapon.Damage or weapon.DamagePerPellet, weapon.Magazine or 0, weapon.Range)
				local frame = row(weapon.DisplayName, subtext, not owned, selected, UIHelpers.NeonBlue)
				if owned then
					makeClickable(frame, function()
						ChangeLoadout:FireServer({ [slot] = id })
					end)
				end
			end
		end
	end
end

--============================================================
-- Tab: Skins (weapon cosmetics)
--============================================================

local function renderSkins()
	clearContent()
	for _, slot in ipairs({ "Primary", "Secondary", "Melee" }) do
		local weaponId = inventory.Loadout[slot]
		local weapon = weaponId and WeaponData.Get(weaponId)
		if weapon then
			UIHelpers.Label(contentFrame, weapon.DisplayName:upper() .. " SKINS", UDim2.fromOffset(500, 24), UDim2.fromOffset(0, 0), 16, UIHelpers.NeonPurple)
			for id, skin in pairs(SkinData.Collections) do
				local owned = id == SkinData.DefaultSkin or inventory.OwnedWeaponSkins[id] == true
				local selected = (inventory.Loadout.WeaponSkins[weaponId] or SkinData.DefaultSkin) == id
				local frame = row(skin.DisplayName, skin.Rarity, not owned, selected, SkinData.RarityColor[skin.Rarity])
				if owned then
					makeClickable(frame, function()
						EquipCosmetic:FireServer({ Kind = "WeaponSkin", WeaponId = weaponId, SkinId = id })
					end)
				end
			end
		end
	end
end

--============================================================
-- Tab: Scooters
--============================================================

local function renderScooters()
	clearContent()
	for id, skin in pairs(ScooterData.Skins) do
		local owned = inventory.OwnedScooterSkins[id] == true
		local selected = inventory.Loadout.ScooterSkin == id
		local frame = row(skin.DisplayName, skin.Rarity, not owned, selected, skin.AccentColor)
		if owned then
			makeClickable(frame, function()
				EquipCosmetic:FireServer({ Kind = "ScooterSkin", SkinId = id })
			end)
		end
	end
end

local RENDERERS = {
	Loadout = renderLoadout,
	Weapons = renderWeapons,
	Skins = renderSkins,
	Scooters = renderScooters,
}

local tabButtons = {}
local function selectTab(name)
	currentTab = name
	for tabName, button in pairs(tabButtons) do
		button.BackgroundColor3 = tabName == name and UIHelpers.NeonBlue or Color3.fromRGB(20, 20, 26)
	end
	RENDERERS[name]()
end

for _, name in ipairs({ "Loadout", "Weapons", "Skins", "Scooters" }) do
	local button = UIHelpers.Button(tabBar, name:upper(), UDim2.fromOffset(180, 44), UDim2.fromOffset(0, 0), UIHelpers.NeonBlue)
	button.MouseButton1Click:Connect(function()
		selectTab(name)
	end)
	tabButtons[name] = button
end

InventoryUpdated.OnClientEvent:Connect(function(snapshot)
	inventory = snapshot
	inventory.Loadout.WeaponSkins = inventory.Loadout.WeaponSkins or {}
	if screenGui.Enabled then
		RENDERERS[currentTab]()
	end
end)

local function openInventory(tab)
	screenGui.Enabled = true
	ClientState.Camera.InputEnabled = false
	selectTab(tab or "Loadout")
end

local function closeInventory()
	screenGui.Enabled = false
	ClientState.Camera.InputEnabled = true
end

UIState.Register("Inventory", openInventory, closeInventory)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled then
		UIState.Close("Inventory")
	end
end)
