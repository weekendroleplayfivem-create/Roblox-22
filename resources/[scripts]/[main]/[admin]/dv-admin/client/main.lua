-- ============================================================
--  dv-admin  |  client
-- ============================================================

local menuOpen = false
local focusReason = nil        -- 'menu' of 'warn'

local flags = {
    noclip = false,
    godmode = false,
    invisible = false,
    names = false,
    blips = false,
}

local spectating = nil         -- server-id van de speler die je bekijkt

-- ------------------------------------------------------------
--  Server-aanroepen met antwoord
-- ------------------------------------------------------------

local reqId, pending = 0, {}

local function call(action, data)
    reqId = reqId + 1
    local id = reqId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('dv-admin:server:call', id, action, data or {})
    SetTimeout(10000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ ok = false, msg = 'Server reageert niet' })
        end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('dv-admin:client:reply', function(id, res)
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

local function teleport(coords)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoords(ent, coords.x, coords.y, coords.z, false, false, false, false)
    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < timeout do Wait(0) end

    DoScreenFadeIn(250)
end

local function teleportToGround(x, y)
    local ped = PlayerPedId()
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    local found, groundZ = false, 0.0
    for z = 1000.0, 0.0, -25.0 do
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        RequestCollisionAtCoord(x, y, z)
        Wait(20)
        found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
        if found then break end
    end
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = (veh ~= 0) and veh or ped
    SetEntityCoords(ent, x, y, found and groundZ or 200.0, false, false, false, false)
    DoScreenFadeIn(250)
    return found
end

local function nearestVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    local coords = GetEntityCoords(ped)
    local best, bestDist = 0, 6.0
    for _, v in ipairs(GetGamePool('CVehicle')) do
        local d = #(GetEntityCoords(v) - coords)
        if d < bestDist then best, bestDist = v, d end
    end
    return best
end

local function requestControl(ent)
    local timeout = GetGameTimer() + 1500
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

local function doRevive()
    local ped = PlayerPedId()
    if GetResourceState('qb-ambulancejob') == 'started' then
        TriggerEvent('hospital:client:Revive')
    elseif GetResourceState('esx_ambulancejob') == 'started' then
        TriggerEvent('esx_ambulancejob:revive')
    elseif IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    end
    Wait(100)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
end

local function doHeal()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    if GetResourceState('qb-ambulancejob') == 'started' then
        TriggerEvent('hospital:client:HealInjuries', 'full')
    end
end

-- ------------------------------------------------------------
--  Noclip
-- ------------------------------------------------------------

local NC_SPEEDS = { 0.05, 0.2, 0.5, 1.0, 2.0, 4.0, 8.0 }
local ncSpeed = 4

local function noclipEntity()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then return veh end
    return ped
end

local function setNoclip(state)
    flags.noclip = state
    local ent = noclipEntity()
    local ped = PlayerPedId()
    if not state then
        FreezeEntityPosition(ent, false)
        SetEntityCollision(ent, true, true)
        SetEntityVisible(ent, not flags.invisible, false)
        SetEntityVisible(ped, not flags.invisible, false)
        SetEntityInvincible(ent, flags.godmode)
        SetEveryoneIgnorePlayer(PlayerId(), false)
        -- veilig landen
        local c = GetEntityCoords(ent)
        local found, z = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
        if found and c.z - z < 3.0 then SetEntityCoords(ent, c.x, c.y, z, false, false, false, false) end
    end
    nui('noclip', { on = state, speed = NC_SPEEDS[ncSpeed] })
end

CreateThread(function()
    while true do
        if flags.noclip then
            local ent = noclipEntity()
            local ped = PlayerPedId()

            FreezeEntityPosition(ent, true)
            SetEntityCollision(ent, false, false)
            SetEntityVisible(ent, false, false)
            SetLocalPlayerVisibleLocally(true)
            SetEntityInvincible(ent, true)
            SetEveryoneIgnorePlayer(PlayerId(), true)

            for _, c in ipairs({ 24, 25, 44, 38, 37, 140, 141, 142, 257, 263, 264, 85, 86, 14, 15, 16, 17 }) do
                DisableControlAction(0, c, true)
            end

            if IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then
                ncSpeed = math.min(ncSpeed + 1, #NC_SPEEDS)
                nui('noclip', { on = true, speed = NC_SPEEDS[ncSpeed] })
            elseif IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then
                ncSpeed = math.max(ncSpeed - 1, 1)
                nui('noclip', { on = true, speed = NC_SPEEDS[ncSpeed] })
            end

            local rot = GetGameplayCamRot(2)
            local rx, rz = math.rad(rot.x), math.rad(rot.z)
            local fwd = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
            local right = vector3(math.cos(rz), math.sin(rz), 0.0)
            local move = vector3(0.0, 0.0, 0.0)

            if IsControlPressed(0, 32) then move = move + fwd end
            if IsControlPressed(0, 33) then move = move - fwd end
            if IsControlPressed(0, 35) then move = move + right end
            if IsControlPressed(0, 34) then move = move - right end
            if IsDisabledControlPressed(0, 38) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, 44) then move = move - vector3(0.0, 0.0, 1.0) end

            local mult = IsControlPressed(0, 21) and 3.0 or (IsControlPressed(0, 36) and 0.3 or 1.0)
            local speed = NC_SPEEDS[ncSpeed] * mult * GetFrameTime() * 60.0
            local pos = GetEntityCoords(ent)

            SetEntityHeading(ent, rot.z)
            SetEntityCoordsNoOffset(ent, pos.x + move.x * speed, pos.y + move.y * speed, pos.z + move.z * speed, true, true, true)
            if ent ~= ped then SetEntityVisible(ped, false, false) end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

-- ------------------------------------------------------------
--  Godmode / onzichtbaar / namen / blips
-- ------------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if flags.godmode then
            SetEntityInvincible(ped, true)
            SetPlayerInvincible(PlayerId(), true)
        end
        if flags.invisible and not flags.noclip then
            sleep = 0
            SetEntityVisible(ped, false, false)
            SetLocalPlayerVisibleLocally(true)
            SetEntityAlpha(ped, 150, false)
        end
        Wait(sleep)
    end
end)

local function draw3D(coords, text)
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 255, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

CreateThread(function()
    while true do
        if flags.names then
            local myCoords = GetEntityCoords(PlayerPedId())
            for _, pl in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(pl)
                local c = GetEntityCoords(ped)
                local dist = #(c - myCoords)
                if dist < 150.0 then
                    local talking = NetworkIsPlayerTalking(pl) and ' ~g~(praat)' or ''
                    local hp = math.max(0, GetEntityHealth(ped) - 100)
                    draw3D(c + vector3(0.0, 0.0, 1.05),
                        ('~b~[%d]~w~ %s%s~n~~c~%d HP - %dm'):format(GetPlayerServerId(pl), GetPlayerName(pl), talking, hp, math.floor(dist)))
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local blips = {}

local function clearBlips()
    for _, b in pairs(blips) do RemoveBlip(b) end
    blips = {}
end

CreateThread(function()
    while true do
        if flags.blips then
            local seen = {}
            for _, pl in ipairs(GetActivePlayers()) do
                if pl ~= PlayerId() then
                    local ped = GetPlayerPed(pl)
                    seen[pl] = true
                    local blip = blips[pl]
                    if not blip or not DoesBlipExist(blip) or GetBlipInfoIdEntityIndex(blip) ~= ped then
                        if blip then RemoveBlip(blip) end
                        blip = AddBlipForEntity(ped)
                        SetBlipSprite(blip, 1)
                        SetBlipColour(blip, 0)
                        SetBlipScale(blip, 0.8)
                        SetBlipCategory(blip, 7)
                        ShowHeadingIndicatorOnBlip(blip, true)
                        BeginTextCommandSetBlipName('STRING')
                        AddTextComponentSubstringPlayerName(('[%d] %s'):format(GetPlayerServerId(pl), GetPlayerName(pl)))
                        EndTextCommandSetBlipName(blip)
                        blips[pl] = blip
                    end
                end
            end
            for pl, b in pairs(blips) do
                if not seen[pl] then RemoveBlip(b); blips[pl] = nil end
            end
            Wait(1000)
        else
            if next(blips) then clearBlips() end
            Wait(1000)
        end
    end
end)

-- ------------------------------------------------------------
--  Spectate
-- ------------------------------------------------------------

local specReturn = nil

local function stopSpectate()
    if not spectating then return end
    spectating = nil
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end
    if specReturn then
        SetEntityCoords(ped, specReturn.x, specReturn.y, specReturn.z, false, false, false, false)
    end
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, not flags.invisible, false)
    SetEntityInvincible(ped, flags.godmode)
    specReturn = nil
    DoScreenFadeIn(200)
    nui('spectate', { on = false })
end

RegisterNetEvent('dv-admin:client:spectate', function(target, coords, targetName)
    if spectating then stopSpectate() end
    if not coords then return notify('Positie van speler onbekend', 'error') end

    local ped = PlayerPedId()
    specReturn = GetEntityCoords(ped)

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end

    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 20.0, false, false, false, false)

    local player = -1
    local timeout = GetGameTimer() + 6000
    while GetGameTimer() < timeout do
        player = GetPlayerFromServerId(target)
        if player ~= -1 and DoesEntityExist(GetPlayerPed(player)) then break end
        Wait(100)
    end

    if player == -1 then
        spectating = target
        stopSpectate()
        return notify('Kon speler niet laden', 'error')
    end

    spectating = target
    NetworkSetInSpectatorMode(true, GetPlayerPed(player))
    DoScreenFadeIn(200)
    nui('spectate', { on = true, name = targetName, id = target })

    CreateThread(function()
        local tick = 0
        while spectating == target do
            -- Backspace = stoppen
            if IsControlJustPressed(0, 177) then
                stopSpectate()
                break
            end
            tick = tick + 1
            if tick % 60 == 0 then
                local pl = GetPlayerFromServerId(target)
                if pl == -1 then
                    notify('Speler is uit bereik of offline', 'error')
                    stopSpectate()
                    break
                end
                -- blijf in de buurt zodat de speler geladen blijft
                local c = GetEntityCoords(GetPlayerPed(pl))
                SetEntityCoords(PlayerPedId(), c.x, c.y, c.z - 20.0, false, false, false, false)
            end
            Wait(0)
        end
    end)
end)

