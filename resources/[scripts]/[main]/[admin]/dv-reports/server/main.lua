-- ============================================================
--  dv-reports  |  server
-- ============================================================

local WEBHOOK = GetConvar('dvreports_webhook', '')
if WEBHOOK == '' then WEBHOOK = GetConvar('dvadmin_webhook', '') end

local RANKS = { [1] = 'Moderator', [2] = 'Admin', [3] = 'Eigenaar' }

local reports = {}        -- [id] = report
local nextId = 1
local lastReport = {}     -- [src] = os.time() van laatste report
local rate = {}           -- [src] = { tijd, aantal }

-- ------------------------------------------------------------
--  Helpers
-- ------------------------------------------------------------

local function getLevel(src)
    if IsPlayerAceAllowed(src, 'dvadmin.owner') then return 3 end
    if IsPlayerAceAllowed(src, 'dvadmin.admin') then return 2 end
    if IsPlayerAceAllowed(src, 'dvadmin.mod') then return 1 end
    return 0
end

local function isStaff(src) return getLevel(src) >= Config.StaffLevel end

local function name(src) return GetPlayerName(src) or ('ID ' .. tostring(src)) end
local function isOnline(id) return id and GetPlayerName(id) ~= nil end

local function cleanText(v, max)
    return (tostring(v or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, max or 500))
end

