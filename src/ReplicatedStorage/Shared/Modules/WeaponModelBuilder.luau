--[[
	WeaponModelBuilder
	Builds the PLACEHOLDER weapon models from primitive parts. Every weapon has
	a "kit" (WeaponConfig.Viewmodel.Kit) describing a distinct silhouette:
	rifles get stocks and scopes, the launcher gets a big plasma chamber, the
	tesla gets prongs, and so on.

	The same builder is used for the first-person viewmodel (client) and the
	third-person world model (server), so both views match.

	Model space: origin = centre of the receiver, -Z = forward (muzzle).
	Returns a Model plus info:
	  Body      the PrimaryPart
	  Muzzle    CFrame offset of the muzzle relative to Body
	  Magazine  part animated during reloads (may be nil)
	  Glow      neon parts (brightened while charging / firing)

	Replace with real models by adding ReplicatedStorage/Assets/Viewmodels/<Id>
	(client) or ServerStorage/Weapons/<Id> (server).
]]

local WeaponModelBuilder = {}

local DEFAULT_BODY = Color3.fromRGB(42, 45, 62)
local TRIM = Color3.fromRGB(95, 102, 128)
local DARK = Color3.fromRGB(20, 22, 30)
local Z_ALIGN = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; turn them to Z

export type Info = {
	Body: BasePart,
	Muzzle: CFrame,
	Magazine: BasePart?,
	MagazineRest: CFrame?,
	Glow: { BasePart },
}

type Spec = {
	Name: string,
	Shape: string?, -- "Block" | "Cylinder" | "Ball" | "Wedge"
	Size: Vector3,
	CFrame: CFrame,
	Role: string, -- "Body" | "Trim" | "Dark" | "Accent" | "Glass"
}

local function box(name: string, size: Vector3, position: Vector3, role: string, rotation: CFrame?): Spec
	return { Name = name, Size = size, CFrame = CFrame.new(position) * (rotation or CFrame.identity), Role = role }
end

-- Cylinder along Z (length, diameter).
local function tube(name: string, length: number, diameter: number, position: Vector3, role: string): Spec
	return { Name = name, Shape = "Cylinder", Size = Vector3.new(length, diameter, diameter), CFrame = CFrame.new(position) * Z_ALIGN, Role = role }
end

local function ball(name: string, diameter: number, position: Vector3, role: string): Spec
	return { Name = name, Shape = "Ball", Size = Vector3.one * diameter, CFrame = CFrame.new(position), Role = role }
end

local function rings(list: { Spec }, count: number, startZ: number, step: number, y: number, diameter: number)
	for index = 0, count - 1 do
		table.insert(list, tube("Ring", 0.05, diameter, Vector3.new(0, y, startZ - index * step), "Accent"))
	end
end

local function sideStrips(list: { Spec }, halfWidth: number, y: number, length: number, z: number)
	table.insert(list, box("Strip", Vector3.new(0.03, 0.07, length), Vector3.new(halfWidth, y, z), "Accent"))
	table.insert(list, box("Strip", Vector3.new(0.03, 0.07, length), Vector3.new(-halfWidth, y, z), "Accent"))
end

local function grip(list: { Spec }, z: number, height: number?)
	table.insert(list, box("Grip", Vector3.new(0.16, height or 0.4, 0.2), Vector3.new(0, -0.32, z), "Body", CFrame.Angles(math.rad(14), 0, 0)))
end

local function sight(list: { Spec }, z: number, y: number)
	table.insert(list, box("Sight", Vector3.new(0.12, 0.12, 0.22), Vector3.new(0, y, z), "Dark"))
	table.insert(list, box("SightLens", Vector3.new(0.09, 0.09, 0.02), Vector3.new(0, y, z - 0.12), "Glass"))
end

