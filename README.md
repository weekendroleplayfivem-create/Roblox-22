# Roblox-22

Two separate Roblox game prototypes, each a self-contained [Rojo](https://rojo.space/)
project. They are different games and different places — build whichever one
you want to open.

| Game | Folder | Project file |
|---|---|---|
| **HYPER BLAST** — neon scooter FPS | `src/` | `default.project.json` |
| **MIND TD** — adaptive-AI tower defence | `mind-td/src/` | `mind-td/default.project.json` |

To open either in Studio:

```
rojo serve default.project.json            # HYPER BLAST
rojo serve mind-td/default.project.json    # MIND TD
```

…then hit **Connect** in the Rojo Studio plugin and press Play. Or build a
standalone place file with `rojo build <project file> -o Game.rbxlx`.

Both maps are generated procedurally at server start, so Workspace looks empty
in edit mode. That's expected — press Play.

---

# MIND TD

A 1–4 player co-op tower defence where **the enemies learn how you play**.

You defend a Core at the end of a forked path through NEURAL OUTPOST, an
abandoned AI research facility. The enemy watches what you build and answers
it: stack your towers on the right and it routes down the left; lean on slow
fields and it fields hardened drives that shrug them off; win with cheap chip
damage and it rotates plated units forward.

**The central idea: the more predictable you are, the stronger the enemy gets.**

### How the adaptation actually works

`AdaptiveAI.lua` keeps a behaviour ledger — where you build, what you build,
what you upgrade, which target modes you pick, which towers deal your damage.
That collapses into a few ratios, thresholds turn those into a named strategy,
and the strategy decides two things: **which units** the adaptive wave slots
send, and **which branch of the fork** they walk.

Two constraints keep it from feeling like cheating:

- **It can't inflate its way to a win.** Every stat change is funnelled through
  `AIData.ClampModifier` (±30% hard ceiling) and is additionally scaled by how
  confident the read is. A shaky read barely changes anything. The AI wins by
  sending the right unit down the right lane, not by buffing numbers.
- **It only knows what you did in the open.** No hidden state, no information
  you couldn't work out by looking at your own board.

### Intel is something you buy

There are two separate numbers, and the distinction is the whole design:

- **Adaptation** — how confident the *enemy* is in its read of you.
- **Analysis** — how much of that *you* can see.

The Enemy Intelligence panel starts mostly redacted (`▓▓▓▓▓▓`). Building
**Analyzer** towers raises your analysis rate and progressively unlocks the
readout: weak side, then the counter unit, then the detected strategy and the
enemy's reasoning. The redaction is applied server-side before the data is
ever sent, so it can't be peeked at from the client.

### Contents

- **Map** — NEURAL OUTPOST, generated from `MapData`: reinforced spawn gate,
  main road, a fork into a ruined **laboratory** (left) and a **power plant**
  (right) that rejoin at a holographic central hub, then the run to the Core.
  20 waypoints, 24 build pads.
- **Towers** — Guardian (damage), Cryo (slow), Analyzer (intel), 3 upgrade
  levels each with visible hardware changes, 4 target modes.
- **Enemies** — Drone, Runner, Tank, plus three adaptive counters: Flanker
  (routes to your thin side), Sprinter (resists slowing), Armour Unit (resists
  chip damage).
- **THE LEARNER** — wave 20 boss. Reads your defence before it spawns,
  announces what it found, and at phase three re-reads the board and sends
  escorts down whichever lane you've left thin *right now*.
- **20 waves**, adaptive slots from wave 6, mini-boss at 10.
- **Enemy Intelligence Report** at the end of every run — never redacted,
  because the point is showing you the pattern you didn't know you had.

### Controls

| | |
|---|---|
| Pan | `WASD` / arrows / right-drag / screen edge |
| Zoom | Scroll / pinch |
| Build | Pick a tower from the bar, click a lit pad |
| Inspect | Click a placed tower → upgrade / sell / cycle target mode |
| Skip prep | **START WAVE** |
| Debug overlay | `F9` |

### Architecture

```
mind-td/src/
├── ReplicatedStorage/Shared/   TowerData, EnemyData, WaveData, AIData, MapData, Utility
├── ServerScriptService/        GameManager (state machine + the only request entry point)
│                               AdaptiveAI, WaveManager, EnemyManager, TowerManager,
│                               BossController, EconomyManager, MapBuilder, DataManager
├── StarterPlayer/…/            CameraController, PlacementController, UIController,
│                               ClientState, UIHelpers
└── StarterGui/                 MainUI, ReportUI, DebugUI
```

Server-authoritative throughout. The client sends intent — place, upgrade,
sell, retarget — and the server re-derives cost, ownership and legality from
the shared data tables before anything changes. Build pads (rather than
free-form placement) make that validation exact and give the AI an
authoritative left/right reading it can't be lied to about.

Performance: enemies are anchored and stepped along waypoints by **one**
Heartbeat loop (no Humanoids, no pathfinding, no physics), tower firing runs on
a single 20 Hz tick, enemy models are pooled, and the AI re-analyses on events
plus a slow timer rather than per frame.

---

# HYPER BLAST

A fast neon scooter FPS — blue × purple, high-speed combat in NEON DISTRICT.
Ride a combat scooter, fight with an original tactical weapon roster, win Team
Blast (4v4 to 50) or Hyper Rush (FFA to 30).

- **Map** — NEON DISTRICT: blue/purple spawns, central plaza, neon market,
  underpass, rooftops, garage with a proximity door, alleyways, boost pads,
  jump pads, and a training area — all procedurally built.
- **Scooter** — a massless cosmetic rig welded under your character; movement
  rides the Humanoid, with a speed ramp, boost, carve-drift and jump layered
  on top.
- **Weapons** — 6 primaries, 3 secondaries, 1 melee, all original. Hipfire/ADS,
  recoil, spread, headshots, shotgun pellets, burst fire.
- **Server-authoritative** — every kill, ammo count, fire-rate and boost grant
  is decided server-side.
- Cosmetic weapon and scooter skins (Common → Mythic), inventory/loadout,
  DataStore-backed profiles with XP and levels, and the full UI flow.

Controls: `WASD` move, `Shift` boost, `Space` jump, mouse aim, `1`/`2`/`3`
weapons, `R` reload.

---

All names, stats, map layouts and UI in both games are original.
