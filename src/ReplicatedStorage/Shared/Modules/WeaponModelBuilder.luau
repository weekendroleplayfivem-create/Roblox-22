--[[
	WeaponModelBuilder
	Builds detailed PLACEHOLDER weapon models from primitive parts: sleek,
	tactical sci-fi silhouettes with angled wedge fairings, two-tone panels,
	rails with teeth, optics with glowing reticles, vented handguards,
	muzzle devices, trigger groups, ejection ports and neon accents.
	All designs are original.

	Each weapon picks a kit (WeaponConfig.Viewmodel.Kit). Kits are composed
	from a small library of reusable components (receiver, rail, optic,
	magazine, grip, stock, barrel, muzzle device ...), so every weapon
	shares the same level of detail while keeping a distinct silhouette.

	The same builder is used for the first-person viewmodel (client, full
	detail) and the third-person world model (server, LowDetail skips the
	tiniest parts).

	Model space: origin = centre of the receiver, -Z = forward (muzzle).
	Returns (Model, Info) where Info has:
	  Body           invisible core / PrimaryPart
	  Muzzle         CFrame of the muzzle relative to Body
	  Eject          CFrame of the ejection port (casings fly out of here)
	  Magazine       part animated during reloads (nil if none)
	  MagazineRest   its rest CFrame
	  MagazineParts  every part that moves with the magazine
	  Glow           neon parts (flash on shots, glow while charging)
	  Sight          point that sits at screen centre when aiming down sights
	  RightHand      grip position (for viewmodel arms)
	  LeftHand       support-hand position (for viewmodel arms)

	Replace with real models by adding ReplicatedStorage/Assets/Viewmodels/<Id>
	(client) or ServerStorage/Weapons/<Id> (server).
]]

local WeaponModelBuilder = {}

-- Default two-tone palette (overridable per weapon via Viewmodel.Palette).
local DEFAULT_PALETTE = {
	Body = Color3.fromRGB(38, 40, 48), -- matte graphite
	Panel = Color3.fromRGB(214, 219, 228), -- off-white panels
}
local METAL = Color3.fromRGB(72, 76, 88)
local DARK = Color3.fromRGB(17, 18, 22)
local GRIP = Color3.fromRGB(28, 29, 34)

local Z_ALIGN = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; turn them to Z
local WEDGE_FORWARD = CFrame.identity -- slope faces forward (-Z): tall at the back
local WEDGE_BACKWARD = CFrame.Angles(0, math.pi, 0)
local WEDGE_UNDER = CFrame.Angles(0, 0, math.pi) -- upside down, slope under the front

export type Info = {
	Body: BasePart,
	Muzzle: CFrame,
	Eject: CFrame,
	Magazine: BasePart?,
	MagazineRest: CFrame?,
	MagazineParts: { { Part: BasePart, Rest: CFrame } },
	Glow: { BasePart },
	RightHand: Vector3,
	LeftHand: Vector3,
	Sight: Vector3,
}

type Spec = {
	Name: string,
	Shape: string?, -- "Block" | "Cylinder" | "Ball" | "Wedge"
	Size: Vector3,
	CFrame: CFrame,
	Role: string, -- Body | Panel | Metal | Dark | Grip | Accent | Glass | Energy
	Detail: boolean?, -- tiny part, skipped in LowDetail
	Mag: boolean?, -- moves with the magazine during reloads
}

--[[ Component library ]]

local Kit = {}
Kit.__index = Kit

local function newKit()
	return setmetatable({
		Specs = {} :: { Spec },
		Muzzle = Vector3.new(0, 0, -2),
		Eject = CFrame.new(0.17, 0.2, -0.05) * CFrame.Angles(0, math.rad(90), 0),
		RightHand = Vector3.new(0, -0.35, 0.3),
		LeftHand = Vector3.new(0, -0.05, -1),
		Sight = Vector3.new(0, 0.3, 0),
	}, Kit)
end

function Kit:Add(spec: Spec): Spec
	table.insert(self.Specs, spec)
	return spec
end

function Kit:Box(name: string, size: Vector3, position: Vector3, role: string, rotation: CFrame?, detail: boolean?): Spec
	return self:Add({ Name = name, Size = size, CFrame = CFrame.new(position) * (rotation or CFrame.identity), Role = role, Detail = detail })
end

function Kit:Wedge(name: string, size: Vector3, position: Vector3, role: string, orientation: CFrame?): Spec
	return self:Add({ Name = name, Shape = "Wedge", Size = size, CFrame = CFrame.new(position) * (orientation or WEDGE_FORWARD), Role = role })
end

function Kit:Tube(name: string, length: number, diameter: number, position: Vector3, role: string, detail: boolean?): Spec
	return self:Add({ Name = name, Shape = "Cylinder", Size = Vector3.new(length, diameter, diameter), CFrame = CFrame.new(position) * Z_ALIGN, Role = role, Detail = detail })
end

function Kit:Ball(name: string, diameter: number, position: Vector3, role: string, detail: boolean?): Spec
	return self:Add({ Name = name, Shape = "Ball", Size = Vector3.one * diameter, CFrame = CFrame.new(position), Role = role, Detail = detail })
end

