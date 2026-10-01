# Architecture

## Boot

- **Server**: `ServerMain` runs `Net.Setup()` to create every remote, requires the services in a fixed order, then calls `Init(Services)` on all of them (wiring only, no yielding) and `Start()` on all of them (events and loops). Services talk to each other through the shared `Services` table, so there are no circular requires.
- **Client**: `ClientMain` does the same with the controllers.

## Security model

The client sends **intents** and the server decides **outcomes**.

| Never trusted from the client | Who decides |
| --- | --- |
| Damage, eliminations, assists | `CombatService` (computes damage from `WeaponConfig`) |
| Hit confirmation | `CombatService.validateHit` (ray angle, range, line of sight, lag-compensated position) |
| Fire rate, ammo, equipped weapon, reload, charge level | `WeaponService` (token bucket per weapon, server-timed reload/charge) |
| Ability cooldowns and effects | `AbilityService` |
| Currency, XP, unlocks, purchases | `ProgressionService`, `ShopService`, `WeaponService.SetLoadout` |
| Match results | `MatchService` + mode rules |
| Settings | `DataService` sanitizes every value with `SettingsConfig` |
| Movement | `AntiCheatService` (speed, teleport, no-clip, flight) |

`Net.OnServerEvent` / `Net.OnServerInvoke` wrap every handler in a per-player token bucket. Excess requests are dropped and reported to the anti-cheat. Every handler type-checks its payload.

## Combatants

`CombatantService` gives players and bots one shared shape (`Id`, `Team`, `Character`, `Stats`, `Shield`, `DamageLog` and so on). Characters carry the attribute `CombatantId`. Spawning, damage, scoring and the scoreboard all work on combatants, so bots follow exactly the same rules as players.

## Match flow (`MatchService`)

```
Lobby → (QueueService countdown) → Loading (build arena, add players + bots)
      → Countdown (everyone spawned, Frozen attribute) → Active (combat on, time limit)
      → Results (rewards, frozen) → Cleanup (bots removed, players → lobby) → Lobby
```

- Mode rules (`Modes/TeamDeathmatch`, `FreeForAll`, `GunGame`) implement `Setup`, `PickTeam`, `GetLoadout`, `OnElimination` (returns true to end the match) and `GetWinner`.
- Respawns happen `PlayerConfig.Respawn.Delay` seconds after an elimination and add spawn protection. Firing ends spawn protection early.
- Join in progress: queueing during Active/Countdown adds you straight away, balanced onto a team, and removes a bot if needed.
- Leaving: through the pause menu (`QueueRequest "LeaveMatch"`) or by disconnecting. If no real players remain, the match ends early with no rewards.
- `QueueService` picks the most-voted mode. `QueueService:RankPlayers` is the hook where MMR sorting and splitting can go later.

## Spawning (`SpawnService`)

Every spawn point gets a score built from these factors:
- **Plus**: distance to the nearest living enemy (capped), nearby teammates in team modes, and being on your team's side.
- **Minus**: an enemy can see it (line of sight from enemy heads), an enemy is too close, recent deaths nearby, recent combat nearby, a neutral spawn in a team mode, and having been used in the last 3 seconds.

A small random jitter is added so spawns aren't predictable. All weights are constants at the top of the file.

## Movement (`MovementController` + `AntiCheatService`)

The character's physics is owned by the client, which is standard on Roblox, so movement runs on the client with zero latency:
- **Acceleration and deceleration**: walk speed moves toward its target at configured rates.
- **Momentum**: extra speed from slides, dashes, pads and wall jumps sits above the base speed and bleeds off. It bleeds off slower in the air, so slide-jumps carry.
- **Slide**: only from a sprint above `MinStartSpeed`. It lasts 0.7s, locks the slide direction, lowers and tilts the camera, shows a trail, and has a cooldown.
- **Double jump**: once per airtime. Wall jumps go through `Shared/Modules/WallMovement`: up to 2 per airtime, with a same-wall cooldown, and they can be disabled in config.
- **Dash**: a `LinearVelocity` in Plane mode for 0.16s. A raycast shortens the dash so it stops before walls; it never teleports.
- **Jump pads**: tagged `JumpPad` with a `LaunchVelocity` attribute. **Low-g fields** apply a `VectorForce`.

