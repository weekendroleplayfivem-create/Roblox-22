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

This repo contains complete, working gameplay/economy/disaster/UI/save/Steam code, but scene
and prefab assembly (an inherently Editor-GUI task) still needs to be done once inside Unity.
Follow **`Docs/EditorSetupGuide.md`** step by step - it takes roughly 30-60 minutes to reach a
playable vertical slice using primitive placeholder art (every system, including all 8
disasters, works with zero external art assets).

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
  ScriptableObjects/  (empty - populate via the Create menus per the setup guide)
  Prefabs/, Scenes/   (empty - built during the setup guide)
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
