--!strict
-- Garage cutscenes: the roll-up door opens and your car drives in (or out) while the camera
-- watches from the side, with letterbox bars and a fade.
-- Everything here is local: a copy of your car is animated, the real car is only hidden, so the
-- physics and network ownership of the real car are never touched.

local Players = game:GetService("Players")

local Drive = require(script.Parent.DriveController)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Parent.Theme)
local HUD = require(script.Parent.HUD)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GarageCinematic = {}
GarageCinematic.Busy = false

---------------------------------------------------------------------------
-- Letterbox + fade
---------------------------------------------------------------------------
local gui = Theme.new("ScreenGui", { Name = "WantedUnboundCinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 30 }, player:WaitForChild("PlayerGui"))
local barTop = Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, gui)
local barBottom = Theme.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, gui)
local fade = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5 }, gui)
local caption = Theme.Label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(500, 28), Text = "", FontFace = Theme.Fonts.Display, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 3 }, gui)
Theme.new("UIGradient", { Color = ColorSequence.new(Theme.Colors.Cyan, Theme.Colors.Pink) }, caption)

local function letterbox(on: boolean, text: string?)
	local h = if on then UDim2.new(1, 0, 0.11, 0) else UDim2.new(1, 0, 0, 0)
	Theme.Tween(barTop, 0.5, { Size = h }, Enum.EasingStyle.Quint)
	Theme.Tween(barBottom, 0.5, { Size = h }, Enum.EasingStyle.Quint)
	caption.Text = text or ""
	Theme.Tween(caption, 0.6, { TextTransparency = if on and text then 0 else 1 })
end

---------------------------------------------------------------------------
-- Hiding the real car (and the driver) locally
---------------------------------------------------------------------------
type Hidden = { parts: { BasePart }, decals: { Decal }, toggles: { [Instance]: boolean } }

local function hide(models: { Instance? }): Hidden
	local h: Hidden = { parts = {}, decals = {}, toggles = {} }
	for _, m in models do
		if not m then
			continue
		end
		for _, d in (m :: Instance):GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
				table.insert(h.parts, d)
			elseif d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
				table.insert(h.decals, d)
			elseif d:IsA("LayerCollector") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
				h.toggles[d] = (d :: any).Enabled
				;(d :: any).Enabled = false
			end
		end
	end
	return h
end

local function unhide(h: Hidden)
	for _, p in h.parts do
		p.LocalTransparencyModifier = 0
	end
	for _, d in h.decals do
		d.LocalTransparencyModifier = 0
	end
	for inst, was in h.toggles do
		if inst.Parent then
			(inst :: any).Enabled = was
		end
	end
end

---------------------------------------------------------------------------
-- Cutscene copy of a car: anchored parts moved with BulkMoveTo, wheels spin
---------------------------------------------------------------------------
type Actor = {
	model: Model,
	parts: { BasePart },
	rel: { CFrame }, -- relative to the pivot (body parts) or to the wheel hub (wheel parts)
	hubOf: { number }, -- 0 = body, otherwise index into hubs
	hubs: { CFrame }, -- hub CFrame relative to the pivot
	radius: number,
	spin: number,
}