The server samples every player's position at 10 Hz:
- Horizontal speed is checked against the max configured speed × tolerance, or against an active **allowance**. Dash, phase, jump pads and wall jumps all grant allowances.
- Big jumps with no allowance count as teleports. A ray between samples hitting solid geometry counts as no-clip. Upward speed and long airtime are checked for flight.
- Violations add suspicion. Above a threshold the player is moved back to their last valid position. Only sustained, very high suspicion in a live server leads to a polite, non-permanent kick. Details only ever go to the server log.

## Weapons (`WeaponConfig`, `WeaponService`, `WeaponController`)

Every weapon is a data table: damage, headshot multiplier, fire rate/mode, burst, magazine, reserve, reload, range, falloff, spread, recoil, projectile, pellets, charge, chain, movement penalty, equip time, ADS FOV, animation and sound references, cosmetic category, unlock level, and viewmodel description. There are 12 weapons across 10 categories, including Burst, Scatter (9 pellets), Charge (the server measures the hold time), Beam (15 ticks/s), Arc (chains to a nearby enemy, server-picked) and Plasma (a server-simulated projectile with splash).

On the client, each shot:
1. Checks local timing and ammo.
2. Builds pellet directions inside the current spread cone (spread grows with movement, air, bloom and hip fire).
3. Raycasts, then shows the tracer, muzzle flash, impact, sound, recoil and a predicted hit marker.
4. Sends `RequestFire { Weapon, Shot, Origin, Direction, Pellets?, Hits? }`.

On the server (`CombatService.HandleFireRequest`):
1. Validates the payload types.
2. Checks the shooter is alive and in an active match.
3. `WeaponService:TryConsumeShot` checks the equipped weapon, equip time, reload, ammo and fire-rate token bucket.
4. Checks the origin is within tolerance of the server head position (scaled by speed and ping).
5. Checks pellets are inside the weapon's max spread cone.
6. For each claimed hit, checks:
   - the target is a live enemy;
   - the part belongs to the target;
   - range;
   - the hit point lies on the claimed ray;
   - no world geometry blocks the line;
   - the point is near where the target was during the last `ping + 0.15s` (lag compensation from a 1-second position history).
7. Computes damage from config (falloff × headshot × charge), then applies shields first, then health.

Server-side tuning guarantees that **no weapon can eliminate a full health + shield target with one shot**. `TestRunner` asserts this.

## Abilities (`AbilityConfig`, `AbilityService`, `AbilityController`)

You have one Movement slot (Dash, Phase) and one Tactical slot (Barrier, Scan Pulse, Decoy, Low-G Field). The client predicts cooldowns and the server owns them.

| Ability | What the server does |
| --- | --- |
| **Barrier** | Builds a part tagged `ShotBlocker`. It blocks enemy shots only, both client-side and in server line-of-sight checks. |
| **Decoy** | Builds a hologram clone that runs forward. Bots can be fooled by it, and any enemy hit pops it. |
| **Scan Pulse** | Reveals enemies inside the radius to the user's team. Revealed players are told they were scanned. |
| **Low-G Field** | Places a sphere tagged `GravityField`. Clients inside it get reduced gravity. |
| **Phase** | Sets a `Phased` attribute. The speed boost runs on the client, the server grants a matching allowance, and other players see you partly transparent. |

## Data (`DataService`)

- **Store and lock**: `UpdateAsync` with a **session lock** (`Lock = {Session, Time}`). A lock owned by another live server is waited on and retried; a lock older than 30 minutes is treated as stale and taken over.
- **Retries**: exponential backoff. Studio "API access disabled" errors fail fast.
- **Reading old data**: `Migrate` steps through the version migrations, then `Validate` (Reconcile with defaults, clamps, unknown items dropped, invalid equips reset).
- **When loading fails**: you get a **temporary profile**. It is playable but never saved, so your real data can't be overwritten. You're told about it with a toast and a warning on your player card.
- **Saving**: autosave every 120 seconds, a save that releases the lock when you leave, and parallel saves in `BindToClose`.
- **Contents**: XP, Level, Credits, owned cosmetics, equipped loadout and cosmetics, lifetime stats and settings.

## Progression and shop

- **XP**: participation (plus a per-minute amount), eliminations, headshots, assists, victory or top three, and per-match challenges. Elimination XP is awarded immediately, so leaving early never loses it.
- **Credits**: per match, per elimination, for winning, and for each level up. Weapons and abilities unlock by **level only**.
- **Shop**: cosmetics only (weapon skins, trails, elimination effects, banners, crosshairs, emotes) at fixed, visible Credit prices. There are no random rewards and no paid currency. Cosmetics never change stats.

