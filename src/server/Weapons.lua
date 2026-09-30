--!strict
-- Roof-mounted car weapons, bought at the Black Market. They only affect police and rival AI
-- cars (never other players). Using them on cops starts a pursuit and raises your heat.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local AIDriver = require(script.Parent.AIDriver)
local Police = require(script.Parent.Police)
local Session = require(script.Parent.Session)

local Weapons = {}

local fx = Instance.new("Folder")
fx.Name = "WeaponFX"
fx.Parent = workspace

local function effectPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = fx
	return p
end

local function aiFromPart(part: BasePart): AIDriver.AI?
	for _, ai in AIDriver.All() do
		if ai.alive and (ai.kind == "cop" or ai.kind == "rival") and part:IsDescendantOf(ai.model) then
			return ai
		end
	end
	return nil
end

local function targetsNear(pos: Vector3, radius: number): { AIDriver.AI }
	local out = {}
	for _, ai in AIDriver.All() do
		if ai.alive and (ai.kind == "cop" or ai.kind == "rival") and (ai.state.root.Position - pos).Magnitude < radius then
			table.insert(out, ai)
		end
	end
	return out
end

local function stun(ai: AIDriver.AI, seconds: number)
	ai.data.stunnedUntil = os.clock() + seconds
end

local function hit(ai: AIDriver.AI, damage: number, by: Session.Session)
	if Police.IsCop(ai) then
		Police.DamageCop(ai, damage, by)
	else
		stun(ai, 1.2)
	end
end

local function boom(pos: Vector3)
	local e = Instance.new("Explosion")
	e.BlastPressure = 0
	e.BlastRadius = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Position = pos
	e.Parent = workspace
end

local function muzzle(car: Model): Vector3
	local root = car.PrimaryPart :: BasePart
	local att = root:FindFirstChild("WeaponMuzzle", true)
	if att and att:IsA("Attachment") then
		return att.WorldPosition
	end
	return root.Position + Vector3.new(0, 5, 0)
end

---------------------------------------------------------------------------
-- The weapons
---------------------------------------------------------------------------
local function pulse(s: Session.Session, car: Model, w: Config.WeaponDef)
	local root = car.PrimaryPart :: BasePart
	local from = muzzle(car)
	local look = root.CFrame.LookVector
	-- lock on to the closest target in a cone ahead
	local best: AIDriver.AI? = nil
	local bestD = 320
	for _, ai in targetsNear(root.Position, 320) do
		local to = ai.state.root.Position - root.Position
		local d = to.Magnitude
		if d > 1 and to.Unit:Dot(look) > 0.93 and d < bestD then
			best, bestD = ai, d
		end
	end
	local target = if best then best.state.root.Position else from + look * 260
	local dist = (target - from).Magnitude
	local bolt = effectPart({ Name = "PulseBolt", Size = Vector3.new(0.8, 0.8, 8), Color = w.color, CFrame = CFrame.lookAt(from, target) })
	local light = Instance.new("PointLight")
	light.Color = w.color
	light.Range = 18
	light.Brightness = 4
	light.Parent = bolt
	local travel = math.clamp(dist / 450, 0.05, 0.5)
	TweenService:Create(bolt, TweenInfo.new(travel, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + (target - from).Unit) }):Play()
	Debris:AddItem(bolt, travel + 0.05)
	local victim = best
	task.delay(travel, function()
		if victim and victim.alive then
			boom(victim.state.root.Position)
			victim.state.root.AssemblyLinearVelocity += (target - from).Unit * 40 + Vector3.new(0, 20, 0)
			hit(victim, 55, s)
		end
	end)
end

local function emp(s: Session.Session, car: Model, w: Config.WeaponDef)
	local pos = (car.PrimaryPart :: BasePart).Position
	local sphere = effectPart({ Name = "EMP", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Color = w.color, Transparency = 0.3, Material = Enum.Material.ForceField, CFrame = CFrame.new(pos) })
	TweenService:Create(sphere, TweenInfo.new(0.6), { Size = Vector3.new(180, 180, 180), Transparency = 1 }):Play()
	Debris:AddItem(sphere, 0.7)
	for _, ai in targetsNear(pos, 90) do
		stun(ai, 5)
		if Police.IsCop(ai) then
			ai.model:SetAttribute("Siren", false)
			task.delay(5, function()
				if ai.alive and ai.data.mode ~= "patrol" then
					ai.model:SetAttribute("Siren", true)
				end
			end)
			Police.DamageCop(ai, 10, s)
		end
	end
