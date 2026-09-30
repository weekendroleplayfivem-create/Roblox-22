--!strict
-- WANTED: UNBOUND - client entry point.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NotifyEvent = Remotes:WaitForChild("Notify") :: RemoteEvent
local RequestRace = Remotes:WaitForChild("RequestRace") :: RemoteEvent
local QuitRace = Remotes:WaitForChild("QuitRace") :: RemoteEvent

local Drive = require(script.Parent.DriveController)
local HUD = require(script.Parent.HUD)
local Garage = require(script.Parent.Garage)
require(script.Parent.CarVisuals)
require(script.Parent.Effects)
require(script.Parent.Sounds)
local BlackMarket = require(script.Parent.BlackMarket)
local Input = require(script.Parent.Input)
require(script.Parent.TouchControls)
require(script.Parent.Collectibles)
require(script.Parent.Weather)
require(script.Parent.Menu)

local player = Players.LocalPlayer

NotifyEvent.OnClientEvent:Connect(function(text: string, color: Color3?)
	HUD.Notify(text, color)
end)

---------------------------------------------------------------------------
-- Context prompt: race starts, garage, quitting races
---------------------------------------------------------------------------
type PromptAction = { kind: string, id: string? }
local promptAction: PromptAction? = nil

local function nearestRace(pos: Vector3): Config.RaceDef?
	for _, race in Config.Races do
		local p = race.route[1]
		local start = Grid.Intersection(p[1], p[2])
		if Vector3.new(pos.X - start.X, 0, pos.Z - start.Z).Magnitude < 40 then
			return race
		end
	end
	return nil
end

local function doPrompt()
	local action = promptAction
	if not action or Drive.Cinematic then
		return
	end
	if action.kind == "race" and action.id then
		RequestRace:FireServer(action.id)
	elseif action.kind == "garage" then
		if Garage.InGarage() then
			Garage.Exit()
		else
			Garage.Enter()
		end
	elseif action.kind == "blackmarket" then
		BlackMarket.Toggle()
	elseif action.kind == "quit" then
		QuitRace:FireServer()
	end
end

HUD.PromptButton.Activated:Connect(doPrompt)

ContextActionService:BindAction("WU_Interact", function(_, inputState, inputObject)
	-- gamepad B inside a menu closes it instead of triggering the world prompt
	if inputObject.KeyCode == Enum.KeyCode.ButtonB and GuiService.SelectedObject ~= nil then
		if BlackMarket.Open then
			BlackMarket.Toggle(false)
		elseif Garage.InGarage() then
			Garage.Exit()
		else
			return Enum.ContextActionResult.Pass
		end
		return Enum.ContextActionResult.Sink
	end
	if inputState == Enum.UserInputState.Begin then
		doPrompt()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonB)

ContextActionService:BindAction("WU_Garage", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and not Drive.Cinematic then
		if Garage.InGarage() then
			Garage.Exit()
		elseif player:GetAttribute("AtSafehouse") then
			Garage.Enter()
		else
			HUD.Notify("The garage is at the safehouse (green S on the map)", Color3.fromRGB(0, 255, 200))
		end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.G, Enum.KeyCode.DPadLeft)

local function updatePrompt(pos: Vector3?)
	promptAction = nil
	if not pos then
		HUD.SetPrompt(nil)
		return
	end
	local mode = player:GetAttribute("PursuitMode")
	if player:GetAttribute("RaceActive") then
		promptAction = { kind = "quit" }
		HUD.SetPrompt(Input.Label("interact") .. " Quit race")
		return
	end
	if mode ~= "idle" and mode ~= nil then
		HUD.SetPrompt(nil)
		return
	end
	if player:GetAttribute("AtBlackMarket") then
		promptAction = { kind = "blackmarket" }
		HUD.SetPrompt(if BlackMarket.Open then Input.Label("interact") .. " Close the Black Market" else Input.Label("interact") .. " Black Market  (roof weapons)")
		return
	end
	if player:GetAttribute("AtSafehouse") then
		promptAction = { kind = "garage" }
		HUD.SetPrompt(if Garage.InGarage() then Input.Label("interact") .. " Drive out of the garage" else Input.Label("interact") .. " Enter the garage  (cars, tuning, paint, Blacklist)")
		return
	end
	local race = nearestRace(pos)
	if race then
		promptAction = { kind = "race", id = race.id }
		local heat = math.floor((player:GetAttribute("Heat") :: number?) or 0)
		local mult = (1 + 0.25 * heat) * (if player:GetAttribute("Night") then Config.NightMultiplier else 1)
		local what = if race.kind == "drift"
			then string.format("score %s in %ds", HUD.Commas(race.driftTarget or 0), race.duration or 60)
			else string.format("win up to $%s", HUD.Commas((race.reward + race.buyIn) * mult))
		HUD.SetPrompt(string.format("%s %s  -  buy-in $%s  -  %s", Input.Label("interact"), race.name, HUD.Commas(race.buyIn), what))
		return
	end
	HUD.SetPrompt(nil)
