--[[
	HUDScreen
	In-match heads-up display (StarterGui/HUD):
	  top     - match timer, team scores / FFA leader / gun game tier
	  centre  - crosshair + hit marker (Crosshair module), announcements,
	            XP popups, streak callouts, status line (respawn, revealed ...)
	  bottom  - health + shield, current weapon + ammo + slots, ability cooldowns
	  side    - kill feed
	  edges   - directional damage indicators + soft damage flash
	One RenderStepped loop drives everything that must update every frame.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local MathUtil = require(Shared.Modules.MathUtil)
local MatchConfig = require(Shared.Config.MatchConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local PlayerConfig = require(Shared.Config.PlayerConfig)

local UIKit = require(script.Parent.UIKit)
local Crosshair = require(script.Parent.Crosshair)
local ClientState = require(script.Parent.Parent.ClientState)
local SoundController = require(script.Parent.Parent.SoundController)
local WeaponController = require(script.Parent.Parent.WeaponController)
local AbilityController = require(script.Parent.Parent.AbilityController)
local CameraController = require(script.Parent.Parent.CameraController)
local InputController = require(script.Parent.Parent.InputController)

local HUDScreen = {}

local player = Players.LocalPlayer
local Theme = UIKit.Theme

local KILLFEED_MAX = 5
local KILLFEED_LIFETIME = 6
local COMBO_WINDOW = 4
local INDICATOR_LIFETIME = 1.4

local screen: ScreenGui
local hudRoot: Frame
local ui: { [string]: any } = {}
local killfeedEntries = {}
local indicators = {}
local lastCountdownSecond = -1
local comboCount = 0
local lastKillTime = 0
local respawnAt = 0
local revealedUntil = 0

local function teamColor(team: string?): Color3
	if team and MatchConfig.Teams[team] then
		return MatchConfig.Teams[team].Color
	end
	return MatchConfig.FreeForAllColor
end

local function keyHint(action: string): string
	local kind = InputController:GetInputKind()
	if kind == "Gamepad" then
		return if action == "MovementAbility" then "LB" else "RB"
	elseif kind == "Touch" then
		return ""
	end
	return if action == "MovementAbility" then "E" else "Q"
end

--[[ Builders ]]

local function buildTopBar(parent: Frame)
	local bar = UIKit.Create("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 64),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	ui.LeftScore = UIKit.Panel({ Size = UDim2.fromOffset(110, 52), Position = UDim2.fromOffset(0, 0), Parent = bar })
	ui.LeftScoreLabel = UIKit.Label({ Text = "0", Font = UIKit.FontBlack, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = ui.LeftScore })
	ui.RightScore = UIKit.Panel({ Size = UDim2.fromOffset(110, 52), Position = UDim2.new(1, -110, 0, 0), Parent = bar })
	ui.RightScoreLabel = UIKit.Label({ Text = "0", Font = UIKit.FontBlack, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = ui.RightScore })
	local timerPanel = UIKit.Panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(160, 52), Parent = bar })
	ui.Timer = UIKit.Label({ Text = "0:00", Font = UIKit.FontBlack, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 34), Parent = timerPanel })
	ui.ScoreLimit = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 16), Parent = timerPanel })
end

