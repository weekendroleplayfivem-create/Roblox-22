--!strict
-- Spawns, refreshes and resets player cars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local CarBuilder = require(script.Parent.CarBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)

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
	return ground + Vector3.new(0, root.Size.Y / 2 + 0.4, 0)
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
	end
end
Vehicles.SeatCharacter = seatCharacter

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
	local stats = Config.ComputeStats(def, PlayerData.Upgrades(profile, def.id))

	local car = CarBuilder.Build({
		style = def.style,
		color = color,
		name = s.player.Name .. "_Car",
		seat = true,
		effectColor = effect.color,
		label = s.player.DisplayName,
	})
	car:SetAttribute("Owner", s.player.UserId)
	car:SetAttribute("CarId", def.id)
	car:SetAttribute("CarName", def.name)
	for k, v in stats :: any do
		car:SetAttribute(k, v)
	end
	car:PivotTo(Vehicles.GroundCFrame(ground :: CFrame, car))
	car.Parent = carsFolder
	s.car = car
	s.stats = stats

	local root = car.PrimaryPart :: BasePart
	pcall(function()
		root:SetNetworkOwner(s.player)
	end)
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
