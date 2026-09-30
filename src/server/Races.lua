--!strict
-- Street races (Unbound buy-in style) and Blacklist challenges (Most Wanted style).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local AIDriver = require(script.Parent.AIDriver)
local CarBuilder = require(script.Parent.CarBuilder)
local Session = require(script.Parent.Session)
local Vehicles = require(script.Parent.Vehicles)

local Races = {}

type Racer = {
	name: string,
	ai: AIDriver.AI?,
	cp: number, -- index of next checkpoint
	finished: boolean,
	place: number?,
}

type Race = {
	def: Config.RaceDef,
	session: Session.Session,
	checkpoints: { Vector3 },
	perLap: number,
	racers: { Racer },
	player: Racer,
	state: string, -- "countdown" | "racing" | "done"
	startTime: number,
	finishedCount: number,
	rival: Config.Rival?,
	driftScore: number,
	folder: Folder,
}

local racesFolder = Instance.new("Folder")
racesFolder.Name = "Races"
racesFolder.Parent = workspace

local GOLD = Color3.fromRGB(255, 215, 60)
local RIVAL_NAMES = { "Jax", "Mika", "Dre", "Suki", "Blaze", "Rook", "Zee", "Kai", "Nitro Nell", "Vex" }

local function setAttrs(player: Player, attrs: { [string]: any })
	for k, v in attrs do
		player:SetAttribute(k, v)
	end
end

local function clearAttrs(player: Player)
	setAttrs(player, {
		RaceActive = false,
		RaceName = "",
		RaceKind = "",
		RacePos = 0,
		RaceRacers = 0,
		RaceCP = 0,
		RaceCPTotal = 0,
		RaceLap = 0,
		RaceLaps = 0,
		RaceTime = 0,
		RaceCountdown = -1,
		RaceNext = Vector3.zero,
		RaceScore = 0,
		RaceTarget = 0,
		RaceStandings = "",
	})
end

local function buildCheckpoints(def: Config.RaceDef): ({ Vector3 }, number)
	local route = {}
	for _, p in def.route do
		table.insert(route, Grid.Intersection(p[1], p[2]))
	end
	local lap = {}
	for k = 2, #route do
		table.insert(lap, route[k])
	end
	if def.kind == "circuit" then
		table.insert(lap, route[1])
	end
	local cps = {}
	local laps = if def.kind == "circuit" then def.laps else 1
	for _ = 1, laps do
		for _, p in lap do
			table.insert(cps, p)
		end
	end
	return cps, #lap
end

local function progress(race: Race, racer: Racer, pos: Vector3): number
	if racer.finished then
		return 1e9 - (racer.place or 0)
	end
	local nextCp = race.checkpoints[racer.cp]
	return racer.cp * 10000 - (nextCp - pos).Magnitude
end

local function racerPos(race: Race, racer: Racer): Vector3?
	if racer.ai then
		local ai = racer.ai :: AIDriver.AI
		if ai.alive and ai.model.PrimaryPart then
			return ai.model.PrimaryPart.Position
		end
		return nil
	end
	return Session.CarPosition(race.session)
end

local function cleanup(race: Race)
	for _, r in race.racers do
		if r.ai then
			local ai = r.ai :: AIDriver.AI
			AIDriver.Remove(ai)
			Debris:AddItem(ai.model, 3)
		end
	end
	Debris:AddItem(race.folder, 3)
	race.session.race = nil
	clearAttrs(race.session.player)
end

local function finishPlayer(race: Race, place: number?)
	local s = race.session
	local def = race.def
	race.state = "done"
	local night = Session.NightMult()
	local heatMult = Session.HeatPayoutMult(s)
	if def.kind == "drift" then
		local target = def.driftTarget or 1
		if race.driftScore >= target then
			local ratio = math.min(race.driftScore / target, 2)
			local payout = def.reward * ratio * night * heatMult
			s.profile.racesWon += 1
			Session.Banner(s.player, "DRIFT EVENT COMPLETE", "Score " .. math.floor(race.driftScore), GOLD)
			Session.AddUnbanked(s, payout, def.name .. " winnings")
		else
			Session.Banner(s.player, "TARGET MISSED", math.floor(race.driftScore) .. " / " .. target, Color3.fromRGB(255, 90, 90))
		end
	elseif place then
		local frac = Config.PlacePayout[place] or 0
		if race.rival then
			local rival = race.rival :: Config.Rival
			if place == 1 then
				s.profile.blacklistBeaten = math.max(s.profile.blacklistBeaten, 6 - rival.rank)
				s.profile.racesWon += 1
				s.profile.owned[rival.carId] = true
				local carDef = Config.GetCar(rival.carId)
				Session.Banner(s.player, "BLACKLIST #" .. rival.rank .. " DEFEATED", string.upper(rival.name) .. " is off the list", GOLD)
				Session.Notify(s.player, "PINK SLIP: " .. (if carDef then carDef.name else rival.carId) .. " is now in your garage", GOLD)
				Session.AddUnbanked(s, rival.reward, "Blacklist reward")
			else
				Session.Banner(s.player, "YOU LOST", string.upper(rival.name) .. " beat you. Try again!", Color3.fromRGB(255, 90, 90))
			end
		else
			if place == 1 then
				s.profile.racesWon += 1
				Session.Banner(s.player, "1ST PLACE", def.name, GOLD)
			else
				Session.Banner(s.player, place .. (if place == 2 then "ND" elseif place == 3 then "RD" else "TH") .. " PLACE", def.name, Color3.new(1, 1, 1))
			end
			if frac > 0 then
				Session.AddUnbanked(s, (def.reward + def.buyIn) * frac * night * heatMult, def.name .. " winnings")
			end
		end
	else
		Session.Notify(s.player, "Race abandoned", Color3.fromRGB(255, 90, 90))
	end
	if place or def.kind == "drift" then
		local before = Session.HeatLevel(s)
		s.heat = math.min(5, s.heat + def.heat * night)
		if Session.HeatLevel(s) > before then
			Session.Notify(s.player, "Your HEAT is now level " .. Session.HeatLevel(s) .. " - bigger payouts, angrier cops", Color3.fromRGB(255, 70, 70))
		end
	end
	Session.CheckMilestones(s)
	cleanup(race)
