--!nonstrict
--[[
	HUDController.luau
	Drives the HUD built by UI/HudBuilder.

	Update policy: the HUD is refreshed from a single Heartbeat, and every element
	writes only when its value CHANGED. A HUD that rebuilds instances every frame
	is the easiest way to turn a 240fps shooter into a 90fps one.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Palette = require(Root.Config.Palette)
local CombatConfig = require(Root.Config.CombatConfig)
local MovementConfig = require(Root.Config.MovementConfig)
local ArenaConfig = require(Root.Config.ArenaConfig)
local Trove = require(Root.Util.Trove)
local Net = require(Root.Util.Net)
local HudBuilder = require(script.Parent.Parent.UI.HudBuilder)

local LocalPlayer = Players.LocalPlayer

local HUDController = {}
HUDController.__index = HUDController

local MINIMAP_RANGE = 190 -- studs of world shown across the minimap

function HUDController.new(context)
	local self = setmetatable({}, HUDController)

	self.context = context
	self._trove = Trove.new()

	self.refs = nil
	self.crosshairSpread = 0
	self.adsAlpha = 0
	self.hitmarkerUntil = 0
	self.reloadStart = 0
	self.reloadDuration = 0
	self.reloading = false
	self.matchState = nil
	self.arena = ArenaConfig.get(ArenaConfig.Default)
	self.minimapDots = {}
	self.overdriveUntil = 0
	self._lastHealth = -1
	self._lastAmmo = -1

	return self
end

function HUDController:Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	self.refs = HudBuilder.build(playerGui)
	self._trove:Add(self.refs.Gui)

	self._trove:Add(RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(self._update, self, dt)
		if not ok then
			warn(`[HUD] update error: {err}`)
		end
	end))

	self._trove:Connect(self.context.Input.ActionPressed, function(action)
		if action == "Scoreboard" then
			self:SetScoreboardVisible(true)
		end
	end)
	self._trove:Connect(self.context.Input.ActionReleased, function(action)
		if action == "Scoreboard" then
			self:SetScoreboardVisible(false)
		end
	end)

	self._trove:Add(Net.onClient("MatchState", function(state)
		self:SetMatchState(state)
	end))

	self._trove:Add(Net.onClient("KillFeed", function(entry)
		self:PushKillFeed(entry)
	end))

	self._trove:Add(Net.onClient("Announce", function(text, duration, color)
		self:Announce(text, duration, color)
	end))

	self._trove:Add(Net.onClient("ObjectiveState", function(state)
		self:SetObjectiveState(state)
	end))

	self._trove:Add(Net.onClient("DamageTaken", function(payload)
		self:ShowDamageIndicator(payload.from, payload.damage)
	end))

	self._trove:Add(Net.onClient("PlayerEliminated", function(payload)
		self:ShowDeathOverlay(payload)
	end))

	return self
end

----------------------------------------------------------------------
-- Weapon / ammo
----------------------------------------------------------------------

function HUDController:SetWeapon(definition, ammo)
	local refs = self.refs
	if not refs or not definition then
		return
	end

	refs.WeaponText.Text = definition.DisplayName
	refs.WeaponText.TextColor3 = definition.Muzzle.Color

	if definition.FireMode == "Melee" then
		refs.AmmoText.Text = "--"
		refs.ReserveText.Text = ""
		return
	end

	if ammo then
		refs.AmmoText.Text = tostring(ammo.mag)
		refs.ReserveText.Text = `/ {ammo.reserve}`
		-- The ammo counter turns amber below a third of a magazine. You should be
		-- able to know you're low without reading a number mid-fight.
		local low = ammo.mag <= math.max(1, math.floor(definition.MagSize / 3))
		refs.AmmoText.TextColor3 = low and Palette.NeonAmber or Color3.new(1, 1, 1)
	end
end

function HUDController:SetReloading(reloading: boolean, duration: number)
	self.reloading = reloading
	self.reloadStart = os.clock()
	self.reloadDuration = duration
	if self.refs then
		self.refs.ReloadBar.Visible = reloading
	end
end

function HUDController:SetCrosshairSpread(spread: number, adsAlpha: number)
	self.crosshairSpread = spread
	self.adsAlpha = adsAlpha
end

----------------------------------------------------------------------
-- Combat feedback
----------------------------------------------------------------------

function HUDController:ShowHitmarker(headshot: boolean, killed: boolean)
	local refs = self.refs
	if not refs then
		return
	end

	local color = if killed
		then Palette.State.HitmarkerKill
		elseif headshot then Palette.State.HitmarkerHeadshot
		else Palette.State.Hitmarker

	local life = if killed
		then CombatConfig.Feedback.KillMarkerTime
		elseif headshot then CombatConfig.Feedback.HeadshotHitmarkerTime
		else CombatConfig.Feedback.HitmarkerTime

	for _, stroke in refs.HitmarkerStrokes do
		stroke.BackgroundColor3 = color
		stroke.Size = UDim2.fromOffset(killed and 3 or 2, headshot and 13 or 10)
	end

	refs.Hitmarker.Visible = true
	self.hitmarkerUntil = os.clock() + life
end

function HUDController:PushDamageNumber(damage: number, headshot: boolean, position: Vector3?)
	local refs = self.refs
	local camera = workspace.CurrentCamera
	if not refs or not camera or not position then
		return
	end

	local screenPoint, onScreen = camera:WorldToViewportPoint(position)
	if not onScreen then
		return
	end

	local text = HudBuilder.label({
		Name = "DamageNumber",
		Text = tostring(damage),
		TextSize = headshot and 26 or 20,
		TextColor3 = headshot and Palette.State.HitmarkerHeadshot or Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(80, 24),
		Position = UDim2.fromOffset(screenPoint.X - 40, screenPoint.Y - 12),
		ZIndex = 12,
	})
	text.Parent = refs.DamageNumbers

	local life = CombatConfig.Feedback.DamageNumberLife
	TweenService:Create(text, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(
			screenPoint.X - 40 + math.random(-12, 12),
			screenPoint.Y - 12 - CombatConfig.Feedback.DamageNumberRise * 14
		),
		TextTransparency = 1,
	}):Play()
	Debris:AddItem(text, life + 0.1)
