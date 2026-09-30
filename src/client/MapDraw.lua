--!strict
-- Draws the city (districts, roads, coast and points of interest) into a GUI frame at any
-- scale. Used by the radar minimap and the full-screen city map.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))

local MapDraw = {}

MapDraw.WorldSize = Grid.Half * 2 + Config.Grid.RoadWidth
MapDraw.Margin = 260 -- studs of coast drawn around the city

local DISTRICT_COLORS = {
	downtown = Color3.fromRGB(58, 58, 74),
	midtown = Color3.fromRGB(66, 66, 78),
	suburb = Color3.fromRGB(48, 74, 50),
	industrial = Color3.fromRGB(78, 72, 62),
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Returns a function mapping world positions to pixel offsets inside `canvas`.
function MapDraw.Draw(canvas: Frame, scale: number, labels: boolean): (Vector3) -> Vector2
	local margin = MapDraw.Margin
	local total = MapDraw.WorldSize + margin * 2
	canvas.Size = UDim2.fromOffset(total * scale, total * scale)
	local origin = MapDraw.WorldSize / 2 + margin
	local function px(pos: Vector3): Vector2
		return Vector2.new((pos.X + origin) * scale, (pos.Z + origin) * scale)
	end
	local function rect(center: Vector3, sizeX: number, sizeZ: number, color: Color3, z: number, name: string?)
		local p = px(center)
		return new("Frame", {
			Name = name or "Rect",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(p.X, p.Y),
			Size = UDim2.fromOffset(math.max(1, sizeX * scale), math.max(1, sizeZ * scale)),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, canvas)
	end

	-- land and sea
	local half = MapDraw.WorldSize / 2
	rect(Vector3.zero, total, total, Color3.fromRGB(40, 58, 40), 1, "Land")
	local sea = Color3.fromRGB(22, 64, 92)
	rect(Vector3.new(half + margin / 2 + 20, 0, 0), margin - 40, total, sea, 1, "Sea")
	rect(Vector3.new(0, 0, half + margin / 2 + 20), total, margin - 40, sea, 1, "Sea")
	rect(Vector3.new(half + 30, 0, 0), 60, MapDraw.WorldSize + 60, Color3.fromRGB(190, 170, 120), 1, "Beach")
	rect(Vector3.new(0, 0, half + 30), MapDraw.WorldSize + 60, 60, Color3.fromRGB(190, 170, 120), 1, "Beach")

	-- districts
	local B = Config.Blocks
	for bx = 0, Grid.Size - 1 do
		for bz = 0, Grid.Size - 1 do
			local color = DISTRICT_COLORS[Config.District(bx, bz)]
			if bx == B.Park[1] and bz == B.Park[2] then
				color = Color3.fromRGB(60, 110, 60)
			end
			rect(Grid.BlockCenter(bx, bz), Config.Grid.BlockSize, Config.Grid.BlockSize, color, 2, "Block")
		end
	end

	-- roads (the Beltway ring is drawn brighter)
	for i = 0, Grid.Size do
		local ring = i == 0 or i == Grid.Size
		local color = if ring then Color3.fromRGB(200, 170, 80) else Color3.fromRGB(125, 125, 140)
		local w = Config.Grid.RoadWidth * (if ring then 1.4 else 1)
		local a = Grid.Intersection(i, Grid.Size / 2)
		rect(Vector3.new(a.X, 0, 0), w, MapDraw.WorldSize, color, 3, "Road")
		local b = Grid.Intersection(Grid.Size / 2, i)
		rect(Vector3.new(0, 0, b.Z), MapDraw.WorldSize, w, color, 3, "Road")
	end

	-- points of interest
	local function marker(pos: Vector3, color: Color3, size: number, text: string?, caption: string?)
		local p = px(pos)
		local f = new("Frame", {
			Name = "Marker",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(p.X, p.Y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			ZIndex = 5,
		}, canvas)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.4 }, f)
		if text then
			new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(0, 0, 0), ZIndex = 6 }, f)
		end
		if caption and labels then
			new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				Size = UDim2.fromOffset(160, 16),
				BackgroundTransparency = 1,
				Text = caption,
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.3,
				ZIndex = 6,
			}, f)
		end
	end
	local big = if labels then 1.4 else 1
	marker(Grid.BlockCenter(B.Safehouse[1], B.Safehouse[2]), Color3.fromRGB(0, 255, 200), 14 * big, "S", "SAFEHOUSE")
	marker(Grid.BlockCenter(B.BlackMarket[1], B.BlackMarket[2]), Color3.fromRGB(255, 40, 50), 13 * big, "B", "BLACK MARKET")
	for _, h in B.HidingSpots do
		marker(Grid.BlockCenter(h[1], h[2]), Color3.fromRGB(80, 255, 120), 9 * big, "H", "Hiding spot")
	end
	for _, b in Config.PursuitBreakers do
		marker(Grid.Intersection(b[1], b[2]) + Vector3.new(36, 0, 36), Color3.fromRGB(255, 70, 70), 7 * big, nil, nil)
	end
	for _, r in Config.Races do
		local p = r.route[1]
		marker(Grid.Intersection(p[1], p[2]), if r.kind == "drift" then Color3.fromRGB(255, 140, 0) else Color3.fromRGB(255, 40, 160), 11 * big, "R", r.name .. "  $" .. r.buyIn)
	end
	return px
end

return MapDraw