end

---------------------------------------------------------------------------
-- Local checkpoint beacon
---------------------------------------------------------------------------
local beacon = Instance.new("Part")
beacon.Name = "CheckpointBeacon"
beacon.Anchored = true
beacon.CanCollide = false
beacon.CanQuery = false
beacon.CanTouch = false
beacon.Shape = Enum.PartType.Cylinder
beacon.Size = Vector3.new(300, 10, 10)
beacon.Material = Enum.Material.Neon
beacon.Color = Color3.fromRGB(255, 230, 40)
beacon.Transparency = 0.45
local ring = Instance.new("Part")
ring.Name = "CheckpointRing"
ring.Anchored = true
ring.CanCollide = false
ring.CanQuery = false
ring.CanTouch = false
ring.Shape = Enum.PartType.Cylinder
ring.Size = Vector3.new(0.4, 76, 76)
ring.Material = Enum.Material.Neon
ring.Color = Color3.fromRGB(255, 230, 40)
ring.Transparency = 0.6

local function updateBeacon()
	local nextCp = player:GetAttribute("RaceNext")
	local racing = player:GetAttribute("RaceActive") == true and player:GetAttribute("RaceKind") ~= "drift"
	if racing and typeof(nextCp) == "Vector3" and nextCp.Magnitude > 0 then
		beacon.CFrame = CFrame.new(nextCp + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.CFrame = CFrame.new(nextCp + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beacon.Parent = workspace.CurrentCamera
		ring.Parent = workspace.CurrentCamera
	else
		beacon.Parent = nil
		ring.Parent = nil
	end
end

---------------------------------------------------------------------------
-- Police siren lights (animated locally)
---------------------------------------------------------------------------
local sirenClock = 0
local sirenParts: { [Model]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any
local function sirensOf(m: Model): { BasePart }
	local cached = sirenParts[m]
	if cached then
		return cached
	end
	local list: { BasePart } = {}
	for _, name in { "SirenRed", "SirenBlue" } do
		local p = m:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			table.insert(list, p)
		end
	end
	sirenParts[m] = list
	return list
end

local function animateSirens(m: Model, phase: boolean, camPos: Vector3)
	local root = m.PrimaryPart
	if not root or not m:GetAttribute("Police") then
		return
	end
	local near = (root.Position - camPos).Magnitude < 250
	local on = m:GetAttribute("Siren") == true
	for _, part in sirensOf(m) do
		local lit = on and ((part.Name == "SirenRed") == phase)
		part.Transparency = if lit then 0 else 0.6
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = lit and near
		end
	end
end

local function updateSirens(dt: number)
	sirenClock += dt
	local phase = math.floor(sirenClock * 6) % 2 == 0
	local police = workspace:FindFirstChild("Police")
	if not police then
		return
	end
	local camPos = workspace.CurrentCamera.CFrame.Position
	for _, m in police:GetChildren() do
		if m:IsA("Model") then
			if m.Name == "Roadblock" then
				for _, inner in m:GetChildren() do
					if inner:IsA("Model") then
						animateSirens(inner, phase, camPos)
					end
				end
			else
				animateSirens(m, phase, camPos)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------
local promptTimer = 0
local sirenTimer = 0
RunService.RenderStepped:Connect(function(dt)
	local car = Drive.Car
	HUD.Gui.Enabled = not Drive.MenuOpen and not Drive.Cinematic
	HUD.Update(dt, Drive.Speed, Drive.Nitro, Drive.NitroCapacity, Drive.NitroOn, car)
	local st = Drive.State
	HUD.SetEngine(Drive.Gear, Drive.Rpm, st ~= nil and st.speed < -1)
	HUD.SetBurst(Drive.BurstMode)
	promptTimer += dt
	if promptTimer > 0.2 then
		promptTimer = 0
		-- your own name floating over your car only gets in the way
		local tag = car and car:FindFirstChild("Tag", true)
		if tag and tag:IsA("BillboardGui") and tag.Enabled then
			tag.Enabled = false
		end
		local pos = car and car.PrimaryPart and car.PrimaryPart.Position
		updatePrompt(pos)
		if Garage.Open and not player:GetAttribute("AtSafehouse") and not Garage.InGarage() then
			Garage.Toggle(false)
		end
		if BlackMarket.Open and not player:GetAttribute("AtBlackMarket") then
			BlackMarket.Toggle(false)
		end
	end
	sirenTimer += dt
	if sirenTimer > 1 / 12 then
		updateSirens(sirenTimer)
		sirenTimer = 0
	end
	updateBeacon()
end)

print("[" .. Config.GameName .. "] client ready")
