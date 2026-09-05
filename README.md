# HYPER BLAST

A fast-paced, original multiplayer scooter-FPS built for Roblox Studio:
**blue neon × purple neon × high-speed combat**. Ride a combat scooter
through the **NEON DISTRICT**, fight with an original tactical weapon
roster, and win Team Blast or Hyper Rush matches.

This repo is a full [Rojo](https://rojo.space/) project — every system in
the game (map, weapons, scooter physics, matchmaking, UI, cosmetics,
server security) is real Luau source under `src/`, not placeholder stubs.
The **NEON DISTRICT** map itself is generated procedurally at server start
(see `src/ServerScriptService/MapGenerator.lua`) rather than hand-placed,
so the whole game ships as code.

## Getting it into Roblox Studio

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
   (the Studio plugin + the `rojo` CLI, or use the VS Code extension).
2. From the repo root, serve the project:
   ```
   rojo serve default.project.json
   ```
3. In Roblox Studio, open the Rojo plugin and click **Connect**.
4. Press **Play** (or **Start Server** for a local multi-client test) —
   the map builds itself, lighting/atmosphere/sound groups are configured,
   and the match loop starts automatically.

You can also `rojo build default.project.json -o HyperBlast.rbxlx` to
produce a standalone place file.

## What's implemented

- **Map** — `NEON DISTRICT`: Blue/Purple spawns, Central Plaza, Neon
  Market, Underpass, Rooftop Area, Garage (with a proximity door), 
  Alleyways, boost pads, jump pads, rooftop ramps, a decorative skyline,
  and a full Training Area (dummies + test track), all procedurally built.
- **Scooter** — arcade acceleration/braking/turning, automatic
  brake-and-turn drift with a boost reward, boost meter (server-authoritative),
  jump, and a neon trail — driven by `ScooterController.client.lua` +
  `ScooterServer.server.lua`.
- **Weapons** — 6 primaries, 3 secondaries, 1 melee (all original names/
  stats — see `WeaponData.lua`), hip-fire/ADS, spread, recoil, headshots,
  shotgun pellets, burst fire, tracers, muzzle flashes, hitmarkers.
- **Server security** — every kill, ammo count, fire-rate, and boost grant
  is decided server-side (`WeaponServer`, `DamageService`, `ScooterServer`,
  `AntiExploit`); clients only send input.
- **Cosmetics** — original weapon skin collections and scooter skins
  (Common → Mythic), inventory/loadout UI, all server-validated for
  ownership before equipping.
- **Modes** — Team Blast (4v4 to 50) and Hyper Rush (FFA to 30), with
  balanced team assignment, safe respawns, killstreak callouts, and a
  continuously-running match loop (countdown → match → post-match →
  next match).
- **UI** — animated loading screen, main menu, match HUD (scores, timer,
  ammo, HP, boost, crosshair, kill feed, respawn countdown, XP/level
  toasts), inventory/loadout, settings (saved to the player's profile),
  and a victory/defeat end screen.
- **Progression** — per-player DataStore-backed profile: K/D, wins/losses,
  XP, levels.
- **Dev tools** — chat-based debug commands (`/startmatch`, `/givexp`,
  `/giveweapon`, `/spawndummy`, ...) gated to the game owner.

## Project layout

```
src/
├── ReplicatedStorage/
│   └── Shared/       -- WeaponData, ScooterData, SkinData, MatchData, Utility, ScooterBuilder
├── ServerScriptService/
│   ├── GameManager, MatchManager, MapGenerator
│   ├── WeaponServer, DamageService, ScooterServer, AntiExploit
│   ├── PlayerData, InventoryService, XPService, DebugCommands
│   └── RemotesSetup, SoundSetup, PlayerDataInit
├── StarterPlayer/StarterPlayerScripts/
│   ├── ScooterController, WeaponController, CameraController, FPSController
│   ├── MobileControls (touch fire/boost/jump/reload/switch buttons)
│   └── ClientState, UIState, UIHelpers  -- shared client plumbing
└── StarterGui/
    ├── LoadingScreen, MainMenu, MatchHUD
    └── InventoryUI, SettingsUI, EndScreenUI
```

All weapon/scooter/skin names, stats, and map layout are original —
nothing is copied from any existing game's assets, models, or UI.
