-- ============================================================
--  dv-hud  |  client
-- ============================================================

local framework = 'standalone'
local QBCore, ESX
local fuelSystem = 'native'

local playerLoaded = false
local hudHidden = false        -- /togglehud
local cinematic = false        -- /cinema
local settingsOpen = false

local needs = { hunger = false, thirst = false, stress = false }
local info = { cash = false, bank = false, job = false }

local seatbelt = false
local voiceMode = 2
local radioTalking = false

local inVehicle = false
local currentVehicle = 0

-- ------------------------------------------------------------
--  Helpers
-- ------------------------------------------------------------

local cache = {}

--- Stuurt alleen gewijzigde waarden naar de NUI.
local function push(action, data)
    local c = cache[action]
    if not c then c = {}; cache[action] = c end
    local changed, any = {}, false
    for k, v in pairs(data) do
        if c[k] ~= v then
            c[k] = v
            changed[k] = v
            any = true
        end
    end
    if any then
        SendNUIMessage({ action = action, data = changed })
    end
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function round(n, dec)
    local m = 10 ^ (dec or 0)
    return math.floor(n * m + 0.5) / m
end

local function clamp(n, lo, hi)
    if n < lo then return lo elseif n > hi then return hi end
    return n
end

local function started(res)
    return GetResourceState(res) == 'started'
end

local function refreshVisibility()
    local visible = playerLoaded and not hudHidden and not cinematic and not IsPauseMenuActive()
    push('visible', { hud = visible, cinematic = cinematic })
end

-- ------------------------------------------------------------
--  Framework
-- ------------------------------------------------------------

local function applyQBData(pd)
    if not pd then return end
    local md = pd.metadata or {}
    if md.hunger then needs.hunger = md.hunger end
    if md.thirst then needs.thirst = md.thirst end
    if md.stress then needs.stress = md.stress end
    if pd.money then
        info.cash = pd.money.cash or false
        info.bank = pd.money.bank or false
    end
    if pd.job then
        local grade = pd.job.grade and pd.job.grade.name
        info.job = pd.job.label .. (grade and (' · ' .. grade) or '')
    end
end

local function applyESXData(pd)
    if not pd then return end
    for _, acc in ipairs(pd.accounts or {}) do
        if acc.name == 'money' then info.cash = acc.money end
        if acc.name == 'bank' then info.bank = acc.money end
    end
    if pd.job then
        info.job = pd.job.label .. (pd.job.grade_label and (' · ' .. pd.job.grade_label) or '')
    end
end

local function detectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if started('qbx_core') then return 'qbx' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    return 'standalone'
end

local function detectFuel()
    if Config.FuelSystem ~= 'auto' then return Config.FuelSystem end
    for _, res in ipairs({ 'ox_fuel', 'LegacyFuel', 'ps-fuel', 'cdn-fuel', 'lj-fuel' }) do
        if started(res) then return res end
    end
    return 'native'
end

local function getFuel(veh)
    if fuelSystem == 'ox_fuel' then
        local v = Entity(veh).state.fuel
        if v then return v end
    elseif fuelSystem ~= 'native' then
        local ok, v = pcall(function() return exports[fuelSystem]:GetFuel(veh) end)
        if ok and v then return v end
    end
    return GetVehicleFuelLevel(veh)
end

-- QBCore / Qbox
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if framework == 'qb' then
        applyQBData(QBCore.Functions.GetPlayerData())
    elseif framework == 'qbx' then
        applyQBData(exports.qbx_core:GetPlayerData())
    end
    playerLoaded = true
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() playerLoaded = false end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(pd) applyQBData(pd) end)

RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst)
    needs.hunger = hunger
    needs.thirst = thirst
end)

RegisterNetEvent('hud:client:UpdateStress', function(stress)
    needs.stress = stress
end)

-- ESX
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    applyESXData(xPlayer)
    playerLoaded = true
end)

RegisterNetEvent('esx:onPlayerLogout', function() playerLoaded = false end)

RegisterNetEvent('esx:setAccountMoney', function(account)
    if account.name == 'money' then info.cash = account.money end
    if account.name == 'bank' then info.bank = account.money end
end)

RegisterNetEvent('esx:setJob', function(job)
    info.job = job.label .. (job.grade_label and (' · ' .. job.grade_label) or '')
end)

AddEventHandler('esx_status:onTick', function(data)
    for _, s in ipairs(data) do
        if s.name == 'hunger' then needs.hunger = s.percent end
        if s.name == 'thirst' then needs.thirst = s.percent end
        if s.name == 'stress' then needs.stress = s.percent end
    end
end)

-- Standalone / andere scripts: exports['dv-hud']:SetStatus('hunger', 80)
local function setStatus(name, value)
    if needs[name] ~= nil then needs[name] = value end
end
exports('SetStatus', setStatus)
RegisterNetEvent('dv-hud:client:setStatus', setStatus)

-- ------------------------------------------------------------
--  Voice (pma-voice)
-- ------------------------------------------------------------

AddEventHandler('pma-voice:setTalkingMode', function(mode) voiceMode = mode end)
AddEventHandler('pma-voice:radioActive', function(active) radioTalking = active end)

