-- ============================================================
--  nijmegen-cinematics  |  client
-- ============================================================

local editorOpen = false
local mode = 'camera'          -- 'camera' (vliegen) of 'mouse' (menu bedienen)
local playing = false
local stopRequested = false

local fc = { cam = nil, pos = nil, rot = nil, fov = Config.DefaultFov, speed = Config.Speed, origin = nil }
local preview = {}             -- instellingen die live getoond worden in de editor

-- ------------------------------------------------------------
--  Server-aanroepen met antwoord
-- ------------------------------------------------------------

local reqId, pending = 0, {}

local function call(action, data)
    reqId = reqId + 1
    local id = reqId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('nijmegen-cinematics:server:call', id, action, data or {})
    SetTimeout(10000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ ok = false })
        end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('nijmegen-cinematics:client:reply', function(id, res)
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
--  Wiskunde
-- ------------------------------------------------------------

local EASE = {
    linear = function(t) return t end,
    ['in'] = function(t) return t * t end,
    out = function(t) return 1 - (1 - t) * (1 - t) end,
    inout = function(t) return t < 0.5 and 2 * t * t or 1 - ((-2 * t + 2) ^ 2) / 2 end,
}

local function lerp(a, b, t) return a + (b - a) * t end

local function catmull(p0, p1, p2, p3, t)
    local t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local KEYS = { 'x', 'y', 'z', 'rx', 'ry', 'rz', 'fov' }

--- Hoeken zo aanpassen dat de camera altijd de korte kant op draait.
local function unwrap(points)
    for i = 2, #points do
        for _, k in ipairs({ 'rx', 'ry', 'rz' }) do
            local prev, v = points[i - 1][k], points[i][k]
            while v - prev > 180 do v = v - 360 end
            while v - prev < -180 do v = v + 360 end
            points[i][k] = v
        end
    end
end

local function copyPoints(src)
    local out = {}
    for i, p in ipairs(src) do
        out[i] = {
            x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0,
            rx = p.rx + 0.0, ry = (p.ry or 0) + 0.0, rz = p.rz + 0.0,
            fov = (p.fov or Config.DefaultFov) + 0.0,
            dur = math.max(0.1, tonumber(p.dur) or Config.DefaultDuration),
            hold = math.max(0, tonumber(p.hold) or 0),
            ease = EASE[p.ease] and p.ease or 'inout',
        }
    end
    return out
end

-- ------------------------------------------------------------
--  Effecten (filter, tijd, weer, speler)
-- ------------------------------------------------------------

local applied = {}

local function applyEffects(s)
    if s.filter and s.filter ~= '' then
        SetTimecycleModifier(s.filter)
        SetTimecycleModifierStrength((s.strength or 1.0) + 0.0)
        applied.filter = true
    elseif applied.filter then
        ClearTimecycleModifier()
        applied.filter = false
    end
    if s.time and s.time >= 0 then
        NetworkOverrideClockTime(s.time, 0, 0)
        applied.time = true
    elseif applied.time then
        NetworkClearClockTimeOverride()
        applied.time = false
    end
    if s.weather and s.weather ~= '' then
        SetOverrideWeather(s.weather)
        applied.weather = true
    elseif applied.weather then
        ClearOverrideWeather()
        applied.weather = false
    end
end

local function clearEffects()
    if applied.filter then ClearTimecycleModifier() end
    if applied.time then NetworkClearClockTimeOverride() end
    if applied.weather then ClearOverrideWeather() end
    applied = {}
end

-- ------------------------------------------------------------
--  Freecam
-- ------------------------------------------------------------

local function camState()
    return {
        x = fc.pos.x, y = fc.pos.y, z = fc.pos.z,
        rx = fc.rot.x, ry = fc.rot.y, rz = fc.rot.z,
        fov = fc.fov,
    }
end

local function setFreecam(p)
    fc.pos = vector3(p.x, p.y, p.z)
    fc.rot = vector3(p.rx, p.ry or 0.0, p.rz)
    fc.fov = p.fov or fc.fov
    if fc.cam then
        SetCamCoord(fc.cam, fc.pos.x, fc.pos.y, fc.pos.z)
        SetCamRot(fc.cam, fc.rot.x, fc.rot.y, fc.rot.z, 2)
        SetCamFov(fc.cam, fc.fov)
    end
end

local function startFreecam()
    local ped = PlayerPedId()
    fc.origin = GetEntityCoords(ped)
    fc.pos = GetGameplayCamCoord()
    fc.rot = GetGameplayCamRot(2)
    fc.rot = vector3(fc.rot.x, 0.0, fc.rot.z)
    fc.fov = Config.DefaultFov
    fc.speed = Config.Speed
    fc.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', fc.pos.x, fc.pos.y, fc.pos.z, fc.rot.x, fc.rot.y, fc.rot.z, fc.fov, true, 2)
    SetCamActive(fc.cam, true)
    RenderScriptCams(true, true, 600, true, true)
    FreezeEntityPosition(ped, true)
end

local function stopFreecam()
    if fc.cam then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(fc.cam, false)
        fc.cam = nil
    end
    ClearFocus()
    FreezeEntityPosition(PlayerPedId(), false)
end

local function setMode(m)
    mode = m
    SetNuiFocus(m == 'mouse', m == 'mouse')
    nui('mode', { mode = m })
end

local function addKeyframe()
    local p = camState()
    p.dur = Config.DefaultDuration
    p.hold = 0
    p.ease = Config.DefaultEase
    nui('addPoint', p)
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function freecamFrame()
    DisableAllControlActions(0)
    EnableControlAction(0, 249, true)   -- push-to-talk
    HideHudAndRadarThisFrame()

    if mode == 'camera' then
        -- kijken
        local mx = GetDisabledControlNormal(0, 1) * Config.Sensitivity
        local my = GetDisabledControlNormal(0, 2) * Config.Sensitivity
        local rx = math.max(-89.0, math.min(89.0, fc.rot.x - my))
        local rz = fc.rot.z - mx
        local ry = fc.rot.y
        if IsDisabledControlPressed(0, 174) then ry = ry - 45.0 * GetFrameTime() end   -- pijl links: kantelen
        if IsDisabledControlPressed(0, 175) then ry = ry + 45.0 * GetFrameTime() end   -- pijl rechts
        if IsDisabledControlJustPressed(0, 73) then ry = 0.0 end                       -- X: recht zetten
        fc.rot = vector3(rx, ry, rz)

        -- zoom (scroll)
        if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then fc.fov = math.min(130.0, fc.fov + 2.0) end
        if IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then fc.fov = math.max(5.0, fc.fov - 2.0) end

        -- snelheid (pijl omhoog/omlaag)
        if IsDisabledControlJustPressed(0, 172) then fc.speed = math.min(10.0, fc.speed * 1.25) end
        if IsDisabledControlJustPressed(0, 173) then fc.speed = math.max(0.02, fc.speed / 1.25) end

        -- bewegen
        local rad = math.pi / 180
        local cx, cz = math.cos(rx * rad), rz * rad
        local fwd = vector3(-math.sin(cz) * math.abs(cx), math.cos(cz) * math.abs(cx), math.sin(rx * rad))
        local right = vector3(math.cos(cz), math.sin(cz), 0.0)
        local move = vector3(0.0, 0.0, 0.0)
        if IsDisabledControlPressed(0, 32) then move = move + fwd end
        if IsDisabledControlPressed(0, 33) then move = move - fwd end
        if IsDisabledControlPressed(0, 35) then move = move + right end
        if IsDisabledControlPressed(0, 34) then move = move - right end
        if IsDisabledControlPressed(0, 38) then move = move + vector3(0.0, 0.0, 1.0) end   -- E
        if IsDisabledControlPressed(0, 44) then move = move - vector3(0.0, 0.0, 1.0) end   -- Q
        local mult = IsDisabledControlPressed(0, 21) and Config.FastMultiplier or (IsDisabledControlPressed(0, 19) and Config.SlowMultiplier or 1.0)
        local newPos = fc.pos + move * (fc.speed * mult * GetFrameTime() * 60.0)

        if Config.MaxDistance > 0 and #(newPos - fc.origin) > Config.MaxDistance then
            notify(L('too_far'), 'error')
        else
            fc.pos = newPos
        end

        -- sneltoetsen
        if IsDisabledControlJustPressed(0, 22) then addKeyframe() end                  -- Spatie
        if IsDisabledControlJustPressed(0, 178) then nui('removeLast', {}) end         -- Delete
        if IsDisabledControlJustPressed(0, 47) then nui('requestPlay', {}) end         -- G
        if IsDisabledControlJustPressed(0, 37) or IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
            setMode('mouse')                                                           -- TAB / ESC
        end
    end

    SetCamCoord(fc.cam, fc.pos.x, fc.pos.y, fc.pos.z)
    SetCamRot(fc.cam, fc.rot.x, fc.rot.y, fc.rot.z, 2)
    SetCamFov(fc.cam, fc.fov)
    SetFocusPosAndVel(fc.pos.x, fc.pos.y, fc.pos.z, 0.0, 0.0, 0.0)
    if preview.dof then SetUseHiDof() end
end

-- ------------------------------------------------------------
--  Pad (gedeeld door afspelen, voorvertoning en 3D-weergave)
-- ------------------------------------------------------------

--- Bouwt de tijdlijn van een scène. Geeft nil bij minder dan 2 punten.
local function buildPath(scene, startIndex)
    local points = copyPoints(scene.points or {})
    if #points < 2 then return nil end
    local s = scene.settings or {}
    startIndex = math.max(1, math.min(#points - 1, tonumber(startIndex) or 1))

    -- loop: eerste punt nog een keer achteraan, zodat de camera netjes terug vliegt
    if s.loop then
        local f = points[1]
        points[#points + 1] = { x = f.x, y = f.y, z = f.z, rx = f.rx, ry = f.ry, rz = f.rz, fov = f.fov, dur = f.dur, hold = f.hold, ease = f.ease }
    end
    unwrap(points)

    -- per stuk eerst 'hold' op het punt, dan 'dur' reizen naar het volgende
    local segs, total = {}, 0.0
    for i = startIndex, #points - 1 do
        segs[#segs + 1] = { a = i, b = i + 1, start = total, hold = points[i].hold, dur = points[i].dur }
        total = total + points[i].hold + points[i].dur
    end
    if not s.loop then total = total + points[#points].hold end
    return { points = points, segs = segs, total = total, s = s }
end

--- Camera-positie op tijdstip t (seconden) langs het pad.
local function stateAt(path, t)
    local points, segs, s = path.points, path.segs, path.s
    local seg = segs[#segs]
    for _, sg in ipairs(segs) do
        if t < sg.start + sg.hold + sg.dur then seg = sg break end
    end
    local localT = t - seg.start
    local a, b = points[seg.a], points[seg.b]
    if localT <= seg.hold then return a end
    local k = EASE[a.ease](math.min(1.0, (localT - seg.hold) / seg.dur))
    local out = {}
    if s.smooth ~= false and #points > 2 then
        local n = #points
        local p0, p3 = points[math.max(1, seg.a - 1)], points[math.min(n, seg.b + 1)]
        for _, key in ipairs(KEYS) do out[key] = catmull(p0[key], a[key], b[key], p3[key], k) end
    else
        for _, key in ipairs(KEYS) do out[key] = lerp(a[key], b[key], k) end
    end
    return out
end

--- Scherptediepte (onscherpe achtergrond) op een camera.
local function applyDof(cam, s)
    if s and s.dof then
        local focus = math.max(0.5, tonumber(s.dofFocus) or 8.0)
        SetCamUseShallowDofMode(cam, true)
        SetCamNearDof(cam, focus * 0.55)
        SetCamFarDof(cam, focus * 1.6)
        SetCamDofStrength(cam, math.max(0.0, math.min(1.0, tonumber(s.dofStrength) or 0.8)))
        return true
    end
    SetCamUseShallowDofMode(cam, false)
    return false
end

-- ------------------------------------------------------------
--  Afspelen
-- ------------------------------------------------------------

--- Speelt een scène af. Blokkeert tot het klaar of gestopt is.
local function playScene(scene, startIndex)
    if playing then return end
    local path = buildPath(scene, startIndex)
    if not path then return notify(L('need_points'), 'error') end
    local s, total = path.s, path.total

    playing = true
    stopRequested = false
    local ped = PlayerPedId()
    local wasEditor = editorOpen

    if s.fade ~= false then
        DoScreenFadeOut(400)
        while not IsScreenFadedOut() do Wait(0) end
    end

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    if s.shake and s.shake ~= '' and (s.shakeAmp or 0) > 0 then ShakeCam(cam, s.shake, s.shakeAmp + 0.0) end
    local dof = applyDof(cam, s)
    applyEffects(s)
    if s.hidePlayer then SetEntityVisible(ped, false, false) end
    FreezeEntityPosition(ped, true)

    Config.OnStart()
    TriggerEvent('nijmegen-cinematics:started', scene.name)
    local marks = {}
    for _, sg in ipairs(path.segs) do marks[#marks + 1] = sg.start / math.max(total, 0.01) end
    nui('playStart', { bars = s.bars or 0, total = total, marks = marks, name = scene.name, editor = wasEditor, texts = scene.texts or {}, loop = s.loop })

    local first = stateAt(path, 0.0)
    SetCamCoord(cam, first.x, first.y, first.z)
    SetCamRot(cam, first.rx, first.ry, first.rz, 2)
    SetCamFov(cam, first.fov)
    SetFocusPosAndVel(first.x, first.y, first.z, 0.0, 0.0, 0.0)
    Wait(300)   -- wereld laten laden
    if s.fade ~= false then DoScreenFadeIn(600) end

    local startTime = GetGameTimer()
    local lastUi = 0
    while not stopRequested do
        local t = (GetGameTimer() - startTime) / 1000.0
        if t >= total then
            if s.loop then
                startTime = GetGameTimer()
                t = 0.0
            else
                break
            end
        end
        local st = stateAt(path, t)
        SetCamCoord(cam, st.x, st.y, st.z)
        SetCamRot(cam, st.rx, st.ry, st.rz, 2)
        SetCamFov(cam, st.fov)
        SetFocusPosAndVel(st.x, st.y, st.z, 0.0, 0.0, 0.0)
        if dof then SetUseHiDof() end

        DisableAllControlActions(0)
        EnableControlAction(0, 249, true)
        if s.hideHud ~= false and Config.HideHud then HideHudAndRadarThisFrame() end
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then
            stopRequested = true
        end
        if GetGameTimer() - lastUi > 50 then
            lastUi = GetGameTimer()
            nui('progress', { t = t, total = total })
        end
        Wait(0)
    end

    if s.fade ~= false then
        DoScreenFadeOut(400)
        while not IsScreenFadedOut() do Wait(0) end
    end
    StopCamShaking(cam, true)
    DestroyCam(cam, false)
    clearEffects()
    if s.hidePlayer then SetEntityVisible(ped, true, false) end
    nui('playStop', {})
    Config.OnStop()
    TriggerEvent('nijmegen-cinematics:stopped', scene.name)

    if editorOpen and fc.cam then
        SetCamActive(fc.cam, true)
        RenderScriptCams(true, false, 0, true, true)
        applyEffects(preview)
    else
        RenderScriptCams(false, false, 0, true, true)
        ClearFocus()
        FreezeEntityPosition(ped, false)
    end
    if s.fade ~= false then DoScreenFadeIn(500) end
    playing = false
end

-- ------------------------------------------------------------
--  3D-weergave in de editor: keyframes en pad in de wereld
-- ------------------------------------------------------------

local editorScene = nil      -- laatste scène uit de editor
local editorPath = nil       -- tijdlijn daarvan (voor pad en schuifbalk)
local selectedPoint = nil

local function hexToRgb(hex)
    local n = tonumber((hex or '#ff8c1a'):sub(2), 16) or 0xff8c1a
    return (n >> 16) & 255, (n >> 8) & 255, n & 255
end
local AR, AG, AB = hexToRgb(Config.Accent)

local function draw3DText(x, y, z, text, scale, r, g, b)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(r, g, b, 255)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        if editorOpen and not playing and editorScene and (editorScene.settings or {}).showPath ~= false then
            local pts = editorScene.points or {}
            local rad = math.pi / 180
            for i, p in ipairs(pts) do
                local sel = selectedPoint == i
                local r, g, b = AR, AG, AB
                if sel then r, g, b = 255, 255, 255 end
                DrawMarker(28, p.x, p.y, p.z, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, r, g, b, 200, false, false, 2, false, nil, nil, false)
                -- kijkrichting van de camera
                local cx = math.cos(p.rx * rad)
                local fx, fy, fz = -math.sin(p.rz * rad) * math.abs(cx), math.cos(p.rz * rad) * math.abs(cx), math.sin(p.rx * rad)
                DrawLine(p.x, p.y, p.z, p.x + fx * 1.5, p.y + fy * 1.5, p.z + fz * 1.5, r, g, b, 255)
                draw3DText(p.x, p.y, p.z + 0.35, ('%d'):format(i), sel and 0.55 or 0.45, r, g, b)
                if sel then
                    draw3DText(p.x, p.y, p.z + 0.18, ('%.1fs · FOV %d'):format(p.dur or 0, math.floor(p.fov or 50)), 0.3, 255, 255, 255)
                end
            end
            -- het pad zelf
            if editorPath then
                local steps = math.min(400, math.max(20, math.floor(editorPath.total * 12)))
                local prev = stateAt(editorPath, 0.0)
                for i = 1, steps do
                    local cur = stateAt(editorPath, editorPath.total * i / steps)
                    DrawLine(prev.x, prev.y, prev.z, cur.x, cur.y, cur.z, AR, AG, AB, 170)
                    prev = cur
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- ------------------------------------------------------------
--  Editor openen / sluiten
-- ------------------------------------------------------------

local function openEditor()
    if editorOpen or playing then return end
    local res = call('open')
    if not res.ok then return notify(res.msg or L('no_access'), 'error') end
    editorOpen = true
    startFreecam()
    nui('open', {
        locale = Config.Locale,
        accent = Config.Accent,
        filters = Config.Filters,
        shakes = Config.Shakes,
        weathers = Config.Weathers,
        defaults = { dur = Config.DefaultDuration, ease = Config.DefaultEase },
        broadcast = res.broadcast,
    })
    setMode('camera')

    CreateThread(function()
        local lastInfo = 0
        while editorOpen do
            if not playing then
                freecamFrame()
                if GetGameTimer() - lastInfo > 150 then
                    lastInfo = GetGameTimer()
                    nui('camInfo', {
                        fov = fc.fov, speed = fc.speed, roll = fc.rot.y,
                        x = fc.pos.x, y = fc.pos.y, z = fc.pos.z,
                        dist = #(fc.pos - fc.origin),
                    })
                end
            end
            Wait(0)
        end
    end)
end

local function closeEditor()
    if not editorOpen then return end
    editorOpen = false
    stopRequested = true
    SetNuiFocus(false, false)
    nui('close', {})
    clearEffects()
    preview = {}
    stopFreecam()
end

RegisterCommand(Config.Command, function()
    if editorOpen then closeEditor() else CreateThread(openEditor) end
end, false)
if Config.Key ~= '' then
    RegisterKeyMapping(Config.Command, 'Cinematic maker', 'keyboard', Config.Key)
end

-- ------------------------------------------------------------
--  NUI callbacks
-- ------------------------------------------------------------

RegisterNUICallback('mode', function(d, cb)
    setMode(d.mode == 'mouse' and 'mouse' or 'camera')
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    closeEditor()
    cb('ok')
end)

RegisterNUICallback('capture', function(_, cb)
    cb(fc.pos and camState() or false)
end)

RegisterNUICallback('goto', function(p, cb)
    if fc.cam and p and p.x then setFreecam(p) end
    cb('ok')
end)

RegisterNUICallback('preview', function(s, cb)
    preview = s or {}
    if editorOpen and not playing then
        applyEffects(preview)
        if fc.cam then applyDof(fc.cam, preview) end
    end
    cb('ok')
end)

-- editor stuurt de scène bij elke wijziging (voor 3D-weergave en schuifbalk)
RegisterNUICallback('scene', function(d, cb)
    editorScene = d.scene
    selectedPoint = d.selected and (d.selected + 1) or nil
    editorPath = editorScene and buildPath(editorScene, 1) or nil
    cb({ total = editorPath and editorPath.total or 0 })
end)

-- schuifbalk: camera naar tijdstip t op het pad
RegisterNUICallback('scrub', function(d, cb)
    if editorOpen and not playing and editorPath and fc.cam then
        local st = stateAt(editorPath, math.max(0.0, math.min(editorPath.total, tonumber(d.t) or 0.0)))
        setFreecam(st)
    end
    cb('ok')
end)

RegisterNUICallback('play', function(d, cb)
    cb('ok')
    if not d.scene then return end
    SetNuiFocus(false, false)
    CreateThread(function()
        playScene(d.scene, d.from)
        if editorOpen then setMode('mouse') end
    end)
end)

RegisterNUICallback('call', function(d, cb)
    CreateThread(function() cb(call(d.name, d.data or {})) end)
end)

-- ------------------------------------------------------------
--  Afspelen vanaf de server of andere scripts
-- ------------------------------------------------------------

RegisterNetEvent('nijmegen-cinematics:client:play', function(scene)
    if editorOpen or playing then return end
    CreateThread(function() playScene(scene) end)
end)

--- exports['nijmegen-cinematics']:Play(scene)   (scene = tabel zoals opgeslagen)
exports('Play', function(scene)
    if playing then return false end
    CreateThread(function() playScene(scene) end)
    return true
end)
exports('Stop', function() stopRequested = true end)
exports('IsPlaying', function() return playing end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if editorOpen or playing then
        SetNuiFocus(false, false)
        RenderScriptCams(false, false, 0, true, true)
        ClearFocus()
        clearEffects()
        FreezeEntityPosition(PlayerPedId(), false)
        SetEntityVisible(PlayerPedId(), true, false)
        DoScreenFadeIn(0)
    end
end)
