Config = {}

-- Framework: 'esx' (standaard). Of 'auto', 'qb', 'qbx', 'standalone'
-- ESX: geld (contant/bank), baan en honger/dorst (esx_status) worden automatisch getoond.
Config.Framework = 'esx'

-- 'auto' detecteert het brandstofscript. Of kies: 'native', 'LegacyFuel', 'ox_fuel', 'ps-fuel', 'cdn-fuel', 'lj-fuel'
Config.FuelSystem = 'auto'

-- Standaard snelheidseenheid ('kmh' of 'mph'). Spelers kunnen dit zelf aanpassen in /hud
Config.SpeedUnit = 'kmh'

-- Onder dit percentage knippert de brandstofindicator
Config.LowFuel = 20

-- Minimap alleen tonen in een voertuig
Config.MinimapOnlyInVehicle = true

-- Ingebouwde gordel. Zet op false als je al een ander gordelscript gebruikt
-- (de HUD luistert dan naar 'seatbelt:client:ToggleSeatbelt').
Config.Seatbelt = {
    enabled = true,
    key = 'B',
    eject = true,          -- uit de auto vliegen bij een crash zonder gordel
    ejectMinSpeed = 45,    -- km/u
    ejectDecel = 0.30,     -- snelheidsverlies (0-1) binnen één frame dat als crash telt
}

-- Commando's
Config.Commands = {
    settings = 'hud',       -- instellingenmenu
    cinematic = 'cinema',   -- filmmodus (zwarte balken, geen HUD)
    toggle = 'togglehud',   -- HUD aan/uit
}

-- Update-snelheid in ms (lager = vloeiender, hoger = zuiniger)
Config.Interval = {
    onFoot = 250,
    inVehicle = 50,
    location = 400,
    info = 1000,
}
