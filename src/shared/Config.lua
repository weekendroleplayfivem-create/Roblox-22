--!strict
-- Central tuning for WANTED: UNBOUND.
-- Most Wanted style: heat levels, pursuits, bounty, Blacklist rivals, pursuit breakers.
-- Unbound style: night stakes, unbanked cash that must reach the safehouse, buy-in races,
-- drift combos, burst nitro and neon driving effects.

local Config = {}

Config.GameName = "WANTED: UNBOUND"

-- 1 stud/s is shown as this many MPH on the speedometer.
Config.MphPerStud = 0.75

---------------------------------------------------------------------------
-- City grid
---------------------------------------------------------------------------
Config.Grid = {
	Blocks = 8, -- 8x8 city blocks -> 9x9 intersections
	BlockSize = 240,
	RoadWidth = 60,
	GroundY = 0,
}
Config.Grid.Cell = Config.Grid.BlockSize + Config.Grid.RoadWidth
Config.Grid.HalfExtent = Config.Grid.Blocks * Config.Grid.Cell / 2

-- Special blocks, by block index (0-based, x then z)
Config.Blocks = {
	Safehouse = { 3, 4 },
	Park = { 5, 2 },
	HidingSpots = { { 1, 1 }, { 6, 6 }, { 2, 6 } }, -- covered parking garages
}

---------------------------------------------------------------------------
-- Cars
---------------------------------------------------------------------------
export type CarDef = {
	id: string,
	name: string,
	class: string,
	price: number,
	maxSpeed: number, -- studs/s
	accel: number, -- studs/s^2
	brake: number,
	turn: number, -- rad/s at full lock
	grip: number, -- lateral grip (higher = less slide)
	nitroMult: number,
	color: Color3,
	style: string, -- body shape: "coupe" | "muscle" | "hyper" | "suv"
	blacklistOnly: boolean?,
}

Config.Cars = {
	{
		id = "vortex",
		name = "Vortex GT",
		class = "D",
		price = 0,
		maxSpeed = 130,
		accel = 42,
		brake = 90,
		turn = 2.3,
		grip = 6,
		nitroMult = 1.3,
		color = Color3.fromRGB(40, 170, 255),
		style = "coupe",
	},
	{
		id = "hawk",
		name = "Street Hawk R",
		class = "C",
		price = 15000,
		maxSpeed = 148,
		accel = 50,
		brake = 95,
		turn = 2.4,
		grip = 6.5,
		nitroMult = 1.32,
		color = Color3.fromRGB(255, 200, 40),
		style = "coupe",
	},
	{
		id = "kaiju",
		name = "Kaiju RS",
		class = "B",
		price = 40000,
		maxSpeed = 166,
		accel = 57,
		brake = 100,
		turn = 2.45,
		grip = 6.2,
		nitroMult = 1.34,
		color = Color3.fromRGB(230, 60, 60),
		style = "hyper",
	},
	{
		id = "phantom",
		name = "Phantom V8",
		class = "A",
		price = 90000,
		maxSpeed = 184,
		accel = 64,
		brake = 100,
		turn = 2.25,
		grip = 5.6,
		nitroMult = 1.36,
		color = Color3.fromRGB(30, 30, 35),
		style = "muscle",
	},
	{
		id = "apex",
		name = "Apex Hyper X",
		class = "S",
		price = 250000,
		maxSpeed = 205,
		accel = 72,
		brake = 110,
		turn = 2.5,
		grip = 7,
		nitroMult = 1.38,
		color = Color3.fromRGB(170, 60, 255),
		style = "hyper",
	},
	-- Pink-slip cars won from the Blacklist
	{
		id = "tiko_drifter",
		name = "Tiko's Drifter",
		class = "C",
		price = 0,
		maxSpeed = 152,
		accel = 52,
		brake = 95,
		turn = 2.7,
		grip = 5,
		nitroMult = 1.35,
		color = Color3.fromRGB(255, 120, 200),
		style = "coupe",
		blacklistOnly = true,
	},
	{
		id = "viper_venom",
		name = "Viper's Venom",
		class = "B",
		price = 0,
		maxSpeed = 172,
		accel = 58,
		brake = 100,
		turn = 2.45,
		grip = 6.4,
		nitroMult = 1.36,
		color = Color3.fromRGB(80, 255, 90),
		style = "hyper",
		blacklistOnly = true,
	},
	{
		id = "nova_star",
		name = "Nova's Supernova",
		class = "A",
		price = 0,
		maxSpeed = 188,
		accel = 66,
		brake = 105,
		turn = 2.5,
		grip = 6.4,
		nitroMult = 1.37,
		color = Color3.fromRGB(255, 150, 30),
		style = "hyper",
		blacklistOnly = true,
	},
	{
		id = "kingpin_crown",
		name = "Kingpin's Crown",
		class = "A",
		price = 0,
		maxSpeed = 198,
		accel = 70,
		brake = 105,
		turn = 2.35,
		grip = 6,
		nitroMult = 1.4,
		color = Color3.fromRGB(255, 215, 0),
		style = "muscle",
		blacklistOnly = true,
	},
	{
		id = "ghost_zero",
		name = "Ghost Zero",
		class = "S+",
		price = 0,
		maxSpeed = 225,
		accel = 80,
		brake = 115,
		turn = 2.6,
		grip = 7.2,
		nitroMult = 1.4,
		color = Color3.fromRGB(235, 245, 255),
		style = "hyper",
		blacklistOnly = true,
	},
} :: { CarDef }

