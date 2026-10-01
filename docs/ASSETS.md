# Placeholder assets

There are no external models, meshes, images, sounds or animations in this repository. Everything visual is built from Roblox primitives in code, and every placeholder is marked `PLACEHOLDER` in the source. Replace them with original or properly licensed assets.

| Placeholder | Where | How to replace |
| --- | --- | --- |
| **Sounds** (all) | `Shared/Config/SoundConfig` uses sounds bundled with the Roblox client (`rbxasset://sounds/...`) with pitch variation | Upload original audio and set `Id = "rbxassetid://<id>"` per key |
| **Map ambience** | `SoundConfig.AmbientNeon/Sky/Core` (empty ids = silent) | Set looping track ids |
| **First-person weapon models** | `Controllers/Viewmodel` builds blocks from `WeaponConfig.Viewmodel` | Add `ReplicatedStorage/Assets/Viewmodels/<WeaponId>` (Model with PrimaryPart and an Attachment named `Muzzle`). It's picked up automatically |
| **Third-person weapon models** | `WeaponService.attachWorldModel` welds a block to the right hand | Put a BasePart named `<WeaponId>` in `ServerStorage/Weapons` |
| **Weapon animations** | `WeaponConfig.Weapons[*].Animations` (`""`). The viewmodel uses procedural equip/reload/recoil motion | Fill in animation ids and play them in `Viewmodel` |
| **Bot animations** | `BotService` loads Roblox's default R15 idle/run ids | Replace with your own uploaded animations |
| **Emotes** | `CosmeticConfig` `Emote_*` use procedural hop/spin | Add animation ids and play them in `MovementController:PlayEmote` |
| **Maps** | `ServerStorage/Maps/*.luau` build primitive geometry through `MapBuilder` | Build models in Studio and return them from the map module. Keep these conventions: spawn points (CFrame + side A/B/neutral), parts tagged `JumpPad` with a `LaunchVelocity` attribute, bot nodes, and `KillY` |
| **Signs / logo** | `MapBuilder:Sign` draws "VECTOR RUSH" text | Replace with an original logo decal |
| **UI icons** | Text-only buttons and tiles | Add original icon images to ability tiles, weapon slots and shop cards |
| **Character cosmetics** | Banners and trails are colour data | Extend `CosmeticConfig` with accessory ids if desired (cosmetic only) |
