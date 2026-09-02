# HYPER BLAST — Architecture

Notes on *why* the code is shaped this way. The README covers what the game does; this covers the
engineering decisions a reviewer would otherwise have to reverse-engineer.

---

## 1. Client simulates, server audits

Roblox hands network ownership of a player's character to that player's client. That is not a
setting you can meaningfully opt out of for a character with a `Humanoid`, and fighting it means
paying a full round trip of latency on every input — which no amount of prediction hides in a game
whose entire identity is movement.

So:

* The **client** runs the movement state machine, writes velocity, and reports what it did.
* The **server** owns everything that changes match state — damage, ammo, ability charges, score —
  and audits movement for plausibility (`Services/MovementGuard`).

`MovementGuard` is deliberately an audit, not an arms race. It catches "I set my WalkSpeed to 400"
and nothing more sophisticated, which is the honest limit of what this model can promise. Its
tolerances are generous and it requires several consecutive bad samples before correcting, because
**a false positive is worse than a false negative**: one rubber-banded legitimate player has a
worse match than a lobby containing one speed hacker.

Crucially, every speed ceiling it checks comes from `MovementState.speedCeiling()`, which reads the
same `MovementConfig` the client simulates from. One source of truth means a slide buff can never
accidentally turn sliding into a bannable offence.

## 2. Hit registration

The client raycasts and reports hits; `CombatService` re-validates each one:

1. Shooter alive, and the weapon is genuinely in their loadout.
2. Rate limit, then a fire-rate audit — you cannot out-shoot your own RPM.
3. Server-side ammo.
4. Origin sanity: the reported muzzle must be near the shooter's actual head.
5. Per hit: victim alive, on the other team, not spawn-protected, and — rewound to the shot
   timestamp — actually near the reported hit point.
6. Line of sight from origin to the rewound position (skipped for wallbangs, which are *defined*
   by shooting through something).

Anything that fails is dropped silently for that shot. Nothing kicks: a misprediction on a bad
connection is not cheating.

Damage itself lives in `Shared/DamageMath`, required by **both** sides. The client shows its
hitmarker on the frame you click, from the same formula the server will apply, so the feedback is
instant and a mismatch is always a bug in the inputs rather than in the maths.

Lag compensation keeps ~5 position samples per player (`MaxRewindTime / HISTORY_INTERVAL`), which
bounds memory regardless of lobby size or match length.

## 3. Why a hybrid physics model

Three options were on the table for movement:

| Approach | Verdict |
| --- | --- |
| Pure `Humanoid` (`WalkSpeed`/`JumpPower` only) | Can't express momentum, slides or air strafing |
| Fully custom controller (`LinearVelocity`, no Humanoid) | Weeks of re-solving stairs, slopes, ledges, moving platforms — for no player-facing gain |
| **Hybrid** | Chosen |

The hybrid: the `Humanoid` keeps ordinary ground locomotion, with our momentum scalar driving
`WalkSpeed` every frame. Air control layers a Quake-style acceleration onto the assembly velocity.
Scripted states (slide, dash, phase, mantle) set `WalkSpeed = 0` and drive the assembly velocity
outright, so the Humanoid stops fighting them.

The simulation runs in `RunService.PreSimulation` where available (velocity writes land *before*
the physics step, saving a frame of latency), falling back to `Heartbeat`.

Mantle and Phase Step anchor the root and interpolate its CFrame — the only two places the game
takes positional control, and both are under 300ms with the camera left entirely to the player.

## 4. One update, one order

`MovementController:_step` runs the same six phases in the same order every frame:

```
probe ground → transitions → stamina → apply motion → stance → publish
```

Movement logic split across several unordered event handlers is movement logic you cannot debug at
2am before a playtest. Landing is allowed to *consume* a frame (it can start a buffered jump or a
slide), and when it does, transition evaluation stops rather than acting on now-stale local state.

## 5. States vs. modifiers

`MovementState` is exclusive: you are sliding *or* airborne *or* sprinting. Overdrive and ADS are
**not** states — they are multipliers on whatever state you're in (`MovementController.modifiers`).
Keeping that separation is what stops a state machine from becoming combinatorial: adding a fourth
buff costs one field, not eleven new states.

## 6. Dependency wiring

Both bootstraps build a plain table and pass it by reference:

```lua
local services = {}
services.Player  = PlayerService.new(services)
services.Combat  = CombatService.new(services)   -- can read services.Match later
services.Match   = MatchService.new(services)
```

No service locator, no require cycles, and exactly one file that decides what exists and in what
order it wakes up. A service constructed early can reference one constructed later because it holds
the table, not the value.

The client mirrors this with `context` (`Input → Movement → Camera → HUD → Effects → Ability →
Weapon`), which is also the dependency order they start in.

## 7. Data over code

Weapons, abilities, movement, arenas and match rules are all config tables. Three consequences that
actually matter:

* **Animation timings are data.** Reload length lives in the same table as the damage numbers, so
  they cannot drift apart the way a keyframed clip and a gameplay timer do.
* **Map balance is a reviewable diff.** Shortening a sightline or moving a jump pad is a change a
  reviewer can read, not a binary blob.
* **Tags, not names.** Everything the movement system touches is found via `CollectionService`
  tags, so hand-built geometry dropped into an arena behaves identically to generated geometry.

## 8. Performance budget

* HUD elements write only when their value changed; the HUD never rebuilds instances per frame.
* World effects are counted (`MAX_ACTIVE_EFFECTS`) and the least important are dropped first.
* Every effect self-destructs via `Debris`.
* Movement snapshots go out 12×/sec over an **unreliable** remote; anything that changes
  authoritative state uses a reliable one. Dropping a stale position packet is free; head-of-line
  blocking is not.
* Four raycasts per frame for wall detection, one for ground, two for mantle — all only when the
  relevant state can actually occur.

## 9. Where to extend

| You want to… | Touch this |
| --- | --- |
| Add a weapon | `Config/WeaponConfig.luau` — no controller changes |
| Add an ability | `Config/AbilityConfig.luau` + a branch in `AbilityController:TryUse` + a movement entry point |
| Add a game mode | Subclass `Modes/BaseMode`, register it in `MatchService.MODE_CLASSES`, add a `GameModeConfig` entry |
| Add a map | `Config/ArenaConfig.luau`; `ArenaBuilder` consumes it unchanged |
| Add a movement verb | A state in `MovementState`, its numbers in `MovementConfig`, a branch in `_handleTransitions` and `_applyMotion`, and a ceiling in `speedCeiling()` |