local function scope(list: { Spec }, z: number, y: number, length: number)
	table.insert(list, tube("Scope", length, 0.2, Vector3.new(0, y, z), "Dark"))
	table.insert(list, tube("ScopeRing", 0.06, 0.26, Vector3.new(0, y, z - length * 0.3), "Trim"))
	table.insert(list, tube("ScopeRing", 0.06, 0.26, Vector3.new(0, y, z + length * 0.3), "Trim"))
	table.insert(list, tube("ScopeLens", 0.02, 0.17, Vector3.new(0, y, z - length / 2), "Glass"))
	table.insert(list, box("ScopeMount", Vector3.new(0.08, 0.1, 0.3), Vector3.new(0, y - 0.13, z), "Trim"))
end

-- Each kit returns (parts, muzzle position, magazine part name or nil).
local Kits: { [string]: () -> ({ Spec }, Vector3) } = {}

Kits.Rifle = function()
	local p = {
		box("Body", Vector3.new(0.32, 0.42, 1.4), Vector3.zero, "Body"),
		box("Rail", Vector3.new(0.18, 0.08, 1.2), Vector3.new(0, 0.25, -0.05), "Trim"),
		box("Shroud", Vector3.new(0.27, 0.27, 0.6), Vector3.new(0, 0.07, -0.95), "Trim"),
		tube("Barrel", 0.75, 0.14, Vector3.new(0, 0.07, -1.35), "Dark"),
		box("Stock", Vector3.new(0.22, 0.32, 0.6), Vector3.new(0, -0.04, 0.98), "Body"),
		box("StockPad", Vector3.new(0.24, 0.36, 0.08), Vector3.new(0, -0.04, 1.3), "Dark"),
		box("Magazine", Vector3.new(0.18, 0.46, 0.28), Vector3.new(0, -0.4, -0.28), "Dark", CFrame.Angles(math.rad(-8), 0, 0)),
		box("MagGlow", Vector3.new(0.2, 0.05, 0.3), Vector3.new(0, -0.22, -0.28), "Accent"),
	}
	grip(p, 0.3)
	sight(p, -0.25, 0.36)
	sideStrips(p, 0.165, 0.05, 1.0, -0.1)
	rings(p, 2, -1.45, 0.16, 0.07, 0.22)
	return p, Vector3.new(0, 0.07, -1.75)
end

Kits.Burst = function()
	local p = {
		box("Body", Vector3.new(0.36, 0.46, 1.3), Vector3.zero, "Body"),
		box("Top", Vector3.new(0.3, 0.14, 1.1), Vector3.new(0, 0.29, -0.1), "Trim"),
		tube("BarrelA", 0.7, 0.1, Vector3.new(0.07, 0.1, -1.0), "Dark"),
		tube("BarrelB", 0.7, 0.1, Vector3.new(-0.07, 0.1, -1.0), "Dark"),
		tube("BarrelC", 0.7, 0.1, Vector3.new(0, -0.03, -1.0), "Dark"),
		box("Bullpup", Vector3.new(0.3, 0.42, 0.55), Vector3.new(0, -0.05, 0.9), "Body"),
		box("Magazine", Vector3.new(0.2, 0.38, 0.32), Vector3.new(0, -0.36, 0.75), "Dark"),
		box("MagGlow", Vector3.new(0.22, 0.05, 0.34), Vector3.new(0, -0.2, 0.75), "Accent"),
		box("Fin", Vector3.new(0.03, 0.18, 0.5), Vector3.new(0, 0.42, -0.4), "Accent"),
	}
	grip(p, 0.15)
	sight(p, 0.1, 0.42)
	sideStrips(p, 0.185, 0.0, 0.9, -0.2)
	return p, Vector3.new(0, 0.06, -1.4)
end