-- ------------------------------------------------------------
--  Gordel
-- ------------------------------------------------------------

local NO_BELT_CLASSES = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

local function hasBelt(veh)
    return veh ~= 0 and not NO_BELT_CLASSES[GetVehicleClass(veh)]
end

local function setSeatbelt(state)
    seatbelt = state
    send('seatbelt', { on = state })
end

exports('IsSeatbeltOn', function() return seatbelt end)

if Config.Seatbelt.enabled then
    RegisterCommand('dvseatbelt', function()
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if not hasBelt(veh) then return end
        setSeatbelt(not seatbelt)
    end, false)
    RegisterKeyMapping('dvseatbelt', 'Gordel om/af', 'keyboard', Config.Seatbelt.key)
else
    -- compatibel met qb-smallresources en vergelijkbare scripts
    RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function(state)
        if state == nil then state = not seatbelt end
        setSeatbelt(state)
    end)
end

-- ------------------------------------------------------------
--  Minimap
-- ------------------------------------------------------------

local function getMinimapAnchor()
    local safezone = GetSafeZoneSize()
    local sz = 1.0 / 20.0
    local aspect = GetAspectRatio(false)
    if aspect > 2 then aspect = 16 / 9 end
    local resX, resY = GetActiveScreenResolution()
    local xs, ys = 1.0 / resX, 1.0 / resY
    local width = xs * (resX / (4 * aspect))
    local height = ys * (resY / 5.674)
    local left = xs * (resX * (sz * (math.abs(safezone - 1.0) * 10)))
    local bottom = 1.0 - ys * (resY * (sz * (math.abs(safezone - 1.0) * 10)))
    return {
        left = round(left, 4),
        right = round(left + width, 4),
        top = round(bottom - height, 4),
        bottom = round(bottom, 4),
    }
end

-- ------------------------------------------------------------
--  Commando's & NUI
-- ------------------------------------------------------------

RegisterCommand(Config.Commands.settings, function()
    settingsOpen = true
    SetNuiFocus(true, true)
    send('openSettings', {})
end, false)

RegisterCommand(Config.Commands.cinematic, function()
    cinematic = not cinematic
    refreshVisibility()
end, false)

RegisterCommand(Config.Commands.toggle, function()
    hudHidden = not hudHidden
    refreshVisibility()
end, false)

RegisterNUICallback('closeSettings', function(_, cb)
    settingsOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and settingsOpen then
        SetNuiFocus(false, false)
    end
end)

-- ------------------------------------------------------------
--  Opstarten
-- ------------------------------------------------------------

CreateThread(function()
    framework = detectFramework()
    fuelSystem = detectFuel()

    if framework == 'qb' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    end

    local frameworkNeeds = framework ~= 'standalone'
    if frameworkNeeds then
        needs.hunger, needs.thirst = 100, 100
        needs.stress = 0
    end

    send('init', {
        framework = framework,
        speedUnit = Config.SpeedUnit,
        lowFuel = Config.LowFuel,
        seatbelt = true,
    })

    -- herstart van de resource terwijl je al ingelogd bent
    if framework == 'qb' then
        if LocalPlayer.state.isLoggedIn then
            applyQBData(QBCore.Functions.GetPlayerData())
            playerLoaded = true
        end
    elseif framework == 'qbx' then
        if LocalPlayer.state.isLoggedIn then
            applyQBData(exports.qbx_core:GetPlayerData())
            playerLoaded = true
        end
    elseif framework == 'esx' then
        if ESX.IsPlayerLoaded() then
            applyESXData(ESX.GetPlayerData())
            playerLoaded = true
        end
    else
        while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
        playerLoaded = true
    end

    -- standaard health/armor balkjes onder de minimap verbergen
    local minimap = RequestScaleformMovie('minimap')
    while not HasScaleformMovieLoaded(minimap) do Wait(0) end
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(3)
    EndScaleformMovieMethod()
end)

-- ------------------------------------------------------------
--  Frame-thread: native HUD verbergen + gordel
-- ------------------------------------------------------------

CreateThread(function()
    local lastSpeed = 0.0
    local lastVelocity = vector3(0.0, 0.0, 0.0)

    while true do
        HideHudComponentThisFrame(3)  -- cash
        HideHudComponentThisFrame(4)  -- mp cash
        HideHudComponentThisFrame(6)  -- voertuignaam
        HideHudComponentThisFrame(7)  -- gebied
        HideHudComponentThisFrame(8)  -- voertuigklasse
        HideHudComponentThisFrame(9)  -- straatnaam
        HideHudComponentThisFrame(13) -- cash verandering

        if cinematic then
            HideHudAndRadarThisFrame()
        end

        if inVehicle and Config.Seatbelt.enabled and hasBelt(currentVehicle) then
            local ped = PlayerPedId()
            if seatbelt then
                DisableControlAction(0, 75, true)  -- uitstappen
                DisableControlAction(27, 75, true)
            end

            local speed = GetEntitySpeed(currentVehicle)
            if Config.Seatbelt.eject and not seatbelt
                and lastSpeed * 3.6 > Config.Seatbelt.ejectMinSpeed
                and (lastSpeed - speed) > lastSpeed * Config.Seatbelt.ejectDecel
                and GetEntitySpeedVector(currentVehicle, true).y > 1.0 then
                local coords = GetEntityCoords(ped)
                local fwd = GetEntityForwardVector(ped)
                SetEntityCoords(ped, coords.x + fwd.x, coords.y + fwd.y, coords.z - 0.47, true, true, true, false)
                SetEntityVelocity(ped, lastVelocity.x, lastVelocity.y, lastVelocity.z)
                Wait(1)
                SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
            end
            lastSpeed = speed
            lastVelocity = GetEntityVelocity(currentVehicle)
            Wait(0)
        else
            lastSpeed = 0.0
            Wait(0)
        end
    end
end)