-- ------------------------------------------------------------
--  Events van de server (op jou uitgevoerd)
-- ------------------------------------------------------------

RegisterNetEvent('dv-admin:client:teleport', function(coords)
    teleport(coords)
end)

RegisterNetEvent('dv-admin:client:freeze', function(state)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    FreezeEntityPosition(ped, state)
    if veh ~= 0 then FreezeEntityPosition(veh, state) end
    nui('toast', { msg = state and 'Je bent bevroren door staff' or 'Je kunt weer bewegen', kind = state and 'warn' or 'success', player = true })
end)

RegisterNetEvent('dv-admin:client:heal', function()
    doHeal()
end)

RegisterNetEvent('dv-admin:client:revive', function()
    doRevive()
end)

RegisterNetEvent('dv-admin:client:kill', function()
    SetEntityHealth(PlayerPedId(), 0)
end)

RegisterNetEvent('dv-admin:client:dm', function(from, msg)
    nui('dm', { from = from, msg = msg })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

RegisterNetEvent('dv-admin:client:announce', function(from, msg)
    nui('announce', { from = from, msg = msg })
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('dv-admin:client:warned', function(from, reason)
    focusReason = 'warn'
    SetNuiFocus(true, true)
    nui('warn', { from = from, reason = reason })
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
end)

-- ------------------------------------------------------------
--  Acties op jezelf (na goedkeuring van de server)
-- ------------------------------------------------------------

local Self = {}

Self.noclip = function() setNoclip(not flags.noclip); return { state = flags.noclip } end

Self.godmode = function()
    flags.godmode = not flags.godmode
    if not flags.godmode then
        SetEntityInvincible(PlayerPedId(), false)
        SetPlayerInvincible(PlayerId(), false)
    end
    return { state = flags.godmode }
end

Self.invisible = function()
    flags.invisible = not flags.invisible
    if not flags.invisible then
        local ped = PlayerPedId()
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
    end
    return { state = flags.invisible }
end

Self.names = function() flags.names = not flags.names; return { state = flags.names } end
Self.blips = function() flags.blips = not flags.blips; return { state = flags.blips } end

Self.healSelf = function() doHeal(); return { msg = 'Je bent genezen' } end
Self.reviveSelf = function() doRevive(); return { msg = 'Je bent gerevived' } end

Self.tpWaypoint = function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return { ok = false, msg = 'Zet eerst een waypoint op de kaart' } end
    local c = GetBlipInfoIdCoord(blip)
    teleportToGround(c.x, c.y)
    return { msg = 'Geteleporteerd naar waypoint' }
end

Self.tpCoords = function(d)
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y then return { ok = false, msg = 'Ongeldige coördinaten' } end
    if z then teleport(vector3(x, y, z)) else teleportToGround(x, y) end
    return { msg = 'Geteleporteerd' }
end

Self.copyCoords = function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    return {
        coords = {
            vec3 = ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z),
            vec4 = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, GetEntityHeading(ped)),
            heading = ('%.2f'):format(GetEntityHeading(ped)),
        },
    }
