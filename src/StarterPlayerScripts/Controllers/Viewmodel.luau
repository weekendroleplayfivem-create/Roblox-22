--[[
	Viewmodel
	First-person weapon. The model comes from Shared/Modules/WeaponModelBuilder
	(PLACEHOLDER procedural kits) unless a real model exists in
	ReplicatedStorage/Assets/Viewmodels/<WeaponId> (Model with a PrimaryPart and
	an Attachment named "Muzzle").

	All animation is procedural (no animation assets needed):
	  equip swing-in, recoil kick, sway, walk bob, sprint pose, slide tilt,
	  aim-down-sights, landing dip, magazine-out/in reload, inspect spin,
	  charge glow + shake, neon flash on every shot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Spring = require(Shared.Modules.Spring)
local MathUtil = require(Shared.Modules.MathUtil)
local WeaponModelBuilder = require(Shared.Modules.WeaponModelBuilder)

local Viewmodel = {}
Viewmodel.__index = Viewmodel

local HIP_OFFSET = CFrame.new(0.85, -0.82, -1.45)
local ADS_OFFSET = CFrame.new(0, -0.43, -1.05)
local SPRINT_POSE = CFrame.new(-0.15, -0.25, 0.15) * CFrame.Angles(math.rad(-18), math.rad(38), math.rad(22))
local SLIDE_POSE = CFrame.new(-0.1, 0.05, 0) * CFrame.Angles(0, 0, math.rad(-14))
local EQUIP_DROP = CFrame.new(0.1, -1.3, 0.5) * CFrame.Angles(math.rad(-65), math.rad(20), math.rad(-25))
local RELOAD_TILT = CFrame.new(0.05, -0.15, 0.1) * CFrame.Angles(math.rad(-12), math.rad(-8), math.rad(32))
local MAG_DROP = CFrame.new(0, -0.9, 0.15) * CFrame.Angles(math.rad(-25), 0, 0)
local INSPECT_TIME = 2.2
local FLASH_TIME = 0.06

local function prepare(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
end

function Viewmodel.new(weapon, skin)
	local self = setmetatable({}, Viewmodel)
	self.Weapon = weapon
	local camera = workspace.CurrentCamera

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Viewmodels")
	local template = folder and folder:FindFirstChild(weapon.Id)
	local model: Model
	if template and template:IsA("Model") and template.PrimaryPart then
		model = template:Clone()
		prepare(model)
		local primary = model.PrimaryPart :: BasePart
		local muzzle = model:FindFirstChild("Muzzle", true)
		self.MuzzleOffset = if muzzle and muzzle:IsA("Attachment")
			then primary.CFrame:ToObjectSpace(muzzle.WorldCFrame)
			else CFrame.new(0, 0, -2)
		self.Glow = {}
		self.Magazine = nil
	else
		local info
		model, info = WeaponModelBuilder.Build(weapon, { Skin = skin, Anchored = true })
		self.MuzzleOffset = info.Muzzle
		self.Glow = info.Glow
		self.Magazine = info.Magazine
		self.MagazineRest = info.MagazineRest
	end
	self.GlowColors = {}
	for index, part in self.Glow do
		self.GlowColors[index] = part.Color
	end

	-- Muzzle light used for flashes.
	local light = Instance.new("PointLight")
	light.Color = weapon.TracerColor
	light.Range = 10
	light.Brightness = 0
	light.Shadows = false
	light.Parent = model.PrimaryPart
	self.Light = light

	model.Name = "Viewmodel"
	model.Parent = camera
	self.Model = model

	self.AimAlpha = 0
	self.SprintAlpha = 0
	self.SlideAlpha = 0
	self.EquipStart = os.clock()
	self.EquipTime = math.max(weapon.EquipTime, 0.12)
	self.ReloadStart = 0
	self.ReloadTime = 0
	self.InspectStart = -100
	self.FlashUntil = 0
	self.Charge = 0
	self.Visible = true
	self.KickSpring = Spring.new(Vector3.zero, 280, 22)
	self.SwaySpring = Spring.new(Vector3.zero, 120, 14)
	self.ImpulseSpring = Spring.new(Vector3.zero, 160, 14)
	self.BobTime = 0
	self.CurrentCFrame = CFrame.identity
	return self
end

function Viewmodel:Kick(strength: number)
	self.KickSpring:Impulse(Vector3.new(math.rad(4) * strength, (math.random() - 0.5) * 0.03 * strength, 0.2 * strength) * 20)
	self.FlashUntil = os.clock() + FLASH_TIME
	self.InspectStart = -100
end

-- Generic positional bump (landing, damage).
function Viewmodel:Impulse(offset: Vector3)
	self.ImpulseSpring:Impulse(offset * 20)
end

function Viewmodel:PlayReload(duration: number)
	self.ReloadStart = os.clock()
	self.ReloadTime = duration
	self.InspectStart = -100
end

function Viewmodel:CancelReload()
	self.ReloadTime = 0
end

function Viewmodel:Inspect()
	if self.ReloadTime == 0 then
		self.InspectStart = os.clock()
	end
end

function Viewmodel:IsBusy(): boolean
	return self.ReloadTime > 0 or os.clock() - self.InspectStart < INSPECT_TIME
end

function Viewmodel:SetCharge(charge: number)
	self.Charge = charge
end

function Viewmodel:SetVisible(visible: boolean)
	if self.Visible == visible then
		return
	end
	self.Visible = visible
	for _, part in self.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
	self.Light.Enabled = visible
end

function Viewmodel:GetMuzzlePosition(): Vector3
	return (self.CurrentCFrame * self.MuzzleOffset).Position
end

function Viewmodel:GetMuzzleCFrame(): CFrame
	return self.CurrentCFrame * self.MuzzleOffset
end

local function smoothstep(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

-- Called every render frame after the camera has updated.
-- `pose` = { Aiming, Speed, Grounded, Sprinting, Sliding }
function Viewmodel:Update(deltaTime: number, pose)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local damp = MathUtil.Damp(14, deltaTime)
	self.AimAlpha = MathUtil.Lerp(self.AimAlpha, if pose.Aiming then 1 else 0, MathUtil.Damp(18, deltaTime))
	self.SprintAlpha = MathUtil.Lerp(self.SprintAlpha, if pose.Sprinting and not pose.Aiming then 1 else 0, damp)
	self.SlideAlpha = MathUtil.Lerp(self.SlideAlpha, if pose.Sliding then 1 else 0, damp)

	-- Sway from mouse movement (reduced while aiming).
	local mouseDelta = UserInputService:GetMouseDelta()
	self.SwaySpring.Target = Vector3.new(-mouseDelta.Y, -mouseDelta.X, mouseDelta.X * 0.5) * 0.0025 * (1 - self.AimAlpha * 0.85)
	local sway = self.SwaySpring:Update(deltaTime)

	-- Walk / sprint bob (figure-eight).
	local bob = CFrame.identity
	if pose.Grounded and pose.Speed > 2 and not pose.Sliding then
		self.BobTime += deltaTime * (5 + pose.Speed * 0.3)
		local intensity = math.clamp(pose.Speed / 24, 0, 1.3) * (1 - self.AimAlpha * 0.85)
		bob = CFrame.new(math.sin(self.BobTime) * 0.04 * intensity, -math.abs(math.cos(self.BobTime)) * 0.045 * intensity, 0)
			* CFrame.Angles(0, 0, math.sin(self.BobTime) * 0.02 * intensity)
	else
		-- Idle breathing.
		bob = CFrame.new(0, math.sin(now * 1.6) * 0.006, 0)
	end

	self.KickSpring.Target = Vector3.zero
	local kick = self.KickSpring:Update(deltaTime)
	self.ImpulseSpring.Target = Vector3.zero
	local impulse = self.ImpulseSpring:Update(deltaTime)

	local equipAlpha = smoothstep((now - self.EquipStart) / self.EquipTime)
	local equipOffset = EQUIP_DROP:Lerp(CFrame.identity, equipAlpha)

	-- Reload: tilt in, magazine out, magazine in, settle.
	local reloadOffset = CFrame.identity
	local magazineOffset = CFrame.identity
	if self.ReloadTime > 0 then
		local alpha = (now - self.ReloadStart) / self.ReloadTime
		if alpha >= 1 then
			self.ReloadTime = 0
		else
			local tilt = smoothstep(math.min(alpha / 0.15, 1)) * (1 - smoothstep((alpha - 0.8) / 0.2))
			reloadOffset = CFrame.identity:Lerp(RELOAD_TILT, tilt)
			if alpha > 0.15 and alpha < 0.45 then
				magazineOffset = CFrame.identity:Lerp(MAG_DROP, smoothstep((alpha - 0.15) / 0.3))
			elseif alpha >= 0.45 and alpha < 0.7 then
				magazineOffset = MAG_DROP:Lerp(CFrame.identity, smoothstep((alpha - 0.45) / 0.25))
			end
			if alpha > 0.7 and alpha < 0.75 then
				-- "Clack" as the magazine seats.
				self.KickSpring:Impulse(Vector3.new(-0.02, 0, 0.04))
			end
		end
	end

	-- Inspect: tilt the weapon to show off its side, then spin back.
	local inspectOffset = CFrame.identity
	local inspectAlpha = (now - self.InspectStart) / INSPECT_TIME
	if inspectAlpha >= 0 and inspectAlpha < 1 and not pose.Aiming then
		local show = smoothstep(inspectAlpha / 0.25) * (1 - smoothstep((inspectAlpha - 0.75) / 0.25))
		local spin = math.sin(inspectAlpha * math.pi) * math.rad(25)
		inspectOffset = CFrame.new(-0.35 * show, 0.15 * show, 0.1 * show) * CFrame.Angles(math.rad(10) * show, math.rad(70) * show + spin, math.rad(-25) * show)
	end

	-- Charge: shake + glow toward white.
	local chargeShake = CFrame.identity
	if self.Charge > 0 then
		local amount = self.Charge * 0.012
		chargeShake = CFrame.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
	end
	local flash = if now < self.FlashUntil then 1 else 0
	local glowAlpha = math.max(self.Charge * 0.8, flash * 0.6)
	for index, part in self.Glow do
		part.Color = self.GlowColors[index]:Lerp(Color3.new(1, 1, 1), glowAlpha)
	end
	self.Light.Brightness = flash * 6 + self.Charge * 2

	local base = HIP_OFFSET:Lerp(ADS_OFFSET, self.AimAlpha)
	local final = camera.CFrame
		* base
		* CFrame.identity:Lerp(SPRINT_POSE, self.SprintAlpha)
		* CFrame.identity:Lerp(SLIDE_POSE, self.SlideAlpha)
		* CFrame.Angles(sway.X, sway.Y, sway.Z)
		* bob
		* CFrame.new(impulse)
		* equipOffset
		* reloadOffset
		* inspectOffset
		* chargeShake
		* CFrame.new(0, 0, kick.Z)
		* CFrame.Angles(kick.X, kick.Y, 0)
	self.CurrentCFrame = final
	self.Model:PivotTo(final)
	if self.Magazine and self.MagazineRest then
		self.Magazine.CFrame = final * self.MagazineRest * magazineOffset
	end
end

function Viewmodel:Destroy()
	self.Model:Destroy()
end

return Viewmodel
