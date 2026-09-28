Config = {}

-- Spelers: /report  of  /report <bericht>
Config.Command = 'report'

-- Staff: /reports (opent het reportpaneel). Optioneel een toets, bv. 'F9' (leeg = geen)
Config.StaffCommand = 'reports'
Config.StaffKey = ''

--[[
    Staff gebruikt dezelfde rangen als dv-admin (server.cfg):
      add_ace group.mod   dvadmin.mod   allow
      add_ace group.admin dvadmin.admin allow
      add_ace group.owner dvadmin.owner allow
    Minimale rang om reports te zien en af te handelen (1 = mod, 2 = admin, 3 = eigenaar):
]]
Config.StaffLevel = 1

Config.Cooldown = 60          -- seconden tussen twee reports van dezelfde speler
Config.KeepClosedHours = 6    -- hoe lang gesloten reports zichtbaar blijven

Config.Categories = { 'Speler melden', 'Bug', 'Vraag', 'Vastgelopen', 'Anders' }

-- Discord-logs: in server.cfg ->  set dvreports_webhook "https://discord.com/api/webhooks/..."
-- (valt terug op dvadmin_webhook als die bestaat)
