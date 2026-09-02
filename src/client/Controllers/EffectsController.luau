--!nonstrict
--[[
	EffectsController.luau
	Every piece of visual/audio feedback in the game funnels through here.

	Feedback design rules:
		* Every player action gets a response inside one frame. Silence reads as
		  "the game didn't register that", which is the worst feeling a shooter can
		  produce.
		* Feedback is layered by importance: an elimination is loud, a footstep is
		  nearly subliminal. If everything shouts, nothing communicates.
		* Nothing here EVER moves the camera. Feedback is colour, light, particles
		  and sound. (Camera kick is owned by CameraController and hard-capped.)
		* Effects are budgeted: they self-destruct and the trail pool is bounded,
		  because a 240fps movement shooter that hitches on a teamfight is a 30fps
		  movement shooter.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Palette = require(Root.Config.Palette)
local WeaponConfig = require(Root.Config.WeaponConfig)
local MovementConfig = require(Root.Config.MovementConfig)
local MovementState = require(Root.Shared.MovementState)
local FxLib = require(Root.Util.FxLib)
local Trove = require(Root.Util.Trove)
local Net = require(Root.Util.Net)

local LocalPlayer = Players.LocalPlayer

local EffectsController = {}
EffectsController.__index = EffectsController

-- Budget: how many world effects may exist at once before we start skipping the
-- low-importance ones. Tuned for a 12-player lobby on a mid-range device.
local MAX_ACTIVE_EFFECTS = 140

function EffectsController.new(context)
	local self = setmetatable({}, EffectsController)

	self.context = context
	self._trove = Trove.new()
	self._activeEffects = 0
	self._slideTrailAccumulator = 0
	self._sprintEmitter = nil
	self._overdriveParts = {}

	return self
end

function EffectsController:Start()
	local movement = self.context.Movement

	self._trove:Connect(movement.StateChanged, function(state, previous)
		self:_onStateChanged(state, previous)
	end)

	self._trove:Connect(movement.SlideStarted, function(direction)
		self:_playSound("rbxassetid://9125402735", 0.45, 1.25)
		local root = movement.root
		if root then
			FxLib.groundRing(root.Position - Vector3.new(0, 2.6, 0), Palette.NeonCyan, 5.5, 0.35, 0.25)
		end
		local _ = direction
	end)

	self._trove:Connect(movement.WallJumped, function(position, normal, chain)
		-- The impact ring faces the wall so it reads as "I pushed off THERE",
		-- and brightens with the chain count as a skill readout.
		local intensity = math.min(chain / MovementConfig.Wall.MaxChain, 1)
		FxLib.ring(CFrame.lookAt(position + normal * 0.15, position + normal), Palette.NeonBlue, 4 + intensity * 3, 0.42, 0.3)
		FxLib.burst(position + normal * 0.4, {
			Color = Palette.NeonCyan,
			Secondary = Palette.NeonPurple,
			Count = 16 + math.floor(intensity * 10),
			Speed = 24,
			Life = 0.4,
			Size = 0.45,
			Direction = normal,
			Spread = 55,
		})
		FxLib.flash(position, Palette.NeonBlue, 5, 14, 0.18)
		self:_playSound("rbxassetid://9118823104", 0.5, 1.35)
	end)

	self._trove:Connect(movement.DashStarted, function(direction, config)
		self:_dashEffect(direction, config)
	end)

	self._trove:Connect(movement.Mantled, function(position)
		FxLib.burst(position, {
			Color = Palette.NeonCyan,
			Count = 10,
			Speed = 14,
			Life = 0.3,
			Size = 0.3,
			Direction = Vector3.yAxis,
			Spread = 40,
		})
		self:_playSound("rbxassetid://9114365255", 0.35, 1.1)
	end)

	self._trove:Connect(movement.PadLaunched, function(pad)
		FxLib.groundRing(pad.Position + Vector3.new(0, 0.6, 0), Palette.NeonPurple, 9, 0.5, 0.4)
		self:_playSound("rbxassetid://9118823104", 0.55, 0.85)
	end)

	self._trove:Connect(movement.Landed, function(fallSpeed, horizontal, heavy)
		if heavy or horizontal > MovementConfig.Speed.Sprint then
			local root = movement.root
			if root then
				FxLib.groundRing(
					root.Position - Vector3.new(0, 2.8, 0),
					Palette.NeonBlue,
					heavy and 7 or 4,
					0.32,
					0.2
				)
			end
		end
		local _ = fallSpeed
	end)

	self._trove:Add(RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end))

	-- Other players' effects, relayed by the server.
	self._trove:Add(Net.onClient("EffectBroadcast", function(kind, payload)
		self:_playRemote(kind, payload)
	end))

	return self
end

----------------------------------------------------------------------
-- Movement feedback
----------------------------------------------------------------------

function EffectsController:_onStateChanged(state: string, previous: string)
	local movement = self.context.Movement
	local root = movement.root
	if not root then
		return
	end

	if state == MovementState.Sprint then
		self:_setSprintParticles(true)
	elseif previous == MovementState.Sprint then
		self:_setSprintParticles(false)
	end

	if state == MovementState.Slide then
		self._slideTrail = FxLib.attachTrail(root, Palette.NeonCyan, Palette.NeonPurple, 0.45, 2.6)
	elseif previous == MovementState.Slide and self._slideTrail then
		self._slideTrail.Destroy()
		self._slideTrail = nil
	end

	if state == MovementState.WallSlide then
		self:_playSound("rbxassetid://9114365255", 0.25, 0.9)
	end
end

--[[ Sprint speed particles. Deliberately subtle - they sit in peripheral vision
	 and tell you "you are at top speed" without ever obscuring an enemy. ]]
function EffectsController:_setSprintParticles(enabled: boolean)
	local root = self.context.Movement.root
	if not root then
		return
	end

	if enabled then
		if self._sprintEmitter and self._sprintEmitter.Parent then
			self._sprintEmitter.Enabled = true
			return
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = "HB_SprintFx"
		attachment.Parent = root

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Palette.NeonCyan),
			ColorSequenceKeypoint.new(1, Palette.NeonPurple),
		})
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.22, 0.4)
		emitter.Rate = 26
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Acceleration = Vector3.new(0, 6, 0)
		emitter.Parent = attachment

		self._sprintEmitter = emitter
		self._trove:Add(attachment)
	elseif self._sprintEmitter then
		self._sprintEmitter.Enabled = false
	end
