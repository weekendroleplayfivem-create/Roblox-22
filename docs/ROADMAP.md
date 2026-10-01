# Known limitations

- **Untested in a live Roblox runtime by the author.** The code was checked with `rojo build` and `luau-lsp` static analysis using Roblox API definitions, but it has not been played in Studio yet. Expect some tuning and small fixes during the first playtest. The automated `TestRunner` runs on the first Studio play.
- **One arena per server.** Matchmaking is per server: queued players in a server play together, and bots fill the rest. Cross-server matchmaking (MemoryStore queues + TeleportService to reserved servers) isn't implemented.
- **Hit validation trusts the client's ray direction within the spread cone.** The server validates the cone, the claimed point, line of sight, range and target history, but it can't prove a player aimed by hand. Aim-assist cheats aren't detectable with these checks. Add statistical heuristics (headshot ratio, snap angles) later.
- **Lag compensation** checks the claimed point against the target's root-position history (about 5.5 studs of tolerance). This is generous for high-ping players and could be tightened with per-part history.
- **Movement anti-cheat** checks horizontal speed, teleports, no-clip, upward speed and airtime. Subtle speed boosts under the tolerance (about 35%) aren't detected.
- **Bots** use PathfindingService. They can't path across Sky Lab's jump gaps, so they pick another route instead. Bots don't use abilities yet.
- **Decoys** are clones without animations (their Animate script is removed), so they slide rather than run.
- **Touch camera sensitivity** uses Roblox's default touch camera. The touch-sensitivity setting was intentionally left out until a custom touch camera exists.
- **Character models** use default Roblox avatars, and arms aren't visible in first person (placeholder glove only).
- **Global leaderboard** names are resolved with `GetNameFromUserIdAsync` and cached for 60 seconds.

# Recommended next steps

1. **Playtest in Studio and tune.** Movement feel (acceleration, slide, momentum decay), recoil and spread, time-to-kill, and map scale. Every value is in `Shared/Config`.
2. **Art pass.** Real viewmodels, arm rigs and animations, VFX textures, original audio, UI icons and a logo (see `ASSETS.md`).
3. **Hand-built maps.** Replace the procedural geometry. Keep the spawn, pad and bot-node conventions, and re-run the spawn-visibility tuning.
4. **Cross-server matchmaking.** Use MemoryStoreService queues and TeleportService reserved servers. Use `QueueService:RankPlayers` for MMR.
5. **Kill cam / spectate** while waiting to respawn, plus a match-start team intro.
6. **Analytics and anti-cheat heuristics.** Accuracy/headshot statistics per weapon, flagged-session review tooling.
7. **More modes.** Use the `MatchService/Modes` interface for objective modes (King of the Hill, Capture).
8. **Accessibility.** Colour-blind team palettes, a hit-marker size option, subtitles for announcements.
9. **More automated tests.** CI already builds the place and runs `luau-lsp analyze` (`.github/workflows/ci.yml`); add TestEZ/Jest-Lua unit tests for shared modules and run the in-game `TestRunner` via Open Cloud Luau execution.