end

Self.spawnVehicle = function(d)
    local model = joaat(tostring(d.model or ''))
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        return { ok = false, msg = 'Onbekend voertuigmodel' }
    end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then return { ok = false, msg = 'Model laden mislukt' } end

    local ped = PlayerPedId()
    local old = GetVehiclePedIsIn(ped, false)
    if old ~= 0 and requestControl(old) then
        SetEntityAsMissionEntity(old, true, true)
        DeleteVehicle(old)
    end

    local c = GetEntityCoords(ped)
    local veh = CreateVehicle(model, c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(model)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, Config.SpawnPlate)
    SetVehicleFuelLevel(veh, 100.0)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetPedIntoVehicle(ped, veh, -1)
    Entity(veh).state:set('fuel', 100.0, true)

    local plate = GetVehicleNumberPlateText(veh)
    if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
    if GetResourceState('LegacyFuel') == 'started' then
        pcall(function() exports['LegacyFuel']:SetFuel(veh, 100.0) end)
    end
    return { msg = 'Voertuig gespawnd' }
end

Self.fixVehicle = function()
    local veh = nearestVehicle()
    if veh == 0 then return { ok = false, msg = 'Geen voertuig in de buurt' } end
    requestControl(veh)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleUndriveable(veh, false)
    return { msg = 'Voertuig gerepareerd' }
