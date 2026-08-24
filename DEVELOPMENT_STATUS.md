# Project FPS — Development Status

**Last Updated:** 2026-08-18  
**Current Milestone:** Milestone 15 — Full 5-Weapon Arsenal, Physical Spring Recoil, High-Performance Combat VFX, Spatial Audio & Stylized Arena Visual Polish (COMPLETE & RUNTIME VERIFIED)

---

## Current Project State

- **Milestone 1 (Movement)** — COMPLETE and playtested.
- **Milestone 2 (First Weapon)** — COMPLETE and playtested.
- **Milestone 3 (Combat Loop)** — COMPLETE and playtested.
- **Milestone 4 (Basic Bot & Combat Feedback Pass)** — COMPLETE & RUNTIME VERIFIED.
- **Milestone 5 (Free For All Foundation)** — COMPLETE & RUNTIME VERIFIED.
- **Milestone 6 (Arena Graybox & Tactical Map Pass)** — COMPLETE & RUNTIME VERIFIED:
  - **Coherent 3-Tier Spatial Architecture (50m x 50m):**
    - **Level 0 (Main Ground Floor):** Continuous, seamless physical floor spanning the full arena footprint. Contains the Center Combat Hub, Left Flank (Flank A), Right Flank (Flank B), and Staging Plazas.
    - **Level +1 (High Ground Catwalk @ Y = +3.5m):** Dedicated elevated catwalk deck (8m x 16m) overlooking Center and Right Flank with waist-high parapet protection.
    - **Level -1 (Underpass Subway Tunnel @ Y = -2.5m):** Subterranean concrete trench (8m x 24m) running beneath the Catwalk, providing 100% overhead cover from sniper fire.
  - **Strict Ramp Purpose Rule (Exactly 4 Functional Ramps):**
    - `Ramp_HighGround_North`: Connects North Plaza (Level 0) $\to$ High Ground Catwalk (Level +1) [10.6m, 19.3° slope].
    - `Ramp_HighGround_South`: Connects South Plaza (Level 0) $\to$ High Ground Catwalk (Level +1) [10.6m, 19.3° slope].
    - `Ramp_Underpass_North`: Connects North Plaza (Level 0) $\to$ Underpass Tunnel (Level -1) [6.5m, 22.6° slope].
    - `Ramp_Underpass_South`: Connects South Plaza (Level 0) $\to$ Underpass Tunnel (Level -1) [6.5m, 22.6° slope].
    - *All random/decorative ramps and jump crates removed.*
  - **Map Boundaries & Fall Protection:**
    - Seamless 6.0m outer perimeter enclosure with zero geometric gaps.
    - Reusable `KillZone` (`Area3D`) at $Y = -8.0$m covering the entire map footprint. Any combatant falling out of bounds is instantly eliminated with environmental damage and safely respawned.
    - Hard boundary safety check in `PlayerController` and `BasicBot` ($Y < -7.0$m safety net).
  - **Balanced Daytime Graybox Lighting:**
    - Single Sun (`DirectionalLight3D`): energy `1.0`, soft shadows (`0.65` opacity, `0.03` bias), natural angle.
    - `WorldEnvironment`: ambient energy `0.42` with balanced daytime sky (no washed-out whites, no black crush).
    - Underpass: 2 localized soft utility worklights (energy `0.75`, range `10m`) for clear tunnel navigation.
    - Controlled mid-tone graybox material palette.
  - **10 Verified Physical Spawn Points:** Strategically distributed across Level 0, Level +1, and Level -1 with line-of-sight obstruction and dynamic safe selection via `MatchManager`.
  - **Navigation & FFA Simulation Verified:** 317 3D navigation polygons baked across all 3 tiers with 0.25 voxel grid alignment. 21/21 tests in `test_milestone6_map.gd` and 32/32 tests in `test_ffa_foundation.gd` passing.
