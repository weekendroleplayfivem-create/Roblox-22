# Editor Setup Guide

Everything in `Assets/_Project/Scripts/` is complete, working C#. Scene/prefab assembly
(placing GameObjects, wiring Inspector references) is inherently a Unity Editor activity that
has to happen inside the Editor - it can't be done from outside it.

## Fast path: the automated scene builder

`Assets/_Project/Editor/DeliveryDisasterSceneBuilder.cs` builds both scenes and all supporting
prefabs/ScriptableObjects for you, using real Editor APIs (`AddComponent`, `SerializedObject`,
`PrefabUtility`) rather than hand-edited files, so every reference resolves correctly. After
opening the project (step 0 below):

1. Menu bar > **Delivery Disaster > Build Everything (Content + Scenes)**.
2. It creates: a starter vehicle (prefab + `VehicleData`, with WheelColliders/Rigidbody/damage/
   package/interaction/audio wired up), all 8 disaster prefabs + `DisasterDefinition` assets
   (pre-tuned per the table in Section 5 below), an NPC traffic prefab, a notification toast
   prefab, an empty `SfxLibrary` asset, then `MainMenu.unity` (bootstrap managers, camera, light,
   Canvas with a working Play/Settings/Quit main menu) and `Gameplay.unity` (ground, 6 delivery
   locations in a ring, an 8-node waypoint loop for traffic with checkpoints, a bridge disaster
   spawn point, all gameplay managers with their pools populated, and a full HUD Canvas -
   delivery panel, timer, money/XP, package status, disaster warning banner, notifications,
   pause menu, game over screen, and a settings panel with working volume sliders and toggles).
3. Both scenes are added to Build Settings automatically. Open `MainMenu.unity` and press Play.

It's safe to re-run (existing prefabs/ScriptableObjects are reused, not duplicated; it asks
before overwriting existing scenes). Two things it deliberately leaves for you, since they're
safer built through Unity's own menus than hand-constructed: the **Quality dropdown** on the
Settings panel (`GameObject > UI > Dropdown - TextMeshPro`, then drag it onto
`SettingsMenuUI.qualityDropdown`) and any **art/audio** (it uses primitive placeholders and
silent audio hooks throughout, exactly like every disaster does at runtime).

The manual walkthrough below is what the builder automates - read it if you want to understand
what got built, extend it by hand, or build a scene without the tool.

Estimated time for a barebones playable vertical slice by hand (primitives, no art): **30-60
minutes**; with the builder script, **under 5 minutes**.

## 0. Opening the project

1. Install **Unity 2022.3 LTS** (any 2022.3.x patch) via Unity Hub.
2. Unity Hub > Add > select this repository's root folder (the one containing `Assets/`,
   `Packages/`, `ProjectSettings/`).
3. Open it. Unity will import all scripts and auto-generate the rest of `ProjectSettings/`
   (input axes, tags, quality levels, etc. all default) plus a `Library/` cache - this can take
   a few minutes on first open. Check the Console for compile errors before continuing (there
   should be none - if there are, see the Troubleshooting section at the end).

## 1. Create the two scenes

`File > New Scene` (Basic (Built-in) template) twice, save as:
- `Assets/_Project/Scenes/MainMenu.unity`
- `Assets/_Project/Scenes/Gameplay.unity`

Add both to **File > Build Settings > Scenes In Build** (MainMenu first = index 0).

## 2. Bootstrap object (persists across both scenes)

In `MainMenu.unity`, create an empty GameObject named `_Bootstrap` and add:
- `GameManager` (Core)
- `SaveManager` (SaveSystem)
- `SteamBootstrap` (SteamIntegration)
- `AudioManager` (Audio) - drag an `SfxLibrary` asset into its `Library` field (create one via
  `Assets > Create > Delivery Disaster > SFX Library`; audio clips are optional, everything
  no-ops safely without them)
- `UnlockManager` (Economy)
- `ProgressionManager` (Economy)
- `EconomyManager` (Economy)

