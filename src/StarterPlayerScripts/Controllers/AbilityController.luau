--[[
	AbilityController
	Client side of abilities. Predicts cooldowns for instant feedback and
	runs local movement (Dash) immediately; the server validates the request
	and sends authoritative cooldowns back in AbilityState.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Signal = require(Shared.Modules.Signal)
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local AbilityConfig = require(Shared.Config.AbilityConfig)

local ClientState = require(script.Parent.ClientState)
local InputController = require(script.Parent.InputController)
local SoundController = require(script.Parent.SoundController)
local MovementController = require(script.Parent.MovementController)
local CameraController = require(script.Parent.CameraController)
local EffectsController = require(script.Parent.EffectsController)

local AbilityController = {}

AbilityController.Changed = Signal.new()
AbilityController.Used = Signal.new() -- (slot, abilityId)

local player = Players.LocalPlayer

-- ReadyAt values are in server time (workspace:GetServerTimeNow()).
local slots = {
	Movement = { Id = AbilityConfig.DefaultMovement, ReadyAt = 0 },
	Tactical = { Id = AbilityConfig.DefaultTactical, ReadyAt = 0 },
}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Returns { Id, Remaining, Cooldown } for each slot (for the HUD).
function AbilityController:GetCooldowns()
	local result = {}
	for slot, data in slots do
		local config = AbilityConfig.Get(data.Id)
		result[slot] = {
			Id = data.Id,
			Config = config,
			Remaining = math.max(0, data.ReadyAt - now()),
			Cooldown = if config then config.Cooldown else 1,
		}
	end
	return result
end

local function aimTarget(range: number): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * range
	local result = workspace:Raycast(origin, direction, RaycastUtil.WorldParams())
	return if result then result.Position + result.Normal * 2 else origin + direction
end

local function canUse(slot: string): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Frozen") then
		return false
	end
	if slot == "Tactical" then
		local matchState = ClientState.Get("MatchState")
		return ClientState.IsInMatch() and matchState ~= nil and matchState.Phase == "Active"
	end
	return true
end

function AbilityController:Use(slot: string)
	local data = slots[slot]
	local config = data and AbilityConfig.Get(data.Id)
	if not config or not canUse(slot) then
		return
	end
	if now() < data.ReadyAt then
		SoundController:Play("DryFire")
		return
	end

	local camera = workspace.CurrentCamera
	local payload = { Direction = if camera then camera.CFrame.LookVector else nil }
	if config.Id == "Dash" then
		if not MovementController:Dash() then
			return
		end
	elseif config.Id == "Gravity" then
		payload.Target = aimTarget(config.Range)
	end

	data.ReadyAt = now() + config.Cooldown -- predicted; server confirms
	if config.Id ~= "Dash" then
		SoundController:Play(config.Sound)
	end
	if config.Id == "Pulse" or config.Id == "Shield" then
		CameraController:Shake(0.15)
	end
	EffectsController.Screen:Pulse(config.Color, 0.22, 0.35)
	Net.Event("Abilities", "UseAbility"):FireServer(slot, payload)
	AbilityController.Used:Fire(slot, config.Id)
	AbilityController.Changed:Fire()
end

function AbilityController:Init() end

function AbilityController:Start()
	Net.Event("Abilities", "AbilityState").OnClientEvent:Connect(function(state)
		if type(state) ~= "table" then
			return
		end
		for _, slot in { "Movement", "Tactical" } do
			if state[slot] then
				slots[slot].Id = state[slot].Id
				slots[slot].ReadyAt = state[slot].ReadyAt
			end
		end
		AbilityController.Changed:Fire()
	end)

	InputController.ActionBegan:Connect(function(action)
		if action == "MovementAbility" then
			AbilityController:Use("Movement")
		elseif action == "TacticalAbility" then
			AbilityController:Use("Tactical")
		end
	end)

	-- Show the equipped abilities from the profile before the first server state.
	ClientState.Observe("Profile", function(profile)
		if profile and profile.Equipped then
			slots.Movement.Id = profile.Equipped.Movement
			slots.Tactical.Id = profile.Equipped.Tactical
			AbilityController.Changed:Fire()
		end
	end)
end

return AbilityController
