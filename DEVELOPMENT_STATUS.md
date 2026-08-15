# Project FPS — Development Status

**Last Updated:** 2026-08-15  
**Current Milestone:** Milestone 4 — Basic Bot & Combat Feedback Pass (COMPLETE & Runtime Verified)

---

## Current Project State

- **Milestone 1 (Movement)** — COMPLETE and playtested.
- **Milestone 2 (First Weapon)** — COMPLETE and playtested.
- **Milestone 3 (Combat Loop)** — COMPLETE and playtested.
- **Milestone 4 (Basic Bot):** COMPLETE & RUNTIME VERIFIED:
  - Removed all obsolete static dummy targets from `scenes/maps/test_arena.tscn`.
  - `BasicBot` character with `NavigationAgent3D` + robust direct-chase fallback with tangent obstacle deflection.
  - Precise Line-of-Sight raycast targeting player's torso center.
  - Finite State Machine (`IDLE`, `SEARCH`, `CHASE`, `ATTACK`, `DEAD`) with 3D State Label (`$StateLabel`) and clean console transition logging.
  - Hitscan shooting (8 damage/shot, 5 rounds/sec, 15-round magazine, 2.0s reload) with configurable spread ($3^\circ$) and reaction delay ($0.35$s).
  - Health component integration with hit flash, death state, collision disabling, and 2.5s respawn cycle.
  - Bot holds fire and returns to `SEARCH` state when target dies.
- **Combat Feedback Pass (Usability & Readability):** COMPLETE & RUNTIME VERIFIED:
  - **Player Health Display:** Minimal bottom-left 2D HUD (`CombatHUD`) displaying live HP with dynamic white/amber/red color scaling.
  - **Damage Screen Flash / Vignette:** Immediate red screen flash on damage fading smoothly over 0.3s, retriggerable on rapid hits.
  - **Camera Hit Reaction:** Subtle camera flinch (pitch/yaw/roll) layered safely with mouse look and weapon recoil without competing overwrites.
  - **Death Presentation:** Fullscreen dark death overlay with "YOU DIED", killer attribution ("Killed by BasicBot"), and live countdown ("Respawning in 2.5s...").
  - **Respawn Restoration:** Restores 100 HP, resets camera offsets, hides death overlay, clears damage flash, recaptures mouse, and re-enables inputs.

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
│   │   └── player.tscn                       [M1-M4: Health, CrosshairHUD, CombatHUD]
│   ├── weapons/
│   │   ├── weapon_base.tscn                  [M2]
│   │   └── assault_rifle.tscn                [M2]
│   ├── enemies/
│   │   └── basic_bot.tscn                    [M4: BasicBot with 3D HP & State labels]
│   ├── ui/
│   │   ├── crosshair.tscn                    [Phase B: 2D CanvasLayer crosshair]
│   │   └── combat_hud.tscn                   [Combat Feedback: HP display, damage flash, death overlay]
│   └── maps/
│       └── test_arena.tscn                   [M4: Graybox arena with Bot & NavRegion]
├── scripts/
│   ├── player/
│   │   └── player_controller.gd              [M1-M4: Movement, Recoil, Health, CombatHUD, Camera kick, Respawn]
│   ├── weapons/
│   │   ├── weapon_data.gd                    [M2]
│   │   └── weapon_base.gd                    [M2]
│   ├── enemies/
│   │   └── basic_bot.gd                      [M4: Bot AI controller]
│   ├── ui/
│   │   └── combat_hud.gd                     [Combat Feedback: 2D HUD controller]
│   ├── maps/
│   │   └── test_arena.gd                     [M4: NavMesh runtime baker]
│   └── systems/
│       ├── health.gd                         [M3: Health component with signals & respawn]
│       └── damage_info.gd                    [M3: Damage payload data container]
└── data/
    ├── weapons/
    │   └── assault_rifle.tres                [M2]
    └── characters/ maps/ configuration/
