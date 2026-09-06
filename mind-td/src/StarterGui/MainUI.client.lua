--[[
	MainUI
	The in-game HUD (brief section 24): wave counter, Core readout, funds,
	tower shop, the selected-tower panel, and the Enemy Intelligence panel.

	Reads only from ClientState and its signals — this script never touches the
	GameEvent remote directly (UIController owns that), and never decides
	anything about legality. It sends intent and displays what comes back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TowerData = require(ReplicatedStorage.Shared.TowerData)
local Utility = require(ReplicatedStorage.Shared.Utility)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpgradeTower = Remotes:WaitForChild("UpgradeTower")
local SellTower = Remotes:WaitForChild("SellTower")
local ChangeTargetMode = Remotes:WaitForChild("ChangeTargetMode")
local StartWave = Remotes:WaitForChild("StartWave")

local Signals = ClientState.Signals

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

--============================================================
-- Top: wave counter
--============================================================

local topPanel = UIHelpers.MakePanel(screenGui, UDim2.fromOffset(300, 76), UDim2.new(0.5, -150, 0, 12))

local waveLabel = UIHelpers.MakeLabel(topPanel, "WAVE 0 / 20", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(14, 8), 22, UIHelpers.Cyan, UIHelpers.TitleFont)
waveLabel.TextXAlignment = Enum.TextXAlignment.Center

local waveSubLabel = UIHelpers.MakeLabel(topPanel, "STANDBY", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(14, 40), 13, UIHelpers.Dim, UIHelpers.MonoFont)
waveSubLabel.TextXAlignment = Enum.TextXAlignment.Center

--============================================================
-- Left: Core + funds
--============================================================

local corePanel = UIHelpers.MakePanel(screenGui, UDim2.fromOffset(230, 96), UDim2.fromOffset(16, 12))

UIHelpers.MakeLabel(corePanel, "CORE", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(14, 8), 14, UIHelpers.Cyan, UIHelpers.TitleFont)

local coreValueLabel = UIHelpers.MakeLabel(corePanel, "1000 / 1000", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(14, 28), 20, UIHelpers.Text, UIHelpers.TitleFont)

local _coreTrack, coreFill = UIHelpers.MakeBar(corePanel, UDim2.new(1, -28, 0, 8), UDim2.fromOffset(14, 58), UIHelpers.Cyan)

local moneyLabel = UIHelpers.MakeLabel(corePanel, "$1,000", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(14, 70), 15, UIHelpers.Green, UIHelpers.MonoFont)

--============================================================
-- Right: Enemy Intelligence
--============================================================

local aiPanel = UIHelpers.MakePanel(screenGui, UDim2.fromOffset(268, 236), UDim2.new(1, -284, 0, 12), UIHelpers.Violet)

UIHelpers.MakeLabel(aiPanel, "ENEMY INTELLIGENCE", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(14, 10), 13, UIHelpers.Violet, UIHelpers.TitleFont)

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -28, 0, 1)
divider.Position = UDim2.fromOffset(14, 34)
divider.BackgroundColor3 = UIHelpers.Violet
divider.BackgroundTransparency = 0.6
divider.BorderSizePixel = 0
divider.Parent = aiPanel

UIHelpers.MakeLabel(aiPanel, "ADAPTATION", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 44), 11, UIHelpers.Dim, UIHelpers.MonoFont)
local adaptationLabel = UIHelpers.MakeLabel(aiPanel, "0%", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 60), 20, UIHelpers.Violet, UIHelpers.TitleFont)
local _adaptTrack, adaptFill = UIHelpers.MakeBar(aiPanel, UDim2.new(1, -28, 0, 6), UDim2.fromOffset(14, 84), UIHelpers.Violet)

UIHelpers.MakeLabel(aiPanel, "DETECTED STRATEGY", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 100), 11, UIHelpers.Dim, UIHelpers.MonoFont)
local strategyLabel = UIHelpers.MakeLabel(aiPanel, "▓▓▓▓▓▓", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 116), 15, UIHelpers.Text, UIHelpers.TitleFont)

UIHelpers.MakeLabel(aiPanel, "WEAK SIDE", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 140), 11, UIHelpers.Dim, UIHelpers.MonoFont)
local weakSideLabel = UIHelpers.MakeLabel(aiPanel, "▓▓▓▓▓▓", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 156), 15, UIHelpers.Amber, UIHelpers.TitleFont)

