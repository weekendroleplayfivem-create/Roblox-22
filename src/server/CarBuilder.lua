--!strict
-- Builds detailed car models from parts at runtime (no meshes needed): real-world proportions,
-- wheel arches, sloped hood / windshield, glass cabin with interior, spoked wheels with brake
-- calipers, bumpers, grille, lights, mirrors, plates and exhausts. Supports the visual tuning
-- options (rims, rim colour, tint, spoiler, body kit, underglow, ride height).

local CarBuilder = {}

export type BuildOptions = {
	style: string,
	color: Color3,
	name: string,
	police: boolean?,
	heavy: boolean?,
	seat: boolean?,
	effectColor: Color3?,
	label: string?,
	rim: number?, -- 1..5 (Config.Visual.rim)
	rimColor: Color3?,
	tint: number?, -- glass transparency
	spoiler: number?, -- 1 none, 2 ducktail, 3 street wing, 4 GT wing
	kit: number?, -- 1 stock, 2 street kit, 3 widebody
	glow: Color3?, -- underglow colour (nil = off)
	ride: number?, -- -2..2 ride height
}

type Dims = {
	W: number, -- width
	L: number, -- length
	c: number, -- ground clearance
	top: number, -- beltline / top of the body
	roof: number, -- roof height
	r: number, -- wheel radius
	cabS: number, -- cabin start (fraction of length from the front)
	cabE: number, -- cabin end
	ws: number, -- windshield length
	rw: number, -- rear window length
	hood: number, -- hood rise
	fAxle: number, -- front axle position (fraction from front)
	rAxle: number, -- rear axle position (fraction from rear)
	spoiler: number, -- default spoiler
	fullTail: boolean, -- full width tail light bar
	exhausts: number,
}

-- Proportions are based on real cars at roughly 1 stud = 0.35 m.
local STYLES: { [string]: Dims } = {
	coupe = { W = 5.6, L = 13, c = 0.45, top = 2.25, roof = 3.7, r = 1.0, cabS = 0.36, cabE = 0.78, ws = 2.4, rw = 2.2, hood = 0.3, fAxle = 0.19, rAxle = 0.18, spoiler = 1, fullTail = false, exhausts = 2 },
	hyper = { W = 5.9, L = 13.4, c = 0.35, top = 1.95, roof = 3.25, r = 1.05, cabS = 0.3, cabE = 0.66, ws = 2.6, rw = 2.6, hood = 0.2, fAxle = 0.18, rAxle = 0.2, spoiler = 3, fullTail = true, exhausts = 2 },
	muscle = { W = 5.9, L = 14, c = 0.5, top = 2.5, roof = 3.9, r = 1.05, cabS = 0.42, cabE = 0.8, ws = 2.2, rw = 1.8, hood = 0.25, fAxle = 0.18, rAxle = 0.17, spoiler = 2, fullTail = true, exhausts = 4 },
	sedan = { W = 5.8, L = 14, c = 0.5, top = 2.45, roof = 4.1, r = 1.05, cabS = 0.31, cabE = 0.8, ws = 2.4, rw = 2.3, hood = 0.25, fAxle = 0.19, rAxle = 0.18, spoiler = 1, fullTail = false, exhausts = 1 },
	suv = { W = 6.2, L = 14.2, c = 0.85, top = 3.2, roof = 5.1, r = 1.25, cabS = 0.28, cabE = 0.93, ws = 2.0, rw = 0.8, hood = 0.2, fAxle = 0.18, rAxle = 0.17, spoiler = 1, fullTail = false, exhausts = 1 },
}

local DARK = Color3.fromRGB(18, 18, 20)
local TRIM = Color3.fromRGB(35, 35, 38)
local CHROME = Color3.fromRGB(210, 210, 215)
local TIRE = Color3.fromRGB(28, 28, 30)
local GLASS = Color3.fromRGB(20, 26, 36)

type Ctx = {
	model: Model,
	chassis: BasePart,
}