Config.StarterCar = "vortex"

function Config.GetCar(id: string): CarDef?
	for _, car in Config.Cars do
		if car.id == id then
			return car
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Tuning (Unbound style). Per car you get:
--   * performance parts in tiers Stock -> Sport -> Pro -> Elite -> Elite+
--   * handling sliders (drift <-> grip, downforce, steering, ride height)
--   * visual customisation (rims, tint, spoiler, body kit, underglow)
-- Everything feeds a Performance Rating (PI) and class, C up to S+.
---------------------------------------------------------------------------
Config.PartTiers = { "Stock", "Sport", "Pro", "Elite", "Elite+" }
Config.PartTierCost = { 1, 2.5, 5, 9 } -- multiplier for tier 1..4 on the part base price

export type PartDef = {
	id: string,
	name: string,
	desc: string,
	base: number,
	-- bonus per tier (fractions, except nitro/cap which are absolute)
	maxSpeed: number?,
	accel: number?,
	turn: number?,
	grip: number?,
	brake: number?,
	nitro: number?,
	cap: number?,
}

Config.Parts = {
	{ id = "engine", name = "Engine", desc = "Top speed + acceleration", base = 3000, maxSpeed = 0.03, accel = 0.05 },
	{ id = "turbo", name = "Forced Induction", desc = "Turbo / supercharger: acceleration", base = 3500, maxSpeed = 0.015, accel = 0.06 },
	{ id = "exhaust", name = "Exhaust", desc = "Free-flow exhaust", base = 1500, maxSpeed = 0.01, accel = 0.02 },
	{ id = "ecu", name = "ECU", desc = "Engine map: top speed", base = 2000, maxSpeed = 0.02, accel = 0.01 },
	{ id = "transmission", name = "Transmission", desc = "Faster shifts: speed + acceleration", base = 2500, maxSpeed = 0.02, accel = 0.03 },
	{ id = "suspension", name = "Suspension", desc = "Cornering + stability", base = 2000, turn = 0.03, grip = 0.03 },
	{ id = "brakes", name = "Brakes", desc = "Stopping power", base = 1500, brake = 0.1 },
	{ id = "tires", name = "Tires", desc = "Grip", base = 2000, grip = 0.05, turn = 0.01 },
	{ id = "nitrous", name = "Nitrous", desc = "Boost power + tank size", base = 2500, nitro = 0.03, cap = 0.2 },
} :: { PartDef }

function Config.GetPart(id: string): PartDef?
	for _, p in Config.Parts do
		if p.id == id then
			return p
		end
	end
	return nil
end

export type Slider = { id: string, name: string, left: string, right: string, min: number, max: number, default: number }

