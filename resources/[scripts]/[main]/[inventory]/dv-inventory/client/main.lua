-- ============================================================
--  dv-inventory  |  client
-- ============================================================

local isOpen = false
local busy = false               -- tijdens een animatie (eten, drinken, ...)
local playerItems = {}           -- laatste kopie van eigen inventory (voor hotbar/wapens)
local equipped = nil             -- { slot, name, hash }
local drops = {}                 -- [id] = { coords, obj }
local openedTrunk = nil          -- voertuig waarvan de kofferbak open staat
local UNARMED = GetHashKey('WEAPON_UNARMED')
local Defs = Config.Items          -- itemlijst; bij ESX gestuurd door de server (ESX-items, wapens, geld)
local isEsx = false                -- ESX beheert wapens zelf (loadout)

-- ------------------------------------------------------------
--  Server-aanroepen met antwoord
-- ------------------------------------------------------------

local reqId, pending = 0, {}

local function call(action, data)
    reqId = reqId + 1
    local id = reqId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('dv-inventory:server:call', id, action, data or {})
    SetTimeout(10000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ ok = false, msg = 'Server reageert niet' })
        end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('dv-inventory:client:reply', function(id, res)
    local p = pending[id]
    if p then
        pending[id] = nil
        p:resolve(res)
    end
end)

local function nui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function notify(msg, kind)
    nui('toast', { msg = msg, kind = kind or 'info' })
end

-- ------------------------------------------------------------
--  Helpers
-- ------------------------------------------------------------

local function itemAt(slot)
    for _, it in ipairs(playerItems) do
        if it.slot == slot then return it end
    end
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
end

local function closestPlayer(maxDist)
    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local best, bestDist = nil, maxDist
    for _, pl in ipairs(GetActivePlayers()) do
        if pl ~= PlayerId() then
            local d = #(GetEntityCoords(GetPlayerPed(pl)) - myCoords)
            if d < bestDist then best, bestDist = GetPlayerServerId(pl), d end
        end
    end
    return best
end

local function closestVehicle(maxDist)
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist = 0, maxDist
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - coords)
        if d < bestDist then best, bestDist = v, d end
    end
    return best
end

--- Staat de speler achter het voertuig (bij de kofferbak)?
local function trunkVehicle()
    local veh = closestVehicle(6.0)
    if veh == 0 then return 0 end
    local class = GetVehicleClass(veh)
    if class == 8 or class == 13 or class == 14 or class == 15 or class == 16 or class == 21 then return 0 end
    local ped = PlayerPedId()
    local bone = GetEntityBoneIndexByName(veh, 'boot')
    local pos
    if bone ~= -1 then
        pos = GetWorldPositionOfEntityBone(veh, bone)
    else
        local min, max = GetModelDimensions(GetEntityModel(veh))
        pos = GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.5, 0.0)
    end
    if #(GetEntityCoords(ped) - pos) <= Config.TrunkDistance then return veh end
    return 0
end

local function nearestDrop()
    local coords = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, Config.DropDistance
    for id, d in pairs(drops) do
        local dist = #(d.coords - coords)
        if dist < bestDist then best, bestDist = id, dist end
    end
    return best
end

-- ------------------------------------------------------------
--  Openen / sluiten
-- ------------------------------------------------------------

local function setTrunk(veh, open)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if open then
        SetVehicleDoorOpen(veh, 5, false, false)
    else
        SetVehicleDoorShut(veh, 5, false)
    end
end