```

---

### Implemented Systems

| System | File | Status |
|---|---|---|
| PlayerController | `scripts/player/player_controller.gd` | Complete (Movement, Recoil absorption, Camera flinch, Health integration, Respawn) |
| Crosshair HUD | `scenes/ui/crosshair.tscn` | Complete (2D CanvasLayer, 4 centered ticks, fixed screen-center) |
| Combat HUD | `scenes/ui/combat_hud.tscn` & `scripts/ui/combat_hud.gd` | Complete (Bottom-left HP display, Damage screen flash, YOU DIED overlay with countdown) |
| WeaponData (Resource) | `scripts/weapons/weapon_data.gd` | Complete |
| WeaponBase | `scripts/weapons/weapon_base.gd` | Complete (Hitscan, Damage dispatch, Recoil spray, Debug label removed) |
| Health Component | `scripts/systems/health.gd` | Complete (damage_received, healed, died, respawned signals) |
| DamageInfo Class | `scripts/systems/damage_info.gd` | Complete |
| BasicBot AI | `scripts/enemies/basic_bot.gd` | Complete (FSM, NavAgent3D + Direct chase, LOS raycast, Aim spread, Hitscan fire, 2.5s respawn, 3D State/HP labels) |
| BasicBot Scene | `scenes/enemies/basic_bot.tscn` | Complete (Stylized low-poly amber/cyan mesh, Capsule col, 3D HP & State Labels) |
| AssaultRifle | `scenes/weapons/assault_rifle.tscn` | Complete |
| AssaultRifle Data | `data/weapons/assault_rifle.tres` | Complete |
| Test Arena | `scenes/maps/test_arena.tscn` | Complete (Player at South, Bot at North, NavRegion, tactical cover blocks) |
| Test Arena Script | `scripts/maps/test_arena.gd` | Complete (NavMesh runtime baker) |

---

## Combat & Feedback Flow

```
+-----------------------------------------------------------------------------------+
|                                COMBAT GAMEPLAY LOOP                               |
+-----------------------------------------------------------------------------------+

     [PLAYER]                                              [BASIC BOT]
  * Fixed 2D Crosshair                                  * Finite State Machine (SEARCH/CHASE/ATTACK/DEAD)
  * CombatHUD (HP 100, Flash, Death UI)                 * NavAgent3D + Direct Fallback with Wall Deflection
  * Layered Camera (Mouse + Recoil + Flinch)            * Torso-level Line of Sight Raycast Check
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
  Player.record_kill("BasicBot")                        CombatHUD triggers Red Flash + updates HP label
  Bot respawns at origin after 2.5s                     Camera applies subtle hit reaction flinch
                                                              │
                                                              ▼ (if Player HP <= 0)
                                                        Player enters DEAD state
                                                        CombatHUD displays "YOU DIED" + Countdown
                                                        Bot transitions to SEARCH & holds fire
                                                        Player respawns after 2.5s (HP = 100, HUD restored)
```

---

## Playtest Checklist (Milestone 4 + Combat Feedback)

- [x] All 3 old static dummy targets removed from `test_arena.tscn`.
- [x] 2D white 4-line crosshair appears fixed in the center of the screen.
- [x] `BasicBot` spawns with 3D HP label and 3D State label (`SEARCH`, `CHASE`, `ATTACK`, `DEAD`).
- [x] Bot moves toward player, navigates around cover blocks, aims, and shoots.
- [x] Bottom-left 2D HUD shows current player health (e.g. `100 HP`).
- [x] Taking damage triggers an immediate red damage screen flash fading smoothly over 0.3s.
- [x] Taking damage triggers a subtle camera flinch that does not interfere with mouse look or weapon recoil.
- [x] Health HUD updates dynamically (`92 HP`, `84 HP`...) and shifts color (White $\to$ Amber $\to$ Red).
- [x] Upon reaching 0 HP, player enters explicit `is_dead` state:
  - Input, movement, and weapon firing are stopped.
  - Fullscreen dark death overlay appears with "YOU DIED", "Killed by BasicBot", and live countdown.
  - Bot stops firing and returns to `SEARCH` state.
- [x] After 2.5s respawn timer, player respawns at spawn point with 100 HP, death overlay hides, damage flash clears, camera resets, and full gameplay controls resume.