end

--[[ Directional "you were shot from there" arc. Drawn as a rotated tick around
	 the crosshair; the player should be able to turn toward a threat without
	 reading anything. ]]
function HUDController:ShowDamageIndicator(from: Vector3?, damage: number)
	local refs = self.refs
	local camera = workspace.CurrentCamera
	if not refs or not camera or not from then
		return
	end

	local look = camera.CFrame.LookVector
	local toSource = (from - camera.CFrame.Position)
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatSource = Vector3.new(toSource.X, 0, toSource.Z)
	if flatLook.Magnitude < 1e-3 or flatSource.Magnitude < 1e-3 then
		return
	end

	local angle = math.atan2(flatSource.Unit:Cross(flatLook.Unit).Y, flatSource.Unit:Dot(flatLook.Unit))
	local degrees = math.deg(angle)

	local indicator = HudBuilder.new("Frame", {
		Name = "DamageIndicator",
		Size = UDim2.fromOffset(60, 5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(
			0.5,
			math.sin(math.rad(degrees)) * 130,
			0.5,
			-math.cos(math.rad(degrees)) * 130
		),
		Rotation = degrees,
		BackgroundColor3 = Palette.State.HealthLow,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 8,
	})
	indicator.Parent = refs.DamageIndicators

	local life = CombatConfig.Feedback.DamageIndicatorLife
	TweenService:Create(indicator, TweenInfo.new(life, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(indicator, life + 0.1)

	local _ = damage
end

----------------------------------------------------------------------
-- Abilities
----------------------------------------------------------------------

function HUDController:FlashAbilityDenied(id: string)
	local slot = self.refs and self.refs.AbilitySlots[id]
	if not slot then
		return
	end
	slot.stroke.Color = Palette.State.HealthLow
	task.delay(0.18, function()
		slot.stroke.Color = slot.color
	end)
end

function HUDController:FlashAbilityReady(id: string)
	local slot = self.refs and self.refs.AbilitySlots[id]
	if not slot then
		return
	end
	slot.stroke.Transparency = 0
	slot.stroke.Thickness = 2.5
	TweenService:Create(slot.stroke, TweenInfo.new(0.35), { Thickness = 1.5, Transparency = 0.2 }):Play()
end

function HUDController:SetOverdrive(active: boolean, duration: number)
	self.overdriveUntil = active and (os.clock() + duration) or 0
end

----------------------------------------------------------------------
-- Match / objectives / feed
----------------------------------------------------------------------

function HUDController:SetMatchState(state)
	self.matchState = state
	local refs = self.refs
	if not refs or not state then
		return
	end

	refs.ModeText.Text = state.modeName or ""
	refs.ScoreLeft.Text = tostring(state.scores and state.scores.Cyan or 0)
	refs.ScoreRight.Text = tostring(state.scores and state.scores.Magenta or 0)

	if state.arena then
		self.arena = ArenaConfig.get(state.arena)
	end
end

function HUDController:SetObjectiveState(state)
	local refs = self.refs
	if not refs then
		return
	end

	for _, child in refs.ObjectiveStrip:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for order, zone in state.zones or {} do
		local owner = zone.owner and Palette.Teams[zone.owner]
		local chip = HudBuilder.new("Frame", {
			Name = zone.id,
			Size = UDim2.fromOffset(52, 22),
			LayoutOrder = order,
			BackgroundColor3 = owner and owner.Color or Color3.fromRGB(40, 40, 60),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
		})
		HudBuilder.new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = chip })

		local text = HudBuilder.label({
			Text = zone.id,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Color3.new(1, 1, 1),
		})
		text.Parent = chip

		-- Capture progress fills the chip from the left while it's being taken.
		if zone.progress and zone.progress > 0 and zone.progress < 1 then
			local fill = HudBuilder.new("Frame", {
				Size = UDim2.fromScale(zone.progress, 1),
				BackgroundColor3 = zone.capturingTeam and Palette.Teams[zone.capturingTeam].Color or Color3.new(1, 1, 1),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ZIndex = 0,
			})
			fill.Parent = chip
		end

		chip.Parent = refs.ObjectiveStrip
	end

	if state.core then
		local chip = HudBuilder.new("Frame", {
			Name = "Core",
			Size = UDim2.fromOffset(120, 22),
			LayoutOrder = 99,
			BackgroundColor3 = Palette.State.Objective,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		})
		HudBuilder.new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = chip })
		local text = HudBuilder.label({
			Text = state.core.carrier and `CORE: {state.core.carrier}` or "CORE LOOSE",
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		text.Parent = chip
		chip.Parent = refs.ObjectiveStrip
	end
end

function HUDController:PushKillFeed(entry)
	local refs = self.refs
	if not refs then
		return
	end

	local children = refs.KillFeed:GetChildren()
	local count = 0
	for _, child in children do
		if child:IsA("GuiObject") then
			count += 1
		end
	end
	if count >= CombatConfig.Feedback.KillFeedMax then
		for _, child in children do
			if child:IsA("GuiObject") then
				child:Destroy()
				break
			end
		end
	end

	local row = HudBuilder.new("Frame", {
		Name = "Entry",
		Size = UDim2.fromOffset(330, 22),
		BackgroundColor3 = Color3.fromRGB(8, 8, 16),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = os.clock() * 1000 // 1,
	})
	HudBuilder.new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = row })

	local involvesMe = entry.killer == LocalPlayer.Name or entry.victim == LocalPlayer.Name
	local text = HudBuilder.label({
		Text = `{entry.killer}  ›  {entry.weapon or ""}  ›  {entry.victim}{entry.headshot and "  ⌖" or ""}`,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(5, 0),
		TextColor3 = involvesMe and Palette.NeonCyan or Color3.fromRGB(210, 214, 235),
	})
	text.Parent = row
	row.Parent = refs.KillFeed

	Debris:AddItem(row, CombatConfig.Feedback.KillFeedLife)
