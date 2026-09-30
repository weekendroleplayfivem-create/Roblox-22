--!strict
-- Realistic city architecture built from parts:
--   * glass skyscrapers with setbacks, curtain-wall mullions, a stone lobby, roof machinery,
--     antennas with aircraft beacons and helipads
--   * mid-rise offices with ribbon windows and rooftop billboards
--   * brick apartment blocks with punched windows, cornices, fire escapes and water tanks
--   * low-rise shops with storefront glass, awnings and shop signs
--   * sidewalks with curbs, trees, hydrants, bins, benches and bus stops
--   * crosswalks, stop lines and traffic lights at intersections
-- Only building cores go in the Buildings folder (collision, AI line of sight, camera);
-- all decoration goes in Props with collision and queries off.

local Architecture = {}

export type Toggle = {
	part: BasePart,
	dayMaterial: Enum.Material,
	dayColor: Color3,
	nightMaterial: Enum.Material,
	nightColor: Color3,
}

local rng = Random.new(7)
local buildings: Folder
local props: Folder
local signals: Folder
local toggles: { Toggle } = {}
local SURFACE = 0.5

function Architecture.Init(buildingsFolder: Folder, propsFolder: Folder, signalsFolder: Folder, surface: number)
	buildings = buildingsFolder
	props = propsFolder
	signals = signalsFolder
	SURFACE = surface
end

function Architecture.Toggles(): { Toggle }
	return toggles
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- Decorative anchored part: no collision, ignored by raycasts.
local function deco(props_: { [string]: any }, parent: Instance?, className: string?): BasePart
	local p = Instance.new((className or "Part") :: any) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props_ do
		(p :: any)[k] = v
	end
	p.Parent = parent or props
	return p
end

-- Solid building volume: collides and blocks line of sight.
local function core(cx: number, cz: number, sx: number, sz: number, y0: number, y1: number, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = "Building"
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(sx, y1 - y0, sz)
	p.CFrame = CFrame.new(cx, (y0 + y1) / 2, cz)
	p.Color = color
	p.Material = material
	p.Parent = buildings
	return p
end

local function lightAtNight(p: BasePart, lit: boolean, nightColor: Color3)
	table.insert(toggles, {
		part = p,
		dayMaterial = p.Material,
		dayColor = p.Color,
		nightMaterial = if lit then Enum.Material.Neon else p.Material,
		nightColor = if lit then nightColor else p.Color:Lerp(rgb(10, 12, 16), 0.6),
	})
end

type FacadeOpts = {
	floorH: number,
	bandH: number,
	bay: number,
	pierW: number,
	depth: number,
	color: Color3,
	material: Enum.Material,
	noBands: boolean?,
}

-- Floor bands wrap all four sides in one part; piers are placed per face. What shows through
-- the gaps is the (glass) core, which reads as a grid of windows.
local function facade(cx: number, cz: number, sx: number, sz: number, y0: number, y1: number, o: FacadeOpts)
	local h = y1 - y0
	if not o.noBands then
		local y = y0 + o.floorH
		while y < y1 - 1 do
			deco({ Name = "Band", Size = Vector3.new(sx + o.depth * 2, o.bandH, sz + o.depth * 2), CFrame = CFrame.new(cx, y, cz), Color = o.color, Material = o.material })
			y += o.floorH
		end
	end
	for _, axis in { "x", "z" } do
		local len = if axis == "x" then sz else sx
		local n = math.max(1, math.floor(len / o.bay))
		local step = len / n
		for k = 0, n do
			local off = -len / 2 + k * step
			for _, side in { -1, 1 } do
				if axis == "x" then
					deco({ Name = "Pier", Size = Vector3.new(o.depth, h, o.pierW), CFrame = CFrame.new(cx + side * (sx / 2 + o.depth / 2), y0 + h / 2, cz + off), Color = o.color, Material = o.material })
				else
					deco({ Name = "Pier", Size = Vector3.new(o.pierW, h, o.depth), CFrame = CFrame.new(cx + off, y0 + h / 2, cz + side * (sz / 2 + o.depth / 2)), Color = o.color, Material = o.material })
				end
			end
		end
	end
end

-- Thin wall around the edge of a flat roof.
local function parapet(cx: number, cz: number, sx: number, sz: number, y: number, color: Color3, material: Enum.Material)
	local hgt = 2.2
	for _, side in { -1, 1 } do
		deco({ Name = "Parapet", Size = Vector3.new(sx + 0.6, hgt, 0.6), CFrame = CFrame.new(cx, y + hgt / 2, cz + side * (sz / 2)), Color = color, Material = material })
		deco({ Name = "Parapet", Size = Vector3.new(0.6, hgt, sz + 0.6), CFrame = CFrame.new(cx + side * (sx / 2), y + hgt / 2, cz), Color = color, Material = material })
	end
	deco({ Name = "Roof", Size = Vector3.new(sx - 0.2, 0.3, sz - 0.2), CFrame = CFrame.new(cx, y + 0.15, cz), Color = rgb(70, 70, 74), Material = Enum.Material.Asphalt })
end

local function hvac(cx: number, cz: number, sx: number, sz: number, y: number, count: number)
	for _ = 1, count do
		local w, d = rng:NextNumber(5, 12), rng:NextNumber(4, 9)
		local x = cx + rng:NextNumber(-sx / 2 + 7, sx / 2 - 7)
		local z = cz + rng:NextNumber(-sz / 2 + 7, sz / 2 - 7)
		deco({ Name = "HVAC", Size = Vector3.new(w, 3.5, d), CFrame = CFrame.new(x, y + 1.75, z), Color = rgb(165, 168, 170), Material = Enum.Material.Metal })
		deco({ Name = "Fan", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.6, 2.6), CFrame = CFrame.new(x, y + 3.6, z) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(60, 62, 64), Material = Enum.Material.Metal })
	end
end

