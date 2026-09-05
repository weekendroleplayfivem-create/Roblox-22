--[[
	MatchHUD
	The in-match HUD (brief section 22): team/score bar, timer, ammo, HP,
	boost meter, crosshair, kill feed, killstreak banners, respawn countdown,
	XP/level toasts. Pulls state from the match/weapon/scooter remotes and
	ClientState rather than owning any gameplay logic itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local MatchData = require(ReplicatedStorage.Shared.MatchData)
local Utility = require(ReplicatedStorage.Shared.Utility)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

local UIHelpers = require(playerScripts:WaitForChild("UIHelpers"))
local ClientState = require(playerScripts:WaitForChild("ClientState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchStateChanged = Remotes:WaitForChild("MatchStateChanged")
local PlayerEliminated = Remotes:WaitForChild("PlayerEliminated")
local PlayerDamaged = Remotes:WaitForChild("PlayerDamaged")
local RespawnCountdown = Remotes:WaitForChild("RespawnCountdown")
local XPGained = Remotes:WaitForChild("XPGained")
local LevelUp = Remotes:WaitForChild("LevelUp")
local HitConfirmed = Remotes:WaitForChild("HitConfirmed")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MatchHUD"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

--============================================================
-- Top bar: score + timer
--============================================================

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(0, 640, 0, 60)
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 16)
topBar.BackgroundTransparency = 1
topBar.Parent = screenGui

local blueScoreLabel = UIHelpers.Label(topBar, "BLUE TEAM   0", UDim2.fromOffset(260, 40), UDim2.fromOffset(0, 10), 26, UIHelpers.NeonBlue)
blueScoreLabel.TextXAlignment = Enum.TextXAlignment.Left

local purpleScoreLabel = UIHelpers.Label(topBar, "0   PURPLE TEAM", UDim2.fromOffset(260, 40), UDim2.fromOffset(380, 10), 26, UIHelpers.NeonPurple)
purpleScoreLabel.TextXAlignment = Enum.TextXAlignment.Right

local timerLabel = UIHelpers.Label(topBar, "00:00", UDim2.fromOffset(120, 40), UDim2.fromOffset(260, 10), 30)
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
timerLabel.TextColor3 = Color3.new(1, 1, 1)

local matchStateLabel = UIHelpers.Label(screenGui, "", UDim2.fromOffset(400, 60), UDim2.new(0.5, -200, 0.35, 0), 40)
matchStateLabel.TextXAlignment = Enum.TextXAlignment.Center
matchStateLabel.TextColor3 = UIHelpers.NeonBlue
matchStateLabel.Visible = false

--============================================================
-- Crosshair
--============================================================

local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.fromOffset(24, 24)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.BackgroundTransparency = 1
crosshair.Parent = screenGui

local crosshairLines = {}
for _, spec in ipairs({
	{ Size = UDim2.fromOffset(2, 8), Pos = UDim2.new(0.5, -1, 0, -12) },
	{ Size = UDim2.fromOffset(2, 8), Pos = UDim2.new(0.5, -1, 1, 4) },
	{ Size = UDim2.fromOffset(8, 2), Pos = UDim2.new(0, -12, 0.5, -1) },
	{ Size = UDim2.fromOffset(8, 2), Pos = UDim2.new(1, 4, 0.5, -1) },
}) do
	local line = Instance.new("Frame")
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.Size = spec.Size
	line.Position = spec.Pos
	line.BorderSizePixel = 0
	line.Parent = crosshair
	table.insert(crosshairLines, { instance = line, basePos = spec.Pos })
end

local hitmarker = Instance.new("ImageLabel")
hitmarker.BackgroundTransparency = 1
hitmarker.Size = UDim2.fromOffset(36, 36)
hitmarker.AnchorPoint = Vector2.new(0.5, 0.5)
hitmarker.Position = UDim2.new(0.5, 0, 0.5, 0)
hitmarker.ImageTransparency = 1
hitmarker.Rotation = 45
hitmarker.Parent = screenGui
-- Drawn with UIStroke crosses instead of an image asset (no external asset id needed).
for _, rot in ipairs({ 0, 90 }) do
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	bar.Size = UDim2.fromOffset(36, 3)
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Rotation = rot
	bar.BackgroundTransparency = 1
	bar.Parent = hitmarker
end

HitConfirmed.OnClientEvent:Connect(function(isHeadshot)
	for _, child in ipairs(hitmarker:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundTransparency = 0
			UIHelpers.Tween(child, 0.35, { BackgroundTransparency = 1 })
		end
	end
	if isHeadshot then
		UIHelpers.Tween(hitmarker, 0.1, { Size = UDim2.fromOffset(48, 48) })
		task.delay(0.1, function()
			UIHelpers.Tween(hitmarker, 0.2, { Size = UDim2.fromOffset(36, 36) })
		end)
	end
end)

RunService.RenderStepped:Connect(function()
	local weapon = ClientState.Weapon.EquippedWeaponId and WeaponData.Get(ClientState.Weapon.EquippedWeaponId)
	local spreadStat = weapon and (ClientState.Weapon.ADS and weapon.ADSSpread or weapon.Spread) or 2
	local spread = math.clamp((spreadStat or 2) * 1.6, 4, 26)
	crosshairLines[1].instance.Position = UDim2.new(0.5, -1, 0, -spread - 4)
	crosshairLines[2].instance.Position = UDim2.new(0.5, -1, 1, spread - 4)
	crosshairLines[3].instance.Position = UDim2.new(0, -spread - 4, 0.5, -1)
	crosshairLines[4].instance.Position = UDim2.new(1, spread - 4, 0.5, -1)
end)

--============================================================
-- Bottom HUD: HP, boost, ammo
--============================================================

local hpLabel = UIHelpers.Label(screenGui, "HP 100", UDim2.fromOffset(160, 30), UDim2.new(0, 24, 1, -110), 22, Color3.fromRGB(255, 90, 90))
local hpTrack, hpFill = UIHelpers.ProgressBar(screenGui, UDim2.fromOffset(220, 14), UDim2.new(0, 24, 1, -78), Color3.fromRGB(255, 90, 90))

local boostLabel = UIHelpers.Label(screenGui, "BOOST", UDim2.fromOffset(160, 24), UDim2.new(0, 24, 1, -58), 16, UIHelpers.NeonPurple)
local boostTrack, boostFill = UIHelpers.ProgressBar(screenGui, UDim2.fromOffset(220, 12), UDim2.new(0, 24, 1, -32), UIHelpers.NeonPurple)

local ammoLabel = UIHelpers.Label(screenGui, "VANTA RIFLE", UDim2.fromOffset(260, 24), UDim2.new(1, -280, 1, -80), 18)
ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
local ammoCount = UIHelpers.Label(screenGui, "25 / 25", UDim2.fromOffset(260, 40), UDim2.new(1, -280, 1, -56), 32)
ammoCount.TextXAlignment = Enum.TextXAlignment.Right

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		hpLabel.Text = "HP " .. math.floor(humanoid.Health)
		UIHelpers.SetProgress(hpFill, humanoid.Health / humanoid.MaxHealth, 0.15)
	end

	UIHelpers.SetProgress(boostFill, ClientState.Scooter.BoostMeter / 100, 0.1)

	local weaponId = ClientState.Weapon.EquippedWeaponId
	local weapon = weaponId and WeaponData.Get(weaponId)
	if weapon then
		ammoLabel.Text = weapon.DisplayName:upper()
		if weapon.Slot == "Melee" then
			ammoCount.Text = ""
		elseif ClientState.Weapon.Reloading[weaponId] then
			ammoCount.Text = "RELOADING..."
		else
			ammoCount.Text = string.format("%d / %d", ClientState.Weapon.Ammo[weaponId] or weapon.Magazine, weapon.Magazine)
		end
	end
end)

--============================================================
-- Score / timer / match state updates
--============================================================

MatchStateChanged.OnClientEvent:Connect(function(data)
	if data.Mode == "TeamBlast" and data.Scores then
		blueScoreLabel.Text = string.format("BLUE TEAM   %d", data.Scores.Blue or 0)
		purpleScoreLabel.Text = string.format("%d   PURPLE TEAM", data.Scores.Purple or 0)
	end

	if data.State == "Countdown" then
		matchStateLabel.Visible = true
		matchStateLabel.Text = "MATCH STARTS IN " .. tostring(data.TimeLeft)
		timerLabel.Text = "--:--"
	elseif data.State == "InProgress" then
		matchStateLabel.Visible = false
		timerLabel.Text = Utility.FormatTime(data.TimeLeft or 0)
	elseif data.State == "Waiting" then
		matchStateLabel.Visible = true
		matchStateLabel.Text = "WAITING FOR PLAYERS..."
	end
end)

--============================================================
-- Kill feed + killstreaks
--============================================================

local killFeed = Instance.new("Frame")
killFeed.Size = UDim2.fromOffset(360, 220)
killFeed.AnchorPoint = Vector2.new(1, 0)
killFeed.Position = UDim2.new(1, -20, 0, 90)
killFeed.BackgroundTransparency = 1
killFeed.Parent = screenGui

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
killFeedLayout.Padding = UDim.new(0, 6)
killFeedLayout.Parent = killFeed

local killstreakBanner = UIHelpers.Label(screenGui, "", UDim2.fromOffset(500, 50), UDim2.new(0.5, -250, 0.2, 0), 30, UIHelpers.NeonPurple)
killstreakBanner.TextXAlignment = Enum.TextXAlignment.Center
killstreakBanner.Visible = false

PlayerEliminated.OnClientEvent:Connect(function(data)
	if data.Type == "Killstreak" then
		killstreakBanner.Text = string.format("%s IS ON A %d KILL STREAK", data.Player:upper(), data.Streak)
		killstreakBanner.Visible = true
		killstreakBanner.TextTransparency = 0
		UIHelpers.Tween(killstreakBanner, 2.5, { TextTransparency = 1 })
		task.delay(2.5, function()
			killstreakBanner.Visible = false
		end)
		return
	end

	if not ClientState.Settings.ShowKillFeed then
		return
	end

	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(360, 32)
	row.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	row.BackgroundTransparency = 0.3
	row.Parent = killFeed
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local weapon = data.WeaponId and WeaponData.Get(data.WeaponId)
	local text = string.format("%s  ✕  %s", data.Killer, data.Victim)
	if weapon then
		text = string.format("%s  [%s]%s  %s", data.Killer, weapon.DisplayName, data.Headshot and " HS" or "", data.Victim)
	end

	local label = UIHelpers.Label(row, text, UDim2.fromScale(1, 1), UDim2.fromOffset(10, 0), 16)
	label.TextXAlignment = Enum.TextXAlignment.Left
	if data.Victim == player.Name then
		label.TextColor3 = Color3.fromRGB(255, 120, 120)
	end

	if data.Killer == player.Name then
		local popup = UIHelpers.Label(screenGui, "ELIMINATION\n+" .. tostring(data.Score or MatchData.KillScore), UDim2.fromOffset(300, 60), UDim2.new(0.5, -150, 0.4, 0), 26, UIHelpers.NeonBlue)
		popup.TextXAlignment = Enum.TextXAlignment.Center
		UIHelpers.Tween(popup, 1.2, { TextTransparency = 1, Position = popup.Position - UDim2.fromOffset(0, 20) })
		Debris:AddItem(popup, 1.3)
	end

	Debris:AddItem(row, 6)
	task.delay(5, function()
		if row.Parent then
			UIHelpers.Tween(row, 1, { BackgroundTransparency = 1 })
			for _, child in ipairs(row:GetChildren()) do
				if child:IsA("TextLabel") then
					UIHelpers.Tween(child, 1, { TextTransparency = 1 })
				end
			end
		end
	end)
end)

--============================================================
-- Damage flash + respawn countdown
--============================================================

local damageFlash = Instance.new("Frame")
damageFlash.Size = UDim2.fromScale(1, 1)
damageFlash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
damageFlash.BackgroundTransparency = 1
damageFlash.ZIndex = 50
damageFlash.Parent = screenGui

PlayerDamaged.OnClientEvent:Connect(function(_amount, _isHeadshot)
	damageFlash.BackgroundTransparency = 0.75
	UIHelpers.Tween(damageFlash, 0.3, { BackgroundTransparency = 1 })
	ClientState.Shake(1.2, 0.15)
end)

local respawnOverlay = Instance.new("Frame")
respawnOverlay.Size = UDim2.fromScale(1, 1)
respawnOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
respawnOverlay.BackgroundTransparency = 1
respawnOverlay.Visible = false
respawnOverlay.ZIndex = 40
respawnOverlay.Parent = screenGui

local respawnLabel = UIHelpers.Label(respawnOverlay, "RESPAWNING...", UDim2.fromOffset(500, 50), UDim2.new(0.5, -250, 0.4, 0), 30)
respawnLabel.TextXAlignment = Enum.TextXAlignment.Center

local respawnCounter = UIHelpers.Label(respawnOverlay, "3", UDim2.fromOffset(200, 80), UDim2.new(0.5, -100, 0.48, 0), 60, UIHelpers.NeonBlue)
respawnCounter.TextXAlignment = Enum.TextXAlignment.Center

RespawnCountdown.OnClientEvent:Connect(function(secondsLeft)
	respawnOverlay.Visible = true
	respawnOverlay.BackgroundTransparency = 0.5
	respawnCounter.Text = tostring(secondsLeft)
	if secondsLeft <= 1 then
		task.delay(1, function()
			respawnOverlay.Visible = false
		end)
	end
end)

--============================================================
-- XP / level toasts
--============================================================

XPGained.OnClientEvent:Connect(function(amount, reason)
	local toast = UIHelpers.Label(screenGui, string.format("+%d XP  (%s)", amount, reason), UDim2.fromOffset(260, 30), UDim2.new(0, 24, 1, -140), 16, UIHelpers.NeonBlue)
	UIHelpers.Tween(toast, 1.5, { TextTransparency = 1, Position = toast.Position - UDim2.fromOffset(0, 20) })
	Debris:AddItem(toast, 1.6)
end)

LevelUp.OnClientEvent:Connect(function(newLevel)
	local banner = UIHelpers.Label(screenGui, "LEVEL UP! " .. tostring(newLevel), UDim2.fromOffset(400, 50), UDim2.new(0.5, -200, 0.3, 0), 34, UIHelpers.NeonPurple)
	banner.TextXAlignment = Enum.TextXAlignment.Center
	UIHelpers.Tween(banner, 2, { TextTransparency = 1 })
	Debris:AddItem(banner, 2.1)
end)

--============================================================
-- Visibility: only show while actually playing
--============================================================

local function updateVisibility()
	screenGui.Enabled = player.Character ~= nil
end

player.CharacterAdded:Connect(updateVisibility)
player.CharacterRemoving:Connect(function()
	task.wait()
	updateVisibility()
end)
updateVisibility()
