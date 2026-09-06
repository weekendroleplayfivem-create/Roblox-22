--[[
	FPSController
	Character-level first-person setup: hides the local player's own body so
	it doesn't obstruct the camera, and boots touch controls on mobile
	(brief section 4, "For mobile"). Weapon/scooter input live in their own
	controllers; this script only owns things tied to the character instance.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Hiding the local body is owned by CameraController (it has to re-apply
-- LocalTransparencyModifier every frame, so it keeps the cached part list).

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")

	-- Roblox's default animations assume walking speeds; at scooter speeds the
	-- run cycle just looks like a blur, and the character is hidden in first
	-- person anyway, so there's nothing to tear down on death here.
	humanoid.Died:Connect(function()
		humanoid.WalkSpeed = 0
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	local success, err = pcall(function()
		require(script.Parent:WaitForChild("MobileControls"))
	end)
	if not success then
		warn("[HyperBlast] Failed to load mobile controls:", err)
	end
end