end

function HUDController:Announce(text: string, duration: number?, color: Color3?)
	local refs = self.refs
	if not refs then
		return
	end

	refs.Announce.Text = text
	refs.Announce.TextColor3 = color or Palette.NeonCyan
	refs.Announce.TextTransparency = 0

	TweenService:Create(
		refs.Announce,
		TweenInfo.new(duration or 2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	):Play()
end

function HUDController:ShowDeathOverlay(payload)
	local refs = self.refs
	if not refs then
		return
	end

	refs.DeathOverlay.Visible = true
	refs.DeathOverlay.BackgroundTransparency = 0.45
	local killer = payload and payload.killer or "the arena"
	refs.DeathText.Text = `ELIMINATED BY {string.upper(killer)}`

	local respawnIn = payload and payload.respawnIn or CombatConfig.Elimination.RespawnDelay
	task.spawn(function()
		local deadline = os.clock() + respawnIn
		while os.clock() < deadline and refs.DeathOverlay.Visible do
			refs.DeathText.Text =
				`ELIMINATED BY {string.upper(killer)}   —   RESPAWN {string.format("%.1f", deadline - os.clock())}`
			task.wait(0.05)
		end
		refs.DeathOverlay.Visible = false
	end)
end

function HUDController:HideDeathOverlay()
	if self.refs then
		self.refs.DeathOverlay.Visible = false
	end
end

function HUDController:SetScoreboardVisible(visible: boolean)
	local refs = self.refs
	if not refs then
		return
	end
	refs.Scoreboard.Visible = visible
	if visible then
		self:_rebuildScoreboard()
	end
end

function HUDController:_rebuildScoreboard()
	local refs = self.refs
	for _, child in refs.ScoreboardList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		local aScore = a:GetAttribute("HB_Score") or 0
		local bScore = b:GetAttribute("HB_Score") or 0
		return aScore > bScore
	end)

	for order, player in players do
		local teamColor = player.Team and Palette.forTeam(player.Team).Color or Color3.new(1, 1, 1)
		local row = HudBuilder.new("Frame", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Color3.fromRGB(14, 14, 26),
			BackgroundTransparency = player == LocalPlayer and 0.1 or 0.5,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 31,
		})
		HudBuilder.new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = row })

		local name = HudBuilder.label({
			Text = player.Name,
			TextSize = 15,
			TextColor3 = teamColor,
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			ZIndex = 32,
		})
		name.Parent = row

		local stats = HudBuilder.label({
			Text = string.format(
				"%d  /  %d  /  %d",
				player:GetAttribute("HB_Kills") or 0,
				player:GetAttribute("HB_Deaths") or 0,
				player:GetAttribute("HB_Score") or 0
			),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.45, -12, 1, 0),
			Position = UDim2.new(0.55, 0, 0, 0),
			ZIndex = 32,
		})
		stats.Parent = row

		row.Parent = refs.ScoreboardList
	end
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------

