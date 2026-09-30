--!strict
-- The garage interior you drive into from the safehouse: an enclosed workshop / showroom with a
-- turntable, spotlights, tool chests, tyre racks and posters. It sits underground, below the
-- city, so daylight never gets in.

local Showroom = {}

local ORIGIN = Vector3.new(0, -300, 0)
local W, D, H = 96, 76, 30

Showroom.Origin = ORIGIN
-- where the car sits (on the turntable), facing the camera side
Showroom.CarCFrame = CFrame.lookAt(ORIGIN + Vector3.new(0, 1.3, 0), ORIGIN + Vector3.new(-1, 1.3, 1))

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(folder: Instance, props: { [string]: any }): BasePart
	local p = Instance.new((props.ClassName or "Part") :: any) :: BasePart
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

local function text(target: BasePart, face: Enum.NormalId, str: string, color: Color3, bright: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = if bright then 0 else 1
	gui.Brightness = if bright then 2 else 1
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = str
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.Parent = gui
	gui.Parent = target
end

function Showroom.Build(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "GarageInterior"
	local o = ORIGIN

	-- shell
	local floor = part(folder, { Name = "Floor", Size = Vector3.new(W, 1, D), CFrame = CFrame.new(o + Vector3.new(0, -0.5, 0)), Color = rgb(58, 60, 64), Material = Enum.Material.Concrete, Reflectance = 0.12 })
	local _ = floor
	part(folder, { Name = "Ceiling", Size = Vector3.new(W, 1, D), CFrame = CFrame.new(o + Vector3.new(0, H + 0.5, 0)), Color = rgb(40, 40, 44), Material = Enum.Material.Metal })
	local wallColor = rgb(150, 150, 152)
	part(folder, { Name = "Wall", Size = Vector3.new(W, H, 1), CFrame = CFrame.new(o + Vector3.new(0, H / 2, -D / 2)), Color = wallColor, Material = Enum.Material.Concrete })
	-- front wall with a door opening (34 x 20) and a short exit tunnel behind the roll-up door
	local sideW = (W - 34) / 2
	for _, sx in { -1, 1 } do
		part(folder, { Name = "Wall", Size = Vector3.new(sideW, H, 1), CFrame = CFrame.new(o + Vector3.new(sx * (17 + sideW / 2), H / 2, D / 2)), Color = wallColor, Material = Enum.Material.Brick })
	end
	part(folder, { Name = "Wall", Size = Vector3.new(34, H - 20, 1), CFrame = CFrame.new(o + Vector3.new(0, 20 + (H - 20) / 2, D / 2)), Color = wallColor, Material = Enum.Material.Brick })
	local tunnelLen = 30
	local tz = D / 2 + tunnelLen / 2
	part(folder, { Name = "TunnelFloor", Size = Vector3.new(34, 1, tunnelLen), CFrame = CFrame.new(o + Vector3.new(0, -0.5, tz)), Color = rgb(40, 40, 44), Material = Enum.Material.Concrete })
	part(folder, { Name = "TunnelRoof", Size = Vector3.new(36, 1, tunnelLen), CFrame = CFrame.new(o + Vector3.new(0, 20.5, tz)), Color = rgb(30, 30, 34), Material = Enum.Material.Concrete })
	for _, sx in { -1, 1 } do
		part(folder, { Name = "TunnelWall", Size = Vector3.new(1, 20, tunnelLen), CFrame = CFrame.new(o + Vector3.new(sx * 17.5, 10, tz)), Color = rgb(36, 36, 40), Material = Enum.Material.Concrete })
		for k = 0, 2 do
			part(folder, { Name = "TunnelLight", Size = Vector3.new(0.3, 0.4, 4), CFrame = CFrame.new(o + Vector3.new(sx * 16.8, 17, D / 2 + 5 + k * 9)), Color = rgb(0, 230, 255), Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	part(folder, { Name = "TunnelEnd", Size = Vector3.new(34, 20, 1), CFrame = CFrame.new(o + Vector3.new(0, 10, D / 2 + tunnelLen)), Color = rgb(8, 8, 10), Material = Enum.Material.SmoothPlastic })
	part(folder, { Name = "Wall", Size = Vector3.new(1, H, D), CFrame = CFrame.new(o + Vector3.new(-W / 2, H / 2, 0)), Color = wallColor, Material = Enum.Material.Concrete })
	part(folder, { Name = "Wall", Size = Vector3.new(1, H, D), CFrame = CFrame.new(o + Vector3.new(W / 2, H / 2, 0)), Color = wallColor, Material = Enum.Material.Concrete })
	-- painted safety stripe along the walls
	for _, z in { -D / 2 + 0.55, D / 2 - 0.55 } do
		part(folder, { Name = "Stripe", Size = Vector3.new(W - 2, 1.2, 0.1), CFrame = CFrame.new(o + Vector3.new(0, 1.2, z)), Color = rgb(230, 180, 20), CanCollide = false })
	end
	-- floor markings around the bay
	for _, s in { -1, 1 } do
		part(folder, { Name = "BayLine", Size = Vector3.new(0.5, 0.05, 40), CFrame = CFrame.new(o + Vector3.new(s * 20, 0.03, 0)), Color = rgb(230, 180, 20), CanCollide = false })
	end

	-- turntable
	part(folder, { Name = "Turntable", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 30, 30), CFrame = CFrame.new(o + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(35, 35, 38), Material = Enum.Material.DiamondPlate, Reflectance = 0.1 })
	part(folder, { Name = "TurntableRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.62, 31, 31), CFrame = CFrame.new(o + Vector3.new(0, 0.29, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(0, 220, 255), Material = Enum.Material.Neon, CanCollide = false })

	-- ceiling light panels
	for x = -30, 30, 20 do
		for z = -20, 20, 20 do
			local panel = part(folder, { Name = "LightPanel", Size = Vector3.new(14, 0.3, 3), CFrame = CFrame.new(o + Vector3.new(x, H - 0.2, z)), Color = rgb(255, 250, 240), Material = Enum.Material.Neon, CanCollide = false })
			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 34
			light.Angle = 120
			light.Brightness = 1.4
			light.Color = rgb(255, 245, 230)
			light.Parent = panel
		end
	end
	-- key spotlights on the car
	for _, off in { Vector3.new(14, 0, 14), Vector3.new(-14, 0, -8) } do
		local lamp = part(folder, { Name = "Spot", Size = Vector3.new(1.5, 1.5, 1.5), CFrame = CFrame.lookAt(o + off + Vector3.new(0, H - 2, 0), o + Vector3.new(0, 1, 0)), Color = rgb(30, 30, 30), Material = Enum.Material.Metal, CanCollide = false })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 45
		spot.Brightness = 5
		spot.Shadows = true
		spot.Parent = lamp
	end

	-- back wall sign
	local sign = part(folder, { Name = "Sign", Size = Vector3.new(50, 7, 0.4), CFrame = CFrame.new(o + Vector3.new(0, H - 8, -D / 2 + 0.8)), Color = rgb(15, 15, 18), CanCollide = false })
	text(sign, Enum.NormalId.Front, "WANTED  UNBOUND  GARAGE", rgb(0, 230, 255), true)
	sign.CFrame = CFrame.lookAt(sign.Position, sign.Position + Vector3.zAxis)
	-- roll-up door on the front wall
	local door = part(folder, { Name = "RollUpDoor", Size = Vector3.new(34, 20, 0.4), CFrame = CFrame.new(o + Vector3.new(0, 10, D / 2 - 0.8)), Color = rgb(120, 124, 128), Material = Enum.Material.CorrodedMetal, CanCollide = false })
	local _ = door
	for y = 2, 18, 2 do
		part(folder, { Name = "DoorSlat", Size = Vector3.new(34, 0.15, 0.1), CFrame = CFrame.new(o + Vector3.new(0, y, D / 2 - 1.05)), Color = rgb(90, 92, 96), CanCollide = false })
	end

	-- tool chests
	for k = 0, 3 do
		local x = -W / 2 + 6 + k * 7
		part(folder, { Name = "ToolChest", Size = Vector3.new(6, 6, 3), CFrame = CFrame.new(o + Vector3.new(x, 3, -D / 2 + 2.5)), Color = rgb(190, 25, 30), Material = Enum.Material.Metal, Reflectance = 0.15 })
		for d = 1, 4 do
			part(folder, { Name = "Drawer", Size = Vector3.new(5.4, 0.12, 0.1), CFrame = CFrame.new(o + Vector3.new(x, d * 1.3, -D / 2 + 4.05)), Color = rgb(200, 200, 205), CanCollide = false })
		end
	end
	-- workbench + pegboard
	part(folder, { Name = "Workbench", Size = Vector3.new(20, 0.6, 4), CFrame = CFrame.new(o + Vector3.new(W / 2 - 14, 4, -D / 2 + 3)), Color = rgb(120, 86, 56), Material = Enum.Material.WoodPlanks })
	part(folder, { Name = "Pegboard", Size = Vector3.new(20, 8, 0.3), CFrame = CFrame.new(o + Vector3.new(W / 2 - 14, 10, -D / 2 + 0.8)), Color = rgb(170, 140, 100), Material = Enum.Material.Cardboard })
	-- tyre racks
	for k = 0, 5 do
		part(folder, { Name = "Tyre", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 3, 3), CFrame = CFrame.new(o + Vector3.new(-W / 2 + 2.5, 1.5 + (k % 3) * 3.1, -10 + math.floor(k / 3) * 4)), Color = rgb(25, 25, 27), Material = Enum.Material.Rubber })
	end
	-- car lift on the side
	for _, z in { 12, 24 } do
		part(folder, { Name = "LiftPost", Size = Vector3.new(1.4, 14, 1.4), CFrame = CFrame.new(o + Vector3.new(W / 2 - 6, 7, z)), Color = rgb(40, 90, 170), Material = Enum.Material.Metal })
	end
	-- posters
	for k, str in { "NITRO", "NEON BAY 24H", "APEX MOTORS" } do
		local poster = part(folder, { Name = "Poster", Size = Vector3.new(0.2, 8, 5.5), CFrame = CFrame.new(o + Vector3.new(-W / 2 + 0.7, 13, -18 + k * 9)), Color = rgb(20, 20, 30), CanCollide = false })
		text(poster, Enum.NormalId.Right, str, rgb(255, 80 + k * 50, 120), false)
	end

	folder.Parent = parent
end

return Showroom
