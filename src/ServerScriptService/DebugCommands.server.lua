--[[
	DebugCommands
	Developer-only chat commands for testing (brief section 43). Gated to the
	game's creator plus an explicit allowlist — never exposed to normal
	players. Not wired to any RemoteEvent, so a client can't invoke it directly.
]]

local Players = game:GetService("Players")

local InventoryService = require(script.Parent.InventoryService)
local XPService = require(script.Parent.XPService)
local MatchManager = require(script.Parent.MatchManager)
local MapGenerator = require(script.Parent.MapGenerator)
local WeaponData = require(game:GetService("ReplicatedStorage").Shared.WeaponData)

-- Add trusted developer UserIds here for testing outside of Studio.
local DEV_USERIDS = {}

local function isDeveloper(player)
	if player.UserId == game.CreatorId then
		return true
	end
	for _, id in ipairs(DEV_USERIDS) do
		if id == player.UserId then
			return true
		end
	end
	return false
end

local COMMANDS = {}

COMMANDS.startmatch = function(_player)
	MatchManager.StartNewMatch()
end

COMMANDS.endmatch = function(_player)
	MatchManager.EndMatch(nil, nil)
end

COMMANDS.resetmatch = function(_player)
	MatchManager.StartNewMatch()
end

COMMANDS.giveweapon = function(player, args)
	local weaponId = args[1]
	if weaponId and WeaponData.Get(weaponId) then
		InventoryService.GrantWeapon(player, weaponId)
	end
end

COMMANDS.givexp = function(player, args)
	local amount = tonumber(args[1]) or 100
	XPService.Award(player, amount, "Debug")
end

COMMANDS.spawndummy = function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	MapGenerator.SpawnDummy(root.CFrame * CFrame.new(0, 0, -10))
end

local function onChatted(player, message)
	if not isDeveloper(player) then
		return
	end
	if message:sub(1, 1) ~= "/" then
		return
	end

	local parts = {}
	for word in message:sub(2):gmatch("%S+") do
		table.insert(parts, word)
	end
	local commandName = table.remove(parts, 1)
	if not commandName then
		return
	end

	local handler = COMMANDS[commandName:lower()]
	if handler then
		local ok, err = pcall(handler, player, parts)
		if not ok then
			warn("[DebugCommands] Error running", commandName, err)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end)