These are all `Singleton<T>` and call `DontDestroyOnLoad`, so one instance in the first-loaded
scene is enough for the whole game.

## 3. Create at least one Vehicle

1. `Assets > Create > Delivery Disaster > Vehicle`, name it e.g. `Vehicle_Starter`.
2. Check **Is Starter Vehicle**, set an Id (e.g. `starter_van`), leave Unlock Cost at 0.
3. Build the vehicle prefab:
   - Create a Cube (or import a car mesh later) as the visual body.
   - Add a `Rigidbody`.
   - Add 4 child empty GameObjects positioned at each wheel corner, each with a `WheelCollider`.
   - Add `VehicleController` (Vehicles) and drag the 4 `WheelCollider`s into its fields.
   - Add `VehicleDamageSystem` (Vehicles) and `PackageController` (Delivery) and
     `PlayerInteraction` (Player) with a large trigger `SphereCollider` (separate from the
     physical body collider - mark it `Is Trigger`).
   - Add `VehicleAudio` (Audio) + an `AudioSource` if you want an engine sound.
   - Drag this GameObject into `Assets/_Project/Prefabs/` to make it a prefab.
4. Back on `Vehicle_Starter`, assign the prefab to **Vehicle Prefab**.
5. On the `_Bootstrap` object's `UnlockManager`, add `Vehicle_Starter` to **All Vehicles**.

## 4. Gameplay scene setup

In `Gameplay.unity`:

1. **Ground/roads**: a Plane or your road meshes, with Colliders.
2. **Player spawn**: empty GameObject with a `World/SpawnPoint` component, Type =
   `PlayerStart`.
3. **Camera**: on Main Camera, add `VehicleCameraFollow` (Player).
4. **Vehicle spawning**: empty GameObject with `VehicleSpawner` (Player), drag the Main
   Camera's `VehicleCameraFollow` into its field (leave Spawn Point empty to auto-use the
   `PlayerStart` SpawnPoint).
5. **Delivery locations**: create 3-6 empty GameObjects around the level, each with:
   - A trigger `SphereCollider` (radius ~4-6).
   - `DeliveryLocation` (Delivery) component - name each one distinctly.
6. **Delivery manager**: empty GameObject with `DeliveryManager` (Delivery).
7. **Difficulty**: empty GameObject with `DifficultyManager` (Economy).
8. **Disasters**: empty GameObject with `DisasterManager` (Disasters) - see Section 5 below for
   populating its pool.
9. **Traffic (optional but recommended)**: place several `World/Waypoint` components around
   your roads, link each one's **Next** list to the next waypoint(s) in sequence (this draws
   gizmo lines in Scene view so you can verify the route visually). Add an empty GameObject with
   `TrafficSpawner` (World), assign an NPC vehicle prefab (same recipe as Section 3 but simpler -
   just needs `Rigidbody` + `NPCVehicleAI`) and either tag a `SpawnPoint` (Type = TrafficSpawn)
   with a `Waypoint` on the same object, or fill the Fallback Waypoints list directly.
10. **Input listener**: empty GameObject with `PauseInputListener` (UI).
11. **Checkpoints (optional)**: a few trigger volumes with `Checkpoint` (World) along the main
    route, for recovering a flipped/stuck vehicle.

## 5. Populate the Disaster pool

For each of the 8 disaster scripts in `Assets/_Project/Scripts/Disasters/Types/`:

1. Create an empty GameObject, add the matching component (e.g. `TornadoDisaster`).
2. Drag it into `Assets/_Project/Prefabs/` as a prefab (e.g. `Disaster_Tornado.prefab`), then
   delete the scene instance.
