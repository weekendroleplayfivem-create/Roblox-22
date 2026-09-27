# wk-hud v2

Moderne HUD voor FiveM (QBCore, Qbox, ESX of standalone).

## Installatie

1. Maak een backup van je oude `wk-hud`.
2. Vervang de map `resources/[scripts]/[main]/[hud]/wk-hud` door deze map.
3. Zorg dat `ensure wk-hud` in je `server.cfg` staat (na je framework).
4. Gebruik je al een ander HUD-script dat ook status/snelheid toont (bv. `qb-hud`), zet dat dan uit.
5. Gebruik je al een gordelscript (bv. in `qb-smallresources`)? Zet `Config.Seatbelt.enabled = false`.

## Functies

- Statusringen: leven, pantser, honger, dorst, stress, uithouding, zuurstof (onder water) en stem (pma-voice: bereik, praten, radio)
- Ringen knipperen rood bij een laag niveau; pantser/stress/uithouding verbergen zich automatisch als ze niet relevant zijn
- Ringen schuiven automatisch mee met de positie van de minimap (elke resolutie en safezone)
- Snelheidsmeter met toerenteller, versnelling, brandstof, motorschade, lichten, gordel en hoogte (vliegtuig/heli)
- Brandstof: automatisch voor native, LegacyFuel, ox_fuel, ps-fuel, cdn-fuel en lj-fuel
- Ingebouwde gordel (toets **B**, instelbaar in GTA-toetsinstellingen) met geluid en uit-de-auto-vliegen bij crashes
- Kompas met graden, straatnaam, kruising en wijk
- Klok, server-ID, contant, bank (met animatie bij verandering) en baan
- Filmmodus met zwarte balken
- Alleen gewijzigde waarden worden naar de NUI gestuurd (laag resmon)

## Commando's

| Commando | Functie |
| --- | --- |
| `/hud` | Instellingen: grootte, accentkleur, km/u of mph, onderdelen aan/uit |
| `/cinema` | Filmmodus aan/uit |
| `/togglehud` | HUD aan/uit |

Instellingen worden per speler opgeslagen.

## Voor andere scripts

```lua
exports['wk-hud']:SetStatus('hunger', 80)   -- standalone: honger/dorst/stress zetten
TriggerEvent('wk-hud:client:setStatus', 'stress', 25)
local belt = exports['wk-hud']:IsSeatbeltOn()
```

## Voorbeeld bekijken

Open `html/index.html` in je browser. Dan draait een demo met testknoppen.