-- Two-tone receiver: lower body + upper panel shell with a sloped front.
function Kit:Receiver(length: number, width: number, height: number, z: number?)
	local center = z or 0
	self:Box("Lower", Vector3.new(width, height * 0.55, length), Vector3.new(0, -height * 0.2, center), "Body")
	self:Box("Upper", Vector3.new(width * 0.92, height * 0.45, length * 0.82), Vector3.new(0, height * 0.3, center + length * 0.09), "Panel")
	self:Wedge("UpperNose", Vector3.new(width * 0.92, height * 0.45, length * 0.18), Vector3.new(0, height * 0.3, center - length * 0.41), "Panel")
	-- Panel seam lines + side accent strip.
	for _, side in { -1, 1 } do
		self:Box("Seam", Vector3.new(0.012, 0.025, length * 0.8), Vector3.new(side * width * 0.465, height * 0.08, center), "Dark", nil, true)
		self:Box("Accent", Vector3.new(0.015, 0.035, length * 0.55), Vector3.new(side * width * 0.505, -height * 0.12, center - length * 0.05), "Accent")
	end
	-- Ejection port on the right side.
	self:Box("Port", Vector3.new(0.012, height * 0.22, length * 0.2), Vector3.new(width * 0.505, height * 0.25, center + length * 0.05), "Dark", nil, true)
	self.Eject = CFrame.new(width * 0.55, height * 0.25, center + length * 0.05) * CFrame.Angles(0, math.rad(90), 0)
end

-- Rail with teeth along the top.
function Kit:Rail(fromZ: number, toZ: number, y: number, width: number?)
	local railWidth = width or 0.14
	local length = math.abs(toZ - fromZ)
	local middle = (fromZ + toZ) / 2
	self:Box("Rail", Vector3.new(railWidth, 0.04, length), Vector3.new(0, y, middle), "Metal")
	local teeth = math.floor(length / 0.11)
	for index = 0, teeth - 1 do
		self:Box("Tooth", Vector3.new(railWidth + 0.03, 0.035, 0.045), Vector3.new(0, y + 0.035, math.min(fromZ, toZ) + 0.06 + index * 0.11), "Metal", nil, true)
	end
end

-- Optics: "Dot" red-dot, "Holo" open holographic frame, "Scope" magnified tube, "Iron" sights.
function Kit:Optic(kind: string, z: number, y: number)
	self.Sight = Vector3.new(0, y + (if kind == "Scope" then 0.17 elseif kind == "Iron" then 0.09 elseif kind == "Holo" then 0.15 else 0.12), z)
	if kind == "Scope" then
		self:Box("ScopeMount", Vector3.new(0.09, 0.1, 0.42), Vector3.new(0, y + 0.03, z), "Metal")
		self:Tube("ScopeBody", 0.8, 0.17, Vector3.new(0, y + 0.17, z), "Body")
		self:Tube("ScopeBell", 0.2, 0.24, Vector3.new(0, y + 0.17, z - 0.45), "Body")
		self:Tube("ScopeEye", 0.14, 0.2, Vector3.new(0, y + 0.17, z + 0.42), "Grip")
		self:Tube("ScopeRing", 0.05, 0.25, Vector3.new(0, y + 0.17, z - 0.12), "Accent")
		self:Tube("ScopeLens", 0.02, 0.2, Vector3.new(0, y + 0.17, z - 0.56), "Glass", true)
		self:Box("Turret", Vector3.new(0.08, 0.08, 0.08), Vector3.new(0, y + 0.29, z), "Metal", nil, true)
		self:Box("Turret", Vector3.new(0.08, 0.08, 0.08), Vector3.new(0.12, y + 0.17, z), "Metal", nil, true)
	elseif kind == "Holo" then
		self:Box("HoloBase", Vector3.new(0.16, 0.06, 0.3), Vector3.new(0, y + 0.03, z), "Metal")
		self:Box("HoloPostL", Vector3.new(0.025, 0.17, 0.06), Vector3.new(-0.075, y + 0.14, z - 0.1), "Body")
		self:Box("HoloPostR", Vector3.new(0.025, 0.17, 0.06), Vector3.new(0.075, y + 0.14, z - 0.1), "Body")
		self:Box("HoloTop", Vector3.new(0.175, 0.03, 0.06), Vector3.new(0, y + 0.235, z - 0.1), "Body")
		self:Box("HoloGlass", Vector3.new(0.13, 0.13, 0.01), Vector3.new(0, y + 0.15, z - 0.1), "Glass", nil, true)
		self:Ball("Reticle", 0.025, Vector3.new(0, y + 0.15, z - 0.1), "Accent", true)
	elseif kind == "Iron" then
		self:Wedge("RearSight", Vector3.new(0.1, 0.07, 0.08), Vector3.new(0, y + 0.035, z + 0.4), "Metal", WEDGE_BACKWARD)
		self:Wedge("FrontSight", Vector3.new(0.05, 0.1, 0.06), Vector3.new(0, y + 0.05, z - 0.45), "Metal")
		self:Ball("SightDot", 0.025, Vector3.new(0, y + 0.1, z - 0.45), "Accent", true)
	else -- Dot
		self:Box("DotBase", Vector3.new(0.13, 0.05, 0.26), Vector3.new(0, y + 0.025, z), "Metal")
		self:Box("DotHousing", Vector3.new(0.15, 0.13, 0.2), Vector3.new(0, y + 0.115, z), "Body")
		self:Wedge("DotHood", Vector3.new(0.15, 0.05, 0.12), Vector3.new(0, y + 0.2, z - 0.04), "Body", WEDGE_BACKWARD)
		self:Box("DotLens", Vector3.new(0.11, 0.09, 0.01), Vector3.new(0, y + 0.12, z - 0.105), "Glass", nil, true)
		self:Ball("Reticle", 0.022, Vector3.new(0, y + 0.12, z - 0.09), "Accent", true)
	end
