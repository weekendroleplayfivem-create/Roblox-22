# Depths

A dungeon crawler for Roblox: 3 biomes (Crypt, Fungal Depths, Molten Forge),
procedurally generated floors, server-authoritative combat, itemization, and
a Hades/Balatro-style relic pick system. See `docs/DESIGN_BIBLE.md` for the
full design doc (biome identities, enemy/boss roster, rarity rules, talent
and relic maps, and the "why" behind major system choices).

## How this codebase is built

This repo is a [Rojo](https://rojo.space/) project, not a `.rbxl` file. Code
is authored as plain `.lua`/`.luau` files under `src/`, mapped to Roblox
service paths by `default.project.json`. This is the standard way to develop
Roblox games with real version control, code review, and CI outside Studio.

**Why Rojo and not direct Studio edits:** this session doesn't have a live
Roblox Studio plugin connection — it's a git/GitHub-only environment. Every
system in this repo (procedural generation, combat validation, loot rolls,
save schema, all content data) is real, runnable Luau, but none of it has
been visually verified in Studio or played live yet. To pick this up in
Studio:

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
   (CLI + the Studio plugin).
2. From the repo root: `rojo serve`
3. In Studio, open the Rojo plugin and connect to the running session.
4. Play-test with F5, exactly as you would any other Studio project.

Once connected, the natural next steps (per `docs/DESIGN_BIBLE.md` §8 and the
process below) are: instance the Crypt's `DungeonGenerator` output into real
parts, build/verify movement and camera, hook up the first 2-3 enemies and a
basic attack loop live, and screen-capture against the anti-slop bar before
moving on to the full UI pass.

## Project layout

```
src/
  ServerScriptService/
    Main.server.lua        -- bootstrap: creates Remotes, Init()s every service, drives the shared tick loop
    Services/               -- DungeonGenerator, CombatService, EnemyAIService, BossService, LootService,
                              InventoryService, ProgressionService, EconomyService, LightingService,
                              SaveService, PartyService, AnalyticsService, BiomeRegistry
  ReplicatedStorage/
    Shared/
      Types.lua              -- the typed contract every content/data module and service satisfies
      Data/                  -- biomes, enemies, bosses, items, rarity, talents, relics (all data-driven)
      Modules/                -- UIStyle, StatusEffects, Remotes registry
  StarterGui/                -- full HUD/menu suite lands here in Phase 3 (not yet built)
  StarterPlayerScripts/
    Main.client.lua          -- client bootstrap: Remotes handshake only, no gameplay logic
  StarterCharacterScripts/
  ServerStorage/
    Vaults/                  -- hand-placed boss arenas / secret rooms (authored in Studio)
docs/
  DESIGN_BIBLE.md
```

## Status

Phase 1 (architecture scaffold + data-driven content stubs, per the build
process in the original brief) is complete: every service module, the shared
type contract, and a real first pass of biome/enemy/boss/item/talent/relic
content exist and are internally consistent. Phase 2 (biome 1 vertical
slice — instanced geometry, movement/camera, live combat, one boss, verified
in Studio) has not started yet. See `docs/DESIGN_BIBLE.md` §8 for the
tracked follow-up list.