- **Milestone 7 (First-Person Viewmodel, Procedural Weapon Animation & Production Asset Integration):** COMPLETE & RUNTIME VERIFIED:
  - **Procedural Viewmodel Animation System (`weapon_base.gd`):**
    - Idle / breathing sinusoidal sway.
    - Velocity-proportional Lissajous stride bobbing while walking/moving.
    - Tactical Sprint presentation with low-ready orientation and dynamic jog pump.
    - Smooth crouch compression offset.
    - Mouse look inertia / lag (yaw, pitch, roll sway) with natural rotational damping.
    - Procedural firing kick impulse and fast exponential decay.
    - Viewmodel vibration trauma decay on sustained fire.
    - Procedural reload animation curve sampling (magazine out, reload, bolt release).
    - Aim Down Sights (ADS): FOV zoom (90° $\to$ 76°), mouse sensitivity reduction (0.75x), optic point alignment, and motion damping.
    - Grip and optic markers (`RightHandGrip`, `LeftHandGrip`, `OpticPoint`, `MuzzleFlash`).
  - **Production 3D Assets Integrated:**
    - High-detail Assault Rifle model (`fps gun.fbx` / `fps_weapon_animated.glb`) with calibrated transforms and materials.
    - Production 3D character model (`player.glb`) integrated into `BasicBot` visuals.
  - **Automated Verification:** 21/21 tests in `test_weapon_restoration.gd`, 21/21 tests in `test_milestone6_map.gd`, and 32/32 tests in `test_ffa_foundation.gd` all passing.
- **Milestone 8 (Complete FFA Match Loop & Match HUD):** COMPLETE & RUNTIME VERIFIED (Git commit `bba2072`):
  - **Match Information HUD (`CombatHUD`):**
    - Top-center Match Timer countdown formatted as `MM:SS` with low-time warning tint ($\le$ 30s).
    - Top-center Live Score Tracker displaying `YOU <PlayerScore>    LEADER <LeaderScore>`.
    - Bottom-right Weapon Ammo counter (`Clip / Reserve`) updated dynamically on fire, reload, and ammo change events.
  - **Top-Right Kill Feed (`KillFeed`):**
    - Compact elimination feed displaying `Killer → Victim`.
    - Local player highlighted (cyan for kills, red for deaths).
    - Maximum 5 active entries with automatic fade-out and destruction after ~3.5s.
  - **End-of-Match & Results Screen (`ResultsOverlay`):**
    - Displays `VICTORY` (green) or `DEFEAT` (crimson) banner based on match outcome.
    - Winner announcement and winning score subtitle.
    - Dynamic 8-combatant Scoreboard table sorted by score/kills descending, then deaths ascending.
    - Local player row visually highlighted in cyan with `(YOU)` tag.
  - **Match State & Lifecycle Control:**
    - On `match_ended`, player movement, shooting, reload, ADS, and pending respawns are cleanly halted.
    - Bot AI navigation, targeting, shooting, and respawns are suppressed.
    - Mouse cursor is automatically released (`Input.MOUSE_MODE_VISIBLE`) on results screen.
  - **Instant Match Restart (`PlayAgainButton` / Keybindings):**
    - "PLAY AGAIN" button and `[SPACE]` / `[ENTER]` keybindings cleanly reload the arena scene.
    - Scene reload completely resets MatchManager state, combatant stats, player/bot health, timers, and restores mouse capture (`Input.MOUSE_MODE_CAPTURED`).
- **Milestone 9 (Multiple Weapons / Weapon Switching):** COMPLETE & RUNTIME VERIFIED:
  - **WeaponBase Lifecycle & Equip Lock:**
    - Added `equip()`, `unequip()`, `is_equipping()`, `is_automatic()`, and a ~0.20s equip lock before firing/reloading.
    - Unequipping safely cancels active reloads without altering weapon's current or reserve ammo.
    - Inactive weapons disable per-frame processing (`set_process(false)`) and remain invisible.
  - **Semi-Automatic Trigger Support:**
    - Fully distinguishes between automatic weapons (hold fire) and semi-automatic weapons (fresh click per shot) driven by `WeaponData.is_automatic`.
  - **Secondary Weapon (Pistol):**
    - Created `data/weapons/pistol.tres` (35 dmg, 2.0x headshot, 5 rps, semi-auto, 12 mag / 48 reserve, 1.4s reload, 0.8° spread, 75m range).
    - Created `scenes/weapons/pistol.tscn` inheriting `weapon_base.tscn` with a clean placeholder visual.
  - **Player Inventory & Switching:**
    - Slot 1 (`AssaultRifle`) and Slot 2 (`Pistol`) selectable via Keys `1` / `2` and mouse wheel scrolling.
    - Active weapon ownership cleanly delegates fire, reload, ADS, and motion processing exclusively to the equipped weapon.
    - Switching immediately updates `CombatHUD` ammo counter via the `ammo_changed` signal.
    - `F3` debug refill restores magazine and reserve ammo for all inventory weapons simultaneously.