-- ------------------------------------------------------------
--  Status + voertuig
-- ------------------------------------------------------------

local function vehicleType(veh)
    local class = GetVehicleClass(veh)
    if class == 15 or class == 16 then return 'air' end
    if class == 14 then return 'boat' end
    if class == 8 or class == 13 then return 'bike' end
    return 'car'
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pid = PlayerId()
        local veh = GetVehiclePedIsIn(ped, false)

        local wasInVehicle = inVehicle
        inVehicle = veh ~= 0
        currentVehicle = veh

        if wasInVehicle and not inVehicle and seatbelt then
            setSeatbelt(false)
        end

        refreshVisibility()
        local radarOn = playerLoaded and not cinematic and (inVehicle or not Config.MinimapOnlyInVehicle)
        DisplayRadar(radarOn)
        push('minimap', { visible = radarOn })

        local maxHealth = GetEntityMaxHealth(ped) - 100
        local health = maxHealth > 0 and clamp((GetEntityHealth(ped) - 100) / maxHealth * 100, 0, 100) or 0
        local underwater = IsPedSwimmingUnderWater(ped)

        push('status', {
            health = math.floor(health + 0.5),
            armor = GetPedArmour(ped),
            hunger = needs.hunger and math.floor(needs.hunger + 0.5) or false,
            thirst = needs.thirst and math.floor(needs.thirst + 0.5) or false,
            stress = needs.stress and math.floor(needs.stress + 0.5) or false,
            stamina = math.floor(100 - GetPlayerSprintStaminaRemaining(pid) + 0.5),
            oxygen = underwater and math.floor(clamp(GetPlayerUnderwaterTimeRemaining(pid) * 10, 0, 100)) or false,
            talking = NetworkIsPlayerTalking(pid),
            radio = radioTalking,
            voiceMode = voiceMode,
            dead = IsEntityDead(ped),
        })

        if inVehicle then
            local _, lightsOn, highbeams = GetVehicleLightsState(veh)
            local gear = GetVehicleCurrentGear(veh)
            local speed = GetEntitySpeed(veh) * 3.6
            local vType = vehicleType(veh)
            push('vehicle', {
                inVehicle = true,
                type = vType,
                speed = math.floor(speed + 0.5),
                rpm = round(GetIsVehicleEngineRunning(veh) and GetVehicleCurrentRpm(veh) or 0, 2),
                gear = gear == 0 and 'R' or (speed < 1 and 'N' or tostring(gear)),
                fuel = math.floor(getFuel(veh) + 0.5),
                engine = math.floor(clamp(GetVehicleEngineHealth(veh) / 10, 0, 100)),
                engineOn = GetIsVehicleEngineRunning(veh),
                lights = lightsOn == 1 or lightsOn == true,
                highbeam = highbeams == 1 or highbeams == true,
                altitude = vType == 'air' and math.floor(GetEntityHeightAboveGround(veh)) or false,
                hasBelt = hasBelt(veh),
            })
        elseif wasInVehicle then
            -- cache legen zodat bij instappen alle waarden opnieuw worden gestuurd
            cache.vehicle = nil
            push('vehicle', { inVehicle = false })
        end

        Wait(inVehicle and Config.Interval.inVehicle or Config.Interval.onFoot)
    end
end)

-- ------------------------------------------------------------
--  Locatie + kompas
-- ------------------------------------------------------------

CreateThread(function()
    while true do
        if playerLoaded then
            local coords = GetEntityCoords(PlayerPedId())
            local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local camRot = GetGameplayCamRot(2)
            push('location', {
                street = GetStreetNameFromHashKey(streetHash),
                cross = crossHash ~= 0 and GetStreetNameFromHashKey(crossHash) or '',
                zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)),
                heading = math.floor((360.0 - camRot.z) % 360.0),
            })
        end
        Wait(inVehicle and 100 or Config.Interval.location)
    end
end)

-- ------------------------------------------------------------
--  Info (tijd, id, geld, baan) + minimap-positie
-- ------------------------------------------------------------

CreateThread(function()
    local tick = 0
    while true do
        push('info', {
            time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
            id = GetPlayerServerId(PlayerId()),
            cash = info.cash,
            bank = info.bank,
            job = info.job,
        })

        if tick % 5 == 0 then
            push('minimap', getMinimapAnchor())
        end
        tick = tick + 1

        Wait(Config.Interval.info)
    end
end)