function HUDController:_update(dt: number)
	local refs = self.refs
	if not refs then
		return
	end

	local movement = self.context.Movement
	local snapshot = movement:GetSnapshot()
	local humanoid = movement.humanoid

	-- Crosshair ---------------------------------------------------------
	-- Gap is a direct function of the live cone, so the crosshair never lies.
	local gap = 4 + self.crosshairSpread * 3.4
	gap *= 1 - self.adsAlpha * 0.85
	for _, tick in refs.CrosshairTicks do
		tick.frame.Position = UDim2.new(0.5, tick.axis.X * gap, 0.5, tick.axis.Y * gap)
	end
	refs.CrosshairDot.BackgroundTransparency = self.adsAlpha * 0.9

	-- Hitmarker ---------------------------------------------------------
	if refs.Hitmarker.Visible and os.clock() > self.hitmarkerUntil then
		refs.Hitmarker.Visible = false
	end

	-- Health ------------------------------------------------------------
	if humanoid then
		local health = math.floor(humanoid.Health + 0.5)
		if health ~= self._lastHealth then
			self._lastHealth = health
			local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			refs.HealthText.Text = tostring(health)
			refs.HealthFill.Size = UDim2.fromScale(ratio, 1)

			local low = humanoid.Health <= CombatConfig.Health.LowHealthThreshold
			local color = low and Palette.State.HealthLow or Palette.State.Health
			refs.HealthText.TextColor3 = color
			refs.HealthFill.BackgroundColor3 = color
		end

		-- Low-health vignette pulses, but gently: a warning, not a jump scare.
		local critical = humanoid.Health <= CombatConfig.Health.CriticalHealthThreshold
		local low = humanoid.Health <= CombatConfig.Health.LowHealthThreshold
		if low and humanoid.Health > 0 then
			local pulse = 0.82 + math.sin(os.clock() * (critical and 7 or 4)) * 0.06
			refs.Vignette.BackgroundTransparency = pulse
		else
			refs.Vignette.BackgroundTransparency = 1
		end
	end

	-- Stamina + momentum -------------------------------------------------
	refs.StaminaFill.Size = UDim2.fromScale(snapshot.stamina / MovementConfig.Stamina.Max, 1)
	refs.StaminaFill.BackgroundColor3 = snapshot.exhausted and Palette.State.StaminaDrained or Palette.State.Stamina

	local momentumRatio = math.clamp(
		(snapshot.horizontalSpeed - MovementConfig.Speed.Walk)
			/ (MovementConfig.Speed.MaxMomentum - MovementConfig.Speed.Walk),
		0,
		1
	)
	refs.MomentumFill.Size = UDim2.fromScale(momentumRatio, 1)
	refs.SpeedText.Text = string.format("%d", snapshot.horizontalSpeed)
	refs.SpeedText.TextTransparency = 1 - math.clamp(momentumRatio * 1.6, 0.1, 1)

	-- Reload -------------------------------------------------------------
	if self.reloading and self.reloadDuration > 0 then
		local alpha = math.clamp((os.clock() - self.reloadStart) / self.reloadDuration, 0, 1)
		refs.ReloadFill.Size = UDim2.fromScale(alpha, 1)
	end

	-- Abilities ----------------------------------------------------------
	local ability = self.context.Ability
	if ability then
		for id, slot in refs.AbilitySlots do
			local state = ability:GetState(id)
			if state then
				local alpha = ability:GetCooldownAlpha(id)
				slot.shade.Size = UDim2.fromScale(1, 1 - alpha)
				slot.charges.Text = state.maxCharges > 1 and tostring(state.charges) or ""
				local ready = state.charges > 0 and state.enabled
				slot.stroke.Transparency = ready and 0.15 or 0.7
				slot.frame.BackgroundTransparency = ready and 0.15 or 0.45
			end
		end
	end

	-- Match timer --------------------------------------------------------
	if self.matchState and self.matchState.endsAt then
		local remaining = math.max(self.matchState.endsAt - workspace:GetServerTimeNow(), 0)
		refs.TimerText.Text = string.format("%d:%02d", remaining // 60, remaining % 60)
		refs.TimerText.TextColor3 = remaining <= 30 and Palette.NeonAmber or Color3.new(1, 1, 1)
	end

	self:_updateMinimap()
	local _ = dt
end

--[[ Minimap: a rotating 2D radar. It draws arena furniture from ArenaConfig (not
	 from the live workspace) so it costs nothing to render, plus live dots for
	 teammates and objectives. Enemies are NOT drawn - map awareness is earned. ]]
function HUDController:_updateMinimap()
	local refs = self.refs
	local camera = workspace.CurrentCamera
	local root = self.context.Movement.root
	if not camera or not root then
		return
	end

	local origin = root.Position
	local look = camera.CFrame.LookVector
	local yaw = math.atan2(look.X, look.Z)
	local cos, sin = math.cos(-yaw), math.sin(-yaw)
	local mapSize = refs.Minimap.AbsoluteSize.X
	local scale = mapSize / MINIMAP_RANGE

	local function project(position: Vector3): (UDim2, boolean)
		local dx, dz = position.X - origin.X, position.Z - origin.Z
		local rx = dx * cos - dz * sin
		local rz = dx * sin + dz * cos
		local px = mapSize * 0.5 + rx * scale
		local py = mapSize * 0.5 + rz * scale
		local inside = px >= -8 and px <= mapSize + 8 and py >= -8 and py <= mapSize + 8
		return UDim2.fromOffset(px, py), inside
	end

	local used = {}

	local function dot(key: string, position: Vector3, color: Color3, size: number)
		local point, inside = project(position)
		local frame = self.minimapDots[key]
		if not frame or not frame.Parent then
			frame = HudBuilder.new("Frame", {
				Name = key,
				Size = UDim2.fromOffset(size, size),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 4,
			})
			HudBuilder.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
			frame.Parent = refs.MinimapWorld
			self.minimapDots[key] = frame
		end
		frame.Position = point
		frame.Visible = inside
		frame.BackgroundColor3 = color
		used[key] = true
	end

	-- Teammates
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player.Team == LocalPlayer.Team then
			local character = player.Character
			local otherRoot = character and character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				dot(`ally_{player.UserId}`, otherRoot.Position, Palette.forTeam(player.Team).Color, 6)
			end
		end
	end

	-- Objectives
	for _, zone in self.arena.ControlZones or {} do
		dot(`zone_{zone.id}`, zone.position, Palette.State.Objective, 9)
	end

	-- Jump pads: the movement routes belong on the map, because routing IS the
	-- game. A player should be able to plan a rotation from the minimap alone.
	for index, pad in self.arena.JumpPads or {} do
		dot(`pad_{index}`, pad.position, Palette.NeonBlue, 4)
	end

	for key, frame in self.minimapDots do
		if not used[key] then
			frame:Destroy()
			self.minimapDots[key] = nil
		end
	end
end

function HUDController:SetVisible(visible: boolean)
	if self.refs then
		self.refs.Gui.Enabled = visible
	end
end

function HUDController:Destroy()
	self._trove:Clean()
end

return HUDController
