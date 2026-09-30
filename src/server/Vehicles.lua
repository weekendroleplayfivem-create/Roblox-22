--!strict
-- Spawns, refreshes and resets player cars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local CarBuilder = require(script.Parent.CarBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local Showroom = require(script.Parent.Showroom)

local Vehicles = {}

local carsFolder = Instance.new("Folder")
carsFolder.Name = "Cars"
carsFolder.Parent = workspace
Vehicles.Folder = carsFolder

local safehouseSpawns: { CFrame } = {}
local spawnIndex = 0

function Vehicles.SetSpawns(spawns: { CFrame })
	safehouseSpawns = spawns
end

function Vehicles.NextSafehouseSpawn(): CFrame
	spawnIndex = spawnIndex % math.max(#safehouseSpawns, 1) + 1
	return safehouseSpawns[spawnIndex] or CFrame.new(0, 5, 0)
end

-- Chassis-centre CFrame for a car standing on the ground at `ground`.
function Vehicles.GroundCFrame(ground: CFrame, car: Model): CFrame
	local root = car.PrimaryPart :: BasePart
	local hover = car:GetAttribute("HoverCenter")
	return ground + Vector3.new(0, (if type(hover) == "number" then hover else root.Size.Y / 2) + 0.05, 0)
end

local function seatCharacter(s: Session.Session)
	local car = s.car
	local character = s.player.Character
	if not car or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat?
	if humanoid and seat and humanoid.Health > 0 then
		if seat.Occupant ~= humanoid then
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				character:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
			end
			seat:Sit(humanoid)
		end
		-- The driver sits behind tinted glass; hide the avatar so it doesn't poke through the roof.
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).Transparency = 1
			end
			-- a weightless driver: the avatar's mass high up in the cabin made the car wobble
			if d:IsA("BasePart") then
				d.Massless = true
			end
		end
	end
end
Vehicles.SeatCharacter = seatCharacter

function Vehicles.WriteStats(car: Model, stats: Config.Stats)
	for k, val in stats :: any do
		car:SetAttribute(k, val)
	end
	car:SetAttribute("RatingClass", Config.RatingClass(stats.rating))
end

-- Re-apply tuning stats to the current car without rebuilding it.
function Vehicles.ApplyStats(s: Session.Session)
	local car = s.car
	local def = Config.GetCar(s.profile.selected)
	if not car or not def then
		return
	end
	local stats = Config.ComputeStats(def, PlayerData.Tune(s.profile, def.id))
	s.stats = stats
	Vehicles.WriteStats(car, stats)
end

function Vehicles.Spawn(s: Session.Session, groundCFrame: CFrame?)
	local profile = s.profile
	local def = Config.GetCar(profile.selected) or Config.GetCar(Config.StarterCar)
	assert(def, "starter car missing")
	local ground = groundCFrame
	if not ground then
		local old = s.car
		if old and old.PrimaryPart and old.Parent then
			local p = old.PrimaryPart.Position
			local look = old.PrimaryPart.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude < 0.1 then
				flatLook = -Vector3.zAxis
			end
			local gp = Vector3.new(p.X, Grid.RoadY, p.Z)
			ground = CFrame.lookAt(gp, gp + flatLook.Unit)
		else
			ground = Vehicles.NextSafehouseSpawn()
		end
	end

	if s.car then
		s.car:Destroy()
		s.car = nil
	end

	local paintIndex = profile.paint[def.id]
	local color = if paintIndex then Config.PaintColors[paintIndex] or def.color else def.color
	local effect = Config.GetEffect(profile.effect)
	local tune = PlayerData.Tune(profile, def.id)
	local stats = Config.ComputeStats(def, tune)
	local v = tune.visual
	local glowEntry = Config.Visual.glow[v.glow] or Config.Visual.glow[1]
	local glowColor: Color3? = glowEntry.color
	if v.glow == 2 then
		glowColor = effect.color
	end
	local rimEntry = Config.Visual.rimColor[v.rimColor] or Config.Visual.rimColor[1]
	local tintEntry = Config.Visual.tint[v.tint] or Config.Visual.tint[2]
	local weaponDef = if profile.weapon ~= "" then Config.GetWeapon(profile.weapon) else nil

	local car = CarBuilder.Build({
		style = def.style,
		color = color,
		name = s.player.Name .. "_Car",
		seat = true,
		effectColor = effect.color,
		label = s.player.DisplayName,
		rim = v.rim,
		rimColor = rimEntry.color,
		tint = tintEntry.transparency,
		spoiler = v.spoiler,
		kit = v.kit,
		glow = glowColor,
		ride = tune.handling.ride,
		weapon = weaponDef and weaponDef.model,
		weaponColor = weaponDef and weaponDef.color,
	})
	car:SetAttribute("Owner", s.player.UserId)
	car:SetAttribute("CarId", def.id)
	car:SetAttribute("CarName", def.name)
	Vehicles.WriteStats(car, stats)
	local root = car.PrimaryPart :: BasePart
	-- streaming: the owner must always have their car, and the ground where it lands
	car.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local target = if s.inGarage then Showroom.CarCFrame.Position else (ground :: CFrame).Position
	pcall(function()
		s.player:RequestStreamAroundAsync(target, 4)
	end)
	if s.inGarage then
		-- parked on the showroom turntable while the garage menu is open
		local hover = car:GetAttribute("HoverCenter")
		car:PivotTo(Showroom.CarCFrame + Vector3.new(0, (if type(hover) == "number" then hover else 1.5) - 0.7, 0))
		root.Anchored = true
	else
		car:PivotTo(Vehicles.GroundCFrame(ground :: CFrame, car))
	end
	car.Parent = carsFolder
	s.car = car
	s.stats = stats

	if not s.inGarage then
		pcall(function()
			root:SetNetworkOwner(s.player)
		end)
	end
	seatCharacter(s)
	return car
end

-- Respawn the car upright on the closest road, facing along it.
function Vehicles.ResetToRoad(s: Session.Session)
	local pos = Session.CarPosition(s)
	if not pos then
		Vehicles.Spawn(s, Vehicles.NextSafehouseSpawn())
		return
	end
	local snapped = Grid.SnapToRoad(pos)
	local i, j = Grid.NearestIntersection(snapped)
	local ix = Grid.Intersection(i, j)
	local dir
	if math.abs(snapped.X - ix.X) < 1 and math.abs(snapped.Z - ix.Z) >= 1 then
		dir = Vector3.new(0, 0, math.sign(snapped.Z - ix.Z))
	else
		dir = Vector3.new(math.sign(snapped.X - ix.X), 0, 0)
	end
	if dir.Magnitude < 0.5 then
		dir = -Vector3.zAxis
	end
	-- keep the heading the car had if it was roughly aligned
	local car = s.car :: Model
	local look = (car.PrimaryPart :: BasePart).CFrame.LookVector
	if look:Dot(dir) < 0 then
		dir = -dir
	end
	Vehicles.Spawn(s, CFrame.lookAt(snapped, snapped + dir))
end

function Vehicles.Freeze(s: Session.Session, seconds: number)
	local car = s.car
	if not car or not car.PrimaryPart then
		return
	end
	local root = car.PrimaryPart
	root.Anchored = true
	s.frozenUntil = os.clock() + seconds
	task.delay(seconds, function()
		if s.car == car and root.Parent and os.clock() >= s.frozenUntil - 0.05 then
			root.Anchored = false
			pcall(function()
				root:SetNetworkOwner(s.player)
			end)
		end
	end)
end

return Vehicles