local function setup(p: BasePart, ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = ctx.model
end

local function weldTo(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function box(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, weldTarget: BasePart?): Part
	local p = Instance.new("Part")
	setup(p, ctx, name, size, cf, color, material)
	weldTo(weldTarget or ctx.chassis, p)
	return p
end

local function wedge(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	setup(p, ctx, name, size, cf, color, material)
	weldTo(ctx.chassis, p)
	return p
end

local function cylinder(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, weldTarget: BasePart?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	setup(p, ctx, name, size, cf, color, material)
	weldTo(weldTarget or ctx.chassis, p)
	return p
end

local function paint(p: BasePart)
	p.Reflectance = 0.18
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, bg: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = if bg then 0 else 1
	label.BackgroundColor3 = bg or Color3.new(1, 1, 1)
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = target
end

-- One wheel: tyre, rim lip, dark barrel, spokes and centre cap on a hub that the client spins.
local function buildWheel(ctx: Ctx, d: Dims, x: number, z: number, front: boolean, opts: BuildOptions)
	local r = d.r
	local side = math.sign(x)
	local chassis = ctx.chassis
	local hubCF = CFrame.new(x, r, z)
	local hub = Instance.new("Part")
	setup(hub, ctx, "WheelHub", Vector3.new(0.2, 0.2, 0.2), hubCF, DARK)
	hub.Transparency = 1
	local weld = Instance.new("Weld")
	weld.Name = "WheelWeld"
	weld.Part0 = chassis
	weld.Part1 = hub
	weld.C0 = chassis.CFrame:ToObjectSpace(hubCF)
	weld:SetAttribute("BaseC0", weld.C0)
	weld:SetAttribute("Front", front)
	weld:SetAttribute("Radius", r)
	weld.Parent = hub

	local rimColor = opts.rimColor or CHROME
	local style = opts.rim or 1
	local width = if opts.kit == 3 then 1.35 else 1.15

	cylinder(ctx, "Tire", Vector3.new(width, r * 2, r * 2), hubCF, TIRE, Enum.Material.SmoothPlastic, hub)
	local outer = side * (width / 2)
	local lipR = if style == 4 then 0.8 else 0.72
	local barrelR = if style == 4 then 0.5 else 0.64
	cylinder(ctx, "RimLip", Vector3.new(0.06, r * 2 * lipR, r * 2 * lipR), hubCF * CFrame.new(outer - side * 0.02, 0, 0), rimColor, Enum.Material.Metal, hub).Reflectance = 0.35
	cylinder(ctx, "RimBarrel", Vector3.new(0.06, r * 2 * barrelR, r * 2 * barrelR), hubCF * CFrame.new(outer - side * 0.01, 0, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Metal, hub)
	-- brake disc visible through the spokes
	cylinder(ctx, "Disc", Vector3.new(0.04, r * 1.05, r * 1.05), hubCF * CFrame.new(outer, 0, 0), Color3.fromRGB(95, 95, 100), Enum.Material.Metal, hub)

	local counts = { 5, 6, 12, 5, 14 }
	local n = counts[style] or 5
	local spokeW = if style == 3 or style == 5 then 0.09 else 0.2
	local spokeLen = r * barrelR
	for k = 0, n - 1 do
		local angle = k * math.pi * 2 / n
		local cf = hubCF * CFrame.new(outer + side * 0.03, 0, 0) * CFrame.Angles(angle, 0, 0)
		if style == 5 then
			cf *= CFrame.Angles(0, 0.6, 0) -- twisted turbine blades
		end
		cf *= CFrame.new(0, spokeLen / 2, 0)
		box(ctx, "Spoke", Vector3.new(0.06, spokeLen, spokeW), cf, rimColor, Enum.Material.Metal, hub).Reflectance = 0.3
	end
	cylinder(ctx, "Cap", Vector3.new(0.08, r * 0.28, r * 0.28), hubCF * CFrame.new(outer + side * 0.05, 0, 0), rimColor, Enum.Material.Metal, hub)

	-- caliper stays still (welded to the chassis)
	box(ctx, "Caliper", Vector3.new(0.08, r * 0.45, r * 0.32), hubCF * CFrame.new(outer + side * 0.015, r * 0.32, r * 0.18), Color3.fromRGB(200, 30, 35))
end

function CarBuilder.Build(opts: BuildOptions): Model
	local styleName = if opts.heavy then "suv" elseif opts.police then "sedan" else opts.style
	local d = STYLES[styleName] or STYLES.coupe
	local model = Instance.new("Model")
	model.Name = opts.name

	local W, L, r = d.W, d.L, d.r
	local chassisH = 1.4
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(W, chassisH, L)
	chassis.Transparency = 1
	chassis.CanCollide = true
	chassis.Anchored = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(if opts.heavy then 1.6 else 0.9, 0, 0, 100, 1)
	chassis.RootPriority = 10
	chassis.CFrame = CFrame.new(0, chassisH / 2, 0)
	chassis.Parent = model
	model.PrimaryPart = chassis
	local ctx: Ctx = { model = model, chassis = chassis }

	-- keep the car upright (primary axis = attachment X axis, pointed up)
	local att = Instance.new("Attachment")
	att.Name = "UprightAttachment"
	att.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, -Vector3.xAxis)
	att.Parent = chassis
	local align = Instance.new("AlignOrientation")
	align.Name = "Upright"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.AlignType = Enum.AlignType.PrimaryAxisParallel
	align.PrimaryAxis = Vector3.yAxis
	align.Attachment0 = att
	align.Responsiveness = 25
	align.MaxTorque = 5e6
	align.Parent = chassis

	local rideOff = (opts.ride or 0) * 0.15
	local bottom = d.c + rideOff
	local top = d.top + rideOff
	local roof = d.roof + rideOff
	local H = top - bottom
	local roofH = roof - top
	local kit = opts.kit or 1
	local wide = kit == 3
	local bodyColor = if opts.police then Color3.fromRGB(14, 14, 18) else opts.color
	local front = -L / 2
	local rear = L / 2
	local fz = front + L * d.fAxle
	local rz = rear - L * d.rAxle
	local a = r + 0.3 -- half length of a wheel arch
	local archTop = math.min(r * 2 + 0.15, top - 0.15)
	local midY = (bottom + top) / 2

	-- Body shell split around the wheel arches
	local sections = {
		{ z0 = front, z1 = fz - a, arch = false },
		{ z0 = fz - a, z1 = fz + a, arch = true },
		{ z0 = fz + a, z1 = rz - a, arch = false },
		{ z0 = rz - a, z1 = rz + a, arch = true },
		{ z0 = rz + a, z1 = rear, arch = false },
	}
	for _, sec in sections do
		local z0, z1, arch = sec.z0, sec.z1, sec.arch
		local len = z1 - z0
		local zc = (z0 + z1) / 2
		if arch then
			paint(box(ctx, "Fender", Vector3.new(W, top - archTop, len), CFrame.new(0, (archTop + top) / 2, zc), bodyColor))
			box(ctx, "ArchInner", Vector3.new(W - 2.6, archTop - bottom, len), CFrame.new(0, (bottom + archTop) / 2, zc), DARK)
			box(ctx, "ArchLiner", Vector3.new(W - 0.1, 0.1, len - 0.1), CFrame.new(0, archTop - 0.05, zc), DARK)
		else
			paint(box(ctx, "Body", Vector3.new(W, H, len), CFrame.new(0, midY, zc), bodyColor))
		end
	end

	-- Hood, windshield, roof, rear window, trunk
	local cabW = W - 0.9
	local cabS = front + L * d.cabS
	local cabE = front + L * d.cabE
	local roofS = cabS + d.ws
	local roofE = cabE - d.rw
	local roofLen = math.max(roofE - roofS, 0.5)
	local roofMid = (roofS + roofE) / 2
	local hoodLen = cabS - (front + 0.3)
	paint(wedge(ctx, "Hood", Vector3.new(W - 0.3, d.hood, hoodLen), CFrame.new(0, top + d.hood / 2, front + 0.3 + hoodLen / 2), bodyColor))
	local tint = opts.tint or 0.4
	local ws = wedge(ctx, "Windshield", Vector3.new(cabW, roofH, d.ws), CFrame.new(0, top + roofH / 2, cabS + d.ws / 2), GLASS, Enum.Material.Glass)
	ws.Transparency = tint
	ws.Reflectance = 0.25
	local roofColor = if opts.police then Color3.fromRGB(240, 240, 240) else bodyColor
	paint(box(ctx, "Roof", Vector3.new(cabW, 0.18, roofLen), CFrame.new(0, roof - 0.09, roofMid), roofColor))
	local cabin = box(ctx, "CabinGlass", Vector3.new(cabW - 0.1, roofH - 0.18, roofLen), CFrame.new(0, top + (roofH - 0.18) / 2, roofMid), GLASS, Enum.Material.Glass)
	cabin.Transparency = tint
	cabin.Reflectance = 0.25
	local rwp = wedge(ctx, "RearWindow", Vector3.new(cabW, roofH, d.rw), CFrame.new(0, top + roofH / 2, cabE - d.rw / 2) * CFrame.Angles(0, math.pi, 0), GLASS, Enum.Material.Glass)
	rwp.Transparency = tint
	rwp.Reflectance = 0.25
	if rear - 0.3 - cabE > 0.5 then
		local trunkLen = rear - 0.3 - cabE
		paint(wedge(ctx, "Trunk", Vector3.new(W - 0.3, 0.15, trunkLen), CFrame.new(0, top + 0.075, cabE + trunkLen / 2) * CFrame.Angles(0, math.pi, 0), bodyColor))
	end
	-- pillars
	for _, s in { -1, 1 } do
		box(ctx, "BPillar", Vector3.new(0.06, roofH - 0.18, 0.35), CFrame.new(s * (cabW / 2), top + (roofH - 0.18) / 2, roofMid + roofLen * 0.1), DARK)
	end

	-- Interior (visible through lighter tints)
	for _, s in { -1, 1 } do
		box(ctx, "Seat", Vector3.new(1.3, 1.5, 0.35), CFrame.new(s * cabW / 4, top + 0.35, roofMid + 0.6) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Fabric)
	end
	box(ctx, "Dash", Vector3.new(cabW - 0.2, 0.35, 0.9), CFrame.new(0, top + 0.1, cabS + d.ws * 0.65), Color3.fromRGB(25, 25, 28))
	cylinder(ctx, "SteeringWheel", Vector3.new(0.12, 0.9, 0.9), CFrame.new(-cabW / 4, top + 0.45, cabS + d.ws * 0.95) * CFrame.Angles(0, math.rad(90), math.rad(20)), DARK)

	-- Front end
	box(ctx, "Bumper", Vector3.new(W - 0.3, 0.4, 0.35), CFrame.new(0, bottom + 0.2, front - 0.12), TRIM)
	box(ctx, "Grille", Vector3.new(W * 0.42, H * 0.35, 0.1), CFrame.new(0, bottom + H * 0.42, front - 0.04), DARK)
	for _, s in { -1, 1 } do
		box(ctx, "Intake", Vector3.new(0.9, 0.3, 0.1), CFrame.new(s * (W / 2 - 1), bottom + 0.55, front - 0.04), DARK)
	end
	for idx, s in { -1, 1 } do
		local x = s * (W / 2 - 0.85)
		local y = top - 0.28
		local head = box(ctx, "Headlight", Vector3.new(1.15, 0.26, 0.1), CFrame.new(x, y, front - 0.06), Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
		local lens = box(ctx, "HeadlightLens", Vector3.new(1.35, 0.4, 0.12), CFrame.new(x, y, front - 0.03), Color3.fromRGB(200, 210, 220), Enum.Material.Glass)
		lens.Transparency = 0.6
		box(ctx, "DRL", Vector3.new(1.2, 0.06, 0.1), CFrame.new(x, y - 0.26, front - 0.06), Color3.fromRGB(220, 240, 255), Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Name = "Beam"
		spot.Face = Enum.NormalId.Front
		spot.Range = 90
		spot.Angle = 55
		spot.Brightness = 3.5
		spot.Color = Color3.fromRGB(255, 245, 225)
		spot.Shadows = opts.seat == true and idx == 1
		spot.Parent = head
	end

	-- Rear end
	box(ctx, "RearBumper", Vector3.new(W - 0.3, 0.45, 0.35), CFrame.new(0, bottom + 0.22, rear + 0.12), TRIM)
	local tailY = top - 0.3
	if d.fullTail then
		box(ctx, "Taillight", Vector3.new(W - 0.5, 0.16, 0.1), CFrame.new(0, tailY, rear + 0.05), Color3.fromRGB(255, 20, 35), Enum.Material.Neon)
	end
	for _, s in { -1, 1 } do
		box(ctx, "Taillight", Vector3.new(1.3, 0.32, 0.1), CFrame.new(s * (W / 2 - 0.85), tailY, rear + 0.05), Color3.fromRGB(230, 15, 30), Enum.Material.Neon)
		box(ctx, "ReverseLight", Vector3.new(0.35, 0.2, 0.1), CFrame.new(s * (W / 2 - 1.75), tailY - 0.05, rear + 0.05), Color3.fromRGB(235, 235, 235), Enum.Material.Glass)
	end
	local firstTail = model:FindFirstChild("Taillight") :: BasePart
	local tailGlow = Instance.new("SurfaceLight")
	tailGlow.Name = "TailGlow"
	tailGlow.Face = Enum.NormalId.Back
	tailGlow.Color = Color3.fromRGB(255, 20, 30)
	tailGlow.Range = 9
	tailGlow.Brightness = 1.2
	tailGlow.Angle = 120
	tailGlow.Parent = firstTail

	-- Exhaust tips
	local tips: { number } = {}
	if d.exhausts == 1 then
		tips = { -(W / 2 - 1.3) }
	elseif d.exhausts == 2 then
		tips = { -(W / 2 - 1.3), W / 2 - 1.3 }
	else
		tips = { -(W / 2 - 1.2), -(W / 2 - 1.75), W / 2 - 1.75, W / 2 - 1.2 }
	end
	for _, x in tips do
		local tip = cylinder(ctx, "ExhaustTip", Vector3.new(0.6, 0.38, 0.38), CFrame.new(x, bottom + 0.22, rear + 0.3) * CFrame.Angles(0, math.rad(90), 0), CHROME, Enum.Material.Metal)
		tip.Reflectance = 0.5
	end

	-- Plates
	local plateF = box(ctx, "Plate", Vector3.new(1.8, 0.42, 0.05), CFrame.new(0, bottom + 0.45, front - 0.32), Color3.new(1, 1, 1))
	surfaceText(plateF, Enum.NormalId.Front, "NEON BAY", Color3.fromRGB(20, 40, 120))
	local plateR = box(ctx, "Plate", Vector3.new(1.8, 0.42, 0.05), CFrame.new(0, bottom + 0.62, rear + 0.32), Color3.new(1, 1, 1))
	surfaceText(plateR, Enum.NormalId.Back, if opts.police then "POLICE" else "WNTD 22", Color3.fromRGB(20, 40, 120))

	-- Sides: mirrors, door shut lines, handles
	for _, s in { -1, 1 } do
		local mx = s * (W / 2 + 0.25)
		paint(box(ctx, "Mirror", Vector3.new(0.5, 0.32, 0.55), CFrame.new(mx, top + 0.3, cabS + 0.55), bodyColor))
		box(ctx, "MirrorArm", Vector3.new(0.4, 0.08, 0.2), CFrame.new(s * (W / 2 + 0.02), top + 0.18, cabS + 0.6), DARK)
		for _, z in { cabS + 0.2, roofMid + roofLen * 0.1, cabE - 0.4 } do
			box(ctx, "DoorLine", Vector3.new(0.03, H - 0.35, 0.05), CFrame.new(s * (W / 2 + 0.005), midY + 0.05, z), DARK)
		end
		box(ctx, "Handle", Vector3.new(0.05, 0.12, 0.5), CFrame.new(s * (W / 2 + 0.02), top - 0.4, roofMid + roofLen * 0.1 - 0.5), TRIM)
		box(ctx, "Sill", Vector3.new(0.08, 0.2, (rz - a) - (fz + a)), CFrame.new(s * (W / 2 + 0.02), bottom + 0.1, (fz + rz) / 2), TRIM)
	end

	-- Body kits
	if kit >= 2 then
		box(ctx, "Splitter", Vector3.new(W + 0.2, 0.08, 0.7), CFrame.new(0, bottom + 0.02, front - 0.25), DARK)
		for k = -2, 2 do
			box(ctx, "Diffuser", Vector3.new(0.06, 0.35, 0.7), CFrame.new(k * 0.7, bottom + 0.15, rear + 0.2), DARK)
		end
		for _, s in { -1, 1 } do
			box(ctx, "SideSkirt", Vector3.new(0.25, 0.28, (rz - a) - (fz + a)), CFrame.new(s * (W / 2 + 0.1), bottom + 0.12, (fz + rz) / 2), DARK)
			box(ctx, "Canard", Vector3.new(0.5, 0.06, 0.6), CFrame.new(s * (W / 2 - 0.2), bottom + 0.5, front - 0.2) * CFrame.Angles(0, 0, s * math.rad(-10)), DARK)
		end
	end
	if wide then
		for _, zc in { fz, rz } do
			for _, s in { -1, 1 } do
				paint(box(ctx, "Flare", Vector3.new(0.4, top - r * 1.25, a * 2 + 0.4), CFrame.new(s * (W / 2 + 0.2), (r * 1.25 + top) / 2, zc), bodyColor))
			end
		end
	end

	-- Spoiler
	local spoiler = opts.spoiler or d.spoiler
	local deck = top + 0.15
	if spoiler == 2 then
		paint(wedge(ctx, "Spoiler", Vector3.new(W - 0.8, 0.35, 0.9), CFrame.new(0, deck + 0.175, rear - 0.65), bodyColor))
	elseif spoiler == 3 or spoiler == 4 then
		local gt = spoiler == 4
		local wingY = deck + (if gt then 1.5 else 0.95)
		local wingW = if gt then W + 0.1 else W - 0.8
		box(ctx, "Spoiler", Vector3.new(wingW, 0.12, if gt then 1.4 else 1.0), CFrame.new(0, wingY, rear - 0.8) * CFrame.Angles(math.rad(-6), 0, 0), if gt then DARK else bodyColor)
		for _, s in { -1, 1 } do
			box(ctx, "SpoilerStrut", Vector3.new(0.12, wingY - deck, 0.45), CFrame.new(s * (wingW / 2 - 1.1), (wingY + deck) / 2, rear - 0.8), DARK)
			if gt then
				box(ctx, "Endplate", Vector3.new(0.08, 0.7, 1.6), CFrame.new(s * (wingW / 2), wingY + 0.1, rear - 0.8), DARK)
			end
		end
	end

	-- Wheels
	local wheelX = W / 2 - 0.6 + (if wide then 0.35 else 0)
	for _, z in { fz, rz } do
		for _, s in { -1, 1 } do
			buildWheel(ctx, d, s * wheelX, z, z == fz, opts)
		end
	end

	-- Police livery, light bar and push bar
	if opts.police then
		for _, s in { -1, 1 } do
			local door = box(ctx, "Door", Vector3.new(0.04, H - 0.4, (rz - a) - (fz + a) - 0.4), CFrame.new(s * (W / 2 + 0.03), midY + 0.05, (fz + rz) / 2), Color3.fromRGB(240, 240, 240))
			surfaceText(door, if s < 0 then Enum.NormalId.Left else Enum.NormalId.Right, "POLICE", Color3.fromRGB(20, 40, 140))
		end
		local hoodStripe = box(ctx, "HoodBadge", Vector3.new(1.4, 0.05, 1.4), CFrame.new(0, top + d.hood + 0.03, front + 1.6), Color3.fromRGB(240, 240, 240))
		local _ = hoodStripe
		local barY = roof + 0.15
		box(ctx, "LightbarBase", Vector3.new(cabW * 0.8, 0.14, 0.9), CFrame.new(0, barY - 0.05, roofMid), DARK)
		local sirens = {
			{ x = -1, color = Color3.fromRGB(255, 20, 30), name = "SirenRed" },
			{ x = 1, color = Color3.fromRGB(20, 80, 255), name = "SirenBlue" },
		}
		for _, info in sirens do
			local light = box(ctx, info.name, Vector3.new(cabW * 0.36, 0.26, 0.75), CFrame.new(info.x * cabW * 0.2, barY + 0.13, roofMid), info.color, Enum.Material.Neon)
			local pl = Instance.new("PointLight")
			pl.Color = info.color
			pl.Range = 30
			pl.Brightness = 5
			pl.Parent = light
		end
		for _, s in { -1, 1 } do
			box(ctx, "PushBar", Vector3.new(0.18, 1.1, 0.18), CFrame.new(s * 0.9, bottom + 0.75, front - 0.55), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		end
		box(ctx, "PushBarTop", Vector3.new(2.2, 0.18, 0.18), CFrame.new(0, bottom + 1.3, front - 0.55), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		box(ctx, "Antenna", Vector3.new(0.04, 1.2, 0.04), CFrame.new(0.6, roof + 0.6, roofE - 0.2), DARK)
		model:SetAttribute("Police", true)
	end

	-- Underglow
	local glowColor = opts.glow
	local glow = Instance.new("PointLight")
	glow.Name = "Underglow"
	glow.Range = 14
	glow.Color = glowColor or Color3.new(1, 1, 1)
	glow.Brightness = if glowColor then 3 else 0
	glow.Parent = chassis
	if glowColor then
		local strip = box(ctx, "GlowStrip", Vector3.new(W - 1.2, 0.05, L - 3.5), CFrame.new(0, bottom - 0.05, 0), glowColor, Enum.Material.Neon)
		strip.Transparency = 0.2
	end

	-- Nitro flames, Unbound style wing trails, drift smoke
	local effectColor = opts.effectColor or Color3.fromRGB(0, 255, 255)
	local exhaust = Instance.new("Attachment")
	exhaust.Name = "Exhaust"
	exhaust.Position = Vector3.new(tips[1], bottom + 0.22 - chassisH / 2, rear + 0.7)
	exhaust.Parent = chassis
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "NitroFlame"
	flame.Enabled = false
	flame.Color = ColorSequence.new(Color3.fromRGB(80, 170, 255), effectColor)
	flame.LightEmission = 1
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	flame.Lifetime = NumberRange.new(0.12, 0.25)
	flame.Rate = 140
	flame.Speed = NumberRange.new(20, 30)
	flame.EmissionDirection = Enum.NormalId.Back
	flame.Parent = exhaust

	for _, s in { -1, 1 } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(s * W / 2, top - 0.3 - chassisH / 2, rear)
		a0.Parent = chassis
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(s * (W / 2 + 1.6), top + 1.3 - chassisH / 2, rear)
		a1.Parent = chassis
		local trail = Instance.new("Trail")
		trail.Name = "EffectTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(effectColor)
		trail.LightEmission = 1
		trail.Lifetime = 0.45
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Enabled = false
		trail.Parent = chassis
	end

	local smokeAtt = Instance.new("Attachment")
	smokeAtt.Name = "Smoke"
	smokeAtt.Position = Vector3.new(0, -chassisH / 2 + 0.2, rz)
	smokeAtt.Parent = chassis
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DriftSmoke"
	smoke.Enabled = false
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 225))
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Size = NumberSequence.new(2, 8)
	smoke.Lifetime = NumberRange.new(0.8, 1.5)
	smoke.Rate = 60
	smoke.Speed = NumberRange.new(2, 5)
	smoke.SpreadAngle = Vector2.new(60, 20)
	smoke.Parent = smokeAtt

	if opts.seat then
		local seat = Instance.new("VehicleSeat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(1.4, 0.4, 1.4)
		seat.CFrame = CFrame.new(-cabW / 4, top - 0.4, roofMid + 0.2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Massless = true
		seat.MaxSpeed = 0
		seat.Torque = 0
		seat.TurnSpeed = 0
		seat.HeadsUpDisplay = false
		seat.Parent = model
		weldTo(chassis, seat)
	end

	if opts.label then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromOffset(200, 36)
		bb.StudsOffset = Vector3.new(0, roof + 2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 250
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = opts.label
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.3
		t.Parent = bb
		bb.Parent = chassis
	end

	return model
end

return CarBuilder
