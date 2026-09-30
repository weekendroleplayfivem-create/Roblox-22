--!strict
-- Most Wanted style police: patrols, heat levels, pursuits, evasion + cooldown,
-- busts, roadblocks, a helicopter at heat 5, wrecking cops and pursuit breakers.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local CarPhysics = require(Shared:WaitForChild("CarPhysics"))
local AIDriver = require(script.Parent.AIDriver)
local CarBuilder = require(script.Parent.CarBuilder)
local MapBuilder = require(script.Parent.MapBuilder)
local Session = require(script.Parent.Session)
local Vehicles = require(script.Parent.Vehicles)

local Police = {}

local P = Config.Police
local mapInfo: MapBuilder.MapInfo
local patrols: { AIDriver.AI } = {}
local roadblocks: { [Player]: { Model } } = {}
local helis: { [Player]: Model } = {}
local onBusted: ((s: Session.Session) -> ())? = nil

local policeFolder = Instance.new("Folder")
policeFolder.Name = "Police"
policeFolder.Parent = workspace

local RED = Color3.fromRGB(255, 70, 70)
local makeSpikeStrip: (center: Vector3, dir: Vector3, across: Vector3, width: number, parent: Instance) -> BasePart
local BLUE = Color3.fromRGB(90, 160, 255)

local function level(s: Session.Session): Config.HeatLevel
	return Config.HeatLevels[math.max(1, Session.HeatLevel(s))]
end

local function copStats(heavy: boolean): CarPhysics.Stats
	return {
		maxSpeed = P.BaseSpeed * (if heavy then 0.95 else 1),
		accel = P.Accel * (if heavy then 0.9 else 1),
		brake = 100,
		turn = P.Turn * (if heavy then 0.85 else 1),
		grip = P.Grip,
		nitroMult = 1.2,
	}
end

local function randomIntersection(): Vector3
	return Grid.Intersection(math.random(0, Grid.Size), math.random(0, Grid.Size))
end

local function inHiding(pos: Vector3): boolean
	for _, z in mapInfo.hidingZones do
		if math.abs(pos.X - z.center.X) < z.size.X / 2 and math.abs(pos.Z - z.center.Z) < z.size.Z / 2 then
			return true
		end
	end
	return false
end

