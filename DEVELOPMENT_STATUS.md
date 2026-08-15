# Project FPS — Development Status

**Last Updated:** 2026-08-15  
**Current Milestone:** Milestone 4 — Basic Bot (Runtime Verified & Fully Operational)

---

## Current Project State

- **Milestone 1 (Movement)** — COMPLETE and playtested.
- **Milestone 2 (First Weapon)** — COMPLETE and playtested.
- **Milestone 3 (Combat Loop)** — COMPLETE and playtested.
- **Combat Presentation Fixes**:
  - **Phase A (Debug Ammo Label):** Removed temporary world-space `Label3D` and update logic from `weapon_base`.
  - **Phase B (Center Crosshair):** Implemented lightweight 2D `CanvasLayer` crosshair with 4 crisp, screen-centered tick marks.
- **Milestone 4 (Basic Bot):** COMPLETE & RUNTIME VERIFIED in real Godot engine:
  - Removed all obsolete static dummy targets from `scenes/maps/test_arena.tscn`.
  - `BasicBot` character with `NavigationAgent3D` + robust direct-chase fallback with tangent obstacle deflection.
  - Precise Line-of-Sight raycast targeting player's torso center.
  - Finite State Machine (`IDLE`, `SEARCH`, `CHASE`, `ATTACK`, `DEAD`) with 3D State Label (`$StateLabel`) and clean console transition logging.
  - Hitscan shooting (8 damage/shot, 5 rounds/sec, 15-round magazine, 2.0s reload) with configurable spread ($3^\circ$) and reaction delay ($0.35$s).
  - Health component integration with hit flash, death state, collision disabling, and 2.5s respawn cycle.
  - Player health integration with damage logging, death handling, and 2.5s respawn.

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
│   │   └── player.tscn                       [M1+2, updated M4 with Health & CrosshairHUD]
│   ├── weapons/
│   │   ├── weapon_base.tscn                  [M2, updated M4: AmmoLabel removed]
│   │   └── assault_rifle.tscn                [M2]
│   ├── enemies/
│   │   └── basic_bot.tscn                    [M4 - BasicBot with 3D HP & State labels]
│   ├── ui/
│   │   └── crosshair.tscn                    [Phase B - 2D CanvasLayer crosshair]
│   └── maps/
│       └── test_arena.tscn                   [M4 - Clean graybox arena with Bot & NavRegion]
├── scripts/
│   ├── player/
│   │   └── player_controller.gd              [M1+2+3, updated M4 with Health & respawn]
│   ├── weapons/
│   │   ├── weapon_data.gd                    [M2]
│   │   └── weapon_base.gd                    [M2+3, updated M4: removed AmmoLabel calls]
│   ├── enemies/
│   │   └── basic_bot.gd                      [M4 - Bot AI controller]
│   ├── maps/
│   │   └── test_arena.gd                     [M4 - NavMesh runtime baker]
│   └── systems/
│       ├── health.gd                         [M3 - Health component with signals & respawn]
│       └── damage_info.gd                    [M3 - Damage payload data container]
└── data/
    ├── weapons/
    │   └── assault_rifle.tres                [M2]
    └── characters/ maps/ configuration/
```

---

### Implemented Systems

| System | File | Status |
|---|---|---|
| PlayerController | `scripts/player/player_controller.gd` | Complete (Movement, Recoil absorption, Kill tracking, Health integration, Respawn) |
| Crosshair HUD | `scenes/ui/crosshair.tscn` | Complete (2D CanvasLayer, 4 centered ticks, fixed screen-center) |
| WeaponData (Resource) | `scripts/weapons/weapon_data.gd` | Complete |
| WeaponBase | `scripts/weapons/weapon_base.gd` | Complete (Hitscan, Damage dispatch, Recoil spray, Debug label removed) |
| Health Component | `scripts/systems/health.gd` | Complete (damage_received, healed, died, respawned signals) |
| DamageInfo Class | `scripts/systems/damage_info.gd` | Complete |
| BasicBot AI | `scripts/enemies/basic_bot.gd` | Complete (FSM, NavAgent3D + Direct chase, LOS raycast, Aim spread, Hitscan fire, 2.5s respawn, 3D State/HP labels) |
| BasicBot Scene | `scenes/enemies/basic_bot.tscn` | Complete (Stylized low-poly amber/cyan mesh, Capsule col, 3D HP & State Labels) |
| AssaultRifle | `scenes/weapons/assault_rifle.tscn` | Complete |
| AssaultRifle Data | `data/weapons/assault_rifle.tres` | Complete |
| Test Arena | `scenes/maps/test_arena.tscn` | Complete (Clean layout: Player at South, Bot at North, NavRegion, tactical cover blocks) |
| Test Arena Script | `scripts/maps/test_arena.gd` | Complete (NavMesh runtime baker) |

---

## Milestone 4 — Bot & Combat Flow

```
+-----------------------------------------------------------------------------------+
|                                COMBAT GAMEPLAY LOOP                               |
+-----------------------------------------------------------------------------------+

     [PLAYER]                                              [BASIC BOT]
  * Fixed 2D Crosshair                                  * Finite State Machine (SEARCH/CHASE/ATTACK/DEAD)
  * Hitscan Raycast (-Z forward)                        * NavAgent3D + Direct Fallback with Wall Deflection
  * Health Component (100 HP)                           * Torso-level Line of Sight Raycast Check
        │                                                     │
        │ [Player fires AR]                                   │ [Bot spots Player within 25m]
        ▼                                                     ▼
  DamageInfo payload                                    State -> CHASE / ATTACK
  (amount: 25, attacker: Player)                        (aims with spread + reaction delay)
        │                                                     │
        ▼ (take_damage)                                       ▼ (fires hitscan)
  Bot Health reduced (-25)                              DamageInfo payload
  Bot flashes yellow & updates 3D HP                    (amount: 8, attacker: Bot)
        │                                                     │
        ▼ (if Bot HP <= 0)                                    ▼ (take_damage)
  Bot enters DEAD state                                 Player Health reduced (-8)
  Player.record_kill("BasicBot")                        Player prints damage feedback
  Bot respawns at origin after 2.5s                           │
                                                              ▼ (if Player HP <= 0)
                                                        Player enters DEAD state
                                                        Player respawns at spawn after 2.5s
```

---

## Playtest Checklist (Milestone 4 — Runtime Verified)

- [x] All 3 old static dummy targets removed from `test_arena.tscn`.
- [x] Debug `AmmoLabel` is removed from the 3D weapon model view.
- [x] 2D white 4-line crosshair appears fixed in the center of the screen.
- [x] Firing the assault rifle hits exactly where the crosshair points.
- [x] `BasicBot` spawns in the arena with an amber body, cyan visor, 3D HP label, and 3D State label.
- [x] Bot acquires line of sight (LOS) and smoothly rotates to face the player.
- [x] When player is behind cover/walls, bot does not shoot through walls and navigates around obstacles.
- [x] Bot engages player with automatic rifle fire (8 damage/shot, 15-round mag, reload cycle).
- [x] Bot aim incorporates slight inaccuracy/spread ($3.0^\circ$) so it is beatable.
- [x] Player takes damage when hit by bot bullets (`[PLAYER DAMAGE] Took 8 damage...`).
- [x] Shooting the bot deals damage, flashes the bot yellow, and reduces bot HP (`[DAMAGE] BasicBot took 25 damage...`).
- [x] When bot HP reaches 0: bot dies, collision is disabled, visuals hide, player records kill (`[KILL] Player eliminated BasicBot`).
- [x] Bot respawns after 2.5s (`[BOT RESPAWN] Bot respawned... HP: 100/100`).