local function buildVitals(parent: Frame)
	local panel = UIKit.Panel({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -20), Size = UDim2.fromOffset(300, 74), Parent = parent })
	UIKit.Padding(panel, 10)
	ui.ShieldBar = UIKit.Bar({ Size = UDim2.new(1, -60, 0, 10), Color = Theme.Accent, Parent = panel })
	ui.ShieldText = UIKit.Label({ Text = "50", TextSize = 16, TextColor3 = Theme.Accent, Position = UDim2.new(1, -52, 0, -6), Size = UDim2.fromOffset(52, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })
	ui.HealthBar = UIKit.Bar({ Size = UDim2.new(1, -60, 0, 18), Position = UDim2.fromOffset(0, 22), Color = Theme.Success, Parent = panel })
	ui.HealthText = UIKit.Label({ Text = "100", Font = UIKit.FontBlack, TextSize = 26, Position = UDim2.new(1, -56, 0, 18), Size = UDim2.fromOffset(56, 28), TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })
	ui.VitalsPanel = panel
end

local function buildWeapon(parent: Frame)
	local panel = UIKit.Panel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(300, 96), Parent = parent })
	ui.WeaponPanel = panel
	UIKit.Padding(panel, 10)
	ui.WeaponName = UIKit.Label({ Text = "", TextSize = 16, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 18), Parent = panel })
	ui.Ammo = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 42), RichText = true, Parent = panel })
	ui.ReloadBar = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -4), Color = Theme.Yellow, Parent = panel })
	ui.Slots = UIKit.Create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -124), Size = UDim2.fromOffset(300, 28), BackgroundTransparency = 1, Parent = parent })
	local layout = UIKit.List(ui.Slots, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	ui.SlotLabels = {}
	for index, slot in { "Primary", "Secondary" } do
		local label = UIKit.Label({
			Text = "",
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.3,
			BackgroundColor3 = Theme.Panel,
			Size = UDim2.fromOffset(140, 26),
			LayoutOrder = index,
			Parent = ui.Slots,
		})
		UIKit.Corner(label, 6)
		ui.SlotLabels[slot] = label
	end
end

local function buildAbilities(parent: Frame)
	local holder = UIKit.Create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(180, 76), BackgroundTransparency = 1, Parent = parent })
	ui.AbilityHolder = holder
	UIKit.List(holder, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	ui.Abilities = {}
	for index, slot in { "Movement", "Tactical" } do
		local tile = UIKit.Panel({ Size = UDim2.fromOffset(76, 76), LayoutOrder = index, Parent = holder })
		local fill = UIKit.Create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2, Parent = tile })
		UIKit.Corner(fill, 12)
		local name = UIKit.Label({ Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Position = UDim2.fromOffset(4, 18), Size = UDim2.new(1, -8, 0, 34), ZIndex = 3, Parent = tile })
		local key = UIKit.Label({ Text = "", TextSize = 13, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 16), ZIndex = 3, Parent = tile })
		local timer = UIKit.Label({ Text = "", Font = UIKit.FontBlack, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 24), ZIndex = 3, Parent = tile })
		ui.Abilities[slot] = { Tile = tile, Fill = fill, Name = name, Key = key, Timer = timer, WasReady = true }
	end
end

local function buildKillfeed(parent: Frame)
	ui.Killfeed = UIKit.Create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 90), Size = UDim2.fromOffset(380, 200), BackgroundTransparency = 1, Parent = parent })
	UIKit.List(ui.Killfeed, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right)
end

local function buildCenter(parent: Frame)
	ui.Announcement = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 0), Size = UDim2.fromOffset(900, 70), Text = "", Font = UIKit.FontBlack, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, Parent = parent })
	ui.AnnouncementSub = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 66), Size = UDim2.fromOffset(900, 30), Text = "", TextSize = 24, TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Center, Parent = parent })
	ui.Status = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(600, 30), Text = "", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, Parent = parent })
	ui.Combo = UIKit.Label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.56, 0), Size = UDim2.fromOffset(600, 34), Text = "", Font = UIKit.FontBlack, TextSize = 28, TextColor3 = Theme.Accent2, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, Parent = parent })
	ui.XPHolder = UIKit.Create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 60, 0.5, 30), Size = UDim2.fromOffset(260, 120), BackgroundTransparency = 1, Parent = parent })
	UIKit.List(ui.XPHolder, Enum.FillDirection.Vertical, 2)
	ui.IndicatorHolder = UIKit.Create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Parent = parent })

	-- Soft edge flash (pink for health, cyan for shield). No gore.
	ui.Flash = UIKit.Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Accent2, BackgroundTransparency = 1, ZIndex = 0, Parent = parent })
	UIKit.Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, 0.85),
			NumberSequenceKeypoint.new(0.75, 0.85),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = ui.Flash,
	})