end

-- Vented handguard with a sloped nose; returns the front of the handguard.
function Kit:Handguard(length: number, width: number, height: number, z: number, y: number, vents: number?)
	self:Box("Handguard", Vector3.new(width, height, length), Vector3.new(0, y, z), "Body")
	self:Wedge("HandguardNose", Vector3.new(width, height * 0.5, length * 0.22), Vector3.new(0, y + height * 0.25, z - length * 0.61), "Panel")
	self:Box("HandguardBottom", Vector3.new(width * 0.9, height * 0.5, length * 0.22), Vector3.new(0, y - height * 0.25, z - length * 0.61), "Body")
	local count = vents or 3
	for index = 1, count do
		local ventZ = z - length * 0.35 + (index - 1) * (length * 0.7 / math.max(count - 1, 1))
		for _, side in { -1, 1 } do
			self:Box("Vent", Vector3.new(0.012, height * 0.45, 0.07), Vector3.new(side * width * 0.505, y, ventZ), "Dark", nil, true)
		end
	end
	self:Box("HandguardStripe", Vector3.new(width * 1.02, 0.025, length * 0.5), Vector3.new(0, y + height * 0.2, z + length * 0.1), "Accent")
	self.LeftHand = Vector3.new(0, y - height * 0.6, z + length * 0.1)
	return z - length * 0.72
end

function Kit:Barrel(length: number, diameter: number, frontZ: number, y: number)
	self:Tube("Barrel", length, diameter, Vector3.new(0, y, frontZ - length / 2), "Metal")
	return frontZ - length
end

-- Muzzle devices: "Brake" slotted, "Comp" angled, "Emitter" glowing rings, "Flash" prongs.
function Kit:MuzzleDevice(kind: string, frontZ: number, y: number, diameter: number)
	local tip = frontZ
	if kind == "Emitter" then
		self:Tube("EmitterBody", 0.22, diameter * 1.6, Vector3.new(0, y, frontZ - 0.11), "Body")
		self:Tube("EmitterRing", 0.04, diameter * 1.9, Vector3.new(0, y, frontZ - 0.05), "Accent")
		self:Tube("EmitterRing", 0.04, diameter * 1.9, Vector3.new(0, y, frontZ - 0.17), "Accent")
		self:Tube("EmitterCore", 0.02, diameter * 1.1, Vector3.new(0, y, frontZ - 0.225), "Energy", true)
		tip = frontZ - 0.23
	elseif kind == "Comp" then
		self:Box("Comp", Vector3.new(diameter * 1.5, diameter * 1.5, 0.24), Vector3.new(0, y, frontZ - 0.12), "Dark")
		self:Wedge("CompTop", Vector3.new(diameter * 1.5, diameter * 0.5, 0.12), Vector3.new(0, y + diameter * 1, frontZ - 0.18), "Dark")
		self:Box("CompPort", Vector3.new(diameter * 0.6, 0.02, 0.06), Vector3.new(0, y + diameter * 0.76, frontZ - 0.08), "Accent", nil, true)
		tip = frontZ - 0.24
	elseif kind == "Flash" then
		for index = 0, 3 do
			local angle = index * math.pi / 2 + math.pi / 4
			self:Box("Prong", Vector3.new(0.035, 0.035, 0.22), Vector3.new(math.cos(angle) * diameter * 0.55, y + math.sin(angle) * diameter * 0.55, frontZ - 0.11), "Dark", nil, true)
		end
		self:Tube("FlashBase", 0.08, diameter * 1.4, Vector3.new(0, y, frontZ - 0.04), "Dark")
		tip = frontZ - 0.22
	else -- Brake
		self:Box("Brake", Vector3.new(diameter * 1.6, diameter * 1.4, 0.3), Vector3.new(0, y, frontZ - 0.15), "Dark")
		for _, side in { -1, 1 } do
			self:Box("BrakeSlot", Vector3.new(0.012, diameter * 0.9, 0.05), Vector3.new(side * diameter * 0.81, y, frontZ - 0.09), "Accent", nil, true)
			self:Box("BrakeSlot", Vector3.new(0.012, diameter * 0.9, 0.05), Vector3.new(side * diameter * 0.81, y, frontZ - 0.2), "Accent", nil, true)
		end
		tip = frontZ - 0.3
	end
	self.Muzzle = Vector3.new(0, y, tip - 0.02)
end

-- Magazine: "Box" straight, "Curved" angled, "Cell" energy cell, "Drum".
function Kit:Magazine(kind: string, z: number, y: number, width: number?)
	local magWidth = width or 0.17
	if kind == "Drum" then
		local drum = self:Tube("Magazine", 0.28, 0.48, Vector3.new(0, y - 0.18, z), "Body")
		drum.Mag = true
		self:Tube("DrumFace", 0.3, 0.3, Vector3.new(0, y - 0.18, z), "Panel").Mag = true
		self:Tube("DrumGlow", 0.31, 0.16, Vector3.new(0, y - 0.18, z), "Accent").Mag = true
		return
	elseif kind == "Cell" then
		self:Box("Magazine", Vector3.new(magWidth + 0.04, 0.3, 0.32), Vector3.new(0, y - 0.15, z), "Panel").Mag = true
		self:Box("CellWindow", Vector3.new(magWidth + 0.05, 0.16, 0.2), Vector3.new(0, y - 0.15, z), "Energy").Mag = true
		self:Box("CellCap", Vector3.new(magWidth + 0.06, 0.05, 0.34), Vector3.new(0, y - 0.32, z), "Dark").Mag = true
		return
	end
	local tilt = if kind == "Curved" then CFrame.Angles(math.rad(-14), 0, 0) else CFrame.identity
	local length = if kind == "Curved" then 0.52 else 0.42
	self:Box("Magazine", Vector3.new(magWidth, length, 0.27), Vector3.new(0, y - length / 2, z), "Body", tilt).Mag = true
	self:Box("MagPanel", Vector3.new(magWidth + 0.01, length * 0.5, 0.2), Vector3.new(0, y - length * 0.45, z), "Panel", tilt).Mag = true
	self:Box("MagGlow", Vector3.new(magWidth + 0.02, 0.03, 0.22), Vector3.new(0, y - length * 0.15, z), "Accent", tilt).Mag = true
	self:Box("MagBase", Vector3.new(magWidth + 0.03, 0.05, 0.3), Vector3.new(0, y - length + 0.02, z - (if kind == "Curved" then 0.06 else 0)), "Dark", tilt).Mag = true