local function surfaceText(target: BasePart, text: string, color: Color3, bright: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = if bright then 0 else 1
	gui.Brightness = if bright then 1.6 else 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = color
	t.Parent = gui
	gui.Parent = target
end

-- A part standing on face `n` of a building, with its Front face pointing outwards.
local function onFace(center: Vector3, n: Vector3, halfDepth: number, y: number, out: number): CFrame
	local pos = Vector3.new(center.X, y, center.Z) + n * (halfDepth + out)
	return CFrame.lookAt(pos, pos + n)
end

local SHOP_NAMES = { "PHARMACY", "CAFE", "PIZZA", "BARBER", "DINER", "LAUNDRY", "BANK", "24/7 MARKET", "TACOS", "BOOKS", "GYM", "AUTO PARTS", "SUSHI", "FLOWERS", "ELECTRONICS", "BAKERY", "NOODLES", "PAWN SHOP" }
local AWNING_COLORS = { rgb(150, 28, 34), rgb(28, 88, 58), rgb(28, 58, 125), rgb(200, 140, 30), rgb(55, 55, 58), rgb(120, 40, 90) }
local SIGN_COLORS = { rgb(255, 240, 200), rgb(255, 90, 80), rgb(120, 220, 255), rgb(255, 210, 90), rgb(140, 255, 160) }

-- Ground floor shopfronts on the street-facing sides.
local function storefronts(center: Vector3, sx: number, sz: number, outward: { Vector3 }, h: number)
	for _, n in outward do
		local half = if n.X ~= 0 then sx / 2 else sz / 2
		local width = if n.X ~= 0 then sz else sx
		local segments = if width > 70 then 2 else 1
		for k = 1, segments do
			local w = width / segments - 6
			local along = (k - (segments + 1) / 2) * (width / segments)
			local lateral = if n.X ~= 0 then Vector3.new(0, 0, along) else Vector3.new(along, 0, 0)
			local base = center + lateral
			local awning = deco({ Name = "Awning", Size = Vector3.new(w, 0.3, 5), CFrame = onFace(base, n, half, SURFACE + h - 1.5, 2.3) * CFrame.Angles(math.rad(-18), 0, 0), Color = pick(AWNING_COLORS), Material = Enum.Material.Fabric })
			local _ = awning
			local sign = deco({ Name = "ShopSign", Size = Vector3.new(w * 0.7, 2.4, 0.3), CFrame = onFace(base, n, half, SURFACE + h + 1.4, 0.2), Color = rgb(22, 22, 26) })
			surfaceText(sign, pick(SHOP_NAMES), pick(SIGN_COLORS), true)
		end
	end
end

---------------------------------------------------------------------------
-- Building types
---------------------------------------------------------------------------
local GLASS = { rgb(62, 86, 104), rgb(44, 62, 78), rgb(70, 92, 92), rgb(96, 84, 62), rgb(52, 58, 66), rgb(80, 100, 118) }
local WARM_NIGHT = { rgb(118, 96, 62), rgb(105, 92, 70), rgb(96, 100, 110), rgb(120, 104, 78) }

local function glassTower(center: Vector3, sx: number, sz: number, h: number, outward: { Vector3 })
	local cx, cz = center.X, center.Z
	local glass = pick(GLASS)
	local lit = rng:NextNumber() < 0.75
	local night = pick(WARM_NIGHT)
	local metal = pick({ rgb(70, 75, 82), rgb(150, 155, 160), rgb(40, 42, 46) })
	local stone = rgb(196, 190, 180)

	-- lobby / podium
	local podiumH = 16
	local lobby = core(cx, cz, sx, sz, SURFACE, SURFACE + podiumH, rgb(38, 44, 52), Enum.Material.Glass)
	lobby.Reflectance = 0.2
	lightAtNight(lobby, true, rgb(140, 120, 90))
	deco({ Name = "Plinth", Size = Vector3.new(sx + 0.8, 2, sz + 0.8), CFrame = CFrame.new(cx, SURFACE + 1, cz), Color = stone, Material = Enum.Material.Marble })
	facade(cx, cz, sx, sz, SURFACE, SURFACE + podiumH, { floorH = 99, bandH = 0, bay = 16, pierW = 1.8, depth = 0.6, color = stone, material = Enum.Material.Marble, noBands = true })
	deco({ Name = "PodiumCap", Size = Vector3.new(sx + 1.2, 1.6, sz + 1.2), CFrame = CFrame.new(cx, SURFACE + podiumH, cz), Color = stone, Material = Enum.Material.Marble })
	local n = outward[1]
	local half = if n.X ~= 0 then sx / 2 else sz / 2
	local canopy = deco({ Name = "Canopy", Size = Vector3.new(24, 0.8, 8), CFrame = onFace(center, n, half, SURFACE + 10, 4), Color = metal, Material = Enum.Material.Metal })
	local _ = canopy

	-- tiers with setbacks
	local rest = h - podiumH
	local fractions: { number } = if h > 200 then { 0.6, 0.28, 0.12 } else { 0.72, 0.28 }
	local shrink = { 1, 0.8, 0.6 }
	local y = SURFACE + podiumH
	local tsx, tsz = sx, sz
	for k, frac in fractions do
		tsx, tsz = sx * shrink[k], sz * shrink[k]
		local th = rest * frac
		local tier = core(cx, cz, tsx, tsz, y, y + th, glass, Enum.Material.Glass)
		tier.Reflectance = 0.28
		lightAtNight(tier, lit, night)
		facade(cx, cz, tsx, tsz, y, y + th, { floorH = 13, bandH = 0.9, bay = 11, pierW = 0.6, depth = 0.3, color = metal, material = Enum.Material.Metal })
		parapet(cx, cz, tsx, tsz, y + th, metal, Enum.Material.Metal)
		y += th
	end

	-- roof: machinery, antenna with beacon or a helipad
	deco({ Name = "Mechanical", Size = Vector3.new(tsx * 0.45, 7, tsz * 0.45), CFrame = CFrame.new(cx, y + 3.5, cz), Color = rgb(120, 122, 126), Material = Enum.Material.Concrete })
	if h > 170 and rng:NextNumber() < 0.7 then
		deco({ Name = "Antenna", Size = Vector3.new(0.9, 34, 0.9), CFrame = CFrame.new(cx, y + 7 + 17, cz), Color = rgb(190, 190, 195), Material = Enum.Material.Metal })
		local beacon = deco({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(cx, y + 7 + 34, cz), Color = rgb(255, 30, 30), Material = Enum.Material.Neon })
		local _ = beacon
	elseif rng:NextNumber() < 0.5 then
		local pad = deco({ Name = "Helipad", Size = Vector3.new(tsx * 0.6, 0.4, tsz * 0.6), CFrame = CFrame.new(cx + tsx * 0.15, y + 0.5, cz + tsz * 0.15), Color = rgb(60, 60, 64), Material = Enum.Material.Concrete })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "H"
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = rgb(240, 240, 240)
		t.Parent = gui
		gui.Parent = pad
	end
end

local function office(center: Vector3, sx: number, sz: number, h: number, outward: { Vector3 })
	local cx, cz = center.X, center.Z
	local concrete = pick({ rgb(186, 180, 170), rgb(150, 150, 155), rgb(120, 112, 104), rgb(205, 200, 190) })
	local glass = pick(GLASS)
	local body = core(cx, cz, sx, sz, SURFACE, SURFACE + h, glass:Lerp(rgb(20, 24, 30), 0.4), Enum.Material.Glass)
	body.Reflectance = 0.22
	lightAtNight(body, rng:NextNumber() < 0.65, pick(WARM_NIGHT))
	-- ribbon windows: wide concrete bands, few piers
	facade(cx, cz, sx, sz, SURFACE, SURFACE + h, { floorH = 12, bandH = 5.5, bay = 24, pierW = 1.4, depth = 0.4, color = concrete, material = Enum.Material.Concrete })
	deco({ Name = "Base", Size = Vector3.new(sx + 1, 3, sz + 1), CFrame = CFrame.new(cx, SURFACE + 1.5, cz), Color = concrete:Lerp(rgb(60, 60, 60), 0.3), Material = Enum.Material.Granite })
	parapet(cx, cz, sx, sz, SURFACE + h, concrete, Enum.Material.Concrete)
	hvac(cx, cz, sx, sz, SURFACE + h, rng:NextInteger(2, 4))
	local n = outward[1]
	local half = if n.X ~= 0 then sx / 2 else sz / 2
	deco({ Name = "Canopy", Size = Vector3.new(18, 0.6, 6), CFrame = onFace(center, n, half, SURFACE + 9, 3), Color = rgb(60, 62, 66), Material = Enum.Material.Metal })
	-- rooftop billboard
	if rng:NextNumber() < 0.3 then
		local bb = deco({ Name = "Billboard", Size = Vector3.new(math.min(sx, sz) * 0.8, 14, 0.8), CFrame = onFace(center, n, half - 10, SURFACE + h + 11, 0), Color = rgb(20, 20, 22) })
		surfaceText(bb, pick({ "DRIVE FAST. LIVE FREE.", "NEON BAY RADIO 101.5", "NITRO ENERGY", "APEX MOTORS", "RACE WEEKEND" }), rgb(255, 255, 255), true)
		for _, s in { -1, 1 } do
			deco({ Name = "BillboardLeg", Size = Vector3.new(0.8, 6, 0.8), CFrame = bb.CFrame * CFrame.new(s * bb.Size.X * 0.35, -9.5, 1), Color = rgb(80, 80, 85), Material = Enum.Material.Metal })
		end
	end
end

local BRICKS = { rgb(142, 72, 56), rgb(120, 60, 46), rgb(165, 125, 92), rgb(96, 58, 46), rgb(182, 160, 130), rgb(130, 86, 70) }

local function fireEscape(center: Vector3, sx: number, sz: number, y0: number, y1: number, floorH: number, n: Vector3)
	local half = if n.X ~= 0 then sx / 2 else sz / 2
	local iron = rgb(35, 35, 38)
	local y = y0 + floorH - 0.5
	while y < y1 - 2 do
		deco({ Name = "EscapeDeck", Size = Vector3.new(12, 0.3, 3), CFrame = onFace(center, n, half, y, 1.5), Color = iron, Material = Enum.Material.Metal })
		deco({ Name = "EscapeRail", Size = Vector3.new(12, 0.15, 0.15), CFrame = onFace(center, n, half, y + 2.5, 3), Color = iron, Material = Enum.Material.Metal })
		y += floorH
	end
	for _, s in { -6, 6 } do
		local cf = onFace(center, n, half, (y0 + y1) / 2, 3) * CFrame.new(s, 0, 0)
		deco({ Name = "EscapeLadder", Size = Vector3.new(0.2, y1 - y0 - floorH, 0.2), CFrame = cf + Vector3.new(0, floorH / 2, 0), Color = iron, Material = Enum.Material.Metal })
	end
end

local function waterTank(x: number, z: number, y: number)
	local wood = rgb(120, 86, 58)
	for _, o in { Vector3.new(-2.5, 0, -2.5), Vector3.new(2.5, 0, -2.5), Vector3.new(-2.5, 0, 2.5), Vector3.new(2.5, 0, 2.5) } do
		deco({ Name = "TankLeg", Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(x + o.X, y + 3, z + o.Z), Color = rgb(40, 40, 42), Material = Enum.Material.Metal })
	end
	deco({ Name = "WaterTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 8, 8), CFrame = CFrame.new(x, y + 10.5, z) * CFrame.Angles(0, 0, math.rad(90)), Color = wood, Material = Enum.Material.WoodPlanks })
	deco({ Name = "TankRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 8.6, 8.6), CFrame = CFrame.new(x, y + 15.6, z) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(60, 60, 62), Material = Enum.Material.Metal })
end

local function brickBlock(center: Vector3, sx: number, sz: number, h: number, outward: { Vector3 })
	local cx, cz = center.X, center.Z
	local brick = pick(BRICKS)
	local trim = rgb(205, 198, 185)
	local shopH = 12
	-- ground floor shops
	local shop = core(cx, cz, sx, sz, SURFACE, SURFACE + shopH, rgb(34, 40, 46), Enum.Material.Glass)
	shop.Reflectance = 0.2
	lightAtNight(shop, true, rgb(150, 130, 95))
	facade(cx, cz, sx, sz, SURFACE, SURFACE + shopH, { floorH = 99, bandH = 0, bay = 22, pierW = 2, depth = 0.6, color = brick, material = Enum.Material.Brick, noBands = true })
	deco({ Name = "ShopCornice", Size = Vector3.new(sx + 1.4, 1.6, sz + 1.4), CFrame = CFrame.new(cx, SURFACE + shopH + 0.2, cz), Color = trim, Material = Enum.Material.Limestone })
	storefronts(center, sx, sz, outward, shopH)
	-- apartments above: brick with punched windows
	local upper = core(cx, cz, sx, sz, SURFACE + shopH, SURFACE + h, rgb(30, 34, 40), Enum.Material.Glass)
	upper.Reflectance = 0.15
	lightAtNight(upper, rng:NextNumber() < 0.8, pick(WARM_NIGHT))
	facade(cx, cz, sx, sz, SURFACE + shopH, SURFACE + h, { floorH = 10, bandH = 6, bay = 8, pierW = 4.4, depth = 0.6, color = brick, material = Enum.Material.Brick })
	deco({ Name = "Cornice", Size = Vector3.new(sx + 2.4, 2, sz + 2.4), CFrame = CFrame.new(cx, SURFACE + h, cz), Color = trim, Material = Enum.Material.Limestone })
	parapet(cx, cz, sx, sz, SURFACE + h + 1, brick, Enum.Material.Brick)
	-- fire escape on a street side
	fireEscape(center, sx, sz, SURFACE + shopH, SURFACE + h, 10, outward[#outward])
	if rng:NextNumber() < 0.5 then
		waterTank(cx + rng:NextNumber(-sx / 4, sx / 4), cz + rng:NextNumber(-sz / 4, sz / 4), SURFACE + h + 1)
	else
		hvac(cx, cz, sx, sz, SURFACE + h + 1, 2)
	end
end

local PLASTER = { rgb(222, 212, 192), rgb(200, 190, 170), rgb(172, 182, 186), rgb(214, 196, 168), rgb(190, 205, 190), rgb(230, 222, 210) }

local function shops(center: Vector3, sx: number, sz: number, h: number, outward: { Vector3 })
	local cx, cz = center.X, center.Z
	local wall = pick(PLASTER)
	local shopH = 11
	local ground = core(cx, cz, sx, sz, SURFACE, SURFACE + shopH, rgb(34, 40, 46), Enum.Material.Glass)
	ground.Reflectance = 0.2
	lightAtNight(ground, true, rgb(160, 140, 100))
	facade(cx, cz, sx, sz, SURFACE, SURFACE + shopH, { floorH = 99, bandH = 0, bay = 18, pierW = 1.6, depth = 0.5, color = wall, material = Enum.Material.Plaster, noBands = true })
	storefronts(center, sx, sz, outward, shopH)
	local upper = core(cx, cz, sx, sz, SURFACE + shopH, SURFACE + h, rgb(34, 38, 44), Enum.Material.Glass)
	lightAtNight(upper, rng:NextNumber() < 0.6, pick(WARM_NIGHT))
	facade(cx, cz, sx, sz, SURFACE + shopH, SURFACE + h, { floorH = 9, bandH = 5, bay = 9, pierW = 5, depth = 0.5, color = wall, material = Enum.Material.Plaster })
	deco({ Name = "Band", Size = Vector3.new(sx + 1.2, 1.2, sz + 1.2), CFrame = CFrame.new(cx, SURFACE + shopH, cz), Color = wall:Lerp(rgb(80, 80, 80), 0.3), Material = Enum.Material.Concrete })
	parapet(cx, cz, sx, sz, SURFACE + h, wall, Enum.Material.Plaster)
	hvac(cx, cz, sx, sz, SURFACE + h, rng:NextInteger(1, 3))
end

local function parkingLot(center: Vector3, size: number)
	local cx, cz = center.X, center.Z
	deco({ Name = "Lot", Size = Vector3.new(size, 0.05, size), CFrame = CFrame.new(cx, SURFACE + 0.03, cz), Color = rgb(48, 48, 52), Material = Enum.Material.Asphalt })
	for k = -4, 4 do
		for _, row in { -1, 1 } do
			deco({ Name = "Bay", Size = Vector3.new(0.4, 0.05, 16), CFrame = CFrame.new(cx + k * 10, SURFACE + 0.06, cz + row * 20), Color = rgb(220, 220, 220) })
		end
	end
end

-- Builds one lot of a city block. `downtown` is 0 at the edge of the city and 1 in the centre.
function Architecture.Lot(center: Vector3, outward: { Vector3 }, downtown: number)
	local r = rng:NextNumber()
	if r < 0.07 then
		parkingLot(center, 96)
		return
	end
	local roll = rng:NextNumber()
	if downtown > 0.5 and roll < 0.55 then
		local s = rng:NextNumber(80, 96)
		glassTower(center, s, rng:NextNumber(80, 96), 120 + downtown * rng:NextNumber(80, 220), outward)
	elseif roll < 0.4 then
		office(center, rng:NextNumber(80, 98), rng:NextNumber(80, 98), rng:NextNumber(55, 120), outward)
	elseif roll < 0.78 then
		brickBlock(center, rng:NextNumber(72, 96), rng:NextNumber(72, 96), rng:NextNumber(34, 82), outward)
	else
		shops(center, rng:NextNumber(80, 98), rng:NextNumber(80, 98), rng:NextNumber(18, 28), outward)
	end
end

---------------------------------------------------------------------------
-- Sidewalks and street furniture
---------------------------------------------------------------------------
local function tree(pos: Vector3)
	local h = rng:NextNumber(9, 13)
	deco({ Name = "TreeGrate", Size = Vector3.new(4, 0.08, 4), CFrame = CFrame.new(pos.X, SURFACE + 0.06, pos.Z), Color = rgb(40, 38, 36), Material = Enum.Material.Metal })
	local trunk = deco({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.1, 1.1), CFrame = CFrame.new(pos.X, SURFACE + h / 2, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(88, 64, 46), Material = Enum.Material.Wood })
	trunk.CanCollide = true
	local green = pick({ rgb(52, 110, 50), rgb(66, 125, 58), rgb(44, 96, 48), rgb(80, 130, 60) })
	deco({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 10, 10), CFrame = CFrame.new(pos.X, SURFACE + h + 2, pos.Z), Color = green, Material = Enum.Material.LeafyGrass })
	deco({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), CFrame = CFrame.new(pos.X + 2, SURFACE + h + 4.5, pos.Z - 1.5), Color = green:Lerp(rgb(120, 160, 80), 0.2), Material = Enum.Material.LeafyGrass })
end

local function busStop(pos: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(Vector3.new(pos.X, SURFACE, pos.Z), Vector3.new(pos.X, SURFACE, pos.Z) + facing)
	local metal = rgb(60, 62, 66)
	deco({ Name = "ShelterRoof", Size = Vector3.new(12, 0.4, 5), CFrame = cf * CFrame.new(0, 8, 0), Color = metal, Material = Enum.Material.Metal })
	local back = deco({ Name = "ShelterGlass", Size = Vector3.new(12, 7, 0.2), CFrame = cf * CFrame.new(0, 4, 2.4), Color = rgb(170, 200, 210), Material = Enum.Material.Glass })
	back.Transparency = 0.6
	for _, s in { -6, 6 } do
		deco({ Name = "ShelterPost", Size = Vector3.new(0.4, 8, 0.4), CFrame = cf * CFrame.new(s, 4, 2.4), Color = metal, Material = Enum.Material.Metal })
	end
	deco({ Name = "Bench", Size = Vector3.new(8, 0.5, 1.6), CFrame = cf * CFrame.new(0, 1.8, 1.5), Color = rgb(110, 80, 55), Material = Enum.Material.WoodPlanks })
	local ad = deco({ Name = "AdPanel", Size = Vector3.new(3.5, 5.5, 0.4), CFrame = cf * CFrame.new(-7.8, 3.5, 0), Color = rgb(250, 250, 250), Material = Enum.Material.Neon })
	local _ = ad
end

-- Sidewalk ring, curb, trees and furniture around one city block.
function Architecture.Sidewalks(c: Vector3, block: number, hasBusStop: boolean, style: string?)
	local kind = style or "city"
	local walk = if kind == "suburb" then 8 elseif kind == "industrial" then 6 else 14
	local paving = if kind == "industrial" then rgb(130, 128, 124) else rgb(168, 165, 158)
	for _, s in { -1, 1 } do
		deco({ Name = "Sidewalk", Size = Vector3.new(block, 0.04, walk), CFrame = CFrame.new(c.X, SURFACE + 0.02, c.Z + s * (block / 2 - walk / 2)), Color = paving, Material = Enum.Material.Pavement })
		deco({ Name = "Sidewalk", Size = Vector3.new(walk, 0.04, block - walk * 2), CFrame = CFrame.new(c.X + s * (block / 2 - walk / 2), SURFACE + 0.02, c.Z), Color = paving, Material = Enum.Material.Pavement })
		deco({ Name = "Curb", Size = Vector3.new(block, 0.07, 0.9), CFrame = CFrame.new(c.X, SURFACE + 0.035, c.Z + s * (block / 2 - 0.45)), Color = rgb(200, 198, 192), Material = Enum.Material.Concrete })
		deco({ Name = "Curb", Size = Vector3.new(0.9, 0.07, block), CFrame = CFrame.new(c.X + s * (block / 2 - 0.45), SURFACE + 0.035, c.Z), Color = rgb(200, 198, 192), Material = Enum.Material.Concrete })
	end
	-- trees along each side (the street lamps sit in the middle of each side)
	local inset = block / 2 - 6
	if kind == "industrial" then
		return
	end
	for _, along in (if kind == "suburb" then { -85 } else { -60, 60 }) :: { number } do
		tree(c + Vector3.new(along, 0, -inset))
		tree(c + Vector3.new(along, 0, inset))
		tree(c + Vector3.new(-inset, 0, along))
		tree(c + Vector3.new(inset, 0, along))
	end
	-- hydrant and bin near a corner
	local corner = c + Vector3.new(inset - 4, 0, inset - 14)
	deco({ Name = "Hydrant", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1, 1), CFrame = CFrame.new(corner.X, SURFACE + 1.2, corner.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(190, 30, 30), Material = Enum.Material.Metal })
	deco({ Name = "HydrantCap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(corner.X, SURFACE + 2.5, corner.Z), Color = rgb(190, 30, 30), Material = Enum.Material.Metal })
	if kind == "suburb" then
		return
	end
	local bin = c + Vector3.new(-inset + 3, 0, inset - 30)
	deco({ Name = "Bin", Size = Vector3.new(2, 3.2, 2), CFrame = CFrame.new(bin.X, SURFACE + 1.6, bin.Z), Color = rgb(40, 70, 50), Material = Enum.Material.Metal })
	if hasBusStop then
		busStop(c + Vector3.new(-30, 0, -inset + 1), -Vector3.zAxis)
	end
end

---------------------------------------------------------------------------
-- Intersections: crosswalks, stop lines and traffic lights
---------------------------------------------------------------------------
local function trafficLight(corner: Vector3, armDir: Vector3, facing: Vector3, axis: string)
	local metal = rgb(70, 72, 76)
	local x, z = corner.X, corner.Z
	deco({ Name = "SignalPole", Size = Vector3.new(0.9, 20, 0.9), CFrame = CFrame.new(x, SURFACE + 10, z), Color = metal, Material = Enum.Material.Metal })
	local armLen = 20
	local armMid = Vector3.new(x, SURFACE + 19.5, z) + armDir * (armLen / 2)
	deco({ Name = "SignalArm", Size = Vector3.new(0.6, 0.6, armLen), CFrame = CFrame.lookAt(armMid, armMid + armDir), Color = metal, Material = Enum.Material.Metal })
	local headPos = Vector3.new(x, SURFACE + 17, z) + armDir * (armLen - 1.5)
	local headCF = CFrame.lookAt(headPos, headPos + facing)
	deco({ Name = "SignalHead", Size = Vector3.new(1.8, 5, 1.2), CFrame = headCF, Color = rgb(30, 30, 32), Material = Enum.Material.Metal })
	local colors = {
		{ name = "red", color = rgb(255, 40, 30), y = 1.5 },
		{ name = "yellow", color = rgb(255, 190, 20), y = 0 },
		{ name = "green", color = rgb(40, 255, 90), y = -1.5 },
	}
	for _, info in colors do
		local lamp = deco({
			Name = "SignalLamp",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, 1.2, 1.2),
			CFrame = headCF * CFrame.new(0, info.y, -0.65) * CFrame.Angles(0, math.rad(90), 0),
			Color = info.color:Lerp(rgb(0, 0, 0), 0.7),
		}, signals)
		lamp:SetAttribute("Axis", axis)
		lamp:SetAttribute("Light", info.name)
		lamp:SetAttribute("On", info.color)
	end
end

local function stopSign(corner: Vector3, facing: Vector3)
	local pos = Vector3.new(corner.X, SURFACE, corner.Z)
	deco({ Name = "SignPost", Size = Vector3.new(0.3, 8, 0.3), CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)), Color = rgb(150, 150, 155), Material = Enum.Material.Metal })
	local cf = CFrame.lookAt(pos + Vector3.new(0, 8.5, 0), pos + Vector3.new(0, 8.5, 0) + facing)
	-- two overlapping squares make an octagon
	local a = deco({ Name = "StopSign", Size = Vector3.new(2.6, 2.6, 0.1), CFrame = cf, Color = rgb(190, 20, 25) })
	deco({ Name = "StopSign", Size = Vector3.new(2.6, 2.6, 0.1), CFrame = cf * CFrame.Angles(0, 0, math.rad(45)), Color = rgb(190, 20, 25) })
	local label = deco({ Name = "StopText", Size = Vector3.new(2.2, 0.9, 0.02), CFrame = cf * CFrame.new(0, 0, -0.07), Color = rgb(190, 20, 25), Transparency = 1 })
	surfaceText(label, "STOP", rgb(255, 255, 255), false)
	local _ = a
end

-- mode: "signals" (city: crosswalks + traffic lights), "stop" (stop signs) or "plain"
function Architecture.Intersection(c: Vector3, road: number, mode: string)
	local white = rgb(232, 232, 228)
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local across = dir:Cross(Vector3.yAxis)
		local cw = c + dir * (road / 2 + 4)
		if mode == "signals" then
			for k = -2.5, 2.5 do
				local p = cw + across * (k * 8.5)
				local size = if dir.X ~= 0 then Vector3.new(6, 0.04, 3.2) else Vector3.new(3.2, 0.04, 6)
				deco({ Name = "Crosswalk", Size = size, CFrame = CFrame.new(p.X, SURFACE + 0.03, p.Z), Color = white })
			end
		end
		-- stop line on the lanes approaching the intersection from this side
		local travel = -dir
		local right = travel:Cross(Vector3.yAxis)
		local sl = c + dir * (road / 2 + 8.5) + right * (road / 4)
		local size = if dir.X ~= 0 then Vector3.new(1.2, 0.04, road / 2 - 3) else Vector3.new(road / 2 - 3, 0.04, 1.2)
		deco({ Name = "StopLine", Size = size, CFrame = CFrame.new(sl.X, SURFACE + 0.03, sl.Z), Color = white })
	end
	if mode == "stop" then
		local o = road / 2 + 3
		stopSign(c + Vector3.new(o, 0, o), Vector3.zAxis)
		stopSign(c + Vector3.new(-o, 0, -o), -Vector3.zAxis)
		stopSign(c + Vector3.new(-o, 0, o), -Vector3.xAxis)
		stopSign(c + Vector3.new(o, 0, -o), Vector3.xAxis)
	elseif mode == "signals" then
		local o = road / 2 + 3
		-- traffic heading -Z (from +Z) drives on the +X side: pole on the (+X, +Z) corner
		trafficLight(c + Vector3.new(o, 0, o), -Vector3.xAxis, Vector3.zAxis, "z")
		-- traffic heading +Z (from -Z) drives on the -X side
		trafficLight(c + Vector3.new(-o, 0, -o), Vector3.xAxis, -Vector3.zAxis, "z")
		-- traffic heading +X (from -X) drives on the +Z side
		trafficLight(c + Vector3.new(-o, 0, o), -Vector3.zAxis, -Vector3.xAxis, "x")
		-- traffic heading -X (from +X) drives on the -Z side
		trafficLight(c + Vector3.new(o, 0, -o), Vector3.zAxis, Vector3.xAxis, "x")
	end
end

---------------------------------------------------------------------------
-- Suburbs: detached houses with gable roofs, driveways and garages
---------------------------------------------------------------------------
local SIDING = { rgb(232, 226, 210), rgb(200, 214, 222), rgb(214, 200, 176), rgb(186, 204, 180), rgb(240, 236, 228), rgb(222, 190, 170), rgb(170, 180, 196) }
local ROOFS = { rgb(70, 62, 60), rgb(110, 60, 45), rgb(60, 66, 76), rgb(90, 80, 70), rgb(140, 72, 50) }

local function house(front: Vector3, n: Vector3)
	-- `front` is the middle of the plot on the street side, `n` points at the street
	local w = rng:NextNumber(30, 38)
	local d = rng:NextNumber(24, 30)
	local wallH = if rng:NextNumber() < 0.45 then 20 else 11
	local center = front - n * (22 + d / 2)
	local hcf = CFrame.lookAt(Vector3.new(center.X, SURFACE, center.Z), Vector3.new(center.X, SURFACE, center.Z) + n)
	local siding = pick(SIDING)
	local roofColor = pick(ROOFS)
	local body = Instance.new("Part")
	body.Name = "House"
	body.Anchored = true
	body.Size = Vector3.new(w, wallH, d)
	body.CFrame = hcf * CFrame.new(0, wallH / 2, 0)
	body.Color = siding
	body.Material = if rng:NextNumber() < 0.5 then Enum.Material.WoodPlanks else Enum.Material.Plaster
	body.TopSurface = Enum.SurfaceType.Smooth
	body.Parent = buildings
	-- gable roof: two wedges meeting at the ridge
	local rh = rng:NextNumber(6, 9)
	local roofMat = if rng:NextNumber() < 0.5 then Enum.Material.RoofShingles else Enum.Material.ClayRoofTiles
	deco({ ClassName = nil, Name = "Roof", Size = Vector3.new(w + 2, rh, d / 2 + 1), CFrame = hcf * CFrame.new(0, wallH + rh / 2, -d / 4 - 0.5), Color = roofColor, Material = roofMat }, nil, "WedgePart")
	deco({ Name = "Roof", Size = Vector3.new(w + 2, rh, d / 2 + 1), CFrame = hcf * CFrame.new(0, wallH + rh / 2, d / 4 + 0.5) * CFrame.Angles(0, math.pi, 0), Color = roofColor, Material = roofMat }, nil, "WedgePart")
	-- chimney
	if rng:NextNumber() < 0.5 then
		deco({ Name = "Chimney", Size = Vector3.new(2.5, rh + 3, 2.5), CFrame = hcf * CFrame.new(w / 2 - 4, wallH + (rh + 3) / 2, 2), Color = rgb(130, 70, 55), Material = Enum.Material.Brick })
	end
	-- front: door, windows, garage
	local faceZ = -d / 2 - 0.05
	deco({ Name = "Door", Size = Vector3.new(3.4, 7, 0.2), CFrame = hcf * CFrame.new(-2, 3.5, faceZ), Color = pick({ rgb(120, 30, 30), rgb(40, 60, 90), rgb(60, 45, 35), rgb(30, 30, 32) }), Material = Enum.Material.Wood })
	local lit = rng:NextNumber() < 0.6
	for _, x in { -w / 2 + 5, 5 } do
		local win = deco({ Name = "Window", Size = Vector3.new(4.5, 4, 0.2), CFrame = hcf * CFrame.new(x - 2, 5.5, faceZ), Color = rgb(60, 80, 96), Material = Enum.Material.Glass, Reflectance = 0.2 })
		lightAtNight(win, lit, rgb(150, 120, 80))
		deco({ Name = "Sill", Size = Vector3.new(5.2, 0.4, 0.5), CFrame = hcf * CFrame.new(x - 2, 3.3, faceZ - 0.2), Color = rgb(240, 240, 235) })
		if wallH > 15 then
			local up = deco({ Name = "Window", Size = Vector3.new(4.5, 4, 0.2), CFrame = hcf * CFrame.new(x - 2, 15, faceZ), Color = rgb(60, 80, 96), Material = Enum.Material.Glass, Reflectance = 0.2 })
			lightAtNight(up, lit and rng:NextNumber() < 0.6, rgb(150, 120, 80))
		end
	end
	local garageX = w / 2 - 6.5
	deco({ Name = "GarageDoor", Size = Vector3.new(10, 8, 0.2), CFrame = hcf * CFrame.new(garageX, 4, faceZ), Color = rgb(235, 235, 230), Material = Enum.Material.SmoothPlastic })
	-- driveway to the street and a porch step
	local driveLen = 22 + 1
	deco({ Name = "Driveway", Size = Vector3.new(11, 0.05, driveLen), CFrame = hcf * CFrame.new(garageX, 0.04, -d / 2 - driveLen / 2), Color = rgb(150, 148, 142), Material = Enum.Material.Concrete })
	deco({ Name = "Path", Size = Vector3.new(3, 0.05, driveLen), CFrame = hcf * CFrame.new(-2, 0.04, -d / 2 - driveLen / 2), Color = rgb(170, 165, 155), Material = Enum.Material.Pavement })
	-- a parked car-shaped block in some driveways would be heavy; a mailbox is cheap
	deco({ Name = "Mailbox", Size = Vector3.new(0.9, 0.9, 1.6), CFrame = hcf * CFrame.new(-6, 3.6, -d / 2 - driveLen + 1.5), Color = rgb(50, 50, 55), Material = Enum.Material.Metal })
	deco({ Name = "MailPost", Size = Vector3.new(0.25, 3.2, 0.25), CFrame = hcf * CFrame.new(-6, 1.6, -d / 2 - driveLen + 1.5), Color = rgb(110, 85, 60), Material = Enum.Material.Wood })
	-- back yard tree
	if rng:NextNumber() < 0.6 then
		local t = hcf * CFrame.new(rng:NextNumber(-w / 2, w / 2), 0, d / 2 + 10)
		local h = rng:NextNumber(8, 12)
		deco({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1, 1), CFrame = CFrame.new(t.Position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(88, 64, 46), Material = Enum.Material.Wood })
		deco({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(11, 11, 11), CFrame = CFrame.new(t.Position + Vector3.new(0, h + 2, 0)), Color = pick({ rgb(52, 110, 50), rgb(66, 125, 58), rgb(80, 130, 60) }), Material = Enum.Material.LeafyGrass })
	end
end

function Architecture.Suburb(c: Vector3, block: number)
	local half = block / 2
	for _, n in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local across = n:Cross(Vector3.yAxis)
		for _, along in { -50, 50 } do
			if rng:NextNumber() < 0.92 then
				house(c + n * half + across * along, n)
			end
		end
	end
	-- back-yard fences dividing the lots
	for _, s in { -1, 1 } do
		deco({ Name = "Fence", Size = Vector3.new(0.4, 4, block - 90), CFrame = CFrame.new(c.X + s * 6, SURFACE + 2, c.Z), Color = rgb(150, 115, 80), Material = Enum.Material.WoodPlanks })
	end
end

---------------------------------------------------------------------------
-- Industrial port: warehouses, shipping containers, cranes and fuel tanks
---------------------------------------------------------------------------
local CONTAINER_COLORS = { rgb(170, 50, 40), rgb(40, 90, 150), rgb(60, 120, 70), rgb(200, 140, 40), rgb(120, 120, 125), rgb(150, 70, 30), rgb(30, 60, 90) }

local function container(pos: Vector3, rotY: number)
	local p = Instance.new("Part")
	p.Name = "Container"
	p.Anchored = true
	p.Size = Vector3.new(8, 8.5, 20)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 4.25, 0)) * CFrame.Angles(0, rotY, 0)
	p.Color = pick(CONTAINER_COLORS)
	p.Material = Enum.Material.CorrodedMetal
	p.Parent = buildings
	-- ribbing
	deco({ Name = "Rib", Size = Vector3.new(8.2, 0.3, 20.2), CFrame = p.CFrame * CFrame.new(0, 3, 0), Color = p.Color:Lerp(rgb(0, 0, 0), 0.25) })
	deco({ Name = "Rib", Size = Vector3.new(8.2, 0.3, 20.2), CFrame = p.CFrame * CFrame.new(0, -3, 0), Color = p.Color:Lerp(rgb(0, 0, 0), 0.25) })
end

local function warehouse(center: Vector3, sx: number, sz: number, outward: Vector3)
	local h = rng:NextNumber(24, 36)
	local body = core(center.X, center.Z, sx, sz, SURFACE, SURFACE + h, pick({ rgb(150, 155, 160), rgb(120, 130, 140), rgb(170, 160, 140), rgb(90, 100, 110) }), Enum.Material.CorrodedMetal)
	local _ = body
	-- corrugated look: vertical ribs
	facade(center.X, center.Z, sx, sz, SURFACE, SURFACE + h, { floorH = 999, bandH = 0, bay = 4, pierW = 0.4, depth = 0.25, color = rgb(110, 115, 120), material = Enum.Material.Metal, noBands = true })
	-- shallow pitched roof
	local ridgeAxisX = sx >= sz
	local rw = if ridgeAxisX then sx else sz
	local rd = if ridgeAxisX then sz else sx
	local rot = if ridgeAxisX then 0 else math.rad(90)
	local base = CFrame.new(center.X, SURFACE + h, center.Z) * CFrame.Angles(0, rot, 0)
	deco({ Name = "Roof", Size = Vector3.new(rw + 1, 4, rd / 2 + 0.5), CFrame = base * CFrame.new(0, 2, -rd / 4), Color = rgb(95, 100, 105), Material = Enum.Material.Metal }, nil, "WedgePart")
	deco({ Name = "Roof", Size = Vector3.new(rw + 1, 4, rd / 2 + 0.5), CFrame = base * CFrame.new(0, 2, rd / 4) * CFrame.Angles(0, math.pi, 0), Color = rgb(95, 100, 105), Material = Enum.Material.Metal }, nil, "WedgePart")
	-- loading bays facing the street
	local half = if outward.X ~= 0 then sx / 2 else sz / 2
	local width = if outward.X ~= 0 then sz else sx
	for k = -1, 1 do
		local lateral = if outward.X ~= 0 then Vector3.new(0, 0, k * width / 3.5) else Vector3.new(k * width / 3.5, 0, 0)
		deco({ Name = "LoadingDoor", Size = Vector3.new(12, 14, 0.3), CFrame = onFace(center + lateral, outward, half, SURFACE + 7, 0.1), Color = rgb(200, 170, 40), Material = Enum.Material.Metal })
	end
	local sign = deco({ Name = "WarehouseSign", Size = Vector3.new(math.min(width * 0.6, 40), 4, 0.3), CFrame = onFace(center, outward, half, SURFACE + h - 4, 0.2), Color = rgb(30, 40, 60) })
	surfaceText(sign, pick({ "NEON BAY LOGISTICS", "HARBOR FREIGHT CO.", "PACIFIC SHIPPING", "DOCK 7", "COLD STORAGE" }), rgb(240, 240, 240), false)
end

local function crane(pos: Vector3)
	local yellow = rgb(230, 175, 30)
	for _, o in { Vector3.new(-12, 0, -8), Vector3.new(12, 0, -8), Vector3.new(-12, 0, 8), Vector3.new(12, 0, 8) } do
		deco({ Name = "CraneLeg", Size = Vector3.new(2, 60, 2), CFrame = CFrame.new(pos + o + Vector3.new(0, 30, 0)), Color = yellow, Material = Enum.Material.Metal })
	end
	deco({ Name = "CraneBeam", Size = Vector3.new(4, 4, 90), CFrame = CFrame.new(pos + Vector3.new(0, 62, 20)), Color = yellow, Material = Enum.Material.Metal })
	deco({ Name = "CraneCab", Size = Vector3.new(6, 5, 6), CFrame = CFrame.new(pos + Vector3.new(0, 57, 30)), Color = rgb(60, 60, 64), Material = Enum.Material.Metal })
	local beacon = deco({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(pos + Vector3.new(0, 65, 64)), Color = rgb(255, 40, 30), Material = Enum.Material.Neon })
	local _ = beacon
end

local function fuelTank(pos: Vector3)
	deco({ Name = "FuelTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(18, 30, 30), CFrame = CFrame.new(pos + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(220, 222, 225), Material = Enum.Material.Metal })
	local p = Instance.new("Part")
	p.Name = "FuelTankCore"
	p.Anchored = true
	p.Transparency = 1
	p.Size = Vector3.new(22, 18, 22)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 9, 0))
	p.Parent = buildings
end

function Architecture.Industrial(c: Vector3, block: number, docks: boolean)
	local roll = rng:NextNumber()
	if roll < 0.55 then
		-- two warehouses facing the east-west streets
		warehouse(c + Vector3.new(0, 0, -50), block - 50, 80, -Vector3.zAxis)
		warehouse(c + Vector3.new(0, 0, 55), block - 60, 70, Vector3.zAxis)
	elseif roll < 0.8 then
		-- container yard
		for row = -2, 2 do
			for col = -1, 1 do
				if rng:NextNumber() < 0.8 then
					local p = c + Vector3.new(col * 30, 0, row * 36)
					container(p, 0)
					if rng:NextNumber() < 0.45 then
						container(p + Vector3.new(0, 8.5, 0), 0)
					end
				end
			end
		end
	else
		-- tank farm
		for _, o in { Vector3.new(-45, 0, -45), Vector3.new(45, 0, -45), Vector3.new(-45, 0, 45), Vector3.new(45, 0, 45) } do
			fuelTank(c + o)
		end
		warehouse(c, 60, 40, Vector3.xAxis)
	end
	if docks then
		crane(c + Vector3.new(block / 2 - 30, 0, rng:NextNumber(-60, 60)))
	end
end

return Architecture