end

--[[ Dynamic pieces ]]

function HUDScreen:Announce(text: string, sub: string?, duration: number?, small: boolean?)
	ui.Announcement.Text = text
	ui.Announcement.TextSize = if small then 36 else 56
	ui.AnnouncementSub.Text = sub or ""
	ui.Announcement.TextTransparency = 0
	ui.AnnouncementSub.TextTransparency = 0
	local scale = ui.Announcement:FindFirstChildOfClass("UIScale") or UIKit.Create("UIScale", { Parent = ui.Announcement })
	scale.Scale = 1.3
	UIKit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local token = os.clock()
	ui.AnnouncementToken = token
	task.delay(duration or 2, function()
		if ui.AnnouncementToken == token then
			UIKit.Tween(ui.Announcement, 0.3, { TextTransparency = 1 })
			UIKit.Tween(ui.AnnouncementSub, 0.3, { TextTransparency = 1 })
		end
	end)
end

function HUDScreen:XPPopup(amount: number, reason: string?)
	local label = UIKit.Label({
		Text = string.format("+%d XP  %s", amount, reason or ""),
		TextSize = 18,
		TextColor3 = Theme.Yellow,
		TextStrokeTransparency = 0.6,
		Size = UDim2.fromOffset(260, 22),
		Parent = ui.XPHolder,
	})
	SoundController:Play("XP")
	task.delay(1.6, function()
		UIKit.Tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.wait(0.45)
		label:Destroy()
	end)
end

local function addKillfeed(data)
	local killer, victim = data.Killer, data.Victim
	local victimName = victim and victim.Name or "?"
	local text
	if killer then
		local weapon = data.Weapon and WeaponConfig.Get(data.Weapon)
		local how = if weapon then weapon.DisplayName elseif data.Reason == "OutOfBounds" then "knock-out" else "elim"
		text = string.format(
			'<font color="#%s">%s</font>  <font color="#AAB4D0">[%s%s]</font>  <font color="#%s">%s</font>',
			teamColor(killer.Team):ToHex(),
			killer.Name,
			how,
			if data.Headshot then " • HEAD" else "",
			teamColor(victim and victim.Team):ToHex(),
			victimName
		)
	else
		text = string.format('<font color="#%s">%s</font>  <font color="#AAB4D0">%s</font>', teamColor(victim and victim.Team):ToHex(), victimName, if data.Reason == "OutOfBounds" then "fell out of bounds" else "was eliminated")
	end
	local involvesMe = (killer and killer.Id == player.UserId) or (victim and victim.Id == player.UserId)
	local entry = UIKit.Label({
		Text = text,
		RichText = true,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundColor3 = if involvesMe then Theme.PanelLight else Theme.Panel,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromOffset(380, 26),
		LayoutOrder = -math.floor(os.clock() * 100),
		Parent = ui.Killfeed,
	})
	UIKit.Padding(entry, 4)
	UIKit.Corner(entry, 6)
	table.insert(killfeedEntries, entry)
	while #killfeedEntries > KILLFEED_MAX do
		local oldest = table.remove(killfeedEntries, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(KILLFEED_LIFETIME, function()
		if entry.Parent then
			UIKit.Tween(entry, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
			task.wait(0.35)
			local index = table.find(killfeedEntries, entry)
			if index then
				table.remove(killfeedEntries, index)
			end
			entry:Destroy()
		end
	end)
end

local function addIndicator(from: Vector3)
	local arrow = UIKit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(46, 8),
		BackgroundColor3 = Theme.Accent2,
		BorderSizePixel = 0,
		Parent = ui.IndicatorHolder,
	})
	UIKit.Corner(arrow, 4)
	table.insert(indicators, { Frame = arrow, From = from, Born = os.clock() })
