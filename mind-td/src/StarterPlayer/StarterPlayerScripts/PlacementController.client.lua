--[[
	PlacementController
	Turns a mouse/touch position into a build pad, previews what would be
	built there, and sends the request (brief section 11).

	Everything here is presentation and intent. The preview's green/red state
	is a courtesy so the player isn't guessing — the server re-checks the pad,
	the funds and the tower type before anything is actually built, and a
	client that skipped straight to firing the remote gains nothing.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local TowerData = require(ReplicatedStorage.Shared.TowerData)
local ClientState = require(script.Parent:WaitForChild("ClientState"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaceTower = Remotes:WaitForChild("PlaceTower")

local player = Players.LocalPlayer

local VALID_COLOR = Color3.fromRGB(110, 240, 150)
local INVALID_COLOR = Color3.fromRGB(255, 90, 90)

-- Preview objects live in a client-only folder. Nothing here replicates, so
-- other players never see someone else's ghost tower.
local previewFolder = Instance.new("Folder")
previewFolder.Name = "PlacementPreview"
previewFolder.Parent = Workspace

local ghostModel: Model?
local rangeIndicator: BasePart?

--============================================================
-- Preview construction
--============================================================

local function clearPreview()
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
	if rangeIndicator then
		rangeIndicator:Destroy()
		rangeIndicator = nil
	end
end

local function buildGhost(towerId: string): Model
	local data = TowerData.Get(towerId) :: any
	local model = Instance.new("Model")
	model.Name = "Ghost"

	local function ghostPart(size: Vector3, offset: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.ForceField
		part.Transparency = 0.4
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Name = "Ghost"
		part:SetAttribute("Offset", offset)
		part.Parent = model
		return part
	end

	ghostPart(Vector3.new(5, 1.6, 5), Vector3.new(0, 1.8, 0), data.Color)
	ghostPart(Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 3.7, 0), data.Color)
	ghostPart(Vector3.new(3, 1.8, 3), Vector3.new(0, 5.5, 0), data.AccentColor)

	model.Parent = previewFolder
	return model
end

local function buildRangeIndicator(range: number, color: Color3): BasePart
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.3, range * 2, range * 2)
	disc.Color = color
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.82
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CastShadow = false
	disc.Name = "RangeIndicator"
	disc.Parent = previewFolder
	return disc
end

local function tintPreview(color: Color3)
	if ghostModel then
		for _, part in ipairs(ghostModel:GetChildren()) do
			if part:IsA("BasePart") then
				part.Color = color
			end
		end
	end
	if rangeIndicator then
		rangeIndicator.Color = color
	end
end

local function positionPreview(spot: BasePart)
	local base = spot.Position
	if ghostModel then
		for _, part in ipairs(ghostModel:GetChildren()) do
			if part:IsA("BasePart") then
				local offset = part:GetAttribute("Offset")
				if typeof(offset) == "Vector3" then
					part.CFrame = CFrame.new(base + offset)
				end
			end
		end
	end
	if rangeIndicator then
		-- Cylinders are built along their X axis, so lay it flat on the ground.
		rangeIndicator.CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
end

--============================================================
-- Hit testing
--============================================================

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = { previewFolder }

-- Finds the build pad under a screen position, if any.
local function spotUnderPointer(screenPosition: Vector2): BasePart?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 2000, raycastParams)
	if not result then
		return nil
	end

	local hit = result.Instance
	if CollectionService:HasTag(hit, "TowerSpot") then
		return hit
	end
	-- The neon trim sits on top of each pad; treat a trim hit as a pad hit so
	-- the player doesn't have to aim at the exact centre.
	local map = Workspace:FindFirstChild("MIND_TD_Map")
	local spots = map and map:FindFirstChild("TowerSpots")
	if spots and hit:IsDescendantOf(spots) then
		local padName = hit.Name:gsub("_Trim$", "")
		local pad = spots:FindFirstChild(padName)
		if pad and CollectionService:HasTag(pad, "TowerSpot") then
			return pad :: BasePart
		end
	end

	return nil
end

local function pointerPosition(): Vector2
	local location = UserInputService:GetMouseLocation()
	return Vector2.new(location.X, location.Y)
end

--============================================================
-- Update loop
--============================================================

local function refreshPreviewForSelection()
	clearPreview()
	local towerId = ClientState.Selection.ShopTowerId
	if not towerId then
		return
	end
	local data = TowerData.Get(towerId)
	if not data then
		return
	end
	ghostModel = buildGhost(towerId)
	rangeIndicator = buildRangeIndicator(data.Levels[1].Range, VALID_COLOR)
end

ClientState.Signals.SelectionChanged.Event:Connect(refreshPreviewForSelection)

RunService.RenderStepped:Connect(function()
	local towerId = ClientState.Selection.ShopTowerId
	if not towerId or not ghostModel then
		return
	end

	local spot = spotUnderPointer(pointerPosition())

	if not spot then
		-- Park the preview out of sight rather than destroying and rebuilding
		-- it every frame the pointer is off a pad.
		for _, part in ipairs(ghostModel:GetChildren()) do
			if part:IsA("BasePart") then
				part.CFrame = CFrame.new(0, -500, 0)
			end
		end
		if rangeIndicator then
			rangeIndicator.CFrame = CFrame.new(0, -500, 0)
		end
		return
	end

	positionPreview(spot)

	local occupied = spot:GetAttribute("Occupied") == true
	local data = TowerData.Get(towerId) :: any
	local affordable = ClientState.Money >= data.Levels[1].Cost
	tintPreview(if occupied or not affordable then INVALID_COLOR else VALID_COLOR)
end)

--============================================================
-- Clicking
--============================================================

local function handleClick(screenPosition: Vector2)
	local spot = spotUnderPointer(screenPosition)
	if not spot then
		-- Clicking empty ground clears whatever was selected.
		ClientState.ClearSelection()
		return
	end

	local spotId = spot:GetAttribute("SpotId")
	if typeof(spotId) ~= "number" then
		return
	end

	local shopTowerId = ClientState.Selection.ShopTowerId
	if shopTowerId then
		if spot:GetAttribute("Occupied") == true then
			return
		end
		PlaceTower:FireServer(shopTowerId, spotId)
		-- Selection is kept so the player can place several in a row; the
		-- server rejects the ones they can't afford.
		return
	end

	-- No shop selection: clicking an occupied pad selects that tower so the
	-- upgrade/sell panel can act on it.
	local tower = ClientState.Towers[spotId]
	if tower then
		ClientState.SelectPlacedTower(tower.TowerRuntimeId)
	else
		ClientState.ClearSelection()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return -- the click landed on the HUD, not the world
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handleClick(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.UserInputType == Enum.UserInputType.Touch then
		handleClick(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.KeyCode == Enum.KeyCode.Escape then
		ClientState.ClearSelection()
	end
end)

-- Clean up the preview if the player is removed mid-placement.
Players.PlayerRemoving:Connect(function(leaving)
	if leaving == player then
		clearPreview()
	end
end)
