-- ============================================================
--  dv-reports  |  client
-- ============================================================

local panel = nil   -- nil, 'player' of 'staff'

-- ------------------------------------------------------------
--  Server-aanroepen met antwoord
-- ------------------------------------------------------------

local reqId, pending = 0, {}

local function call(action, data)
    reqId = reqId + 1
    local id = reqId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('dv-reports:server:call', id, action, data or {})
    SetTimeout(10000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ ok = false, msg = 'Server reageert niet' })
        end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('dv-reports:client:reply', function(id, res)
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

local function setPanel(value)
    panel = value
    SetNuiFocus(value ~= nil, value ~= nil)
end

-- ------------------------------------------------------------
--  Spelers: /report
-- ------------------------------------------------------------

local function openPlayer(prefill)
    if panel then return end
    local res = call('mine')
    if not res.ok then return notify(res.msg or 'Er ging iets mis', 'error') end
    res.prefill = prefill
    setPanel('player')
    nui('playerOpen', res)
end

RegisterCommand(Config.Command, function(_, args)
    local prefill = #args > 0 and table.concat(args, ' ') or nil
    CreateThread(function() openPlayer(prefill) end)
end, false)

-- ------------------------------------------------------------
--  Staff: /reports
-- ------------------------------------------------------------

local function openStaff()
    if panel then return end
    local res = call('open')
    if not res.ok then return notify(res.msg or 'Geen toegang', 'error') end
    setPanel('staff')
    nui('staffOpen', res)
end

RegisterCommand(Config.StaffCommand, function() CreateThread(openStaff) end, false)
if Config.StaffKey ~= '' then
    RegisterKeyMapping(Config.StaffCommand, 'Reports openen (staff)', 'keyboard', Config.StaffKey)
end

CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Meld iets bij staff (speler, bug, vraag)', {
        { name = 'bericht', help = 'Optioneel: je bericht' },
    })
    TriggerEvent('chat:addSuggestion', '/' .. Config.StaffCommand, 'Open het reportpaneel (staff)')
end)

-- ------------------------------------------------------------
--  Events van de server
-- ------------------------------------------------------------

-- speler: update over eigen report
RegisterNetEvent('dv-reports:client:update', function(report, toast, kind)
    nui('myReport', { report = report, toast = toast, kind = kind })
    if toast then PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true) end
end)

-- staff: melding
RegisterNetEvent('dv-reports:client:notify', function(msg, kind, count, sound)
    nui('toast', { msg = msg, kind = kind })
    nui('count', { count = count })
    if sound then PlaySoundFrontend(-1, 'ATM_WINDOW', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
end)

-- staff: lijst verversen als het paneel open is
RegisterNetEvent('dv-reports:client:changed', function(id, count)
    nui('changed', { id = id, count = count })
end)

RegisterNetEvent('dv-reports:client:teleport', function(coords)
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
end)

-- ------------------------------------------------------------
--  NUI
-- ------------------------------------------------------------

RegisterNUICallback('call', function(d, cb)
    CreateThread(function()
        cb(call(d.name, d.data or {}))
    end)
end)

RegisterNUICallback('close', function(_, cb)
    setPanel(nil)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and panel then SetNuiFocus(false, false) end
end)
