# Testing

## Automated checks

`ServerScriptService/Tests/TestRunner` runs automatically when a Studio play session starts (`DevConfig.RunTestsOnStudioStart`). You can also run it with the dev command `runtests`. It uses temporary bot combatants and dummy rigs, never real player data.

| Test | Covers |
| --- | --- |
| Weapon configs are complete and valid | every field, slot, fire mode, mode-specific tables |
| No weapon can eliminate a full health+shield target in one shot | "no instant unavoidable kills" |
| Ability, match, map and cosmetic configs are consistent | rules module per mode, map module per map, gun-game ladder, free default cosmetics |
| Data validation repairs corrupt and old profiles | migration v1→v2, wrong types, negative credits, wrong-slot equips, unknown items/settings |
| Settings sanitizer rejects invalid values | NaN, bad enum, bad type, clamping, unknown keys |
| Fire rate is limited server-side | "client fires too quickly" |
| Ammo is enforced and wrong weapons rejected | invalid ammo / invalid weapon state |
| Switching weapons cancels reload | weapon switching |
| Abilities respect cooldowns | "ability used during cooldown" |
| Remote rate limiter drops spam | remote spam |
| Progression curve is monotonic | levels |
| Spread helper stays within cone | shot spread math used by both client and server |

Static checks used during development:
- `rojo build` confirms the project tree builds.
- `luau-lsp analyze` with Roblox type definitions, run over all sources, reports no errors in non-strict mode.

## Developer commands

Developer commands work in Studio, or in a private server for UserIds listed in `DevConfig.AuthorizedUserIds`. Open the dev console with **F2**, or type `/vr <command>` in chat.

| Command | Effect |
| --- | --- |
| `help` | List commands |
| `startmatch [Mode] [Map]` | Start immediately with lobby players (+ bots) |
| `endmatch` | End the current match (results + rewards) |
| `resetround` | Restart the current match with the same players |
| `bots <count> [Easy\|Normal\|Hard]` | Add bots to the running match |
| `give <WeaponId>` | Give a weapon into its slot |
| `health <n>` | Set your health |
| `tp <x y z>` / `tp <player>` | Teleport (anti-cheat baseline is reset) |
| `god` | Toggle long spawn protection |
| `xp <n>` / `credits <n>` | Test progression and the shop |
| `runtests` | Run the automated checks |

## Manual test plan (Studio)

Use **Play** for a solo test, or **Test → Clients and Servers** with 2–3 players for multiplayer cases.

| Case | Steps | Expected |
| --- | --- | --- |
| Player joins | Play | Lobby spawn, main menu, player card shows level/credits |
| Data fails to load | Disable Studio API access, Play | Toast "progress won't save", red note on player card, game fully playable |
| Data saves | Enable API access, earn XP, stop, play again | XP/credits/loadout persist |
| Match starts | QUICK PLAY | Queue countdown → arena → frozen countdown → GO! |
| Player dies / respawns | Get eliminated by a bot (`health 5`) | Dissolve, kill feed, "Respawning in 3", respawn with spawn protection |
| Match ends | `endmatch` or reach the limit | Results with server-computed XP/credits, back to lobby after 12s |
| Player leaves during match | Clients and Servers: close one client mid-match | No errors. If they were the last real player the match ends "Aborted" without rewards |
| Leave match (controlled) | M → LEAVE MATCH (tap twice) | Back in the lobby, match continues for others |
| Server shuts down | Stop the session with players in it | `BindToClose` saves all profiles (see Output) |
| Client fires too quickly | `runtests` (fire-rate test). An exploit-style rapid `RequestFire` loop gets rejected and logged as `[AntiCheat] ... FireRate` | Extra shots dropped |
| Client sends invalid damage | There is no damage remote. Claimed hits far off the ray or through walls are rejected (`InvalidHit` log) | No damage applied |
| Impossible movement | In the client command bar set `HumanoidRootPart.CFrame` 100 studs away | Server logs `Teleport` and snaps you back |
| Player changes weapons | 1 / 2 / wheel / D-pad / SWAP | Instant switch, equip animation, reload cancelled |
| Disconnect during reload | Start a reload, close the client | No errors, state cleaned up |
| Ability during cooldown | Spam Q | Client blocks it, server rejects extras, HUD shows the timer |
| Gun Game | `startmatch GunGame` | Each elimination upgrades the weapon. A kill with the final weapon wins |
| TDM / FFA limits | Lower `ScoreLimit` in MatchConfig temporarily | Match ends at the limit with the correct winner |
| Mobile controls | Studio **Device Emulator** (phone) → Play | Touch buttons appear in the match and scale with the screen. Drag FIRE to aim |
| Controller controls | Connect a controller | All actions work, and menus can be navigated with the controller |
| Bots | `bots 4 Hard` | Bots patrol, react to sight/sound/damage, strafe, retreat, respawn |
| Shop | `credits 1000`, buy and equip a trail/skin | Credits deducted server-side, cosmetic shows on slide/dash or the weapon |