Kits.Shotgun = function()
	local p = {
		box("Body", Vector3.new(0.46, 0.46, 1.1), Vector3.zero, "Body"),
		tube("BarrelL", 0.9, 0.2, Vector3.new(0.11, 0.08, -0.95), "Dark"),
		tube("BarrelR", 0.9, 0.2, Vector3.new(-0.11, 0.08, -0.95), "Dark"),
		tube("MuzzleL", 0.08, 0.24, Vector3.new(0.11, 0.08, -1.4), "Accent"),
		tube("MuzzleR", 0.08, 0.24, Vector3.new(-0.11, 0.08, -1.4), "Accent"),
		box("Pump", Vector3.new(0.4, 0.2, 0.45), Vector3.new(0, -0.12, -0.8), "Trim"),
		box("Stock", Vector3.new(0.26, 0.36, 0.7), Vector3.new(0, -0.08, 0.85), "Body", CFrame.Angles(math.rad(-6), 0, 0)),
		box("Magazine", Vector3.new(0.3, 0.16, 0.35), Vector3.new(0, -0.3, -0.1), "Dark"),
		box("Cell", Vector3.new(0.12, 0.12, 0.3), Vector3.new(0.25, 0.05, 0.1), "Accent"),
		box("Cell", Vector3.new(0.12, 0.12, 0.3), Vector3.new(-0.25, 0.05, 0.1), "Accent"),
	}
	grip(p, 0.35)
	sight(p, -0.2, 0.3)
	return p, Vector3.new(0, 0.08, -1.45)
end

Kits.Drum = function()
	local p = {
		box("Body", Vector3.new(0.44, 0.44, 1.2), Vector3.zero, "Body"),
		tube("Barrel", 0.7, 0.22, Vector3.new(0, 0.06, -0.95), "Dark"),
		tube("Choke", 0.12, 0.3, Vector3.new(0, 0.06, -1.32), "Accent"),
		tube("Magazine", 0.3, 0.5, Vector3.new(0, -0.35, -0.15), "Dark"),
		tube("DrumGlow", 0.32, 0.3, Vector3.new(0, -0.35, -0.15), "Accent"),
		box("Stock", Vector3.new(0.24, 0.34, 0.6), Vector3.new(0, -0.05, 0.9), "Body"),
		box("Top", Vector3.new(0.2, 0.1, 0.9), Vector3.new(0, 0.27, -0.1), "Trim"),
	}
	grip(p, 0.35)
	sight(p, -0.15, 0.36)
	sideStrips(p, 0.225, 0.08, 0.8, -0.1)
	return p, Vector3.new(0, 0.06, -1.4)
end

Kits.Sniper = function()
	local p = {
		box("Body", Vector3.new(0.3, 0.4, 1.5), Vector3.zero, "Body"),
		tube("Barrel", 1.5, 0.12, Vector3.new(0, 0.06, -1.5), "Dark"),
		box("BarrelFin", Vector3.new(0.04, 0.2, 1.0), Vector3.new(0, 0.18, -1.3), "Trim"),
		tube("Brake", 0.2, 0.2, Vector3.new(0, 0.06, -2.25), "Trim"),
		box("Stock", Vector3.new(0.2, 0.36, 0.8), Vector3.new(0, -0.06, 1.1), "Body"),
		box("Cheek", Vector3.new(0.18, 0.1, 0.4), Vector3.new(0, 0.18, 1.0), "Dark"),
		box("Magazine", Vector3.new(0.16, 0.3, 0.3), Vector3.new(0, -0.3, -0.2), "Dark"),
		box("Bipod", Vector3.new(0.06, 0.3, 0.06), Vector3.new(0.08, -0.15, -1.8), "Trim", CFrame.Angles(0, 0, math.rad(15))),
		box("Bipod", Vector3.new(0.06, 0.3, 0.06), Vector3.new(-0.08, -0.15, -1.8), "Trim", CFrame.Angles(0, 0, math.rad(-15))),
	}
	grip(p, 0.35)
	scope(p, -0.15, 0.38, 0.9)
	sideStrips(p, 0.155, 0.02, 1.2, 0)
	rings(p, 3, -1.75, 0.18, 0.06, 0.18)
	return p, Vector3.new(0, 0.06, -2.4)
end

Kits.Marksman = function()
	local p = {
		box("Body", Vector3.new(0.34, 0.44, 1.4), Vector3.zero, "Body"),
		box("Handguard", Vector3.new(0.28, 0.3, 0.9), Vector3.new(0, 0.05, -1.05), "Trim"),
		tube("Barrel", 0.6, 0.13, Vector3.new(0, 0.06, -1.75), "Dark"),
		box("Stock", Vector3.new(0.22, 0.34, 0.6), Vector3.new(0, -0.05, 0.98), "Body"),
		box("Magazine", Vector3.new(0.18, 0.36, 0.24), Vector3.new(0, -0.36, -0.25), "Dark"),
		box("MagGlow", Vector3.new(0.2, 0.05, 0.26), Vector3.new(0, -0.2, -0.25), "Accent"),
	}
	grip(p, 0.3)
	scope(p, -0.2, 0.37, 0.6)
	sideStrips(p, 0.145, 0.05, 0.8, -1.0)
	return p, Vector3.new(0, 0.06, -2.1)