local function openInventory()
    if isOpen or busy then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPauseMenuActive() then return end

    local req
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        req = { kind = 'glovebox', net = VehToNet(veh) }
    else
        local drop = nearestDrop()
        local trunk = trunkVehicle()
        if drop then
            req = { kind = 'drop', id = drop }
        elseif trunk ~= 0 then
            req = { kind = 'trunk', net = VehToNet(trunk) }
            openedTrunk = trunk
        end
    end

    local res = call('open', req)
    if not res.ok then
        openedTrunk = nil
        return notify(res.msg or 'Kan inventory niet openen', 'error')
    end
    if res.secondary and res.secondary.type == 'trunk' then
        setTrunk(openedTrunk, true)
    else
        openedTrunk = nil
    end
    playerItems = res.player.items
    if res.defs then Defs = res.defs end
    if res.esx ~= nil then isEsx = res.esx end
    isOpen = true
    SetNuiFocus(true, true)
    nui('open', { player = res.player, secondary = res.secondary, items = Defs, hotbar = Config.Hotbar })
end

local function closeInventory()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    nui('close', {})
    if openedTrunk then
        setTrunk(openedTrunk, false)
        openedTrunk = nil
    end
    CreateThread(function() call('close') end)
end

RegisterCommand('inventory', function() CreateThread(openInventory) end, false)
RegisterKeyMapping('inventory', 'Inventory openen', 'keyboard', Config.OpenKey)

-- geopend door de server (stash)
RegisterNetEvent('dv-inventory:client:openServer', function(data)
    if isOpen then
        nui('update', data)
        return
    end
    playerItems = data.player.items
    if data.defs then Defs = data.defs end
    isOpen = true
    SetNuiFocus(true, true)
    nui('open', { player = data.player, secondary = data.secondary, items = Defs, hotbar = Config.Hotbar })
end)

-- ------------------------------------------------------------
--  Wapens
-- ------------------------------------------------------------

local function holster()
    local ped = PlayerPedId()
    -- bij ESX blijft het wapen in je loadout; alleen wegstoppen
    if equipped and not isEsx then
        RemoveWeaponFromPed(ped, equipped.hash)
    end
    SetCurrentPedWeapon(ped, UNARMED, true)
    equipped = nil
    nui('equipped', { slot = false })
end

RegisterNetEvent('dv-inventory:client:weapon', function(slot, name, weapon)
    local hash = GetHashKey(weapon)
    if equipped and equipped.slot == slot then
        return holster()
    end
    if equipped then holster() end
    local ped = PlayerPedId()
    if not isEsx then GiveWeaponToPed(ped, hash, 0, false, true) end
    SetCurrentPedWeapon(ped, hash, true)
    equipped = { slot = slot, name = name, hash = hash }
    nui('equipped', { slot = slot })
end)

-- wapen weg als het item niet meer in dat vakje zit (weggegooid, gegeven, verplaatst)
local function checkEquipped()
    if not equipped then return end
    local it = itemAt(equipped.slot)
    if not it or it.name ~= equipped.name then
        -- misschien alleen verschoven: zoek hetzelfde wapen
        for _, other in ipairs(playerItems) do
            if other.name == equipped.name then
                equipped.slot = other.slot
                nui('equipped', { slot = other.slot })
                return
            end
        end
        holster()
    end
end

-- ------------------------------------------------------------
--  Effecten van items
-- ------------------------------------------------------------

local ANIMS = {
    eat = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger', time = 3000 },
    drink = { dict = 'mp_player_intdrink', clip = 'loop_bottle', time = 3000 },
    bandage = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', time = 3500 },
    smoke = { dict = 'amb@world_human_smoking@male@male_a@enter', clip = 'enter', time = 4000 },
}

local function playAnim(kind)
    local a = ANIMS[kind]
    if not a then return end
    busy = true
    loadAnimDict(a.dict)
    TaskPlayAnim(PlayerPedId(), a.dict, a.clip, 3.0, 3.0, a.time, 49, 0, false, false, false)
    nui('progress', { label = kind == 'eat' and 'Eten…' or kind == 'drink' and 'Drinken…' or kind == 'smoke' and 'Roken…' or 'Verzorgen…', time = a.time })
    Wait(a.time)
    ClearPedTasks(PlayerPedId())
    busy = false
end

