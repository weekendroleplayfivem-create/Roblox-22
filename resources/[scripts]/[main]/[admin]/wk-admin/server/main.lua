-- ============================================================
--  wk-admin  |  server
-- ============================================================

local RES = GetCurrentResourceName()
local WEBHOOK = GetConvar('wkadmin_webhook', '')

local bans = json.decode(LoadResourceFile(RES, 'data/bans.json') or '[]') or {}
local warns = json.decode(LoadResourceFile(RES, 'data/warns.json') or '{}') or {}
local logs = {}
local joinedAt = {}
local frozen = {}

-- ------------------------------------------------------------
--  Helpers
-- ------------------------------------------------------------

local function saveBans() SaveResourceFile(RES, 'data/bans.json', json.encode(bans), -1) end
local function saveWarns() SaveResourceFile(RES, 'data/warns.json', json.encode(warns), -1) end

local function getLevel(src)
    if src == 0 then return 3 end
    if IsPlayerAceAllowed(src, 'wkadmin.owner') then return 3 end
    if IsPlayerAceAllowed(src, 'wkadmin.admin') then return 2 end
    if IsPlayerAceAllowed(src, 'wkadmin.mod') then return 1 end
    return 0
end

local function name(src)
    return GetPlayerName(src) or ('ID ' .. tostring(src))
end

local function identifier(src, kind)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, #kind + 1) == kind .. ':' then return id end
    end
end

