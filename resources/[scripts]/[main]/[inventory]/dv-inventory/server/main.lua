-- ============================================================
--  dv-inventory  |  server
--  De server is de baas: elke verplaatsing wordt hier gecontroleerd.
-- ============================================================

local RES = GetCurrentResourceName()
local Items = Config.Items

local Invs = {}            -- [invId] = inventory (in geheugen)
local saved = json.decode(LoadResourceFile(RES, 'data/inventories.json') or '{}') or {}
local dirty = {}           -- [invId] = true -> moet opgeslagen worden
local playerInv = {}       -- [src] = invId
local openWith = {}        -- [src] = invId van het tweede venster
local drops = {}           -- [dropId] = { coords, created }
local nextDrop = 1
local Usable = {}          -- [itemName] = function(src, item, slot)
local rate = {}

local QBCore, ESX
CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

-- ------------------------------------------------------------
--  Helpers
-- ------------------------------------------------------------

local function isOnline(id) return id and GetPlayerName(id) ~= nil end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

local function stackMax(name)
    local d = Items[name]
    if not d or not d.stack then return 1 end
    return d.max or 100
end

local function weightOf(inv)
    local w = 0
    for _, it in pairs(inv.items) do
        local d = Items[it.name]
        if d then w = w + (d.weight or 0) * it.count end
    end
    return w
end

--- Lijst voor verzenden/opslaan (JSON kan niet goed met 'gaten' in een tabel).
local function toList(inv)
    local list = {}
    for slot, it in pairs(inv.items) do
        list[#list + 1] = { slot = slot, name = it.name, count = it.count, meta = it.meta }
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return list
end

local function fromList(list, slots)
    local items = {}
    for _, it in ipairs(list or {}) do
        local slot = tonumber(it.slot)
        if slot and slot >= 1 and slot <= slots and Items[it.name] and (tonumber(it.count) or 0) > 0 then
            items[slot] = { name = it.name, count = math.floor(tonumber(it.count)), meta = it.meta or {} }
        end
    end
    return items
end

local function payload(inv)
    if not inv then return nil end
    return {
        id = inv.id,
        type = inv.type,
        label = inv.label,
        slots = inv.slots,
        maxWeight = inv.maxWeight,
        weight = weightOf(inv),
        items = toList(inv),
    }
end

-- ------------------------------------------------------------
--  Opslaan
-- ------------------------------------------------------------

local function markDirty(inv)
    if inv.persist then dirty[inv.id] = true end
end

local function saveAll()
    local any = false
    for id in pairs(dirty) do
        local inv = Invs[id]
        if inv then saved[id] = toList(inv) end
        any = true
    end
    dirty = {}
    if any then SaveResourceFile(RES, 'data/inventories.json', json.encode(saved), -1) end
end

CreateThread(function()
    while true do
        Wait(30000)
        saveAll()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == RES then saveAll() end
end)

local function getInv(id, opts)
    local inv = Invs[id]
    if inv then return inv end
    inv = {
        id = id,
        type = opts.type,
        label = opts.label,
        slots = opts.slots,
        maxWeight = opts.maxWeight,
        persist = opts.persist ~= false,
        owner = opts.owner,
    }
    inv.items = inv.persist and fromList(saved[id], inv.slots) or {}
    Invs[id] = inv
    return inv
end

-- ------------------------------------------------------------
--  Spelers
-- ------------------------------------------------------------

local function playerKey(src)
    if QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        return p and ('player:' .. p.PlayerData.citizenid) or nil
    elseif ESX then
        local p = ESX.GetPlayerFromId(src)
        return p and ('player:' .. p.identifier) or nil
    end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return 'player:' .. id:sub(9) end
    end
end

local addItem  -- vooruit gedeclareerd

local function loadPlayer(src)
    local id = playerInv[src]
    if id and Invs[id] then return Invs[id] end
    local key = playerKey(src)
    if not key then return nil end
    local isNew = saved[key] == nil
    local inv = getInv(key, {
        type = 'player', label = GetPlayerName(src) or 'Speler',
        slots = Config.PlayerSlots, maxWeight = Config.PlayerWeight, owner = src,
    })
    inv.owner = src
    playerInv[src] = key
    if isNew then
        for _, s in ipairs(Config.StartItems) do addItem(inv, s.name, s.count) end
        markDirty(inv)
    end
    return inv
end

local function unloadPlayer(src)
    local id = playerInv[src]
    if id and Invs[id] then
        saved[id] = toList(Invs[id])
        dirty[id] = true
        saveAll()
        Invs[id] = nil
    end
    playerInv[src] = nil
    openWith[src] = nil
end

AddEventHandler('playerDropped', function()
    unloadPlayer(source)
    rate[source] = nil
end)

-- Wisselen van karakter (QBCore / ESX)
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function() unloadPlayer(source) end)
AddEventHandler('esx:playerDropped', function(src) unloadPlayer(src) end)