- **Milestone 10 (Weapon Polish & Combat Feel):** COMPLETE & RUNTIME VERIFIED:
  - Weapon-specific fire, dryfire, and reload audio.
  - Dynamic muzzle flash scaling and randomized roll per shot.
  - Ring-buffer pooling shell casing ejection system (`CasingManager`).
  - Distinct Assault Rifle and Pistol procedural reload keyframe animations.
  - Crisp body & headshot hitmarker ticks.
  - 59/59 automated tests passing in `test_milestone10_weapon_polish.gd`.
- **Milestone 11 (Player Feedback, Polish & Gameplay Juice):** IMPLEMENTATION COMPLETE (Pending Manual Playtest):
  - **Phase 1: Local Player Damage Feedback & Directional Indicators:**
    - Retriggerable radial screen-space damage vignette and perimeter flash on damage.
    - 8-slot pooled radial directional damage indicators pointing toward attacker bearing relative to camera yaw with smooth 0.55s decay.
    - Directional camera flinch / impact kick impulse reacting to incoming damage bearing.
  - **Phase 2 & 5: Hit Feel Hierarchy & Kill Confirmation:**
    - Instant client-side lethal damage detection in `WeaponBase._fire()` before dispatch.
    - 4 distinct hit feel tiers in `CrosshairHUD`:
      - Body hit: 1.0x scale crisp white diagonal cross (0.12s decay).
      - Headshot hit: 1.35x scale crimson red critical punch (0.20s decay).
      - Body kill: 1.55x scale vivid amber/crimson expanded kill punch (0.25s decay).
      - Headshot kill: 1.75x scale critical red-gold kill flare (0.30s decay).
    - Distinct audio cues via `AudioManager.play_kill_confirm(is_headshot)`.
  - **Phase 3: Death & Respawn Presentation:**
    - Authoritative combat suppression on death (halts movement, shooting, reloading, ADS, weapon switching).
    - Knockdown death camera presentation (+14° roll tilt, +6° pitch slump, -0.35m floor sink).
    - Dynamic "YOU DIED" death overlay with killer name and live countdown ("Respawning in 2.5s...").
    - Clean state restoration on respawn: eye height, camera angles, active weapon equip, and tactical respawn audio cue (`AudioManager.play_respawn()`).
  - **Phase 4: Compact Health Display & Juice:**
    - Bottom-left compact health bar with trailing chip damage effect (`DamageTrailBar`).
    - Dynamic color transitions: Green (>60% HP) $\to$ Amber (30-60% HP) $\to$ Critical Red ($\le$30% HP).
    - Low-health pulsating perimeter warning vignette when HP $\le$ 30, cleanly stopped upon healing/respawn.
  - **Phase 6: Combat Audio Polish:**
    - Integrated native 16-bit 44.1kHz audio assets: `kill_confirm.wav` and `respawn.wav`.
    - Integrated `AudioManager` helper methods for kill confirmation and respawn playback.
  - **Phase 7: Automated Verification:**
    - 65/65 tests in `test_milestone11_combat_feedback.gd` passing.
- **Milestone 12 (Map Gameplay & Spawn Quality):** COMPLETE & RUNTIME VERIFIED:
  - Tactical 3-Lane Combat Arena (50m x 50m) with West CQC Flank, Center Monument Hub, and East Wing (Catwalk + Underpass).
  - Authoritative 1.2s spawn protection with `[SHIELD]` UI feedback.
  - Multi-factor safe spawn point selection (distance, density, LOS raycasting, and death proximity penalties).
  - 45/45 tests passing in `test_milestone12_map_gameplay.gd`.