local function allIdentifiers(src)
    local ids, tokens = {}, {}
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if not id:find('^ip:') then ids[#ids + 1] = id end
    end
    for i = 0, GetNumPlayerTokens(src) - 1 do
        tokens[#tokens + 1] = GetPlayerToken(src, i)
    end
    return ids, tokens
end

local function isOnline(id)
    return id and GetPlayerName(id) ~= nil
end

local function fmtDate(t)
    return os.date('%d-%m-%Y %H:%M', t)
end

local function log(src, action, target, detail)
    local entry = {
        time = os.date('%H:%M:%S'),
        date = os.date('%d-%m'),
        admin = src == 0 and 'Console' or name(src),
        action = action,
        target = target and name(target) or nil,
        detail = detail,
    }
    table.insert(logs, 1, entry)
    if #logs > 300 then logs[#logs] = nil end

    local line = ('[wk-admin] %s -> %s%s%s'):format(entry.admin, action,
        entry.target and (' | ' .. entry.target) or '', detail and (' | ' .. detail) or '')
    print(line)

    if WEBHOOK ~= '' then
        PerformHttpRequest(WEBHOOK, function() end, 'POST', json.encode({
            username = 'WK Staff',
            embeds = { {
                title = action,
                color = 5025616,
                description = ('**Staff:** %s\n%s%s'):format(entry.admin,
                    entry.target and ('**Speler:** ' .. entry.target .. '\n') or '',
                    detail and ('**Info:** ' .. detail) or ''),
                footer = { text = os.date('%d-%m-%Y %H:%M:%S') },
            } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- ------------------------------------------------------------
--  Bans
-- ------------------------------------------------------------

local function findBan(ids, tokens)
    local now = os.time()
    local lookup = {}
    for _, v in ipairs(ids) do lookup[v] = true end
    for _, v in ipairs(tokens) do lookup[v] = true end

    for i = #bans, 1, -1 do
        local b = bans[i]
        if b.expires ~= 0 and b.expires < now then
            table.remove(bans, i)
        else
            for _, v in ipairs(b.identifiers or {}) do if lookup[v] then return b end end
            for _, v in ipairs(b.tokens or {}) do if lookup[v] then return b end end
        end
    end
end

local function banMessage(b)
    return ('\n🚫 Je bent verbannen van deze server.\n\nReden: %s\nVerloopt: %s\nBan-ID: %s\n\nDenk je dat dit onterecht is? Neem contact op met staff via Discord.')
        :format(b.reason, b.expires == 0 and 'Nooit (permanent)' or fmtDate(b.expires), b.id)
end

local function newBanId()
    local id
    repeat
        id = ('WK-%04d'):format(math.random(0, 9999))
        local taken = false
        for _, b in ipairs(bans) do if b.id == id then taken = true break end end
    until not taken
    return id
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Ban-controle...')
    local ids, tokens = allIdentifiers(src)
    local ban = findBan(ids, tokens)
    if ban then
        deferrals.done(banMessage(ban))
    else
        deferrals.done()
    end
end)

AddEventHandler('playerJoining', function()
    joinedAt[source] = os.time()
end)

AddEventHandler('playerDropped', function()
    joinedAt[source] = nil
    frozen[source] = nil
end)

CreateThread(function()
    for _, id in ipairs(GetPlayers()) do joinedAt[tonumber(id)] = os.time() end
    math.randomseed(os.time())
end)

-- ------------------------------------------------------------
--  Acties
-- ------------------------------------------------------------

local Actions = {}

--- Controleert of de doelspeler bestaat en geen hogere rang heeft.
local function checkTarget(src, target, allowSelf)
    target = tonumber(target)
    if not isOnline(target) then return nil, 'Speler is niet (meer) online' end
    if not allowSelf and target == src then return nil, 'Dat kan niet op jezelf' end
    if target ~= src and getLevel(target) > getLevel(src) then
        return nil, 'Deze speler heeft een hogere rang'
    end
    return target
end

Actions.open = function(src)
    local level = getLevel(src)
    local perms = {}
    for action, need in pairs(Config.Permissions) do perms[action] = level >= need end
    return {
        ok = true,
        level = level,
        rank = Config.RankNames[level],
        name = name(src),
        perms = perms,
        durations = Config.BanDurations,
        serverName = GetConvar('sv_projectName', GetConvar('sv_hostname', 'Server')),
    }
end

Actions.players = function(src)
    local list = {}
    local myCoords = coordsOf(src)
    for _, sid in ipairs(GetPlayers()) do
        local id = tonumber(sid)
        local ped = GetPlayerPed(id)
        local c = ped ~= 0 and GetEntityCoords(ped)
        local license = identifier(id, 'license')
        local maxHp = ped ~= 0 and GetEntityMaxHealth(ped) or 200
        list[#list + 1] = {
            id = id,
            name = name(id),
            ping = GetPlayerPing(id),
            health = ped ~= 0 and math.max(0, math.floor((GetEntityHealth(ped) - 100) / math.max(maxHp - 100, 1) * 100)) or 0,
            armor = ped ~= 0 and GetPedArmour(ped) or 0,
            distance = (c and myCoords) and math.floor(#(c - myCoords)) or nil,
            license = license,
            discord = identifier(id, 'discord'),
            steam = identifier(id, 'steam'),
            fivem = identifier(id, 'fivem'),
            warns = license and warns[license] or {},
            staff = Config.RankNames[getLevel(id)],
            frozen = frozen[id] or false,
            playtime = joinedAt[id] and (os.time() - joinedAt[id]) or 0,
            self = id == src,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return { ok = true, players = list }
end

Actions['goto'] = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    local c = coordsOf(target)
    if not c then return { ok = false, msg = 'Positie onbekend' } end
    TriggerClientEvent('wk-admin:client:teleport', src, c)
    log(src, 'Teleport naar', target)
    return { ok = true, msg = 'Geteleporteerd naar ' .. name(target) }
end

Actions.bring = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    local c = coordsOf(src)
    TriggerClientEvent('wk-admin:client:teleport', target, c)
    log(src, 'Speler gehaald', target)
    return { ok = true, msg = name(target) .. ' is naar je toe gehaald' }
end

Actions.spectate = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    TriggerClientEvent('wk-admin:client:spectate', src, target, coordsOf(target), name(target))
    log(src, 'Spectate', target)
    return { ok = true, close = true }
end

Actions.freeze = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    frozen[target] = not frozen[target]
    TriggerClientEvent('wk-admin:client:freeze', target, frozen[target])
    log(src, frozen[target] and 'Bevroren' or 'Ontdooid', target)
    return { ok = true, msg = name(target) .. (frozen[target] and ' is bevroren' or ' kan weer bewegen'), state = frozen[target] }
end

Actions.heal = function(src, d)
    local target, err = checkTarget(src, d.target, true)
    if not target then return { ok = false, msg = err } end
    TriggerClientEvent('wk-admin:client:heal', target)
    log(src, 'Genezen', target)
    return { ok = true, msg = name(target) .. ' is genezen' }
end

Actions.revive = function(src, d)
    local target, err = checkTarget(src, d.target, true)
    if not target then return { ok = false, msg = err } end
    TriggerClientEvent('wk-admin:client:revive', target)
    log(src, 'Gerevived', target)
    return { ok = true, msg = name(target) .. ' is gerevived' }
end

Actions.kill = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    TriggerClientEvent('wk-admin:client:kill', target)
    log(src, 'Gedood', target)
    return { ok = true, msg = name(target) .. ' is gedood' }
end

Actions.dm = function(src, d)
    local target, err = checkTarget(src, d.target, true)
    if not target then return { ok = false, msg = err } end
    local msg = tostring(d.message or ''):sub(1, 500)
    if msg == '' then return { ok = false, msg = 'Leeg bericht' } end
    TriggerClientEvent('wk-admin:client:dm', target, name(src), msg)
    log(src, 'Bericht', target, msg)
    return { ok = true, msg = 'Bericht verstuurd' }
end

Actions.warn = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    local reason = tostring(d.reason or ''):sub(1, 300)
    if reason == '' then return { ok = false, msg = 'Geef een reden op' } end
    local license = identifier(target, 'license')
    if license then
        warns[license] = warns[license] or {}
        table.insert(warns[license], { reason = reason, by = name(src), date = fmtDate(os.time()) })
        saveWarns()
    end
    TriggerClientEvent('wk-admin:client:warned', target, name(src), reason)
    log(src, 'Waarschuwing', target, reason)
    return { ok = true, msg = name(target) .. ' is gewaarschuwd' }
end

Actions.kick = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    local reason = tostring(d.reason or ''):sub(1, 300)
    if reason == '' then return { ok = false, msg = 'Geef een reden op' } end
    local tName = name(target)
    log(src, 'Gekickt', target, reason)
    DropPlayer(target, ('Je bent gekickt door %s.\nReden: %s'):format(name(src), reason))
    return { ok = true, msg = tName .. ' is gekickt' }
end

Actions.ban = function(src, d)
    local target, err = checkTarget(src, d.target)
    if not target then return { ok = false, msg = err } end
    local reason = tostring(d.reason or ''):sub(1, 300)
    if reason == '' then return { ok = false, msg = 'Geef een reden op' } end
    local hours = tonumber(d.hours) or 0
    local ids, tokens = allIdentifiers(target)
    local ban = {
        id = newBanId(),
        name = name(target),
        identifiers = ids,
        tokens = tokens,
        reason = reason,
        by = name(src),
        created = os.time(),
        expires = hours > 0 and (os.time() + hours * 3600) or 0,
    }
    bans[#bans + 1] = ban
    saveBans()
    local tName = name(target)
    log(src, 'Verbannen', target, ('%s (%s) [%s]'):format(reason, hours > 0 and (hours .. ' uur') or 'permanent', ban.id))
    DropPlayer(target, banMessage(ban))
    return { ok = true, msg = tName .. ' is verbannen (' .. ban.id .. ')' }
end

Actions.bans = function()
    local now, list = os.time(), {}
    for i = #bans, 1, -1 do
        local b = bans[i]
        if b.expires ~= 0 and b.expires < now then
            table.remove(bans, i)
        else
            list[#list + 1] = {
                id = b.id, name = b.name, reason = b.reason, by = b.by,
                created = fmtDate(b.created),
                expires = b.expires == 0 and 'Permanent' or fmtDate(b.expires),
                license = (function()
                    for _, v in ipairs(b.identifiers or {}) do if v:find('^license:') then return v end end
                end)(),
            }
        end
    end
    return { ok = true, bans = list }
end

Actions.unban = function(src, d)
    for i, b in ipairs(bans) do
        if b.id == d.id then
            table.remove(bans, i)
            saveBans()
            log(src, 'Unban', nil, ('%s (%s)'):format(b.name, b.id))
            return { ok = true, msg = b.name .. ' is unbanned' }
        end
    end
    return { ok = false, msg = 'Ban niet gevonden' }
end

Actions.logs = function()
    return { ok = true, logs = logs }
end

-- Acties op jezelf: de server controleert alleen de rang en logt;
-- de client voert ze daarna uit.
for _, a in ipairs({ 'noclip', 'invisible', 'names', 'blips', 'godmode', 'tpWaypoint', 'tpCoords',
    'copyCoords', 'fixVehicle', 'deleteVehicle', 'healSelf', 'reviveSelf' }) do
    Actions[a] = function(src)
        log(src, a)
        return { ok = true }
    end
end

Actions.spawnVehicle = function(src, d)
    local model = tostring(d.model or ''):gsub('[^%w_]', '')
    if model == '' then return { ok = false, msg = 'Geef een modelnaam op' } end
    log(src, 'Voertuig gespawnd', nil, model)
    return { ok = true }
end

Actions.announce = function(src, d)
    local msg = tostring(d.message or ''):sub(1, 500)
    if msg == '' then return { ok = false, msg = 'Leeg bericht' } end
    TriggerClientEvent('wk-admin:client:announce', -1, name(src), msg)
    log(src, 'Aankondiging', nil, msg)
    return { ok = true, msg = 'Aankondiging verstuurd' }
end

Actions.healAll = function(src)
    TriggerClientEvent('wk-admin:client:heal', -1)
    log(src, 'Iedereen genezen')
    return { ok = true, msg = 'Iedereen is genezen' }
end

Actions.reviveAll = function(src)
    TriggerClientEvent('wk-admin:client:revive', -1)
    log(src, 'Iedereen gerevived')
    return { ok = true, msg = 'Iedereen is gerevived' }
end

Actions.clearArea = function(src)
    local c = coordsOf(src)
    if not c then return { ok = false, msg = 'Positie onbekend' } end
    local radius = Config.ClearAreaRadius
    local count = 0
    for _, veh in ipairs(GetAllVehicles()) do
        if #(GetEntityCoords(veh) - c) <= radius then
            local occupied = false
            for seat = -1, 6 do
                local ped = GetPedInVehicleSeat(veh, seat)
                if ped ~= 0 and IsPedAPlayer(ped) then occupied = true break end
            end
            if not occupied then DeleteEntity(veh); count = count + 1 end
        end
    end
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and #(GetEntityCoords(ped) - c) <= radius then
            DeleteEntity(ped); count = count + 1
        end
    end
    log(src, 'Gebied opgeruimd', nil, ('%d entiteiten, %dm'):format(count, radius))
    return { ok = true, msg = ('%d entiteiten verwijderd'):format(count) }
end

-- ------------------------------------------------------------
--  Aanroepen vanaf de client
-- ------------------------------------------------------------

RegisterNetEvent('wk-admin:server:call', function(reqId, action, data)
    local src = source
    local res
    local handler = Actions[action]
    local need = action == 'open' and 1 or Config.Permissions[action]

    if not handler or not need then
        res = { ok = false, msg = 'Onbekende actie' }
    elseif getLevel(src) < need then
        res = { ok = false, msg = 'Je hebt hier geen permissie voor' }
        if action ~= 'open' then
            print(('[wk-admin] %s (%d) probeerde zonder rechten: %s'):format(name(src), src, tostring(action)))
        end
    else
        local ok, result = pcall(handler, src, type(data) == 'table' and data or {})
        res = ok and result or { ok = false, msg = 'Er ging iets mis' }
        if not ok then print('[wk-admin] fout in ' .. action .. ': ' .. tostring(result)) end
    end

    TriggerClientEvent('wk-admin:client:reply', src, reqId, res)
end)

-- Console: unban vanaf de servercommandline ->  wkunban WK-1234
RegisterCommand('wkunban', function(src, args)
    if src ~= 0 then return end
    local r = Actions.unban(0, { id = args[1] })
    print('[wk-admin] ' .. r.msg)
end, true)
