--!nonstrict
--[[
	HyperBlastClient
	Client bootstrap. Constructs every controller, wires them into one shared
	context table, then starts them in dependency order.

	The context is a plain table rather than a service locator on purpose: a
	controller's dependencies are visible at the call site, and there is exactly
	one place (this file) that decides what exists and in what order it wakes up.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local Root = ReplicatedStorage:WaitForChild("HyperBlast")
local Net = require(Root.Util.Net)
local Palette = require(Root.Config.Palette)
local GameModeConfig = require(Root.Config.GameModeConfig)
local AbilityConfig = require(Root.Config.AbilityConfig)

local Controllers = script.Controllers
local InputController = require(Controllers.InputController)
local MovementController = require(Controllers.MovementController)
local CameraController = require(Controllers.CameraController)
local HUDController = require(Controllers.HUDController)
local EffectsController = require(Controllers.EffectsController)
local AbilityController = require(Controllers.AbilityController)
local WeaponController = require(Controllers.WeaponController)

local LocalPlayer = Players.LocalPlayer

-- Roblox's default backpack/health UI has no place in a game with its own HUD.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

----------------------------------------------------------------------
-- Post-processing. Set up client-side so it can be quality-scaled later
-- without touching replicated state.
----------------------------------------------------------------------
local function setupAtmosphere()
	if not Lighting:FindFirstChild("HB_Bloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "HB_Bloom"
		bloom.Intensity = 1.05
		bloom.Size = 26
		bloom.Threshold = 1.35 -- high threshold: only the NEON blooms, not the walls
		bloom.Parent = Lighting
	end

	if not Lighting:FindFirstChild("HB_Color") then
		local color = Instance.new("ColorCorrectionEffect")
		color.Name = "HB_Color"
		color.Saturation = 0.16
		color.Contrast = 0.14
		color.TintColor = Color3.fromRGB(238, 236, 255)
		color.Parent = Lighting
	end

	-- Deliberately NO depth of field and NO motion blur: both cost you the ability
	-- to track a moving target, and this is a game about tracking moving targets.
end

setupAtmosphere()

----------------------------------------------------------------------
-- Controllers
----------------------------------------------------------------------
local context = {}

context.Input = InputController.new()
context.Movement = MovementController.new(context)
context.Camera = CameraController.new(context)
context.HUD = HUDController.new(context)
context.Effects = EffectsController.new(context)
context.Ability = AbilityController.new(context)
context.Weapon = WeaponController.new(context)

-- Start order mirrors the dependency graph: input feeds movement, movement feeds
-- the camera and HUD, and the weapon sits on top of all of them.
context.Input:Start()
context.Movement:Start()
context.Camera:Start()
context.HUD:Start()
context.Effects:Start()
context.Ability:Start()
context.Weapon:Start()

----------------------------------------------------------------------
-- Match phase handling
----------------------------------------------------------------------
local function setPlayable(playable: boolean)
	context.Input:SetEnabled(playable)
	context.Weapon:SetEnabled(playable)
	context.Ability:SetEnabled(playable)
	context.Movement:SetFrozen(not playable)
end

Net.onClient("MatchState", function(state)
	if not state then
		return
	end

	local playable = state.phase == "Live" or state.phase == "Overtime"
	setPlayable(playable)

	if state.phase == "Warmup" then
		context.HUD:Announce("GET READY", 2.0, Palette.NeonCyan)
	elseif state.phase == "Live" and state.justStarted then
		context.HUD:Announce("GO", 1.0, Palette.NeonLime)
	elseif state.phase == "Overtime" then
		context.HUD:Announce("OVERTIME", 2.5, Palette.NeonAmber)
	elseif state.phase == "PostMatch" then
		local winner = state.winner and Palette.Teams[state.winner]
		context.HUD:Announce(
			winner and `{winner.Name} WINS` or "DRAW",
			4.0,
			winner and winner.Color or Palette.NeonPurple
		)
	end

	-- Modes can switch the ability sandbox off (Hyper Duel disables Overdrive;
	-- a Core Rush carrier loses Phase Step).
	local mode = state.mode and GameModeConfig.get(state.mode)
	if mode and mode.AbilitiesEnabled then
		for id in AbilityConfig.Abilities do
			context.Ability:SetAbilityEnabled(id, mode.AbilitiesEnabled[id] ~= false)
		end
	end
end)

Net.onClient("PlayerEliminated", function()
	setPlayable(false)
end)

----------------------------------------------------------------------
-- Respawn
----------------------------------------------------------------------
local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	context.HUD:HideDeathOverlay()
	context.Ability:ResetAll()
	setPlayable(true)

	humanoid.Died:Once(function()
		setPlayable(false)
		context.Weapon:SetEnabled(false)
	end)
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
end

-- Tell the server we're ready for a body. The server owns spawning so it can
-- place us by team, mode and phase rather than on a random SpawnLocation.
Net.toServer("RequestRespawn")

print("[HYPER BLAST] client online")