-- ------------------------------------------------------------
--  Kern: toevoegen, verwijderen, tellen
-- ------------------------------------------------------------

--- Past `count` van `name` erin? (gewicht en vakjes)
local function canAdd(inv, name, count)
    local d = Items[name]
    if not d then return false, 'Onbekend item' end
    if weightOf(inv) + (d.weight or 0) * count > inv.maxWeight then return false, 'Te zwaar' end
    local max, room = stackMax(name), 0
    for slot = 1, inv.slots do
        local it = inv.items[slot]
        if not it then
            room = room + max
        elseif d.stack and it.name == name then
            room = room + math.max(0, max - it.count)
        end
        if room >= count then return true end
    end
    return false, 'Geen ruimte'
end

addItem = function(inv, name, count, meta)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return false, 'Ongeldig aantal' end
    local ok, err = canAdd(inv, name, count)
    if not ok then return false, err end
    local d, max, left = Items[name], stackMax(name), count
    if d.stack then
        for slot = 1, inv.slots do
            local it = inv.items[slot]
            if it and it.name == name and it.count < max then
                local add = math.min(max - it.count, left)
                it.count = it.count + add
                left = left - add
                if left == 0 then break end
            end
        end
    end
    for slot = 1, inv.slots do
        if left == 0 then break end
        if not inv.items[slot] then
            local add = math.min(max, left)
            inv.items[slot] = { name = name, count = add, meta = copy(meta) or {} }
            left = left - add
        end
    end
    markDirty(inv)
    return true
end

local function countItem(inv, name)
    local n = 0
    for _, it in pairs(inv.items) do if it.name == name then n = n + it.count end end
    return n
end

local function removeItem(inv, name, count, slot)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 or countItem(inv, name) < count then return false end
    local left = count
    local function take(s)
        local it = inv.items[s]
        if it and it.name == name and left > 0 then
            local n = math.min(it.count, left)
            it.count = it.count - n
            left = left - n
            if it.count <= 0 then inv.items[s] = nil end
        end
    end
    if slot then take(slot) end
    for s = 1, inv.slots do take(s) end
    markDirty(inv)
    return true
end

-- ------------------------------------------------------------
--  Synchroniseren naar clients
-- ------------------------------------------------------------

local function sync(inv)
    if inv.type == 'player' and inv.owner and isOnline(inv.owner) then
        TriggerClientEvent('dv-inventory:client:update', inv.owner, { player = payload(inv) })
    end
    for src, id in pairs(openWith) do
        if id == inv.id then
            TriggerClientEvent('dv-inventory:client:update', src, { secondary = payload(inv) })
        end
    end
end

local function itembox(src, name, delta)
    if isOnline(src) then TriggerClientEvent('dv-inventory:client:itembox', src, name, delta) end
end