end

local function dropBehind(car: Model, dist: number): (Vector3, Vector3)
	local root = car.PrimaryPart :: BasePart
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z).Unit
	local p = root.Position - flat * dist
	return Vector3.new(p.X, Grid.RoadY, p.Z), flat
end

local function oil(s: Session.Session, car: Model, w: Config.WeaponDef)
	local pos, flat = dropBehind(car, 14)
	local slick = effectPart({ Name = "OilSlick", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 22, 22), Color = w.color, Material = Enum.Material.Glass, Reflectance = 0.5, Transparency = 0.1, CanTouch = true, CFrame = CFrame.new(pos + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	local done: { [AIDriver.AI]: boolean } = {}
	slick.Touched:Connect(function(part)
		local ai = aiFromPart(part)
		if ai and not done[ai] then
			done[ai] = true
			stun(ai, 1.8)
			local r = ai.state.root
			r.AssemblyAngularVelocity = Vector3.new(0, (if math.random() < 0.5 then -1 else 1) * 9, 0)
			r.AssemblyLinearVelocity *= 0.6
			if Police.IsCop(ai) then
				Police.DamageCop(ai, 20, s)
			end
		end
	end)
	local _ = flat
	Debris:AddItem(slick, 15)
end

local function spikes(s: Session.Session, car: Model, w: Config.WeaponDef)
	local pos, flat = dropBehind(car, 12)
	local across = flat:Cross(Vector3.yAxis)
	local strip = effectPart({ Name = "SpikeDrop", Size = Vector3.new(26, 0.35, 2.2), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.DiamondPlate, CanTouch = true, CFrame = CFrame.fromMatrix(pos + Vector3.new(0, 0.18, 0), across, Vector3.yAxis) })
	for k = -8, 8 do
		local spike = effectPart({ Name = "Spike", Size = Vector3.new(0.3, 0.7, 0.3), Color = w.color, Material = Enum.Material.Metal, CFrame = strip.CFrame * CFrame.new(k * 1.5, 0.5, 0) })
		spike.Parent = strip
	end
	local done: { [AIDriver.AI]: boolean } = {}
	strip.Touched:Connect(function(part)
		local ai = aiFromPart(part)
		if ai and not done[ai] then
			done[ai] = true
			stun(ai, 2.5)
			hit(ai, 120, s)
		end
	end)
	Debris:AddItem(strip, 20)
end

local function shock(s: Session.Session, car: Model, w: Config.WeaponDef)
	local pos = (car.PrimaryPart :: BasePart).Position
	local ring = effectPart({ Name = "Shockwave", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 6, 6), Color = w.color, Transparency = 0.2, CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(ring, TweenInfo.new(0.45), { Size = Vector3.new(1, 130, 130), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)
	for _, ai in targetsNear(pos, 65) do
		local r = ai.state.root
		local away = r.Position - pos
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 1 then
			away = Vector3.xAxis
		end
		r.AssemblyLinearVelocity += away.Unit * 130 + Vector3.new(0, 35, 0)
		r.AssemblyAngularVelocity += Vector3.new(math.random(-3, 3), math.random(-6, 6), math.random(-3, 3))
		stun(ai, 1.5)
		if Police.IsCop(ai) then
			Police.DamageCop(ai, 40, s)
		end
	end
	-- traffic gets shoved too, it just isn't damaged
	local traffic = workspace:FindFirstChild("Traffic")
	if traffic then
		for _, m in traffic:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart and (m.PrimaryPart.Position - pos).Magnitude < 50 then
				local away = m.PrimaryPart.Position - pos
				m.PrimaryPart.AssemblyLinearVelocity += Vector3.new(away.X, 0, away.Z).Unit * 70 + Vector3.new(0, 20, 0)
			end
		end
	end
end

local FIRE = {
	pulse = pulse,
	emp = emp,
	oil = oil,
	spikes = spikes,
	shock = shock,
}

-- Returns true if the weapon fired.
function Weapons.Fire(s: Session.Session): boolean
	local w = Config.GetWeapon(s.profile.weapon)
	local car = s.car
	if not w or not car or not car.PrimaryPart or s.inGarage then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local ready = s.player:GetAttribute("WeaponReadyAt")
	if type(ready) == "number" and now < ready then
		return false
	end
	s.player:SetAttribute("WeaponReadyAt", now + w.cooldown)
	local fn = FIRE[w.id]
	if fn then
		fn(s, car, w)
	end
	return true
end

return Weapons
