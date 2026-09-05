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

local function hideOwnBody(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		end
	end)
end

local function onCharacterAdded(character)
	hideOwnBody(character)

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		-- WeaponController/ScooterController simply stop finding a live
		-- character/scooter on their next frame; nothing else to tear down.
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