end

Kits.SMG = function()
	local p = {
		box("Body", Vector3.new(0.34, 0.44, 1.0), Vector3.zero, "Body"),
		tube("Barrel", 0.45, 0.13, Vector3.new(0, 0.08, -0.7), "Dark"),
		box("Vent", Vector3.new(0.26, 0.2, 0.35), Vector3.new(0, 0.08, -0.55), "Trim"),
		box("Magazine", Vector3.new(0.14, 0.6, 0.18), Vector3.new(0, -0.45, -0.25), "Dark"),
		box("MagGlow", Vector3.new(0.16, 0.05, 0.2), Vector3.new(0, -0.24, -0.25), "Accent"),
		box("Stock", Vector3.new(0.06, 0.25, 0.55), Vector3.new(0.1, -0.05, 0.75), "Trim"),
		box("Stock", Vector3.new(0.06, 0.25, 0.55), Vector3.new(-0.1, -0.05, 0.75), "Trim"),
		box("ForeGrip", Vector3.new(0.12, 0.3, 0.12), Vector3.new(0, -0.32, -0.6), "Body"),
	}
	grip(p, 0.25)
	sight(p, -0.1, 0.3)
	sideStrips(p, 0.175, 0.12, 0.7, -0.1)
	return p, Vector3.new(0, 0.08, -0.95)
end

Kits.Launcher = function()
	local p = {
		tube("Body", 1.4, 0.5, Vector3.zero, "Body"),
		tube("Front", 0.25, 0.6, Vector3.new(0, 0, -0.8), "Trim"),
		tube("Bore", 0.06, 0.4, Vector3.new(0, 0, -0.93), "Dark"),
		ball("Chamber", 0.42, Vector3.new(0, 0.32, 0.05), "Accent"),
		box("ChamberCage", Vector3.new(0.5, 0.06, 0.5), Vector3.new(0, 0.32, 0.05), "Trim"),
		tube("Back", 0.2, 0.55, Vector3.new(0, 0, 0.75), "Dark"),
		box("Magazine", Vector3.new(0.26, 0.3, 0.3), Vector3.new(0, -0.38, 0.25), "Dark"),
		box("CellGlow", Vector3.new(0.28, 0.05, 0.32), Vector3.new(0, -0.22, 0.25), "Accent"),
	}
	grip(p, 0.35, 0.45)
	sight(p, -0.3, 0.33)
	rings(p, 3, -0.45, 0.2, 0, 0.56)
	return p, Vector3.new(0, 0, -1.0)
end

Kits.Charge = function()
	local p = {
		box("Body", Vector3.new(0.34, 0.44, 1.5), Vector3.zero, "Body"),
		tube("Barrel", 1.1, 0.16, Vector3.new(0, 0.06, -1.25), "Dark"),
		box("Stock", Vector3.new(0.22, 0.34, 0.6), Vector3.new(0, -0.05, 1.0), "Body"),
		box("Magazine", Vector3.new(0.2, 0.3, 0.4), Vector3.new(0, -0.32, 0.1), "Dark"),
		box("Capacitor", Vector3.new(0.14, 0.14, 0.6), Vector3.new(0.2, 0.15, -0.3), "Accent"),
		box("Capacitor", Vector3.new(0.14, 0.14, 0.6), Vector3.new(-0.2, 0.15, -0.3), "Accent"),
	}
	grip(p, 0.35)
	scope(p, -0.1, 0.36, 0.5)
	rings(p, 5, -0.85, 0.16, 0.06, 0.26)
	return p, Vector3.new(0, 0.06, -1.85)
end