end

local function updateIndicators()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for index = #indicators, 1, -1 do
		local indicator = indicators[index]
		local age = now - indicator.Born
		if age > INDICATOR_LIFETIME or not camera then
			indicator.Frame:Destroy()
			table.remove(indicators, index)
		else
			local relative = camera.CFrame:PointToObjectSpace(indicator.From)
			local angle = math.atan2(relative.X, -relative.Z) -- 0 = straight ahead
			local radius = 110
			indicator.Frame.Position = UDim2.fromOffset(math.sin(angle) * radius, -math.cos(angle) * radius)
			indicator.Frame.Rotation = math.deg(angle)
			indicator.Frame.BackgroundTransparency = age / INDICATOR_LIFETIME
		end
	end
end

local function updateTopBar(matchState)
	local scoreboard = ClientState.Get("Scoreboard") or {}
	local remaining = if matchState.PhaseEndsAt then matchState.PhaseEndsAt - workspace:GetServerTimeNow() else 0
	ui.Timer.Text = MathUtil.FormatTime(remaining)

	if matchState.Phase == "Countdown" then
		local second = math.ceil(remaining)
		if second ~= lastCountdownSecond and second > 0 then
			lastCountdownSecond = second
			HUDScreen:Announce(tostring(second), "GET READY", 0.9)
			SoundController:Play("Countdown")
		end
	else
		lastCountdownSecond = -1
	end

	if matchState.TeamBased and matchState.TeamScores then
		local myTeam = player:GetAttribute("Team")
		local other = if myTeam == "Flux" then "Nova" else "Flux"
		local mine = myTeam or "Nova"
		ui.LeftScore.BackgroundColor3 = teamColor(mine):Lerp(Theme.Panel, 0.55)
		ui.RightScore.BackgroundColor3 = teamColor(other):Lerp(Theme.Panel, 0.55)
		ui.LeftScoreLabel.Text = tostring(matchState.TeamScores[mine] or 0)
		ui.RightScoreLabel.Text = tostring(matchState.TeamScores[other] or 0)
		ui.ScoreLimit.Text = "FIRST TO " .. tostring(matchState.ScoreLimit or 0)
	else
		local me, leader = nil, scoreboard[1]
		for _, entry in scoreboard do
			if entry.Id == player.UserId then
				me = entry
			end
		end
		ui.LeftScore.BackgroundColor3 = Theme.PanelLight
		ui.RightScore.BackgroundColor3 = Theme.Panel
		if matchState.Mode == "GunGame" then
			local best = 0
			for _, entry in scoreboard do
				best = math.max(best, entry.GunGameLevel or 0)
			end
			ui.LeftScoreLabel.Text = tostring(me and me.GunGameLevel or 1)
			ui.RightScoreLabel.Text = tostring(best)
			ui.ScoreLimit.Text = string.format("TIER • %d TOTAL", matchState.ScoreLimit or 0)
		else
			ui.LeftScoreLabel.Text = tostring(me and me.Kills or 0)
			ui.RightScoreLabel.Text = tostring(leader and leader.Kills or 0)
			ui.ScoreLimit.Text = "YOU • LEADER • " .. tostring(matchState.ScoreLimit or 0)
		end
	end
end

local function updateVitals()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local health = math.max(0, humanoid.Health)
	local shield = character:GetAttribute("Shield") or 0
	local maxShield = character:GetAttribute("MaxShield") or PlayerConfig.Health.MaxShield
	ui.HealthBar.Set(health / humanoid.MaxHealth)
	ui.HealthText.Text = tostring(math.ceil(health))
	ui.HealthBar.Fill.BackgroundColor3 = Theme.Danger:Lerp(Theme.Success, health / humanoid.MaxHealth)
	ui.ShieldBar.Set(shield / math.max(1, maxShield))
	ui.ShieldText.Text = tostring(math.floor(shield))