Config.HandlingSliders = {
	{ id = "drift", name = "Handling", left = "DRIFT", right = "GRIP", min = -5, max = 5, default = 0 },
	{ id = "downforce", name = "Downforce", left = "LOW", right = "HIGH", min = 0, max = 5, default = 1 },
	{ id = "steering", name = "Steering", left = "SLOW", right = "FAST", min = -3, max = 3, default = 0 },
	{ id = "ride", name = "Ride Height", left = "LOW", right = "HIGH", min = -2, max = 2, default = 0 },
} :: { Slider }

Config.Visual = {
	rim = { "Classic 5-Spoke", "Sport 6-Spoke", "Mesh", "Deep Dish", "Turbine" },
	rimColor = {
		{ name = "Silver", color = Color3.fromRGB(200, 200, 210) },
		{ name = "Gunmetal", color = Color3.fromRGB(70, 72, 80) },
		{ name = "Black", color = Color3.fromRGB(25, 25, 28) },
		{ name = "Gold", color = Color3.fromRGB(215, 175, 60) },
		{ name = "Bronze", color = Color3.fromRGB(150, 100, 55) },
		{ name = "White", color = Color3.fromRGB(240, 240, 240) },
		{ name = "Neon Pink", color = Color3.fromRGB(255, 60, 170) },
	},
	tint = {
		{ name = "Clear", transparency = 0.65 },
		{ name = "Light", transparency = 0.45 },
		{ name = "Dark", transparency = 0.25 },
		{ name = "Limo", transparency = 0.1 },
	},
	spoiler = { "None", "Ducktail Lip", "Street Wing", "GT Wing" },
	kit = { "Stock", "Street Kit", "Widebody" },
	glow = {
		{ name = "Off", color = nil :: Color3? },
		{ name = "Effect Colour", color = nil :: Color3? },
		{ name = "Cyan", color = Color3.fromRGB(0, 240, 255) :: Color3? },
		{ name = "Pink", color = Color3.fromRGB(255, 40, 170) :: Color3? },
		{ name = "Purple", color = Color3.fromRGB(160, 60, 255) :: Color3? },
		{ name = "Green", color = Color3.fromRGB(60, 255, 100) :: Color3? },
		{ name = "Orange", color = Color3.fromRGB(255, 140, 20) :: Color3? },
	},
}
Config.VisualOrder = { "rim", "rimColor", "tint", "spoiler", "kit", "glow" }
Config.VisualNames = { rim = "Rims", rimColor = "Rim Colour", tint = "Window Tint", spoiler = "Spoiler", kit = "Body Kit", glow = "Underglow" }

export type Tune = {
	parts: { [string]: number },
	handling: { [string]: number },
	visual: { [string]: number },
}

function Config.DefaultTune(): Tune
	local parts = {}
	for _, p in Config.Parts do
		parts[p.id] = 0
	end
	local handling = {}
	for _, sl in Config.HandlingSliders do
		handling[sl.id] = sl.default
	end
	local visual = { rim = 1, rimColor = 1, tint = 2, spoiler = 1, kit = 1, glow = 2 }
	return { parts = parts, handling = handling, visual = visual }
end

-- Class multiplier for tuning prices
Config.ClassCostMult = { D = 1, C = 1.3, B = 1.7, A = 2.2, S = 3, ["S+"] = 3.5 }

function Config.PartCost(car: CarDef, part: PartDef, tier: number): number
	return math.floor(part.base * (Config.PartTierCost[tier] or 99) * (Config.ClassCostMult[car.class] or 1))
end

export type Stats = {
	maxSpeed: number,
	accel: number,
	brake: number,
	turn: number,
	grip: number,
	nitroMult: number,
	nitroCapacity: number,
	driftGrip: number,
	downforce: number,
	rating: number,
}

-- Performance rating like Unbound: C < 400, B 400+, A 500+, A+ 600+, S 700+, S+ 800+
function Config.RatingClass(rating: number): string
	if rating >= 800 then
		return "S+"
	elseif rating >= 700 then
		return "S"
	elseif rating >= 600 then
		return "A+"
	elseif rating >= 500 then
		return "A"
	elseif rating >= 400 then
		return "B"
	end
	return "C"
end