local function broadcastDrops()
    local list = {}
    for id, d in pairs(drops) do list[#list + 1] = { id = id, x = d.coords.x, y = d.coords.y, z = d.coords.z } end
    TriggerClientEvent('dv-inventory:client:drops', -1, list)
end

local function removeDropIfEmpty(inv)
    if inv.type ~= 'drop' or next(inv.items) then return end
    drops[inv.id] = nil
    Invs[inv.id] = nil
    for src, id in pairs(openWith) do
        if id == inv.id then
            openWith[src] = nil
            TriggerClientEvent('dv-inventory:client:update', src, { secondary = false })
        end
    end
    broadcastDrops()
end

local function newDrop(coords)
    local id = 'drop:' .. nextDrop
    nextDrop = nextDrop + 1
    drops[id] = { coords = coords, created = os.time() }
    getInv(id, { type = 'drop', label = 'Grond', slots = Config.DropSlots, maxWeight = 1e9, persist = false })
    return id
end

-- opruimen van oude drops
CreateThread(function()
    while true do
        Wait(60000)
        local changed = false
        for id, d in pairs(drops) do
            if os.time() - d.created > Config.DropDespawnMinutes * 60 then
                drops[id] = nil
                Invs[id] = nil
                changed = true
            end
        end
        if changed then broadcastDrops() end
    end
end)

-- ------------------------------------------------------------
--  Toegang tot een inventory
-- ------------------------------------------------------------

local function access(src, id)
    if not id then return nil end
    if id == playerInv[src] then return Invs[id] end
    if id == openWith[src] then return Invs[id] end
    return nil
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

--- Bepaalt welk tweede venster de speler mag openen (en controleert afstand).
local function openSecondary(src, req)
    local myCoords = coordsOf(src)
    if type(req) ~= 'table' or not myCoords then return nil end

    if req.kind == 'glovebox' or req.kind == 'trunk' then
        local veh = NetworkGetEntityFromNetworkId(tonumber(req.net) or 0)
        if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
        local plate = trim(GetVehicleNumberPlateText(veh))
        if plate == '' then return nil end
        if req.kind == 'glovebox' then
            if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= veh then return nil end
            return getInv('glovebox:' .. plate, { type = 'glovebox', label = 'Dashboardkastje · ' .. plate, slots = Config.GloveboxSlots, maxWeight = Config.GloveboxWeight })
        end
        if #(GetEntityCoords(veh) - myCoords) > Config.TrunkDistance + 3.0 then return nil end
        if GetVehicleDoorLockStatus(veh) > 1 then return 'locked' end
        return getInv('trunk:' .. plate, { type = 'trunk', label = 'Kofferbak · ' .. plate, slots = Config.TrunkSlots, maxWeight = Config.TrunkWeight })
    end

    if req.kind == 'drop' then
        local d = drops[req.id]
        if d and #(d.coords - myCoords) <= Config.DropDistance + 1.0 then return Invs[req.id] end
    end
    return nil
end

-- ------------------------------------------------------------
--  Acties
-- ------------------------------------------------------------

local Actions = {}

Actions.open = function(src, d)
    local inv = loadPlayer(src)
    if not inv then return { ok = false, msg = 'Je karakter is nog niet geladen' } end
    local sec = openSecondary(src, d)
    if sec == 'locked' then
        sec = nil
        TriggerClientEvent('dv-inventory:client:notify', src, 'De kofferbak zit op slot', 'error')
    end
    openWith[src] = sec and sec.id or nil
    return { ok = true, player = payload(inv), secondary = sec and payload(sec) or nil }
end

Actions.close = function(src)
    openWith[src] = nil
    return { ok = true }
end

Actions.get = function(src)
    local inv = loadPlayer(src)
    return { ok = inv ~= nil, player = payload(inv) }
end

Actions.move = function(src, d)
    local from = access(src, d.from)
    local toId = d.to
    if toId == 'ground' then
        -- slepen naar "Grond": maak een nieuwe drop onder de speler
        if not from or from.type ~= 'player' then return { ok = false, msg = 'Kan niet' } end
        local c = coordsOf(src)
        if not c then return { ok = false } end
        toId = newDrop(vector3(c.x, c.y, c.z - 0.95))
        openWith[src] = toId
    end
    local to = access(src, toId)
    if not from or not to then return { ok = false, msg = 'Geen toegang' } end

    local fromSlot, toSlot = tonumber(d.fromSlot), tonumber(d.toSlot)
    local it = fromSlot and from.items[fromSlot]
    if not it then return { ok = false, msg = 'Leeg vakje' } end
    if not toSlot or toSlot < 1 or toSlot > to.slots then
        -- geen specifiek vakje: eerste vrije plek
        toSlot = nil
        for s = 1, to.slots do if not to.items[s] then toSlot = s break end end
        if not toSlot then return { ok = false, msg = 'Geen ruimte' } end
    end
    if from == to and fromSlot == toSlot then return { ok = true } end

    local count = math.floor(tonumber(d.count) or 0)
    if count <= 0 or count > it.count then count = it.count end

    local def = Items[it.name]
    local dest = to.items[toSlot]
    local w = (def.weight or 0)

    if not dest then
        if from ~= to and weightOf(to) + w * count > to.maxWeight then return { ok = false, msg = 'Te zwaar' } end
        to.items[toSlot] = { name = it.name, count = count, meta = copy(it.meta) }
        it.count = it.count - count
        if it.count <= 0 then from.items[fromSlot] = nil end
    elseif dest.name == it.name and def.stack then
        local n = math.min(stackMax(it.name) - dest.count, count)
        if n <= 0 then return { ok = false, msg = 'Stapel is vol' } end
        if from ~= to and weightOf(to) + w * n > to.maxWeight then return { ok = false, msg = 'Te zwaar' } end
        dest.count = dest.count + n
        it.count = it.count - n
        if it.count <= 0 then from.items[fromSlot] = nil end
    else
        if count < it.count then return { ok = false, msg = 'Kan niet wisselen met een deel van een stapel' } end
        if from ~= to then
            local dw = (Items[dest.name].weight or 0) * dest.count
            local iw = w * it.count
            if weightOf(to) - dw + iw > to.maxWeight then return { ok = false, msg = 'Te zwaar' } end
            if weightOf(from) - iw + dw > from.maxWeight then return { ok = false, msg = 'Te zwaar' } end
        end
        from.items[fromSlot], to.items[toSlot] = dest, it
    end

    markDirty(from)
    markDirty(to)
    sync(from)
    if to ~= from then sync(to) end
    removeDropIfEmpty(from)
    if to.type == 'drop' then broadcastDrops() end
    return { ok = true }
end

Actions.give = function(src, d)
    local inv = loadPlayer(src)
    local target = tonumber(d.target)
    if not inv or not isOnline(target) or target == src then return { ok = false, msg = 'Geen speler in de buurt' } end
    local a, b = coordsOf(src), coordsOf(target)
    if not a or not b or #(a - b) > Config.GiveDistance + 1.0 then return { ok = false, msg = 'Speler is te ver weg' } end
    local tinv = loadPlayer(target)
    if not tinv then return { ok = false, msg = 'Speler is nog niet geladen' } end

    local slot = tonumber(d.slot)
    local it = slot and inv.items[slot]
    if not it then return { ok = false, msg = 'Leeg vakje' } end
    local count = math.floor(tonumber(d.count) or 0)
    if count <= 0 or count > it.count then count = it.count end

    local ok, err = canAdd(tinv, it.name, count)
    if not ok then return { ok = false, msg = 'De ander kan dit niet dragen (' .. err .. ')' } end
    local name, meta = it.name, copy(it.meta)
    removeItem(inv, name, count, slot)
    addItem(tinv, name, count, meta)
    sync(inv)
    sync(tinv)
    itembox(src, name, -count)
    itembox(target, name, count)
    TriggerClientEvent('dv-inventory:client:giveAnim', src)
    return { ok = true, msg = ('Je gaf %dx %s'):format(count, Items[name].label) }
end

Actions.use = function(src, d)
    local inv = loadPlayer(src)
    local slot = tonumber(d.slot)
    local it = inv and slot and inv.items[slot]
    if not it then return { ok = false } end
    local def = Items[it.name]

    if Usable[it.name] then
        local ok, err = pcall(Usable[it.name], src, { name = it.name, count = it.count, meta = copy(it.meta), slot = slot }, slot)
        if not ok then print('[dv-inventory] fout in usable ' .. it.name .. ': ' .. tostring(err)) end
        TriggerEvent('dv-inventory:server:itemUsed', src, it.name, slot)
        return { ok = true, close = def.close }
    end
    if not def.usable then return { ok = false, msg = def.label .. ' kun je niet gebruiken' } end

    if def.weapon then
        TriggerClientEvent('dv-inventory:client:weapon', src, slot, it.name, def.weapon)
        return { ok = true, close = def.close }
    end
    if def.ammo or def.action then
        -- de client controleert (wapen in hand, voertuig in de buurt) en bevestigt met 'consume'
        TriggerClientEvent('dv-inventory:client:special', src, slot, it.name, def.ammo, def.action)
        return { ok = true, close = def.close }
    end

    if def.consume then
        removeItem(inv, it.name, 1, slot)
        sync(inv)
        itembox(src, it.name, -1)
    end

    local eff = def.effects or {}
    TriggerClientEvent('dv-inventory:client:effect', src, it.name, eff, def.anim)

    -- honger/dorst/stress naar het framework
    if QBCore and (eff.hunger or eff.thirst or eff.stress) then
        local p = QBCore.Functions.GetPlayer(src)
        if p then
            local md = p.PlayerData.metadata
            local h = math.max(0, math.min(100, (md.hunger or 100) + (eff.hunger or 0)))
            local t = math.max(0, math.min(100, (md.thirst or 100) + (eff.thirst or 0)))
            local s = math.max(0, math.min(100, (md.stress or 0) + (eff.stress or 0)))
            p.Functions.SetMetaData('hunger', h)
            p.Functions.SetMetaData('thirst', t)
            p.Functions.SetMetaData('stress', s)
            TriggerClientEvent('hud:client:UpdateNeeds', src, h, t)
            TriggerClientEvent('hud:client:UpdateStress', src, s)
        end
    elseif ESX then
        if eff.hunger then TriggerClientEvent('esx_status:add', src, 'hunger', eff.hunger * 10000) end
        if eff.thirst then TriggerClientEvent('esx_status:add', src, 'thirst', eff.thirst * 10000) end
    end

    TriggerEvent('dv-inventory:server:itemUsed', src, it.name, slot)
    return { ok = true, close = def.close }
end

Actions.consume = function(src, d)
    local inv = loadPlayer(src)
    local slot = tonumber(d.slot)
    local it = inv and slot and inv.items[slot]
    if not it or it.name ~= d.name then return { ok = false } end
    removeItem(inv, it.name, 1, slot)
    sync(inv)
    itembox(src, d.name, -1)
    return { ok = true }
end

-- ------------------------------------------------------------
--  Aanroepen vanaf de client
-- ------------------------------------------------------------

RegisterNetEvent('dv-inventory:server:call', function(reqId, action, data)
    local src = source
    if type(action) ~= 'string' then return end
    local now = os.time()
    local r = rate[src]
    if not r or now - r[1] >= 5 then r = { now, 0 }; rate[src] = r end
    r[2] = r[2] + 1
    local res
    if r[2] > 40 then
        res = { ok = false, msg = 'Rustig aan' }
    elseif not Actions[action] then
        res = { ok = false, msg = 'Onbekende actie' }
    else
        local ok, result = pcall(Actions[action], src, type(data) == 'table' and data or {})
        res = ok and result or { ok = false, msg = 'Er ging iets mis' }
        if not ok then print('[dv-inventory] fout in ' .. action .. ': ' .. tostring(result)) end
    end
    TriggerClientEvent('dv-inventory:client:reply', src, reqId, res)
end)

-- nieuwe speler: drops doorsturen
RegisterNetEvent('dv-inventory:server:ready', function()
    local src = source
    local list = {}
    for id, d in pairs(drops) do list[#list + 1] = { id = id, x = d.coords.x, y = d.coords.y, z = d.coords.z } end
    TriggerClientEvent('dv-inventory:client:drops', src, list)
    local inv = loadPlayer(src)
    if inv then TriggerClientEvent('dv-inventory:client:update', src, { player = payload(inv) }) end
end)

-- ------------------------------------------------------------
--  Exports voor andere scripts
-- ------------------------------------------------------------

exports('AddItem', function(src, name, count, meta)
    local inv = loadPlayer(src)
    if not inv then return false end
    local ok = addItem(inv, name, count or 1, meta)
    if ok then sync(inv); itembox(src, name, count or 1) end
    return ok
end)

exports('RemoveItem', function(src, name, count, slot)
    local inv = loadPlayer(src)
    if not inv then return false end
    local ok = removeItem(inv, name, count or 1, slot)
    if ok then sync(inv); itembox(src, name, -(count or 1)) end
    return ok
end)

exports('GetItemCount', function(src, name)
    local inv = loadPlayer(src)
    return inv and countItem(inv, name) or 0
end)

exports('HasItem', function(src, name, count)
    local inv = loadPlayer(src)
    return inv ~= nil and countItem(inv, name) >= (count or 1)
end)

exports('CanCarry', function(src, name, count)
    local inv = loadPlayer(src)
    return inv ~= nil and canAdd(inv, name, count or 1) == true
end)

exports('GetInventory', function(src)
    local inv = loadPlayer(src)
    return inv and toList(inv) or {}
end)

exports('RegisterUsable', function(name, cb)
    Usable[name] = cb
end)

--- Stash openen vanuit een ander script:
--- exports['dv-inventory']:OpenStash(src, 'politie_kluis', 'Politie kluis', 50, 200000)
exports('OpenStash', function(src, id, label, slots, maxWeight)
    local inv = loadPlayer(src)
    if not inv then return false end
    local stash = getInv('stash:' .. id, { type = 'stash', label = label or id, slots = slots or 50, maxWeight = maxWeight or 100000 })
    openWith[src] = stash.id
    TriggerClientEvent('dv-inventory:client:openServer', src, { player = payload(inv), secondary = payload(stash) })
    return true
end)

-- ------------------------------------------------------------
--  Admin-commando's
-- ------------------------------------------------------------

local function isAdmin(src) return src == 0 or IsPlayerAceAllowed(src, Config.AdminAce) end

local function reply(src, msg)
    if src == 0 then print('[dv-inventory] ' .. msg)
    else TriggerClientEvent('dv-inventory:client:notify', src, msg, 'info') end
end

-- /giveitem <id> <item> [aantal]
RegisterCommand('giveitem', function(src, args)
    if not isAdmin(src) then return end
    local target, name, count = tonumber(args[1]), args[2], tonumber(args[3]) or 1
    if not isOnline(target) or not Items[name] then return reply(src, 'Gebruik: /giveitem <id> <item> [aantal]') end
    local inv = loadPlayer(target)
    if not inv then return reply(src, 'Speler is nog niet geladen') end
    local ok, err = addItem(inv, name, count)
    if not ok then return reply(src, 'Mislukt: ' .. err) end
    sync(inv)
    itembox(target, name, count)
    reply(src, ('%dx %s gegeven aan %s'):format(count, Items[name].label, GetPlayerName(target)))
    print(('[dv-inventory] %s gaf %dx %s aan %s'):format(src == 0 and 'Console' or GetPlayerName(src), count, name, GetPlayerName(target)))
end, false)

-- /clearinv <id>
RegisterCommand('clearinv', function(src, args)
    if not isAdmin(src) then return end
    local target = tonumber(args[1])
    if not isOnline(target) then return reply(src, 'Gebruik: /clearinv <id>') end
    local inv = loadPlayer(target)
    if not inv then return end
    inv.items = {}
    markDirty(inv)
    sync(inv)
    reply(src, 'Inventory van ' .. GetPlayerName(target) .. ' is leeggemaakt')
end, false)