## Bots (`BotService`, `BotBrain`)

- **States**: Patrol (pathfinding between map bot nodes), Investigate (sounds), Chase (last seen position), Engage (strafe, keep a preferred range, shoot after a reaction delay with aim error) and Retreat (low health).
- **Fair perception**: a view cone plus distance plus line of sight, hearing gunshots within a radius, being damaged, and allied scan pulses. Bots never read positions they couldn't perceive.
- **Difficulty**: Easy, Normal and Hard change reaction time, aim error, fire rate, view distance, field of view, hearing, strafing and weapon pool.
- **Same rules as players**: bots fire through `WeaponService` (ammo and fire-rate rules) and `CombatService`. They avoid strafing off ledges.

## Client controllers

| Controller | Responsibility |
| --- | --- |
| `ClientState` | Store for server snapshots (profile, match, queue, scoreboard, settings) |
| `InputController` | Keyboard, gamepad and touch mapped to named actions; input is blocked while menus are open |
| `CameraController` | Removes last frame's cosmetic offset → default camera → applies permanent recoil and a new offset (bob, shake, landing dip, slide tilt, damage punch), spring FOV (sprint, slide, dash, ADS), sensitivity |
| `MovementController` | Everything in the Movement section |
| `WeaponController` | Fire modes, spread, recoil, ammo prediction, reload and switch, viewmodel |
| `AbilityController` | Cooldown prediction, local dash, ability requests |
| `EffectsController` | Pooled tracers and rings, bursts, projectile visuals, dissolve on elimination, reveals, other players' movement FX, lighting and ambience per map |
| `SoundController` | Keyed 2D and 3D sounds, master volume |
| `UIController` | Screen coordination, Modal mouse release, CoreGui setup |

## Remotes (`Shared/Modules/Net.Definitions`)

| Category | Remote | Dir | Purpose |
| --- | --- | --- | --- |
| Combat | RequestFire | C→S | Fire intent + claimed hits |
| Combat | RequestReload | C→S | Reload intent |
| Combat | ChargeStart | C→S | Start of a charge (server times it) |
| Combat | ShotReplicated *(unreliable)* | S→C | Cosmetic tracer for other players |
| Combat | HitConfirm | S→C | Hit marker / damage number for the shooter |
| Combat | DamageTaken | S→C | Direction indicator for the victim |
| Combat | Elimination | S→C | Kill feed + dissolve |
| Combat | ProjectileSpawned / ProjectileImpact | S→C | Projectile visuals |
| Inventory | EquipSlot | C→S | Switch weapon |
| Inventory | WeaponState | S→C | Authoritative slots + ammo |
| Inventory | SetLoadout *(function)* | C→S | Choose weapons/abilities (validated) |
| Movement | MovementAction | C→S | Slide / DoubleJump / WallJump notification |
| Movement | MovementFx *(unreliable)* | S→C | Others' movement FX |
| Movement | Correction | S→C | Server moved you back |
| Abilities | UseAbility | C→S | Ability intent |
| Abilities | AbilityState | S→C | Authoritative cooldowns |
| Abilities | AbilityEffect | S→C | Reveal / decoy popped / revealed |
| Match | QueueRequest | C→S | Join / Leave / LeaveMatch / Refresh |
| Match | QueueState, MatchState, Scoreboard, Announcement, Results, XPEvent | S→C | Match UI |
| UI | DataSync | S→C | Your own profile |
| UI | Notify | S→C | Toasts / level up |
| UI | UpdateSettings | C→S | Settings (sanitized) |
| UI | PurchaseItem, EquipCosmetic, GetLeaderboard, RequestData *(functions)* | C→S | Shop / stats |
| UI | DevCommand *(function)* | C→S | Studio/private test only |

## Performance notes

- One render loop each for the camera, the weapon/viewmodel and the HUD. Everything else is event-driven or runs on throttled Heartbeat accumulators (anti-cheat 10 Hz, bots 8 Hz, regen 5 Hz, history 20 Hz, scoreboard 1 Hz).
- Tracers, rings and muzzle flashes are pooled. The **Reduced Effects** setting skips particles and secondary impacts.
- Projectiles are pure data on the server. Cosmetic broadcasts use unreliable remotes.
- Maps are built of anchored primitives (roughly 150–300 parts each), and only one arena exists at a time.
- `Maid` cleans up per-character connections. Ability objects have lifetimes set through `Debris`.