Kits.Tesla = function()
	local p = {
		box("Body", Vector3.new(0.44, 0.48, 1.1), Vector3.zero, "Body"),
		tube("Coil", 0.6, 0.3, Vector3.new(0, 0.05, -0.75), "Trim"),
		ball("Core", 0.26, Vector3.new(0, 0.05, -1.12), "Accent"),
		box("Prong", Vector3.new(0.05, 0.05, 0.5), Vector3.new(0.17, 0.2, -1.05), "Accent", CFrame.Angles(math.rad(10), math.rad(-10), 0)),
		box("Prong", Vector3.new(0.05, 0.05, 0.5), Vector3.new(-0.17, 0.2, -1.05), "Accent", CFrame.Angles(math.rad(10), math.rad(10), 0)),
		box("Prong", Vector3.new(0.05, 0.05, 0.5), Vector3.new(0, -0.14, -1.05), "Accent", CFrame.Angles(math.rad(-12), 0, 0)),
		box("Magazine", Vector3.new(0.22, 0.32, 0.3), Vector3.new(0, -0.36, 0.05), "Dark"),
		tube("Tank", 0.5, 0.18, Vector3.new(0.25, 0.1, 0.25), "Glass"),
		box("Stock", Vector3.new(0.22, 0.32, 0.5), Vector3.new(0, -0.05, 0.75), "Body"),
	}
	grip(p, 0.3)
	rings(p, 3, -0.55, 0.15, 0.05, 0.36)
	return p, Vector3.new(0, 0.05, -1.28)
end

Kits.Beam = function()
	local p = {
		box("Body", Vector3.new(0.42, 0.46, 1.3), Vector3.zero, "Body"),
		tube("Emitter", 0.5, 0.26, Vector3.new(0, 0.05, -0.85), "Trim"),
		tube("Dish", 0.06, 0.46, Vector3.new(0, 0.05, -1.12), "Trim"),
		tube("Lens", 0.04, 0.3, Vector3.new(0, 0.05, -1.16), "Accent"),
		box("Magazine", Vector3.new(0.2, 0.34, 0.34), Vector3.new(0, -0.36, -0.1), "Dark"),
		tube("Battery", 0.6, 0.16, Vector3.new(0.24, -0.05, 0.2), "Accent"),
		box("Stock", Vector3.new(0.24, 0.34, 0.5), Vector3.new(0, -0.05, 0.85), "Body"),
	}
	grip(p, 0.3)
	sight(p, -0.2, 0.32)
	return p, Vector3.new(0, 0.05, -1.2)
end

Kits.Pistol = function()
	local p = {
		box("Body", Vector3.new(0.24, 0.26, 0.85), Vector3.new(0, 0.05, -0.1), "Body"),
		box("Slide", Vector3.new(0.26, 0.12, 0.8), Vector3.new(0, 0.22, -0.12), "Trim"),
		tube("Barrel", 0.12, 0.1, Vector3.new(0, 0.12, -0.58), "Accent"),
		box("Magazine", Vector3.new(0.16, 0.32, 0.18), Vector3.new(0, -0.28, 0.12), "Dark", CFrame.Angles(math.rad(12), 0, 0)),
		box("Grip", Vector3.new(0.18, 0.4, 0.24), Vector3.new(0, -0.2, 0.15), "Body", CFrame.Angles(math.rad(12), 0, 0)),
	}
	sideStrips(p, 0.125, 0.05, 0.6, -0.1)
	return p, Vector3.new(0, 0.12, -0.66)
end

Kits.MachinePistol = function()
	local p = {
		box("Body", Vector3.new(0.26, 0.3, 0.9), Vector3.new(0, 0.05, -0.1), "Body"),
		box("Slide", Vector3.new(0.28, 0.12, 0.85), Vector3.new(0, 0.24, -0.12), "Trim"),
		tube("Barrel", 0.2, 0.12, Vector3.new(0, 0.12, -0.62), "Dark"),
		box("Magazine", Vector3.new(0.14, 0.55, 0.16), Vector3.new(0, -0.38, 0.1), "Dark", CFrame.Angles(math.rad(10), 0, 0)),
		box("MagGlow", Vector3.new(0.16, 0.05, 0.18), Vector3.new(0, -0.62, 0.14), "Accent"),
		box("Grip", Vector3.new(0.18, 0.36, 0.24), Vector3.new(0, -0.18, 0.12), "Body", CFrame.Angles(math.rad(10), 0, 0)),
		box("Vent", Vector3.new(0.3, 0.05, 0.4), Vector3.new(0, 0.32, -0.2), "Accent"),
	}
	return p, Vector3.new(0, 0.12, -0.74)