local function log(title, raw)
    -- regels mogen nil zijn (optionele info), die slaan we over
    local lines = {}
    for i = 1, 10 do if raw[i] then lines[#lines + 1] = raw[i] end end
    print(('[dv-reports] %s | %s'):format(title, table.concat(lines, ' | ')))
    if WEBHOOK == '' then return end
    PerformHttpRequest(WEBHOOK, function() end, 'POST', json.encode({
        username = 'Dayverse Reports',
        embeds = { {
            title = title,
            color = 16747546,
            description = table.concat(lines, '\n'),
            footer = { text = 'Dayverse Roleplay · ' .. os.date('%d-%m-%Y %H:%M:%S') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end

local function openCount()
    local n = 0
    for _, r in pairs(reports) do if r.status ~= 'closed' then n = n + 1 end end
    return n
end

local function toStaff(event, ...)
    for _, sid in ipairs(GetPlayers()) do
        local id = tonumber(sid)
        if isStaff(id) then TriggerClientEvent(event, id, ...) end
    end
end

local function staffNotify(msg, kind, sound)
    toStaff('dv-reports:client:notify', msg, kind or 'info', openCount(), sound ~= false)
end

local function changed(id)
    toStaff('dv-reports:client:changed', id, openCount())
end

--- Wat de speler zelf van zijn report mag zien.
local function publicReport(r)
    if not r then return nil end
    return {
        id = r.id,
        category = r.category,
        status = r.status,
        claimedBy = r.claimedBy and r.claimedBy.name or nil,
        messages = r.messages,
    }
end

local function playerUpdate(r, toast, kind)
    if not r.offline and isOnline(r.src) then
        TriggerClientEvent('dv-reports:client:update', r.src, publicReport(r), toast, kind)
    end
end

local function addMessage(r, from, author, text)
    r.messages[#r.messages + 1] = { from = from, name = author, text = text, time = os.date('%H:%M') }
    r.updated = os.time()
end

local function openReportOf(src)
    for _, r in pairs(reports) do
        if r.src == src and r.status ~= 'closed' and not r.offline then return r end
    end
end

local function getReport(id)
    local r = reports[tonumber(id)]
    if not r then return nil, 'Report niet gevonden' end
    return r
end

-- ------------------------------------------------------------
--  Acties voor spelers
-- ------------------------------------------------------------

local Public = {}

Public.mine = function(src)
    return { ok = true, report = publicReport(openReportOf(src)), categories = Config.Categories }
end

Public.create = function(src, d)
    if openReportOf(src) then return { ok = false, msg = 'Je hebt al een open report' } end
    local wait = (lastReport[src] or 0) + Config.Cooldown - os.time()
    if wait > 0 then return { ok = false, msg = ('Wacht nog %d seconden'):format(wait) } end

    local message = cleanText(d.message, 500)
    if #message < 5 then return { ok = false, msg = 'Beschrijf je report iets uitgebreider' } end

    local category = Config.Categories[1]
    for _, c in ipairs(Config.Categories) do if c == d.category then category = c end end

    local target
    local tid = tonumber(d.target)
    if tid and isOnline(tid) and tid ~= src then target = { id = tid, name = name(tid) } end

    local r = {
        id = nextId,
        src = src,
        name = name(src),
        category = category,
        target = target,
        status = 'open',
        created = os.time(),
        updated = os.time(),
        messages = {},
    }
    nextId = nextId + 1
    addMessage(r, 'player', r.name, message)
    reports[r.id] = r
    lastReport[src] = os.time()

    log('Nieuwe report #' .. r.id, {
        ('**Speler:** %s (%d)'):format(r.name, src),
        '**Onderwerp:** ' .. category,
        target and ('**Meldt:** %s (%d)'):format(target.name, target.id) or nil,
        '**Bericht:** ' .. message,
    })
    staffNotify(('Nieuwe report #%d van %s: %s'):format(r.id, r.name, message:sub(1, 80)), 'warn')
    changed(r.id)
    return { ok = true, msg = 'Report verstuurd, staff is op de hoogte', report = publicReport(r) }
end

Public.message = function(src, d)
    local r = openReportOf(src)
    if not r then return { ok = false, msg = 'Je hebt geen open report' } end
    local text = cleanText(d.text, 500)
    if text == '' then return { ok = false, msg = 'Leeg bericht' } end
    addMessage(r, 'player', r.name, text)
    if r.claimedBy and isOnline(r.claimedBy.src) then
        TriggerClientEvent('dv-reports:client:notify', r.claimedBy.src,
            ('Report #%d · %s: %s'):format(r.id, r.name, text:sub(1, 80)), 'info', openCount(), true)
    end
    changed(r.id)
    return { ok = true, report = publicReport(r) }
end

Public.cancel = function(src)
    local r = openReportOf(src)
    if not r then return { ok = false, msg = 'Je hebt geen open report' } end
    r.status = 'closed'
    addMessage(r, 'system', nil, 'Ingetrokken door ' .. r.name)
    log('Report #' .. r.id .. ' ingetrokken', { r.name })
    staffNotify(('Report #%d is ingetrokken door %s'):format(r.id, r.name), 'info', false)
    changed(r.id)
    return { ok = true, msg = 'Report ingetrokken' }
end

-- ------------------------------------------------------------
--  Acties voor staff
-- ------------------------------------------------------------

local Staff = {}

Staff.open = function(src)
    local level = getLevel(src)
    return { ok = true, name = name(src), rank = RANKS[level], open = openCount() }
end

Staff.list = function()
    local list = {}
    local cutoff = os.time() - Config.KeepClosedHours * 3600
    for id, r in pairs(reports) do
        if r.status == 'closed' and r.updated < cutoff then
            reports[id] = nil
        else
            list[#list + 1] = {
                id = r.id,
                src = r.src,
                name = r.name,
                online = not r.offline and isOnline(r.src),
                category = r.category,
                target = r.target,
                status = r.status,
                claimedBy = r.claimedBy and r.claimedBy.name or nil,
                created = os.date('%H:%M', r.created),
                age = os.time() - r.created,
                messages = r.messages,
            }
        end
    end
    table.sort(list, function(a, b)
        if (a.status == 'closed') ~= (b.status == 'closed') then return b.status == 'closed' end
        return a.id > b.id
    end)
    return { ok = true, reports = list }
end

Staff.claim = function(src, d)
    local r, err = getReport(d.id)
    if not r then return { ok = false, msg = err } end
    if r.status == 'closed' then return { ok = false, msg = 'Report is al gesloten' } end
    if r.claimedBy and r.claimedBy.src == src then return { ok = true, msg = 'Je had deze report al' } end
    r.status = 'claimed'
    r.claimedBy = { src = src, name = name(src) }
    addMessage(r, 'system', nil, name(src) .. ' heeft de report opgepakt')
    log('Report #' .. r.id .. ' opgepakt', { name(src) })
    playerUpdate(r, name(src) .. ' heeft je report opgepakt', 'success')
    staffNotify(('%s heeft report #%d opgepakt'):format(name(src), r.id), 'info', false)
    changed(r.id)
    return { ok = true, msg = 'Report #' .. r.id .. ' opgepakt' }
end

Staff.reply = function(src, d)
    local r, err = getReport(d.id)
    if not r then return { ok = false, msg = err } end
    if r.status == 'closed' then return { ok = false, msg = 'Report is al gesloten' } end
    local text = cleanText(d.text, 500)
    if text == '' then return { ok = false, msg = 'Leeg bericht' } end
    if not r.claimedBy then
        r.status = 'claimed'
        r.claimedBy = { src = src, name = name(src) }
    end
    addMessage(r, 'staff', name(src), text)
    log('Report #' .. r.id .. ' antwoord', { name(src), text })
    playerUpdate(r, 'Nieuw bericht van ' .. name(src) .. ' over je report', 'info')
    changed(r.id)
    return { ok = true }
end

Staff.close = function(src, d)
    local r, err = getReport(d.id)
    if not r then return { ok = false, msg = err } end
    if r.status == 'closed' then return { ok = false, msg = 'Report is al gesloten' } end
    local note = cleanText(d.note, 300)
    r.status = 'closed'
    addMessage(r, 'system', nil, 'Gesloten door ' .. name(src) .. (note ~= '' and (': ' .. note) or ''))
    log('Report #' .. r.id .. ' gesloten', { name(src), note ~= '' and note or nil })
    playerUpdate(r, 'Je report is afgehandeld door ' .. name(src), 'success')
    changed(r.id)
    return { ok = true, msg = 'Report #' .. r.id .. ' gesloten' }
end

local function teleportAction(src, d, bring)
    local r, err = getReport(d.id)
    if not r then return { ok = false, msg = err } end
    local target = d.who == 'target' and r.target and r.target.id or r.src
    if not isOnline(target) then return { ok = false, msg = 'Speler is offline' } end
    local from, to = target, src
    if bring then from, to = src, target end
    local ped = GetPlayerPed(from)
    if ped == 0 then return { ok = false, msg = 'Positie onbekend' } end
    TriggerClientEvent('dv-reports:client:teleport', to, GetEntityCoords(ped))
    log(('Report #%d %s'):format(r.id, bring and 'speler gehaald' or 'teleport'), { name(src), name(target) })
    return { ok = true, msg = bring and (name(target) .. ' is gehaald') or ('Geteleporteerd naar ' .. name(target)) }
end

Staff['goto'] = function(src, d) return teleportAction(src, d, false) end
Staff.bring = function(src, d) return teleportAction(src, d, true) end

-- ------------------------------------------------------------
--  Aanroepen vanaf de client
-- ------------------------------------------------------------

RegisterNetEvent('dv-reports:server:call', function(reqId, action, data)
    local src = source
    data = type(data) == 'table' and data or {}
    if type(action) ~= 'string' then return end

    local now = os.time()
    local rl = rate[src]
    if not rl or now - rl[1] >= 5 then rl = { now, 0 }; rate[src] = rl end
    rl[2] = rl[2] + 1
    if rl[2] > 25 then
        return TriggerClientEvent('dv-reports:client:reply', src, reqId, { ok = false, msg = 'Rustig aan, te veel acties' })
    end

    local fn, res = Public[action], nil
    if not fn and Staff[action] then
        if isStaff(src) then
            fn = Staff[action]
        else
            res = { ok = false, msg = action == 'open' and 'Alleen staff kan reports bekijken' or 'Geen permissie' }
        end
    end

    if fn then
        local ok, result = pcall(fn, src, data)
        res = ok and result or { ok = false, msg = 'Er ging iets mis' }
        if not ok then print('[dv-reports] fout in ' .. action .. ': ' .. tostring(result)) end
    elseif not res then
        res = { ok = false, msg = 'Onbekende actie' }
    end

    TriggerClientEvent('dv-reports:client:reply', src, reqId, res)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, r in pairs(reports) do
        if r.src == src and r.status ~= 'closed' then
            r.offline = true
            addMessage(r, 'system', nil, r.name .. ' heeft de server verlaten')
            changed(r.id)
        end
    end
    lastReport[src] = nil
    rate[src] = nil
end)

-- Aantal open reports voor andere scripts: exports['dv-reports']:GetOpenCount()
exports('GetOpenCount', openCount)
