--[[
	ScooterServer
	Owns the authoritative boost meter for every player and periodically
	sanity-checks movement speed. The client predicts boost/drift locally for
	feel, but this state is what actually gates whether a boost is granted.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScooterData = require(ReplicatedStorage.Shared.ScooterData)
local AntiExploit = require(script.Parent.AntiExploit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Boost = Remotes:WaitForChild("Boost")
local ScooterAction = Remotes:WaitForChild("ScooterAction")
local BoostStateChanged = Remotes:WaitForChild("BoostStateChanged")

local Physics = ScooterData.Physics

-- [player] = { Meter = 0-100, Active = bool, CooldownUntil = clock, LastRegenTime = clock }
local boostState = {}

local function getState(player)
	local s = boostState[player]
	if not s then
		s = { Meter = 100, Active = false, CooldownUntil = 0, LastRegenTime = os.clock() }
		boostState[player] = s
	end
	return s
end

Players.PlayerAdded:Connect(function(player)
	boostState[player] = { Meter = 100, Active = false, CooldownUntil = 0, LastRegenTime = os.clock() }
end)

Players.PlayerRemoving:Connect(function(player)
	boostState[player] = nil
end)

Boost.OnServerEvent:Connect(function(player, wantsActive)
	local state = getState(player)
	local now = os.clock()

	if wantsActive then
		if state.Active then
			return
		end
		if state.Meter < 15 or now < state.CooldownUntil then
			BoostStateChanged:FireClient(player, state.Meter, false)
			return
		end
		state.Active = true
	else
		state.Active = false
		state.CooldownUntil = now + 0.15
	end

	BoostStateChanged:FireClient(player, state.Meter, state.Active)
end)

ScooterAction.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	-- Jump/drift are physics-only (client authoritative for feel); this hook
	-- exists so server-side effects (e.g. drift boost reward) can react.
	if payload.Type == "DriftReward" then
		local amount = tonumber(payload.Amount) or 0
		amount = math.clamp(amount, 0, 15)
		local state = getState(player)
		state.Meter = math.clamp(state.Meter + amount, 0, 100)
		BoostStateChanged:FireClient(player, state.Meter, state.Active)
	end
end)

-- Boost meter drain/regen tick.
RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for player, state in pairs(boostState) do
		if state.Active then
			state.Meter = math.max(0, state.Meter - Physics.BoostDrainPerSecond * dt)
			state.LastRegenTime = now
			if state.Meter <= 0 then
				state.Active = false
				state.CooldownUntil = now + Physics.BoostCooldown
				BoostStateChanged:FireClient(player, state.Meter, false)
			end
		elseif now - state.LastRegenTime > Physics.BoostRegenDelay and state.Meter < 100 then
			state.Meter = math.min(100, state.Meter + Physics.BoostRegenPerSecond * dt)
		end
	end
end)

-- Throttled movement sanity check (every ~0.5s per player).
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				AntiExploit.CheckMovement(player, root.Position)
			end
		end
	end
end)