- **Milestone 13 (Bot AI & Combat Intelligence):** COMPLETE & RUNTIME VERIFIED:
  - Cone-Based Vision Perception (`fov_degrees: 115.0°`) & close-range hearing (`hearing_range: 3.5m`).
  - Damage alertness stimulus (attacks from behind trigger immediate alert and acquisition).
  - Last-Known-Position (LKP) tracking with 3.5s memory decay and dedicated `INVESTIGATE` state.
  - Dynamic lateral combat strafing (1.0s – 2.2s cadence) with micro-pauses and obstacle raycast probing.
  - Tactical cover seeking under heavy damage ($\le 35\%$ HP) or empty-magazine reload under fire.
  - Human-like rotational smoothing (`turn_speed: 6.5 rad/s`) and fire alignment tolerance ($\le 14.0^\circ$).
  - Data-driven difficulty presets (`EASY`, `MEDIUM`, `HARD`) and multi-factor target prioritization scoring.
  - 43/43 tests passing in `test_milestone13_bot_ai.gd`.
  - Full regression suite: 286/286 tests passing (100%).


---

## Current Architecture

### Engine

- **Godot:** 4.7
- **Renderer:** GL Compatibility (Web + Windows target)
- **Physics:** Jolt Physics
- **Windows rendering:** D3D12
- **Main scene:** `res://scenes/maps/test_arena.tscn`

### Directory Structure

```
project-fps/
├── assets/
│   ├── models/
│   │   ├── 12_low_poly_guns.glb              [Untouched master 12-weapon 3D asset source]
│   │   ├── player/                           [Production character asset: player.glb]
│   │   ├── enemies/
│   │   └── environment/
│   ├── animations/ audio/ materials/ textures/ vfx/
├── scenes/
│   ├── player/
│   │   └── player.tscn                       [M1-M7: ADS Camera, Health, CrosshairHUD, CombatHUD, Combatant]
│   ├── weapons/
│   │   ├── weapon_base.tscn                  [M2, M7: Procedural Viewmodel Animation base]
│   │   ├── assault_rifle.tscn                [M2, M7: Calibrated Assault Rifle with grips & optic point]
│   │   ├── assault_rifle_visual.tscn         [M7: Direct instance of 12_low_poly_guns.glb (M16_8)]
│   │   ├── pistol.tscn                       [M9: Calibrated Semi-Auto Pistol]
│   │   ├── pistol_visual.tscn                [M9: Direct instance of 12_low_poly_guns.glb (Glock Handgun_45)]
│   │   ├── shotgun.tscn                      [M10: Calibrated Pump-Action Shotgun]
│   │   ├── shotgun_visual.tscn               [M10: Direct instance of 12_low_poly_guns.glb (Pump Action Shotgun_25)]
│   │   ├── smg.tscn                          [M10: Calibrated High-RPM SMG]
│   │   ├── smg_visual.tscn                   [M10: Direct instance of 12_low_poly_guns.glb (MP5_17)]
│   │   ├── sniper.tscn                       [M10: Calibrated Bolt-Action Sniper Rifle]
│   │   └── sniper_visual.tscn                [M10: Direct instance of 12_low_poly_guns.glb (M40_33)]
│   ├── enemies/
│   │   ├── basic_bot.tscn                    [M4-M7: Production 3D model, Multi-target AI, 3D labels]
│   │   └── dummy_target.tscn                 [M3: Static shooting target]
│   ├── ui/
│   │   ├── crosshair.tscn                    [Phase B: 2D CanvasLayer crosshair]
│   │   └── combat_hud.tscn                   [Combat Feedback: HP display, damage flash, death overlay]
│   └── maps/
│       └── test_arena.tscn                   [M6: 3-Tier Tactical Arena with KillZone & 10 Spawns]
├── scripts/
│   ├── player/
│   │   └── player_controller.gd              [M1-M7: Movement, Recoil, ADS FOV Zoom, Health, Combatant]
│   ├── weapons/
│   │   ├── weapon_data.gd                    [M2: Weapon resource parameters]
│   │   └── weapon_base.gd                    [M2, M7: Procedural Sway, Bob, Kick, Reload, ADS & Firing]
│   ├── enemies/
│   │   ├── basic_bot.gd                      [M4-M6: FFA AI, Multi-Target, Safe Respawn, Fall Guard]
│   │   └── dummy_target.gd                   [M3: Damage feedback dummy]
│   ├── gameplay/
│   │   ├── match_manager.gd                  [M5: FFA Match lifecycle, Timer, Scores, Safe Spawns]
│   │   └── kill_zone.gd                      [M6: Reusable Fall Protection / Kill Boundary]
│   ├── ui/
│   │   └── combat_hud.gd                     [Combat Feedback: 2D HUD controller]
│   ├── maps/
│   │   ├── test_arena.gd                     [M6: 3D NavMesh runtime static collider baker]
│   │   └── spawn_point.gd                    [M5: Reusable 3D Arena Spawn Point]
│   └── systems/
│       ├── health.gd                         [M3-M5: Health component with MatchManager integration]
│       ├── damage_info.gd                    [M3: Damage payload data container]
│       ├── test_ffa_foundation.gd            [M5: Automated FFA unit & integration test suite]
│       ├── test_ffa_sim.gd                   [M5: Live FFA multi-combatant simulation test]
│       ├── test_milestone6_map.gd            [M6: Automated Map & Tactical Pass test suite]
│       └── test_weapon_restoration.gd        [M7: Automated Weapon & Viewmodel verification test suite]
└── data/
    ├── weapons/
    │   └── assault_rifle.tres                [M2]
    └── characters/ maps/ configuration/
```

