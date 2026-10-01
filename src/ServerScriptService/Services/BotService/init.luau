--[[
	BotService
	Optional practice bots that fill matches. Bots are normal combatants:
	they use WeaponService ammo/fire-rate rules and CombatService damage, so
	they can never do anything a player can't.

	Perception is fair: bots only know about enemies they can SEE (view
	distance + field-of-view cone + line of sight), HEAR (gunshots within a
	radius), or that just DAMAGED them, plus allied scan pulses.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaycastUtil = require(Shared.Modules.RaycastUtil)
local BotConfig = require(Shared.Config.BotConfig)
local MatchConfig = require(Shared.Config.MatchConfig)

local BotBrain = require(script:WaitForChild("BotBrain"))

local BotService = {}

local Services

local brains: { [number]: any } = {}
local usedNames: { [string]: boolean } = {}

-- PLACEHOLDER animations: Roblox's default R15 walk/idle animation ids.
-- Replace with your own uploaded animations.
local ANIMATIONS = {
	Idle = "rbxassetid://507766666",
	Run = "rbxassetid://507767714",
}

local function pickName(): string
	local names = BotConfig.Names
	for _ = 1, #names do
		local name = names[math.random(1, #names)]
		if not usedNames[name] then
			usedNames[name] = true
			return name
		end
	end
	return "Bot" .. math.random(100, 999)
end

function BotService:CreateBots(count: number, difficulty: string?)
	local created = {}
	local difficultyName = if difficulty and BotConfig.Difficulties[difficulty] then difficulty else "Normal"
	local settings = BotConfig.Difficulties[difficultyName]
	for _ = 1, math.min(count, BotConfig.MaxBots) do
		local name = pickName()
		local combatant = Services.CombatantService:CreateForBot(name)
		combatant.Difficulty = difficultyName
		combatant.Level = math.random(1, 20)
		combatant.BotLoadout = {
			Primary = settings.Weapons[math.random(1, #settings.Weapons)],
			Secondary = "EnergySidearm",
		}
		combatant.BotAbilities = {
			Movement = "Dash",
			Tactical = if math.random() < 0.5 then "Shield" else "Pulse",
		}
		brains[combatant.Id] = BotBrain.new(combatant, settings, Services)
		table.insert(created, combatant)
	end
	return created
end

local function buildFallbackRig(): Model
	-- Simple block rig used if HumanoidDescription rigs are unavailable.
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Parent = model
	local legs = Instance.new("Part")
	legs.Name = "LowerTorso"
	legs.Size = Vector3.new(2, 2, 1)
	legs.Parent = model
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.6, 0)
	legs.CFrame = root.CFrame * CFrame.new(0, -2, 0)
	for _, part in { torso, head, legs } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 3
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildRig(teamColor: Color3): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(255, 220, 180)
	description.TorsoColor = teamColor
	description.LeftArmColor = teamColor
	description.RightArmColor = teamColor
	description.LeftLegColor = Color3.fromRGB(40, 40, 60)
	description.RightLegColor = Color3.fromRGB(40, 40, 60)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		return model
	end
	warn("[BotService] Falling back to block rig: " .. tostring(model))
	local fallback = buildFallbackRig()
	for _, part in fallback:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = teamColor
		end
	end
	return fallback
end

local function playAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks = {}
	for key, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = true
			tracks[key] = track
		end
	end
	if tracks.Idle then
		tracks.Idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if not tracks.Run then
			return
		end
		if speed > 1 then
			if not tracks.Run.IsPlaying then
				tracks.Run:Play(0.15)
			end
			tracks.Run:AdjustSpeed(math.clamp(speed / 16, 0.6, 1.8))
		elseif tracks.Run.IsPlaying then
			tracks.Run:Stop(0.15)
		end
	end)
end

function BotService:SpawnBotCharacter(combatant, cframe: CFrame): Model?
	if combatant.Character then
		combatant.Character:Destroy()
	end
	local color = if combatant.Team and MatchConfig.Teams[combatant.Team]
		then MatchConfig.Teams[combatant.Team].Color
		else Color3.fromRGB(200, 200, 210)
	local model = buildRig(color)
	model.Name = combatant.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = "[BOT] " .. combatant.Name
	end
	model.Parent = RaycastUtil.GetContainer(RaycastUtil.Containers.Bots)
	model:PivotTo(cframe)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	if humanoid then
		playAnimations(humanoid)
	end
	local brain = brains[combatant.Id]
	if brain then
		brain:OnSpawned(model)
	end
	return model
end

function BotService:RemoveBot(combatant)
	local brain = brains[combatant.Id]
	if brain then
		brain:Destroy()
		brains[combatant.Id] = nil
	end
	usedNames[combatant.Name] = nil
	if combatant.Character then
		combatant.Character:Destroy()
		combatant.Character = nil
	end
	Services.CombatantService:Remove(combatant)
end

function BotService:RemoveAll()
	for _, combatant in Services.CombatantService:GetAll() do
		if combatant.IsBot then
			BotService:RemoveBot(combatant)
		end
	end
end

function BotService:GetBrains()
	return brains
end

-- Allied scan pulses share revealed positions with bots on the same team.
function BotService:OnPulse(owner, revealed: { Model }, _duration: number)
	for _, brain in brains do
		local bot = brain.Combatant
		if bot ~= owner and (bot.Team ~= nil and bot.Team == owner.Team) then
			for _, character in revealed do
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					brain:HearNoise(root.Position)
				end
			end
		end
	end
end

function BotService:Init(services)
	Services = services
end

function BotService:Start()
	local interval = 1 / BotConfig.ThinkRate
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < interval then
			return
		end
		local step = elapsed
		elapsed = 0
		for _, brain in brains do
			brain:Think(step)
		end
	end)

	-- Hearing: gunshots alert nearby enemy bots.
	Services.CombatService.ShotFired:Connect(function(shooter, origin)
		for _, brain in brains do
			local bot = brain.Combatant
			if bot ~= shooter and bot.Alive and Services.CombatantService:AreEnemies(bot, shooter) and bot.Root then
				if (bot.Root.Position - origin).Magnitude <= brain.Settings.HearingRadius then
					brain:HearNoise(origin)
				end
			end
		end
	end)

	-- Being damaged reveals the attacker's position to the victim bot.
	Services.CombatService.DamageDealt:Connect(function(attacker, victim)
		local brain = brains[victim.Id]
		if brain and attacker and attacker.Root then
			brain:OnDamaged(attacker)
		end
	end)
end

return BotService
