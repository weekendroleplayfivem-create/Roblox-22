--[[
	Viewmodel
	PLACEHOLDER first-person weapon built from simple parts using the
	weapon's `Viewmodel` description in WeaponConfig. Procedural animation
	(equip, reload, recoil kick, sway, bob, aim-down-sights) is done in code.

	To use a real model: put a Model named after the weapon id in
	ReplicatedStorage/Assets/Viewmodels with a PrimaryPart and an Attachment
	named "Muzzle"; it will be used instead of the generated one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Spring = require(Shared.Modules.Spring)
local MathUtil = require(Shared.Modules.MathUtil)

local Viewmodel = {}
Viewmodel.__index = Viewmodel

local HIP_OFFSET = CFrame.new(0.85, -0.8, -1.5)
local ADS_OFFSET = CFrame.new(0, -0.42, -1.15)
local EQUIP_DROP = CFrame.new(0, -1.2, 0.4) * CFrame.Angles(math.rad(-55), 0, 0)
local RELOAD_POSE = CFrame.new(0.1, -0.25, 0.1) * CFrame.Angles(math.rad(-20), 0, math.rad(35))

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function weldTo(base: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = base.CFrame * offset
end

function Viewmodel.new(weapon, skin, accentColor: Color3?)
	local self = setmetatable({}, Viewmodel)
	self.Weapon = weapon
	local camera = workspace.CurrentCamera

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Viewmodels")
	local template = folder and folder:FindFirstChild(weapon.Id)
	local model: Model
	if template and template:IsA("Model") and template.PrimaryPart then
		model = template:Clone()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		local muzzle = model:FindFirstChild("Muzzle", true)
		self.MuzzleOffset = if muzzle and muzzle:IsA("Attachment")
			then model.PrimaryPart.CFrame:ToObjectSpace(muzzle.WorldCFrame)
			else CFrame.new(0, 0, -2)
		self.Accent = nil
	else
		model = Instance.new("Model")
		local description = weapon.Viewmodel
		local bodyColor = if skin and skin.Color then skin.Color else Color3.fromRGB(42, 44, 60)
		local material = if skin then Enum.Material[skin.Material] else Enum.Material.SmoothPlastic
		local body = makePart("Body", description.BodySize, bodyColor, material, model)
		body.CFrame = CFrame.identity
		local barrelSize = Vector3.new(description.BodySize.X * 0.45, description.BodySize.Y * 0.4, description.BarrelLength)
		local barrel = makePart("Barrel", barrelSize, Color3.fromRGB(25, 25, 35), Enum.Material.Metal, model)
		weldTo(body, barrel, CFrame.new(0, description.BodySize.Y * 0.15, -(description.BodySize.Z + description.BarrelLength) / 2))
		local accent = makePart("Accent", Vector3.new(description.BodySize.X + 0.04, 0.08, description.BodySize.Z * 0.75), accentColor or description.Color, Enum.Material.Neon, model)
		weldTo(body, accent, CFrame.new(0, description.BodySize.Y / 2, 0))
		local grip = makePart("Grip", Vector3.new(description.BodySize.X * 0.7, 0.55, 0.32), bodyColor, material, model)
		weldTo(body, grip, CFrame.new(0, -description.BodySize.Y / 2 - 0.2, description.BodySize.Z * 0.25) * CFrame.Angles(math.rad(15), 0, 0))
		-- Stylised glove (no realistic hands needed for the placeholder).
		local glove = makePart("Glove", Vector3.new(0.38, 0.38, 0.5), Color3.fromRGB(240, 240, 250), Enum.Material.SmoothPlastic, model)
		weldTo(body, glove, CFrame.new(0, -description.BodySize.Y / 2 - 0.15, description.BodySize.Z * 0.3))
		model.PrimaryPart = body
		self.MuzzleOffset = CFrame.new(0, description.BodySize.Y * 0.15, -(description.BodySize.Z / 2 + description.BarrelLength))
		self.Accent = accent
		self.AccentColor = accent.Color
	end
	model.Name = "Viewmodel"
	model.Parent = camera
	self.Model = model

	self.AimAlpha = 0
	self.EquipStart = os.clock()
	self.EquipTime = math.max(weapon.EquipTime, 0.05)
	self.ReloadStart = 0
	self.ReloadTime = 0
	self.Charge = 0
	self.Visible = true
	self.KickSpring = Spring.new(Vector3.zero, 260, 22)
	self.SwaySpring = Spring.new(Vector3.zero, 120, 14)
	self.BobTime = 0
	self.CurrentCFrame = CFrame.identity
	return self
end

function Viewmodel:Kick(strength: number)
	self.KickSpring:Impulse(Vector3.new(math.rad(4) * strength, (math.random() - 0.5) * 0.02, 0.18 * strength) * 20)
end

function Viewmodel:PlayReload(duration: number)
	self.ReloadStart = os.clock()
	self.ReloadTime = duration
end

function Viewmodel:CancelReload()
	self.ReloadTime = 0
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
end

function Viewmodel:GetMuzzlePosition(): Vector3
	return (self.CurrentCFrame * self.MuzzleOffset).Position
end

-- Called every render frame after the camera has updated.
function Viewmodel:Update(deltaTime: number, aiming: boolean, moveSpeed: number, grounded: boolean)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	self.AimAlpha = MathUtil.Lerp(self.AimAlpha, if aiming then 1 else 0, MathUtil.Damp(18, deltaTime))

	-- Sway from mouse movement.
	local mouseDelta = UserInputService:GetMouseDelta()
	self.SwaySpring.Target = Vector3.new(-mouseDelta.Y, -mouseDelta.X, 0) * 0.0025 * (1 - self.AimAlpha * 0.8)
	local sway = self.SwaySpring:Update(deltaTime)

	-- Bob while moving on the ground.
	local bob = CFrame.identity
	if grounded and moveSpeed > 2 then
		self.BobTime += deltaTime * (6 + moveSpeed * 0.25)
		local intensity = math.clamp(moveSpeed / 24, 0, 1.2) * (1 - self.AimAlpha * 0.85)
		bob = CFrame.new(math.sin(self.BobTime) * 0.035 * intensity, math.abs(math.cos(self.BobTime)) * 0.04 * intensity, 0)
	end

	self.KickSpring.Target = Vector3.zero
	local kick = self.KickSpring:Update(deltaTime)

	local equipAlpha = math.clamp((now - self.EquipStart) / self.EquipTime, 0, 1)
	local equipOffset = EQUIP_DROP:Lerp(CFrame.identity, 1 - (1 - equipAlpha) ^ 3)

	local reloadOffset = CFrame.identity
	if self.ReloadTime > 0 then
		local alpha = (now - self.ReloadStart) / self.ReloadTime
		if alpha >= 1 then
			self.ReloadTime = 0
		else
			local pose = math.sin(alpha * math.pi)
			reloadOffset = CFrame.identity:Lerp(RELOAD_POSE, math.min(1, pose * 1.6))
		end
	end

	local chargeShake = CFrame.identity
	if self.Charge > 0 then
		local amount = self.Charge * 0.01
		chargeShake = CFrame.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
		if self.Accent then
			self.Accent.Color = self.AccentColor:Lerp(Color3.new(1, 1, 1), self.Charge)
		end
	elseif self.Accent then
		self.Accent.Color = self.AccentColor
	end

	local base = HIP_OFFSET:Lerp(ADS_OFFSET, self.AimAlpha)
	local final = camera.CFrame
		* base
		* CFrame.Angles(sway.X, sway.Y, 0)
		* bob
		* equipOffset
		* reloadOffset
		* chargeShake
		* CFrame.new(0, 0, kick.Z)
		* CFrame.Angles(kick.X, kick.Y, 0)
	self.CurrentCFrame = final
	self.Model:PivotTo(final)
end

function Viewmodel:Destroy()
	self.Model:Destroy()
end

return Viewmodel
