--!strict
-- Builds car models from parts at runtime (no meshes needed), for players, police and rivals.

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
}

type Dims = {
	size: Vector3, -- chassis size
	bodyH: number,
	cabin: Vector3,
	cabinZ: number,
	spoiler: boolean,
	scoop: boolean,
}

local STYLES: { [string]: Dims } = {
	coupe = { size = Vector3.new(7, 1.6, 13), bodyH = 1.8, cabin = Vector3.new(6, 1.7, 6), cabinZ = 0.8, spoiler = false, scoop = false },
	hyper = { size = Vector3.new(7.4, 1.4, 13.6), bodyH = 1.4, cabin = Vector3.new(5.8, 1.4, 5), cabinZ = 0.4, spoiler = true, scoop = false },
	muscle = { size = Vector3.new(7.4, 1.8, 14.2), bodyH = 2, cabin = Vector3.new(6.2, 1.7, 5.6), cabinZ = 1.4, spoiler = false, scoop = true },
	suv = { size = Vector3.new(8, 2.2, 14), bodyH = 2.6, cabin = Vector3.new(7.6, 2.4, 8.5), cabinZ = 1.4, spoiler = false, scoop = false },
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function addText(target: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = target
end

function CarBuilder.Build(opts: BuildOptions): Model
	local style = if opts.heavy then "suv" else opts.style
	local d = STYLES[style] or STYLES.coupe
	local model = Instance.new("Model")
	model.Name = opts.name

	local size = d.size
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = size
	chassis.Transparency = 1
	chassis.CanCollide = true
	chassis.Anchored = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(if opts.heavy then 1.4 else 0.8, 0, 0, 100, 1)
	chassis.RootPriority = 10
	chassis.CFrame = CFrame.new(0, size.Y / 2, 0)
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- Keep the car upright (primary axis = attachment X axis, pointed up)
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

	local bottom = 0
	local bodyColor = opts.color
	local bodyY = bottom + 0.6 + d.bodyH / 2

	local body = part({
		Name = "Body",
		Size = Vector3.new(size.X + 0.2, d.bodyH, size.Z + 0.4),
		CFrame = CFrame.new(0, bodyY, 0),
		Color = bodyColor,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.15,
	})
	body.Parent = model
	weld(chassis, body)

	local cabinY = bodyY + d.bodyH / 2 + d.cabin.Y / 2
	local cabin = part({
		Name = "Cabin",
		Size = d.cabin,
		CFrame = CFrame.new(0, cabinY, d.cabinZ),
		Color = Color3.fromRGB(20, 25, 35),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Reflectance = 0.3,
	})
	cabin.Parent = model
	weld(chassis, cabin)

	local roof = part({
		Name = "Roof",
		Size = Vector3.new(d.cabin.X - 0.4, 0.3, d.cabin.Z - 1),
		CFrame = CFrame.new(0, cabinY + d.cabin.Y / 2 + 0.15, d.cabinZ + 0.3),
		Color = if opts.police then Color3.fromRGB(245, 245, 245) else bodyColor,
		Material = Enum.Material.SmoothPlastic,
	})
	roof.Parent = model
	weld(chassis, roof)

	if d.spoiler then
		local wing = part({
			Name = "Spoiler",
			Size = Vector3.new(size.X, 0.3, 1.4),
			CFrame = CFrame.new(0, bodyY + d.bodyH / 2 + 1.2, size.Z / 2 - 0.6),
			Color = Color3.fromRGB(20, 20, 20),
		})
		wing.Parent = model
		weld(chassis, wing)
		for _, x in { -size.X / 2 + 1, size.X / 2 - 1 } do
			local strut = part({
				Size = Vector3.new(0.3, 1.1, 0.5),
				CFrame = CFrame.new(x, bodyY + d.bodyH / 2 + 0.55, size.Z / 2 - 0.6),
				Color = Color3.fromRGB(20, 20, 20),
			})
			strut.Parent = model
			weld(chassis, strut)
		end
	end

	if d.scoop then
		local scoop = part({
			Name = "Scoop",
			Size = Vector3.new(2.2, 0.6, 3),
			CFrame = CFrame.new(0, bodyY + d.bodyH / 2 + 0.3, -size.Z / 2 + 3.5),
			Color = Color3.fromRGB(15, 15, 15),
		})
		scoop.Parent = model
		weld(chassis, scoop)
	end

	-- Racing stripe for player / rival cars
	if not opts.police then
		local stripe = part({
			Name = "Stripe",
			Size = Vector3.new(1.2, 0.05, size.Z + 0.42),
			CFrame = CFrame.new(0, bodyY + d.bodyH / 2 + 0.02, 0),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
		})
		stripe.Parent = model
		weld(chassis, stripe)
	end

	-- Wheels
	local wheelRadius = 1.35
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local wheel = part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.3, wheelRadius * 2, wheelRadius * 2),
				CFrame = CFrame.new(x * (size.X / 2), bottom + wheelRadius - 0.1, z * (size.Z / 2 - 2.4)),
				Color = Color3.fromRGB(25, 25, 25),
				Material = Enum.Material.SmoothPlastic,
			})
			wheel.Parent = model
			weld(chassis, wheel)
			local rim = part({
				Name = "Rim",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.35, wheelRadius * 1.1, wheelRadius * 1.1),
				CFrame = wheel.CFrame,
				Color = Color3.fromRGB(190, 190, 200),
				Material = Enum.Material.Metal,
			})
			rim.Parent = model
			weld(chassis, rim)
		end
	end

	-- Headlights / taillights
	for _, x in { -1, 1 } do
		local head = part({
			Name = "Headlight",
			Size = Vector3.new(1.4, 0.5, 0.2),
			CFrame = CFrame.new(x * (size.X / 2 - 1.1), bodyY + 0.2, -size.Z / 2 - 0.25),
			Color = Color3.fromRGB(255, 250, 220),
			Material = Enum.Material.Neon,
		})
		head.Parent = model
		weld(chassis, head)
		local tail = part({
			Name = "Taillight",
			Size = Vector3.new(1.6, 0.45, 0.2),
			CFrame = CFrame.new(x * (size.X / 2 - 1.1), bodyY + 0.2, size.Z / 2 + 0.25),
			Color = Color3.fromRGB(255, 30, 40),
			Material = Enum.Material.Neon,
		})
		tail.Parent = model
		weld(chassis, tail)
	end
	local beamPart = model:FindFirstChild("Headlight") :: BasePart
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 70
	spot.Brightness = 2.5
	spot.Color = Color3.fromRGB(255, 245, 220)
	spot.Parent = beamPart

	-- Police livery and light bar
	if opts.police then
		body.Color = Color3.fromRGB(15, 15, 20)
		for _, side in { -1, 1 } do
			local door = part({
				Name = "Door",
				Size = Vector3.new(0.1, d.bodyH * 0.8, size.Z * 0.45),
				CFrame = CFrame.new(side * (size.X / 2 + 0.12), bodyY, 0.5),
				Color = Color3.fromRGB(245, 245, 245),
				Material = Enum.Material.SmoothPlastic,
			})
			door.Parent = model
			weld(chassis, door)
			addText(door, if side < 0 then Enum.NormalId.Left else Enum.NormalId.Right, "POLICE", Color3.fromRGB(20, 40, 140))
		end
		local barY = roof.Position.Y + 0.4
		local sirens = {
			{ x = -1, color = Color3.fromRGB(255, 20, 30), name = "SirenRed" },
			{ x = 1, color = Color3.fromRGB(20, 80, 255), name = "SirenBlue" },
		}
		for _, info in sirens do
			local light = part({
				Name = info.name,
				Size = Vector3.new(1.8, 0.5, 0.9),
				CFrame = CFrame.new(info.x * 1.1, barY, roof.Position.Z),
				Color = info.color,
				Material = Enum.Material.Neon,
			})
			light.Parent = model
			weld(chassis, light)
			local pl = Instance.new("PointLight")
			pl.Color = info.color
			pl.Range = 24
			pl.Brightness = 4
			pl.Parent = light
		end
		model:SetAttribute("Police", true)
	end

	-- Underglow + nitro / driving effect emitters
	local effectColor = opts.effectColor or Color3.fromRGB(0, 255, 255)
	local glow = Instance.new("PointLight")
	glow.Name = "Underglow"
	glow.Color = if opts.police then Color3.fromRGB(80, 80, 255) else effectColor
	glow.Range = 14
	glow.Brightness = if opts.police then 0 else 2
	glow.Parent = chassis

	local exhaust = Instance.new("Attachment")
	exhaust.Name = "Exhaust"
	exhaust.Position = Vector3.new(0, 0.4, size.Z / 2 + 0.5)
	exhaust.Parent = chassis
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "NitroFlame"
	flame.Enabled = false
	flame.Color = ColorSequence.new(Color3.fromRGB(80, 170, 255), effectColor)
	flame.LightEmission = 1
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	flame.Lifetime = NumberRange.new(0.15, 0.3)
	flame.Rate = 120
	flame.Speed = NumberRange.new(20, 30)
	flame.EmissionDirection = Enum.NormalId.Back
	flame.Parent = exhaust

	-- Unbound style "wings" trails off the rear corners
	for _, side in { -1, 1 } do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(side * size.X / 2, 0.5, size.Z / 2)
		a0.Parent = chassis
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(side * (size.X / 2 + 1.8), 2.2, size.Z / 2)
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

	-- Drift smoke
	local smokeAtt = Instance.new("Attachment")
	smokeAtt.Name = "Smoke"
	smokeAtt.Position = Vector3.new(0, -0.6, size.Z / 2 - 2)
	smokeAtt.Parent = chassis
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DriftSmoke"
	smoke.Enabled = false
	smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 225))
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Size = NumberSequence.new(2, 7)
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Rate = 60
	smoke.Speed = NumberRange.new(2, 5)
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.Parent = smokeAtt

	if opts.seat then
		local seat = Instance.new("VehicleSeat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2, 0.6, 2)
		seat.CFrame = CFrame.new(0, bodyY + d.bodyH / 2 - 0.8, d.cabinZ + 0.5)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Massless = true
		seat.MaxSpeed = 0
		seat.Torque = 0
		seat.TurnSpeed = 0
		seat.HeadsUpDisplay = false
		seat.Parent = model
		weld(chassis, seat)
	end

	if opts.label then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromOffset(200, 40)
		bb.StudsOffset = Vector3.new(0, 6, 0)
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
