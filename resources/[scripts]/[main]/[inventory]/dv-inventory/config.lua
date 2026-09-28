Config = {}

-- Framework: 'esx' (standaard), 'auto', 'qb' of 'standalone'
-- Bij ESX blijft ESX de baas over items, wapens en geld: alle ESX-scripts (winkels, banen,
-- esx_basicneeds, ambulance, ...) blijven gewoon werken via xPlayer.addInventoryItem enz.
Config.Framework = 'esx'

Config.Esx = {
    -- ESX-gewicht is in kg (Config.MaxWeight = 24, items weight = 1). 1 ESX-eenheid = 1000 gram.
    WeightUnit = 1000,
    -- Gewicht van een wapen in een kofferbak/op de grond (ESX telt wapens niet mee voor de speler)
    WeaponWeight = 1500,
    -- Contant geld en zwart geld als item tonen (verplaatsen naar kofferbak, geven, weggooien)
    MoneyAsItem = true,
    MoneyLabel = 'Contant geld',
    MoneyDesc = 'Je ESX-contant geld.',
    BlackMoneyLabel = 'Zwart geld',
    -- ESX-groepen die /giveitem en /clearinv mogen gebruiken
    AdminGroups = { admin = true, superadmin = true, owner = true },
    -- Plaatjes voor ESX-items die niet in Config.Items staan
    Icons = {
        bread = '🍞', water = '💧', phone = '📱', radio = '📻', bandage = '🩹', medikit = '🧰',
        fixkit = '🔧', fixtool = '🔧', carokit = '🧽', carotool = '🧽', blowpipe = '🔥', gazbottle = '🛢️',
        alive_chicken = '🐔', slaughtered_chicken = '🍗', packaged_chicken = '🍗', fish = '🐟',
        stone = '🪨', washed_stone = '🪨', copper = '🟫', iron = '⚙️', gold = '🥇', diamond = '💎',
        wood = '🪵', cutted_wood = '🪵', packaged_plank = '🪵', petrol = '⛽', petrol_raffin = '⛽', essence = '⛽',
        wool = '🧶', fabric = '🧵', clothe = '👕', cannabis = '🌿', marijuana = '🌿', coke = '❄️', meth = '🧪', opium = '🌺',
        lockpick = '🗝️', weed = '🌿', beer = '🍺', wine = '🍷', vodka = '🍸', whisky = '🥃', tequila = '🥃',
        cigarett = '🚬', cigarette = '🚬', lighter = '🔥', chips = '🥔', sandwich = '🥪', burger = '🍔', hamburger = '🍔',
        chocolate = '🍫', coffee = '☕', icetea = '🧋', cola = '🥤', soda = '🥤', apple = '🍎', banana = '🍌',
    },
    IconPatterns = {
        ['^weapon_knife'] = '🔪', ['^weapon_dagger'] = '🗡️', ['^weapon_bat'] = '🏏', ['^weapon_flashlight'] = '🔦',
        ['^weapon_hammer'] = '🔨', ['^weapon_wrench'] = '🔧', ['^weapon_crowbar'] = '🪛', ['^weapon_petrolcan'] = '⛽',
        ['^weapon_stungun'] = '⚡', ['^weapon_fireextinguisher'] = '🧯', ['^weapon_'] = '🔫',
        ['ammo'] = '📦', ['drink'] = '🥤', ['food'] = '🍔', ['key'] = '🔑', ['card'] = '💳',
    },
    DefaultIcon = '📦',
}

-- Openen (spelers kunnen de toets aanpassen in GTA > Instellingen > Toetsen > FiveM)
Config.OpenKey = 'I'

-- Hotbar: vakjes 1 t/m 5 gebruiken met de cijfertoetsen
Config.Hotbar = true

-- Speler
Config.PlayerSlots = 30
Config.PlayerWeight = 30000        -- gram (30 kg)

-- Voertuigen
Config.TrunkSlots = 30
Config.TrunkWeight = 100000        -- 100 kg
Config.GloveboxSlots = 5
Config.GloveboxWeight = 10000      -- 10 kg

-- Spullen op de grond
Config.DropSlots = 30
Config.DropDespawnMinutes = 30
Config.DropProp = 'prop_paper_bag_small'

-- Afstand (meter) voor geven / grond / kofferbak
Config.GiveDistance = 3.0
Config.DropDistance = 2.5
Config.TrunkDistance = 3.5

-- Items die nieuwe spelers krijgen
Config.StartItems = {
    { name = 'water', count = 2 },
    { name = 'sandwich', count = 2 },
    { name = 'phone', count = 1 },
    { name = 'id_card', count = 1 },
}

-- Wie mag /giveitem en /clearinv gebruiken (zelfde rangen als dv-admin)
Config.AdminAce = 'dvadmin.admin'

