# Project FPS — Development Status

**Last Updated:** 2026-08-15  
**Current Milestone:** Milestone 6 — Arena Graybox & Tactical Map Pass (IN PROGRESS — graybox implemented, awaiting manual playtest)

---

## Current Project State

- **Milestone 1 (Movement)** — COMPLETE and playtested.
- **Milestone 2 (First Weapon)** — COMPLETE and playtested.
- **Milestone 3 (Combat Loop)** — COMPLETE and playtested.
- **Milestone 4 (Basic Bot & Combat Feedback Pass)** — COMPLETE & RUNTIME VERIFIED.
- **Milestone 5 (Free For All Foundation)** — COMPLETE & RUNTIME VERIFIED.
- **Milestone 6 (Arena Graybox & Tactical Map Pass):** IN PROGRESS — graybox implemented, awaiting manual playtest:
  - **Medium-Sized Tactical Footprint (50m x 50m):** Upgraded from the flat 40m test box to a structured 50m x 50m graybox arena with 5.0m perimeter containment walls, designed for fast 5–15s encounter pacing and dynamic movement (sprint, jump, slide).
  - **Zone Breakdown & Color Coding:**
    - **Center (Main Combat Hub):** 20m x 20m arena featuring a full-height 3x3m central monument (`mat_center_monument`), 4 angled waist-high barriers (`mat_cover_waist`), and 2 sightline-blocking pillars.
    - **Flank Route A (West Pillar Alley):** Semi-enclosed corridor (X: -24 to -12) separated by partition walls with 2 archway connectors into Center; features heavy cover pillars and staggered crates for 5–12m CQC.
    - **Flank Route B & High Ground (East Catwalk Overlook):** Elevated platform at **Y = 3.5m** (10m x 16m) overlooking Center with waist-high parapet railings. Features **3 distinct attack vectors**: North Ramp (10m, ~19°), South Ramp (10m, ~19°), and Center 2-tier skill-jump crates (Y = 1.2m and 2.4m).
    - **Lower Route (Subway Underpass Trench):** Recessed corridor at **Y = -2.0m** (8m x 28m) running under the High Ground bridge, providing 100% overhead cover from sniper fire with 3 access ramps (North, South, and Center).
    - **North & South Plazas:** Tactical spawn staging zones with L-shaped barriers and crates.
  - **10 Strategic Spawn Points:** Distributed across all sectors (North Plaza, South Plaza, Flank A, High Ground Catwalk, Low Route Underpass, and Center Alcove) with natural LOS obstruction to prevent spawn camping.
  - **Full 3D NavigationMesh Integration:** Runtime StaticBody3D collision parsing generating 327 active 3D navigation polygons across ground floor, underpass, catwalk, and ramps.
  - **FFA Simulation Verified:** Verified in automated integration test suites (`test_milestone6_map.gd`, `test_ffa_foundation.gd`, `test_ffa_sim.gd`) with 8 combatants actively fighting, eliminating targets, and safely respawning across all sectors.

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
│       └── test_arena.tscn                   [M6: 50x50 Tactical Graybox Arena with 10 Spawns]
├── scripts/
│   ├── player/
│   │   └── player_controller.gd              [M1-M5: Movement, Recoil, Health, Combatant, Dynamic Spawns]
│   ├── weapons/
│   │   ├── weapon_data.gd                    [M2]
│   │   └── weapon_base.gd                    [M2]
│   ├── enemies/
│   │   └── basic_bot.gd                      [M4-M5: FFA Multi-Target Bot AI controller]
│   ├── gameplay/
│   │   └── match_manager.gd                  [M5: FFA Match lifecycle, Timer, Scores, Safe Spawns]
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

## Tactical Arena Layout & Sector Breakdown

```text
               [-25, -25]                                [+25, -25]
                      +-----------------------------------+
                      |         NORTH SPAWN PLAZA         |
                      |   [Spawn 1: Flank A / Spawn 2: CTR]
                      |   [Spawn 3: Flank B North Approach]
+---------------------+----+-------------------------+----+---------------------+
|                          |                         |                          |
|      FLANK ROUTE A       |         CENTER          |      FLANK ROUTE B       |
|    (West / Pillar Alley) |       MAIN ARENA        |  (East / Terrace Overlook|
|                          |                         |    & High Ground Catwalk)|
|  - Staggered waist crates| - Central 3x3m Monument |  - Elevated Catwalk      |
|    (1.1m) & tall pillars | - 4 Diagonal Barriers   |    (Y = 3.5m)            |
|  - 5-12m SMG/shotgun CQC | - Sprint/slide space    |  - Ramp North & South    |
|  - Partition wall with   | - Sightline pillars     |  - Skill-jump crates     |
|    2 archway connectors  | - [Spawn 10: Alcove]    |  - [Spawn 7: Catwalk]    |
|  - [Spawn 6: West Mid]   |                         |  - [Spawn 8: Underpass]  |
|                          |                         |                          |
+---------------------+----+------------+------------+----+---------------------+
|                     |                 |                 |                     |
|                     |        LOWER ROUTE / TUNNEL       |                     |
|                     |        (Y = -2.0m Underpass)      |                     |
|                     |  - Connects North/South & Center  |                     |
|                     |  - 100% overhead sniper cover     |                     |
|                     |  - [Spawn 9: Underpass Floor]     |                     |
|                     +-----------------+-----------------+                     |
|                                                                               |
|                     |         SOUTH SPAWN PLAZA         |                     |
|                     |   [Spawn 4: Flank A / Spawn 5: CTR]
|                     |   [Spawn 6: Flank B South Approach]
|                     +-----------------------------------+                     |
|                                                                               |
+-------------------------------------------------------------------------------+
               [-25, +25]                                [+25, +25]
```

