--[[
	CameraController
	Angled top-down tower defence camera (brief section 28).

	There is no player character in MIND TD, so the camera isn't following
	anything — it owns a focus point on the ground plane which the player pans
	and zooms. The focus point is clamped to the map bounds, and the camera
	angle is fixed, which together make it impossible to clip through the
	facility or lose the board.

	The camera type is re-asserted every frame because Roblox resets it to
	Custom on a number of events; a one-time assignment silently stops working.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PAN_SPEED = 90
local EDGE_PAN_MARGIN = 12
local PITCH = math.rad(58) -- fixed angle: consistent readability of the board

local MIN_ZOOM, MAX_ZOOM = 60, 260
local BOUNDS = {
	MinX = -130,
	MaxX = 130,
	MinZ = -200,
	MaxZ = 150,
}

local focus = Vector3.new(0, 0, -20)
local zoom = 170
local targetZoom = zoom
local yaw = 0

local function getCamera(): Camera?
	return Workspace.CurrentCamera
end

local camera = getCamera()
if camera then
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 55
end

--============================================================
-- Input
--============================================================

local keysDown: { [Enum.KeyCode]: boolean } = {}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keysDown[input.KeyCode] = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		keysDown[input.KeyCode] = nil
	end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		targetZoom = math.clamp(targetZoom - input.Position.Z * 18, MIN_ZOOM, MAX_ZOOM)
	end
end)

-- Pinch-to-zoom on touch devices.
UserInputService.TouchPinch:Connect(function(_touchPositions, scale, _velocity, touchState)
	if touchState == Enum.UserInputState.Change then
		targetZoom = math.clamp(targetZoom / math.max(scale, 0.1), MIN_ZOOM, MAX_ZOOM)
	end
end)

-- Right-drag to pan with the mouse; one-finger drag on touch.
local dragging = false
local lastDragPosition: Vector3?

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		lastDragPosition = input.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		lastDragPosition = nil
	end
end)

UserInputService.InputChanged:Connect(function(input, _processed)
	if not dragging or not lastDragPosition then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - lastDragPosition
		lastDragPosition = input.Position
		-- Scale the drag by zoom so panning feels the same at every distance.
		local scale = zoom / 3000
		focus += Vector3.new(-delta.X * scale * 3, 0, -delta.Y * scale * 3)
	end
end)

--============================================================
-- Update
--============================================================

local function panFromKeyboard(dt: number)
	local move = Vector3.zero
	if keysDown[Enum.KeyCode.W] or keysDown[Enum.KeyCode.Up] then
		move += Vector3.new(0, 0, -1)
	end
	if keysDown[Enum.KeyCode.S] or keysDown[Enum.KeyCode.Down] then
		move += Vector3.new(0, 0, 1)
	end
	if keysDown[Enum.KeyCode.A] or keysDown[Enum.KeyCode.Left] then
		move += Vector3.new(-1, 0, 0)
	end
	if keysDown[Enum.KeyCode.D] or keysDown[Enum.KeyCode.Right] then
		move += Vector3.new(1, 0, 0)
	end

	if move.Magnitude > 0 then
		-- Pan faster when zoomed out, so crossing the map takes a similar
		-- amount of time at any zoom level.
		focus += move.Unit * PAN_SPEED * dt * (zoom / 140)
	end
end

local function panFromScreenEdge(dt: number)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return -- edge panning makes no sense on touch
	end
	local currentCamera = getCamera()
	if not currentCamera then
		return
	end

	local mouse = UserInputService:GetMouseLocation()
	local viewport = currentCamera.ViewportSize
	local move = Vector3.zero

	if mouse.X <= EDGE_PAN_MARGIN then
		move += Vector3.new(-1, 0, 0)
	elseif mouse.X >= viewport.X - EDGE_PAN_MARGIN then
		move += Vector3.new(1, 0, 0)
	end
	if mouse.Y <= EDGE_PAN_MARGIN then
		move += Vector3.new(0, 0, -1)
	elseif mouse.Y >= viewport.Y - EDGE_PAN_MARGIN then
		move += Vector3.new(0, 0, 1)
	end

	if move.Magnitude > 0 then
		focus += move.Unit * PAN_SPEED * dt * (zoom / 140)
	end
end

RunService.RenderStepped:Connect(function(dt)
	local currentCamera = getCamera()
	if not currentCamera then
		return
	end
	if currentCamera.CameraType ~= Enum.CameraType.Scriptable then
		currentCamera.CameraType = Enum.CameraType.Scriptable
	end

	panFromKeyboard(dt)
	panFromScreenEdge(dt)

	-- Hard clamp: the board always stays on screen.
	focus = Vector3.new(
		math.clamp(focus.X, BOUNDS.MinX, BOUNDS.MaxX),
		0,
		math.clamp(focus.Z, BOUNDS.MinZ, BOUNDS.MaxZ)
	)

	zoom += (targetZoom - zoom) * math.clamp(dt * 8, 0, 1)

	local offset = Vector3.new(
		math.sin(yaw) * math.cos(PITCH) * zoom,
		math.sin(PITCH) * zoom,
		math.cos(yaw) * math.cos(PITCH) * zoom
	)

	currentCamera.CFrame = CFrame.lookAt(focus + offset, focus)
end)

-- No API is exported: this is a LocalScript, so nothing can require it.
-- PlacementController converts clicks to world positions through
-- Workspace.CurrentCamera directly, which works no matter who drives it.