---

## 3-Tier Tactical Arena Layout

```text
===================================================================================
                       NORTH BOUNDARY (Z = -25, Wall 6.0m)
===================================================================================
  NORTH PLAZA (Z: -24 to -18)
  - Wide open staging area with 2 L-shaped staging barriers.
  - Level 0 Ground connects West to Left Flank, South to Center Hub.
  - [Ramp 1] North High Ground Ramp: (X: +18, Z: -18, Y: 0) -> Catwalk (X: +18, Z: -8, Y: +3.5m).
  - [Ramp 3] North Underpass Ramp: (X: +9, Z: -18, Y: 0) -> Underpass (X: +9, Z: -12, Y: -2.5m).
-----------------------------------------------------------------------------------
  [X: -25 to -12]         |    [X: -12 to +5]            |    [X: +5 to +25]
  LEFT FLANK (Flank A)    |    CENTER COMBAT HUB         |    RIGHT FLANK (Flank B)
  "Pillar Alley / Yard"   |    "Main Courtyard"          |    "Catwalk & Underpass"
                          |                              |
  - Solid ground (Y=0)    |  - Solid ground (Y=0)        |  - Ground Floor (Y=0)
  - 4.0m partition wall   |  - Central monument          |    under Catwalk
    with 2 wide archways  |    (4m x 3.5m x 4m)          |  - High Ground Catwalk (+1)
    into Center           |  - 4 clean waist-high        |    at Y = +3.5m overhead
  - Staggered cover       |    barriers (1.1m)           |  - Underpass Tunnel (-1)
    pillars & waist       |  - 2 sightline pillars       |    at Y = -2.5m recessed
    crates                |  - Fluid sprint/slide space  |    directly below
  - 5–15m CQC fights      |  - Connects all 4 sides      |
-----------------------------------------------------------------------------------
  SOUTH PLAZA (Z: +18 to +24)
  - Wide open staging area with 2 L-shaped staging barriers.
  - Level 0 Ground connects West to Left Flank, North to Center Hub.
  - [Ramp 2] South High Ground Ramp: (X: +18, Z: +18, Y: 0) -> Catwalk (X: +18, Z: +8, Y: +3.5m).
  - [Ramp 4] South Underpass Ramp: (X: +9, Z: +18, Y: 0) -> Underpass (X: +9, Z: +12, Y: -2.5m).
===================================================================================
                       SOUTH BOUNDARY (Z = +25, Wall 6.0m)
===================================================================================
```

---

## 10 Strategic Spawn Points

| Spawn Name | Location | Elevation | Description / Strategic Purpose |
|---|---|---|---|
| `SpawnPoint_1_NorthA` | `(-18.5, 0.9, -21.0)` | Level 0 | Left Flank North entrance behind staging cover |
| `SpawnPoint_2_NorthPlaza` | `(-3.5, 0.9, -22.5)` | Level 0 | North Plaza behind L-shaped barricade |
| `SpawnPoint_3_NorthEast` | `(18.0, 0.9, -21.5)` | Level 0 | Right Flank North ramp approach base |
| `SpawnPoint_4_SouthA` | `(-18.5, 0.9, 21.0)` | Level 0 | Left Flank South entrance behind staging cover |
| `SpawnPoint_5_SouthPlaza` | `(-3.5, 0.9, 22.5)` | Level 0 | South Plaza behind L-shaped barricade (Player start) |
| `SpawnPoint_6_SouthEast` | `(18.0, 0.9, 21.5)` | Level 0 | Right Flank South ramp approach base |
| `SpawnPoint_7_WestMid` | `(-22.0, 0.9, 0.0)` | Level 0 | Left Flank mid pocket behind heavy pillar |
| `SpawnPoint_8_HighGround` | `(18.0, 4.4, 0.0)` | Level +1 | Center of Catwalk deck facing West |
| `SpawnPoint_9_Underpass` | `(9.0, -1.6, 0.0)` | Level -1 | Center of Underpass tunnel floor |
| `SpawnPoint_10_CenterAlcove` | `(-9.5, 0.9, 0.0)` | Level 0 | Center Hub alcove shielded behind monument |