### Sightline Design & Engagement Ranges
- **Short-Range (5–10m):** Flank Route A alleys, Lower Route subway tunnel, Center monument corners.
- **Medium-Range (10–25m):** North/South Plazas to Center, between Flank A partition archways, across East terrace.
- **Long-Range (25–35m):** High Ground Catwalk overlooking Center diagonally and North/South ramp approaches (limited by cover pieces to prevent map-wide sniper dominance).

### Verticality & Reachability
- **High Ground Catwalk (Y = 3.5m):** Provides powerful high-angle sightlines, but is balanced with 3 access routes:
  1. North Ramp (10.6m length, slope 19.3°)
  2. South Ramp (10.6m length, slope 19.3°)
  3. Center Skill-Jump Crates (Step 1 at Y = 1.2m, Step 2 at Y = 2.4m)
- **Lower Route Trench (Y = -2.0m):** Provides subterranean traversal protected from elevated angles, with North, South, and West entry ramps.

---

## 10 Strategic Spawn Points

| Spawn Name | Location | Elevation | Description / Strategic Purpose |
|---|---|---|---|
| `SpawnPoint_1_NorthA` | `(-18, 0.9, -21)` | Ground (Y=0) | Flank Route A North entrance behind staging cover |
| `SpawnPoint_2_NorthPlaza` | `(0, 0.9, -22)` | Ground (Y=0) | North Plaza behind L-shaped barricade |
| `SpawnPoint_3_NorthEast` | `(18, 0.9, -22)` | Ground (Y=0) | Flank Route B North ramp approach |
| `SpawnPoint_4_SouthA` | `(-18, 0.9, 21)` | Ground (Y=0) | Flank Route A South entrance behind staging cover |
| `SpawnPoint_5_SouthPlaza` | `(0, 0.9, 22)` | Ground (Y=0) | South Plaza behind L-shaped barricade (Player start) |
| `SpawnPoint_6_SouthEast` | `(18, 0.9, 22)` | Ground (Y=0) | Flank Route B South ramp approach |
| `SpawnPoint_7_WestMid` | `(-22, 0.9, 0)` | Ground (Y=0) | Flank Route A mid-pocket behind heavy pillar |
| `SpawnPoint_8_HighGround` | `(17, 4.4, 0)` | High Ground (Y=3.5) | Center of Catwalk platform facing West |
| `SpawnPoint_9_LowRoute` | `(9, -1.1, 0)` | Underpass (Y=-2.0) | Subterranean trench floor under Catwalk |
| `SpawnPoint_10_CenterAlcove` | `(-8, 0.9, 0)` | Ground (Y=0) | Center West alcove shielded behind monument |

---

## Playtest & Verification Checklist

- [x] **10 Viable Spawn Points:** Verified 10 registered spawn points with proper spatial distribution.
- [x] **3D Navigation Mesh Runtime Baking:** 327 navigation polygons baked cleanly covering Ground, High Ground Catwalk, Underpass Trench, and all connecting ramps.
- [x] **Tactical Sectors Implemented:** Center Monument + Barriers, Flank A Corridor + Partitions, High Ground Catwalk + Ramps + Skill Jumps, Lower Route Trench.
- [x] **FFA Multi-Combatant Simulation (10s & 20s):** Verified 8 combatants actively acquiring targets, fighting, eliminating enemies, and respawning across varied safe spawns.
- [x] **Regression FFA Test Suite:** 32/32 tests in `test_ffa_foundation.gd` passing with zero failures.
- [x] **Milestone 6 Test Suite:** 18/18 tests in `test_milestone6_map.gd` passing with zero failures.
- [ ] **Manual Playtest Tuning:** Full manual playtest by user to evaluate subjective feel of sliding around cover, jump heights, and assault rifle gunplay across sectors.

---

## Known Issues / Tuning Notes
- Godot 4 logs informational warnings when baking navigation mesh regarding voxel unit precision clamping (`agent_height`, `agent_max_climb`, `agent_radius`), which are expected engine diagnostics and do not impact navigation accuracy (327 valid polygons baked).