local function makeActor(car: Model): Actor?
	local root = car.PrimaryPart
	if not root then
		return nil
	end
	local ok, copy = pcall(function()
		return car:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local model = copy :: Model
	model.Name = "CutsceneCar"
	model:SetAttribute("Owner", nil)
	local pivot = root.CFrame
	local actor: Actor = { model = model, parts = {}, rel = {}, hubOf = {}, hubs = {}, radius = 1, spin = 0 }
	local hubIndex: { [BasePart]: number } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "WheelHub" then
			table.insert(actor.hubs, pivot:ToObjectSpace(d.CFrame))
			hubIndex[d] = #actor.hubs
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("VehicleSeat") or d:IsA("Constraint") or d:IsA("VectorForce") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("WeldConstraint") or d:IsA("Weld") then
			-- work out which parts belong to a wheel before the joints go
			local w = d :: any
			local p0, p1 = w.Part0, w.Part1
			if p0 and hubIndex[p0] and p1 and not hubIndex[p1] then
				p1:SetAttribute("CutsceneHub", hubIndex[p0])
			end
		elseif d:IsA("SpotLight") then
			d.Enabled = true -- headlights on for the show
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
			local hub = d:GetAttribute("CutsceneHub")
			table.insert(actor.parts, d)
			if type(hub) == "number" then
				table.insert(actor.hubOf, hub)
				table.insert(actor.rel, (pivot * actor.hubs[hub]):ToObjectSpace(d.CFrame))
			else
				table.insert(actor.hubOf, 0)
				table.insert(actor.rel, pivot:ToObjectSpace(d.CFrame))
			end
		end
	end
	local tire = model:FindFirstChild("Tire", true)
	if tire and tire:IsA("BasePart") then
		actor.radius = tire.Size.Y / 2
	end
	model.Parent = workspace
	return actor
end

local function placeActor(a: Actor, pivot: CFrame, distance: number)
	a.spin -= distance / a.radius
	local hubCFs: { CFrame } = {}
	for k, rel in a.hubs do
		hubCFs[k] = pivot * rel * CFrame.Angles(a.spin, 0, 0)
	end
	local cfs = table.create(#a.parts)
	for i, rel in a.rel do
		local hub = a.hubOf[i]
		cfs[i] = if hub > 0 then hubCFs[hub] * rel else pivot * rel
	end
	workspace:BulkMoveTo(a.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

---------------------------------------------------------------------------
-- Roll-up doors: the panel shrinks upwards and the slats roll away under the lintel
---------------------------------------------------------------------------
type Door = {
	panel: BasePart,
	others: { BasePart },
	panelSize: Vector3,
	panelCF: CFrame,
	otherCF: { CFrame },
	otherT: { number },
	height: number,
	top: number, -- world Y of the top edge
}

local function makeDoor(panel: BasePart, others: { BasePart }): Door
	local d: Door = {
		panel = panel,
		others = others,
		panelSize = panel.Size,
		panelCF = panel.CFrame,
		otherCF = {},
		otherT = {},
		height = panel.Size.Y,
		top = panel.Position.Y + panel.Size.Y / 2,
	}
	for i, p in others do
		d.otherCF[i] = p.CFrame
		d.otherT[i] = p.Transparency
	end
	return d
end

local function setDoor(d: Door, open: number)
	local k = math.clamp(open, 0, 1)
	local h = math.max(d.height * (1 - k), 0.05)
	d.panel.Size = Vector3.new(d.panelSize.X, h, d.panelSize.Z)
	d.panel.CFrame = d.panelCF + Vector3.new(0, (d.height - h) / 2, 0)
	d.panel.Transparency = if k >= 0.995 then 1 else 0
	local lift = d.height * k
	for i, p in d.others do
		local cf = d.otherCF[i] + Vector3.new(0, lift, 0)
		p.CFrame = cf
		p.Transparency = if cf.Position.Y > d.top - 0.2 then 1 else d.otherT[i]
	end
end

local function resetDoor(d: Door)
	d.panel.Size = d.panelSize
	d.panel.CFrame = d.panelCF
	d.panel.Transparency = 0
	for i, p in d.others do
		p.CFrame = d.otherCF[i]
		p.Transparency = d.otherT[i]
	end
end

local function findOutsideDoor(timeout: number): Door?
	local map = workspace:FindFirstChild("Map")
	local deadline = os.clock() + timeout
	while true do
		local model = map and map:FindFirstChild("SafehouseGarageDoor", true)
		if model and model:IsA("Model") then
			local panel = model:FindFirstChild("Door")
			if panel and panel:IsA("BasePart") then
				local others = {}
				for _, c in model:GetChildren() do
					if c:IsA("BasePart") and c ~= panel then
						table.insert(others, c)
					end
				end
				return makeDoor(panel, others)
			end
		end
		if os.clock() > deadline then
			return nil
		end
		task.wait(0.1)
		map = workspace:FindFirstChild("Map")
	end
end

local function findInsideDoor(): Door?
	local map = workspace:FindFirstChild("Map")
	local interior = map and map:FindFirstChild("GarageInterior")
	if not interior then
		return nil
	end
	local panel = interior:FindFirstChild("RollUpDoor")
	if not panel or not panel:IsA("BasePart") then
		return nil
	end
	local others = {}
	for _, c in interior:GetChildren() do
		if c:IsA("BasePart") and c.Name == "DoorSlat" then
			table.insert(others, c)
		end
	end
	return makeDoor(panel, others)
end

---------------------------------------------------------------------------
-- Shot runner
---------------------------------------------------------------------------
local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: number): (Vector3, Vector3)
	local u = 1 - t
	local pos = p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t)
	local tangent = (p1 - p0) * (2 * u) + (p2 - p1) * (2 * t)
	return pos, tangent
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

type Shot = {
	duration: number,
	actor: Actor,
	path: { Vector3 }, -- p0, p1, p2 (pivot positions)
	startRot: CFrame?, -- blend from this rotation at the start
	endRot: CFrame?, -- blend to this rotation at the end
	moveStart: number, -- seconds before the car starts rolling
	camFrom: Vector3,
	camTo: Vector3,
	door: Door?,
	doorFrom: number, -- door open amount at the start / end of its move
	doorTo: number,
	doorStart: number,
	doorTime: number,
	fadeOutAt: number?, -- start fading to black at this time
}

local function runShot(shot: Shot)
	local clock = 0
	local lastPos = shot.path[1]
	local look = shot.path[1]
	local p0, p1, p2 = shot.path[1], shot.path[2], shot.path[3]
	local fading = false
	local doorSoundPlayed = false
	while clock < shot.duration do
		local dt = task.wait()
		clock += dt
		-- door
		if shot.door then
			local k = math.clamp((clock - shot.doorStart) / shot.doorTime, 0, 1)
			if k > 0 and not doorSoundPlayed then
				doorSoundPlayed = true
				Sounds.Play("rbxasset://sounds/action_footsteps_plastic.mp3", 0.6, 0.35)
				Sounds.Play("rbxasset://sounds/volume_slider.ogg", 0.5, 0.4)
			end
			setDoor(shot.door, shot.doorFrom + (shot.doorTo - shot.doorFrom) * smooth(k))
		end
		-- car
		local u = smooth((clock - shot.moveStart) / (shot.duration - shot.moveStart))
		local pos, tangent = bezier(p0, p1, p2, u)
		local flat = Vector3.new(tangent.X, 0, tangent.Z)
		local rot = if flat.Magnitude > 0.01 then CFrame.lookAt(Vector3.zero, flat.Unit) else (shot.startRot or CFrame.identity)
		if shot.startRot then
			rot = (shot.startRot :: CFrame):Lerp(rot, math.clamp(u / 0.25, 0, 1))
		end
		if shot.endRot then
			rot = rot:Lerp(shot.endRot :: CFrame, math.clamp((u - 0.7) / 0.3, 0, 1))
		end
		placeActor(shot.actor, CFrame.new(pos) * rot, (pos - lastPos).Magnitude)
		local speed = (pos - lastPos).Magnitude / math.max(dt, 1 / 240)
		Drive.CinematicRpm = math.clamp(0.25 + speed / 70, 0.25, 0.8)
		lastPos = pos
		-- camera: slow dolly, eyes on the car
		local c = smooth(clock / shot.duration)
		local camPos = shot.camFrom:Lerp(shot.camTo, c)
		look = look:Lerp(pos + Vector3.new(0, 1.5, 0), math.min(1, dt * 6))
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(camPos, look)
		camera.FieldOfView = 50
		if shot.fadeOutAt and clock >= (shot.fadeOutAt :: number) and not fading then
			fading = true
			Theme.Tween(fade, shot.duration - (shot.fadeOutAt :: number), { BackgroundTransparency = 0 })
		end
	end
end

local function begin(caption_: string)
	GarageCinematic.Busy = true
	Drive.Cinematic = true
	letterbox(true, caption_)
end

local function finish()
	Drive.Cinematic = false
	Drive.CinematicRpm = nil
	GarageCinematic.Busy = false
	letterbox(false)
	Theme.Tween(fade, 0.5, { BackgroundTransparency = 1 })
end

local function waitFor(check: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while not check() do
		if os.clock() > deadline then
			return false
		end
		task.wait(0.05)
	end
	return true
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- Drive from the safehouse lot through the roll-up door. `fire` tells the server to move the
-- car into the garage (called while the screen is black).
function GarageCinematic.Enter(fire: () -> ())
	if GarageCinematic.Busy then
		return
	end
	local car = Drive.Car
	local root = car and car.PrimaryPart
	local door = findOutsideDoor(0)
	if not car or not root or not door then
		fire()
		return
	end
	begin("SAFEHOUSE GARAGE")
	local function enterBody(): ()
		local actor = makeActor(car)
		if not actor then
			error("could not copy the car")
		end
		local character = player.Character
		local hidden = hide({ car, character })
		local y = root.Position.Y
		local dp = door.panelCF.Position
		local p0 = root.Position
		local p1 = Vector3.new(dp.X, y, dp.Z - 48)
		local p2 = Vector3.new(dp.X, y, dp.Z + 26)
		local approach = (p1 - p0).Magnitude + 74
		local duration = math.clamp(approach / 40, 3.2, 5.5)
		local side = if p0.X > dp.X then 1 else -1
		runShot({
			duration = duration,
			actor = actor,
			path = { p0, p1, p2 },
			startRot = root.CFrame.Rotation,
			moveStart = 0.2,
			camFrom = dp + Vector3.new(side * 44, 9, -46),
			camTo = dp + Vector3.new(side * 24, 6, -20),
			door = door,
			doorFrom = 0,
			doorTo = 1,
			doorStart = 0.2,
			doorTime = 1.7,
			fadeOutAt = duration - 0.55,
		})
		fade.BackgroundTransparency = 0
		fire()
		waitFor(function()
			return player:GetAttribute("InGarage") == true and Drive.Car ~= car and Drive.Car ~= nil
		end, 6)
		task.wait(0.25)
		actor.model:Destroy()
		resetDoor(door)
		unhide(hidden)
	end
	local ok, err = pcall(function()
		enterBody()
	end)
	if not ok then
		warn("[GarageCinematic] enter:", err)
		if player:GetAttribute("InGarage") ~= true then
			fire()
		end
	end
	finish()
end

-- Roll off the turntable and out of the workshop, then out of the safehouse garage onto the lot.
function GarageCinematic.Exit(fire: () -> ())
	if GarageCinematic.Busy then
		return
	end
	local car = Drive.Car
	local root = car and car.PrimaryPart
	local inside = findInsideDoor()
	if not car or not root or not inside then
		fire()
		return
	end
	begin("HIT THE STREETS")
	local function exitBody(): ()
		-- 1) inside the workshop
		local actor = makeActor(car)
		if not actor then
			error("could not copy the car")
		end
		local hidden = hide({ car, player.Character })
		local y = root.Position.Y
		local dp = inside.panelCF.Position
		local p0 = root.Position
		runShot({
			duration = 3.4,
			actor = actor,
			path = { p0, Vector3.new(dp.X - 3, y, p0.Z + 18), Vector3.new(dp.X, y, dp.Z + 14) },
			startRot = root.CFrame.Rotation,
			moveStart = 0.9,
			camFrom = p0 + Vector3.new(24, 7, 4),
			camTo = p0 + Vector3.new(16, 5, 16),
			door = inside,
			doorFrom = 0,
			doorTo = 1,
			doorStart = 0,
			doorTime = 1.4,
			fadeOutAt = 2.9,
		})
		fade.BackgroundTransparency = 0
		fire()
		actor.model:Destroy()
		resetDoor(inside)
		unhide(hidden)

		-- 2) out of the safehouse garage onto the lot
		local spawned = waitFor(function()
			local c = Drive.Car
			return player:GetAttribute("InGarage") ~= true and c ~= nil and c ~= car and c.PrimaryPart ~= nil
		end, 6)
		local newCar = Drive.Car
		local newRoot = newCar and newCar.PrimaryPart
		local outside = if spawned then findOutsideDoor(3) else nil
		if not newCar or not newRoot or not outside then
			return
		end
		task.wait(0.15)
		local actor2 = makeActor(newCar)
		if not actor2 then
			return
		end
		local hidden2 = hide({ newCar, player.Character })
		local target = newRoot.CFrame
		local y2 = target.Position.Y
		local op = outside.panelCF.Position
		local q0 = Vector3.new(op.X, y2, op.Z + 22)
		local q2 = target.Position
		local q1 = Vector3.new(op.X, y2, (op.Z + q2.Z) / 2)
		local side = if q2.X > op.X then 1 else -1
		setDoor(outside, 1)
		placeActor(actor2, CFrame.lookAt(q0, q0 - Vector3.zAxis), 0)
		Theme.Tween(fade, 0.6, { BackgroundTransparency = 1 })
		runShot({
			duration = 3.6,
			actor = actor2,
			path = { q0, q1, q2 },
			endRot = target.Rotation,
			startRot = CFrame.lookAt(Vector3.zero, -Vector3.zAxis),
			moveStart = 0.3,
			camFrom = op + Vector3.new(-side * 34, 7, -62),
			camTo = op + Vector3.new(-side * 20, 5, -48),
			door = outside,
			doorFrom = 1,
			doorTo = 0,
			doorStart = 2.1,
			doorTime = 1.4,
		})
		actor2.model:Destroy()
		resetDoor(outside)
		unhide(hidden2)
	end
	local ok, err = pcall(function()
		exitBody()
	end)
	if not ok then
		warn("[GarageCinematic] exit:", err)
		if player:GetAttribute("InGarage") == true then
			fire()
		end
	end
	finish()
	HUD.Intro()
end

return GarageCinematic
