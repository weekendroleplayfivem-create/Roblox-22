# dv-reports · Dayverse Roleplay

Los reportsysteem in dezelfde oranje stijl als `dv-hud` en `dv-admin`. Werkt ook zonder `dv-admin`.

## Installatie

1. Zet de map `dv-reports` in je resources, bv. `resources/[scripts]/[main]/[admin]/dv-reports`.
2. In `server.cfg`:

```cfg
ensure dv-reports

# Staff (dezelfde rangen als dv-admin; sla over als je die al hebt)
add_ace group.mod   dvadmin.mod   allow
add_ace group.admin dvadmin.admin allow
add_ace group.owner dvadmin.owner allow
add_principal identifier.license:JOUW_LICENSE group.owner

# Optioneel: Discord-logs (anders wordt dvadmin_webhook gebruikt)
set dvreports_webhook "https://discord.com/api/webhooks/..."
```

## Gebruik

**Spelers:** `/report` of `/report <bericht>`

1. Kies een onderwerp (Speler melden, Bug, Vraag, Vastgelopen, Anders), eventueel het ID van de speler die je meldt, en beschrijf wat er is.
2. Je ziet live of staff je report heeft opgepakt en je kunt met staff chatten.
3. Met `/report` open je het gesprek weer; je kunt je report ook intrekken.

**Staff:** `/reports` (of vanuit het staffmenu via de knop *Reports*)

- Bij een nieuwe report krijgt alle online staff een melding met geluid.
- Filter op *Open*, *Mijn* en *Gesloten*.
- Per report: oppakken, chatten, naar de speler of de gemelde speler teleporteren, de speler halen, en sluiten met een notitie.

## Instellingen (`config.lua`)

| Instelling | Standaard | Wat |
| --- | --- | --- |
| `Command` | `report` | Commando voor spelers |
| `StaffCommand` | `reports` | Commando voor staff |
| `StaffKey` | leeg | Optionele toets voor staff, bv. `F9` |
| `StaffLevel` | `1` | Minimale rang (1 mod, 2 admin, 3 eigenaar) |
| `Cooldown` | `60` | Seconden tussen twee reports per speler |
| `KeepClosedHours` | `6` | Hoe lang gesloten reports zichtbaar blijven |
| `Categories` | 5 onderwerpen | Eigen onderwerpen toevoegen of weghalen |

## Voor andere scripts

```lua
local open = exports['dv-reports']:GetOpenCount()   -- server
```

## Voorbeeld bekijken

Open `html/index.html` in je browser voor het staffpaneel, of `html/index.html#report` voor het spelervenster.
