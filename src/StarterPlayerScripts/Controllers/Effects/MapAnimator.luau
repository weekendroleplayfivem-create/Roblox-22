--[[
	MapAnimator
	Animates decorative map parts on the client (zero network cost):
	  VR_Spin    attributes SpinAxis (world Vector3), SpinSpeed (degrees/second)
	  VR_Bob     attributes BobHeight (studs), BobSpeed (cycles/second)
	  VR_Pulse   attributes PulseSpeed, PulseMin, PulseMax (Transparency range)
	  VR_Flicker hologram flicker (Transparency)
	Only decorative, non-collidable parts are tagged by the server
	(MapBuilder), so moving them locally never affects gameplay.
	Updates run at a capped rate and batch CFrames with BulkMoveTo.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RaycastUtil = require(ReplicatedStorage:WaitForChild("Shared").Modules.RaycastUtil)
local FXUtil = require(script.Parent.FXUtil)

local MapAnimator = {}

local UPDATE_RATE = 1 / 30

type Entry = { Part: BasePart, Base: CFrame, Phase: number }

local movers: { [BasePart]: Entry } = {}
local pulsers: { [BasePart]: Entry } = {}
local flickers: { [BasePart]: Entry } = {}

local function register(list, instance: Instance)
	if instance:IsA("BasePart") and not instance.CanCollide then
		list[instance] = { Part = instance, Base = instance.CFrame, Phase = math.random() * math.pi * 2 }
	end
end

local function unregister(list, instance: Instance)
	list[instance :: any] = nil
end

local function watch(tag: string, list)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		register(list, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		unregister(list, instance)
	end)
	for _, instance in CollectionService:GetTagged(tag) do
		register(list, instance)
	end
end

local elapsed = 0
local function step(deltaTime: number)
	elapsed += deltaTime
	if elapsed < UPDATE_RATE then
		return
	end
	elapsed = 0
	local now = os.clock()
	local parts, cframes = {}, {}
	for part, entry in movers do
		if not part.Parent then
			movers[part] = nil
			continue
		end
		local cframe = entry.Base
		local speed = part:GetAttribute("SpinSpeed")
		if speed then
			-- World-space axis through the part's own centre.
			local axis = part:GetAttribute("SpinAxis") or Vector3.yAxis
			cframe = CFrame.new(cframe.Position) * CFrame.fromAxisAngle(axis.Unit, math.rad(speed) * now + entry.Phase) * cframe.Rotation
		end
		local height = part:GetAttribute("BobHeight")
		if height then
			local bobSpeed = part:GetAttribute("BobSpeed") or 0.3
			cframe = CFrame.new(0, math.sin(now * bobSpeed * math.pi * 2 + entry.Phase) * height, 0) * cframe
		end
		table.insert(parts, part)
		table.insert(cframes, cframe)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	local reduced = FXUtil.Reduced()
	for part, entry in pulsers do
		if not part.Parent then
			pulsers[part] = nil
			continue
		end
		local speed = part:GetAttribute("PulseSpeed") or 1
		local low = part:GetAttribute("PulseMin") or 0
		local high = part:GetAttribute("PulseMax") or 0.6
		local wave = (math.sin(now * speed * math.pi * 2 + entry.Phase) + 1) / 2
		part.Transparency = low + (high - low) * wave
	end
	if not reduced then
		for part in flickers do
			if not part.Parent then
				flickers[part] = nil
				continue
			end
			part.Transparency = if math.random() < 0.06 then 0.7 else 0.15
		end
	end
end

function MapAnimator:Init() end

function MapAnimator:Start()
	watch(RaycastUtil.Tags.Spin, movers)
	watch(RaycastUtil.Tags.Bob, movers)
	watch(RaycastUtil.Tags.Pulse, pulsers)
	watch(RaycastUtil.Tags.Flicker, flickers)
	RunService.Heartbeat:Connect(step)
end

return MapAnimator