end

local function updateWeapon()
	local info = WeaponController:GetHudInfo()
	ui.Slots.Visible = info ~= nil
	if not info then
		ui.WeaponName.Text = ""
		ui.Ammo.Text = ""
		ui.ReloadBar.Set(0)
		return
	end
	ui.WeaponName.Text = string.upper(info.Weapon.DisplayName)
	local reserve = if info.Infinite then "∞" else tostring(info.Reserve)
	local magColor = if info.Mag == 0 then Theme.Danger:ToHex() elseif info.Mag <= info.Weapon.MagazineSize * 0.25 then Theme.Yellow:ToHex() else "FFFFFF"
	ui.Ammo.Text = string.format('<font color="#%s">%d</font><font size="22" color="#A0ACCD"> / %s</font>', magColor, info.Mag, reserve)
	ui.ReloadBar.Set(if info.Reloading then info.ReloadProgress else 0)
	for slot, label in ui.SlotLabels do
		local weaponId = info.Slots[slot]
		label.Visible = weaponId ~= nil
		if weaponId then
			local weapon = WeaponConfig.Get(weaponId)
			label.Text = string.format("%d  %s", if slot == "Primary" then 1 else 2, weapon.DisplayName)
			label.TextColor3 = if info.Equipped == slot then Theme.Text else Theme.SubText
			label.BackgroundColor3 = if info.Equipped == slot then Theme.PanelLight else Theme.Panel
		end
	end
end

local function updateAbilities()
	local cooldowns = AbilityController:GetCooldowns()
	for slot, widget in ui.Abilities do
		local data = cooldowns[slot]
		local config = data.Config
		widget.Name.Text = if config then string.upper(config.DisplayName) else ""
		widget.Key.Text = keyHint(if slot == "Movement" then "MovementAbility" else "TacticalAbility")
		local ready = data.Remaining <= 0
		widget.Fill.Size = UDim2.fromScale(1, if ready then 0 else math.clamp(data.Remaining / data.Cooldown, 0, 1))
		widget.Timer.Text = if ready then "" else tostring(math.ceil(data.Remaining))
		local stroke = widget.Tile:FindFirstChildOfClass("UIStroke")
		if stroke and config then
			stroke.Color = config.Color
			stroke.Transparency = if ready then 0.1 else 0.75
		end
		if ready and not widget.WasReady then
			-- Small pop when an ability comes off cooldown.
			local scale = widget.Tile:FindFirstChildOfClass("UIScale") or UIKit.Create("UIScale", { Parent = widget.Tile })
			scale.Scale = 1.15
			UIKit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		widget.WasReady = ready
	end
end

local function updateStatus()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local now = workspace:GetServerTimeNow()
	local text = ""
	local matchState = ClientState.Get("MatchState")
	if humanoid and humanoid.Health <= 0 and matchState.Phase == "Active" then
		text = string.format("Respawning in %d", math.max(0, math.ceil(respawnAt - os.clock())))
	elseif character and character:GetAttribute("SpawnProtected") then
		text = "Spawn protected"
	elseif now < revealedUntil then
		text = "You were revealed by a scan!"
	elseif ClientState.Get("TemporaryProfile") then
		text = ""
	end
	ui.Status.Text = text
end

local function onRender()
	local inMatch = ClientState.IsInMatch()
	hudRoot.Visible = inMatch
	if not inMatch then
		return
	end
	Crosshair:Update()
	updateVitals()
	updateWeapon()
	updateAbilities()
	updateIndicators()
	updateStatus()
	local matchState = ClientState.Get("MatchState")
	if matchState then
		updateTopBar(matchState)
	end
	if os.clock() - lastKillTime > COMBO_WINDOW and comboCount > 0 then
		comboCount = 0
		UIKit.Tween(ui.Combo, 0.3, { TextTransparency = 1 })
	end
