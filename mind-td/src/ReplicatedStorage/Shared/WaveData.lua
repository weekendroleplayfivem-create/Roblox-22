--!strict
--[[
	WaveData
	The 20-wave campaign for NEURAL OUTPOST.

	A group with Adaptive = true does not name its enemy type here. At spawn
	time WaveManager asks AdaptiveAI which counter-unit the enemy has decided
	to field, so those slots are literally where the enemy "responds" to how
	the run has been going. Early waves stay readable and forgiving; the first
	adaptive slot lands at wave 6, once players have had time to form a habit
	worth countering.
]]

export type WaveGroup = {
	Enemy: string?,
	Adaptive: boolean?,
	Count: number,
	Interval: number, -- seconds between units in this group
	Delay: number, -- seconds after wave start before this group begins
}

export type Wave = {
	Number: number,
	Name: string?,
	Groups: { WaveGroup },
	Reward: number,
	PrepTime: number,
	IsBossWave: boolean?,
}

local WaveData = {}

WaveData.DefaultPrepTime = 15
WaveData.FirstWavePrepTime = 25

WaveData.Waves = {
	{ Number = 1, Groups = { { Enemy = "Normal", Count = 5, Interval = 1.2, Delay = 0 } }, Reward = 100, PrepTime = 25 },
	{ Number = 2, Groups = { { Enemy = "Normal", Count = 8, Interval = 1.0, Delay = 0 } }, Reward = 110, PrepTime = 15 },
	{
		Number = 3,
		Groups = {
			{ Enemy = "Normal", Count = 10, Interval = 0.9, Delay = 0 },
			{ Enemy = "Runner", Count = 2, Interval = 1.0, Delay = 6 },
		},
		Reward = 130,
		PrepTime = 15,
	},
	{ Number = 4, Groups = { { Enemy = "Runner", Count = 6, Interval = 0.8, Delay = 0 } }, Reward = 140, PrepTime = 15 },
	{
		Number = 5,
		Groups = {
			{ Enemy = "Normal", Count = 10, Interval = 0.8, Delay = 0 },
			{ Enemy = "Tank", Count = 1, Interval = 1, Delay = 4 },
		},
		Reward = 170,
		PrepTime = 18,
	},
	{
		Number = 6,
		Name = "ADAPTATION ONLINE",
		Groups = {
			{ Enemy = "Normal", Count = 8, Interval = 0.8, Delay = 0 },
			{ Adaptive = true, Count = 4, Interval = 1.0, Delay = 5 },
		},
		Reward = 190,
		PrepTime = 18,
	},
	{
		Number = 7,
		Groups = {
			{ Enemy = "Runner", Count = 8, Interval = 0.6, Delay = 0 },
			{ Adaptive = true, Count = 4, Interval = 0.9, Delay = 6 },
		},
		Reward = 200,
		PrepTime = 15,
	},
	{
		Number = 8,
		Groups = {
			{ Enemy = "Normal", Count = 12, Interval = 0.7, Delay = 0 },
			{ Enemy = "Tank", Count = 2, Interval = 2.0, Delay = 5 },
		},
		Reward = 220,
		PrepTime = 15,
	},
	{
		Number = 9,
		Groups = {
			{ Adaptive = true, Count = 8, Interval = 0.8, Delay = 0 },
			{ Enemy = "Runner", Count = 6, Interval = 0.6, Delay = 8 },
		},
		Reward = 250,
		PrepTime = 15,
	},
	{
		Number = 10,
		Name = "PROTOTYPE",
		Groups = {
			{ Enemy = "MiniBoss", Count = 1, Interval = 1, Delay = 0 },
			{ Enemy = "Normal", Count = 10, Interval = 0.9, Delay = 6 },
		},
		Reward = 400,
		PrepTime = 25,
		IsBossWave = true,
	},
	{
		Number = 11,
		Groups = {
			{ Enemy = "Normal", Count = 14, Interval = 0.6, Delay = 0 },
			{ Adaptive = true, Count = 6, Interval = 0.8, Delay = 6 },
		},
		Reward = 260,
		PrepTime = 18,
	},
	{
		Number = 12,
		Groups = {
			{ Enemy = "Tank", Count = 3, Interval = 2.5, Delay = 0 },
			{ Enemy = "Runner", Count = 10, Interval = 0.5, Delay = 4 },
		},
		Reward = 280,
		PrepTime = 15,
	},
	{
		Number = 13,
		Groups = {
			{ Adaptive = true, Count = 10, Interval = 0.7, Delay = 0 },
			{ Enemy = "Normal", Count = 10, Interval = 0.7, Delay = 5 },
		},
		Reward = 300,
		PrepTime = 15,
	},
	{
		Number = 14,
		Groups = {
			{ Enemy = "Runner", Count = 14, Interval = 0.45, Delay = 0 },
			{ Enemy = "Tank", Count = 2, Interval = 2, Delay = 8 },
		},
		Reward = 320,
		PrepTime = 15,
	},
	{
		Number = 15,
		Name = "PRESSURE TEST",
		Groups = {
			{ Enemy = "Normal", Count = 16, Interval = 0.5, Delay = 0 },
			{ Adaptive = true, Count = 8, Interval = 0.7, Delay = 5 },
			{ Enemy = "Tank", Count = 2, Interval = 2, Delay = 12 },
		},
		Reward = 360,
		PrepTime = 20,
	},
	{
		Number = 16,
		Groups = {
			{ Adaptive = true, Count = 12, Interval = 0.6, Delay = 0 },
			{ Enemy = "Tank", Count = 3, Interval = 2, Delay = 8 },
		},
		Reward = 380,
		PrepTime = 15,
	},
	{
		Number = 17,
		Groups = {
			{ Enemy = "Runner", Count = 18, Interval = 0.4, Delay = 0 },
			{ Adaptive = true, Count = 8, Interval = 0.6, Delay = 6 },
		},
		Reward = 400,
		PrepTime = 15,
	},
	{
		Number = 18,
		Groups = {
			{ Enemy = "Tank", Count = 5, Interval = 2, Delay = 0 },
			{ Adaptive = true, Count = 10, Interval = 0.6, Delay = 5 },
		},
		Reward = 430,
		PrepTime = 18,
	},
	{
		Number = 19,
		Name = "FINAL SWEEP",
		Groups = {
			{ Enemy = "Normal", Count = 20, Interval = 0.4, Delay = 0 },
			{ Adaptive = true, Count = 12, Interval = 0.5, Delay = 5 },
			{ Enemy = "Tank", Count = 4, Interval = 1.5, Delay = 12 },
		},
		Reward = 500,
		PrepTime = 20,
	},
	{
		Number = 20,
		Name = "THE LEARNER",
		Groups = {
			{ Enemy = "Learner", Count = 1, Interval = 1, Delay = 0 },
			{ Adaptive = true, Count = 10, Interval = 1.2, Delay = 15 },
		},
		Reward = 1000,
		PrepTime = 35,
		IsBossWave = true,
	},
} :: { Wave }

WaveData.TotalWaves = #WaveData.Waves

function WaveData.Get(waveNumber: number): Wave?
	return WaveData.Waves[waveNumber]
end

-- Human-readable summary for the "next wave" panel, e.g. "Runner x8, Tank x2".
function WaveData.Describe(waveNumber: number): string
	local wave = WaveData.Waves[waveNumber]
	if not wave then
		return "UNKNOWN"
	end
	local parts = {}
	for _, group in ipairs(wave.Groups) do
		local label = if group.Adaptive then "ADAPTIVE" else (group.Enemy or "?"):upper()
		table.insert(parts, string.format("%s x%d", label, group.Count))
	end
	return table.concat(parts, "   ")
end

return WaveData
