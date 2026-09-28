# dv-inventory · Dayverse Roleplay

Inventory in dezelfde oranje stijl als `dv-hud`, `dv-admin` en `dv-reports`, gemaakt voor **ESX** (`Config.Framework = 'esx'`).

**ESX blijft de baas.** Je items, wapens (loadout), contant en zwart geld komen uit `xPlayer`, en alles wat je in de inventory doet wordt via ESX uitgevoerd (`addInventoryItem`, `removeInventoryItem`, `addWeapon`, `removeWeapon`, `addAccountMoney`, ...). Daardoor blijven winkels, banen, `esx_basicneeds`, ambulance enz. gewoon werken, zonder iets om te bouwen.

- Items met een ESX-gebruik (`ESX.RegisterUsableItem`, bv. bread/water) worden via `ESX.UseItem` gebruikt.
- Items die niet in ESX bruikbaar zijn maar wel een effect in `Config.Items` hebben (verband, EHBO, vest, ...) gebruiken dat effect.
- Items met `can_remove = 0` kun je niet weggeven of weggooien.
- Kofferbak, dashboardkastje, grond en stashes bewaart dv-inventory zelf in `data/inventories.json`.
- Importeer `esx_items.sql` voor de extra items. ESX-gewicht: 1 eenheid = 1 kg (`Config.Esx.WeightUnit`).
- Zet `ox_inventory` of een ander inventory-script uit; de F2-inventory van ESX mag blijven.

## Installatie

1. Zet de map `dv-inventory` in je resources, bv. `resources/[scripts]/[main]/[inventory]/dv-inventory`.
2. Importeer `esx_items.sql` in je database.
3. In `server.cfg` (of `dayverse.cfg`): `ensure dv-inventory` **na** `ensure es_extended`.
4. Zorg dat de server mag schrijven in `data/`.

## Gebruik

| Toets / commando | Wat |
| --- | --- |
| **I** | Inventory openen (in een voertuig: dashboardkastje, achter een auto: kofferbak, bij spullen op de grond: grond) |
| **1-5** | Hotbar: item in vakje 1 t/m 5 gebruiken of wapen pakken/wegstoppen |
| Slepen | Verplaatsen, stapelen of wisselen |
| Shift + slepen | Halve stapel |
| Aantal-veld | Precies zoveel verplaatsen / geven / weggooien |
| Dubbelklik | Gebruiken |
| Rechtsklik | Gebruiken, geven, splitsen, weggooien |
| Sleep naar *Geven* | Geven aan de dichtstbijzijnde speler |
| `/giveitem <id> <item> [aantal]` | Admin: item geven |
| `/clearinv <id>` | Admin: inventory leegmaken |

Admin-commando's werken voor iedereen met `dvadmin.admin` (zelfde rang als in `dv-admin`).

## Wat zit erin

- 30 vakjes en 30 kg per speler, gewicht en stapels per item
- Kofferbak (per kenteken, 100 kg), dashboardkastje (5 vakjes), spullen op de grond (met tasje en marker, verdwijnen na 30 min), stashes
- Eten, drinken, verband, EHBO, vest, sigaret met animatie en voortgangsbalk
- Wapens als item: pakken en wegstoppen via hotbar; wapen verdwijnt uit je hand als je het item weggeeft of weggooit
- Munitie gebruik je met het juiste wapen in je hand
- Reparatieset repareert het voertuig naast je
- Meldingen bij items erbij/eraf, hotbar-weergave bij 1-5
- Honger/dorst/stress gaan naar QBCore (metadata) of ESX (`esx_status`); `dv-hud` toont ze meteen
- QBCore/ESX: inventory per karakter (citizenid / identifier); standalone: per license
- Alles wordt op de server gecontroleerd: afstand, gewicht, ruimte, toegang; spam-bescherming

## Items toevoegen

In `config.lua` onder `Config.Items`, bijvoorbeeld:

```lua
pizza = { label = 'Pizza', icon = '🍕', weight = 600, stack = true, usable = true, consume = true, close = true, anim = 'eat', effects = { hunger = 60 }, desc = 'Een hele pizza.' },
```

Het icoon is een emoji; je kunt elke emoji gebruiken.

## Voor andere scripts (server)

```lua
local inv = exports['dv-inventory']

inv:AddItem(source, 'water', 2)                 -- true/false
inv:RemoveItem(source, 'water', 1)
inv:HasItem(source, 'lockpick')                 -- true/false
inv:GetItemCount(source, 'water')
inv:CanCarry(source, 'armor', 1)
inv:GetInventory(source)                        -- lijst met { slot, name, count, meta }

-- stash openen (bv. vanuit een politie-script)
inv:OpenStash(source, 'politie_kluis', 'Politie kluis', 50, 200000)

-- eigen gebruik van een item
inv:RegisterUsable('lockpick', function(src, item, slot)
    -- jouw code; verwijder zelf het item als dat moet
end)

-- elk gebruikt item
AddEventHandler('dv-inventory:server:itemUsed', function(src, name, slot) end)
```

## Voorbeeld bekijken

Open `html/index.html` in je browser voor een demo (slepen, rechtsklik en tooltips werken).
