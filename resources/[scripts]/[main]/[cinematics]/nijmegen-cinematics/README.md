# Nijmegen Scripts · Cinematics

Cinematic maker for FiveM (standalone, works with any framework). Fly a free camera, place keyframes, and play them back as a smooth cinematic with letterbox bars, filters, camera shake, time and weather.

In-game texts are Dutch by default; set `Config.Locale = 'en'` for English.

## Installation

1. Put the `nijmegen-cinematics` folder in your resources.
2. In `server.cfg`:

```cfg
ensure nijmegen-cinematics

# who may use the editor (or set Config.Everyone = true)
add_ace group.admin nijmegen.cinematics allow
# who may play a scene for ALL players
add_ace group.admin nijmegen.cinematics.broadcast allow
```

`dvadmin.admin` (Dayverse staff menu) also has access by default, see `Config.Aces`.

## Usage

`/cinematic` opens (and closes) the editor.

**Camera mode** (you fly the camera):

| Key | Action |
| --- | --- |
| W A S D | move |
| Q / E | down / up |
| Mouse | look around |
| Scroll | zoom (FOV) |
| Shift / Alt | fast / slow |
| Arrow up / down | base speed |
| Arrow left / right, X | roll, reset roll |
| **Space** | add keyframe |
| Delete | remove last keyframe |
| G | play |
| **TAB** / ESC | switch to the menu |

**Menu mode** (TAB or ESC switches back to the camera):

- **Keyframes:** per keyframe the travel time to the next point, a hold (wait) time, FOV and curve (smooth, linear, ease in, ease out). Move the camera to a keyframe, overwrite a keyframe with the current camera, reorder or delete. Select a keyframe and new ones are inserted after it. *Play from #* starts at the selected keyframe.
- **Effects:** letterbox bars, filter + strength, camera shake + strength, smooth spline path, loop, fade in/out, time and weather (only for you), hide HUD, hide your own character. Filter, time and weather are previewed live while editing.
- **Scenes:** save, load and delete scenes (stored server-side in `data/scenes.json`), play the current scene for everyone, and copy ready-made code to use a scene in another script.

Your unsaved work is kept automatically, even if you close the editor.

Backspace or ESC stops playback.

## Using scenes in other scripts

```lua
-- server: play a saved scene for one player (or -1 for everyone)
exports['nijmegen-cinematics']:PlayScene(source, 'Intro')

-- server: get a saved scene
local scene = exports['nijmegen-cinematics']:GetScene('Intro')

-- client: play a scene table directly
exports['nijmegen-cinematics']:Play(scene)
exports['nijmegen-cinematics']:Stop()
exports['nijmegen-cinematics']:IsPlaying()

-- client events
AddEventHandler('nijmegen-cinematics:started', function(name) end)
AddEventHandler('nijmegen-cinematics:stopped', function(name) end)
```

Example: a welcome cinematic when a player joins:

```lua
AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(5000, function() exports['nijmegen-cinematics']:PlayScene(src, 'Intro') end)
end)
```

## Config

Everything is in `config.lua`: language, command/key, accent colour, permissions, camera speed and sensitivity, maximum distance from your character, default keyframe time and curve, the lists of filters/shakes/weather, and `Config.OnStart` / `Config.OnStop` to hide your own HUD during a cinematic.

## Preview

Open `html/index.html` in a browser to see the editor (`#camera` at the end of the URL shows camera mode).
