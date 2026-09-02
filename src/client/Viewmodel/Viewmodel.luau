--!nonstrict
--[[
	Viewmodel.luau
	Procedural first-person weapon model + animation rig.

	HYPER BLAST ships with no art dependencies, so every weapon is assembled from
	primitives at runtime using its `Viewmodel` config block, and every animation
	is a CFrame curve rather than an imported clip. That has a real advantage
	beyond "no assets": animation timings are DATA, so reload length and recoil
	kick are tuned in the same table as the damage numbers, and they can never
	drift out of sync with the gameplay timers the way a keyframed clip does.

	Layering (applied in this order, each one a separate offset):
		base grip  ->  ADS blend  ->  sway  ->  bob  ->  recoil  ->  animation
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Spring = require(Root.Util.Spring)
local Trove = require(Root.Util.Trove)

local LocalPlayer = Players.LocalPlayer

local Viewmodel = {}
Viewmodel.__index = Viewmodel

local BODY_COLOR = Color3.fromRGB(28, 28, 42)
local METAL_COLOR = Color3.fromRGB(52, 54, 74)

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function Viewmodel.new()
	local self = setmetatable({}, Viewmodel)

	self._trove = Trove.new()
	self.model = nil :: Model?
	self.root = nil :: BasePart?
	self.muzzle = nil :: Attachment?
	self.definition = nil

	self.swaySpring = Spring.new(Vector2.zero, 3.0, 0.7)
	self.recoilSpring = Spring.new(Vector3.zero, 7.0, 0.55) -- x: kick back, y: rise, z: roll
	self.bobPhase = 0
	self.adsAlpha = 0
	self.animationOffset = CFrame.identity
	self._parts = {}
	self._animationCancel = nil :: (() -> ())?
	self._lastCameraCFrame = CFrame.identity

	return self
end

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------

function Viewmodel:Build(definition)
	self:Clear()
	self.definition = definition

	local spec = definition.Viewmodel
	local model = Instance.new("Model")
	model.Name = `Viewmodel_{definition.Id}`

	local length = spec.Length
	local body = makePart("Body", Vector3.new(0.42, 0.5, length), BODY_COLOR, Enum.Material.Metal)
	body.Anchored = true
	self.root = body

	-- Parts parented to the Camera are rendered but NOT physics-simulated, so
	-- welds would never update. We keep an explicit offset list and drive every
	-- CFrame ourselves each frame - which we need anyway for the animation layers.
	self._parts = {}
	local function attach(part: BasePart, offset: CFrame)
		part.Anchored = true
		part.CFrame = offset
		table.insert(self._parts, { part = part, offset = offset })
		part.Parent = model
	end

	body.Parent = model

	-- Barrel / emitter -------------------------------------------------
	if spec.BarrelLength > 0 then
		local barrel = makePart(
			"Barrel",
			Vector3.new(0.18, 0.18, spec.BarrelLength),
			METAL_COLOR,
			Enum.Material.Metal
		)
		attach(barrel, CFrame.new(0, 0.06, -(length * 0.5 + spec.BarrelLength * 0.5)))
	end

	-- Neon accent strips: the weapon's identity colour, readable in the corner
	-- of the eye without ever covering the crosshair.
	for _, side in { -1, 1 } do
		local accent = makePart("Accent", Vector3.new(0.05, 0.1, length * 0.62), spec.Accent, Enum.Material.Neon)
		attach(accent, CFrame.new(side * 0.22, 0.1, -length * 0.08))
	end

	-- Sight (the thing your eye lines up in ADS) ------------------------
	local sight = makePart("Sight", Vector3.new(0.1, 0.16, 0.1), spec.Accent, Enum.Material.Neon)
	attach(sight, CFrame.new(0, 0.33, -length * 0.28))

	local rearSight = makePart("RearSight", Vector3.new(0.16, 0.1, 0.08), METAL_COLOR, Enum.Material.Metal)
	attach(rearSight, CFrame.new(0, 0.31, length * 0.22))

	-- Magazine: a real, separately-animated part so MagSwap reloads read clearly.
	if spec.ReloadStyle == "MagSwap" then
		local magazine = makePart("Magazine", Vector3.new(0.24, 0.42, 0.34), METAL_COLOR, Enum.Material.Metal)
		magazine.Anchored = true -- animated independently of the body
		magazine.Parent = model
		self.magazine = magazine
		self.magazineOffset = CFrame.new(0, -0.42, length * 0.04)
	elseif spec.ReloadStyle == "BoltCycle" then
		local bolt = makePart("Bolt", Vector3.new(0.2, 0.2, 0.5), METAL_COLOR, Enum.Material.Metal)
		bolt.Anchored = true
		bolt.Parent = model
		self.bolt = bolt
		self.boltOffset = CFrame.new(0.22, 0.16, 0)
	elseif spec.ReloadStyle == "ShellFeed" then
		local pump = makePart("Pump", Vector3.new(0.3, 0.24, 0.5), METAL_COLOR, Enum.Material.Metal)
		pump.Anchored = true
		pump.Parent = model
		self.pump = pump
		self.pumpOffset = CFrame.new(0, -0.12, -length * 0.3)
	end

	-- Grip + stock ------------------------------------------------------
	local grip = makePart("Grip", Vector3.new(0.2, 0.46, 0.24), BODY_COLOR, Enum.Material.Metal)
	attach(grip, CFrame.new(0, -0.36, length * 0.22) * CFrame.Angles(math.rad(-12), 0, 0))

	-- Muzzle attachment: the origin for flashes and tracers.
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.06, -(length * 0.5 + spec.BarrelLength))
	muzzle.Parent = body
	self.muzzle = muzzle

	model.PrimaryPart = body
	model.Parent = workspace.CurrentCamera
	self.model = model

	-- The viewmodel is cosmetic: never let it block a shot or a probe.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
			descendant.CanCollide = false
		end
	end

	return self
end

function Viewmodel:Clear()
	if self._animationCancel then
		self._animationCancel()
		self._animationCancel = nil
	end
	if self.model then
		self.model:Destroy()
	end
	self.model = nil
	self.root = nil
	self._parts = {}
	self.muzzle = nil
	self.magazine = nil
	self.bolt = nil
	self.pump = nil
	self.animationOffset = CFrame.identity
end

----------------------------------------------------------------------
-- Per-frame update
----------------------------------------------------------------------

--[[ `context` = { adsAlpha, moveSpeed, grounded, sprinting, dt } ]]
function Viewmodel:Update(dt: number, context)
	local camera = workspace.CurrentCamera
	if not camera or not self.root or not self.definition then
		return
	end

	local spec = self.definition.Viewmodel
	self.adsAlpha = context.adsAlpha or 0

	-- Sway: the weapon LAGS the camera. Derived from the frame's actual angular
	-- delta so it is framerate-independent and reads as weight, not as latency.
	local delta = self._lastCameraCFrame:ToObjectSpace(camera.CFrame)
	local _, deltaYaw, _ = delta:ToEulerAnglesYXZ()
	local deltaPitch = math.asin(math.clamp(delta.LookVector.Y, -1, 1))
	self._lastCameraCFrame = camera.CFrame

	self.swaySpring:Impulse(Vector2.new(
		math.clamp(-deltaYaw * 42, -12, 12),
		math.clamp(-deltaPitch * 42, -12, 12)
	))
	self.swaySpring:SetTarget(Vector2.zero)
	local sway = self.swaySpring:Update(dt) * (1 - self.adsAlpha * 0.8)

	-- Bob: tied to real movement speed, killed almost entirely while aiming.
	local speedRatio = math.clamp((context.moveSpeed or 0) / 30, 0, 1.6)
	local bobOffset = Vector3.zero
	if context.grounded and speedRatio > 0.05 then
		self.bobPhase += dt * 9.2 * speedRatio
		local amplitude = 0.035 * speedRatio * (1 - self.adsAlpha * 0.92)
		bobOffset = Vector3.new(
			math.cos(self.bobPhase * 0.5) * amplitude * 1.6,
			math.abs(math.sin(self.bobPhase)) * amplitude,
			0
		)
	end

	-- Sprint pose: the weapon tilts out of the sightline while running. It is a
	-- readable "you are not currently able to shoot instantly" signal.
	local sprintBlend = if context.sprinting and self.adsAlpha < 0.05 then 1 else 0
	self._sprintBlend = self._sprintBlend or 0
	self._sprintBlend += (sprintBlend - self._sprintBlend) * math.clamp(dt * 9, 0, 1)

	local recoil = self.recoilSpring:Update(dt)
	self.recoilSpring:SetTarget(Vector3.zero)

	local basePose = CFrame.new(spec.GripOffset)
	local adsPose = CFrame.new(spec.AdsOffset)
	local pose = basePose:Lerp(adsPose, self.adsAlpha)

	local sprintPose = CFrame.new(0.12, -0.12, 0.1)
		* CFrame.Angles(math.rad(-14), math.rad(22), math.rad(-13))

	local final = camera.CFrame
		* pose
		* CFrame.new(bobOffset)
		* CFrame.Angles(math.rad(sway.Y), math.rad(sway.X), math.rad(sway.X * 0.35))
		* sprintPose:Lerp(CFrame.identity, 1 - self._sprintBlend)
		* CFrame.new(0, recoil.Y * 0.35, recoil.X)
		* CFrame.Angles(math.rad(-recoil.Y * 3.4), 0, math.rad(recoil.Z))
		* self.animationOffset

	self.root.CFrame = final

	for _, entry in self._parts do
		entry.part.CFrame = final * entry.offset
	end

	-- Sub-parts that animate independently ride the body.
	if self.magazine then
		self.magazine.CFrame = final * self.magazineOffset * (self._magazineAnim or CFrame.identity)
	end
	if self.bolt then
		self.bolt.CFrame = final * self.boltOffset * (self._boltAnim or CFrame.identity)
	end
	if self.pump then
		self.pump.CFrame = final * self.pumpOffset * (self._pumpAnim or CFrame.identity)
	end
end

----------------------------------------------------------------------
-- Animations (data-driven CFrame curves)
----------------------------------------------------------------------

function Viewmodel:PlayFire()
	local kick = self.definition.VisualKick
	self.recoilSpring:Impulse(Vector3.new(kick.back * 26, kick.up * 26, kick.roll * 2.4))
end

function Viewmodel:_runAnimation(duration: number, step: (number) -> ())
	if self._animationCancel then
		self._animationCancel()
	end

	local RunService = game:GetService("RunService")
	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		step(alpha)
		if alpha >= 1 then
			connection:Disconnect()
			self._animationCancel = nil
			self.animationOffset = CFrame.identity
			self._magazineAnim = nil
			self._boltAnim = nil
			self._pumpAnim = nil
		end
	end)

	self._animationCancel = function()
		if connection.Connected then
			connection:Disconnect()
		end
		self.animationOffset = CFrame.identity
		self._magazineAnim = nil
		self._boltAnim = nil
		self._pumpAnim = nil
	end
