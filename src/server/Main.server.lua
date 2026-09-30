--!strict
-- WANTED: UNBOUND - server entry point.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))

local DayNight = require(script.Parent.DayNight)
local MapBuilder = require(script.Parent.MapBuilder)
local PlayerData = require(script.Parent.PlayerData)
local Session = require(script.Parent.Session)
local Vehicles = require(script.Parent.Vehicles)
local Police = require(script.Parent.Police)
local Traffic = require(script.Parent.Traffic)
local Showroom = require(script.Parent.Showroom)
local Weapons = require(script.Parent.Weapons)
local Races = require(script.Parent.Races)
local Leaderboard = require(script.Parent.Leaderboard)

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(className: string, name: string): Instance
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
remote("RemoteEvent", "Notify")
remote("RemoteEvent", "Banner")
remote("RemoteEvent", "RaceResult")
remote("RemoteEvent", "DailyReward")
local nearMissEvent = remote("RemoteEvent", "NearMiss") :: RemoteEvent
local nitroEvent = remote("RemoteEvent", "NitroState") :: RemoteEvent
local raceEvent = remote("RemoteEvent", "RequestRace") :: RemoteEvent
local respawnEvent = remote("RemoteEvent", "RespawnCar") :: RemoteEvent
local rivalEvent = remote("RemoteEvent", "ChallengeRival") :: RemoteEvent
local garageEvent = remote("RemoteEvent", "Garage") :: RemoteEvent
local settingsEvent = remote("RemoteEvent", "SaveSettings") :: RemoteEvent
local fireEvent = remote("RemoteEvent", "FireWeapon") :: RemoteEvent
local codeFunction = remote("RemoteFunction", "RedeemCode") :: RemoteFunction
local collectedEvent = remote("RemoteEvent", "Collected") :: RemoteEvent
local exitGarage: (s: Session.Session, respawn: boolean) -> ()
local quitEvent = remote("RemoteEvent", "QuitRace") :: RemoteEvent
local shopFunction = remote("RemoteFunction", "Shop") :: RemoteFunction
remotes.Parent = ReplicatedStorage
Session.SetRemotes(remotes)

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------
local mapInfo = MapBuilder.Build()
Vehicles.SetSpawns(mapInfo.safehouseSpawns)
Police.Init(mapInfo)
Traffic.Init()
Showroom.Build(workspace:WaitForChild("Map"))
Leaderboard.Init(mapInfo.safehouse, workspace:WaitForChild("Map"))
Police.SetBustedCallback(function(s)
	Races.Cancel(s)
end)

Players.CharacterAutoLoads = true
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Anchored = true
spawnLocation.Transparency = 1
spawnLocation.CanCollide = false
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.CFrame = CFrame.new(mapInfo.safehouse + Vector3.new(0, 4, 40))
spawnLocation.Neutral = true
spawnLocation.Duration = 0
spawnLocation.Parent = workspace

-- Realistic day / night lighting (sky, clouds, colour grading, street lamps)
DayNight.Init(mapInfo.nightLights, mapInfo.nightNeon, mapInfo.nightToggles)

-- weather: rain showers every few minutes
task.spawn(function()
	workspace:SetAttribute("Raining", false)
	while true do
		task.wait(math.random(240, 480))
		if math.random() < 0.45 then
			workspace:SetAttribute("Raining", true)
			for _, s in Session.All() do
				Session.Notify(s.player, "It's starting to rain - roads are slippery", Color3.fromRGB(150, 190, 255))
			end
			task.wait(math.random(120, 240))
			workspace:SetAttribute("Raining", false)
		end
	end
end)