---

## Playtest & Verification Checklist

- [x] **Coherent 3-Tier Structure:** Level 0 (Ground), Level +1 (Catwalk), Level -1 (Underpass) cleanly unified.
- [x] **Strict 4-Ramp System:** Exactly 4 vertical ramps connecting Ground to Catwalk and Ground to Underpass with zero decorative ramps.
- [x] **Fall Protection & KillZone3D:** KillZone at $Y = -8.0$m and safety guards in Player/Bot controllers preventing infinite falls.
- [x] **Balanced Daytime Lighting:** Single sun (1.0) + natural ambient (0.42) + soft underpass lights (0.75) with calibrated mid-tone materials.
- [x] **3D NavigationMesh Baking:** 317 polygons baked with 0.25 voxel grid alignment without precision warnings.
- [x] **10 Verified Spawn Points:** Solid ground placement with line-of-sight obstruction and dynamic safe spawn integration.
- [x] **Procedural Viewmodel Animations & ADS:** Idle sway, Lissajous walk bob, tactical sprint pump, crouch compression, mouse look inertia, recoil kick, and smooth ADS zoom.
- [x] **Production 3D Assets:** High-detail weapon visual and character bot models assigned and aligned.
- [x] **Milestone 10 Weapon Polish:** Audio keys, casing ejection, custom reload curves, dynamic muzzle flashes, and dry-fire tactile kicks.
- [x] **Milestone 11 Combat Feedback & Juice:**
  - Radial screen damage vignette and 8-slot directional damage indicators.
  - 4-tier hit feel hierarchy (Body, Headshot, Kill, Headshot Kill) with distinct visual scale & audio cues.
  - Knockdown death camera presentation (+14° roll, +6° pitch slump, -0.35m sink) & dynamic respawn timer.
  - Health bar with trailing chip damage and pulsating low-health warning.
- [x] **Milestone 13 (Bot AI & Combat Intelligence):**
  - **Cone-Based Perception & Awareness (FOV):**
    - Configurable field-of-view angle (`fov_degrees: 115.0°`) replacing 360° omniscience. Target must satisfy angular cone relative to forward facing direction.
    - Close-range 360° hearing/proximity awareness (`hearing_range: 3.5m`) sensing nearby un-aimed opponents.
    - Damage alertness: receiving damage immediately alerts bot to attacker bearing, breaking stealth.
    - Full physics line-of-sight raycasts against arena static colliders.
  - **Last-Known-Position (LKP) & Memory System:**
    - Records coordinates upon LOS break with configurable persistence duration (`target_persistence: 3.5s`).
    - Dedicated `INVESTIGATE` state: bot navigates to LKP, conducts localized sweep scan (`investigate_duration: 2.0s`), and smoothly decays memory back to `SEARCH` if target is not found.
  - **Dynamic Combat Movement & Strafing:**
    - Non-static firefights: bots perform alternating lateral combat strafing (1.0s – 2.2s cadence) with micro-pauses for human-like hesitation.
    - Distance maintenance: advances when $> 16.0$m, backpedals and strafes when $< 5.5$m, and holds combat radius.
    - Proactive obstacle probing: short lateral raycasts prevent bots from strafing into walls.
  - **Tactical Cover & Survival Mechanics:**
    - Under critical damage ($\text{HP} \le 35\%$) or empty-magazine reload under fire, bot evaluates 16 radial candidate positions around arena geometry.
    - Transitions to `COVER` state, navigates to cover breaking threat LOS, and completes reload.
  - **Human-Like Aiming & Fire Tolerances:**
    - Smooth yaw/pitch rotational interpolation via `turn_speed` (no instant $180^\circ$ snaps).
    - Strict fire alignment tolerance: weapon only discharges if $\text{angle}(\text{forward}, \text{aim\_dir}) \le \text{fire\_tolerance\_degrees}$ ($14.0^\circ$).
  - **Data-Driven Difficulty Presets & Multi-Target Prioritization:**
    - Data-driven presets: `EASY`, `MEDIUM` (default), `HARD`, with dynamic runtime method `apply_difficulty_preset()`.
    - Multi-factor target prioritization scoring: visibility in FOV (+60), distance weighting (+35), attacker retaliation (+55), target stickiness hysteresis (+50), and low-health opportunism (+20).
  - **Automated Verification Test Suite:**
    - 43/43 tests in `test_milestone13_bot_ai.gd` passing.
    - 45/45 tests in `test_milestone12_map_gameplay.gd` passing.
    - 65/65 tests in `test_milestone11_combat_feedback.gd` passing.
    - 59/59 tests in `test_milestone10_weapon_polish.gd` passing.
    - 32/32 tests in `test_ffa_foundation.gd` passing.
    - 21/21 tests in `test_milestone6_map.gd` passing.
    - 21/21 tests in `test_weapon_restoration.gd` passing.
    - **Total: 286 / 286 automated tests passing (100%).**