end

function EffectsController:_dashEffect(direction: Vector3, config)
	local root = self.context.Movement.root
	if not root then
		return
	end

	-- Signature cyan-purple burst + trail. This is the game's most-seen effect,
	-- so it gets the most attention: a directional cone, a ring, and a trail that
	-- outlives the dash so the *path* stays readable to everyone watching.
	FxLib.burst(root.Position, {
		Color = config.TrailColor or Palette.NeonCyan,
		Secondary = config.TrailColorSecondary or Palette.NeonPurple,
		Count = config.BurstParticles or 36,
		Speed = 34,
		Life = 0.45,
		Size = 0.55,
		Direction = -direction,
		Spread = 38,
		Acceleration = Vector3.zero,
	})

	FxLib.ring(
		CFrame.lookAt(root.Position, root.Position + direction),
		config.TrailColor or Palette.NeonCyan,
		5,
		0.3,
		0.28
	)
	FxLib.flash(root.Position, config.TrailColor or Palette.NeonCyan, 7, 18, 0.22)

	local trail = FxLib.attachTrail(
		root,
		config.TrailColor or Palette.NeonCyan,
		config.TrailColorSecondary or Palette.NeonPurple,
		config.TrailLife or 0.42,
		3.0
	)
	task.delay(config.Duration + 0.15, function()
		trail.Destroy()
	end)

	local sound = config.Sound
	if sound then
		self:_playSound(sound.Id, sound.Volume, sound.Pitch)
	end
end

function EffectsController:PhaseAfterimages(character: Model, config)
	for index = 1, config.AfterimageCount do
		task.delay((index - 1) * (config.Duration / config.AfterimageCount), function()
			if character.Parent then
				FxLib.afterimage(character, config.TrailColor, config.AfterimageLife)
			end
		end)
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		FxLib.ring(root.CFrame, config.TrailColorSecondary, 6, 0.4, 0.3)
	end

	local sound = config.Sound
	if sound then
		self:_playSound(sound.Id, sound.Volume, sound.Pitch)
	end
end

