-- ============================================================
--  nijmegen-cinematics  |  server
-- ============================================================

local RES = GetCurrentResourceName()
local scenes = json.decode(LoadResourceFile(RES, 'data/scenes.json') or '{}') or {}

local function save()
    SaveResourceFile(RES, 'data/scenes.json', json.encode(scenes), -1)
end

local ESX
CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

local function esxGroup(src)
    local xPlayer = ESX and ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.getGroup() or nil
end

local function hasAccess(src)
    if Config.Everyone then return true end
    for _, ace in ipairs(Config.Aces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    local g = esxGroup(src)
    return g ~= nil and Config.EsxGroups[g] == true
end

local function canBroadcast(src)
    if IsPlayerAceAllowed(src, Config.BroadcastAce) then return true end
    local g = esxGroup(src)
    return g ~= nil and Config.EsxBroadcastGroups[g] == true
end

local function clean(v, max)
    return (tostring(v or ''):gsub('[%c]', ''):sub(1, max or 40))
end

--- Controleert en schoont een scène op (alleen getallen en bekende velden).
local function sanitize(scene)
    if type(scene) ~= 'table' or type(scene.points) ~= 'table' then return nil end
    local out = { name = clean(scene.name, 40), points = {}, settings = {} }
    if out.name == '' then return nil end
    for i, p in ipairs(scene.points) do
        if i > 200 then break end
        local n = {}
        for _, k in ipairs({ 'x', 'y', 'z', 'rx', 'ry', 'rz', 'fov', 'dur', 'hold' }) do
            n[k] = tonumber(p[k]) or 0
        end
        n.fov = math.max(5, math.min(130, n.fov))
        n.dur = math.max(0.1, math.min(120, n.dur))
        n.hold = math.max(0, math.min(60, n.hold))
        n.ease = ({ linear = 1, ['in'] = 1, out = 1, inout = 1 })[p.ease] and p.ease or 'inout'
        out.points[#out.points + 1] = n
    end
    if #out.points < 2 then return nil end
    local s = type(scene.settings) == 'table' and scene.settings or {}
    out.settings = {
        bars = math.max(0, math.min(0.3, tonumber(s.bars) or 0.12)),
        filter = clean(s.filter, 40),
        strength = math.max(0, math.min(1, tonumber(s.strength) or 1)),
        shake = clean(s.shake, 40),
        shakeAmp = math.max(0, math.min(3, tonumber(s.shakeAmp) or 0)),
        smooth = s.smooth ~= false,
        loop = s.loop == true,
        hideHud = s.hideHud ~= false,
        hidePlayer = s.hidePlayer == true,
        time = math.max(-1, math.min(23, math.floor(tonumber(s.time) or -1))),
        weather = clean(s.weather, 20),
        fade = s.fade ~= false,
        dof = s.dof == true,
        dofFocus = math.max(0.5, math.min(200, tonumber(s.dofFocus) or 8)),
        dofStrength = math.max(0, math.min(1, tonumber(s.dofStrength) or 0.8)),
    }

    -- teksten in beeld
    local POS = { ['bottom-center'] = 1, ['bottom-left'] = 1, ['bottom-right'] = 1, ['middle-center'] = 1, ['top-center'] = 1 }
    local SIZE = { s = 1, m = 1, l = 1, xl = 1 }
    out.texts = {}
    for i, t in ipairs(type(scene.texts) == 'table' and scene.texts or {}) do
        if i > 20 then break end
        if type(t) == 'table' then
            out.texts[#out.texts + 1] = {
                title = clean(t.title, 120),
                sub = clean(t.sub, 160),
                start = math.max(0, math.min(600, tonumber(t.start) or 0)),
                dur = math.max(0.5, math.min(120, tonumber(t.dur) or 4)),
                pos = POS[t.pos] and t.pos or 'bottom-center',
                size = SIZE[t.size] and t.size or 'l',
            }
        end
    end
    return out
end

-- ------------------------------------------------------------
--  Aanroepen
-- ------------------------------------------------------------

local Actions = {}

Actions.open = function(src)
    return { ok = true, broadcast = canBroadcast(src) }
end

Actions.list = function()
    local list = {}
    for name, s in pairs(scenes) do
        list[#list + 1] = { name = name, points = #s.points, by = s.by, date = s.date }
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return { ok = true, scenes = list }
end

Actions.load = function(_, d)
    local s = scenes[clean(d.name, 40)]
    if not s then return { ok = false, msg = L('not_found') } end
    return { ok = true, scene = s }
end

Actions.save = function(src, d)
    local s = sanitize(d.scene)
    if not s then return { ok = false, msg = L('need_points') } end
    s.by = GetPlayerName(src)
    s.date = os.date('%d-%m-%Y %H:%M')
    scenes[s.name] = s
    save()
    print(('[nijmegen-cinematics] %s slaat scène "%s" op (%d punten)'):format(s.by, s.name, #s.points))
    return { ok = true, msg = L('saved') }
end

Actions.delete = function(src, d)
    local name = clean(d.name, 40)
    if not scenes[name] then return { ok = false, msg = L('not_found') } end
    scenes[name] = nil
    save()
    print(('[nijmegen-cinematics] %s verwijdert scène "%s"'):format(GetPlayerName(src), name))
    return { ok = true, msg = L('deleted') }
end

Actions.broadcast = function(src, d)
    if not canBroadcast(src) then return { ok = false, msg = L('no_access') } end
    local s = sanitize(d.scene)
    if not s then return { ok = false, msg = L('need_points') } end
    TriggerClientEvent('nijmegen-cinematics:client:play', -1, s)
    print(('[nijmegen-cinematics] %s speelt "%s" af voor iedereen'):format(GetPlayerName(src), s.name))
    return { ok = true, msg = L('broadcast') }
end

local rate = {}
RegisterNetEvent('nijmegen-cinematics:server:call', function(reqId, action, data)
    local src = source
    local now = os.time()
    local r = rate[src]
    if not r or now - r[1] >= 5 then r = { now, 0 }; rate[src] = r end
    r[2] = r[2] + 1

    local res
    if r[2] > 20 then
        res = { ok = false, msg = '...' }
    elseif type(action) ~= 'string' or not Actions[action] then
        res = { ok = false }
    elseif not hasAccess(src) then
        res = { ok = false, msg = L('no_access') }
    else
        local ok, result = pcall(Actions[action], src, type(data) == 'table' and data or {})
        res = ok and result or { ok = false }
        if not ok then print('[nijmegen-cinematics] fout in ' .. action .. ': ' .. tostring(result)) end
    end
    TriggerClientEvent('nijmegen-cinematics:client:reply', src, reqId, res)
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)

-- ------------------------------------------------------------
--  Exports voor andere scripts
-- ------------------------------------------------------------

--- Speel een opgeslagen scène af voor één speler (of -1 = iedereen).
--- exports['nijmegen-cinematics']:PlayScene(source, 'intro')
exports('PlayScene', function(target, name)
    local s = scenes[name]
    if not s then return false end
    TriggerClientEvent('nijmegen-cinematics:client:play', target, s)
    return true
end)

exports('GetScene', function(name) return scenes[name] end)
