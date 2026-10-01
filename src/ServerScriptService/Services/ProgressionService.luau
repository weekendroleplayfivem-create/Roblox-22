--[[
	ProgressionService
	Awards XP and Credits (server only), handles level ups and per-match
	challenges. Clients only ever receive notifications.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local ProgressionConfig = require(Shared.Config.ProgressionConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local AbilityConfig = require(Shared.Config.AbilityConfig)

local ProgressionService = {}

local Services

function ProgressionService:Init(services)
	Services = services
end

function ProgressionService:Start()
	Services.CombatService.DamageDealt:Connect(function(attacker, victim, amount)
		if attacker and attacker ~= victim then
			ProgressionService:RecordDamage(attacker, amount)
		end
	end)
end

-- Lists everything that unlocks at exactly `level`.
function ProgressionService:GetUnlocksAtLevel(level: number): { string }
	local unlocks = {}
	for _, id in WeaponConfig.Order do
		local weapon = WeaponConfig.Get(id)
		if weapon.UnlockLevel == level then
			table.insert(unlocks, weapon.DisplayName)
		end
	end
	for _, id in AbilityConfig.Order do
		local ability = AbilityConfig.Get(id)
		if ability.UnlockLevel == level then
			table.insert(unlocks, ability.DisplayName)
		end
	end
	return unlocks
end

-- Adds XP and handles level ups. `reason` is shown in the XP popup.
function ProgressionService:AddXP(player: Player, amount: number, reason: string?, silent: boolean?)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	local oldLevel, newLevel = 0, 0
	Services.DataService:Update(player, function(data)
		oldLevel = data.Level
		data.XP += amount
		local level = ProgressionConfig.LevelFromXP(data.XP)
		data.Level = level
		newLevel = level
		if newLevel > oldLevel then
			data.Credits += ProgressionConfig.Credits.PerLevelUp * (newLevel - oldLevel)
		end
	end)
	if not silent then
		Net.Event("Match", "XPEvent"):FireClient(player, { Amount = amount, Reason = reason })
	end
	if newLevel > oldLevel then
		local unlocks = {}
		for level = oldLevel + 1, newLevel do
			for _, name in ProgressionService:GetUnlocksAtLevel(level) do
				table.insert(unlocks, name)
			end
		end
		Net.Event("UI", "Notify"):FireClient(player, {
			Kind = "LevelUp",
			Level = newLevel,
			Credits = ProgressionConfig.Credits.PerLevelUp * (newLevel - oldLevel),
			Unlocks = unlocks,
			Text = "LEVEL " .. newLevel,
			Duration = 4,
		})
		player:SetAttribute("Level", newLevel)
		local combatant = Services.CombatantService:GetByPlayer(player)
		if combatant then
			combatant.Level = newLevel
		end
	end
end

function ProgressionService:AddCredits(player: Player, amount: number)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	Services.DataService:Update(player, function(data)
		data.Credits += amount
	end)
end

-- Called by MatchService for every real player still in the match at the end.
-- Returns a summary table for the results screen.
function ProgressionService:AwardMatch(combatant, summary)
	local player = combatant.Player
	if not player then
		return nil
	end
	local xp = ProgressionConfig.XP
	local credits = ProgressionConfig.Credits
	local stats = combatant.Stats
	local breakdown = {}

	local minutes = math.clamp(summary.Duration / 60, 0, 10)
	local participation = xp.Participation + math.floor(xp.ParticipationPerMinute * minutes)
	table.insert(breakdown, { Label = "Match complete", XP = participation })
	if summary.Won then
		table.insert(breakdown, { Label = "Victory", XP = xp.Victory })
	elseif summary.TopThree then
		table.insert(breakdown, { Label = "Top 3 finish", XP = xp.TopThreeFFA })
	end

	-- Challenges (per match).
	local completed = {}
	for _, challenge in ProgressionConfig.Challenges do
		local value = stats[challenge.Stat] or 0
		if value >= challenge.Goal then
			table.insert(breakdown, { Label = challenge.Description, XP = challenge.XP })
			table.insert(completed, challenge.Id)
		end
	end

	local total = 0
	for _, line in breakdown do
		total += line.XP
	end
	local creditTotal = credits.PerMatch + credits.PerElimination * stats.Kills + (if summary.Won then credits.Victory else 0)

	ProgressionService:AddXP(player, total, "Match rewards", true)
	ProgressionService:AddCredits(player, creditTotal)
	Services.DataService:Update(player, function(data)
		local lifetime = data.Stats
		lifetime.MatchesPlayed += 1
		if summary.Won then
			lifetime.Wins += 1
		end
		lifetime.BestStreak = math.max(lifetime.BestStreak, stats.BestStreak)
	end)
	return {
		XP = total,
		Credits = creditTotal,
		Breakdown = breakdown,
		Challenges = completed,
	}
end

-- Lifetime stat tracking for in-match events (eliminations count immediately
-- so leaving early never loses them).
function ProgressionService:RecordElimination(killer, victim, assists, info)
	local XP = ProgressionConfig.XP
	if killer and killer.Player then
		local amount = XP.Elimination + (if info.Headshot then XP.Headshot else 0)
		ProgressionService:AddXP(killer.Player, amount, if info.Headshot then "Headshot elimination" else "Elimination")
		Services.DataService:Update(killer.Player, function(data)
			data.Stats.Eliminations += 1
			if info.Headshot then
				data.Stats.Headshots += 1
			end
		end)
	end
	for _, helper in assists do
		if helper.Player then
			ProgressionService:AddXP(helper.Player, XP.Assist, "Assist")
			Services.DataService:Update(helper.Player, function(data)
				data.Stats.Assists += 1
			end)
		end
	end
	if victim.Player then
		Services.DataService:Update(victim.Player, function(data)
			data.Stats.Deaths += 1
		end)
	end
end

function ProgressionService:RecordDamage(attacker, amount: number)
	if attacker and attacker.Player then
		local data = Services.DataService:Get(attacker.Player)
		if data then
			-- Direct write (no sync) to avoid a network update per bullet; it is
			-- synced with the next Update call.
			data.Stats.DamageDealt += amount
		end
	end
end

return ProgressionService