function EffectsController:OverdriveStart(config, duration: number)
	local character = self.context.Movement.character
	if not character then
		return
	end

	-- The glow is a two-way contract: you get the buff, the enemy gets a target.
	local highlight = Instance.new("Highlight")
	highlight.Name = "HB_Overdrive"
	highlight.FillColor = config.BodyGlow
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = config.BodyGlow
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = character
	table.insert(self._overdriveParts, highlight)

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Parent = root

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(config.BodyGlow)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.35)
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Rate = config.AuraParticles
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = attachment
		table.insert(self._overdriveParts, attachment)
	end

	local sound = config.Sound
	if sound then
		self:_playSound(sound.Id, sound.Volume, sound.Pitch)
	end

	local _ = duration
end

function EffectsController:OverdriveEnd(config)
	for _, instance in self._overdriveParts do
		if instance and instance.Parent then
			instance:Destroy()
		end
	end
	table.clear(self._overdriveParts)

	local sound = config.EndSound
	if sound then
		self:_playSound(sound.Id, sound.Volume, sound.Pitch)
	end
end

----------------------------------------------------------------------
-- Combat feedback
----------------------------------------------------------------------

function EffectsController:MuzzleFlash(position: Vector3, direction: Vector3, definition)
	local muzzle = definition.Muzzle
	if muzzle.Size <= 0 then
		return
	end

	FxLib.burst(position, {
		Color = muzzle.Color,
		Secondary = muzzle.Color,
		Count = math.floor(6 * muzzle.Size),
		Speed = 14 * muzzle.Size,
		Life = 0.12,
		Size = 0.5 * muzzle.Size,
		Direction = direction,
		Spread = 22,
		Acceleration = Vector3.zero,
		Drag = 8,
	})
	FxLib.flash(position, muzzle.Color, muzzle.Light, 10 * muzzle.Size, 0.07)
end

function EffectsController:Tracer(from: Vector3, to: Vector3, definition)
	local tracer = definition.Tracer
	if tracer.Width <= 0 then
		return
	end
	if self._activeEffects > MAX_ACTIVE_EFFECTS then
		return -- budget exceeded: drop the least important thing on screen
	end
	self._activeEffects += 1
	FxLib.beam(from, to, tracer.Color, tracer.Width, tracer.Life)
	task.delay(tracer.Life + 0.1, function()
		self._activeEffects -= 1
	end)
end

function EffectsController:Impact(position: Vector3, normal: Vector3, definition, hitPart: BasePart?)
	FxLib.burst(position, {
		Color = definition.Muzzle.Color,
		Secondary = Palette.NeonPurple,
		Count = 8,
		Speed = 12,
		Life = 0.3,
		Size = 0.28,
		Direction = normal,
		Spread = 45,
	})
	FxLib.flash(position + normal * 0.3, definition.Muzzle.Color, 2.5, 6, 0.1)
	local _ = hitPart
end

function EffectsController:Hitmarker(headshot: boolean, killed: boolean)
	self.context.HUD:ShowHitmarker(headshot, killed)

	if headshot then
		-- Headshots get their own distinct read: a bright hologram chirp, so you
		-- can tell a head hit from a body hit without looking at damage numbers.
		self:_playSound("rbxassetid://9114365255", 0.6, 1.6)
	elseif killed then
		self:_playSound("rbxassetid://9118823104", 0.7, 1.0)
	else
		self:_playSound("rbxassetid://9114365255", 0.4, 1.2)
	end
end

--[[ Headshot world effect: a holographic ring aligned to the shot, distinct from
	 every other impact in the game. ]]
function EffectsController:HeadshotEffect(position: Vector3, direction: Vector3)
	FxLib.ring(CFrame.lookAt(position, position - direction), Palette.State.HitmarkerHeadshot, 2.4, 0.35, 0.16)
	FxLib.burst(position, {
		Color = Palette.State.HitmarkerHeadshot,
		Secondary = Palette.NeonAmber,
		Count = 14,
		Speed = 18,
		Life = 0.35,
		Size = 0.3,
		Direction = -direction,
		Spread = 60,
	})
end

--[[ Elimination burst, skinned to the weapon that got the kill. Same silhouette
	 of feedback every time (burst + ring + light) so it always reads as a kill,
	 but the colour and shape credit the weapon. ]]
