# Steam Setup

The code ships a full Steamworks integration layer (`Assets/_Project/Scripts/SteamIntegration/`)
that is **inert by default** - the game runs and builds with zero Steam SDK installed, using
`NoOpSteamworksService`. Everything below is what turns that into a real Steam connection.
None of this is invented/fabricated Steam API behaviour - it's Steamworks.NET's real API calls,
gated so they only compile once you've actually imported the SDK.

## 1. Get a Steamworks App ID

You need a Steam Partner account and an App ID from https://partner.steamgames.com/.
Until you have one, use Valve's public test App ID **480** (Spacewar) for local development.

## 2. Import Steamworks.NET

This project does not (and cannot) bundle Steamworks.NET - it's a third-party open-source
wrapper you need to add yourself:

1. Download the latest release from https://github.com/rlabrecque/Steamworks.NET (the
   `Steamworks.NET_x.x.x.unitypackage` or the source, per their instructions).
2. Import it into `Assets/` (anywhere outside `_Project` is fine, e.g. `Assets/Steamworks.NET`).
3. This adds the `Steamworks` namespace and native `steam_api.dll`/`libsteam_api.so`/`.dylib`.

## 3. Enable the integration

1. Go to **Project Settings > Player > Other Settings > Scripting Define Symbols**.
2. Add `SW_STEAMWORKS_NET` for each platform tab you build (PC/Mac/Linux).
3. This flips `SteamService.Current` (`Assets/_Project/Scripts/SteamIntegration/SteamService.cs`)
   from `NoOpSteamworksService` to `SteamworksNetService`, which calls the real
   `SteamAPI` / `SteamUserStats` / `SteamRemoteStorage` classes.

## 4. Local testing without the Steam client running as your build

Steamworks.NET reads a `steam_appid.txt` file (containing just the App ID, e.g. `480`) placed
next to your built executable when the Steam client isn't intermediating the launch. This file
is gitignored (see `.gitignore`) - **do not commit it**, and do not ship it in your Steam
depot build (Steam injects the real App ID at runtime when launched through Steam).

## 5. Configure Achievements & Stats in the Steamworks dashboard

The game calls these exact API names (`Assets/_Project/Scripts/SteamIntegration/SteamService.cs`,
class `SteamIds`) - **you must create matching entries in App Admin > Stats & Achievements**
for your App ID, or the calls will silently no-op on Steam's side:

**Achievements** (App Admin > Stats & Achievements > Achievements):
- `ACH_FIRST_DELIVERY`
- `ACH_DELIVERY_STREAK_10`
- `ACH_DELIVERY_STREAK_50`
- `ACH_SURVIVED_TORNADO`
- `ACH_SURVIVED_FLOOD`
- `ACH_DISASTER_MAGNET`
- `ACH_REACH_LEVEL_10`
- `ACH_ALL_VEHICLES_UNLOCKED`
- `ACH_PERFECT_RUN`

**Stats** (App Admin > Stats & Achievements > Stats), all integer/int32:
- `STAT_TOTAL_DELIVERIES`
- `STAT_TOTAL_DISASTERS_SURVIVED`
- `STAT_TOTAL_MONEY_EARNED`
- `STAT_BEST_DELIVERY_STREAK`

Add art (icon) for each achievement in the dashboard - the game only sets unlock state, it
doesn't manage achievement art/text (that's entirely dashboard-side, per Steam's model).

## 6. Steam Cloud

`SaveManager` (`Assets/_Project/Scripts/SaveSystem/SaveManager.cs`) automatically mirrors the
local save file to Steam Cloud via `ISteamworksService.WriteCloudFile`/`TryReadCloudFile`
whenever `IsCloudAvailable` is true. To enable this:

1. In App Admin, go to **Steam Cloud** and enable it for your app.
2. No extra code/config is needed beyond `SW_STEAMWORKS_NET` being defined - Steamworks.NET
   handles the Cloud file API once initialized.
3. Cloud sync respects the player's own Steam Cloud settings (can be disabled per-account) -
   `IsCloudEnabledForAccount()`/`IsCloudEnabledForApp()` are checked before every write.

## 7. Steam Overlay

The Steam overlay works automatically for any game launched through Steam once `SteamAPI.Init()`
succeeds - no extra code is required. If the overlay doesn't appear in testing, confirm you're
launching via Steam (or via `steam://run/<appid>`) rather than the raw .exe when testing overlay
behaviour specifically.

## 8. Controller Support & Steam Deck

- The current input layer (`Assets/_Project/Scripts/Input/`) uses Unity's classic Input Manager
  (`Input.GetAxis`/`GetButton`), which works with any controller mapped through Windows XInput
  or **Steam Input** (Steam's controller remapping layer, which is what Steam Deck uses).
- For full Steam Deck certification you will eventually want:
  - A Steam Input controller configuration (VDF) in the Steamworks dashboard, or ship a default
    one - this is dashboard/Steam-side configuration, not something this codebase can generate.
  - Verification that the default UI is legible/usable at Deck's 1280x800 screen and that all
    interactions work with a controller only (the game already avoids requiring
    mouse-hover-only UI patterns, but test this once menus are built in the Editor).
  - Consider migrating `IInputProvider` (see `Assets/_Project/Scripts/Input/IInputProvider.cs`)
    to Unity's new Input System package (already referenced in `Packages/manifest.json`) for
    richer per-device glyph support; the interface boundary was specifically kept thin so this
    swap doesn't require touching any gameplay code, only a new `IInputProvider` implementation.
- Steam Deck compatibility review itself happens on Valve's side (Steamworks dashboard >
  Steam Deck Compatibility) once you have a build to submit - nothing to configure in-code.

## What I cannot configure for you

- Creating the actual Steamworks App ID/App Admin account (requires your Steam Partner account
  and a one-time $100 Steam Direct fee, paid by you to Valve).
- Importing Steamworks.NET itself (third-party package, licensing means it can't be
  pre-bundled here).
- Anything inside the Steamworks web dashboard (achievement art/text, Cloud toggle, Deck
  compatibility review, store page, pricing, depots/builds).