function Config.ComputeStats(car: CarDef, tune: Tune?): Stats
	local t = tune or Config.DefaultTune()
	local speedB, accelB, turnB, gripB, brakeB, nitroB, capB = 0, 0, 0, 0, 0, 0, 0
	for _, p in Config.Parts do
		local tier = (t.parts and t.parts[p.id]) or 0
		speedB += (p.maxSpeed or 0) * tier
		accelB += (p.accel or 0) * tier
		turnB += (p.turn or 0) * tier
		gripB += (p.grip or 0) * tier
		brakeB += (p.brake or 0) * tier
		nitroB += (p.nitro or 0) * tier
		capB += (p.cap or 0) * tier
	end
	local h: { [string]: number } = t.handling or {}
	local g = (h.drift or 0) / 5 -- -1 drift .. +1 grip
	local df = (h.downforce or 1) / 5
	local steer = h.steering or 0
	local ride = h.ride or 0

	local maxSpeed = car.maxSpeed * (1 + speedB) * (1 - 0.04 * df)
	local accel = car.accel * (1 + accelB)
	local turn = car.turn * (1 + turnB) * (1 - 0.06 * g) * (1 + 0.06 * steer)
	local grip = car.grip * (1 + gripB) * (1 + 0.18 * g) * (1 - 0.02 * ride)
	local brake = car.brake * (1 + brakeB)
	local rating = maxSpeed * 1.6 + accel * 2.5 + turn * grip * 4 + brake * 0.3
	return {
		maxSpeed = maxSpeed,
		accel = accel,
		brake = brake,
		turn = turn,
		grip = grip,
		nitroMult = car.nitroMult + nitroB,
		nitroCapacity = 1 + capB,
		driftGrip = 0.4 + 0.12 * g,
		downforce = df,
		rating = math.clamp(math.floor(rating), 100, 999),
	}
end

Config.PaintColors = {
	Color3.fromRGB(40, 170, 255),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(230, 60, 60),
	Color3.fromRGB(30, 30, 35),
	Color3.fromRGB(240, 240, 245),
	Color3.fromRGB(170, 60, 255),
	Color3.fromRGB(80, 255, 90),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(255, 150, 30),
	Color3.fromRGB(0, 230, 210),
}

-- Unbound-style driving effects: the trail/particle colours used while boosting.
Config.DrivingEffects = {
	{ id = "neon", name = "Neon Wings", price = 0, color = Color3.fromRGB(0, 255, 255) },
	{ id = "flame", name = "Flame Tag", price = 5000, color = Color3.fromRGB(255, 110, 20) },
	{ id = "toxic", name = "Toxic Spray", price = 8000, color = Color3.fromRGB(120, 255, 40) },
	{ id = "royal", name = "Royal Smoke", price = 12000, color = Color3.fromRGB(190, 70, 255) },
	{ id = "gold", name = "Gold Rush", price = 25000, color = Color3.fromRGB(255, 215, 0) },
}

function Config.GetEffect(id: string)
	for _, e in Config.DrivingEffects do
		if e.id == id then
			return e
		end
	end
	return Config.DrivingEffects[1]
end

---------------------------------------------------------------------------
-- Police / Heat (Most Wanted)
---------------------------------------------------------------------------
Config.Police = {
	BaseSpeed = 128,
	Accel = 50,
	Turn = 2.4,
	Grip = 6.5,
	PatrolCount = 4, -- roaming patrols across the whole city (daytime)
	NightExtraPatrols = 5, -- extra patrol cars out at night
	NightExtraCops = 2, -- extra units per pursuit at night
	NightSpawnMult = 0.65, -- pursuit reinforcements arrive faster at night
	SpeedLimit = 95, -- studs/s (~71 mph). Faster than this in front of a cop starts a pursuit.
	SpotRadius = 140,
	BustRadius = 22,
	BustSpeed = 14, -- player must be slower than this near a cop for the bust meter to fill
	BustTime = 3,
	CopHealth = 100,
	HeatPerMinute = 1.2, -- during a pursuit
	RoadblockInterval = 35,
}

