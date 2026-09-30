--!strict
-- Runtime (non-saved) state for every player in the server, plus money helpers.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)

local Session = {}

export type Session = {
	player: Player,
	profile: PlayerData.Profile,
	car: Model?,
	stats: Config.Stats?,
	unbanked: number,
	heat: number,
	mode: string, -- "idle" | "pursuit" | "cooldown"
	evade: number,
	cooldown: number,
	bust: number,
	bounty: number,
	pursuitTime: number,
	copsWrecked: number,
	cops: { any },
	lastSeen: Vector3?,
	lastCopSpawn: number,
	lastRoadblock: number,
	heli: Model?,
	race: any?,
	driftCombo: number,
	driftIdle: number,
	camCooldown: { [number]: number },
	atSafehouse: boolean,
	hiding: boolean,
	frozenUntil: number,
	inGarage: boolean,
	atBlackMarket: boolean,
}

local sessions: { [Player]: Session } = {}
local remotes: Folder? = nil

function Session.SetRemotes(folder: Folder)
	remotes = folder
end

function Session.Create(player: Player, profile: PlayerData.Profile): Session
	local s: Session = {
		player = player,
		profile = profile,
		car = nil,
		stats = nil,
		unbanked = 0,
		heat = 0,
		mode = "idle",
		evade = 0,
		cooldown = 0,
		bust = 0,
		bounty = 0,
		pursuitTime = 0,
		copsWrecked = 0,
		cops = {},
		lastSeen = nil,
		lastCopSpawn = 0,
		lastRoadblock = 0,
		heli = nil,
		race = nil,
		driftCombo = 0,
		driftIdle = 0,
		camCooldown = {},
		atSafehouse = false,
		hiding = false,
		frozenUntil = 0,
		inGarage = false,
		atBlackMarket = false,
	}
	sessions[player] = s
	return s
end

function Session.Get(player: Player): Session?
	return sessions[player]
end

function Session.Remove(player: Player)
	sessions[player] = nil
end

function Session.All(): { [Player]: Session }
	return sessions
end

function Session.IsNight(): boolean
	return Config.IsNight(Lighting.ClockTime)
end

function Session.NightMult(): number
	return if Session.IsNight() then Config.NightMultiplier else 1
end

function Session.HeatLevel(s: Session): number
	return math.clamp(math.floor(s.heat), 0, 5)
end

-- Unbound: higher heat = bigger race payouts
function Session.HeatPayoutMult(s: Session): number
	return 1 + 0.25 * Session.HeatLevel(s)
end

function Session.Notify(player: Player, text: string, color: Color3?)
	if not remotes then
		return
	end
	local ev = (remotes :: Folder):FindFirstChild("Notify") :: RemoteEvent?
	if ev then
		ev:FireClient(player, text, color or Color3.new(1, 1, 1))
	end
end

function Session.Sync(s: Session)
	local p = s.player
	p:SetAttribute("Cash", s.profile.cash)
	p:SetAttribute("Unbanked", math.floor(s.unbanked))
	p:SetAttribute("Heat", s.heat)
	p:SetAttribute("PursuitMode", s.mode)
	p:SetAttribute("Evade", s.evade)
	p:SetAttribute("Cooldown", s.cooldown)
	p:SetAttribute("Bust", s.bust)
	p:SetAttribute("Bounty", math.floor(s.bounty))
	p:SetAttribute("TotalBounty", s.profile.totalBounty)
	p:SetAttribute("RacesWon", s.profile.racesWon)
	p:SetAttribute("BlacklistBeaten", s.profile.blacklistBeaten)
	p:SetAttribute("DriftCombo", math.floor(s.driftCombo))
	p:SetAttribute("AtSafehouse", s.atSafehouse)
	p:SetAttribute("AtBlackMarket", s.atBlackMarket)
	p:SetAttribute("Hiding", s.hiding)
	p:SetAttribute("Night", Session.IsNight())
	local level, into, need = Session.RepLevel(s.profile.rep)
	p:SetAttribute("RepLevel", level)
	p:SetAttribute("RepProgress", into / need)
	p:SetAttribute("Weapon", s.profile.weapon)
	local ls = p:FindFirstChild("leaderstats")
	if ls then
		local cash = ls:FindFirstChild("Cash") :: IntValue?
		local bounty = ls:FindFirstChild("Bounty") :: IntValue?
		local heat = ls:FindFirstChild("Heat") :: IntValue?
		if cash then
			cash.Value = s.profile.cash
		end
		if bounty then
			bounty.Value = s.profile.totalBounty
		end
		if heat then
			heat.Value = Session.HeatLevel(s)
		end
	end
