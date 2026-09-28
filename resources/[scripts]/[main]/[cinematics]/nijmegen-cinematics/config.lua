Config = {}

-- Taal van het menu: 'nl' of 'en'
Config.Locale = 'nl'

-- Openen met /cinematic (optioneel een toets, bv. 'F7'; leeg = geen)
Config.Command = 'cinematic'
Config.Key = ''

-- Kleur van het menu
Config.Accent = '#ff8c1a'

-- Wie mag de editor gebruiken?
-- Everyone = true: iedereen. Anders iedereen met een van deze ACE-rechten (server.cfg).
Config.Everyone = false
Config.Aces = { 'nijmegen.cinematics', 'dvadmin.admin' }

-- Wie mag een scène voor ALLE spelers afspelen
Config.BroadcastAce = 'nijmegen.cinematics.broadcast'

-- Freecam
Config.MaxDistance = 1500.0     -- max. afstand van je personage (0 = onbeperkt)
Config.Speed = 0.35             -- basis-snelheid (scroll met pijltjes omhoog/omlaag)
Config.FastMultiplier = 4.0     -- Shift
Config.SlowMultiplier = 0.2     -- Alt
Config.Sensitivity = 6.0        -- muis
Config.DefaultFov = 50.0

-- Standaard voor nieuwe keyframes
Config.DefaultDuration = 4.0    -- seconden naar het volgende punt
Config.DefaultEase = 'inout'    -- 'linear', 'in', 'out', 'inout'

-- Tijdens afspelen alles van GTA verbergen (radar, meldingen)
Config.HideHud = true

-- Koppeling met je eigen HUD/chat e.d. (wordt uitgevoerd op de client)
Config.OnStart = function()
    -- bv. ExecuteCommand('togglehud')
end
Config.OnStop = function()
    -- bv. ExecuteCommand('togglehud')
end

-- Filters (timecycle modifiers)
Config.Filters = {
    { id = '', label = 'Geen / None' },
    { id = 'cinema', label = 'Cinema' },
    { id = 'NG_filmic01', label = 'Filmic 1' },
    { id = 'NG_filmic02', label = 'Filmic warm' },
    { id = 'NG_filmic04', label = 'Filmic zacht' },
    { id = 'NG_filmic06', label = 'Filmic koel' },
    { id = 'NG_filmic10', label = 'Vintage' },
    { id = 'NG_filmic16', label = 'Kleurrijk' },
    { id = 'NG_filmic20', label = 'Donker' },
    { id = 'hud_def_desat_Neutral', label = 'Zwart-wit' },
    { id = 'rply_saturation', label = 'Verzadigd' },
    { id = 'rply_contrast', label = 'Contrast' },
    { id = 'rply_vignette', label = 'Vignet' },
    { id = 'MP_Bull_tost', label = 'Dromerig' },
}

-- Camerabeweging (shake)
Config.Shakes = {
    { id = '', label = 'Geen / None' },
    { id = 'HAND_SHAKE', label = 'Handcamera' },
    { id = 'ROAD_VIBRATION_SHAKE', label = 'Rijden' },
    { id = 'DRUNK_SHAKE', label = 'Dronken' },
    { id = 'SKY_DIVING_SHAKE', label = 'Vrije val' },
    { id = 'VIBRATE_SHAKE', label = 'Trillen' },
}

-- Weer (alleen lokaal tijdens de cinematic)
Config.Weathers = {
    { id = '', label = 'Server / Server' },
    { id = 'EXTRASUNNY', label = 'Zonnig' },
    { id = 'CLEAR', label = 'Helder' },
    { id = 'CLOUDS', label = 'Bewolkt' },
    { id = 'OVERCAST', label = 'Grijs' },
    { id = 'RAIN', label = 'Regen' },
    { id = 'THUNDER', label = 'Onweer' },
    { id = 'FOGGY', label = 'Mist' },
    { id = 'SNOW', label = 'Sneeuw' },
    { id = 'XMAS', label = 'Kerst' },
    { id = 'HALLOWEEN', label = 'Halloween' },
}

-- Meldingen (Lua-kant)
Config.Locales = {
    nl = {
        no_access = 'Je hebt geen toegang tot de cinematic maker',
        too_far = 'Camera mag niet verder van je personage',
        need_points = 'Je hebt minimaal 2 keyframes nodig',
        saved = 'Scène opgeslagen',
        deleted = 'Scène verwijderd',
        not_found = 'Scène niet gevonden',
        broadcast = 'Scène wordt voor iedereen afgespeeld',
    },
    en = {
        no_access = 'You do not have access to the cinematic maker',
        too_far = 'Camera cannot go further from your character',
        need_points = 'You need at least 2 keyframes',
        saved = 'Scene saved',
        deleted = 'Scene deleted',
        not_found = 'Scene not found',
        broadcast = 'Scene is playing for everyone',
    },
}

function L(key)
    local t = Config.Locales[Config.Locale] or Config.Locales.nl
    return t[key] or key
end