export type HeatLevel = {
	maxCops: number,
	spawnInterval: number,
	speedMult: number,
	detectRadius: number,
	evadeTime: number,
	cooldownTime: number,
	roadblocks: boolean,
	heli: boolean,
	heavy: boolean,
	bountyPerSecond: number,
}

Config.HeatLevels = {
	{ maxCops = 2, spawnInterval = 7, speedMult = 1.0, detectRadius = 220, evadeTime = 5, cooldownTime = 18, roadblocks = false, heli = false, heavy = false, bountyPerSecond = 8 },
	{ maxCops = 3, spawnInterval = 6, speedMult = 1.08, detectRadius = 240, evadeTime = 6, cooldownTime = 22, roadblocks = false, heli = false, heavy = false, bountyPerSecond = 14 },
	{ maxCops = 4, spawnInterval = 5, speedMult = 1.16, detectRadius = 260, evadeTime = 7, cooldownTime = 26, roadblocks = true, heli = false, heavy = false, bountyPerSecond = 22 },
	{ maxCops = 5, spawnInterval = 4.5, speedMult = 1.26, detectRadius = 280, evadeTime = 8, cooldownTime = 30, roadblocks = true, heli = false, heavy = true, bountyPerSecond = 32 },
	{ maxCops = 6, spawnInterval = 4, speedMult = 1.36, detectRadius = 300, evadeTime = 9, cooldownTime = 35, roadblocks = true, heli = true, heavy = true, bountyPerSecond = 45 },
} :: { HeatLevel }

Config.Bounty = {
	CopWrecked = 750,
	RoadblockSmashed = 1000,
	PursuitBreaker = 1500,
}

---------------------------------------------------------------------------
-- Day / night (Unbound): night pays more and heat builds faster.
---------------------------------------------------------------------------
Config.DayLengthSeconds = 720 -- a full 24h cycle
Config.NightMultiplier = 1.5

function Config.IsNight(clockTime: number): boolean
	return clockTime < 6 or clockTime >= 18.5
end

---------------------------------------------------------------------------
-- Races. Routes are lists of intersections {i, j} (0..Blocks). Consecutive
-- points must share a row or a column so the route follows real roads.
---------------------------------------------------------------------------
export type RaceDef = {
	id: string,
	name: string,
	kind: string, -- "sprint" | "circuit" | "drift"
	route: { { number } },
	laps: number,
	buyIn: number,
	reward: number,
	heat: number, -- heat gained for finishing (Unbound)
	rivals: number,
	rivalSpeed: number,
	driftTarget: number?,
	duration: number?,
}

Config.Races = {
	{
		id = "downtown_dash",
		name = "Downtown Dash",
		kind = "sprint",
		route = { { 0, 0 }, { 0, 4 }, { 4, 4 }, { 4, 8 }, { 8, 8 } },
		laps = 1,
		buyIn = 500,
		reward = 3000,
		heat = 0.6,
		rivals = 3,
		rivalSpeed = 125,
	},
	{
		id = "neon_loop",
		name = "Neon Loop",
		kind = "circuit",
		route = { { 2, 2 }, { 2, 6 }, { 6, 6 }, { 6, 2 } },
		laps = 2,
		buyIn = 1500,
		reward = 7500,
		heat = 0.8,
		rivals = 3,
		rivalSpeed = 140,
	},
	{
		id = "harbor_run",
		name = "Harbor Run",
		kind = "sprint",
		route = { { 8, 0 }, { 5, 0 }, { 5, 3 }, { 1, 3 }, { 1, 7 }, { 3, 7 }, { 3, 8 } },
		laps = 1,
		buyIn = 3000,
		reward = 14000,
		heat = 1,
		rivals = 3,
		rivalSpeed = 155,
	},
	{
		id = "outer_ring",
		name = "Outer Ring",
		kind = "circuit",
		route = { { 0, 8 }, { 8, 8 }, { 8, 0 }, { 0, 0 } },
		laps = 2,
		buyIn = 6000,
		reward = 30000,
		heat = 1.2,
		rivals = 3,
		rivalSpeed = 175,
	},
	{
		id = "park_drift",
		name = "Park Side Drift",
		kind = "drift",
		route = { { 6, 3 } },
		laps = 1,
		buyIn = 800,
		reward = 5000,
		heat = 0.4,
		rivals = 0,
		rivalSpeed = 0,
		driftTarget = 25000,
		duration = 60,
	},
} :: { RaceDef }

