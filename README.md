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
| Fire roof weapon | F | RB | FIRE button |
| City map | M | D-pad ↑ | MAP button |
| Leaderboard | L | D-pad → (LB / RB switch tabs) | 🏆 button |
| Pause menu | P | D-pad ↓ | ☰ button |
| Photo mode | C (Q/E filter, H hide UI, Z/X tilt) | View button (LB/RB filter, Y hide UI) | 📷 button |

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

### Garage cutscenes, animations and rewards update
- **Garage cutscenes:**
  - Press E at the safehouse and the roll-up door rolls open.
  - Your car drives across the lot and into the garage while the camera tracks it, with letterbox bars and your engine revving.
  - Driving out, the workshop door opens and you roll through the tunnel. Outside, the car pulls out of the safehouse garage onto the lot and the door closes behind you.
  - The safehouse garage is now a real building with a lit interior, not a solid block.
- **Everything animates:**
  - The garage window slides in, its cards cascade in when you switch tabs, and the garage camera sweeps in when you arrive.
  - The Black Market slides up, and the menu side panels slide in and out.
  - The race panel, weapon chip, heat pill and interact prompt slide on and off screen.
  - After menus and cutscenes the HUD flies back in from the edges.
  - The drift counter pops, and the REP badge bounces when you level up.
- **Rolling cash counters** with floating +$ / -$ popups whenever your cash or unbanked money changes.
- **Race results screen:**
  - Shows a medal with your place (or score), your time, and the cash and REP counting up.
  - Shows your heat and the final order of the race.
  - Confetti when you win.
- **Daily reward:** log in each day for a growing reward (up to $8,000 on day 7) plus REP, shown on a 7-day streak track.
- **Photo mode:** orbit the camera around your car, zoom, tilt and pick one of 7 filters (Vivid, Neon Nights, Golden, Ice, Noir, Vintage...). Depth of field is on, and you can hide the UI for clean shots.
- **Wet roads:** when it rains, the asphalt turns glossy and reflects the city.

### Looks, leaderboard and new cars update
- **Brand-new racing HUD:**
  - A glass-panel theme with the Michroma and Montserrat fonts.
  - An analog speed dial with an LED tach ring, gear and nitro gauge.
  - A wallet card, a heat star pill and a weapon chip.
  - A race panel with live standings.
  - Notification pills that pop in.
  - The **minimap is now a proper circle** (clipped) with a ring and north marker.
  - The controls hint moved to the bottom centre and fades out, so it no longer covers the minimap.
- **Leaderboards:**
  - **THIS SERVER** shows REP level, wins and bounty.
  - **ALL-TIME BOUNTY** and **ALL-TIME REP** are global boards that use OrderedDataStores and refresh every minute.
  - Open them with **L** or the 🏆 button, or look at the big screen next to the safehouse garage.
  - Without API access (Studio), the all-time boards fall back to the players on the server.
- **Animations:**
  - The city map, pause menu and leaderboard slide and pop in and out, and the world behind them blurs.
  - The menu buttons cascade in, and the logo gets a shine sweep.
  - Tabs slide, rows fade in, and the HUD buttons bounce when you press them.
  - The map now opens on top of the pause menu (before, it was hidden behind it).
- **3 new car models:**
  - **Outlaw 4x4 Pickup** (class C): an open bed with rails, a roll bar, running boards, cab lights and a chrome grille.
  - **Stallion GT500** (class B): a fastback GT with racing stripes, a hood scoop, side scoops, round headlights and a ducktail.
  - **Cuneo 5000 QV** (class A): an 80s wedge supercar with pop-up lights, NACA ducts, engine air boxes, a louvred deck and a GT wing.
  - Pickups now also show up in traffic.
- **Every car looks better:** chrome window trim, wipers, grille slats, amber side markers and a third brake light.
- **Prettier world:**
  - Richer colour grading, with more saturation and contrast by day and at golden hour.
  - Suburb houses get front hedges, flower beds and bushes, and sometimes a car parked in the driveway.
  - Stop signs are real octagons now.
  - Your own name tag no longer floats over your car.

### Driving, performance, console & mobile update
- **New driving physics (hover suspension):**
  - The chassis floats on four wheel raycasts, with a critically damped spring and an
    anti-gravity force, instead of a box sliding over the road. That removes the snagging and
    bouncing on seams between road parts.
  - The driver's avatar is weightless, so it no longer makes the car wobble.
  - Brake-to-drift only triggers on a deliberate tap and turn.
  - Cars no longer gain speed through corners.
  - Ramps are climbed smoothly by the wheel rays.
- **Performance:**
  - ShadowMap lighting instead of Future.
  - A smaller streaming radius (900) with opportunistic stream-out.
  - Half the street lamps, one headlight beam per car, and car lights (headlight, underglow,
    tail and siren) only within about 230 studs of the camera.
  - Low-detail models for traffic and police (about half the parts).
  - Fewer facade parts on buildings.
  - AI line-of-sight checks 5x per second instead of every frame.
  - A cheaper siren animation loop.
  - Fewer traffic and patrol cars and fewer nearby engine sounds.
  - Phones and tablets start in performance mode.