function EffectsController:Elimination(position: Vector3, weaponId: string?)
	local definition = weaponId and WeaponConfig.get(weaponId)
	local skin = definition and WeaponConfig.skinFor(definition) or WeaponConfig.Skins.VoltEdge

	FxLib.burst(position, {
		Color = skin.Primary,
		Secondary = skin.Secondary,
		Count = skin.Particles,
		Speed = if skin.Shape == "Scatter" then 44 else 30,
		Life = 0.75,
		Size = if skin.Shape == "Shards" then 0.8 else 0.5,
		Direction = Vector3.yAxis,
		Spread = 180,
	})
	FxLib.groundRing(position, skin.Primary, 8, 0.55, 0.35)
	FxLib.flash(position, skin.Primary, 9, 26, 0.4)

	if skin.Shape == "Beam" then
		FxLib.beam(position, position + Vector3.new(0, 22, 0), skin.Primary, 0.9, 0.4)
	elseif skin.Shape == "Rings" then
		for index = 1, 3 do
			task.delay(index * 0.06, function()
				FxLib.groundRing(position + Vector3.new(0, index * 1.2, 0), skin.Secondary, 6 - index, 0.4, 0.2)
			end)
		end
	end

	self:_playSound("rbxassetid://9118823104", 0.75, 0.9)
end

function EffectsController:MeleeSwing(cframe: CFrame, definition)
	local start = cframe.Position + cframe.LookVector * 2
	FxLib.beam(
		start - cframe.RightVector * 2.5 + cframe.UpVector * 1.2,
		start + cframe.RightVector * 2.5 - cframe.UpVector * 0.8,
		definition.Muzzle.Color,
		0.35,
		0.16
	)
	self:_playSound("rbxassetid://9125402735", 0.4, 1.5)
end

----------------------------------------------------------------------
-- Remote (other players)
----------------------------------------------------------------------

function EffectsController:_playRemote(kind: string, payload)
	if kind == "Dash" then
		FxLib.burst(payload.position, {
			Color = Palette.NeonCyan,
			Secondary = Palette.NeonPurple,
			Count = 24,
			Speed = 30,
			Life = 0.4,
			Size = 0.5,
			Direction = payload.direction or Vector3.yAxis,
			Spread = 45,
		})
	elseif kind == "WallJump" then
		FxLib.ring(
			CFrame.lookAt(payload.position, payload.position + (payload.normal or Vector3.yAxis)),
			Palette.NeonBlue,
			4,
			0.4,
			0.28
		)
	elseif kind == "Phase" then
		FxLib.ring(CFrame.new(payload.from), Palette.NeonPurple, 5, 0.4, 0.3)
		FxLib.ring(CFrame.new(payload.to), Palette.NeonMagenta, 5, 0.4, 0.3)
	elseif kind == "Elimination" then
		self:Elimination(payload.position, payload.weapon)
	elseif kind == "Shot" then
		local definition = WeaponConfig.get(payload.weapon)
		if definition then
			self:MuzzleFlash(payload.origin, payload.direction or Vector3.yAxis, definition)
			if payload.hit then
				self:Tracer(payload.origin, payload.hit, definition)
			end
		end
	elseif kind == "JumpPad" then
		FxLib.groundRing(payload.position, Palette.NeonPurple, 8, 0.45, 0.35)
	end
end

----------------------------------------------------------------------
-- Frame + audio
----------------------------------------------------------------------

function EffectsController:_update(dt: number)
	local movement = self.context.Movement
	local snapshot = movement:GetSnapshot()

	-- Slide floor trail: laid down as discrete glowing segments at a fixed spatial
	-- interval, so the trail length reads as distance travelled, not as frame rate.
	if snapshot.state == MovementState.Slide and movement.root and movement.humanoid then
		self._slideTrailAccumulator += snapshot.horizontalSpeed * dt
		if self._slideTrailAccumulator >= 3.2 then
			self._slideTrailAccumulator = 0
			local root = movement.root
			FxLib.groundTrailSegment(
				root.Position - Vector3.new(0, movement.humanoid.HipHeight + 0.4, 0),
				movement.groundNormal or Vector3.yAxis,
				movement:GetSlideDirection(),
				Palette.NeonCyan,
				0.7
			)
		end
	else
		self._slideTrailAccumulator = 0
	end
end

function EffectsController:_playSound(id: string, volume: number, pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.RollOffMaxDistance = 220
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
	local _ = LocalPlayer
end

function EffectsController:Destroy()
	if self._slideTrail then
		self._slideTrail.Destroy()
	end
	self:OverdriveEnd({ EndSound = nil })
	self._trove:Clean()
end

return EffectsController