UIHelpers.MakeLabel(aiPanel, "COUNTER", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 180), 11, UIHelpers.Dim, UIHelpers.MonoFont)
local counterLabel = UIHelpers.MakeLabel(aiPanel, "▓▓▓▓▓▓", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 196), 15, UIHelpers.Red, UIHelpers.TitleFont)

-- Tells the player WHY parts of the panel are unreadable, and what fixes it.
local analysisHint = UIHelpers.MakeLabel(aiPanel, "", UDim2.new(1, -28, 0, 16), UDim2.fromOffset(14, 216), 10, UIHelpers.Dim, UIHelpers.MonoFont)

--============================================================
-- Bottom: tower shop
--============================================================

local shopPanel = UIHelpers.MakePanel(screenGui, UDim2.fromOffset(430, 104), UDim2.new(0.5, -215, 1, -116))

local shopLayout = Instance.new("UIListLayout")
shopLayout.FillDirection = Enum.FillDirection.Horizontal
shopLayout.Padding = UDim.new(0, 10)
shopLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
shopLayout.VerticalAlignment = Enum.VerticalAlignment.Center
shopLayout.Parent = shopPanel

local shopButtons: { [string]: TextButton } = {}

for _, towerId in ipairs(TowerData.ShopOrder) do
	local data = TowerData.Get(towerId) :: any

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(128, 82)
	button.BackgroundColor3 = UIHelpers.PanelLight
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = shopPanel
	UIHelpers.Corner(button, 6)
	local stroke = UIHelpers.Stroke(button, data.AccentColor, 1.4)

	-- Colour swatch so the shop entry matches the tower on the board.
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(1, -16, 0, 4)
	swatch.Position = UDim2.fromOffset(8, 8)
	swatch.BackgroundColor3 = data.AccentColor
	swatch.BorderSizePixel = 0
	swatch.Parent = button
	UIHelpers.Corner(swatch, 2)

	UIHelpers.MakeLabel(button, data.DisplayName:upper(), UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 16), 14, UIHelpers.Text, UIHelpers.TitleFont)
	UIHelpers.MakeLabel(button, data.Role, UDim2.new(1, -16, 0, 14), UDim2.fromOffset(8, 36), 10, UIHelpers.Dim, UIHelpers.MonoFont)

	local costLabel = UIHelpers.MakeLabel(button, Utility.FormatMoney(data.Levels[1].Cost), UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 54), 15, UIHelpers.Green, UIHelpers.MonoFont)

	button.MouseButton1Click:Connect(function()
		if ClientState.Selection.ShopTowerId == towerId then
			ClientState.ClearSelection()
		else
			ClientState.SelectShopTower(towerId)
		end
	end)

	shopButtons[towerId] = button
	button:SetAttribute("Cost", data.Levels[1].Cost)
	-- Named so the refresh pass below can find them again without keeping a
	-- parallel table of references.
	costLabel.Name = "CostLabel"
	stroke.Name = "Accent"
end

--============================================================
-- Selected tower panel
--============================================================

local selectionPanel = UIHelpers.MakePanel(screenGui, UDim2.fromOffset(250, 178), UDim2.new(1, -284, 1, -194), UIHelpers.Blue)
selectionPanel.Visible = false

local selectionTitle = UIHelpers.MakeLabel(selectionPanel, "TOWER", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(14, 8), 16, UIHelpers.Blue, UIHelpers.TitleFont)
local selectionStats = UIHelpers.MakeLabel(selectionPanel, "", UDim2.new(1, -20, 0, 46), UDim2.fromOffset(14, 30), 11, UIHelpers.Dim, UIHelpers.MonoFont)
selectionStats.TextYAlignment = Enum.TextYAlignment.Top

local upgradeButton = UIHelpers.MakeButton(selectionPanel, "UPGRADE", UDim2.new(1, -28, 0, 30), UDim2.fromOffset(14, 78), UIHelpers.Green)
local targetButton = UIHelpers.MakeButton(selectionPanel, "TARGET: FIRST", UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 112), UIHelpers.Amber)
local sellButton = UIHelpers.MakeButton(selectionPanel, "SELL", UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 142), UIHelpers.Red)

--============================================================
-- Start wave button + toasts
--============================================================

local startWaveButton = UIHelpers.MakeButton(screenGui, "START WAVE", UDim2.fromOffset(180, 44), UDim2.new(0.5, -90, 1, -168), UIHelpers.Green)
startWaveButton.Visible = false
startWaveButton.MouseButton1Click:Connect(function()
	StartWave:FireServer()
end)