-- day / night cycle
task.spawn(function()
	local wasNight = Config.IsNight(Lighting.ClockTime)
	while true do
		task.wait(0.5)
		local night = Config.IsNight(Lighting.ClockTime)
		if night ~= wasNight then
			wasNight = night
			for _, s in Session.All() do
				if night then
					Session.Notify(s.player, "NIGHT HAS FALLEN - x" .. Config.NightMultiplier .. " payouts, but more cops are out on patrol", Color3.fromRGB(170, 120, 255))
				else
					Session.Notify(s.player, "Sunrise - fewer cops, payouts back to normal", Color3.fromRGB(255, 220, 120))
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local function makeLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in { "Cash", "Bounty", "Heat" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player
end

local function onCharacter(s: Session.Session, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	task.wait(0.3)
	if s.car and s.car.Parent then
		Vehicles.SeatCharacter(s)
	else
		Vehicles.Spawn(s, Vehicles.NextSafehouseSpawn())
	end
end

local function onPlayerAdded(player: Player)
	local profile = PlayerData.Load(player)
	if not player.Parent then
		return
	end
	local s = Session.Create(player, profile)
	makeLeaderstats(player)
	Session.Sync(s)
	player.CharacterAdded:Connect(function(character)
		onCharacter(s, character)
	end)
	if player.Character then
		task.spawn(onCharacter, s, player.Character)
	end
	Session.Notify(player, "Welcome to " .. Config.GameName .. "!  Race, raise your heat, escape the cops and climb the Blacklist.", Color3.fromRGB(0, 255, 220))

	-- daily reward (UTC days); a missed day resets the streak
	local today = math.floor(os.time() / 86400)
	if profile.dailyDay ~= today then
		local streak = if profile.dailyDay == today - 1 then profile.dailyStreak + 1 else 1
		profile.dailyDay = today
		profile.dailyStreak = streak
		local rewards = Config.DailyRewards
		local amount = rewards[math.min(streak, #rewards)]
		profile.cash += amount
		Session.AddRep(s, Config.DailyRep, nil)
		Session.Sync(s)
		task.delay(4, function()
			if player.Parent then
				Session.Fire(player, "DailyReward", { day = streak, amount = amount, rep = Config.DailyRep, rewards = rewards })
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local s = Session.Get(player)
	if s then
		Races.Cancel(s)
		Police.Cleanup(s)
		if s.car then
			s.car:Destroy()
		end
		Session.Remove(player)
	end
	pcall(function()
		Leaderboard.Submit(player)
	end)
	PlayerData.Release(player)
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		PlayerData.Save(p)
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, p in Players:GetPlayers() do
			PlayerData.Save(p)
		end
	end
end)

---------------------------------------------------------------------------
-- Remote handlers
---------------------------------------------------------------------------
local lastRespawn: { [Player]: number } = {}
respawnEvent.OnServerEvent:Connect(function(player)
	local s = Session.Get(player)
	if not s or os.clock() - (lastRespawn[player] or 0) < 3 then
		return
	end
	lastRespawn[player] = os.clock()
	if s.car and s.car.Parent then
		Vehicles.ResetToRoad(s)
	else
		Vehicles.Spawn(s, Vehicles.NextSafehouseSpawn())
	end
end)

nitroEvent.OnServerEvent:Connect(function(player, on)
	local s = Session.Get(player)
	if not s or not s.car or type(on) ~= "boolean" then
		return
	end
	for _, d in s.car:GetDescendants() do
		if d.Name == "NitroFlame" and d:IsA("ParticleEmitter") then
			d.Enabled = on
		elseif d.Name == "EffectTrail" and d:IsA("Trail") then
			d.Enabled = on
		end
	end
end)

raceEvent.OnServerEvent:Connect(function(player, raceId)
	local s = Session.Get(player)
	if not s or type(raceId) ~= "string" then
		return
	end
	local def = Config.GetRace(raceId)
	local pos = Session.CarPosition(s)
	if not def or not pos then
		return
	end
	local first = def.route[1]
	local start = Grid.Intersection(first[1], first[2])
	if (pos - start).Magnitude > 60 then
		Session.Notify(player, "Drive to the race start marker first", Color3.fromRGB(255, 90, 90))
		return
	end
	local ok, msg = Races.Start(s, def, nil)
	if not ok then
		Session.Notify(player, msg, Color3.fromRGB(255, 90, 90))
	end
end)

quitEvent.OnServerEvent:Connect(function(player)
	local s = Session.Get(player)
	if s and s.race then
		Races.Cancel(s)
	end
end)

---------------------------------------------------------------------------
-- Weapons and codes
---------------------------------------------------------------------------
fireEvent.OnServerEvent:Connect(function(player)
	local s = Session.Get(player)
	if s then
		Weapons.Fire(s)
	end
end)

codeFunction.OnServerInvoke = function(player, code)
	local s = Session.Get(player)
	if not s or type(code) ~= "string" then
		return false, "Try again in a moment"
	end
	local key = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[key]
	if not reward then
		return false, "Invalid code"
	end
	local p = s.profile
	if p.redeemed[key] then
		return false, "You already redeemed this code"
	end
	p.redeemed[key] = true
	if reward.cash then
		p.cash += reward.cash
	end
	if reward.car and Config.GetCar(reward.car) then
		p.owned[reward.car] = true
	end
	if reward.weapon and Config.GetWeapon(reward.weapon) then
		p.weapons[reward.weapon] = true
	end
	if reward.rep then
		Session.AddRep(s, reward.rep)
	end
	Session.Sync(s)
	PlayerData.Save(player)
	Session.Banner(player, "CODE REDEEMED", reward.message, Color3.fromRGB(0, 255, 200))
	return true, reward.message
end

---------------------------------------------------------------------------
-- Garage: press E at the safehouse to drive inside the workshop
---------------------------------------------------------------------------
exitGarage = function(s: Session.Session, respawn: boolean)
	if not s.inGarage then
		return
	end
	s.inGarage = false
	s.player:SetAttribute("InGarage", false)
	if respawn then
		Vehicles.Spawn(s, Vehicles.NextSafehouseSpawn())
		Vehicles.Freeze(s, 0.5)
	end
end

local SETTING_TYPES: { [string]: string } = { shake = "boolean", speedLines = "boolean", blur = "boolean", units = "string", volume = "number", performance = "boolean" }
settingsEvent.OnServerEvent:Connect(function(player, values)
	local s = Session.Get(player)
	if not s or type(values) ~= "table" then
		return
	end
	local clean: { [string]: any } = {}
	for k, t in SETTING_TYPES do
		local v = values[k]
		if type(v) == t then
			if k == "volume" then
				v = math.clamp(v, 0, 1)
			elseif k == "units" and v ~= "mph" and v ~= "kmh" then
				v = "mph"
			end
			clean[k] = v
		end
	end
	s.profile.settings = clean
end)

garageEvent.OnServerEvent:Connect(function(player, action)
	local s = Session.Get(player)
	if not s then
		return
	end
	if action == "enter" then
		if s.inGarage then
			return
		end
		if not s.atSafehouse or s.mode ~= "idle" or s.race then
			Session.Notify(player, "Drive to the safehouse (without cops on you) to enter the garage", Color3.fromRGB(255, 90, 90))
			return
		end
		s.inGarage = true
		Vehicles.Spawn(s)
		player:SetAttribute("InGarage", true)
	elseif action == "exit" then
		exitGarage(s, true)
	end
end)

rivalEvent.OnServerEvent:Connect(function(player, rank)
	local s = Session.Get(player)
	if not s or type(rank) ~= "number" then
		return
	end
	local rival = Config.GetRival(rank)
	if not rival then
		return
	end
	local nextRank = 5 - s.profile.blacklistBeaten
	if rank ~= nextRank then
		Session.Notify(player, "Beat Blacklist #" .. nextRank .. " first", Color3.fromRGB(255, 90, 90))
		return
	end
	if s.profile.totalBounty < rival.bountyReq or s.profile.racesWon < rival.winsReq then
		Session.Notify(player, "You need $" .. rival.bountyReq .. " total bounty and " .. rival.winsReq .. " race wins", Color3.fromRGB(255, 90, 90))
		return
	end
	if not s.atSafehouse then
		Session.Notify(player, "Challenge the Blacklist from the safehouse", Color3.fromRGB(255, 90, 90))
		return
	end
	exitGarage(s, false)
	local ok, msg = Races.Start(s, Races.RivalDef(rival), rival)
	if not ok then
		Session.Notify(player, msg, Color3.fromRGB(255, 90, 90))
	end
end)

-- Near misses are detected on the driver's client (it owns the car physics); the server
-- checks the claim against the traffic car's position and rate-limits it.
local lastNearMiss: { [Player]: number } = {}
nearMissEvent.OnServerEvent:Connect(function(player, civ)
	local s = Session.Get(player)
	if not s or typeof(civ) ~= "Instance" or not civ:IsA("Model") or civ.Parent ~= Traffic.Folder then
		return
	end
	local now = os.clock()
	if now - (lastNearMiss[player] or 0) < 0.6 then
		return
	end
	local pos = Session.CarPosition(s)
	local civRoot = (civ :: Model).PrimaryPart
	if not pos or not civRoot or (civRoot.Position - pos).Magnitude > 40 then
		return
	end
	lastNearMiss[player] = now
	Session.AddStat(s, "nearMisses", 1)
	Session.AddRep(s, 15)
	if s.race and s.race.def.kind == "takeover" then
		s.race.driftScore += 600
	end
	s.unbanked += Config.Traffic.NearMissCash * Session.NightMult()
end)

local function snapshot(s: Session.Session)
	local p = s.profile
	return {
		cash = p.cash,
		owned = p.owned,
		selected = p.selected,
		tuning = p.tuning,
		paint = p.paint,
		effects = p.effects,
		effect = p.effect,
		totalBounty = p.totalBounty,
		racesWon = p.racesWon,
		blacklistBeaten = p.blacklistBeaten,
		stats = p.stats,
		milestones = p.milestones,
		settings = p.settings,
		weapons = p.weapons,
		weapon = p.weapon,
		collected = p.collected,
		rep = p.rep,
	}
end

shopFunction.OnServerInvoke = function(player, action, a, b)
	local s = Session.Get(player)
	if not s then
		return false, "Not ready", nil
	end
	local p = s.profile
	if action == "Get" then
		return true, "", snapshot(s)
	end
	-- Black Market: roof weapons
	if action == "BuyWeapon" or action == "EquipWeapon" then
		if not s.atBlackMarket or s.mode ~= "idle" or s.race then
			return false, "Weapons are sold at the Black Market (red B on the map) - lose the cops first", snapshot(s)
		end
		if type(a) ~= "string" then
			return false, "Bad request", snapshot(s)
		end
		if action == "EquipWeapon" and a == "" then
			p.weapon = ""
			Vehicles.Spawn(s)
			Session.Sync(s)
			return true, "Weapon removed", snapshot(s)
		end
		local w = Config.GetWeapon(a)
		if not w then
			return false, "Unknown weapon", snapshot(s)
		end
		if action == "BuyWeapon" then
			if p.weapons[a] then
				return false, "Already owned", snapshot(s)
			end
			if p.cash < w.price then
				return false, "Not enough cash", snapshot(s)
			end
			p.cash -= w.price
			p.weapons[a] = true
		elseif not p.weapons[a] then
			return false, "Buy it first", snapshot(s)
		end
		p.weapon = a
		Vehicles.Spawn(s)
		Session.Sync(s)
		return true, w.name .. " mounted - press F to fire", snapshot(s)
	end
	if not s.atSafehouse or s.mode ~= "idle" or s.race then
		return false, "Garage is only available at the safehouse (and without cops on you)", snapshot(s)
	end
	local msg = ""
	if action == "BuyCar" and type(a) == "string" then
		local car = Config.GetCar(a)
		if not car or car.blacklistOnly then
			return false, "Not for sale", snapshot(s)
		end
		if p.owned[a] then
			return false, "Already owned", snapshot(s)
		end
		if p.cash < car.price then
			return false, "Not enough cash", snapshot(s)
		end
		p.cash -= car.price
		p.owned[a] = true
		p.selected = a
		Vehicles.Spawn(s, Vehicles.NextSafehouseSpawn())
		msg = "Bought " .. car.name .. "!"
	elseif action == "SelectCar" and type(a) == "string" then
		if not p.owned[a] then
			return false, "You don't own that car", snapshot(s)
		end
		p.selected = a
		Vehicles.Spawn(s, Vehicles.NextSafehouseSpawn())
		msg = "Switched car"
	elseif action == "Part" and type(a) == "string" then
		-- performance part: buy the next tier
		local car = Config.GetCar(p.selected)
		local part = Config.GetPart(a)
		if not car or not part then
			return false, "Unknown part", snapshot(s)
		end
		local tune = PlayerData.Tune(p, car.id)
		local cur = tune.parts[part.id] or 0
		if cur >= #Config.PartTiers - 1 then
			return false, part.name .. " is maxed out", snapshot(s)
		end
		local cost = Config.PartCost(car, part, cur + 1)
		if p.cash < cost then
			return false, "Not enough cash", snapshot(s)
		end
		p.cash -= cost
		tune.parts[part.id] = cur + 1
		Vehicles.ApplyStats(s)
		msg = part.name .. " upgraded to " .. Config.PartTiers[cur + 2]
	elseif action == "Handling" and type(a) == "string" and type(b) == "number" then
		local slider
		for _, sl in Config.HandlingSliders do
			if sl.id == a then
				slider = sl
			end
		end
		if not slider then
			return false, "Unknown setting", snapshot(s)
		end
		local tune = PlayerData.Tune(p, p.selected)
		local value = math.clamp(math.round(b), slider.min, slider.max)
		tune.handling[a] = value
		if a == "ride" then
			Vehicles.Spawn(s)
		else
			Vehicles.ApplyStats(s)
		end
		msg = slider.name .. " set"
	elseif action == "Visual" and type(a) == "string" and type(b) == "number" then
		local options = (Config.Visual :: any)[a]
		if not options or not options[b] then
			return false, "Unknown option", snapshot(s)
		end
		local tune = PlayerData.Tune(p, p.selected)
		tune.visual[a] = b
		Vehicles.Spawn(s)
		msg = (Config.VisualNames :: any)[a] .. " changed"
	elseif action == "Paint" and type(a) == "number" then
		if not Config.PaintColors[a] then
			return false, "Bad colour", snapshot(s)
		end
		p.paint[p.selected] = a
		Vehicles.Spawn(s)
		msg = "Fresh paint!"
	elseif action == "Effect" and type(a) == "string" then
		local effect = Config.GetEffect(a)
		if effect.id ~= a then
			return false, "Unknown effect", snapshot(s)
		end
		if not p.effects[a] then
			if p.cash < effect.price then
				return false, "Not enough cash", snapshot(s)
			end
			p.cash -= effect.price
			p.effects[a] = true
		end
		p.effect = a
		Vehicles.Spawn(s)
		msg = "Driving effect: " .. effect.name
	else
		return false, "Unknown action", snapshot(s)
	end
	Session.Sync(s)
	return true, msg, snapshot(s)
end

---------------------------------------------------------------------------
-- World loop: safehouse banking, drift combos, speed cameras, races, sync
---------------------------------------------------------------------------
local worldTick: (s: Session.Session, dt: number) -> ()
task.spawn(function()
	while true do
		local dt = task.wait(0.1)
		for _, s in Session.All() do
			-- one player's error must never stop the loop for everyone
			local ok, err = pcall(function()
				worldTick(s, dt)
			end)
			if not ok then
				warn("[World] tick error:", err)
			end
		end
	end
end)

worldTick = function(s: Session.Session, dt: number)
	do
			local car = s.car
			local root = car and car.PrimaryPart
			if not car or not root or not car.Parent then
				Session.Sync(s)
				return
			end
			local pos = root.Position
			local vel = root.AssemblyLinearVelocity
			local speed = vel.Magnitude

			-- fell out of the world (the garage interior is underground on purpose)
			if pos.Y < -40 and not s.inGarage then
				Vehicles.ResetToRoad(s)
				return
			end

			-- make sure the driver is seated
			local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat?
			if seat and not seat.Occupant and s.player.Character then
				Vehicles.SeatCharacter(s)
			end

			-- Black Market zone
			s.atBlackMarket = not s.inGarage and (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(mapInfo.blackMarket.X, 0, mapInfo.blackMarket.Z)).Magnitude < 60

			-- street art collectibles
			for _, art in mapInfo.collectibles do
				if not s.profile.collected[art.id] and (Vector3.new(pos.X, art.position.Y, pos.Z) - art.position).Magnitude < 24 then
					s.profile.collected[art.id] = true
					local count = 0
					for _ in s.profile.collected do
						count += 1
					end
					s.profile.cash += Config.CollectibleCash
					collectedEvent:FireClient(s.player, art.id)
					Session.Banner(s.player, "STREET ART " .. count .. " / " .. #mapInfo.collectibles, "+$" .. Config.CollectibleCash .. " banked", Color3.fromRGB(140, 255, 60))
					Session.AddRep(s, 100)
					Session.AddStat(s, "art", 1)
				end
			end

			-- safehouse: bank unbanked cash and clear heat (Unbound)
			local flat = Vector3.new(pos.X - mapInfo.safehouse.X, 0, pos.Z - mapInfo.safehouse.Z)
			s.atSafehouse = s.inGarage or flat.Magnitude < 70
			if s.atSafehouse and s.mode == "idle" and not s.race then
				if s.unbanked > 0 then
					local amount = math.floor(s.unbanked)
					s.profile.cash += amount
					s.unbanked = 0
					Session.Notify(s.player, "BANKED $" .. amount .. " at the safehouse", Color3.fromRGB(80, 255, 140))
					task.spawn(PlayerData.Save, s.player) -- DataStore calls yield: never inside the loop
				end
				if s.heat > 0 then
					s.heat = 0
					Session.Notify(s.player, "You laid low. Heat cleared.", Color3.fromRGB(120, 200, 255))
				end
			end

			-- drift combo (computed from the replicated velocity)
			local right = root.CFrame.RightVector
			local lateral = math.abs(vel:Dot(right))
			local driftGain = 0
			if lateral > 12 and speed > 38 then
				driftGain = lateral * dt * 12 * (1 + speed / 150)
				s.driftCombo += driftGain
				s.driftIdle = 0
			else
				s.driftIdle += dt
				if s.driftIdle > 1.2 and s.driftCombo > 0 then
					local combo = s.driftCombo
					Session.MaxStat(s, "bestDrift", math.floor(combo))
					Session.AddRep(s, combo / 100)
					s.driftCombo = 0
					if combo > 400 and not s.race then
						Session.AddUnbanked(s, combo / 25 * Session.NightMult(), "DRIFT x" .. math.floor(combo))
					end
				end
			end

			-- speed cameras
			for idx, cam in mapInfo.speedCams do
				if (Vector3.new(pos.X, cam.Y, pos.Z) - cam).Magnitude < 34 and os.clock() > (s.camCooldown[idx] or 0) then
					s.camCooldown[idx] = os.clock() + 20
					local mph = math.floor(speed * Config.MphPerStud)
					Session.MaxStat(s, "bestSpeedCam", mph)
					if mph > 60 then
						Session.AddUnbanked(s, (mph - 60) * Config.SpeedCameraCashPerMph * Session.NightMult(), "SPEED CAMERA " .. mph .. " MPH")
						if s.mode ~= "idle" then
							s.heat = math.min(5, s.heat + 0.25)
						end
					end
				end
			end

			if s.race then
				local ok, err = pcall(function()
					Races.Update(s, driftGain)
				end)
				if not ok then
					warn("[Races] update error:", err)
				end
			end
			Session.Sync(s)
	end
end

print("[" .. Config.GameName .. "] server ready")
