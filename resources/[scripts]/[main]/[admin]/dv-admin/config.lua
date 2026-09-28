Config = {}

-- Openen met /staff of met een toets (spelers kunnen de toets aanpassen in GTA-instellingen)
Config.Command = 'staff'
Config.Key = 'F10'

-- Noclip los aan/uit zetten (leeg = geen standaardtoets)
Config.NoclipCommand = 'noclip'
Config.NoclipKey = ''

--[[
    Rangen (in server.cfg via ACE):
      1 = moderator   ->  add_ace group.mod   dvadmin.mod   allow
      2 = admin       ->  add_ace group.admin dvadmin.admin allow
      3 = eigenaar    ->  add_ace group.owner dvadmin.owner allow

    Minimale rang per actie:
]]
Config.Permissions = {
    -- spelers
    players = 1, ['goto'] = 1, bring = 1, spectate = 1, freeze = 1,
    heal = 1, revive = 1, dm = 1, warn = 1, kick = 1,
    kill = 2, ban = 2,

    -- bans / logs
    bans = 1, unban = 2, logs = 1,

    -- jezelf
    noclip = 1, invisible = 1, names = 1, blips = 1, godmode = 2,
    healSelf = 1, reviveSelf = 1, tpWaypoint = 1, tpCoords = 1, copyCoords = 1,
    spawnVehicle = 2, fixVehicle = 1, deleteVehicle = 1,

    -- server
    announce = 2, healAll = 2, reviveAll = 2, clearArea = 2,

    -- ESX
    giveMoney = 3, setJob = 2, jobs = 1,
}

-- ESX-groepen als staff-rang (1 = moderator, 2 = admin, 3 = eigenaar).
-- Zet iemands groep in ESX met /setgroup <id> admin (of in de database).
Config.EsxGroups = { mod = 1, moderator = 1, helper = 1, admin = 2, superadmin = 3, owner = 3 }

Config.RankNames = { [1] = 'Moderator', [2] = 'Admin', [3] = 'Eigenaar' }

-- Ban-duur in uren (0 = permanent)
Config.BanDurations = {
    { label = '1 uur', hours = 1 },
    { label = '6 uur', hours = 6 },
    { label = '1 dag', hours = 24 },
    { label = '3 dagen', hours = 72 },
    { label = '1 week', hours = 168 },
    { label = '1 maand', hours = 720 },
    { label = 'Permanent', hours = 0 },
}

Config.ClearAreaRadius = 75.0
Config.SpawnPlate = 'STAFF'

-- Discord-logs: zet in server.cfg ->  set dvadmin_webhook "https://discord.com/api/webhooks/..."
-- (staat bewust niet hier, want dit bestand is ook voor spelers leesbaar)
