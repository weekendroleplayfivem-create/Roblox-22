--[[
	BossController
	Phase logic for THE LEARNER (brief section 20).

	The boss is the payoff for the whole adaptive system, so its adaptations
	are the loudest ones in the game — it announces what it detected before it
	acts on it. That's the point: the player should recognise their own habit
	being read back to them.

	It still plays fair. The route it walks is chosen once at spawn from the
	same AdaptiveAI read every other unit uses, its resistances only ever move
	within the AIData clamp, and phase three answers the board by sending
	escorts down the lane the player has actually left thin rather than by
	inflating the boss's own numbers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AIData = require(ReplicatedStorage.Shared.AIData)
local AdaptiveAI = require(script.Parent.AdaptiveAI)
local EnemyManager = require(script.Parent.EnemyManager)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")

local BossController = {}

local watched: { [number]: { Enemy: any, Phase: number, EscortsSent: boolean } } = {}
local connection: RBXScriptConnection?
local accumulator = 0

local function say(line: string)
	GameEvent:FireAllClients({
		Type = "BossLine",
		Text = line,
	})
end

-- Announces what the boss read in the player's defence, then applies the one
-- matching bounded buff. Called once, as the boss arrives.
local function applySpawnAdaptation(enemy: any)
	local strategy = AdaptiveAI.GetStrategy()
	local score = AdaptiveAI.GetAdaptationScore()

	say(AIData.BossLines.Spawn)

	task.delay(2.5, function()
		local line = AIData.BossLines[strategy] or AIData.BossLines.Balanced
		say(line)
	end)

	-- One counter-buff, scaled by how confident the read is and hard-capped by
	-- AIData. A shaky read barely changes anything.
	local magnitude = AIData.MinStatAdaptation
		+ (AIData.MaxStatAdaptation - AIData.MinStatAdaptation) * score

	if strategy == "AntiSlow" then
		-- Players leaned on Cryo: the boss hardens against slowing.
		enemy.SlowResistance = math.max(0.2, enemy.SlowResistance - magnitude)
	elseif strategy == "AntiChip" then
		-- Players leaned on chip damage: the boss plates up.
		enemy.DamageResistance = math.max(0.7, enemy.DamageResistance - magnitude)
	elseif strategy == "AntiLongRange" then
		-- Players leaned on range: the boss closes distance faster.
		enemy.BaseSpeed = enemy.BaseSpeed * (1 + magnitude)
	end
end

local function enterPhase(record: any, phase: number)
	record.Phase = phase
	local enemy = record.Enemy

	if phase == 2 then
		say(AIData.BossLines.PhaseTwo)
		-- Phase 2: it commits. A modest, clamped speed increase.
		enemy.BaseSpeed = enemy.BaseSpeed * AIData.ClampModifier(1.15)
		GameEvent:FireAllClients({ Type = "BossPhase", Phase = 2 })
	elseif phase == 3 then
		say(AIData.BossLines.PhaseThree)
		GameEvent:FireAllClients({ Type = "BossPhase", Phase = 3 })

		-- Phase 3 re-reads the board as it stands RIGHT NOW and sends escorts
		-- down whichever lane is currently thin. This is the boss answering
		-- the defence the player has built during the fight, not the one they
		-- had when it spawned.
		if not record.EscortsSent then
			record.EscortsSent = true
			local weakSide = AdaptiveAI.GetDebugInfo()
			local lane = if weakSide.LeftUsage < weakSide.RightUsage then "Left" else "Right"
			local counterUnit = AdaptiveAI.GetCounterUnit()

			task.spawn(function()
				for _ = 1, 6 do
					EnemyManager.Spawn(counterUnit, lane)
					task.wait(1.1)
				end
			end)
		end
	end
end

function BossController.Watch(enemy: any)
	if not enemy or not enemy.IsBoss then
		return
	end

	watched[enemy.Id] = { Enemy = enemy, Phase = 1, EscortsSent = false }

	-- Only THE LEARNER gets the full dialogue treatment; the wave 10 prototype
	-- is a straight fight.
	if enemy.EnemyId == "Learner" then
		applySpawnAdaptation(enemy)
	end

	BossController.Start()
end

function BossController.OnBossDefeated(enemy: any)
	local record = watched[enemy.Id]
	if not record then
		return
	end
	watched[enemy.Id] = nil
	if enemy.EnemyId == "Learner" then
		say(AIData.BossLines.Defeated)
	end
end

-- Low-frequency poll (4Hz). Phase transitions don't need frame precision, and
-- this keeps the boss off the hot movement loop entirely.
function BossController.Start()
	if connection then
		return
	end
	connection = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0

		for id, record in pairs(watched) do
			local enemy = record.Enemy
			if enemy.Dead then
				watched[id] = nil
			else
				local ratio = enemy.Health / enemy.MaxHealth
				if record.Phase == 1 and ratio <= 0.66 then
					enterPhase(record, 2)
				elseif record.Phase == 2 and ratio <= 0.33 then
					enterPhase(record, 3)
				end
			end
		end

		if next(watched) == nil and connection then
			connection:Disconnect()
			connection = nil
		end
	end)
end

function BossController.ClearAll()
	watched = {}
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return BossController