end

function HUDScreen:Build()
	screen = UIKit.GetScreen("HUD", 5)
	hudRoot = UIKit.Create("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
	-- Crosshair stays pixel-exact (not scaled); everything else auto-scales.
	Crosshair:Build(screen)
	local scaled = UIKit.Create("Frame", { Name = "Scaled", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = hudRoot })
	buildCenter(hudRoot)
	buildTopBar(scaled)
	buildVitals(scaled)
	buildWeapon(scaled)
	buildAbilities(scaled)
	buildKillfeed(scaled)
	-- Each anchored cluster scales around its own anchor point.
	for _, cluster in { scaled:FindFirstChild("TopBar"), ui.VitalsPanel, ui.WeaponPanel, ui.Slots, ui.AbilityHolder, ui.Killfeed } do
		UIKit.AutoScale(cluster, 0.6, 1.2)
	end
	ui.Root = hudRoot
end

function HUDScreen:GetScreen(): ScreenGui
	return screen
end

function HUDScreen:Start()
	Crosshair:Start()
	RunService.RenderStepped:Connect(onRender)

	Net.Event("Combat", "Elimination").OnClientEvent:Connect(function(data)
		addKillfeed(data)
		if data.Killer and data.Killer.Id == player.UserId then
			local now = os.clock()
			comboCount = if now - lastKillTime <= COMBO_WINDOW then comboCount + 1 else 1
			lastKillTime = now
			local callouts = { "ELIMINATION", "DOUBLE ELIM!", "TRIPLE ELIM!", "QUAD ELIM!", "UNSTOPPABLE!" }
			ui.Combo.Text = callouts[math.min(comboCount, #callouts)] .. (if data.Streak and data.Streak >= 3 then string.format("  •  %d STREAK", data.Streak) else "")
			ui.Combo.TextTransparency = 0
			local scale = ui.Combo:FindFirstChildOfClass("UIScale") or UIKit.Create("UIScale", { Parent = ui.Combo })
			scale.Scale = 1.25
			UIKit.Tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if data.Victim and data.Victim.Id == player.UserId then
			respawnAt = os.clock() + PlayerConfig.Respawn.Delay
			local by = if data.Killer then "Eliminated by " .. data.Killer.Name else "Eliminated"
			HUDScreen:Announce(by, nil, 2, true)
		end
	end)

	Net.Event("Combat", "DamageTaken").OnClientEvent:Connect(function(data)
		if typeof(data.From) == "Vector3" then
			addIndicator(data.From)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				CameraController:DamagePunch((data.From - root.Position).Unit)
			end
		end
		local shieldLeft = (player.Character and player.Character:GetAttribute("Shield") or 0) > 0
		ui.Flash.BackgroundColor3 = if shieldLeft then Theme.Accent else Theme.Accent2
		ui.Flash.BackgroundTransparency = 0.55
		UIKit.Tween(ui.Flash, 0.35, { BackgroundTransparency = 1 })
		CameraController:Shake(if data.Explosion then 0.5 else 0.18)
		SoundController:Play(if data.ShieldBroken then "ShieldBreak" else "Damaged", 0.05)
	end)

	Net.Event("Match", "XPEvent").OnClientEvent:Connect(function(data)
		if ClientState.IsInMatch() then
			HUDScreen:XPPopup(data.Amount, data.Reason)
		end
	end)

	Net.Event("Match", "Announcement").OnClientEvent:Connect(function(data)
		HUDScreen:Announce(data.Text or "", data.Sub, data.Duration, data.Small)
		if data.Text == "GO!" then
			SoundController:Play("MatchStart")
		end
	end)

	Net.Event("Abilities", "AbilityEffect").OnClientEvent:Connect(function(data)
		if data.Kind == "Revealed" then
			revealedUntil = workspace:GetServerTimeNow() + (data.Duration or 2)
		end
	end)
end

return HUDScreen