- **Console (gamepad):**
  - Driving: RT gas, LT brake, left stick steer, X drift, A nitro, RB fire, Y reset,
    B interact / back.
  - D-pad: ↑ map, ↓ pause, ← garage.
  - All menus (main menu, pause, garage, Black Market) can be navigated with the D-pad and A.
  - Prompts show the right button for your device.
- **Mobile:**
  - Dedicated touch controls: an analog steering pad, GAS and BRAKE pedals, and NOS, DRIFT,
    FIRE and RESET buttons, all multi-touch.
  - The default thumbstick is switched off while you drive.
  - A MAP button next to ☰.
  - The HUD rearranges itself for touch screens.
  - Menus and panels scale down on small screens.

### Weapons, codes and Unbound update
- **Codes:** open **CODES** in the main menu. Each code works once per player:
  | Code | Reward |
  | --- | --- |
  | `WANTED` | $10,000 |
  | `UNBOUND` | $25,000 + 500 REP |
  | `NEONBAY` | $15,000 |
  | `NITRO` | free EMP Blaster |
  | `BLACKMARKET` | free Pulse Cannon |
  | `DRIFTKING` | free Kitsune S15 |
  | `RELEASE` | $50,000 + 1,000 REP |

  Add your own in `Config.Codes`.
- **Roof weapons from the Black Market** (red **B** on the map, at the docks). Drive in, press E,
  buy and mount one. Fire with **F** (gamepad RB, or the FIRE button on mobile). They only affect
  police and rival AI, never other players. Using them on cops starts a pursuit and raises heat.
  - **Pulse Cannon:** locks on to the car ahead. Two hits wreck a cop.
  - **EMP Blaster:** stalls every cop within 90 studs for 5 s.
  - **Oil Slick:** cops that hit it spin out.
  - **Spike Drop:** wrecks chasing cops.
  - **Shockwave:** blasts every car around you away.

  Each weapon has its own roof mount model (cannon, dish, pod, rack or ring) and a cooldown bar on
  the HUD.
- **From Unbound:**
  - **Burst Nitrous:** set Nitrous Type to BURST in Handling. Tap for short, hard boosts with 3
    charges.
  - **Takeover events** (Downtown and Harbor): score style in a zone by drifting, near misses and
    big air, and smash the highlighted cones, barrels and crates.
  - **Side bets:** in every race you bet against a named rival. Beat them to double your stake.
  - **REP levels** with a cash bonus each level, shown on the HUD and the player card.
  - **40 street art pieces** hidden around the city, each worth cash and REP.
  - New milestones for street art and takeovers.
- **Also better:**
  - **Rain showers** with streaks, grey grading, rain sound and slippery roads.
  - Cops attempt **PIT manoeuvres** on your rear quarter.
  - Race countdown beeps.
  - Codes and tips on the title screen.

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

> **Workspace.StreamingEnabled** is on (the place file and Rojo project set it, with a 900-stud
> target radius), and lighting uses **ShadowMap** for performance. The city is too big to send to
> every player at once.

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
  Weapons.lua       roof weapons (pulse cannon, EMP, oil, spikes, shockwave)
  Showroom.lua      the garage interior (underground workshop with turntable)
  Races.lua         races, drift events and Blacklist challenges
  Session.lua       per-player runtime state and money helpers
  PlayerData.lua    DataStore save / load
  Leaderboard.lua   all-time (OrderedDataStore) + live server leaderboards, safehouse screen
src/client/   (StarterPlayerScripts.Client)
  Main.client.lua   prompts, checkpoint beacon, siren lights, main loop
  DriveController.lua  input, physics, nitro, chase camera
  HUD.lua           all on-screen UI + minimap
  Theme.lua         shared UI look: fonts, colours, glass panels, blur + popup animations
  LeaderboardUI.lua leaderboard screen (L)
  GarageCinematic.lua  garage door cutscenes (drive in / drive out)
  Rewards.lua       race results screen + daily reward
  PhotoMode.lua     photo mode (C)
  Garage.lua        garage: cars, performance parts, handling, visuals, Blacklist
  CarVisuals.lua    spinning / steering wheels, headlights at night, brake lights
  Effects.lua       banners, speed lines, blur, near-miss popups, GPS arrow
  Sounds.lua        engine synth, wind, tyres, backfires, crashes, explosions, UI sounds
  Menu.lua          main menu + pause menu (settings, how to play, credits, player card)
  Settings.lua      player settings (saved in the profile)
  MapDraw.lua       draws the city for the radar and the full map
  FullMap.lua       full-screen city map (M)
  BlackMarket.lua   Black Market window + fire button
  Collectibles.lua  hides street art you already found
  Weather.lua       rain
  Input.lua         device detection (keyboard / gamepad / touch) + button labels
  Scale.lua         UI scaling for small screens
  TouchControls.lua mobile driving controls
```

You can change almost everything in `src/shared/Config.lua`, including car stats, prices, heat
levels, race routes and rewards, and the Blacklist.
