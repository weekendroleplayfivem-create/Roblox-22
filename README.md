# WANTED: UNBOUND

An English-language Roblox street-racing game that mixes **Need for Speed: Most Wanted**-style
police pursuits with **Need for Speed: Unbound**-style street culture. Everything is generated
in code, so you don't need any models, meshes or assets.

## How to play

| Action | Keyboard | Gamepad | Mobile |
| --- | --- | --- | --- |
| Drive / steer | WASD or arrow keys | Triggers + left stick | Thumbstick |
| Drift (handbrake) | Space | X | DRIFT button |
| Nitrous | Left Shift | A | NOS button |
| Reset car to road | R | Y | RESET button |
| Interact (start race / garage / quit race) | E | B | on-screen prompt |
| Garage (at the safehouse) | G | — | on-screen prompt |

### The loop
1. **Race.** Drive into a pink race marker (**R** on the minimap) and press **E**. You pay a buy-in
   and race 3 AI rivals. Your winnings scale with your **heat level** and are worth **1.5x at night**.
2. **Raise your heat.** Finishing races, speeding past cops and ramming police all raise your heat
   (1–5 stars). More heat means bigger payouts, but also angrier cops.
3. **Escape the cops.** If a patrol sees you, a pursuit starts. Get out of sight to fill the evade
   meter, then stay hidden until **cooldown** finishes. Covered parking garages (**H**) cool you
   down 3x faster. If you're slow with a cop right next to you, the **bust** meter fills.
4. **Bank your cash.** Money you win is **unbanked** until you drive it to the **safehouse**
   (**S**). If you get busted, you lose all of it. Banking at the safehouse also clears your heat.
5. **Climb the Blacklist.** Earn total bounty and race wins, then challenge Blacklist rivals #5 → #1
   from the garage. Beat one and you win their car's **pink slip**.

### Features
- **Most Wanted:** heat levels 1–5, patrols, pursuits with evade + cooldown meters, bust meter,
  bounty, wrecking cops, **roadblocks** (heat 3+), heavy SUV units (heat 4+), a **helicopter**
  (heat 5), **pursuit breakers** (red rings on the minimap: drive through one to drop a billboard
  onto the cops chasing you), speed cameras, hiding spots and the Blacklist with pink slips.
- **Unbound:** day/night cycle with bigger night stakes, unbanked cash that you lose if you get
  busted, buy-in races, drift combos that pay cash, nitro that refills from drifting and airtime,
  and neon "driving effects" (wing trails + flames when you use nitro).
- **Race types:** sprint, circuit (laps) and a timed drift event.
- **Garage + Unbound-style tuning:**
  - 5 cars to buy and 5 Blacklist cars to win. Every car has a **Performance Rating** (PI) and a
    class from C up to S+.
  - **Performance parts:** engine, forced induction, exhaust, ECU, transmission, suspension,
    brakes, tires and nitrous. Each goes through the tiers Stock → Sport → Pro → Elite → Elite+.
  - **Handling sliders:** Drift ↔ Grip, downforce, steering speed and ride height.
  - **Visuals:** paint, 5 rim styles, rim colour, window tint, spoilers (ducktail / street wing /
    GT wing), body kits (street kit / widebody) and underglow.
  - Driving effects (nitro trail colours).
- **Realistic cars built from parts:** real-world proportions, wheel arches, a sloped hood and
  windshield, and a glass cabin with an interior. The wheels have spokes and brake calipers,
  spin, and steer. Cars also get bumpers, a grille, headlight lenses with DRLs, taillights,
  mirrors, license plates and exhaust tips. Headlights switch on at night, and brake and reverse
  lights work.
- **Realistic lighting:** Future lighting, smooth day/night colour grading (sunrise, midday, golden
  hour, dusk, night), sky with stars, clouds, sun rays, bloom, depth of field. Street lamps and
  building windows switch on at night, and the roads have painted markings.
- **More police at night:** extra patrol cars roam the city after dark, pursuits send more units,
  and reinforcements arrive faster.
- **Procedural city "Neon Bay":** 8×8 blocks of neon skyscrapers, a park with jumps, ramps,
  parking garages, a safehouse and invisible boundary walls.
- **Arcade driving model** with drifting, a chase camera and speed-based FOV.
- **HUD:** speedometer, nitro bar, heat stars, pursuit/cooldown/bust meters, cash (banked and
  unbanked), race standings, countdown, drift combo, notifications and a live minimap.
- **DataStore saving:** cash, cars, upgrades, paint, effects, bounty, wins and Blacklist progress.

## Opening it in Roblox Studio

### Option A: open the place file (easiest)
1. Download `WantedUnbound.rbxlx` from this repo.
2. Open it in Roblox Studio, then press **Play**.
3. If you want saving to work, publish the place and turn on
   *Game Settings → Security → Enable Studio Access to API Services*.

### Option B: Rojo (for development)
```bash
rojo serve        # then connect from the Rojo plugin in Studio
# or
rojo build -o WantedUnbound.rbxlx
```

After you change anything under `src/`, rebuild the place file without Rojo:
```bash
python3 tools/build.py
```

> Keep **Workspace.StreamingEnabled** off (the place file and Rojo project already do this).
> The minimap and police AI expect the whole city to be loaded.

## Project layout
```
src/shared/   (ReplicatedStorage.Shared)
  Config.lua        all tuning: cars, upgrades, heat levels, races, Blacklist, world features
  Grid.lua          road-grid helpers
  CarPhysics.lua    arcade driving model, shared by the player car (client) and the AI (server)
src/server/   (ServerScriptService.Server)
  Main.server.lua   bootstrap, remotes, lighting, day/night, garage shop, safehouse/drift/speed cams
  MapBuilder.lua    procedural city
  CarBuilder.lua    builds detailed cars out of parts (player, police, rivals)
  DayNight.lua      day/night lighting, sky, clouds, street lamps
  Vehicles.lua      spawning / resetting player cars
  AIDriver.lua      road-grid navigation + unstick logic for AI cars
  Police.lua        heat, pursuits, cops, roadblocks, helicopter, pursuit breakers, busts
  Races.lua         races, drift events and Blacklist challenges
  Session.lua       per-player runtime state and money helpers
  PlayerData.lua    DataStore save / load
src/client/   (StarterPlayerScripts.Client)
  Main.client.lua   prompts, checkpoint beacon, siren lights, main loop
  DriveController.lua  input, physics, nitro, chase camera
  HUD.lua           all on-screen UI + minimap
  Garage.lua        garage: cars, performance parts, handling, visuals, Blacklist
  CarVisuals.lua    spinning / steering wheels, headlights at night, brake lights
```

You can change almost everything in `src/shared/Config.lua`, including car stats, prices, heat
levels, race routes and rewards, and the Blacklist.
