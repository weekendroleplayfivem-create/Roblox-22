--[[
	RemotesSetup
	Creates ReplicatedStorage.Remotes. Every other script reaches these with a
	blocking WaitForChild, so the order these top-level Scripts happen to run
	in doesn't matter.

	GameEvent is a single server -> client channel carrying a typed payload
	({ Type = "CoreUpdate", ... }) rather than a remote per notification. One
	channel keeps the client's subscription in one place and makes adding a new
	event a data change instead of a wiring change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

-- client -> server requests (all validated server-side, none trusted)
local EVENTS = {
	"PlaceTower",
	"SellTower",
	"UpgradeTower",
	"StartWave",
	"ChangeTargetMode",
	-- server -> client
	"GameEvent",
}

local FUNCTIONS = {
	"RequestSnapshot", -- late joiners / respawns pull current state once
}

for _, name in ipairs(EVENTS) do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
end

for _, name in ipairs(FUNCTIONS) do
	local func = Instance.new("RemoteFunction")
	func.Name = name
	func.Parent = remotes
end

print("[MIND TD] Remotes ready")
