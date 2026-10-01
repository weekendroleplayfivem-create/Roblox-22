# VECTOR RUSH

A fast, colourful, kid-friendly Roblox arena FPS prototype. You can slide, dash, wall-jump and swap weapons quickly, and the server stays authoritative for everything competitive.

> Working title. This is an original project and is not affiliated with Arsenal, Hyper Shot or any other game. All names, maps, UI, weapons and code are original.

A new player can go **JOIN → MENU → QUEUE → MATCH → SPAWN → MOVE → SHOOT → USE ABILITIES → GET ELIMINATIONS → FINISH MATCH → RECEIVE XP → RETURN TO LOBBY**. Bots fill empty slots, so a single player can test the full loop alone in Studio.

| Doc | What's inside |
| --- | --- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How every system works, the full remote list, and the security model |
| [docs/TESTING.md](docs/TESTING.md) | Studio test plan, dev commands, automated tests |
| [docs/ASSETS.md](docs/ASSETS.md) | Every placeholder asset and where the final asset should go |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Known limitations and recommended next steps |

---

## Setup

The project uses [Rojo](https://rojo.space) 7.x. Every script in `src/` maps onto the Roblox DataModel through `default.project.json`.

### Option A: live sync (recommended for development)
1. Install Rojo (CLI plus the Roblox Studio plugin). With Aftman/Rokit: `rokit add rojo-rbx/rojo@7.4.4`.
2. Run `rojo serve` in the repository root.
3. In Studio, open a new **Baseplate** place. **Delete the default `Baseplate` and `SpawnLocation`**: the game builds its own lobby and arenas.
4. In the Rojo plugin, click **Connect**.

### Option B: build a place file
```bash
rojo build default.project.json -o VectorRush.rbxl
```
Then open `VectorRush.rbxl` in Studio.

### Studio settings
- **Game Settings → Security → Enable Studio Access to API Services**: turn this on to test saving. If it's off, the game still runs: the DataService falls back to a temporary profile that is never saved, and a toast tells you.
- To test the global leaderboard and saving between sessions, the place has to be published.

### Before publishing
- Replace the placeholder sounds and animations (see [docs/ASSETS.md](docs/ASSETS.md)).
- Add your UserId to `DevConfig.AuthorizedUserIds` if you want dev commands in private servers. They never work in public servers.
- Review `MatchConfig.Queue` (MinPlayers, bot fill) for live servers.

---

## Project structure

```
default.project.json
src/
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Config/        PlayerConfig, WeaponConfig, AbilityConfig, MatchConfig, MapConfig,
│   │   │                  ProgressionConfig, CosmeticConfig, SettingsConfig, SoundConfig,
│   │   │                  BotConfig, DevConfig
│   │   ├── Modules/       Signal, Maid, Spring, RaycastUtil, MathUtil, TableUtil,
│   │   │                  Net (remote registry + rate limiting), ObjectPool, WallMovement
│   │   └── Types          shared type definitions
│   ├── Assets/            (optional) Viewmodels/<WeaponId> models, see ASSETS.md
│   └── Remotes/           created at runtime by Net.Setup() from Net.Definitions
├── ServerScriptService/
│   ├── ServerMain         boots services (Init all, then Start all)
│   ├── Services/
│   │   ├── CombatantService   registry of players + bots ("combatants")
│   │   ├── DataService        DataStore profiles, session locks, migrations
│   │   ├── AntiCheatService   movement checks, suspicion scoring
│   │   ├── MapService         lobby + arena loading, jump pads
│   │   ├── SpawnService       scored spawn selection
│   │   ├── PlayerService      join/leave, spawning, out-of-bounds
│   │   ├── WeaponService      slots, ammo, reload, fire-rate validation
│   │   ├── CombatService      hit validation, damage, shields, eliminations
│   │   ├── ProjectileService  server-simulated plasma projectiles
│   │   ├── AbilityService     dash/phase/barrier/decoy/pulse/low-g field
│   │   ├── ProgressionService XP, levels, credits, challenges
│   │   ├── ShopService        cosmetic purchases + equips
│   │   ├── LeaderboardService match scoreboard + global leaderboard
│   │   ├── BotService/        practice bots (BotBrain state machine)
│   │   ├── MatchService/      match lifecycle + Modes/ (TDM, FFA, GunGame)
│   │   ├── QueueService       matchmaking queue (MMR hook ready)
│   │   └── DevCommandService  Studio/private-server developer commands
│   └── Tests/TestRunner   automated server checks
├── ServerStorage/
│   ├── Maps/              MapBuilder + NeonDistrict, SkyLab, CoreStation, Lobby
│   ├── Weapons/           (optional) third-person weapon models by WeaponId
│   └── ServerAssets/
└── StarterPlayerScripts/
    ├── ClientMain         boots controllers
    └── Controllers/
        ├── ClientState, InputController, CameraController, MovementController,
        ├── WeaponController, Viewmodel, AbilityController, EffectsController,
        ├── SoundController, UIController
        └── UI/            UIKit, MainMenuScreen, HUDScreen, Crosshair, ScoreboardScreen,
                           LoadoutScreen, ShopScreen (Shop + Customize), SettingsScreen,
                           ResultsScreen, TouchControls, Notifications, DevPanel
```

StarterGui contains the empty `MainMenu`, `HUD`, `Scoreboard`, `Loadout`, `Results`, `Settings` and `Shop` ScreenGuis. The UI modules fill them in at runtime.

---

## Controls

| Action | Keyboard / Mouse | Controller | Mobile |
| --- | --- | --- | --- |
| Move / look | WASD / mouse | Left stick / right stick | Thumbstick / drag (drag the FIRE button to aim while firing) |
| Fire / Aim | LMB / RMB | RT / LT | FIRE / AIM (toggle) |
| Jump, double jump, wall jump | Space | A / Cross | JUMP |
| Sprint | Left Shift (hold, or toggle in Settings) | L3 | SPRINT (toggle) |
| Crouch / Slide (while sprinting) | C or Left Ctrl | B / Circle | SLIDE |
| Movement ability (Dash/Phase) | E | LB | DASH |
| Tactical ability | Q | RB | TAC |
| Reload | R | X / Square | R |
| Weapons | 1 / 2 / mouse wheel | D-pad ← → / Y | SWAP |
| Scoreboard | Tab (hold) | Select / View | TAB |
| Menu | M | Start / Menu | ≡ |
| Emote (lobby) | G | D-pad ↓ | — |
| Dev console (Studio) | F2 | — | — |

---

## Quick Studio test (about 2 minutes)

1. Press **Play** (solo). The Output shows `[VectorRush] Server started` and `[Tests] N passed, 0 failed`.
2. The main menu opens. Click **QUICK PLAY**. After an 8-second queue countdown the arena builds, bots fill the match, there's a 5-second frozen countdown, then **GO!**
3. Move, slide, dash (E), wall-jump, shoot, use your tactical (Q), and eliminate bots.
4. Press **F2** and run `endmatch` (or play to the score limit). You'll see the results screen with XP and credits, then return to the lobby.

The full test plan is in [docs/TESTING.md](docs/TESTING.md).

---

## Tuning

Every gameplay number lives in `src/ReplicatedStorage/Shared/Config`. Movement base values are `WalkSpeed 16`, `SprintSpeed 24`, `SlideSpeed 30` and `JumpPower 50`, and the camera FOV is 80 (sprint 86), all set in `PlayerConfig`. Adding a weapon means adding a table entry in `WeaponConfig`. Adding a mode means adding a `MatchConfig.Modes` entry plus a rules module in `MatchService/Modes`.