- [x] **Milestone 14 (Playable Game Loop & Arena Gameplay Systems):**
  - **Dynamic Arena Pickups (Health Kits & Ammo Packs):**
    - Created reusable `Pickup` (`Area3D`) component with procedural hover rotation & vertical bobbing.
    - `pickup_health.tscn`: Low-poly health kit with glowing green cross restoring 35 HP. Full-health waste prevention.
    - `pickup_ammo.tscn`: Low-poly ammo crate with glowing amber ring restoring full magazine and reserve ammo for Player & Bot weapons.
    - 15s cooldown respawn lifecycle with smooth procedural scale pop-in.
    - 4 pickups strategically distributed across the arena: Level -1 Underpass (`Pickup_Health_Underpass`), Level 0 West Flank (`Pickup_Health_FlankA`), Level +1 Catwalk (`Pickup_Ammo_Catwalk`), Level 0 North Plaza (`Pickup_Ammo_Plaza`).
    - Bot AI integration: Low-HP bots ($\text{HP} \le 45\%$) actively query and navigate toward nearest active HealthKit during search patrol; empty-ammo bots seek AmmoPacks.
  - **Pre-Match Staging Countdown ("3... 2... 1... FIGHT!"):**
    - 3.0s pre-match freeze state in `MatchManager` (`MatchState.STAGING`).
    - Player and bot movement, jumping, and weapon firing locked at spawn during countdown.
    - Animated `StagingOverlay` on `CombatHUD` displaying large countdown numbers with bounce scale tweening and vivid gold "FIGHT!" badge.
    - Procedural countdown tick and fight fanfare sound effects in `AudioManager`.
  - **Kill Streaks & Combat Accolades:**
    - `MatchManager` streak tracking and multi-kill time-window calculation (4.0s).
    - Accolade hierarchy: `FIRST BLOOD!` (+50 pts), `DOUBLE KILL!` (+50 pts), `TRIPLE KILL!` (+100 pts), `MULTI KILL!` (+150 pts), `KILLING SPREE!` (3 kills, +100 pts), `RAMPAGE!` (5 kills, +200 pts), `DOMINATING!` (7 kills, +300 pts), `UNSTOPPABLE!` (10 kills, +500 pts).
    - Animated `AccoladeOverlay` in `CombatHUD` with back-ease scale pop-in, glowing borders, and gold/crimson styling.
    - Sound synthesis in `AudioManager` (`play_accolade(is_multikill)`).
  - **Submachine Gun (SMG) CQC Weapon & Slot 3:**
    - Data-driven `data/weapons/smg.tres`: 18 damage, 1.75x headshot, 15 rounds/sec cadence, 35-round magazine, 140 reserve ammo, 1.5s reload, 1.4° hipfire spread, 50m max range.
    - Low-poly 3D weapon prefab `scenes/weapons/smg.tscn` inheriting `weapon_base.tscn`.
    - Input action `weapon_slot_3` (Key `3`) added to `project.godot`.
    - PlayerController inventory updated with Slot 0 (AR), Slot 1 (SMG), Slot 2 (Pistol) with seamless key and scroll switching.
  - **In-Match Live TAB Scoreboard:**
    - Hold `Tab` during active match to inspect live FFA standings sorted by score/kills descending, then deaths ascending.
    - Real-time highlight for local player `(YOU)` in cyan.
  - **In-Game Pause & Settings Menu:**
    - Press `Escape` / `ui_cancel` to toggle pause overlay and liberate mouse cursor.
    - Live Mouse Sensitivity slider (`0.0005` to `0.0080` rad/pixel) dynamically modifying PlayerController sensitivity.
    - Master Volume and SFX Volume sliders controlling Godot audio buses with linear-to-dB conversion.
    - "RESUME MATCH" and "RESTART MATCH" interactive buttons.
  - **Automated Verification Test Suite:**
    - 26/26 tests in `test_milestone14_game_loop.gd` passing.