end

-- Pistol grip + trigger group; sets the right-hand position.
function Kit:Grip(z: number, y: number, angle: number?)
	local tilt = CFrame.Angles(math.rad(angle or 16), 0, 0)
	self:Box("Grip", Vector3.new(0.16, 0.42, 0.21), Vector3.new(0, y - 0.21, z), "Grip", tilt)
	self:Box("GripPanel", Vector3.new(0.17, 0.3, 0.08), Vector3.new(0, y - 0.22, z + 0.06), "Body", tilt, true)
	self:Box("TriggerGuard", Vector3.new(0.035, 0.035, 0.3), Vector3.new(0, y - 0.15, z - 0.24), "Metal", nil, true)
	self:Box("TriggerGuardFront", Vector3.new(0.035, 0.14, 0.035), Vector3.new(0, y - 0.08, z - 0.38), "Metal", nil, true)
	self:Box("Trigger", Vector3.new(0.025, 0.1, 0.035), Vector3.new(0, y - 0.07, z - 0.22), "Accent", CFrame.Angles(math.rad(12), 0, 0), true)
	self.RightHand = Vector3.new(0, y - 0.2, z)
end

-- Stocks: "Full" angular, "Skeleton" open frame, "Bullpup" pad only, "Brace" folding.
function Kit:Stock(kind: string, backZ: number, y: number)
	if kind == "Skeleton" then
		self:Box("StockTop", Vector3.new(0.06, 0.06, 0.55), Vector3.new(0, y + 0.05, backZ + 0.27), "Metal")
		self:Box("StockBottom", Vector3.new(0.06, 0.06, 0.5), Vector3.new(0, y - 0.17, backZ + 0.3), "Metal", CFrame.Angles(math.rad(-10), 0, 0))
		self:Box("StockPad", Vector3.new(0.18, 0.36, 0.07), Vector3.new(0, y - 0.05, backZ + 0.56), "Grip")
		self:Box("StockAccent", Vector3.new(0.19, 0.03, 0.08), Vector3.new(0, y + 0.08, backZ + 0.56), "Accent", nil, true)
	elseif kind == "Bullpup" then
		self:Box("ButtPad", Vector3.new(0.22, 0.42, 0.08), Vector3.new(0, y - 0.05, backZ + 0.04), "Grip")
	elseif kind == "Brace" then
		self:Box("Brace", Vector3.new(0.05, 0.22, 0.4), Vector3.new(0.09, y - 0.03, backZ + 0.2), "Metal")
		self:Box("Brace", Vector3.new(0.05, 0.22, 0.4), Vector3.new(-0.09, y - 0.03, backZ + 0.2), "Metal")
		self:Box("BracePad", Vector3.new(0.22, 0.26, 0.06), Vector3.new(0, y - 0.03, backZ + 0.42), "Grip")
	else -- Full
		self:Tube("BufferTube", 0.32, 0.12, Vector3.new(0, y + 0.02, backZ + 0.16), "Metal")
		self:Box("Stock", Vector3.new(0.2, 0.3, 0.42), Vector3.new(0, y - 0.03, backZ + 0.5), "Body")
		self:Wedge("StockCheek", Vector3.new(0.2, 0.08, 0.42), Vector3.new(0, y + 0.16, backZ + 0.5), "Panel", WEDGE_BACKWARD)
		self:Wedge("StockToe", Vector3.new(0.2, 0.14, 0.3), Vector3.new(0, y - 0.25, backZ + 0.56), "Body", WEDGE_UNDER * WEDGE_BACKWARD)
		self:Box("StockPad", Vector3.new(0.22, 0.38, 0.06), Vector3.new(0, y - 0.03, backZ + 0.74), "Grip")
		self:Box("StockAccent", Vector3.new(0.205, 0.025, 0.25), Vector3.new(0, y + 0.07, backZ + 0.45), "Accent", nil, true)
	end
end

function Kit:ChargingHandle(z: number, y: number)
	self:Box("Handle", Vector3.new(0.18, 0.04, 0.08), Vector3.new(0, y, z), "Metal", nil, true)
	self:Box("HandleTip", Vector3.new(0.05, 0.05, 0.08), Vector3.new(0.11, y, z), "Accent", nil, true)
end

-- Underslung laser / light module.
function Kit:Module(z: number, y: number)
	self:Box("Module", Vector3.new(0.12, 0.1, 0.24), Vector3.new(0.13, y, z), "Dark")
	self:Ball("ModuleLens", 0.06, Vector3.new(0.13, y, z - 0.12), "Accent", true)
