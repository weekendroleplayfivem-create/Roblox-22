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
local Races = require(script.Parent.Races)

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
local nearMissEvent = remote("RemoteEvent", "NearMiss") :: RemoteEvent
local nitroEvent = remote("RemoteEvent", "NitroState") :: RemoteEvent
local raceEvent = remote("RemoteEvent", "RequestRace") :: RemoteEvent
local respawnEvent = remote("RemoteEvent", "RespawnCar") :: RemoteEvent
local rivalEvent = remote("RemoteEvent", "ChallengeRival") :: RemoteEvent
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
DayNight.Init(mapInfo.nightLights, mapInfo.nightNeon)

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
task.spawn(function()
	while true do
		local dt = task.wait(0.1)
		for _, s in Session.All() do
			local car = s.car
			local root = car and car.PrimaryPart
			if not car or not root or not car.Parent then
				Session.Sync(s)
				continue
			end
			local pos = root.Position
			local vel = root.AssemblyLinearVelocity
			local speed = vel.Magnitude

			-- fell out of the world
			if pos.Y < -40 then
				Vehicles.ResetToRoad(s)
				continue
			end

			-- make sure the driver is seated
			local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat?
			if seat and not seat.Occupant and s.player.Character then
				Vehicles.SeatCharacter(s)
			end

			-- safehouse: bank unbanked cash and clear heat (Unbound)
			local flat = Vector3.new(pos.X - mapInfo.safehouse.X, 0, pos.Z - mapInfo.safehouse.Z)
			s.atSafehouse = flat.Magnitude < 70
			if s.atSafehouse and s.mode == "idle" and not s.race then
				if s.unbanked > 0 then
					local amount = math.floor(s.unbanked)
					s.profile.cash += amount
					s.unbanked = 0
					Session.Notify(s.player, "BANKED $" .. amount .. " at the safehouse", Color3.fromRGB(80, 255, 140))
					PlayerData.Save(s.player)
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
end)

print("[" .. Config.GameName .. "] server ready")