end

--[[ Reload. Each style is its own curve, which is what makes every weapon's
	 reload legible at a glance - you can tell what someone is doing from the
	 shape of their hands, not just from a timer. ]]
function Viewmodel:PlayReload(duration: number, empty: boolean)
	local style = self.definition.Viewmodel.ReloadStyle

	if style == "MagSwap" then
		self:_runAnimation(duration, function(alpha)
			-- Tilt down, drop mag, insert new mag, snap back up.
			local tilt = math.sin(math.min(alpha * 2.6, math.pi)) * 0.55
			self.animationOffset = CFrame.new(0, -tilt * 0.28, tilt * 0.1)
				* CFrame.Angles(math.rad(tilt * 32), math.rad(tilt * 14), math.rad(-tilt * 10))

			local magPhase
			if alpha < 0.35 then
				magPhase = alpha / 0.35 -- falling away
				self._magazineAnim = CFrame.new(0, -magPhase * 1.4, 0)
					* CFrame.Angles(math.rad(magPhase * 30), 0, 0)
			elseif alpha < 0.62 then
				self._magazineAnim = CFrame.new(0, -1.6, 0) -- offscreen, swapping
			else
				magPhase = (alpha - 0.62) / 0.38
				self._magazineAnim = CFrame.new(0, -(1 - magPhase) * 1.4, 0)
			end

			-- An empty reload also cycles the bolt at the end: that extra half
			-- second is the cost of running yourself dry, and you can SEE it.
			if empty and alpha > 0.85 then
				local cycle = (alpha - 0.85) / 0.15
				self.animationOffset = self.animationOffset * CFrame.new(0, 0, math.sin(cycle * math.pi) * 0.12)
			end
		end)
	elseif style == "BoltCycle" then
		self:_runAnimation(duration, function(alpha)
			local tilt = math.sin(math.min(alpha * 2.2, math.pi)) * 0.45
			self.animationOffset = CFrame.new(0, -tilt * 0.2, 0)
				* CFrame.Angles(math.rad(tilt * 20), math.rad(-tilt * 26), 0)
			local cycle = math.sin(math.clamp(alpha, 0, 1) * math.pi * 2)
			self._boltAnim = CFrame.new(0, 0, math.max(cycle, 0) * 0.42)
		end)
	elseif style == "ShellFeed" then
		self:_runAnimation(duration, function(alpha)
			-- One visible pump per shell. Cancellable mid-way by the controller.
			local shells = 4
			local phase = (alpha * shells) % 1
			local tilt = 0.4
			self.animationOffset = CFrame.new(0, -0.12, 0)
				* CFrame.Angles(math.rad(tilt * 18), math.rad(tilt * 20), 0)
			self._pumpAnim = CFrame.new(0, 0, math.sin(phase * math.pi) * 0.34)
		end)
	else
		self:_runAnimation(duration, function(alpha)
			local tilt = math.sin(alpha * math.pi) * 0.5
			self.animationOffset = CFrame.Angles(math.rad(tilt * 24), 0, math.rad(tilt * 18))
		end)
	end