end

-- Exposed energy coils (charge / tesla weapons).
function Kit:Coils(count: number, fromZ: number, step: number, y: number, diameter: number)
	for index = 0, count - 1 do
		self:Tube("Coil", 0.05, diameter, Vector3.new(0, y, fromZ - index * step), "Accent")
		self:Tube("CoilInner", 0.06, diameter * 0.75, Vector3.new(0, y, fromZ - index * step), "Dark", true)
	end
end

--[[ Weapon kits ]]

local Kits: { [string]: () -> typeof(newKit()) } = {}

-- Pulse Rifle: balanced assault rifle (dot sight, full stock, brake).
Kits.Rifle = function()
	local k = newKit()
	k:Receiver(1.25, 0.3, 0.42)
	k:Rail(-0.6, 0.55, 0.25)
	k:Optic("Dot", -0.05, 0.27)
	k:ChargingHandle(0.5, 0.24)
	local front = k:Handguard(0.8, 0.3, 0.3, -0.98, 0.06, 3)
	k:Module(-1.05, -0.14)
	local tip = k:Barrel(0.35, 0.11, front, 0.08)
	k:MuzzleDevice("Brake", tip, 0.08, 0.11)
	k:Magazine("Curved", -0.32, -0.12)
	k:Grip(0.32, -0.12)
	k:Stock("Full", 0.62, 0.04)
	return k
end

-- Triad Burst: bullpup with three emitters and a holo sight.
Kits.Burst = function()
	local k = newKit()
	k:Receiver(1.5, 0.32, 0.46, 0.15)
	k:Rail(-0.5, 0.4, 0.27)
	k:Optic("Holo", -0.1, 0.29)
	k:Wedge("Shroud", Vector3.new(0.34, 0.24, 0.5), Vector3.new(0, 0.12, -0.85), "Panel")
	for _, offset in { Vector3.new(0.07, 0.1, 0), Vector3.new(-0.07, 0.1, 0), Vector3.new(0, -0.03, 0) } do
		k:Tube("Barrel", 0.55, 0.08, Vector3.new(offset.X, offset.Y, -1.0), "Metal")
		k:Tube("BarrelTip", 0.05, 0.1, Vector3.new(offset.X, offset.Y, -1.28), "Accent")
	end
	k.Muzzle = Vector3.new(0, 0.05, -1.33)
	k:Magazine("Box", 0.62, -0.12)
	k:Grip(-0.22, -0.12)
	k:Stock("Bullpup", 0.9, 0)
	k.LeftHand = Vector3.new(0, -0.15, -0.75)
	k.Eject = CFrame.new(0.2, 0.15, 0.45) * CFrame.Angles(0, math.rad(90), 0)
	return k
end

-- Spreadshot: chunky pump scatter with twin tubes.
Kits.Shotgun = function()
	local k = newKit()
	k:Receiver(1.0, 0.36, 0.44)
	k:Rail(-0.45, 0.35, 0.24)
	k:Optic("Iron", 0, 0.26)
	k:Tube("BarrelTop", 1.0, 0.16, Vector3.new(0, 0.1, -1.0), "Metal")
	k:Tube("TubeMag", 0.9, 0.14, Vector3.new(0, -0.07, -0.95), "Body")
	k:Box("Pump", Vector3.new(0.3, 0.2, 0.42), Vector3.new(0, -0.08, -0.9), "Panel")
	for index = 0, 3 do
		k:Box("PumpRidge", Vector3.new(0.31, 0.02, 0.03), Vector3.new(0, -0.08 + (index - 1.5) * 0.045, -0.9), "Dark", nil, true)
	end
	k:MuzzleDevice("Comp", -1.5, 0.1, 0.16)
	k:Magazine("Cell", -0.15, -0.14, 0.22)
	k:Grip(0.32, -0.12)
	k:Stock("Full", 0.5, 0.02)
	k.LeftHand = Vector3.new(0, -0.2, -0.9)
	return k
end

-- Hailstorm: drum-fed auto scatter.
Kits.Drum = function()
	local k = newKit()
	k:Receiver(1.1, 0.38, 0.44)
	k:Rail(-0.5, 0.4, 0.24)
	k:Optic("Holo", -0.05, 0.26)
	local front = k:Handguard(0.6, 0.34, 0.3, -0.85, 0.05, 2)
	k:Barrel(0.15, 0.18, front, 0.07)
	k:MuzzleDevice("Comp", front - 0.15, 0.07, 0.2)
	k:Magazine("Drum", -0.2, -0.12)
	k:Grip(0.35, -0.12)
	k:Stock("Skeleton", 0.55, 0.04)
	return k
end

-- Longshot: long-range rifle with scope, bipod and big brake.
Kits.Sniper = function()
	local k = newKit()
	k:Receiver(1.4, 0.28, 0.4)
	k:Rail(-0.6, 0.6, 0.23)
	k:Optic("Scope", -0.05, 0.25)
	k:ChargingHandle(0.45, 0.1)
	local front = k:Handguard(0.7, 0.26, 0.26, -1.05, 0.05, 4)
	local tip = k:Barrel(1.0, 0.1, front, 0.07)
	k:MuzzleDevice("Brake", tip, 0.07, 0.12)
	k:Box("Bipod", Vector3.new(0.04, 0.32, 0.04), Vector3.new(0.07, -0.2, -1.25), "Metal", CFrame.Angles(math.rad(-20), 0, math.rad(12)), true)
	k:Box("Bipod", Vector3.new(0.04, 0.32, 0.04), Vector3.new(-0.07, -0.2, -1.25), "Metal", CFrame.Angles(math.rad(-20), 0, math.rad(-12)), true)
	k:Magazine("Box", -0.25, -0.1, 0.15)
	k:Grip(0.35, -0.1)
	k:Stock("Full", 0.7, 0.03)
	return k
