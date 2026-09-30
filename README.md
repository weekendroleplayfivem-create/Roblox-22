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
| City map | M | — | menu → CITY MAP |
| Pause menu | P | — | ☰ button |

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

### Big city update
- **Better driving:**
  - Smooth steering input that ramps in and recentres quickly.
  - The car has yaw inertia: it rotates into turns instead of snapping.
  - Weight transfer: braking sharpens turn-in, and throttle settles the car.
  - A traction limit off the line and engine braking.
  - **Unbound-style brake-to-drift:** tap the brake, then get back on the gas while steering.
  - **Drift assist:** holding the throttle keeps the slide going, and the car won't spin out past
    about 60 degrees.
  - A moment of looseness after landing a jump.
- **A WAY bigger map:** 16×16 blocks (4.8 km a side, 4× the area).
  - **Downtown:** glass skyscrapers.
  - **Midtown:** brick apartments, offices and shops.
  - **Suburbs:** detached houses with gable roofs, chimneys, driveways, garages, mailboxes, back
    yards and fences.
  - **Industrial docks** on the east side: warehouses with loading bays, stacked shipping
    containers, tank farms and harbour cranes.
  - **The Beltway:** a freeway ring road with lane lines, guard rails and green exit-sign gantries.
  - **Terrain:** an ocean with beaches to the east and south, and hills and snowy mountains to the
    north and west.
  - Traffic lights and crosswalks in the dense districts, stop signs in the suburbs and docks.
  - 42 traffic cars, more police (10 patrols by day, +8 at night) and 3 new races: Beltway Blitz,
    Suburb Scramble and Dockyard Dash. Four new hiding spots, more speed cameras, pursuit
    breakers and ramps.
  - **StreamingEnabled** is on, so each player only loads the area around them. Cop cars and
    player cars stay visible city-wide.
- **Better menus:**
  - A new **main menu**: cinematic camera shots, animated buttons, a player card with your stats,
    **Settings**, How to play, Credits and a rotating tips bar.
  - **Settings** (saved to your profile): camera shake, speed lines, motion blur, MPH or KM/H,
    volume and a performance mode (turns off shadows and heavy post effects).
  - **Pause menu:** press P or the ☰ button.
  - **Radar minimap** that follows your car, with district colours.
  - **Full city map:** press M. It shows every race with its name, the safehouse, hiding spots
    and live police.

### Sound, better cars and the garage interior
- **Sound:**
  - A **synthesized engine** with no audio ids needed. It's built from Roblox's own wind-noise
    sound: pitched down, bass-boosted, distorted and pulsed at the firing rate. It follows a
    simulated RPM through 6 gears, with shift dips and a turbo/intake whine.
  - Wind rush that grows with speed, a synthesized tyre screech while drifting and a flat-tyre
    rattle.
  - Exhaust backfire pops (with flames) when you lift off at high revs.
  - Crash thuds, explosions when cops get wrecked, near-miss whooshes, checkpoint beeps and UI
    clicks.
  - Nearby cars (traffic, cops, rivals, other players) get 3D engine sounds.
  - Only sounds that actually ship with the Roblox client are used (`content/sounds`). For a real
    engine recording, siren or tyre screech, paste audio ids into `Config.Sounds.Engine / Siren /
    Skid`.
- **Better cars:**
  - The body is sprung: it **leans in corners, squats when accelerating and dives when braking**,
    with a little bounce.
  - **Skid marks** are left on the road while sliding.
  - Rubber tyres, and a **tachometer with gear indicator** on the speedometer.
  - 3 new cars: **Kitsune S15** (drift), **Rally Hatch R** (new hatchback body) and **Veloce V12**.
- **Enter the garage:** press **E** (or G) at the safehouse to drive into an underground workshop.
  Your car sits on a lit turntable while the camera orbits it. The workshop has tool chests, a
  workbench, tyre racks, a car lift and posters. The garage menu is on the right, so you watch
  your car change as you tune it. Press E again to drive back out.

### Realistic city update
- **Real architecture** (every building is made of parts, no meshes):
  - **Glass skyscrapers:** setbacks, curtain-wall mullions and floor bands, a marble lobby with an
    entrance canopy, and roof machinery. They also get antennas with red aircraft beacons or
    helipads.
  - **Office blocks:** ribbon windows, rooftop AC units and billboards.
  - **Brick apartment buildings:** punched windows, stone cornices, fire escapes and rooftop water
    tanks, with shops on the ground floor.
  - **Low-rise shops:** storefront glass, fabric awnings and lit shop signs (PHARMACY, PIZZA,
    BANK...).
  - Parking lots.