end

--[[ Inspect. Pure flourish, fully cancellable by firing - a cosmetic animation
	 must never cost you a duel. ]]
function Viewmodel:PlayInspect(duration: number)
	self:_runAnimation(duration, function(alpha)
		local turn = math.sin(alpha * math.pi)
		self.animationOffset = CFrame.new(-turn * 0.22, turn * 0.1, turn * 0.34)
			* CFrame.Angles(
				math.rad(turn * 18),
				math.rad(math.sin(alpha * math.pi * 2) * 78),
				math.rad(turn * 26)
			)
	end)
end

function Viewmodel:PlayEquip(duration: number)
	self:_runAnimation(duration, function(alpha)
		local eased = 1 - (1 - alpha) ^ 3
		self.animationOffset = CFrame.new(0, -(1 - eased) * 1.1, (1 - eased) * 0.3)
			* CFrame.Angles(math.rad(-(1 - eased) * 52), 0, math.rad((1 - eased) * 22))
	end)
end

function Viewmodel:CancelAnimation()
	if self._animationCancel then
		self._animationCancel()
		self._animationCancel = nil
	end
end

function Viewmodel:GetMuzzlePosition(): Vector3
	if self.muzzle then
		return self.muzzle.WorldPosition
	end
	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position or Vector3.zero
end

function Viewmodel:SetVisible(visible: boolean)
	if not self.model then
		return
	end
	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = visible and 0 or 1
		end
	end
end

function Viewmodel:Destroy()
	self:Clear()
	self._trove:Clean()
	local _ = LocalPlayer
end

return Viewmodel
