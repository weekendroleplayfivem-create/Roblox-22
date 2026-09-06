--[[
	WaveManager
	Runs a wave: resolves its groups into actual spawns, tracks how many units
	are still alive, and reports when the wave is finished.

	Adaptive groups are resolved at spawn time, not wave start, so the enemy's
	answer reflects the board as it is at that moment — including towers built
	during the wave itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveData = require(ReplicatedStorage.Shared.WaveData)
local EnemyData = require(ReplicatedStorage.Shared.EnemyData)
local AdaptiveAI = require(script.Parent.AdaptiveAI)
local EnemyManager = require(script.Parent.EnemyManager)
local BossController = require(script.Parent.BossController)

local WaveManager = {}

WaveManager.CurrentWave = 0
WaveManager.Spawning = false

local aliveFromWave = 0
local spawnToken = 0 -- invalidates in-flight spawn loops when a run resets

-- Set by GameManager.
WaveManager.OnWaveCleared = nil :: ((waveNumber: number) -> ())?

local function spawnGroup(group: any, token: number)
	if group.Delay and group.Delay > 0 then
		task.wait(group.Delay)
	end

	for index = 1, group.Count do
		if token ~= spawnToken then
			return -- run was reset underneath us
		end

		-- Adaptive slots ask the AI what to send, right now.
		local enemyId = group.Enemy
		if group.Adaptive then
			enemyId = AdaptiveAI.GetCounterUnit()
		end

		local enemy = EnemyManager.Spawn(enemyId)
		if enemy then
			aliveFromWave += 1
			if enemy.IsBoss then
				BossController.Watch(enemy)
			end
		end

		if index < group.Count then
			task.wait(group.Interval)
		end
	end
end

-- Called by GameManager whenever an enemy dies or reaches the Core, so the
-- wave can end on the last unit rather than on a timer.
function WaveManager.NotifyEnemyRemoved()
	aliveFromWave = math.max(0, aliveFromWave - 1)

	if aliveFromWave == 0 and not WaveManager.Spawning then
		local cleared = WaveManager.CurrentWave
		AdaptiveAI.OnWaveCompleted(cleared)
		if WaveManager.OnWaveCleared then
			WaveManager.OnWaveCleared(cleared)
		end
	end
end

function WaveManager.StartWave(waveNumber: number): boolean
	local wave = WaveData.Get(waveNumber)
	if not wave then
		return false
	end

	WaveManager.CurrentWave = waveNumber
	WaveManager.Spawning = true
	aliveFromWave = 0
	spawnToken += 1
	local token = spawnToken

	-- Each group runs on its own thread so delays and intervals overlap the
	-- way the wave table describes.
	local groupsRunning = #wave.Groups
	for _, group in ipairs(wave.Groups) do
		task.spawn(function()
			spawnGroup(group, token)
			groupsRunning -= 1
			if groupsRunning <= 0 and token == spawnToken then
				WaveManager.Spawning = false
				-- Edge case: everything spawned died before the last group
				-- finished spawning, so nothing is left to trigger the check.
				if aliveFromWave == 0 then
					WaveManager.NotifyEnemyRemoved()
				end
			end
		end)
	end

	return true
end

function WaveManager.GetWaveInfo(waveNumber: number)
	local wave = WaveData.Get(waveNumber)
	if not wave then
		return nil
	end
	return {
		Number = wave.Number,
		Name = wave.Name,
		Summary = WaveData.Describe(waveNumber),
		PrepTime = wave.PrepTime,
		Reward = wave.Reward,
		IsBossWave = wave.IsBossWave == true,
		Total = WaveData.TotalWaves,
	}
end

function WaveManager.AliveCount(): number
	return aliveFromWave
end

function WaveManager.Reset()
	spawnToken += 1
	WaveManager.CurrentWave = 0
	WaveManager.Spawning = false
	aliveFromWave = 0
end

-- Guard so a malformed wave table can't silently spawn nothing.
function WaveManager.Validate()
	for number, wave in ipairs(WaveData.Waves) do
		assert(wave.Number == number, string.format("Wave %d has mismatched Number field", number))
		for _, group in ipairs(wave.Groups) do
			if not group.Adaptive then
				assert(
					EnemyData.Get(group.Enemy or ""),
					string.format("Wave %d references unknown enemy '%s'", number, tostring(group.Enemy))
				)
			end
		end
	end
end

return WaveManager