end

Kits.Revolver = function()
	local p = {
		box("Frame", Vector3.new(0.24, 0.3, 0.5), Vector3.new(0, 0.1, 0.05), "Body"),
		tube("Barrel", 0.65, 0.16, Vector3.new(0, 0.16, -0.5), "Trim"),
		box("BarrelRib", Vector3.new(0.06, 0.08, 0.6), Vector3.new(0, 0.27, -0.48), "Accent"),
		tube("Magazine", 0.3, 0.32, Vector3.new(0, 0.08, -0.05), "Dark"),
		tube("CylinderGlow", 0.32, 0.2, Vector3.new(0, 0.08, -0.05), "Accent"),
		box("Grip", Vector3.new(0.2, 0.42, 0.24), Vector3.new(0, -0.22, 0.25), "Body", CFrame.Angles(math.rad(18), 0, 0)),
		box("Hammer", Vector3.new(0.06, 0.1, 0.1), Vector3.new(0, 0.28, 0.28), "Dark"),
	}
	return p, Vector3.new(0, 0.16, -0.85)
end

local function colorFor(role: string, accent: Color3, bodyColor: Color3): Color3
	if role == "Body" then
		return bodyColor
	elseif role == "Trim" then
		return TRIM
	elseif role == "Dark" then
		return DARK
	elseif role == "Glass" then
		return accent:Lerp(Color3.new(1, 1, 1), 0.4)
	end
	return accent
end

local function materialFor(role: string, bodyMaterial: Enum.Material): Enum.Material
	if role == "Accent" then
		return Enum.Material.Neon
	elseif role == "Glass" then
		return Enum.Material.Glass
	elseif role == "Body" then
		return bodyMaterial
	elseif role == "Trim" then
		return Enum.Material.Metal
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
	             false for world models (welded to the body)
]]
function WeaponModelBuilder.Build(weapon, options): (Model, Info)
	local scale = options.Scale or 1
	local kitBuilder = Kits[weapon.Viewmodel.Kit] or Kits.Rifle
	local specs, muzzlePosition = kitBuilder()
	local skin = options.Skin
	local bodyColor = if skin and skin.Color then skin.Color else DEFAULT_BODY
	local bodyMaterial = if skin and skin.Material then (Enum.Material :: any)[skin.Material] else Enum.Material.SmoothPlastic
	local accent = weapon.Viewmodel.Color

	local model = Instance.new("Model")
	model.Name = weapon.Id

	-- Invisible core so the pivot is always the receiver centre.
	local body = Instance.new("Part")
	body.Name = "Core"
	body.Size = Vector3.new(0.2, 0.2, 0.2) * scale
	body.Transparency = 1
	body.CFrame = CFrame.identity

	local info: Info = {
		Body = body,
		Muzzle = CFrame.new(muzzlePosition * scale),
		Magazine = nil,
		MagazineRest = nil,
		Glow = {},
	}

	local parts = { body }
	for _, spec in specs do
		local part = Instance.new("Part")
		part.Name = spec.Name
		if spec.Shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif spec.Shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.Size = spec.Size * scale
		part.CFrame = CFrame.new(spec.CFrame.Position * scale) * spec.CFrame.Rotation
		part.Color = colorFor(spec.Role, accent, bodyColor)
		part.Material = materialFor(spec.Role, bodyMaterial)
		if spec.Role == "Glass" then
			part.Transparency = 0.35
		end
		part.Parent = model
		table.insert(parts, part)
		if spec.Role == "Accent" then
			table.insert(info.Glow, part)
		end
		if spec.Name == "Magazine" then
			info.Magazine = part
			info.MagazineRest = part.CFrame
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