--[[
    Items
    ---------------------------------------------------------------
    label    naam in het menu
    icon     emoji of tekst die als plaatje wordt getoond
    weight   gewicht in gram (per stuk)
    stack    mag het stapelen (true/false)
    max      maximaal per stapel (standaard 100)
    usable   kan gebruikt worden
    consume  verdwijnt 1 stuk bij gebruik
    close    sluit het menu bij gebruik
    effects  { heal, armor, hunger, thirst, stress } bij gebruik
    anim     'eat', 'drink', 'bandage' of 'smoke' tijdens gebruik
    weapon   wapen-naam (item wordt dan een wapen)
    ammo     { type = 'AMMO_PISTOL', amount = 12 } voor munitie
    action   'repair' = speciale actie op de client (repareert voertuig)
    desc     beschrijving
]]
Config.Items = {
    -- eten & drinken
    water     = { label = 'Water', icon = '💧', weight = 500, stack = true, usable = true, consume = true, close = true, anim = 'drink', effects = { thirst = 35 }, desc = 'Een flesje koud water.' },
    cola      = { label = 'Cola', icon = '🥤', weight = 350, stack = true, usable = true, consume = true, close = true, anim = 'drink', effects = { thirst = 25, stress = -5 }, desc = 'Bruisend en zoet.' },
    coffee    = { label = 'Koffie', icon = '☕', weight = 300, stack = true, usable = true, consume = true, close = true, anim = 'drink', effects = { thirst = 15, stress = -10 }, desc = 'Houdt je wakker.' },
    sandwich  = { label = 'Broodje', icon = '🥪', weight = 300, stack = true, usable = true, consume = true, close = true, anim = 'eat', effects = { hunger = 30 }, desc = 'Broodje kaas.' },
    burger    = { label = 'Burger', icon = '🍔', weight = 400, stack = true, usable = true, consume = true, close = true, anim = 'eat', effects = { hunger = 45 }, desc = 'Vet lekker.' },
    donut     = { label = 'Donut', icon = '🍩', weight = 150, stack = true, usable = true, consume = true, close = true, anim = 'eat', effects = { hunger = 15, stress = -5 }, desc = 'Favoriet van de politie.' },

    -- medisch
    bandage   = { label = 'Verband', icon = '🩹', weight = 100, stack = true, usable = true, consume = true, close = true, anim = 'bandage', effects = { heal = 20 }, desc = 'Stopt kleine bloedingen (+20 leven).' },
    medkit    = { label = 'EHBO-kit', icon = '🧰', weight = 1000, stack = true, max = 5, usable = true, consume = true, close = true, anim = 'bandage', effects = { heal = 100 }, desc = 'Volledig genezen.' },
    armor     = { label = 'Kogelvrij vest', icon = '🦺', weight = 3000, stack = true, max = 5, usable = true, consume = true, close = true, anim = 'bandage', effects = { armor = 100 }, desc = 'Volledig pantser.' },

    -- spullen
    phone     = { label = 'Telefoon', icon = '📱', weight = 200, stack = false, desc = 'Je smartphone.' },
    radio     = { label = 'Portofoon', icon = '📻', weight = 500, stack = false, desc = 'Voor contact met je team.' },
    id_card   = { label = 'ID-kaart', icon = '🪪', weight = 20, stack = false, desc = 'Je identiteitsbewijs.' },
    lockpick  = { label = 'Lockpick', icon = '🗝️', weight = 150, stack = true, max = 10, desc = 'Voor sloten die niet van jou zijn.' },
    repairkit = { label = 'Reparatieset', icon = '🔧', weight = 2500, stack = true, max = 5, usable = true, action = 'repair', close = true, desc = 'Repareert het voertuig waar je naast staat.' },
    cigarette = { label = 'Sigaret', icon = '🚬', weight = 10, stack = true, usable = true, consume = true, close = true, anim = 'smoke', effects = { stress = -15 }, desc = 'Slecht voor je, goed voor je stress.' },
    rope      = { label = 'Touw', icon = '🪢', weight = 800, stack = true, max = 10, desc = 'Stevig touw.' },

    -- wapens
    weapon_pistol = { label = 'Pistool', icon = '🔫', weight = 1100, stack = false, usable = true, weapon = 'WEAPON_PISTOL', desc = 'Gebruikt pistoolmunitie.' },
    weapon_knife  = { label = 'Mes', icon = '🔪', weight = 300, stack = false, usable = true, weapon = 'WEAPON_KNIFE', desc = 'Scherp.' },
    weapon_bat    = { label = 'Honkbalknuppel', icon = '🏏', weight = 1000, stack = false, usable = true, weapon = 'WEAPON_BAT', desc = 'Voor honkbal. Natuurlijk.' },
    ammo_pistol   = { label = 'Pistoolmunitie', icon = '📦', weight = 200, stack = true, usable = true, ammo = { type = 'AMMO_PISTOL', amount = 12 }, desc = 'Doos met 12 kogels. Gebruik met je pistool in de hand.' },
}