RegisterNetEvent('dv-inventory:client:effect', function(name, eff, anim)
    CreateThread(function()
        if anim then playAnim(anim) end
        local ped = PlayerPedId()
        if eff.heal then
            local max = GetEntityMaxHealth(ped)
            SetEntityHealth(ped, math.min(max, GetEntityHealth(ped) + math.floor((max - 100) * eff.heal / 100)))
        end
        if eff.armor then
            SetPedArmour(ped, math.min(100, GetPedArmour(ped) + eff.armor))
        end
        -- hook voor andere scripts (bv. een eigen honger/dorst-systeem)
        TriggerEvent('dv-inventory:client:used', name, eff)
    end)
end)

RegisterNetEvent('dv-inventory:client:special', function(slot, name, ammo, action)
    local ped = PlayerPedId()
    if ammo then
        local weapon = GetSelectedPedWeapon(ped)
        if weapon == UNARMED or GetPedAmmoTypeFromWeapon(ped, weapon) ~= GetHashKey(ammo.type) then
            return notify('Pak eerst het juiste wapen', 'error')
        end
        local res = call('consume', { slot = slot, name = name, weaponHash = weapon })
        -- bij ESX zet de server de kogels (ESX onthoudt ze in je loadout)
        if res.ok and not res.esx then AddAmmoToPed(ped, weapon, ammo.amount) end
        if not res.ok and res.msg then notify(res.msg, 'error') end
    elseif action == 'repair' then
        local veh = closestVehicle(5.0)
        if veh == 0 or IsPedInAnyVehicle(ped, false) then
            return notify('Ga naast een voertuig staan', 'error')
        end
        busy = true
        TaskStartScenarioInPlace(ped, 'PROP_HUMAN_BUM_BIN', 0, true)
        nui('progress', { label = 'Repareren…', time = 8000 })
        Wait(8000)
        ClearPedTasks(ped)
        busy = false
        local res = call('consume', { slot = slot, name = name })
        if res.ok then
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleUndriveable(veh, false)
            notify('Voertuig gerepareerd', 'success')
        end
    end
end)

RegisterNetEvent('dv-inventory:client:giveAnim', function()
    CreateThread(function()
        loadAnimDict('mp_common')
        TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 49, 0, false, false, false)
    end)
end)

-- ------------------------------------------------------------
--  Hotbar (1-5)
-- ------------------------------------------------------------

local function useSlot(slot)
    if busy or isOpen or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
    local it = itemAt(slot)
    nui('hotbar', { items = playerItems, used = slot })
    if not it then return end
    CreateThread(function()
        local res = call('use', { slot = slot })
        if not res.ok and res.msg then notify(res.msg, 'error') end
    end)
end

if Config.Hotbar then
    for i = 1, 5 do
        RegisterCommand('dvslot' .. i, function() useSlot(i) end, false)
        RegisterKeyMapping('dvslot' .. i, ('Hotbar vakje %d'):format(i), 'keyboard', tostring(i))
    end

    -- GTA-wapenwiel op 1-5 en TAB uitzetten, anders pakt GTA die toetsen
    CreateThread(function()
        while true do
            DisableControlAction(0, 37, true)      -- wapenwiel (TAB)
            for c = 157, 165 do DisableControlAction(0, c, true) end
            HideHudComponentThisFrame(19)          -- wapenwiel
            HideHudComponentThisFrame(20)
            Wait(0)
        end
    end)
end

-- ------------------------------------------------------------
--  Updates van de server
-- ------------------------------------------------------------

RegisterNetEvent('dv-inventory:client:update', function(data)
    if data.defs then Defs = data.defs end
    if data.esx ~= nil then isEsx = data.esx end
    if data.player then
        playerItems = data.player.items
        checkEquipped()
    end
    if data.secondary == false and openedTrunk then
        setTrunk(openedTrunk, false)
        openedTrunk = nil
    end
    nui('update', data)
end)

