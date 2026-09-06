--[[
	EconomyManager
	Server-owned currency. The client is never told "you have N" as anything
	but a display value — every spend goes through TrySpend here, which is the
	only thing that can decrease a balance.

	Money is per-player (you spend your own), but the defence is shared, so
	wave rewards are paid to everyone rather than split.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")

local EconomyManager = {}

EconomyManager.StartingMoney = 1000

local balances: { [Player]: number } = {}
local earnedThisRun: { [Player]: number } = {}

local function push(player: Player)
	GameEvent:FireClient(player, {
		Type = "EconomyUpdate",
		Money = balances[player] or 0,
	})
end

function EconomyManager.Register(player: Player)
	balances[player] = EconomyManager.StartingMoney
	earnedThisRun[player] = 0
	push(player)
end

function EconomyManager.Unregister(player: Player)
	balances[player] = nil
	earnedThisRun[player] = nil
end

function EconomyManager.Get(player: Player): number
	return balances[player] or 0
end

function EconomyManager.CanAfford(player: Player, amount: number): boolean
	return (balances[player] or 0) >= amount
end

-- The single spend path. Returns false and changes nothing if the player
-- cannot afford it, so callers can treat a false as "reject the request".
function EconomyManager.TrySpend(player: Player, amount: number): boolean
	if amount < 0 then
		return false
	end
	local balance = balances[player]
	if not balance or balance < amount then
		return false
	end
	balances[player] = balance - amount
	push(player)
	return true
end

function EconomyManager.Award(player: Player, amount: number)
	if not balances[player] or amount <= 0 then
		return
	end
	balances[player] += amount
	earnedThisRun[player] += amount
	push(player)
end

-- Shared income: kills and wave clears pay the whole team, since the defence
-- is a joint effort and splitting it just punishes bigger lobbies.
function EconomyManager.AwardAll(amount: number)
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyManager.Award(player, amount)
	end
end

function EconomyManager.ResetAll()
	for _, player in ipairs(Players:GetPlayers()) do
		balances[player] = EconomyManager.StartingMoney
		earnedThisRun[player] = 0
		push(player)
	end
end

function EconomyManager.GetEarned(player: Player): number
	return earnedThisRun[player] or 0
end

return EconomyManager
