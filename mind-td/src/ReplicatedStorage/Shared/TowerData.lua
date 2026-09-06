--!strict
--[[
	TowerData
	Authoritative tower stats. The server reads these for every damage,
	cost and upgrade decision; the client reads the same table purely to draw
	the shop and range previews. A client that lies about a stat changes
	nothing, because the server never asks it for one.
]]

export type TowerLevel = {
	Damage: number,
	Range: number,
	Cooldown: number,
	Cost: number, -- cost to REACH this level (level 1 = purchase price)
	Slow: number?,
	SlowDuration: number?,
	AnalysisBonus: number?,
}

export type Tower = {
	Id: string,
	DisplayName: string,
	Description: string,
	Role: string,
	Color: Color3,
	AccentColor: Color3,
	ProjectileColor: Color3,
	Levels: { TowerLevel },
}

local TowerData = {}

TowerData.TargetModes = { "First", "Last", "Strongest", "Weakest" }

TowerData.Towers = {
	Guardian = {
		Id = "Guardian",
		DisplayName = "Guardian",
		Description = "Reliable single-target damage. The backbone of any line.",
		Role = "Damage",
		Color = Color3.fromRGB(60, 70, 88),
		AccentColor = Color3.fromRGB(70, 190, 255),
		ProjectileColor = Color3.fromRGB(110, 210, 255),
		Levels = {
			{ Damage = 15, Range = 28, Cooldown = 0.8, Cost = 250 },
			{ Damage = 25, Range = 30, Cooldown = 0.75, Cost = 200 },
			{ Damage = 45, Range = 34, Cooldown = 0.65, Cost = 350 },
		},
	},

	Cryo = {
		Id = "Cryo",
		DisplayName = "Cryo",
		Description = "Low damage, heavy slow. Buys your Guardians time.",
		Role = "Support",
		Color = Color3.fromRGB(72, 96, 112),
		AccentColor = Color3.fromRGB(150, 235, 255),
		ProjectileColor = Color3.fromRGB(190, 245, 255),
		Levels = {
			{ Damage = 7, Range = 24, Cooldown = 1.5, Cost = 400, Slow = 0.30, SlowDuration = 2 },
			{ Damage = 11, Range = 26, Cooldown = 1.4, Cost = 300, Slow = 0.38, SlowDuration = 2.4 },
			{ Damage = 16, Range = 29, Cooldown = 1.2, Cost = 450, Slow = 0.45, SlowDuration = 3 },
		},
	},

	Analyzer = {
		Id = "Analyzer",
		DisplayName = "Analyzer",
		Description = "Barely a weapon. It reads the enemy, and shows you what they've learned.",
		Role = "Intel",
		Color = Color3.fromRGB(58, 62, 76),
		AccentColor = Color3.fromRGB(180, 130, 255),
		ProjectileColor = Color3.fromRGB(200, 160, 255),
		Levels = {
			{ Damage = 3, Range = 35, Cooldown = 2, Cost = 600, AnalysisBonus = 0.20 },
			{ Damage = 5, Range = 38, Cooldown = 1.9, Cost = 400, AnalysisBonus = 0.35 },
			{ Damage = 8, Range = 42, Cooldown = 1.7, Cost = 600, AnalysisBonus = 0.55 },
		},
	},
} :: { [string]: Tower }

TowerData.ShopOrder = { "Guardian", "Cryo", "Analyzer" }

TowerData.MaxLevel = 3
TowerData.SellRefundRatio = 0.6

function TowerData.Get(towerId: string): Tower?
	return TowerData.Towers[towerId]
end

function TowerData.GetLevel(towerId: string, level: number): TowerLevel?
	local tower = TowerData.Towers[towerId]
	if not tower then
		return nil
	end
	return tower.Levels[level]
end

-- Total spent to get a tower to its current level, used for sell refunds.
function TowerData.TotalInvested(towerId: string, level: number): number
	local tower = TowerData.Towers[towerId]
	if not tower then
		return 0
	end
	local total = 0
	for index = 1, math.min(level, #tower.Levels) do
		total += tower.Levels[index].Cost
	end
	return total
end

function TowerData.IsValidTargetMode(mode: string): boolean
	for _, valid in ipairs(TowerData.TargetModes) do
		if valid == mode then
			return true
		end
	end
	return false
end

return TowerData