RegisterNetEvent('dv-inventory:client:itembox', function(name, delta)
    local def = Defs[name]
    if def then nui('itembox', { label = def.label, icon = def.icon, delta = delta }) end
end)

RegisterNetEvent('dv-inventory:client:notify', function(msg, kind)
    notify(msg, kind)
end)

-- ------------------------------------------------------------
--  Spullen op de grond
-- ------------------------------------------------------------

local function spawnDropProp(d)
    local model = GetHashKey(Config.DropProp)
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
    if not HasModelLoaded(model) then return end
    local obj = CreateObject(model, d.coords.x, d.coords.y, d.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(model)
    d.obj = obj
end

RegisterNetEvent('dv-inventory:client:drops', function(list)
    local keep = {}
    for _, d in ipairs(list) do
        keep[d.id] = true
        if not drops[d.id] then drops[d.id] = { coords = vector3(d.x, d.y, d.z) } end
    end
    for id, d in pairs(drops) do
        if not keep[id] then
            if d.obj and DoesEntityExist(d.obj) then DeleteEntity(d.obj) end
            drops[id] = nil
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for _, d in pairs(drops) do
            local dist = #(d.coords - coords)
            if dist < 60.0 and not d.obj then
                spawnDropProp(d)
            elseif dist >= 80.0 and d.obj then
                DeleteEntity(d.obj)
                d.obj = nil
            end
            if dist < 8.0 then
                sleep = 0
                DrawMarker(2, d.coords.x, d.coords.y, d.coords.z + 0.35, 0, 0, 0, 180.0, 0, 0, 0.15, 0.15, 0.15, 255, 140, 26, 180, true, true, 2, false, nil, nil, false)
            end
        end
        Wait(sleep)
    end
end)

-- ------------------------------------------------------------
--  NUI callbacks
-- ------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    closeInventory()
    cb('ok')
end)

RegisterNUICallback('move', function(d, cb)
    CreateThread(function() cb(call('move', d)) end)
end)

RegisterNUICallback('use', function(d, cb)
    CreateThread(function()
        local res = call('use', { slot = d.slot })
        if res.ok and res.close then closeInventory() end
        cb(res)
    end)
end)

RegisterNUICallback('give', function(d, cb)
    CreateThread(function()
        local target = closestPlayer(Config.GiveDistance)
        if not target then return cb({ ok = false, msg = 'Niemand in de buurt' }) end
        cb(call('give', { slot = d.slot, count = d.count, target = target }))
    end)
end)

-- ------------------------------------------------------------
--  Opstarten / stoppen
-- ------------------------------------------------------------

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    Wait(2000)
    TriggerServerEvent('dv-inventory:server:ready')
end)

-- nieuw karakter geladen (QBCore / ESX): drops en inventory opnieuw ophalen
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('dv-inventory:server:ready') end)
RegisterNetEvent('esx:playerLoaded', function() TriggerServerEvent('dv-inventory:server:ready') end)

-- ESX: als een ander script items, wapens of geld verandert, halen we de inventory opnieuw op
local refreshPending = false
local function refreshSoon()
    if refreshPending then return end
    refreshPending = true
    SetTimeout(200, function()
        refreshPending = false
        CreateThread(function()
            local res = call('get')
            if res.ok and res.player then
                playerItems = res.player.items
                if res.defs then Defs = res.defs end
                checkEquipped()
                nui('update', { player = res.player })
            end
        end)
    end)
end
for _, ev in ipairs({ 'esx:addInventoryItem', 'esx:removeInventoryItem', 'esx:setAccountMoney', 'esx:addLoadoutItem', 'esx:removeLoadoutItem', 'esx:addWeapon', 'esx:removeWeapon' }) do
    RegisterNetEvent(ev, refreshSoon)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    for _, d in pairs(drops) do
        if d.obj and DoesEntityExist(d.obj) then DeleteEntity(d.obj) end
    end
end)