local toastLabel = UIHelpers.MakeLabel(screenGui, "", UDim2.fromOffset(420, 26), UDim2.new(0.5, -210, 1, -196), 15, UIHelpers.Text, UIHelpers.TitleFont)
toastLabel.TextXAlignment = Enum.TextXAlignment.Center
toastLabel.TextTransparency = 1

local toastToken = 0
local function toast(message: string, color: Color3)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = message
	toastLabel.TextColor3 = color
	toastLabel.TextTransparency = 0
	task.delay(1.6, function()
		if myToken == toastToken then
			UIHelpers.Tween(toastLabel, 0.5, { TextTransparency = 1 })
		end
	end)
end

--============================================================
-- Refresh
--============================================================

local function refreshShop()
	local selected = ClientState.Selection.ShopTowerId
	for towerId, button in pairs(shopButtons) do
		local accent = button:FindFirstChild("Accent") :: UIStroke?
		local cost = button:GetAttribute("Cost") :: number
		local affordable = ClientState.Money >= cost

		if accent then
			accent.Transparency = if towerId == selected then 0 else 0.4
			accent.Thickness = if towerId == selected then 2.5 else 1.4
		end
		button.BackgroundTransparency = if towerId == selected then 0.45 else 0.1

		local costLabel = button:FindFirstChild("CostLabel") :: TextLabel?
		if costLabel then
			costLabel.TextColor3 = if affordable then UIHelpers.Green else UIHelpers.Red
		end
	end
end

local function refreshSelection()
	local runtimeId = ClientState.Selection.TowerRuntimeId
	if not runtimeId then
		selectionPanel.Visible = false
		return
	end

	local tower = ClientState.GetTowerByRuntimeId(runtimeId)
	if not tower then
		selectionPanel.Visible = false
		return
	end

	local data = TowerData.Get(tower.TowerId)
	if not data then
		selectionPanel.Visible = false
		return
	end

	selectionPanel.Visible = true
	selectionTitle.Text = string.format("%s  LV.%d", data.DisplayName:upper(), tower.Level)

	local levelData = data.Levels[tower.Level]
	local statLines = {
		string.format("DAMAGE   %d", levelData.Damage),
		string.format("RANGE    %d", levelData.Range),
		string.format("COOLDOWN %.2fs", levelData.Cooldown),
	}
	if levelData.Slow then
		table.insert(statLines, string.format("SLOW     %d%%", levelData.Slow * 100))
	end
	if levelData.AnalysisBonus then
		table.insert(statLines, string.format("ANALYSIS +%d%%", levelData.AnalysisBonus * 100))
	end
	selectionStats.Text = table.concat(statLines, "\n")

	local nextLevel = data.Levels[tower.Level + 1]
	if nextLevel then
		upgradeButton.Text = string.format("UPGRADE  %s", Utility.FormatMoney(nextLevel.Cost))
		upgradeButton.Visible = true
	else
		upgradeButton.Text = "MAX LEVEL"
		upgradeButton.Visible = true
	end

	targetButton.Text = "TARGET: " .. (tower.TargetMode or "First"):upper()

	local refund = math.floor(TowerData.TotalInvested(tower.TowerId, tower.Level) * TowerData.SellRefundRatio)
	sellButton.Text = string.format("SELL  %s", Utility.FormatMoney(refund))
end

local function refreshAI()
	local ai = ClientState.AI
	adaptationLabel.Text = Utility.Percent(ai.Adaptation or 0)
	adaptFill.Size = UDim2.fromScale(math.clamp(ai.Adaptation or 0, 0, 1), 1)

	strategyLabel.Text = tostring(ai.StrategyName)
	weakSideLabel.Text = tostring(ai.WeakSide)
	counterLabel.Text = tostring(ai.CounterUnit)

	if ai.FullyRevealed then
		analysisHint.Text = "ANALYSIS " .. Utility.Percent(ai.AnalysisRate or 0) .. " — FULL READ"
		analysisHint.TextColor3 = UIHelpers.Green
	else
		analysisHint.Text = "ANALYSIS " .. Utility.Percent(ai.AnalysisRate or 0) .. " — BUILD ANALYZERS"
		analysisHint.TextColor3 = UIHelpers.Dim
	end
end

