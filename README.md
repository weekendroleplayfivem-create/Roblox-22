# HYPER BLAST

A fast-paced 3D neon competitive shooter for Roblox, built around **movement skill + gunplay**.

Sprint into a slide, hop out of it with your speed intact, air-dash across the gap, wall-jump
off a panel, mantle the ledge, swap to your sidearm and land the shot — all without the camera
ever fighting you for control.

```
Sprint → Slide → Jump → Air Dash → Land → Quick swap → Aim
```

Everything in this repository is code and data: the arena, the weapons, the viewmodels and every
visual effect are generated at runtime from config tables. There are no art dependencies to
install and nothing to click together in Studio.

---

## Running it

Requires [Rojo](https://rojo.space/) 7.x. With [Aftman](https://github.com/LPGhatguy/aftman):

```bash
aftman install          # installs rojo, stylua, selene from aftman.toml
rojo serve              # then connect from the Roblox Studio Rojo plugin
```

Or build a place file directly:

```bash
rojo build -o HyperBlast.rbxlx
```

Press **Play** in Studio. The server builds the arena, assigns teams and starts the mode rotation;
no manual setup, no SpawnLocations to place.

Linting and formatting:

```bash
selene src
stylua --check src
```

---

## Controls

| Action | Keyboard / Mouse | Gamepad |
| --- | --- | --- |
| Move | `W A S D` | Left stick |
| Sprint | `Left Shift` | `L3` |
| Crouch / Slide | `Left Ctrl` or `C` | `B` |
| Jump / Wall-jump / Mantle | `Space` | `A` |
| Fire | `Mouse 1` | `RT` |
| Aim down sights | `Mouse 2` | `LT` |
| Reload | `R` | `X` |
| Quick melee | `V` | `R3` |
| Inspect weapon | `T` | `D-Pad Up` |
| Weapon slots | `1` `2` `3` | `D-Pad Right` cycles |
| Hyper Dash | `Q` | `LB` |
| Phase Step | `E` | `RB` |
| Overdrive | `F` | `Y` |
| Scoreboard | `Tab` | `Select` |

Sprint, crouch and slide share one verb: **crouch while fast enough and you slide instead.**
Jump is context-sensitive — near a wall it wall-jumps, at a ledge it mantles, otherwise it jumps.

---

## The movement model

The feel comes from one idea: **speed you earned is speed you keep.** A momentum scalar carries
across state transitions and bleeds away slowly, instead of being reset every time the state
machine changes its mind.

| System | What it does | Why it's there |
| --- | --- | --- |
| **Momentum scalar** | Ground speed carries out of slides, dashes and pads, then decays at `MomentumBleed` | Rewards chaining; punishes stopping |
| **Slide** | Boosts on entry, accelerates downhill, steers slowly, keeps 100% of its speed into a jump | The core combo enabler |
| **Air control** | Quake-style acceleration: only the wish-direction component is capped | Strafe-jumping skill ceiling in four lines of code |
| **Coyote time + jump buffer** | 120ms grace after a ledge, 140ms before a landing | The difference between "tight" and "the game ate my input" |
| **Wall jump** | Blends push-off-wall with keep-going-where-you-look; capped chain, same-wall lockout | Redirects momentum instead of resetting it; can't elevator one surface |
| **Mantle** | 260ms ledge vault with full camera control throughout | Fast enough never to read as a cutscene |
| **Stamina** | Gates sprint, slide entry and wall jumps; long punish for hitting zero | Makes "when do I go fast" a decision |
| **Jump pads** | Launch + refresh your air dash | Turns a pad into a route, not a novelty |

Ordinary ground locomotion is left to the Roblox `Humanoid` with our momentum scalar driving
`WalkSpeed`; scripted states (slide, dash, phase, mantle) take over the assembly velocity outright.
See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for why that hybrid, and
[`src/shared/Config/MovementConfig.luau`](src/shared/Config/MovementConfig.luau) for every number
with its rationale.

### Camera

No traumatic screen shake anywhere. Speed is communicated with FOV, a couple of degrees of roll,
a small view bob and trails — never by making the target harder to hit. All positional camera
impulses are hard-clamped by `MovementConfig.Camera.MaxShake`.

---

## Combat

Six weapons, each with its own recoil pattern, spread behaviour, mobility multiplier, procedural
reload animation and elimination effect skin.

| Weapon | Class | Identity |
| --- | --- | --- |
| **PULSE-7** | Assault Rifle | The honest default; wins mid-range if you can track |
| **VOLT-SMG** | SMG | Beats PULSE inside 25 studs, loses hard past 45; the runner's gun |
| **FRACTURE-12** | Energy Shotgun | Lethal inside 14 studs, a joke outside it; rewards flank routes |
| **LANCE-R** | Rail Marksman | One-shots to the head, punishing on-miss; can wallbang thin cover |
| **SPARK-9** | Sidearm | Fastest swap in the game — the answer to "I got caught reloading" |
| **RIFT BLADE** | Melee | Fast, mobile, backstab multiplier |

Recoil is a **deterministic pattern plus a small random cone**: learnable, not a dice roll. The
pattern moves the camera, so it has to be pulled down, and it recovers on a spring when you stop
firing. The crosshair gap is driven by the live spread value, so what you see is what the gun
will do.

Headshots do increased damage and get their own distinct holographic hit effect and audio cue,
so you can tell a head hit from a body hit without reading a number.

---

## Abilities

| Ability | Cooldown | What it does |
| --- | --- | --- |
| **Hyper Dash** | 5s × 2 charges | Directional burst with a cyan/purple trail; keeps its speed on landing, so dash → slide chains |
| **Phase Step** | 9s | Short forward blink with holographic afterimages; refuses to fire rather than putting you inside geometry |
| **Overdrive** | 26s | +22% speed, +45% reload, +50% swap for 7s — and you glow bright purple, so the enemy sees you coming |

Charges recover independently and on a stagger, so banking one for a rotation is a real choice.
None of the three deals damage: an ability can never trade a duel for you.

---

## Game modes

| Mode | Rules |
| --- | --- |
| **Hyper Team Deathmatch** | Two teams, first to 50 eliminations |
| **Neon Control** | Three zones; points tick while you hold them. Contested zones freeze rather than reverse. Spawns move toward zones you own |
| **Core Rush** | One core, two objectives. The carrier is slower, sidearm-only and loses Phase Step — the mode where routing *is* the content |
| **1v1 Hyper Duel** | Round-based, small arena, no Overdrive. Movement and aim, nothing else |

Modes rotate automatically (`GameModeConfig.Rotation`). Each one is a class implementing
`Modes/BaseMode`, so no mode-specific logic leaks into the core services.

---

## Arena design

`NeonSpire` (and the smaller `DuelCage`) are built procedurally from `ArenaConfig`, which means
the map's balance data is a reviewable diff rather than a binary blob. Every layout follows the
same rules:

* Every long sightline has a covered flank route that beats it.
* Every raised position has **two** ways up, one of which is movement-only (wall jump or jump pad).
* Nothing is more than ~2.5 seconds of movement from cover.
* Wall-jump panels wear cyan trim, jump pads project light columns — routes are *readable*,
  not memorised.
* Environment colours are dark and desaturated; team colours never appear in the world, so an
  enemy silhouette can never be confused with a wall.

Features include the contested central spire (four ramps, four wall-jump faces), corner tower
rooftops, staggered mid platforms that chain with a dash, low-ceiling slide tunnels that only a
sliding player fits through, jump pads, mantleable low cover and wall-jumpable high cover.

Anything the movement system can interact with is driven by **CollectionService tags**
(`src/shared/Shared/Tags.luau`), so hand-built geometry dropped into the arena behaves identically
to generated geometry.

---

## Feedback

Every action gets a response inside one frame — silence reads as "the game didn't register that".

| Action | Feedback |
| --- | --- |
| Sprint | Subtle cyan speed particles, FOV lift |
| Slide | Glowing floor trail laid at fixed distance intervals, entry ring, camera roll |
| Dash | Cyan energy burst, directional ring, motion trail that outlives the dash |
| Wall jump | Neon impact ring on the wall, brightening with your chain count |
| Headshot | Distinct holographic ring + a higher hitmarker chirp |
| Elimination | Particle burst skinned to the killing weapon |
| Low health | Gently pulsing HUD vignette |

World effects are budgeted (`MAX_ACTIVE_EFFECTS`) and self-destructing: a 240fps movement shooter
that hitches during a teamfight is a 90fps movement shooter.

---

## Project layout

```
src/
  shared/           → ReplicatedStorage.HyperBlast
    Config/         Palette, Movement, Weapon, Ability, Combat, GameMode, Arena
    Shared/         MovementState, DamageMath, Tags
    Util/           Signal, Trove, Spring, Net, FxLib
  server/           → ServerScriptService.HyperBlastServer
    Services/       Player, Combat, Ability, MovementGuard, Match
    Modes/          BaseMode + the four game modes
    Arena/          ArenaBuilder
  client/           → StarterPlayer.StarterPlayerScripts.HyperBlastClient
    Controllers/    Input, Movement, Camera, Weapon, Ability, Effects, HUD
    Viewmodel/      Procedural first-person weapon rig
    UI/             HUD layout
```

---

## Tuning

Almost nothing needs code changes:

* **Movement feel** — `src/shared/Config/MovementConfig.luau`
* **Weapon balance, recoil patterns, reload timings** — `src/shared/Config/WeaponConfig.luau`
* **Ability cooldowns and strength** — `src/shared/Config/AbilityConfig.luau`
* **Health, damage, hit registration tolerances** — `src/shared/Config/CombatConfig.luau`
* **Match length, score limits, rotation** — `src/shared/Config/GameModeConfig.luau`
* **Map layout** — `src/shared/Config/ArenaConfig.luau`

The server's anti-cheat ceilings read from the *same* `MovementConfig`, so buffing sliding can
never accidentally make sliding a punishable offence.

---

## Known limitations

Stated plainly, because a design doc that only lists wins isn't useful:

* **Movement is client-authoritative**, audited server-side rather than simulated. This is the
  standard Roblox tradeoff and the only way to get zero-latency movement; `MovementGuard` catches
  naive speed hacks, not sophisticated ones.
* **Sound IDs are placeholders.** The `rbxassetid://` values in the configs are stand-ins; swap in
  your own audio.
* **No touch controls.** Keyboard/mouse and gamepad are first-class; a mobile layer would need
  its own input surface in `InputController`.
* **Characters use default Roblox rigs.** The viewmodel is procedural, but third-person character
  animation is whatever the rig ships with.
* **`Blockcast` is used for Phase Step**, which requires a reasonably current Roblox client.

---

## Design pillars

1. **Responsive.** One frame from input to motion. No animation locks on movement, no adaptive
   input buffers.
2. **Readable.** The camera never fights the player. Enemies are always the brightest, highest
   contrast thing on screen.
3. **Skill floor and ceiling.** Walking and shooting is comfortable and viable; chaining movement
   crosses the map twice as fast.
4. **Short and intense.** A match should fit inside the time it takes to decide whether you want
   another one.