end

local function rivalThink(race: Race, racer: Racer)
	return function(ai: AIDriver.AI, _dt: number)
		if race.state ~= "racing" or racer.finished then
			ai.input.throttle = 0
			ai.input.handbrake = true
			ai.input.steer = 0
			return
		end
		local target = race.checkpoints[racer.cp]
		-- rubber band against the player
		local pos = ai.state.root.Position
		local ppos = Session.CarPosition(race.session)
		local mult = 1
		if ppos then
			local diff = progress(race, racer, pos) - progress(race, race.player, ppos)
			if diff > 250 then
				mult = 0.86
			elseif diff < -250 then
				mult = 1.14
			end
		end
		ai.state.speedMult = mult
		ai.input.nitro = mult > 1
		AIDriver.DriveTo(ai, target)
	end
end

function Races.Start(s: Session.Session, def: Config.RaceDef, rival: Config.Rival?): (boolean, string)
	if s.race then
		return false, "Already racing"
	end
	if s.mode ~= "idle" then
		return false, "Lose the cops first!"
	end
	if not s.car then
		return false, "No car"
	end
	if s.profile.cash < def.buyIn then
		return false, "Not enough cash for the $" .. def.buyIn .. " buy-in"
	end
	s.profile.cash -= def.buyIn

	local checkpoints, perLap = buildCheckpoints(def)
	local folder = Instance.new("Folder")
	folder.Name = s.player.Name .. "_Race"
	folder.Parent = racesFolder

	local playerRacer: Racer = { name = s.player.DisplayName, ai = nil, cp = 1, finished = false }
	local race: Race = {
		def = def,
		session = s,
		checkpoints = checkpoints,
		perLap = perLap,
		racers = { playerRacer },
		player = playerRacer,
		state = "countdown",
		startTime = 0,
		finishedCount = 0,
		rival = rival,
		driftScore = 0,
		folder = folder,
	}
	s.race = race

	-- starting grid, placed along the first segment of the route
	local first = def.route[1]
	local startPos = Grid.Intersection(first[1], first[2])
	local dir
	if #def.route > 1 then
		local second = def.route[2]
		dir = (Grid.Intersection(second[1], second[2]) - startPos).Unit
	else
		dir = -Vector3.zAxis
	end
	local right = dir:Cross(Vector3.yAxis)
	local function slot(k: number): CFrame
		local row = math.floor(k / 2)
		local side = if k % 2 == 0 then -11 else 11
		local p = startPos + dir * (70 - row * 22) + right * side
		return CFrame.lookAt(p, p + dir)
	end

	Vehicles.Spawn(s, slot(if def.kind == "drift" then 0 else 2))
	Vehicles.Freeze(s, 3.2)

	local rivals = if rival then 1 else def.rivals
	local slotOrder = { 0, 1, 3, 4, 5 }
	for k = 1, rivals do
		local carDef
		local name
		local speed = def.rivalSpeed
		if rival then
			carDef = Config.GetCar(rival.carId)
			name = "#" .. rival.rank .. " " .. rival.name
			speed = rival.speed
		else
			carDef = Config.Cars[math.random(1, 5)]
			name = RIVAL_NAMES[math.random(1, #RIVAL_NAMES)]
		end
		assert(carDef, "rival car missing")
		local fx = Config.DrivingEffects[math.random(1, #Config.DrivingEffects)].color
		local model = CarBuilder.Build({
			style = carDef.style,
			color = carDef.color,
			name = "Rival_" .. name,
			effectColor = fx,
			glow = fx,
			label = name,
			rim = math.random(1, #Config.Visual.rim),
			spoiler = if math.random() < 0.5 then nil else math.random(2, 4),
			kit = math.random(1, 3),
		})
		local cf = slot(slotOrder[k])
		model:PivotTo(Vehicles.GroundCFrame(cf, model))
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		model.Parent = folder
		local root = model.PrimaryPart :: BasePart
		root.Anchored = true
		local racer: Racer = { name = name, ai = nil, cp = 1, finished = false }
		local stats = {
			maxSpeed = speed,
			accel = carDef.accel * (speed / carDef.maxSpeed),
			brake = carDef.brake,
			turn = carDef.turn,
			grip = carDef.grip + 1,
			nitroMult = 1.15,
		}
		racer.ai = AIDriver.Add(model, stats, "rival", rivalThink(race, racer))
		table.insert(race.racers, racer)
	end

	setAttrs(s.player, {
		RaceActive = true,
		RaceName = if rival then ("BLACKLIST #" .. rival.rank .. " vs " .. rival.name) else def.name,
		RaceKind = def.kind,
		RaceRacers = #race.racers,
		RaceCP = 0,
		RaceCPTotal = #checkpoints,
		RaceLap = 1,
		RaceLaps = if def.kind == "circuit" then def.laps else 1,
		RaceTime = 0,
		RaceNext = checkpoints[1] or startPos,
		RaceScore = 0,
		RaceTarget = def.driftTarget or 0,
	})

	task.spawn(function()
		for n = 3, 1, -1 do
			if s.race ~= race then
				return
			end
			s.player:SetAttribute("RaceCountdown", n)
			task.wait(1)
		end
		if s.race ~= race then
			return
		end
		s.player:SetAttribute("RaceCountdown", 0)
		race.state = "racing"
		race.startTime = os.clock()
		for _, r in race.racers do
			if r.ai then
				(r.ai :: AIDriver.AI).state.root.Anchored = false
				pcall(function()
					((r.ai :: AIDriver.AI).state.root :: BasePart):SetNetworkOwner(nil)
				end)
			end
		end
		task.delay(1, function()
			if s.race == race then
				s.player:SetAttribute("RaceCountdown", -1)
			end
		end)
	end)

	return true, "Race started"
end

function Races.Cancel(s: Session.Session)
	local race = s.race
	if race then
		finishPlayer(race, nil)
	end
end

-- Called every 0.1s from the main loop
function Races.Update(s: Session.Session, driftGain: number)
	local race = s.race :: Race?
	if not race or race.state ~= "racing" then
		return
	end
	local elapsed = os.clock() - race.startTime
	local player = s.player
	player:SetAttribute("RaceTime", elapsed)

	if race.def.kind == "drift" then
		race.driftScore += driftGain
		player:SetAttribute("RaceScore", math.floor(race.driftScore))
		local left = (race.def.duration or 60) - elapsed
		player:SetAttribute("RaceTimeLeft", left)
		if left <= 0 then
			finishPlayer(race, 1)
		end
		return
	end

	for _, r in race.racers do
		if r.finished then
			continue
		end
		local pos = racerPos(race, r)
		if not pos then
			continue
		end
		local cp = race.checkpoints[r.cp]
		if Vector3.new(pos.X - cp.X, 0, pos.Z - cp.Z).Magnitude < 38 then
			r.cp += 1
			if r.cp > #race.checkpoints then
				r.finished = true
				race.finishedCount += 1
				r.place = race.finishedCount
				if r == race.player then
					finishPlayer(race, r.place)
					return
				end
			end
		end
	end

	-- standings
	local ppos = Session.CarPosition(s)
	if ppos then
		local mine = progress(race, race.player, ppos)
		local place = 1
		for _, r in race.racers do
			if r ~= race.player then
				local p = racerPos(race, r)
				if p and progress(race, r, p) > mine then
					place += 1
				end
			end
		end
		player:SetAttribute("RacePos", place)

		-- live standings list for the HUD
		local rows = {}
		for _, r in race.racers do
			local p = if r == race.player then ppos else racerPos(race, r)
			if p then
				table.insert(rows, { name = if r == race.player then "YOU" else r.name, score = progress(race, r, p) })
			end
		end
		table.sort(rows, function(x, y)
			return x.score > y.score
		end)
		local lines = {}
		for k, row in rows do
			table.insert(lines, k .. ".  " .. row.name)
		end
		player:SetAttribute("RaceStandings", table.concat(lines, "\n"))
	end
	player:SetAttribute("RaceCP", race.player.cp - 1)
	player:SetAttribute("RaceLap", math.min(math.floor((race.player.cp - 1) / race.perLap) + 1, player:GetAttribute("RaceLaps") :: number))
	player:SetAttribute("RaceNext", race.checkpoints[race.player.cp] or Vector3.zero)

	if elapsed > 300 then
		Session.Notify(player, "Time's up!", Color3.fromRGB(255, 90, 90))
		finishPlayer(race, nil)
	end
end

-- Build a RaceDef for a Blacklist rival.
function Races.RivalDef(rival: Config.Rival): Config.RaceDef
	return {
		id = "blacklist_" .. rival.rank,
		name = "Blacklist #" .. rival.rank .. ": " .. rival.name,
		kind = if rival.laps > 1 then "circuit" else "sprint",
		route = rival.route,
		laps = rival.laps,
		buyIn = 0,
		reward = 0,
		heat = 1,
		rivals = 1,
		rivalSpeed = rival.speed,
	}
end

return Races