end

Self.deleteVehicle = function()
    local veh = nearestVehicle()
    if veh == 0 then return { ok = false, msg = 'Geen voertuig in de buurt' } end
    if not requestControl(veh) then return { ok = false, msg = 'Geen controle over voertuig' } end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    return { msg = 'Voertuig verwijderd' }
end

-- ------------------------------------------------------------
--  Menu openen / NUI
-- ------------------------------------------------------------

local function openMenu(tab)
    if menuOpen then return end
    local res = call('open')
    if not res.ok then return notify(res.msg or 'Geen toegang', 'error') end
    menuOpen = true
    focusReason = 'menu'
    SetNuiFocus(true, true)
    res.flags = flags
    res.tab = tab
    nui('open', res)
end

RegisterCommand(Config.Command, function() CreateThread(openMenu) end, false)
RegisterKeyMapping(Config.Command, 'Staffmenu openen', 'keyboard', Config.Key)

RegisterCommand(Config.NoclipCommand, function()
    CreateThread(function()
        local res = call('noclip')
        if res.ok then Self.noclip() end
    end)
end, false)
if Config.NoclipKey ~= '' then
    RegisterKeyMapping(Config.NoclipCommand, 'Noclip aan/uit (staff)', 'keyboard', Config.NoclipKey)
end

RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    focusReason = nil
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('warnAck', function(_, cb)
    if focusReason == 'warn' then
        focusReason = menuOpen and 'menu' or nil
        if not menuOpen then SetNuiFocus(false, false) end
    end
    cb('ok')
end)

-- Reports-knop in het menu: sluit het staffmenu en opent dv-reports
RegisterNUICallback('openReports', function(_, cb)
    menuOpen = false
    focusReason = nil
    SetNuiFocus(false, false)
    cb('ok')
    if GetResourceState('dv-reports') == 'started' then
        ExecuteCommand('reports')
    else
        notify('dv-reports is niet gestart', 'error')
    end
end)

RegisterNUICallback('stopSpectate', function(_, cb)
    CreateThread(stopSpectate)
    cb('ok')
end)

RegisterNUICallback('action', function(d, cb)
    CreateThread(function()
        local name, data = d.name, d.data or {}
        local res = call(name, data)
        if res.ok and Self[name] then
            local extra = Self[name](data) or {}
            for k, v in pairs(extra) do res[k] = v end
        end
        if res.close then
            menuOpen = false
            focusReason = nil
            SetNuiFocus(false, false)
        end
        cb(res)
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if menuOpen or focusReason then SetNuiFocus(false, false) end
    if flags.noclip then setNoclip(false) end
    if spectating then stopSpectate() end
    clearBlips()
end)
