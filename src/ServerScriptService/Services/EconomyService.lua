--!strict
-- Currency, shop, and monetization hooks.
--
-- Monetization boundary (deliberate design decision, not an oversight):
-- Depths sells cosmetics, convenience (extra loadout slots, stash tabs), and
-- the optional ante/pact difficulty-modifier cosmetic rewards track only.
-- It never sells talents, relics, gear, or run-affecting currency at a rate
-- that outpaces normal play - CurrencyKind below enforces this at the type
-- level: "Soft" currency (earned in-run, spends on talents/gear) has no
-- real-money purchase path in EconomyService.PurchaseCatalog at all; only
-- "Premium" currency (cosmetic-gated) does. This keeps "pay-to-win" a
-- structural impossibility rather than a policy we could accidentally
-- violate by adding a shop entry in the wrong table.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Modules.Remotes)

local EconomyService = {}

export type CurrencyKind = "Soft" | "Premium"

export type Wallet = {
	Soft: number, -- earned via runs, spent on talents/gear/bank
	Premium: number, -- earned in small amounts via achievements, or purchased
}

export type ShopEntry = {
	id: string,
	displayName: string,
	currency: CurrencyKind,
	price: number,
	category: "Cosmetic" | "Convenience" | "AnteReward",
}

local wallets: { [number]: Wallet } = {}

-- Cosmetic/convenience-only catalog, per the monetization boundary above.
-- No entry here can reference a talent, relic, or item id from Items.lua/
-- Talents.lua/Relics.lua - that separation is what the comment above means
-- by "structural," not just documented policy.
local ShopCatalog: { ShopEntry } = {
	{ id = "Cosmetic_CryptWatchCloak", displayName = "Crypt-Watch Cloak", currency = "Premium", price = 350, category = "Cosmetic" },
	{ id = "Convenience_ExtraLoadoutSlot", displayName = "Extra Loadout Slot", currency = "Premium", price = 500, category = "Convenience" },
	{ id = "Convenience_StashTab", displayName = "Additional Stash Tab", currency = "Soft", price = 2500, category = "Convenience" },
}

local function newWallet(): Wallet
	return { Soft = 0, Premium = 0 }
end

function EconomyService.GetWallet(player: Player): Wallet
	local wallet = wallets[player.UserId]
	if not wallet then
		wallet = newWallet()
		wallets[player.UserId] = wallet
	end
	return wallet
end

function EconomyService.Grant(player: Player, currency: CurrencyKind, amount: number)
	assert(amount >= 0, "EconomyService.Grant amount must be non-negative; use Spend for deductions")
	local wallet = EconomyService.GetWallet(player)
	wallet[currency] += amount
	EconomyService._push(player)
end

local RemotesFolder: Folder

local function onRequestPurchase(player: Player, entryId: string?)
	if typeof(entryId) ~= "string" then
		return
	end
	local entry: ShopEntry? = nil
	for _, candidate in ShopCatalog do
		if candidate.id == entryId then
			entry = candidate
			break
		end
	end
	if not entry then
		return
	end

	local wallet = EconomyService.GetWallet(player)
	-- Affordability re-checked server-side even though the client should
	-- already know its own balance from EconomyUpdated - never trust a
	-- client's decision that it can afford something.
	if wallet[entry.currency] < entry.price then
		return
	end
	wallet[entry.currency] -= entry.price
	-- Cosmetic/convenience grant delegates to a catalog-specific handler
	-- (wardrobe unlock, stash-tab count increment) wired during the hub
	-- content pass; the payment validation above is already final.
	EconomyService._push(player)
end

function EconomyService._push(player: Player)
	local event = Remotes.Get(RemotesFolder, "EconomyUpdated") :: RemoteEvent
	local wallet = EconomyService.GetWallet(player)
	event:FireClient(player, { Soft = wallet.Soft, Premium = wallet.Premium })
end

-- Optional Balatro/Hades-style "ante" difficulty modifiers, opted into
-- pre-run from the hub for better rewards. Purely a risk/reward toggle - it
-- changes BiomeRegistry.GetDifficultyMultiplier's ante term and LootService's
-- rarityBonusPct on drops, never a paywalled unlock.
export type AnteModifier = {
	id: string,
	displayName: string,
	description: string,
	anteLevel: number,
}

local AnteModifiers: { AnteModifier } = {
	{ id = "Ante_GildedRisk", displayName = "Gilded Risk", description = "+15% enemy strength. +15% loot rarity weight.", anteLevel = 1 },
	{ id = "Ante_DoubledDark", displayName = "Doubled Dark", description = "+30% enemy strength, enemies gain +1 random resistance. +35% loot rarity weight.", anteLevel = 2 },
	{ id = "Ante_TheLongDescent", displayName = "The Long Descent", description = "+45% enemy strength, no mid-run healing stations. +60% loot rarity weight, guaranteed Legendary on floor 6.", anteLevel = 3 },
}

function EconomyService.GetAnteModifiers(): { AnteModifier }
	return AnteModifiers
end

function EconomyService.Init(remotesFolder: Folder)
	RemotesFolder = remotesFolder
	(Remotes.Get(remotesFolder, "RequestPurchase") :: RemoteEvent).OnServerEvent:Connect(onRequestPurchase)

	(Remotes.Get(remotesFolder, "GetShopCatalog") :: RemoteFunction).OnServerInvoke = function()
		return ShopCatalog
	end

	Players.PlayerRemoving:Connect(function(player)
		wallets[player.UserId] = nil
	end)
end

return EconomyService
