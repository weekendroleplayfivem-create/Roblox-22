--[[
	RemotesSetup
	Creates every RemoteEvent/RemoteFunction the game uses under
	ReplicatedStorage.Remotes. This runs first (Script priority via name)
	so every other server and client script can just index the folder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local EVENTS = {
	-- Weapons
	"FireWeapon",
	"ReloadWeapon",
	"SwitchWeapon",
	"WeaponFired", -- server -> all clients, cosmetic replication (tracer/muzzle/sound)
	"HitConfirmed", -- server -> shooter, hitmarker feedback
	"WeaponEquipped",

	-- Damage / combat
	"RequestDamage",
	"PlayerEliminated", -- server -> clients, kill feed + killstreak
	"PlayerDamaged", -- server -> victim, HUD damage flash

	-- Scooter
	"ScooterAction", -- client -> server: {Type = "Jump"/"DriftStart"/"DriftEnd"}
	"Boost", -- client -> server: request boost start
	"BoostStateChanged", -- server -> owner, authoritative boost meter/state

	-- Loadout / inventory
	"ChangeLoadout",
	"EquipCosmetic",
	"InventoryUpdated", -- server -> owner, full inventory snapshot
	"UpdateSettings",

	-- Match flow
	"MatchStateChanged", -- server -> all: {State, TimeLeft, Mode, Scores}
	"RespawnCountdown",
	"XPGained",
	"LevelUp",

	-- UI / misc
	"PlayClicked",
	"NotifyClient", -- generic small toast: {Title, Text}
}

local FUNCTIONS = {
	"RequestPlayerProfile",
	"RequestJoinMatch",
	"RequestShopCatalog",
}

for _, name in ipairs(EVENTS) do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotesFolder
end

for _, name in ipairs(FUNCTIONS) do
	local func = Instance.new("RemoteFunction")
	func.Name = name
	func.Parent = remotesFolder
end

print("[HyperBlast] Remotes initialized (" .. #EVENTS .. " events, " .. #FUNCTIONS .. " functions)")
