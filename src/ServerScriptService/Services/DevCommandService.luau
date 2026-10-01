--[[
	DevCommandService
	Developer/testing commands. Only available:
	  * in Roblox Studio, or
	  * in a private server, for UserIds in DevConfig.AuthorizedUserIds.
	Never available in public live servers. Commands come from the in-game
	dev console (F2 in Studio) via the DevCommand RemoteFunction, or from chat
	messages starting with DevConfig.CommandPrefix (e.g. "/vr bots 4 Hard").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local DevConfig = require(Shared.Config.DevConfig)
local WeaponConfig = require(Shared.Config.WeaponConfig)
local MatchConfig = require(Shared.Config.MatchConfig)
local MapConfig = require(Shared.Config.MapConfig)
local BotConfig = require(Shared.Config.BotConfig)

local DevCommandService = {}

local Services

function DevCommandService:IsAuthorized(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	local isPrivateServer = game.PrivateServerId ~= ""
	return isPrivateServer and table.find(DevConfig.AuthorizedUserIds, player.UserId) ~= nil
end

local Commands = {}

Commands.help = {
	Usage = "help",
	Run = function()
		local lines = {}
		for name, command in Commands do
			table.insert(lines, command.Usage or name)
		end
		table.sort(lines)
		return true, table.concat(lines, "\n")
	end,
}

Commands.give = {
	Usage = "give <WeaponId>   (e.g. give PlasmaLauncher)",
	Run = function(player, args)
		local weaponId = args[1]
		local weapon = weaponId and WeaponConfig.Get(weaponId)
		if not weapon then
			return false, "Unknown weapon. Options: " .. table.concat(WeaponConfig.Order, ", ")
		end
		local combatant = Services.CombatantService:GetByPlayer(player)
		local state = Services.WeaponService:GetState(combatant)
		local slots = if state then table.clone(state.Slots) else {}
		slots[weapon.Slot] = weaponId
		Services.WeaponService:GiveLoadout(combatant, slots, false)
		Services.WeaponService:Equip(combatant, weapon.Slot)
		Services.WeaponService:SendState(combatant)
		return true, "Gave " .. weapon.DisplayName
	end,
}

Commands.health = {
	Usage = "health <amount>",
	Run = function(player, args)
		local amount = tonumber(args[1])
		local combatant = Services.CombatantService:GetByPlayer(player)
		if not amount or not combatant or not combatant.Humanoid then
			return false, "Usage: health <amount>"
		end
		combatant.Humanoid.Health = math.clamp(amount, 1, combatant.Humanoid.MaxHealth)
		return true, "Health set to " .. combatant.Humanoid.Health
	end,
}

Commands.startmatch = {
	Usage = "startmatch [TeamDeathmatch|FreeForAll|GunGame] [NeonDistrict|SkyLab|CoreStation]",
	Run = function(player, args)
		local mode = args[1] or "TeamDeathmatch"
		if not MatchConfig.Modes[mode] then
			return false, "Unknown mode"
		end
		local mapId = args[2]
		if mapId and not MapConfig.Get(mapId) then
			return false, "Unknown map"
		end
		if Services.MatchService:GetMatch() then
			return false, "A match is already running (use endmatch)"
		end
		local players = {}
		for _, other in Players:GetPlayers() do
			if other:GetAttribute("Location") == "Lobby" then
				table.insert(players, other)
			end
		end
		task.spawn(Services.MatchService.StartMatch, Services.MatchService, mode, players, mapId)
		return true, "Starting " .. mode
	end,
}

Commands.endmatch = {
	Usage = "endmatch",
	Run = function()
		Services.MatchService:ForceEnd()
		return true, "Match ended"
	end,
}

Commands.resetround = {
	Usage = "resetround  (restart the current match with the same players)",
	Run = function()
		local match = Services.MatchService:GetMatch()
		if not match then
			return false, "No match running"
		end
		local mode, mapId = match.ModeId, match.MapId
		local players = {}
		for combatant in match.Participants do
			if combatant.Player then
				table.insert(players, combatant.Player)
			end
		end
		Services.MatchService:Cleanup()
		task.delay(1, function()
			Services.MatchService:StartMatch(mode, players, mapId)
		end)
		return true, "Round reset"
	end,
}

Commands.tp = {
	Usage = "tp <x> <y> <z> | tp <playerName>",
	Run = function(player, args)
		local character = player.Character
		if not character then
			return false, "No character"
		end
		local target: CFrame? = nil
		if #args >= 3 then
			local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
			if x and y and z then
				target = CFrame.new(x, y, z)
			end
		elseif args[1] then
			for _, other in Players:GetPlayers() do
				if string.lower(other.Name):sub(1, #args[1]) == string.lower(args[1]) and other.Character then
					target = other.Character:GetPivot() * CFrame.new(0, 0, 5)
				end
			end
		end
		if not target then
			return false, "Usage: tp <x> <y> <z> | tp <playerName>"
		end
		character:PivotTo(target)
		Services.AntiCheatService:ResetBaseline(player, target.Position, 1)
		return true, "Teleported"
	end,
}

Commands.bots = {
	Usage = "bots <count> [Easy|Normal|Hard]  (adds bots to the running match)",
	Run = function(_player, args)
		local count = math.clamp(tonumber(args[1]) or 2, 1, BotConfig.MaxBots)
		local difficulty = args[2] or "Normal"
		if not BotConfig.Difficulties[difficulty] then
			return false, "Difficulty must be Easy, Normal or Hard"
		end
		local match = Services.MatchService:GetMatch()
		if not match then
			return false, "Start a match first (startmatch)"
		end
		for _, bot in Services.BotService:CreateBots(count, difficulty) do
			Services.CombatantService:ResetMatchState(bot)
			bot.InMatch = true
			match.Participants[bot] = true
			Services.CombatantService:SetTeam(bot, match.Rules.PickTeam(match))
			Services.AbilityService:ApplyLoadout(bot)
			task.spawn(Services.MatchService.SpawnParticipant, Services.MatchService, bot)
		end
		return true, string.format("Added %d %s bots", count, difficulty)
	end,
}

Commands.xp = {
	Usage = "xp <amount>",
	Run = function(player, args)
		local amount = tonumber(args[1]) or 500
		Services.ProgressionService:AddXP(player, amount, "Dev")
		return true, "Added XP"
	end,
}

Commands.credits = {
	Usage = "credits <amount>",
	Run = function(player, args)
		Services.ProgressionService:AddCredits(player, tonumber(args[1]) or 1000)
		return true, "Added credits"
	end,
}

Commands.god = {
	Usage = "god  (toggle long spawn protection)",
	Run = function(player)
		local combatant = Services.CombatantService:GetByPlayer(player)
		if combatant.SpawnProtectedUntil > os.clock() + 60 then
			combatant.SpawnProtectedUntil = 0
			return true, "God mode off"
		end
		combatant.SpawnProtectedUntil = os.clock() + 100000
		return true, "God mode on (firing turns it off)"
	end,
}

Commands.runtests = {
	Usage = "runtests",
	Run = function()
		local runner = require(ServerScriptService:WaitForChild("Tests"):WaitForChild("TestRunner"))
		local passed, failed, report = runner.Run(Services)
		return failed == 0, string.format("%d passed, %d failed\n%s", passed, failed, report)
	end,
}

function DevCommandService:Execute(player: Player, text: string): (boolean, string)
	if not DevCommandService:IsAuthorized(player) then
		return false, "Not available"
	end
	if type(text) ~= "string" or #text > 200 then
		return false, "Invalid command"
	end
	local args = string.split(text, " ")
	for index = #args, 1, -1 do
		if args[index] == "" then
			table.remove(args, index)
		end
	end
	local name = table.remove(args, 1)
	local command = name and Commands[string.lower(name)]
	if not command then
		return false, "Unknown command. Type 'help'."
	end
	local ok, success, message = pcall(command.Run, player, args)
	if not ok then
		return false, "Error: " .. tostring(success)
	end
	print(string.format("[DevCommand] %s ran '%s': %s", player.Name, text, tostring(message)))
	return success, message
end

function DevCommandService:Init(services)
	Services = services
	Net.OnServerInvoke("UI", "DevCommand", function(player, text)
		return DevCommandService:Execute(player, text)
	end, { Rate = 3, Burst = 6 })
end

function DevCommandService:Start()
	local prefix = DevConfig.CommandPrefix .. " "
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, #prefix) == prefix and DevCommandService:IsAuthorized(player) then
				local ok, result = DevCommandService:Execute(player, string.sub(message, #prefix + 1))
				Net.Event("UI", "Notify"):FireClient(player, { Text = result, Kind = if ok then "Info" else "Warning", Duration = 5 })
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

DevCommandService.Commands = Commands

return DevCommandService