- **Windows light up at night**, but not all of them, in slightly different warm tones.
- **Streets:** paved sidewalks with curbs, trees with grates, hydrants, bins and bus stops.
- **Intersections:** zebra crosswalks, stop lines and **working traffic lights**. The lights are
  synced on every client, and **traffic stops at red lights**. Cops and racers run them.
- **Natural lighting:** a deep blue night lit by warm street lamps, soft sunrise, neutral daylight
  and golden hour, instead of the purple neon look.
- Realistic asphalt colour and concrete jersey barriers at the edge of the city.

### New in this version
- **Title screen** with a camera flight over the city, plus a "How to play" screen.
- **City traffic:** civilian cars stay in the right lane, turn at intersections and brake for
  cars ahead.
- **Near misses:** pass traffic close and fast without touching it to earn cash and nitro. Chain
  them for a combo.
- **Spike strips** from heat 3: flat tyres make your car slow and slippery for 8 seconds, with
  sparks. From heat 4 some roadblocks are one long spike strip with a single open lane.
- **Smarter cops:** they use nitro on long straights to catch up.
- **Milestones:** 27 challenges with cash rewards (wreck cops, escape pursuits, near misses,
  drift combos, speed cameras, race wins and more). There's a Milestones tab in the garage.
- **Speed effects:** camera shake (speed, nitro and crashes), speed lines, nitro blur and colour
  grading, and a flash when you crash.
- **Animated banners:** PURSUIT, BUSTED, ESCAPED, HEAT LEVEL, SPIKED!, 1ST PLACE, BLACKLIST
  DEFEATED, MILESTONE COMPLETE.
- **GPS arrow** floating above your car that points to the next checkpoint, the nearest hiding
  spot (during cooldown) or the safehouse (when you're carrying unbanked cash).
- **Live race standings** in the race panel, and traffic shown on the minimap.
- **Sounds:** near miss, checkpoint and banner sounds. You can add engine and siren loops by
  pasting audio ids into `Config.Sounds` in `src/shared/Config.lua`.

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

> **Workspace.StreamingEnabled** is on (the place file and Rojo project set it, with a 1500-stud
> target radius). The city is too big to send to every player at once.

## Project layout
```
src/shared/   (ReplicatedStorage.Shared)
  Config.lua        all tuning: cars, upgrades, heat levels, races, Blacklist, world features
  Grid.lua          road-grid helpers
  Signals.lua       traffic light timing (shared clock)
  CarPhysics.lua    arcade driving model, shared by the player car (client) and the AI (server)
src/server/   (ServerScriptService.Server)
  Main.server.lua   bootstrap, remotes, lighting, day/night, garage shop, safehouse/drift/speed cams
  MapBuilder.lua    procedural city layout (roads, blocks, special areas)
  Architecture.lua  realistic buildings, sidewalks, street furniture, crosswalks, traffic lights
  CarBuilder.lua    builds detailed cars out of parts (player, police, rivals)
  DayNight.lua      day/night lighting, sky, clouds, street lamps
  Vehicles.lua      spawning / resetting player cars
  AIDriver.lua      road-grid navigation + unstick logic for AI cars
  Police.lua        heat, pursuits, cops, roadblocks, spike strips, helicopter, pursuit breakers, busts
  Traffic.lua       civilian traffic
  Showroom.lua      the garage interior (underground workshop with turntable)
  Races.lua         races, drift events and Blacklist challenges
  Session.lua       per-player runtime state and money helpers
  PlayerData.lua    DataStore save / load
src/client/   (StarterPlayerScripts.Client)
  Main.client.lua   prompts, checkpoint beacon, siren lights, main loop
  DriveController.lua  input, physics, nitro, chase camera
  HUD.lua           all on-screen UI + minimap
  Garage.lua        garage: cars, performance parts, handling, visuals, Blacklist
  CarVisuals.lua    spinning / steering wheels, headlights at night, brake lights
  Effects.lua       banners, speed lines, blur, near-miss popups, GPS arrow
  Sounds.lua        engine synth, wind, tyres, backfires, crashes, explosions, UI sounds
  Menu.lua          main menu + pause menu (settings, how to play, credits, player card)
  Settings.lua      player settings (saved in the profile)
  MapDraw.lua       draws the city for the radar and the full map
  FullMap.lua       full-screen city map (M)
```

You can change almost everything in `src/shared/Config.lua`, including car stats, prices, heat
levels, race routes and rewards, and the Blacklist.