function Config.GetRace(id: string): RaceDef?
	for _, r in Config.Races do
		if r.id == id then
			return r
		end
	end
	return nil
end

-- Payout fraction by finishing place (1st, 2nd, 3rd, 4th)
Config.PlacePayout = { 1, 0.4, 0.15, 0 }

---------------------------------------------------------------------------
-- Blacklist (Most Wanted). Beat them in order, from #5 up to #1.
---------------------------------------------------------------------------
export type Rival = {
	rank: number,
	name: string,
	bio: string,
	bountyReq: number,
	winsReq: number,
	carId: string,
	speed: number,
	reward: number,
	route: { { number } },
	laps: number,
}

Config.Blacklist = {
	{
		rank = 5,
		name = "Tiko",
		bio = "Drift kid who owns the park. Slides everywhere, rarely wins straight.",
		bountyReq = 1500,
		winsReq = 1,
		carId = "tiko_drifter",
		speed = 138,
		reward = 10000,
		route = { { 4, 4 }, { 4, 0 }, { 8, 0 }, { 8, 4 } },
		laps = 1,
	},
	{
		rank = 4,
		name = "Viper",
		bio = "Street hustler. Never lost a bet she set up herself.",
		bountyReq = 6000,
		winsReq = 3,
		carId = "viper_venom",
		speed = 158,
		reward = 25000,
		route = { { 0, 2 }, { 7, 2 }, { 7, 7 }, { 2, 7 }, { 2, 2 } },
		laps = 1,
	},
	{
		rank = 3,
		name = "Nova",
		bio = "Streams every race. Two million followers watching you lose.",
		bountyReq = 15000,
		winsReq = 5,
		carId = "nova_star",
		speed = 176,
		reward = 50000,
		route = { { 1, 1 }, { 1, 7 }, { 7, 7 }, { 7, 1 } },
		laps = 2,
	},
	{
		rank = 2,
		name = "Kingpin",
		bio = "Runs the underground betting scene. The cops are on his payroll.",
		bountyReq = 40000,
		winsReq = 8,
		carId = "kingpin_crown",
		speed = 190,
		reward = 90000,
		route = { { 0, 0 }, { 0, 8 }, { 8, 8 }, { 8, 0 } },
		laps = 2,
	},
	{
		rank = 1,
		name = "Ghost",
		bio = "Nobody has seen his face. Nobody has seen his taillights up close either.",
		bountyReq = 90000,
		winsReq = 12,
		carId = "ghost_zero",
		speed = 212,
		reward = 200000,
		route = { { 4, 0 }, { 4, 8 }, { 0, 8 }, { 0, 4 }, { 8, 4 }, { 8, 0 } },
		laps = 1,
	},
} :: { Rival }

function Config.GetRival(rank: number): Rival?
	for _, r in Config.Blacklist do
		if r.rank == rank then
			return r
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Misc world features
---------------------------------------------------------------------------
-- Speed cameras: {i, j, axis} placed mid-road. axis "x" = road runs along X.
Config.SpeedCameras = {
	{ i = 2, j = 4, axis = "x" },
	{ i = 6, j = 1, axis = "z" },
	{ i = 4, j = 7, axis = "x" },
	{ i = 0, j = 5, axis = "z" },
}
Config.SpeedCameraCashPerMph = 25

-- Pursuit breakers placed on block corners next to these intersections.
Config.PursuitBreakers = {
	{ 1, 2 },
	{ 3, 6 },
	{ 5, 5 },
	{ 7, 3 },
	{ 2, 4 },
	{ 6, 7 },
}

-- Ramps: mid-road jumps. {i, j, axis}
Config.Ramps = {
	{ i = 1, j = 5, axis = "x" },
	{ i = 7, j = 6, axis = "z" },
	{ i = 3, j = 2, axis = "z" },
	{ i = 5, j = 8, axis = "x" },
}

Config.StartingCash = 5000

return Config