- [x] **Milestone 15 (Full 5-Weapon Arsenal, Physical Spring Recoil, High-Performance Combat VFX, Spatial Audio & Stylized Arena Visual Polish):**
  - **Complete 5-Weapon Arsenal (Game Bible Spec):**
    - **Assault Rifle (Slot 1):** 25 dmg, 10 rps, 30 mag, 120 reserve, 2.0s reload, automatic, balanced general-purpose rifle.
    - **SMG (Slot 2):** 18 dmg, 15 rps, 35 mag, 140 reserve, 1.5s reload, automatic, high fire-rate CQC shredder.
    - **Shotgun (Slot 3):** Pump-action, 8 pellets $\times$ 12 dmg (96 max body damage, 1.5x headshot = 144 max headshot dmg), 1.1 rps, 6-shell tubular magazine, 36 reserve, 2.2s reload, 3.8° spread cone. Crimson 12-gauge shell casing profile.
    - **Sniper Rifle (Slot 4):** Bolt-action, 85 base dmg, 2.0x headshot = 170 lethal headshot dmg, 0.75 rps, 5-round magazine, 20 reserve, 2.4s reload, 5.0° hipfire spread, 0.05° pinpoint ADS spread.
    - **Pistol (Slot 5):** Semi-auto sidearm, 35 dmg, 2.0x headshot, 5 rps, 12 mag, 48 reserve, 1.4s reload.
    - Hotkeys `1`, `2`, `3`, `4`, `5` and scroll wheel weapon cycling seamlessly across all 5 slots.
  - **Damped Harmonic Spring-Mass Recoil Dynamics:**
    - Second-order physical spring-damper system ($k=260, c=24, m=1$) replacing simple linear recovery.
    - Velocity kick impulses on shooting create tactile mechanical kick with natural overshoot and settling.
  - **Zero-Allocation Pooled Combat VFX (`VFXManager`):**
    - `BulletTracer` (32 pooled slots): High-speed ballistic 3D tracer streaks with customizable speed and weapon-specific coloration.
    - `SurfaceImpact` (24 pooled slots): 3D normal-aligned impact sparks and dust puffs on world collisions.
    - `EliminationBurst` (12 pooled slots): Dynamic stylized 3D voxel shatter burst on bot elimination.
  - **Spatial Movement Audio & Sound Expansion (`AudioManager`):**
    - Stride-based footstep cadence dynamically scaling with velocity for Walking (2.4m), Sprinting (2.8m), and Crouching (1.6m).
    - Dedicated Jump Launch and Land Impact sound synthesis and dispatch.
    - 3D spatial footsteps for bots with distance-based attenuation.
    - Sound profiles and synthesis for Shotgun fire/pump/reload and Sniper fire/bolt/reload.
  - **Stylized Competitive Arena Visual Polish:**
    - High-contrast competitive arena materials (dark slate floor, amber side decks, cobalt catwalk, cyan underpass).
    - Vibrant skybox palette and ACES filmic tonemapping with tuned exposure.
    - Stylized Sniper Scope HUD overlay with custom reticle and peripheral masking.
  - **Automated Verification Test Suite:**
    - 88/88 tests in `test_milestone15_audio_vfx_weapons.gd` passing.
    - **Total: 400 / 400 automated tests passing across all 9 milestone test suites (100% pass rate).**
