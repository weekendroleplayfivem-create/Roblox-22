--!strict
-- Player settings, saved in the player's profile on the server.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SaveSettings = Remotes:WaitForChild("SaveSettings") :: RemoteEvent

local Settings = {}

export type Values = {
	shake: boolean,
	speedLines: boolean,
	blur: boolean,
	units: string, -- "mph" | "kmh"
	volume: number, -- 0..1
	performance: boolean,
}

Settings.Values = {
	shake = true,
	speedLines = true,
	blur = true,
	units = "mph",
	volume = 0.8,
	performance = false,
} :: Values

-- every sound in the game plays through this group so the volume setting affects all of it
Settings.Master = Instance.new("SoundGroup")
Settings.Master.Name = "WU_Master"
Settings.Master.Parent = SoundService

local listeners: { () -> () } = {}
function Settings.OnChanged(fn: () -> ())
	table.insert(listeners, fn)
end

local function apply()
	local v = Settings.Values
	Settings.Master.Volume = v.volume
	-- performance mode: drop the expensive post effects and shadows on this device only
	for _, e in Lighting:GetChildren() do
		if e:IsA("DepthOfFieldEffect") or e:IsA("SunRaysEffect") then
			e.Enabled = not v.performance
		elseif e:IsA("BloomEffect") then
			e.Enabled = not v.performance
		end
	end
	Lighting.GlobalShadows = not v.performance
	for _, fn in listeners do
		task.spawn(fn)
	end
end

local saveToken = 0
function Settings.Set(key: string, value: any)
	(Settings.Values :: any)[key] = value
	apply()
	saveToken += 1
	local token = saveToken
	task.delay(1, function()
		if token == saveToken then
			SaveSettings:FireServer(Settings.Values)
		end
	end)
end

function Settings.Load(saved: any)
	if type(saved) == "table" then
		for k, default in Settings.Values :: any do
			if type(saved[k]) == type(default) then
				(Settings.Values :: any)[k] = saved[k]
			end
		end
	end
	apply()
end

-- speed in the chosen units
function Settings.Speed(studsPerSecond: number, mphPerStud: number): (number, string)
	local mph = studsPerSecond * mphPerStud
	if Settings.Values.units == "kmh" then
		return mph * 1.609, "KM/H"
	end
	return mph, "MPH"
end

-- Lighting effects are created by the server a moment after joining; re-apply once they exist.
Lighting.ChildAdded:Connect(function()
	task.defer(apply)
end)

return Settings
