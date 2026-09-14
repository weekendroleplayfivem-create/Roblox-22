# Delivery Disaster

A chaotic delivery-driving game for PC/Steam built in Unity. Pick up packages, race them to
their destination before the timer runs out, and survive whatever the disaster system throws
at you along the way - tornadoes, floods, falling debris, road collapses, exploding traffic,
and more.

## Requirements

- Unity **2022.3 LTS** (any patch version)
- (Optional, for real Steam integration) [Steamworks.NET](https://github.com/rlabrecque/Steamworks.NET)
  - see `Docs/SteamSetup.md`

## Getting started

1. Open this repo's root folder as a project in Unity Hub (Unity 2022.3 LTS).
2. Menu bar > **Delivery Disaster > Build Everything (Content + Scenes)**. This builds both
   scenes and every supporting prefab/ScriptableObject (vehicle, all 8 disasters, traffic, UI)
   automatically via `Assets/_Project/Editor/DeliveryDisasterSceneBuilder.cs`, using real Editor
   APIs rather than hand-edited files.
3. Open `Assets/_Project/Scenes/MainMenu.unity` and press Play.

Everything works with primitive placeholder art out of the box - no external assets required.
See **`Docs/EditorSetupGuide.md`** for what the builder creates and how to extend or hand-build
a scene yourself instead.

## Project layout

```
Assets/_Project/
  Scripts/
    Core/            GameManager, EventBus, shared enums
    SaveSystem/       JSON save/load + Steam Cloud hook
    Economy/          Money, XP/levels, difficulty scaling, unlocks/upgrades
    Vehicles/         VehicleController (WheelCollider-based), damage system, vehicle data
    Player/           Interaction, camera follow, vehicle spawning
    Delivery/         Job generation, pickup/dropoff, package condition
    Disasters/        Modular disaster framework + 8 concrete disasters
    World/            Traffic AI, waypoints, obstacles, checkpoints, spawn points
    UI/               HUD, delivery panel, timer, notifications, menus
    Audio/            Event-driven SFX/music hub
    SteamIntegration/ Achievements/stats/cloud, NoOp-by-default
    Input/            Swappable input abstraction
  Editor/              DeliveryDisasterSceneBuilder.cs - builds both scenes + prefabs/SOs
  ScriptableObjects/, Prefabs/, Scenes/  populated by running the scene builder (see above)
Docs/
  EditorSetupGuide.md  Step-by-step scene/prefab assembly
  SteamSetup.md         What to configure for real Steam integration
```

## Adding content (by design, none of this requires touching manager code)

- **New vehicle**: `Assets > Create > Delivery Disaster > Vehicle`, build a prefab with
  `VehicleController`, add both to `UnlockManager`.
- **New disaster**: subclass `DisasterBase`, make a prefab, create a
  `Delivery Disaster > Disaster Definition` asset pointing at it, add to `DisasterManager`'s pool.
- **New delivery location**: any GameObject with a trigger Collider + `DeliveryLocation`.
- **New upgrade/cosmetic**: `Assets > Create > Delivery Disaster > Upgrade` / `> Cosmetic`, add
  to `UnlockManager`.