end

-- Spectre: compact marksman rifle with short scope and comp.
Kits.Marksman = function()
	local k = newKit()
	k:Receiver(1.3, 0.3, 0.42)
	k:Rail(-0.6, 0.5, 0.25)
	k:Optic("Scope", -0.1, 0.27)
	local front = k:Handguard(0.85, 0.28, 0.28, -1.1, 0.06, 4)
	local tip = k:Barrel(0.3, 0.1, front, 0.08)
	k:MuzzleDevice("Flash", tip, 0.08, 0.11)
	k:Magazine("Box", -0.28, -0.12)
	k:Grip(0.32, -0.12)
	k:Stock("Skeleton", 0.62, 0.04)
	return k
end

-- Buzzsaw: compact SMG with brace stock and long magazine.
Kits.SMG = function()
	local k = newKit()
	k:Receiver(0.95, 0.3, 0.42)
	k:Rail(-0.4, 0.4, 0.25)
	k:Optic("Holo", 0, 0.27)
	local front = k:Handguard(0.45, 0.28, 0.28, -0.7, 0.06, 2)
	k:MuzzleDevice("Flash", front, 0.07, 0.11)
	k:Box("ForeGrip", Vector3.new(0.1, 0.26, 0.11), Vector3.new(0, -0.2, -0.7), "Grip")
	k:Magazine("Box", -0.2, -0.12, 0.14)
	k:Grip(0.25, -0.12)
	k:Stock("Brace", 0.48, 0.02)
	k.LeftHand = Vector3.new(0, -0.32, -0.7)
	return k
end

-- Plasmortar: launcher with a glowing chamber orb.
Kits.Launcher = function()
	local k = newKit()
	k:Tube("Body", 1.2, 0.48, Vector3.new(0, 0, -0.1), "Body")
	k:Tube("BodyPanel", 0.6, 0.5, Vector3.new(0, 0, 0.15), "Panel")
	k:Tube("Front", 0.2, 0.58, Vector3.new(0, 0, -0.75), "Dark")
	k:Tube("Bore", 0.04, 0.42, Vector3.new(0, 0, -0.86), "Energy")
	k:Coils(3, -0.4, 0.15, 0, 0.53)
	k:Ball("Chamber", 0.36, Vector3.new(0, 0.3, 0.12), "Energy")
	k:Box("ChamberCage", Vector3.new(0.44, 0.05, 0.44), Vector3.new(0, 0.3, 0.12), "Metal")
	k:Box("ChamberCage", Vector3.new(0.05, 0.4, 0.05), Vector3.new(0.2, 0.3, 0.32), "Metal", nil, true)
	k:Box("ChamberCage", Vector3.new(0.05, 0.4, 0.05), Vector3.new(-0.2, 0.3, -0.08), "Metal", nil, true)
	k:Tube("Back", 0.18, 0.52, Vector3.new(0, 0, 0.58), "Dark")
	k:Optic("Iron", -0.1, 0.24)
	k.Muzzle = Vector3.new(0, 0, -0.9)
	k:Magazine("Cell", 0.25, -0.22, 0.24)
	k:Grip(-0.15, -0.18)
	k.LeftHand = Vector3.new(0, -0.3, -0.55)
	return k
end

-- Capacitor: charge rifle with exposed coils and long scope.
Kits.Charge = function()
	local k = newKit()
	k:Receiver(1.35, 0.32, 0.44)
	k:Rail(-0.5, 0.5, 0.26)
	k:Optic("Scope", -0.05, 0.28)
	k:Tube("Spine", 1.1, 0.14, Vector3.new(0, 0.07, -1.2), "Metal")
	k:Coils(5, -0.85, 0.15, 0.07, 0.28)
	k:Box("Capacitor", Vector3.new(0.09, 0.09, 0.55), Vector3.new(0.19, 0.12, -0.25), "Energy")
	k:Box("Capacitor", Vector3.new(0.09, 0.09, 0.55), Vector3.new(-0.19, 0.12, -0.25), "Energy")
	k:MuzzleDevice("Emitter", -1.75, 0.07, 0.14)
	k:Magazine("Cell", 0.05, -0.12)
	k:Grip(0.4, -0.12)
	k:Stock("Full", 0.68, 0.04)
	k.LeftHand = Vector3.new(0, -0.1, -0.85)
	return k
end

-- Tesla Coil: arc weapon with prongs around a glowing core.
Kits.Tesla = function()
	local k = newKit()
	k:Receiver(1.0, 0.38, 0.46)
	k:Rail(-0.4, 0.35, 0.25)
	k:Optic("Dot", 0, 0.27)
	k:Tube("Coil", 0.55, 0.28, Vector3.new(0, 0.05, -0.75), "Metal")
	k:Coils(3, -0.55, 0.15, 0.05, 0.36)
	k:Ball("Core", 0.24, Vector3.new(0, 0.05, -1.1), "Energy")
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3 + math.pi / 2
		k:Box("Prong", Vector3.new(0.045, 0.045, 0.5), Vector3.new(math.cos(angle) * 0.17, 0.05 + math.sin(angle) * 0.17, -1.05), "Accent", CFrame.Angles(math.sin(angle) * 0.2, -math.cos(angle) * 0.2, 0))
	end
	k:Tube("Tank", 0.45, 0.16, Vector3.new(0.24, 0.12, 0.15), "Glass")
	k:Tube("TankCore", 0.42, 0.08, Vector3.new(0.24, 0.12, 0.15), "Energy")
	k.Muzzle = Vector3.new(0, 0.05, -1.25)
	k:Magazine("Cell", -0.05, -0.14)
	k:Grip(0.3, -0.14)
	k:Stock("Skeleton", 0.5, 0.02)
	k.LeftHand = Vector3.new(0, -0.2, -0.7)
	return k