end

-- Fire any client remote by name (safe before the remotes exist).
function Session.Fire(player: Player, name: string, ...: any)
	if not remotes then
		return
	end
	local ev = (remotes :: Folder):FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then
		ev:FireClient(player, ...)
	end
end

function Session.Banner(player: Player, title: string, subtitle: string?, color: Color3?)
	if not remotes then
		return
	end
	local ev = (remotes :: Folder):FindFirstChild("Banner") :: RemoteEvent?
	if ev then
		ev:FireClient(player, title, subtitle or "", color or Color3.new(1, 1, 1))
	end
end

function Session.StatValue(s: Session, stat: string): number
	if stat == "racesWon" then
		return s.profile.racesWon
	end
	return s.profile.stats[stat] or 0
end

-- Pay out any milestones that are now complete (reward goes straight to the bank).
function Session.CheckMilestones(s: Session)
	local done = s.profile.milestones
	for _, m in Config.Milestones do
		if not done[m.id] and Session.StatValue(s, m.stat) >= m.goal then
			done[m.id] = true
			s.profile.cash += m.reward
			Session.AddRep(s, 200)
			Session.Banner(s.player, "MILESTONE COMPLETE", m.name .. "   +$" .. m.reward, Color3.fromRGB(120, 255, 170))
		end
	end
end

function Session.AddStat(s: Session, stat: string, amount: number)
	s.profile.stats[stat] = (s.profile.stats[stat] or 0) + amount
	Session.CheckMilestones(s)
end

function Session.MaxStat(s: Session, stat: string, value: number)
	if value > (s.profile.stats[stat] or 0) then
		s.profile.stats[stat] = value
		Session.CheckMilestones(s)
	end
end

function Session.RepLevel(rep: number): (number, number, number)
	-- returns level, rep into this level, rep needed for the next level
	local level = 1
	local left = rep
	while level < Config.Rep.MaxLevel do
		local need = Config.Rep.PerLevel(level)
		if left < need then
			return level, left, need
		end
		left -= need
		level += 1
	end
	return level, 0, 1
end

function Session.AddRep(s: Session, amount: number, reason: string?)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	local before = Session.RepLevel(s.profile.rep)
	s.profile.rep += amount
	local after = Session.RepLevel(s.profile.rep)
	if reason then
		Session.Notify(s.player, reason .. "  +" .. amount .. " REP", Color3.fromRGB(170, 140, 255))
	end
	if after > before then
		local cash = Config.Rep.LevelReward * math.max(1, math.floor(after / 2))
		s.profile.cash += cash
		Session.Banner(s.player, "REP LEVEL " .. after, "+$" .. cash .. " level-up bonus", Color3.fromRGB(170, 140, 255))
	end
end

function Session.AddUnbanked(s: Session, amount: number, reason: string)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	s.unbanked += amount
	Session.Notify(s.player, reason .. "  +$" .. amount, Color3.fromRGB(255, 200, 60))
end

function Session.CarSpeed(s: Session): number
	local car = s.car
	if car and car.PrimaryPart then
		return car.PrimaryPart.AssemblyLinearVelocity.Magnitude
	end
	return 0
end

function Session.CarPosition(s: Session): Vector3?
	local car = s.car
	if car and car.PrimaryPart and car.Parent then
		return car.PrimaryPart.Position
	end
	return nil
end

return Session
