--[[
	ClientState
	Small client-side store for data the server sends us (profile, match
	state, queue, scoreboard ...). Controllers read from here and listen to
	`Changed` instead of each wiring their own remotes.

	Everything here is a *copy* of server state used for display/prediction.
	Changing it never changes anything on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Modules.Signal)
local Net = require(Shared.Modules.Net)
local SettingsConfig = require(Shared.Config.SettingsConfig)

local ClientState = {}

ClientState.Changed = Signal.new() -- (key, value)
ClientState._pendingSettings = nil :: { [string]: any }?
ClientState._saveScheduled = false

local values: { [string]: any } = {
	Profile = nil,
	TemporaryProfile = false,
	Settings = SettingsConfig.GetDefaults(),
	MatchState = { Phase = "Lobby" },
	QueueState = nil,
	Scoreboard = {},
	Location = "Loading",
}

function ClientState.Get(key: string): any
	return values[key]
end

function ClientState.Set(key: string, value: any)
	values[key] = value
	ClientState.Changed:Fire(key, value)
end

-- Fires `callback(value)` now and whenever `key` changes. Returns the connection.
function ClientState.Observe(key: string, callback: (any) -> ())
	task.spawn(callback, values[key])
	return ClientState.Changed:Connect(function(changedKey, value)
		if changedKey == key then
			callback(value)
		end
	end)
end

function ClientState.GetSetting(key: string): any
	local settings = values.Settings
	if settings[key] ~= nil then
		return settings[key]
	end
	local entry = SettingsConfig.GetEntry(key)
	return entry and entry.Default
end

-- Applies a setting locally right away and asks the server to save it.
function ClientState.SetSetting(key: string, value: any)
	local clean = SettingsConfig.SanitizeValue(key, value)
	if clean == nil then
		return
	end
	local settings = table.clone(values.Settings)
	settings[key] = clean
	ClientState.Set("Settings", settings)
	ClientState._pendingSettings = ClientState._pendingSettings or {}
	ClientState._pendingSettings[key] = clean
	-- Batch saves so dragging a slider doesn't spam the server.
	if not ClientState._saveScheduled then
		ClientState._saveScheduled = true
		task.delay(1, function()
			ClientState._saveScheduled = false
			local pending = ClientState._pendingSettings
			ClientState._pendingSettings = nil
			if pending then
				Net.Event("UI", "UpdateSettings"):FireServer(pending)
			end
		end)
	end
end

function ClientState.IsInMatch(): boolean
	return values.Location == "Match"
end

function ClientState:Init()
	local player = Players.LocalPlayer

	Net.Event("UI", "DataSync").OnClientEvent:Connect(function(data, temporary)
		ClientState.Set("TemporaryProfile", temporary == true)
		ClientState.Set("Profile", data)
		if not ClientState._pendingSettings and type(data) == "table" and data.Settings then
			ClientState.Set("Settings", SettingsConfig.Sanitize(data.Settings))
		end
	end)
	Net.Event("Match", "MatchState").OnClientEvent:Connect(function(state)
		ClientState.Set("MatchState", state)
	end)
	Net.Event("Match", "QueueState").OnClientEvent:Connect(function(state)
		ClientState.Set("QueueState", state)
	end)
	Net.Event("Match", "Scoreboard").OnClientEvent:Connect(function(entries)
		ClientState.Set("Scoreboard", entries)
	end)

	local function updateLocation()
		ClientState.Set("Location", player:GetAttribute("Location") or "Loading")
	end
	player:GetAttributeChangedSignal("Location"):Connect(updateLocation)
	updateLocation()
end

function ClientState:Start()
	task.spawn(function()
		local ok, data, temporary = pcall(function()
			return Net.Function("UI", "RequestData"):InvokeServer()
		end)
		if ok and data then
			ClientState.Set("TemporaryProfile", temporary == true)
			ClientState.Set("Profile", data)
			ClientState.Set("Settings", SettingsConfig.Sanitize(data.Settings))
		end
	end)
end

return ClientState