local function playerCarFromPart(part: BasePart): (Model?, Session.Session?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= Vehicles.Folder do
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	if not model then
		return nil, nil
	end
	local owner = model:GetAttribute("Owner")
	if type(owner) ~= "number" then
		return nil, nil
	end
	local player = Players:GetPlayerByUserId(owner)
	if not player then
		return nil, nil
	end
	return model, Session.Get(player)
end

---------------------------------------------------------------------------
-- Pursuit state changes
---------------------------------------------------------------------------
local function startPursuit(s: Session.Session, reason: string)
	if s.mode ~= "idle" or s.race then
		return
	end
	s.mode = "pursuit"
	s.heat = math.max(s.heat, 1)
	s.evade = 0
	s.cooldown = 0
	s.bust = 0
	s.bounty = 0
	s.pursuitTime = 0
	s.copsWrecked = 0
	s.lastCopSpawn = os.clock()
	s.lastRoadblock = os.clock()
	Session.Banner(s.player, "PURSUIT", reason, RED)
end
Police.StartPursuit = startPursuit

local function releaseCop(ai: AIDriver.AI)
	ai.data.mode = "leave"
	ai.data.session = nil
	ai.data.roam = randomIntersection()
	task.delay(6, function()
		AIDriver.Remove(ai)
		if ai.model.Parent then
			ai.model:Destroy()
		end
	end)
end

local function clearRoadblocks(player: Player)
	local list = roadblocks[player]
	if list then
		for _, m in list do
			m:Destroy()
		end
	end
	roadblocks[player] = nil
end

local function endPursuit(s: Session.Session)
	s.mode = "idle"
	s.evade = 0
	s.cooldown = 0
	s.bust = 0
	s.bounty = 0
	for _, ai in s.cops do
		if ai.alive then
			releaseCop(ai)
		end
	end
	s.cops = {}
	local heli = helis[s.player]
	if heli then
		helis[s.player] = nil
		heli:SetAttribute("Leaving", true)
		Debris:AddItem(heli, 6)
	end
	s.heli = nil
	clearRoadblocks(s.player)
end
Police.EndPursuit = endPursuit

local function busted(s: Session.Session)
	local lost = math.floor(s.unbanked)
	Session.Banner(s.player, "BUSTED", "You lost $" .. lost .. " of unbanked cash", RED)
	s.unbanked = 0
	s.heat = 0
	endPursuit(s)
	if onBusted then
		onBusted(s)
	end
	Vehicles.Spawn(s, Vehicles.NextSafehouseSpawn())
	Vehicles.Freeze(s, 2)
end

local function escaped(s: Session.Session)
	local reward = math.floor(s.bounty)
	s.profile.totalBounty += reward
	Session.Banner(s.player, "ESCAPED", "Bounty +" .. reward .. "  -  bank it at the safehouse", Color3.fromRGB(80, 255, 140))
	Session.AddStat(s, "pursuitsEvaded", 1)
	Session.MaxStat(s, "maxHeatEvaded", Session.HeatLevel(s))
	Session.MaxStat(s, "bestBounty", reward)
	Session.AddUnbanked(s, reward, "Bounty cash (take it to the safehouse)")
	endPursuit(s)
end

---------------------------------------------------------------------------
-- Cop cars
---------------------------------------------------------------------------
local wreck: (ai: AIDriver.AI, by: Session.Session?) -> ()

local function copThink(ai: AIDriver.AI, _dt: number)
	local mode = ai.data.mode
	local state = ai.state
	local pos = state.root.Position
	ai.input.nitro = false
	if mode == "chase" or mode == "search" then
		local s = ai.data.session :: Session.Session?
		if not s then
			ai.data.mode = "patrol"
			return
		end
		local target = Session.CarPosition(s)
		local lvl = level(s)
		if mode == "chase" and target then
			local car = s.car :: Model
			local vel = (car.PrimaryPart :: BasePart).AssemblyLinearVelocity
			local dist = (target - pos).Magnitude
			local mult = lvl.speedMult
			if dist > 260 then
				mult *= 1.3
			elseif dist > 120 then
				mult *= 1.12
			end
			state.speedMult = mult
			local lead = math.clamp(dist / 200, 0.1, 0.6)
			AIDriver.DriveTo(ai, target + vel * lead, dist < 60)
			-- hit the nitro to catch up on long straights
			ai.input.nitro = dist > 180 and math.abs(ai.input.steer) < 0.3
		else
			local goal = ai.data.searchGoal or s.lastSeen or pos
			if (goal - pos).Magnitude < 35 then
				ai.data.searchGoal = (s.lastSeen or pos) + Vector3.new(math.random(-400, 400), 0, math.random(-400, 400))
			end
			state.speedMult = lvl.speedMult * 0.8
			AIDriver.DriveTo(ai, goal)
		end
	else
		-- patrol / leave: cruise between random intersections
		local goal = ai.data.roam :: Vector3?
		if not goal or (goal - pos).Magnitude < 35 then
			local i, j = Grid.NearestIntersection(pos)
			goal = Grid.Intersection(math.clamp(i + math.random(-3, 3), 0, Grid.Size), math.clamp(j + math.random(-3, 3), 0, Grid.Size))
			ai.data.roam = goal
		end
		state.speedMult = if mode == "leave" then 0.9 else 0.5
		AIDriver.DriveTo(ai, goal :: Vector3)
	end
end

local function spawnCop(pos: Vector3, look: Vector3, heavy: boolean, mode: string, s: Session.Session?): AIDriver.AI
	local model = CarBuilder.Build({
		style = "coupe",
		color = Color3.fromRGB(15, 15, 20),
		name = if heavy then "PoliceHeavy" else "Police",
		police = true,
		heavy = heavy,
	})
	model:SetAttribute("Siren", mode ~= "patrol")
	local root = model.PrimaryPart :: BasePart
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.zAxis
	end
	local p = Vector3.new(pos.X, Grid.RoadY + root.Size.Y / 2 + 0.5, pos.Z)
	model:PivotTo(CFrame.lookAt(p, p + flat.Unit))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- visible on the radar city-wide
	model.Parent = policeFolder
	local ai = AIDriver.Add(model, copStats(heavy), "cop", copThink)
	ai.data.mode = mode
	ai.data.session = s
	ai.data.health = if heavy then P.CopHealth * 1.7 else P.CopHealth
	ai.data.lastHit = 0

	root.Touched:Connect(function(hit)
		if not ai.alive or ai.data.wrecked then
			return
		end
		local car, owner = playerCarFromPart(hit)
		if not car or not owner then
			return
		end
		local now = os.clock()
		if now - ai.data.lastHit < 0.4 then
			return
		end
		local carRoot = car.PrimaryPart :: BasePart
		local rel = (carRoot.AssemblyLinearVelocity - root.AssemblyLinearVelocity).Magnitude
		if rel < 25 then
			return
		end
		ai.data.lastHit = now
		ai.data.health -= (rel - 20) * 1.1
		if owner.mode == "idle" then
			if not owner.race then
				startPursuit(owner, "Ramming a police vehicle!")
				if ai.data.mode == "patrol" then
					local idx = table.find(patrols, ai)
					if idx then
						table.remove(patrols, idx)
					end
					ai.data.mode = "chase"
					ai.data.session = owner
					model:SetAttribute("Siren", true)
					table.insert(owner.cops, ai)
				end
			end
		else
			owner.heat = math.min(5, owner.heat + 0.05)
		end
		if ai.data.health <= 0 then
			wreck(ai, owner)
		end
	end)
	return ai
end

wreck = function(ai: AIDriver.AI, by: Session.Session?)
	if ai.data.wrecked then
		return
	end
	ai.data.wrecked = true
	AIDriver.Remove(ai)
	local idx = table.find(patrols, ai)
	if idx then
		table.remove(patrols, idx)
	end
	local owner = ai.data.session :: Session.Session?
	if owner then
		local i2 = table.find(owner.cops, ai)
		if i2 then
			table.remove(owner.cops, i2)
		end
	end
	local model = ai.model
	model:SetAttribute("Siren", false)
	local root = model.PrimaryPart :: BasePart
	local boom = Instance.new("Explosion")
	boom.BlastPressure = 0
	boom.BlastRadius = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Position = root.Position
	boom.Parent = workspace
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Chassis" then
			d.Color = d.Color:Lerp(Color3.fromRGB(20, 20, 20), 0.7)
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Parent = root
	local align = root:FindFirstChild("Upright") :: AlignOrientation?
	if align then
		align.Enabled = false
	end
	root.AssemblyLinearVelocity += Vector3.new(0, 30, 0)
	root.AssemblyAngularVelocity = Vector3.new(math.random() * 4, math.random() * 2, math.random() * 4)
	Debris:AddItem(model, 6)
	if by and by.mode ~= "idle" then
		by.copsWrecked += 1
		Session.AddStat(by, "copsWrecked", 1)
		by.bounty += Config.Bounty.CopWrecked * Session.NightMult()
		by.heat = math.min(5, by.heat + 0.12)
		Session.Notify(by.player, "COP WRECKED  +" .. Config.Bounty.CopWrecked .. " bounty", Color3.fromRGB(255, 160, 60))
	end
end

local function spawnCopFor(s: Session.Session)
	local target = Session.CarPosition(s)
	if not target then
		return
	end
	local candidates = {}
	for i = 0, Grid.Size do
		for j = 0, Grid.Size do
			local p = Grid.Intersection(i, j)
			local d = (p - target).Magnitude
			if d > 220 and d < 460 then
				table.insert(candidates, p)
			end
		end
	end
	if #candidates == 0 then
		return
	end
	local p = candidates[math.random(1, #candidates)]
	local lvl = level(s)
	local heavy = lvl.heavy and math.random() < 0.4
	local ai = spawnCop(p, target - p, heavy, if s.mode == "pursuit" then "chase" else "search", s)
	table.insert(s.cops, ai)
end

---------------------------------------------------------------------------
-- Spike strips: flatten the tyres of any player car that drives over them
---------------------------------------------------------------------------
local function flatten(owner: Session.Session)
	local car = owner.car
	if not car or car:GetAttribute("Flat") then
		return
	end
	car:SetAttribute("Flat", true)
	local root = car.PrimaryPart
	local smokeAtt = root and root:FindFirstChild("Smoke")
	if smokeAtt then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 90, 20))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.Lifetime = NumberRange.new(0.2, 0.45)
		sparks.Speed = NumberRange.new(15, 30)
		sparks.SpreadAngle = Vector2.new(35, 35)
		sparks.Rate = 90
		sparks.Acceleration = Vector3.new(0, -60, 0)
		sparks.Parent = smokeAtt
		Debris:AddItem(sparks, Config.Spikes.FlatSeconds)
	end
	Session.Banner(owner.player, "SPIKED!", "Flat tyres - slow and slippery for " .. Config.Spikes.FlatSeconds .. "s", RED)
	task.delay(Config.Spikes.FlatSeconds, function()
		if car.Parent then
			car:SetAttribute("Flat", false)
		end
	end)
end

makeSpikeStrip = function(center: Vector3, dir: Vector3, across: Vector3, width: number, parent: Instance): BasePart
	local strip = Instance.new("Part")
	strip.Name = "SpikeStrip"
	strip.Anchored = true
	strip.CanCollide = false
	strip.Size = Vector3.new(width, 0.35, 2.2)
	strip.CFrame = CFrame.lookAt(center + Vector3.new(0, Grid.RoadY + 0.18, 0), center + Vector3.new(0, Grid.RoadY + 0.18, 0) + dir) * CFrame.Angles(0, 0, 0)
	-- the strip's long side runs across the road
	strip.CFrame = CFrame.fromMatrix(center + Vector3.new(0, Grid.RoadY + 0.18, 0), across, Vector3.yAxis)
	strip.Color = Color3.fromRGB(60, 60, 65)
	strip.Material = Enum.Material.DiamondPlate
	strip.Parent = parent
	local teeth = math.floor(width / 1.5)
	for k = 0, teeth - 1 do
		local tooth = Instance.new("WedgePart")
		tooth.Anchored = true
		tooth.CanCollide = false
		tooth.CanTouch = false
		tooth.CanQuery = false
		tooth.Size = Vector3.new(0.3, 0.6, 0.6)
		tooth.Color = Color3.fromRGB(200, 200, 210)
		tooth.Material = Enum.Material.Metal
		tooth.CFrame = strip.CFrame * CFrame.new(-width / 2 + 0.75 + k * 1.5, 0.45, 0)
		tooth.Parent = parent
	end
	strip.Touched:Connect(function(hit)
		local _, owner = playerCarFromPart(hit)
		if owner then
			flatten(owner)
		end
	end)
	return strip
end

---------------------------------------------------------------------------
-- Roadblocks
---------------------------------------------------------------------------
local function spawnRoadblock(s: Session.Session)
	local car = s.car
	if not car or not car.PrimaryPart then
		return
	end
	local root = car.PrimaryPart
	local vel = root.AssemblyLinearVelocity
	if vel.Magnitude < 40 then
		return
	end
	local dx, dz = 0, 0
	if math.abs(vel.X) > math.abs(vel.Z) then
		dx = math.sign(vel.X)
	else
		dz = math.sign(vel.Z)
	end
	local i, j = Grid.NearestIntersection(root.Position)
	local ti, tj = i + dx * 2, j + dz * 2
	if not Grid.InBounds(ti, tj) then
		ti, tj = i + dx, j + dz
		if not Grid.InBounds(ti, tj) then
			return
		end
	end
	local dir = Vector3.new(dx, 0, dz)
	local across = dir:Cross(Vector3.yAxis)
	local center = Grid.Intersection(ti, tj) - dir * 45
	local model = Instance.new("Model")
	model.Name = "Roadblock"
	local heatLvl = Session.HeatLevel(s)
	local spikes = heatLvl >= Config.Spikes.MinHeat
	-- from heat 4, some "roadblocks" are just a long spike strip with one open lane
	if heatLvl >= 4 and math.random() < 0.4 then
		local openSide = if math.random() < 0.5 then -1 else 1
		makeSpikeStrip(center - openSide * across * 6, dir, across, 42, model)
		for k = -3, 3 do
			local cone = Instance.new("Part")
			cone.Name = "Cone"
			cone.Size = Vector3.new(1.5, 2.5, 1.5)
			cone.Color = Color3.fromRGB(255, 120, 0)
			cone.Material = Enum.Material.Neon
			cone.CFrame = CFrame.new(center - dir * 25 - openSide * across * (6 + k * 5) + Vector3.new(0, Grid.RoadY + 1.25, 0))
			cone.Parent = model
		end
		model.Parent = policeFolder
		local list = roadblocks[s.player] or {}
		table.insert(list, model)
		roadblocks[s.player] = list
		Debris:AddItem(model, 40)
		Session.Notify(s.player, "SPIKE STRIP AHEAD!", RED)
		return
	end
	local counted = false
	for _, off in { -24, -12, 12, 24 } do
		local cop = CarBuilder.Build({ style = "coupe", color = Color3.fromRGB(15, 15, 20), name = "RoadblockCar", police = true })
		cop:SetAttribute("Siren", true)
		local croot = cop.PrimaryPart :: BasePart
		local pos = center + across * off + Vector3.new(0, croot.Size.Y / 2 + 0.5, 0)
		cop:PivotTo(CFrame.lookAt(pos, pos + across))
		croot.Anchored = true
		cop.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		cop.Parent = model
		local smashed = false
		croot.Touched:Connect(function(hit)
			if smashed then
				return
			end
			local pcar, owner = playerCarFromPart(hit)
			if not pcar or not owner then
				return
			end
			local speed = (pcar.PrimaryPart :: BasePart).AssemblyLinearVelocity.Magnitude
			if speed < 70 then
				return
			end
			smashed = true
			croot.Anchored = false
			croot.AssemblyLinearVelocity = dir * 50 + Vector3.new(0, 25, 0)
			croot.AssemblyAngularVelocity = Vector3.new(3, 2, 1)
			if owner.mode ~= "idle" and not counted then
				counted = true
				owner.bounty += Config.Bounty.RoadblockSmashed * Session.NightMult()
				Session.AddStat(owner, "roadblocksSmashed", 1)
				Session.Notify(owner.player, "ROADBLOCK SMASHED  +" .. Config.Bounty.RoadblockSmashed .. " bounty", Color3.fromRGB(255, 160, 60))
			end
		end)
	end
	if spikes then
		-- spike strip in the gap between the cars
		makeSpikeStrip(center - dir * 10, dir, across, 12, model)
	end
	for k = -2, 2 do
		local cone = Instance.new("Part")
		cone.Name = "Cone"
		cone.Size = Vector3.new(1.5, 2.5, 1.5)
		cone.Color = Color3.fromRGB(255, 120, 0)
		cone.Material = Enum.Material.Neon
		cone.CFrame = CFrame.new(center - dir * 20 + across * (k * 6) + Vector3.new(0, Grid.RoadY + 1.25, 0))
		cone.Parent = model
	end
	model.Parent = policeFolder
	local list = roadblocks[s.player] or {}
	table.insert(list, model)
	roadblocks[s.player] = list
	Debris:AddItem(model, 40)
	Session.Notify(s.player, "ROADBLOCK AHEAD!", RED)
end

---------------------------------------------------------------------------
-- Helicopter (heat 5)
---------------------------------------------------------------------------
local function spawnHeli(s: Session.Session)
	local pos = Session.CarPosition(s)
	if not pos then
		return
	end
	local model = Instance.new("Model")
	model.Name = "PoliceHeli"
	local function add(props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		for k, v in props do
			(p :: any)[k] = v
		end
		p.Parent = model
		return p
	end
	local body = add({ Name = "Body", Size = Vector3.new(8, 7, 14), Color = Color3.fromRGB(20, 25, 40), Material = Enum.Material.SmoothPlastic })
	add({ Name = "Tail", Size = Vector3.new(1.5, 1.5, 14), Color = Color3.fromRGB(20, 25, 40) })
	add({ Name = "Rotor", Size = Vector3.new(34, 0.3, 2), Color = Color3.fromRGB(40, 40, 40) })
	local lamp = add({ Name = "Lamp", Size = Vector3.new(2, 1, 2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Range = 140
	spot.Angle = 35
	spot.Brightness = 6
	spot.Parent = lamp
	for _, info in { { x = -3, color = RED }, { x = 3, color = BLUE } } do
		local l = add({ Name = "Beacon", Size = Vector3.new(0.8, 0.8, 0.8), Color = info.color, Material = Enum.Material.Neon })
		l:SetAttribute("Offset", Vector3.new(info.x, -3.5, 5))
	end
	model.PrimaryPart = body
	body.CFrame = CFrame.new(pos + Vector3.new(200, 130, 200))
	model:SetAttribute("Owner", s.player.UserId)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = policeFolder
	helis[s.player] = model
	s.heli = model
	Session.Notify(s.player, "HELICOPTER INBOUND!", RED)
end

local rotorAngle = 0
RunService.Heartbeat:Connect(function(dt: number)
	rotorAngle += dt * 25
	for player, heli in helis do
		local s = Session.Get(player)
		local body = heli.PrimaryPart
		if not s or not body then
			continue
		end
		local target = Session.CarPosition(s)
		local cur = body.CFrame
		local goal = cur.Position
		if target then
			goal = target + Vector3.new(0, 110, 0)
		end
		local newPos = cur.Position:Lerp(goal, math.min(1, dt * 0.9))
		local flat = Vector3.new(goal.X - newPos.X, 0, goal.Z - newPos.Z)
		local cf = if flat.Magnitude > 2 then CFrame.lookAt(newPos, newPos + flat) else CFrame.new(newPos) * cur.Rotation
		body.CFrame = cf
		for _, p in heli:GetChildren() do
			if not p:IsA("BasePart") or p == body then
				continue
			end
			if p.Name == "Tail" then
				p.CFrame = cf * CFrame.new(0, 1, 12)
			elseif p.Name == "Rotor" then
				p.CFrame = cf * CFrame.new(0, 4, 0) * CFrame.Angles(0, rotorAngle, 0)
			elseif p.Name == "Lamp" then
				p.CFrame = cf * CFrame.new(0, -4, -5)
			elseif p.Name == "Beacon" then
				p.CFrame = cf * CFrame.new(p:GetAttribute("Offset") :: Vector3)
			end
		end
	end
	-- helicopters that are leaving climb away
	for _, heli in policeFolder:GetChildren() do
		if heli:IsA("Model") and heli:GetAttribute("Leaving") then
			heli:PivotTo(heli:GetPivot() + Vector3.new(0, dt * 40, dt * 60))
		end
	end
end)

---------------------------------------------------------------------------
-- Main update (10 Hz)
---------------------------------------------------------------------------
local function canSee(from: Vector3, to: Vector3, radius: number): boolean
	return (from - to).Magnitude < radius and AIDriver.ClearLine(from, to)
end

local function updatePursuit(s: Session.Session, pos: Vector3, dt: number)
	local lvl = level(s)
	local now = os.clock()
	for idx = #s.cops, 1, -1 do
		if not s.cops[idx].alive then
			table.remove(s.cops, idx)
		end
	end
	local speed = Session.CarSpeed(s)
	local detect = lvl.detectRadius * (if s.hiding then 0.4 else 1)
	local seen = false
	local nearest = math.huge
	for _, ai in s.cops do
		local cp = ai.state.root.Position
		local d = (cp - pos).Magnitude
		nearest = math.min(nearest, d)
		if not seen and canSee(cp, pos, if s.mode == "cooldown" then detect * 0.75 else detect) then
			seen = true
		end
	end
	local heli = s.heli
	if heli and heli.PrimaryPart and not s.hiding then
		local hp = heli.PrimaryPart.Position
		if Vector3.new(hp.X - pos.X, 0, hp.Z - pos.Z).Magnitude < 220 then
			seen = true
		end
	end
	if seen then
		s.lastSeen = pos
	end

	-- bust meter
	if nearest < P.BustRadius and speed < P.BustSpeed then
		s.bust = math.min(1, s.bust + dt / P.BustTime)
	else
		s.bust = math.max(0, s.bust - dt / 2)
	end
	if s.bust >= 1 then
		busted(s)
		return
	end

	local night = Session.NightMult()
	if s.mode == "pursuit" then
		s.pursuitTime += dt
		local before = Session.HeatLevel(s)
		s.heat = math.min(5, s.heat + dt * P.HeatPerMinute / 60 * night)
		if Session.HeatLevel(s) > before then
			Session.Banner(s.player, "HEAT LEVEL " .. Session.HeatLevel(s), "More cops, faster units", RED)
		end
		s.bounty += lvl.bountyPerSecond * dt * night
		if seen then
			s.evade = math.max(0, s.evade - dt * 1.5)
		else
			s.evade += dt / lvl.evadeTime
			if s.evade >= 1 then
				s.mode = "cooldown"
				s.cooldown = 0
				for _, ai in s.cops do
					ai.data.mode = "search"
					ai.data.searchGoal = s.lastSeen
				end
				Session.Notify(s.player, "Out of sight - lie low for COOLDOWN", BLUE)
			end
		end
		local isNight = Session.IsNight()
		local maxCops = lvl.maxCops + (if isNight then P.NightExtraCops else 0)
		local interval = lvl.spawnInterval * (if isNight then P.NightSpawnMult else 1)
		if #s.cops < maxCops and now - s.lastCopSpawn > interval then
			s.lastCopSpawn = now
			spawnCopFor(s)
		end
		if lvl.roadblocks and now - s.lastRoadblock > P.RoadblockInterval then
			s.lastRoadblock = now
			spawnRoadblock(s)
		end
		if lvl.heli and not s.heli then
			spawnHeli(s)
		end
	elseif s.mode == "cooldown" then
		if seen then
			s.mode = "pursuit"
			s.evade = 0
			for _, ai in s.cops do
				ai.data.mode = "chase"
			end
			Session.Notify(s.player, "SPOTTED!  Pursuit resumed", RED)
		else
			s.cooldown += dt / lvl.cooldownTime * (if s.hiding then 3 else 1)
			if s.cooldown >= 1 then
				escaped(s)
			end
		end
	end
end

local function maintainPatrols()
	for idx = #patrols, 1, -1 do
		if not patrols[idx].alive then
			table.remove(patrols, idx)
		end
	end
	-- more patrols roam the city at night
	local want = P.PatrolCount + math.floor(#Players:GetPlayers() / 2) + (if Session.IsNight() then P.NightExtraPatrols else 0)
	if #patrols > want then
		-- daybreak: send surplus patrols home once nobody can see them
		for idx = #patrols, 1, -1 do
			local ai = patrols[idx]
			local pos = ai.state.root.Position
			local seen = false
			for _, s in Session.All() do
				local cp = Session.CarPosition(s)
				if cp and (cp - pos).Magnitude < 350 then
					seen = true
					break
				end
			end
			if not seen then
				table.remove(patrols, idx)
				AIDriver.Remove(ai)
				ai.model:Destroy()
				return
			end
		end
		return
	end
	if #patrols == want then
		return
	end
	-- spawn away from every player
	for _ = 1, 10 do
		local i, j = math.random(0, Grid.Size), math.random(0, Grid.Size)
		local p = Grid.Intersection(i, j)
		local ok = true
		for _, s in Session.All() do
			local cp = Session.CarPosition(s)
			if cp and (cp - p).Magnitude < 300 then
				ok = false
				break
			end
		end
		if ok then
			local look = Grid.Intersection(math.clamp(i + 1, 0, Grid.Size), j) - p
			table.insert(patrols, spawnCop(p, look, false, "patrol", nil))
			return
		end
	end
end

local function checkPatrolSpotting(s: Session.Session, pos: Vector3)
	if s.race or s.atSafehouse or os.clock() < s.frozenUntil then
		return
	end
	local speed = Session.CarSpeed(s)
	local heatLvl = Session.HeatLevel(s)
	local radius = P.SpotRadius + heatLvl * 20
	for idx, ai in patrols do
		if not ai.alive then
			continue
		end
		local cp = ai.state.root.Position
		if (heatLvl >= 1 or speed > P.SpeedLimit) and canSee(cp, pos, radius) then
			local reason = if heatLvl >= 1
				then "Known street racer spotted!"
				else ("Speeding at " .. math.floor(speed * Config.MphPerStud) .. " MPH")
			startPursuit(s, reason)
			table.remove(patrols, idx)
			ai.data.mode = "chase"
			ai.data.session = s
			ai.model:SetAttribute("Siren", true)
			table.insert(s.cops, ai)
			return
		end
	end
end

local function checkBreakers(s: Session.Session, pos: Vector3)
	if s.mode == "idle" then
		return
	end
	for _, b in mapInfo.breakers do
		if b.armed and (Vector3.new(pos.X, b.position.Y, pos.Z) - b.position).Magnitude < 30 and Session.CarSpeed(s) > 45 then
			MapBuilder.CollapseBreaker(b, pos)
			local taken = 0
			for _, ai in table.clone(AIDriver.All()) do
				if ai.kind == "cop" and (ai.state.root.Position - b.position).Magnitude < 110 then
					wreck(ai, nil)
					taken += 1
				end
			end
			s.bounty += Config.Bounty.PursuitBreaker * Session.NightMult()
			s.copsWrecked += taken
			s.bounty += taken * Config.Bounty.CopWrecked
			Session.Banner(s.player, "PURSUIT BREAKER", taken .. " cops taken out", Color3.fromRGB(255, 160, 60))
			Session.AddStat(s, "breakersUsed", 1)
			Session.AddStat(s, "copsWrecked", taken)
			task.delay(90, function()
				MapBuilder.ResetBreaker(b)
			end)
		end
	end
end

function Police.Init(info: MapBuilder.MapInfo)
	mapInfo = info
	AIDriver.SetBuildings(info.buildings)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, s in Session.All() do
				local pos = Session.CarPosition(s)
				if not pos then
					continue
				end
				s.hiding = inHiding(pos)
				local ok, err = pcall(function()
					if s.mode == "idle" then
						checkPatrolSpotting(s, pos)
					else
						updatePursuit(s, pos, dt)
						checkBreakers(s, pos)
					end
				end)
				if not ok then
					warn("[Police] update error:", err)
				end
			end
			maintainPatrols()
		end
	end)
end

function Police.SetBustedCallback(fn: (s: Session.Session) -> ())
	onBusted = fn
end

function Police.Cleanup(s: Session.Session)
	endPursuit(s)
end

return Police
