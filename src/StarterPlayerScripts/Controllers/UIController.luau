--[[
	UIController
	Coordinates every screen:
	  * Lobby: main menu (can be hidden to explore; M re-opens).
	  * Match: HUD; M / Start opens the pause menu.
	  * Sub-menus (Loadout, Customize, Shop, Settings) open on top and return
	    to the menu they came from.
	  * While any menu is open: gameplay input is blocked and the mouse is
	    released (a Modal button frees the cursor in first person).
	  * Tab/Select hold shows the scoreboard; Results show after each match.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)

local ClientState = require(script.Parent.ClientState)
local InputController = require(script.Parent.InputController)

local UIFolder = script.Parent:WaitForChild("UI")
local UIKit = require(UIFolder.UIKit)
local MainMenuScreen = require(UIFolder.MainMenuScreen)
local HUDScreen = require(UIFolder.HUDScreen)
local ScoreboardScreen = require(UIFolder.ScoreboardScreen)
local LoadoutScreen = require(UIFolder.LoadoutScreen)
local ShopScreen = require(UIFolder.ShopScreen)
local SettingsScreen = require(UIFolder.SettingsScreen)
local ResultsScreen = require(UIFolder.ResultsScreen)
local TouchControls = require(UIFolder.TouchControls)
local Notifications = require(UIFolder.Notifications)
local DevPanel = require(UIFolder.DevPanel)

local UIController = {}

local player = Players.LocalPlayer

local openMenu: string? = nil
local lobbyMenuVisible = true
local pauseVisible = false
local modalButton: TextButton

local function inMatch(): boolean
	return ClientState.IsInMatch()
end

local function setCore(name: string, value: any)
	-- SetCore can fail before the CoreScripts register; retry briefly.
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCore, StarterGui, name, value) then
				return
			end
			task.wait(0.5)
		end
	end)
end

local function updateModal()
	local anyMenu = openMenu ~= nil
		or pauseVisible
		or (not inMatch() and lobbyMenuVisible)
		or ResultsScreen:IsVisible()
		or DevPanel:IsOpen()
	InputController:SetBlocked(anyMenu)
	-- A visible Modal button releases the mouse even in first-person lock.
	modalButton.Visible = anyMenu
end

local function applyMenus()
	LoadoutScreen:SetVisible(openMenu == "Loadout")
	ShopScreen:SetVisible(openMenu == "Shop" or openMenu == "Customize", if openMenu == "Customize" then "Customize" elseif openMenu == "Shop" then "Shop" else nil)
	SettingsScreen:SetVisible(openMenu == "Settings")
	local showLobby = not inMatch() and lobbyMenuVisible and openMenu == nil and not ResultsScreen:IsVisible()
	MainMenuScreen:ShowLobby(showLobby)
	MainMenuScreen:ShowPause(inMatch() and pauseVisible and openMenu == nil)
	updateModal()
end

function UIController:OpenMenu(name: string)
	openMenu = name
	applyMenus()
end

function UIController:CloseMenu()
	openMenu = nil
	applyMenus()
end

function UIController:CloseAll()
	openMenu = nil
	pauseVisible = false
	applyMenus()
end

function UIController:SetMainMenuVisible(visible: boolean)
	lobbyMenuVisible = visible
	applyMenus()
end

local function toggleMenu()
	if openMenu then
		UIController:CloseMenu()
	elseif inMatch() then
		pauseVisible = not pauseVisible
		applyMenus()
	else
		lobbyMenuVisible = not lobbyMenuVisible
		applyMenus()
	end
end

function UIController:Init() end

function UIController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local modalGui = UIKit.GetScreen("ModalHelper", 1)
	modalButton = UIKit.Create("TextButton", {
		Name = "MouseRelease",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		Visible = false,
		Parent = modalGui,
	})

	setCore("ResetButtonCallback", true)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	for _, screen in { Notifications, HUDScreen, ScoreboardScreen, ResultsScreen, DevPanel } do
		screen:Build()
	end
	for _, screen in { MainMenuScreen, LoadoutScreen, ShopScreen, SettingsScreen } do
		screen:Build(UIController)
	end
	TouchControls:Build(HUDScreen:GetScreen())
	for _, screen in { Notifications, HUDScreen, ScoreboardScreen, ResultsScreen, DevPanel, MainMenuScreen, LoadoutScreen, ShopScreen, SettingsScreen, TouchControls } do
		screen:Start()
	end

	InputController.ActionBegan:Connect(function(action)
		if action == "Menu" then
			toggleMenu()
		elseif action == "Scoreboard" then
			ScoreboardScreen:SetVisible(true)
		elseif action == "DevConsole" then
			DevPanel:Toggle()
			updateModal()
		end
	end)
	InputController.ActionEnded:Connect(function(action)
		if action == "Scoreboard" then
			ScoreboardScreen:SetVisible(false)
		end
	end)

	ClientState.Observe("Location", function(location)
		openMenu = nil
		pauseVisible = false
		if location == "Lobby" then
			lobbyMenuVisible = true
			ResultsScreen:Hide()
			setCore("ResetButtonCallback", true)
		elseif location == "Match" then
			-- Resetting mid-match would just be a free respawn; disable it.
			setCore("ResetButtonCallback", false)
		end
		ScoreboardScreen:SetVisible(false)
		applyMenus()
	end)

	Net.Event("Match", "Results").OnClientEvent:Connect(function(data)
		openMenu = nil
		pauseVisible = false
		ScoreboardScreen:SetVisible(false)
		ResultsScreen:Show(data)
		applyMenus()
	end)

	-- Re-apply after respawns (PlayerGui contents persist, but be safe).
	playerGui.ChildAdded:Connect(function()
		task.defer(updateModal)
	end)
end

return UIController
