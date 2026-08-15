# Project FPS — Development Status

**Last Updated:** 2026-08-15  
**Current Milestone:** Milestone 6 — Arena Graybox & Tactical Map Pass (IN PROGRESS — structural redesign and collision synchronization complete, awaiting manual playtest)

---

## Current Project State

- **Milestone 1 (Movement)** — COMPLETE and playtested.
- **Milestone 2 (First Weapon)** — COMPLETE and playtested.
- **Milestone 3 (Combat Loop)** — COMPLETE and playtested.
- **Milestone 4 (Basic Bot & Combat Feedback Pass)** — COMPLETE & RUNTIME VERIFIED.
- **Milestone 5 (Free For All Foundation)** — COMPLETE & RUNTIME VERIFIED.
- **Milestone 6 (Arena Graybox & Tactical Map Pass):** IN PROGRESS — structural redesign & collision synchronization complete:
  - **Full Geometry & Collision Synchronization Audit (40 Objects Audited):**
    - 100% synchronization achieved between visible mesh geometry, collision geometry, and 3D navigation surfaces.
    - Synchronized all 6 manually modified objects (`Floor_Underpass`, `TrenchWall_East`, `Ramp_Underpass_North`, `Ramp_Underpass_South`, `Ramp_HighGround_North`, `Ramp_HighGround_South`).
    - Fixed ramp normal orientation vectors to guarantee true upward slope surfaces without invisible step barriers or reversed normal snagging.
    - Mathematically calculated exact flush thresholds for all 4 ramps connecting Level 0 $\leftrightarrow$ Level +1 and Level 0 $\leftrightarrow$ Level -1.
  - **Coherent 3-Tier Spatial Architecture (50m x 50m):**
    - **Level 0 (Main Ground Floor):** Continuous, seamless physical floor spanning the full arena footprint. Contains the Center Combat Hub, Left Flank (Flank A), Right Flank (Flank B), and Staging Plazas.
    - **Level +1 (High Ground Catwalk @ Y = +3.5m):** Dedicated elevated catwalk deck (8m x 16m) overlooking Center and Right Flank with waist-high parapet protection.
    - **Level -1 (Underpass Subway Tunnel @ Y = -2.5m):** Subterranean concrete trench (8.5m x 24.3m) running beneath the Catwalk, providing 100% overhead cover from sniper fire.
  - **Strict Ramp Purpose Rule (Exactly 4 Functional Ramps):**
    - `Ramp_HighGround_North`: Connects North Plaza (Level 0) $\to$ High Ground Catwalk (Level +1) [10.6m, 19.29° slope].
    - `Ramp_HighGround_South`: Connects South Plaza (Level 0) $\to$ High Ground Catwalk (Level +1) [10.6m, 19.29° slope].
    - `Ramp_Underpass_North`: Connects North Plaza (Level 0) $\to$ Underpass Tunnel (Level -1) [6.5m, 22.62° slope].
    - `Ramp_Underpass_South`: Connects South Plaza (Level 0) $\to$ Underpass Tunnel (Level -1) [6.5m, 22.62° slope].
  - **Map Boundaries & Fall Protection:**
    - Seamless 6.0m outer perimeter enclosure with zero geometric gaps.
    - Reusable `KillZone` (`Area3D`) at $Y = -8.0$m covering the entire map footprint. Any combatant falling out of bounds is instantly eliminated with environmental damage and safely respawned.
    - Hard boundary safety check in `PlayerController` and `BasicBot` ($Y < -7.0$m safety net).
  - **Balanced Daytime Graybox Lighting:**
    - Single Sun (`DirectionalLight3D`): energy `1.0`, soft shadows (`0.65` opacity, `0.03` bias), natural angle.
    - `WorldEnvironment`: ambient energy `0.42` with balanced daytime sky (no washed-out whites, no black crush).
    - Underpass: 2 localized soft utility worklights (energy `0.75`, range `10m`) for clear tunnel navigation.
  - **10 Verified Physical Spawn Points:** Strategically distributed across Level 0, Level +1, and Level -1 with line-of-sight obstruction and dynamic safe selection via `MatchManager`.
  - **Navigation & FFA Simulation Verified:** 327 3D navigation polygons baked across all 3 tiers with 0.25 voxel grid alignment. 21/21 tests in `test_milestone6_map.gd` and 32/32 tests in `test_ffa_foundation.gd` passing.

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
│   └── models/ animations/ audio/ materials/ textures/ vfx/
├── scenes/
│   ├── player/
│   │   └── player.tscn                       [M1-M5: Health, CrosshairHUD, CombatHUD, Combatant]
│   ├── weapons/
│   │   ├── weapon_base.tscn                  [M2]
│   │   └── assault_rifle.tscn                [M2]
│   ├── enemies/
│   │   └── basic_bot.tscn                    [M4-M5: Multi-target Combatant with 3D labels]
│   ├── ui/
│   │   ├── crosshair.tscn                    [Phase B: 2D CanvasLayer crosshair]
│   │   └── combat_hud.tscn                   [Combat Feedback: HP display, damage flash, death overlay]
│   └── maps/
│       └── test_arena.tscn                   [M6: 3-Tier Tactical Arena with KillZone & 10 Spawns]
├── scripts/
│   ├── player/
│   │   └── player_controller.gd              [M1-M6: Movement, Recoil, Health, Combatant, Fall Guard]
│   ├── weapons/
│   │   ├── weapon_data.gd                    [M2]
│   │   └── weapon_base.gd                    [M2]
│   ├── enemies/
│   │   └── basic_bot.gd                      [M4-M6: FFA AI, Multi-Target, Safe Respawn, Fall Guard]
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
│       └── test_milestone6_map.gd            [M6: Automated Map & Tactical Pass test suite]
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
  - [Ramp 3] North Underpass Ramp: (X: +9.25, Z: -18, Y: 0) -> Underpass (X: +9.25, Z: -12, Y: -2.5m).
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
  - [Ramp 4] South Underpass Ramp: (X: +9.25, Z: +18, Y: 0) -> Underpass (X: +9.25, Z: +12, Y: -2.5m).
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

- [x] **Full Collision Audit & Synchronization:** All 40 StaticBody3D objects audited; 0 mismatches between mesh and collision shapes.
- [x] **Ramp Normal & Flush Threshold Verification:** All 4 ramps connect Level 0 $\leftrightarrow$ Level +1 and Level 0 $\leftrightarrow$ Level -1 with upward normals and flush floor thresholds.
- [x] **Physics Traversal Test Suite:** 6/6 walking routes verified up and down ramps, through underpass, and across catwalk platform.
- [x] **Coherent 3-Tier Structure:** Level 0 (Ground), Level +1 (Catwalk), Level -1 (Underpass) cleanly unified.
- [x] **Fall Protection & KillZone3D:** KillZone at $Y = -8.0$m and safety guards in Player/Bot controllers preventing infinite falls.
- [x] **Balanced Daytime Lighting:** Single sun (1.0) + natural ambient (0.42) + soft underpass lights (0.75) with calibrated mid-tone materials.
- [x] **3D NavigationMesh Baking:** 327 polygons baked with 0.25 voxel grid alignment without precision warnings.
- [x] **10 Verified Spawn Points:** Solid ground placement with line-of-sight obstruction and dynamic safe spawn integration.
- [x] **Automated Regression Test Suite:** 32/32 tests in `test_ffa_foundation.gd` passing.
- [x] **Automated Milestone 6 Test Suite:** 21/21 tests in `test_milestone6_map.gd` passing.