3. `Assets > Create > Delivery Disaster > Disaster Definition`, name it to match (e.g.
   `Disaster_Tornado`), assign the prefab, fill in Display Name/Warning/Duration/Cooldown.
   Reasonable starting values (tune to taste):

   | Disaster | Warning | Duration | Cooldown | Min Difficulty |
   |---|---|---|---|---|
   | Tornado | 4s | 14s | 30s | 1.5 |
   | Flood | 5s | 16s | 35s | 1.5 |
   | FallingObjects | 3s | 12s | 25s | 1.0 |
   | RoadCollapse | 3s | 20s | 30s | 1.0 |
   | VehicleExplosion | 2s | 6s | 25s | 2.0 |
   | TrafficAccident | 3s | 15s | 25s | 1.0 |
   | ConstructionZone | 3s | 18s | 30s | 1.0 |
   | BridgeBlocked | 3s | 20s | 40s | 2.5 (set Required Spawn Category = "Bridge") |

4. Drag all 8 Disaster Definition assets into `DisasterManager`'s **Disaster Pool** list.
5. For `BridgeBlocked` specifically: place a `World/DisasterSpawnPoint` (Category = "Bridge") at
   each bridge/crossing in your level, or it simply won't have anywhere valid to spawn (the
   others all fall back to "near the player" automatically and need no placement).

Every disaster spawns simple colored primitives automatically if you don't assign custom
visuals (see `DisasterBase.SpawnPlaceholderVisual`) - so the whole pool is testable immediately
with zero art.

## 6. UI

Build one Canvas (`Screen Space - Overlay`) in `Gameplay.unity` with these panels as children
(each is a plain UI Image/Panel unless noted), and attach the listed script to the object that
should own it:

- **HUD root** (only visible while Playing) - `HUDController`, drag itself as `Hud Root`.
  - Delivery panel - `DeliveryPanelUI` (needs 2 `TMP_Text`: title, target location, reward).
  - Timer - `TimerUI` (a `TMP_Text` + an `Image` with Fill Method = Radial/Horizontal).
  - Money/XP - `MoneyXpUI` (`TMP_Text` x2 + an `Image` fill bar).
  - Package status - `PackageStatusUI` (`TMP_Text`).
  - Notifications container - `NotificationSystem` on an empty container with a Vertical
    Layout Group; make a simple toast prefab (a panel + `TMP_Text`) and assign it.
  - Disaster warning banner - `DisasterWarningUI` (`TMP_Text` + `Image` + `CanvasGroup`).
- **Pause menu panel** (hidden by default) - `PauseMenuUI`, with Resume/Settings/Quit buttons
  wired to its `OnResumeClicked`/`OnSettingsClicked`/`OnQuitToMenuClicked` methods via each
  Button's OnClick.
- **Game over panel** (hidden by default) - `GameOverUI` (`TMP_Text` summary + Retry/Menu
  buttons wired to `OnRetryClicked`/`OnMainMenuClicked`).
- **Settings panel** (hidden by default) - `SettingsMenuUI`, wire each Slider/Toggle/Dropdown's
  `OnValueChanged` to the matching `On...Changed` method.

In `MainMenu.unity`, build a simple Canvas with `MainMenuUI` and Play/Settings/Quit buttons.

## 7. Play it

Open `MainMenu.unity`, press Play. Click Play, drive around with WASD/arrow keys (Space =
handbrake, E = interact, Esc = pause), pick up and deliver packages, and disasters will start
spawning on their own per `DisasterManager`'s schedule.

## Troubleshooting

- **"WheelCollider requires a convex mesh"**: WheelColliders need a valid ground collider under
  them (MeshCollider on your road must have reasonable geometry) - a flat Plane works fine.
- **TextMeshPro prompts to import TMP Essentials** the first time you use a `TMP_Text`: accept
  it (Window > TextMeshPro > Import TMP Essential Resources). One-time, per-project.
- **Nothing spawns / "No DeliveryLocation..." warning**: make sure your `DeliveryLocation`
  objects are enabled and have `Can Be Pickup`/`Can Be Dropoff` checked appropriately, and that
  there are at least 2 total.
- **Player falls through the road**: the road needs a non-trigger Collider, and the vehicle's
  WheelColliders need to actually touch it (check Y position).