local function refreshCore()
	local game = ClientState.Game
	local ratio = math.clamp(game.CoreHP / math.max(game.MaxCoreHP, 1), 0, 1)
	coreValueLabel.Text = string.format("%d / %d", math.floor(game.CoreHP), game.MaxCoreHP)

	local color = UIHelpers.Cyan
	if ratio <= 0.3 then
		color = UIHelpers.Red
	elseif ratio <= 0.6 then
		color = UIHelpers.Amber
	end

	coreValueLabel.TextColor3 = color
	coreFill.BackgroundColor3 = color
	UIHelpers.Tween(coreFill, 0.25, { Size = UDim2.fromScale(ratio, 1) })
end

local function refreshWave()
	local game = ClientState.Game
	waveLabel.Text = string.format("WAVE %d / %d", game.Wave, game.TotalWaves)

	if game.State == "Preparing" then
		local info = game.WaveInfo
		local summary = info and info.Summary or ""
		waveSubLabel.Text = string.format("NEXT: %s", summary)
		startWaveButton.Visible = true
	elseif game.State == "WaveActive" or game.State == "Boss" then
		waveSubLabel.Text = string.format("%d HOSTILES ACTIVE", game.EnemiesAlive)
		startWaveButton.Visible = false
	elseif game.State == "Lobby" then
		waveSubLabel.Text = "AWAITING OPERATORS"
		startWaveButton.Visible = false
	else
		waveSubLabel.Text = game.State:upper()
		startWaveButton.Visible = false
	end
end

--============================================================
-- Wiring
--============================================================

upgradeButton.MouseButton1Click:Connect(function()
	local runtimeId = ClientState.Selection.TowerRuntimeId
	if runtimeId then
		UpgradeTower:FireServer(runtimeId)
	end
end)

sellButton.MouseButton1Click:Connect(function()
	local runtimeId = ClientState.Selection.TowerRuntimeId
	if runtimeId then
		SellTower:FireServer(runtimeId)
	end
end)

targetButton.MouseButton1Click:Connect(function()
	local runtimeId = ClientState.Selection.TowerRuntimeId
	if not runtimeId then
		return
	end
	local tower = ClientState.GetTowerByRuntimeId(runtimeId)
	if not tower then
		return
	end
	-- Cycle through the four modes.
	local modes = TowerData.TargetModes
	local currentIndex = 1
	for index, mode in ipairs(modes) do
		if mode == tower.TargetMode then
			currentIndex = index
			break
		end
	end
	local nextMode = modes[(currentIndex % #modes) + 1]
	ChangeTargetMode:FireServer(runtimeId, nextMode)
end)

Signals.EconomyUpdate.Event:Connect(function()
	moneyLabel.Text = Utility.FormatMoney(ClientState.Money)
	refreshShop()
	refreshSelection()
end)

Signals.StateChanged.Event:Connect(function()
	refreshWave()
	refreshCore()
end)

Signals.CoreUpdate.Event:Connect(refreshCore)
Signals.AIUpdate.Event:Connect(refreshAI)
Signals.SelectionChanged.Event:Connect(function()
	refreshShop()
	refreshSelection()
end)
Signals.TowersChanged.Event:Connect(refreshSelection)

Signals.ActionResult.Event:Connect(function(payload)
	if not payload.Message or payload.Message == "Placed" then
		return -- a successful placement is self-evident on the board
	end
	toast(payload.Message:upper(), if payload.Success then UIHelpers.Green else UIHelpers.Red)
end)

Signals.WaveCleared.Event:Connect(function(payload)
	toast(string.format("WAVE %d CLEARED  +%s", payload.Wave, Utility.FormatMoney(payload.Reward)), UIHelpers.Green)
end)

Signals.Leak.Event:Connect(function()
	toast("CORE BREACHED", UIHelpers.Red)
end)

-- Prep countdown ticks locally between server broadcasts so the number moves
-- smoothly instead of jumping once a second.
RunService.Heartbeat:Connect(function(dt)
	local game = ClientState.Game
	if game.State ~= "Preparing" then
		return
	end
	game.PrepRemaining = math.max(0, game.PrepRemaining - dt)
	local info = game.WaveInfo
	waveSubLabel.Text = string.format(
		"NEXT IN %ds   %s",
		math.ceil(game.PrepRemaining),
		info and info.Summary or ""
	)
end)

refreshShop()
refreshAI()
refreshCore()
refreshWave()
