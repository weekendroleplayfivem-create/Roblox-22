# wk-admin

Staffmenu in de stijl van txAdmin, in dezelfde look als `wk-hud`. Werkt standalone, met extra ondersteuning voor QBCore en ESX (revive).

## Installatie

1. Zet de map `wk-admin` in je resources, bv. `resources/[scripts]/[main]/[admin]/wk-admin`.
2. Voeg toe aan `server.cfg`:

```cfg
ensure wk-admin

# Rangen
add_ace group.mod   wkadmin.mod   allow
add_ace group.admin wkadmin.admin allow
add_ace group.admin wkadmin.mod   allow
add_ace group.owner wkadmin.owner allow
add_ace group.owner wkadmin.admin allow
add_ace group.owner wkadmin.mod   allow

# Staffleden (license vind je in txAdmin of in het staffmenu zelf)
add_principal identifier.license:JOUW_LICENSE group.owner

# Optioneel: Discord-logs
set wkadmin_webhook "https://discord.com/api/webhooks/..."
```

3. Zorg dat de map `data/` schrijfbaar is (bans en warns worden daar opgeslagen).

## Openen

- `/staff` of **F10** (aan te passen in GTA-instellingen → Toetsen → FiveM)
- `/noclip` zet noclip direct aan/uit

## Functies

**Mijzelf:** noclip, godmode, onzichtbaar, namen en ID's boven hoofden, blips op de kaart, genezen, reviven, teleport naar waypoint of coördinaten, coördinaten kopiëren (vector3/vector4/heading), voertuig spawnen, repareren en verwijderen.

**Spelers:** live lijst met ID, naam, leven, pantser, ping, afstand, speeltijd en staff-rang. Per speler: ga naar, haal, spectate, genezen, reviven, bevriezen, bericht, waarschuwen, doden, kick en ban. Identifiers en eerdere waarschuwingen zie je direct.

**Server:** aankondiging naar iedereen, iedereen genezen of reviven, gebied opruimen (lege voertuigen en NPC's).

**Bans:** alle actieve bans met zoekfunctie en unban. Bans werken op alle identifiers én hardware-tokens, dus een nieuwe Steam/Discord helpt niet. Unban kan ook vanaf de console: `wkunban WK-1234`.

**Logs:** alle staff-acties sinds de laatste herstart, ook in de serverconsole en optioneel in Discord.

## Beveiliging

- Elke actie wordt op de server op rang gecontroleerd; de client beslist niets zelf.
- Staff kan geen acties uitvoeren op iemand met een hogere rang.
- Pogingen zonder rechten worden in de console gelogd.
- De Discord-webhook staat in `server.cfg`, niet in een bestand dat spelers kunnen lezen.

Welke rang wat mag, stel je in via `Config.Permissions` in `config.lua`.

## Voorbeeld bekijken

Open `html/index.html` in je browser voor een demo met testspelers.