end

-- Lumen Beam: emitter dish and battery pack.
Kits.Beam = function()
	local k = newKit()
	k:Receiver(1.2, 0.36, 0.44)
	k:Rail(-0.5, 0.45, 0.24)
	k:Optic("Holo", -0.05, 0.26)
	k:Tube("Emitter", 0.45, 0.24, Vector3.new(0, 0.05, -0.82), "Panel")
	k:Tube("Dish", 0.05, 0.44, Vector3.new(0, 0.05, -1.06), "Body")
	k:Tube("Lens", 0.03, 0.28, Vector3.new(0, 0.05, -1.1), "Energy")
	k:Coils(2, -0.7, 0.18, 0.05, 0.3)
	k:Tube("Battery", 0.55, 0.16, Vector3.new(-0.25, -0.02, 0.15), "Energy")
	k:Box("BatteryClamp", Vector3.new(0.2, 0.06, 0.08), Vector3.new(-0.2, -0.02, 0.15), "Metal", nil, true)
	k.Muzzle = Vector3.new(0, 0.05, -1.14)
	k:Magazine("Cell", -0.1, -0.12)
	k:Grip(0.32, -0.12)
	k:Stock("Brace", 0.6, 0.02)
	k.LeftHand = Vector3.new(0, -0.15, -0.75)
	return k
end

-- Spark: slide-action energy pistol.
Kits.Pistol = function()
	local k = newKit()
	k:Box("Frame", Vector3.new(0.22, 0.16, 0.75), Vector3.new(0, 0, -0.12), "Body")
	k:Box("Slide", Vector3.new(0.24, 0.15, 0.8), Vector3.new(0, 0.15, -0.14), "Panel")
	k:Wedge("SlideNose", Vector3.new(0.24, 0.15, 0.12), Vector3.new(0, 0.15, -0.6), "Panel")
	for index = 0, 4 do
		k:Box("Serration", Vector3.new(0.25, 0.1, 0.02), Vector3.new(0, 0.15, 0.12 + index * 0.04), "Dark", nil, true)
	end
	k:Box("SlideStripe", Vector3.new(0.245, 0.025, 0.5), Vector3.new(0, 0.12, -0.2), "Accent")
	k:Tube("Barrel", 0.1, 0.09, Vector3.new(0, 0.13, -0.68), "Metal")
	k:Optic("Iron", -0.12, 0.22)
	k.Muzzle = Vector3.new(0, 0.13, -0.74)
	k:Magazine("Box", 0.12, -0.1, 0.14)
	k:Grip(0.12, 0.02, 14)
	k.LeftHand = Vector3.new(-0.05, -0.2, 0.1)
	k.Eject = CFrame.new(0.15, 0.17, -0.1) * CFrame.Angles(0, math.rad(90), 0)
	return k
end

-- Flicker: full-auto machine pistol with extended mag and vent rib.
Kits.MachinePistol = function()
	local k = newKit()
	k:Box("Frame", Vector3.new(0.24, 0.18, 0.85), Vector3.new(0, 0, -0.12), "Body")
	k:Box("Slide", Vector3.new(0.26, 0.15, 0.9), Vector3.new(0, 0.16, -0.14), "Panel")
	k:Wedge("SlideNose", Vector3.new(0.26, 0.15, 0.12), Vector3.new(0, 0.16, -0.65), "Panel")
	k:Box("VentRib", Vector3.new(0.1, 0.05, 0.6), Vector3.new(0, 0.26, -0.25), "Dark")
	for index = 0, 4 do
		k:Box("VentGlow", Vector3.new(0.11, 0.02, 0.05), Vector3.new(0, 0.29, -0.45 + index * 0.1), "Accent", nil, true)
	end
	k:Tube("Barrel", 0.14, 0.1, Vector3.new(0, 0.14, -0.74), "Metal")
	k:MuzzleDevice("Comp", -0.76, 0.14, 0.1)
	k:Magazine("Box", 0.12, -0.1, 0.13)
	k:Box("MagExtension", Vector3.new(0.13, 0.25, 0.22), Vector3.new(0, -0.65, 0.12), "Body").Mag = true
	k:Grip(0.12, 0.02, 12)
	k.LeftHand = Vector3.new(-0.05, -0.2, 0.1)
	k.Eject = CFrame.new(0.16, 0.17, -0.1) * CFrame.Angles(0, math.rad(90), 0)
	return k
end

-- Comet: heavy energy revolver.
Kits.Revolver = function()
	local k = newKit()
	k:Box("Frame", Vector3.new(0.22, 0.28, 0.48), Vector3.new(0, 0.08, 0.05), "Body")
	k:Wedge("FrameTop", Vector3.new(0.22, 0.08, 0.2), Vector3.new(0, 0.26, 0.2), "Body", WEDGE_BACKWARD)
	k:Tube("Barrel", 0.62, 0.15, Vector3.new(0, 0.15, -0.5), "Panel")
	k:Box("BarrelRib", Vector3.new(0.07, 0.07, 0.62), Vector3.new(0, 0.25, -0.5), "Body")
	k:Box("RibGlow", Vector3.new(0.075, 0.02, 0.5), Vector3.new(0, 0.29, -0.5), "Accent")
	k:Box("Ejector", Vector3.new(0.05, 0.05, 0.4), Vector3.new(0, 0.04, -0.45), "Metal", nil, true)
	local cylinder = k:Tube("Magazine", 0.3, 0.32, Vector3.new(0, 0.07, -0.04), "Metal")
	cylinder.Mag = true
	k:Tube("CylinderGlow", 0.31, 0.2, Vector3.new(0, 0.07, -0.04), "Energy").Mag = true
	k:Box("Hammer", Vector3.new(0.05, 0.1, 0.1), Vector3.new(0, 0.27, 0.3), "Dark", nil, true)
	k:Optic("Iron", -0.25, 0.28)
	k.Muzzle = Vector3.new(0, 0.15, -0.83)
	k:Grip(0.3, -0.04, 20)
	k.LeftHand = Vector3.new(-0.05, -0.25, 0.25)
	k.Eject = CFrame.new(0.12, 0.08, -0.04) * CFrame.Angles(0, math.rad(90), 0)
	return k
end

--[[ Assembly ]]

local function colorFor(role: string, accent: Color3, palette): Color3
	if role == "Body" then
		return palette.Body
	elseif role == "Panel" then
		return palette.Panel
	elseif role == "Metal" then
		return METAL
	elseif role == "Dark" then
		return DARK
	elseif role == "Grip" then
		return GRIP
	elseif role == "Glass" then
		return accent:Lerp(Color3.new(1, 1, 1), 0.55)
	end
	return accent
end

local function materialFor(role: string, bodyMaterial: Enum.Material): Enum.Material
	if role == "Accent" then
		return Enum.Material.Neon
	elseif role == "Energy" then
		return Enum.Material.ForceField
	elseif role == "Glass" then
		return Enum.Material.Glass
	elseif role == "Body" then
		return bodyMaterial
	elseif role == "Metal" then
		return Enum.Material.Metal
	elseif role == "Grip" then
		return Enum.Material.Fabric
	end
	return Enum.Material.SmoothPlastic
end

function WeaponModelBuilder.GetKitNames(): { string }
	local names = {}
	for name in Kits do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--[[
	options:
	  Skin       CosmeticConfig weapon skin item (Color, Material) or nil
	  Scale      uniform scale (default 1)
	  Anchored   true for client viewmodels (moved by CFrame every frame);
	             false for world models (welded to the core)
	  LowDetail  skip tiny detail parts (world models)
]]
function WeaponModelBuilder.Build(weapon, options): (Model, Info)
	local scale = options.Scale or 1
	local builder = Kits[weapon.Viewmodel.Kit] or Kits.Rifle
	local kit = builder()
	local skin = options.Skin
	local palette = table.clone(weapon.Viewmodel.Palette or DEFAULT_PALETTE)
	if skin and skin.Color then
		palette.Body = skin.Color
	end
	local bodyMaterial = if skin and skin.Material then (Enum.Material :: any)[skin.Material] else Enum.Material.SmoothPlastic
	local accent = weapon.Viewmodel.Color

	local model = Instance.new("Model")
	model.Name = weapon.Id

	local body = Instance.new("Part")
	body.Name = "Core"
	body.Size = Vector3.new(0.2, 0.2, 0.2) * scale
	body.Transparency = 1
	body.CFrame = CFrame.identity

	local info: Info = {
		Body = body,
		Muzzle = CFrame.new(kit.Muzzle * scale),
		Eject = CFrame.new(kit.Eject.Position * scale) * kit.Eject.Rotation,
		Magazine = nil,
		MagazineRest = nil,
		MagazineParts = {},
		Glow = {},
		RightHand = kit.RightHand * scale,
		LeftHand = kit.LeftHand * scale,
		Sight = kit.Sight * scale,
	}

	local parts = { body }
	for _, spec in kit.Specs do
		if options.LowDetail and spec.Detail then
			continue
		end
		local part: BasePart
		if spec.Shape == "Wedge" then
			part = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			if spec.Shape == "Cylinder" then
				block.Shape = Enum.PartType.Cylinder
			elseif spec.Shape == "Ball" then
				block.Shape = Enum.PartType.Ball
			end
			part = block
		end
		part.Name = spec.Name
		part.Size = spec.Size * scale
		part.CFrame = CFrame.new(spec.CFrame.Position * scale) * spec.CFrame.Rotation
		part.Color = colorFor(spec.Role, accent, palette)
		part.Material = materialFor(spec.Role, bodyMaterial)
		if spec.Role == "Glass" then
			part.Transparency = 0.45
		elseif spec.Role == "Energy" then
			part.Transparency = 0.05
		end
		part.Parent = model
		table.insert(parts, part)
		if spec.Role == "Accent" or spec.Role == "Energy" then
			table.insert(info.Glow, part)
		end
		if spec.Mag then
			table.insert(info.MagazineParts, { Part = part, Rest = part.CFrame })
			if spec.Name == "Magazine" then
				info.Magazine = part
				info.MagazineRest = part.CFrame
			end
		end
	end
	body.Parent = model

	for _, part in parts do
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.Anchored = options.Anchored == true
		if not part.Anchored and part ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.PrimaryPart = body
	return model, info
end

return WeaponModelBuilder
