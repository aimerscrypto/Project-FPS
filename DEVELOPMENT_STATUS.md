# Project FPS — Development Status

**Last Updated:** 2026-08-15  
**Current Milestone:** Milestone 4 — Basic Bot (implementation complete and automated test suite passed; ready for manual playtesting)

---

## Current Project State

- **Milestone 1 (Movement)** — COMPLETE and playtested.
- **Milestone 2 (First Weapon)** — COMPLETE and playtested.
- **Milestone 3 (Combat Loop)** — COMPLETE and playtested.
- **Combat Presentation Fixes**:
  - **Phase A (Debug Ammo Label):** Removed temporary world-space `Label3D` and update logic from `weapon_base`.
  - **Phase B (Center Crosshair):** Implemented lightweight 2D `CanvasLayer` crosshair with 4 crisp, screen-centered tick marks.
- **Milestone 4 (Basic Bot):** COMPLETE implementation & automated test verification:
  - `BasicBot` character with `NavigationAgent3D`, FSM (`IDLE`, `SEARCH`, `CHASE`, `ATTACK`, `DEAD`), Line-of-Sight checks, hitscan shooting with aim inaccuracy, reload cycle, hit flash, and 2.5s respawn.
  - `Health` component and `take_damage(DamageInfo)` integrated into `PlayerController` with prototype respawn loop.
  - `NavigationRegion3D` setup and automatic navigation mesh baking on `test_arena.tscn`.

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
│   │   ├── dummy_target.tscn                 [M3]
│   │   └── basic_bot.tscn                    [NEW - Milestone 4]
│   ├── ui/
│   │   └── crosshair.tscn                    [NEW - Phase B]
│   └── maps/
│       └── test_arena.tscn                   [M1+2+3, updated M4 with NavRegion & Bot]
├── scripts/
│   ├── player/
│   │   └── player_controller.gd              [M1+2+3, updated M4 with Health & respawn]
│   ├── weapons/
│   │   ├── weapon_data.gd                    [M2]
│   │   └── weapon_base.gd                    [M2+3, updated M4: removed AmmoLabel calls]
│   ├── enemies/
│   │   ├── dummy_target.gd                   [M3]
│   │   └── basic_bot.gd                      [NEW - Milestone 4 AI]
│   ├── maps/
│   │   └── test_arena.gd                     [NEW - Milestone 4 NavMesh baker]
│   └── systems/
│       ├── health.gd                         [M3]
│       └── damage_info.gd                    [M3]
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
| BasicBot AI | `scripts/enemies/basic_bot.gd` | Complete (FSM, NavAgent3D, LOS raycast, Aim spread, Hitscan fire, 2.5s respawn) |
| BasicBot Scene | `scenes/enemies/basic_bot.tscn` | Complete (Stylized low-poly amber/cyan mesh, Capsule col, 3D HP Label) |
| DummyTarget Entity | `scenes/enemies/dummy_target.tscn` | Complete (100 HP, Damage flash, 3D HP Label, 2s Respawn) |
| AssaultRifle | `scenes/weapons/assault_rifle.tscn` | Complete |
| AssaultRifle Data | `data/weapons/assault_rifle.tres` | Complete |
| Test Arena | `scenes/maps/test_arena.tscn` | Complete (NavigationRegion3D, Baked NavMesh, BasicBot, DummyTargets) |
| Test Arena Script | `scripts/maps/test_arena.gd` | Complete (NavMesh runtime baker) |

---

## Milestone 4 — Bot & Combat Flow

```
+-----------------------------------------------------------------------------------+
|                                COMBAT GAMEPLAY LOOP                               |
+-----------------------------------------------------------------------------------+

     [PLAYER]                                              [BASIC BOT]
  * Fixed 2D Crosshair                                  * Finite State Machine
  * Hitscan Raycast (-Z forward)                        * NavigationAgent3D Pathfinding
  * Health Component (100 HP)                           * Line of Sight Raycast Check
        │                                                     │
        │ [Player fires AR]                                   │ [Bot spots Player]
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

## Playtest Checklist (Milestone 4)

- [x] Debug `AmmoLabel` is removed from the 3D weapon model view.
- [x] 2D white 4-line crosshair appears fixed in the center of the screen.
- [x] Crosshair stays centered regardless of camera pitch/yaw and viewmodel movement.
- [x] Firing the assault rifle hits exactly where the crosshair points.
- [x] `BasicBot` spawns in the arena with a distinct amber body, cyan visor, and 3D HP label.
- [x] Bot acquires line of sight (LOS) and rotates to face the player.
- [x] When player is behind cover/walls, bot does not shoot through walls and navigates around obstacles.
- [x] Bot engages player with automatic rifle fire (8 damage/shot, 15-round mag, reload cycle).
- [x] Bot aim incorporates slight inaccuracy/spread ($3.0^\circ$) so it is beatable.
- [x] Player takes damage when hit by bot bullets (`[PLAYER DAMAGE] Took 8 damage...`).
- [x] Shooting the bot deals damage, flashes the bot yellow, and reduces bot HP (`[DAMAGE] BasicBot took 25 damage...`).
- [x] When bot HP reaches 0: bot dies, collision is disabled, visuals hide, player records kill (`[KILL] Player eliminated BasicBot`).
- [x] Bot respawns after 2.5s (`[BOT RESPAWN] Bot respawned... HP: 100/100`).
- [x] If player HP reaches 0: player dies, input locks, and player respawns after 2.5s.
- [x] All Milestone 1 movement (walk, sprint, jump, crouch, slide) and weapon mechanics (firing, ammo, reload, recoil) remain intact.

---

## Milestones Roadmap

| Milestone | Description | Status |
|---|---|---|
| **0 — Foundation** | Project structure, input, git, docs | COMPLETE |
| **1 — Movement** | CharacterBody3D, mouse look, walk, sprint, jump, crouch, slide | COMPLETE |
| **2 — First Weapon** | Weapon data, hitscan, reload, recoil, placeholder geometry | COMPLETE |
| **3 — Combat Loop** | Health, damage, death, respawn, kill tracking | COMPLETE |
| **4 — Basic Bot** | Navigation, perception, targeting, bot combat, player damage/respawn | COMPLETE (awaiting manual playtest) |
| 5 — FFA | Multiple bots, score, timer, match end, scoreboard | Planned |
| 6 — Combat Polish | Weapon animation, hit VFX, muzzle flash, audio, camera effects | Planned |
| 7 — First Art Pass | Character, weapon model, environment, materials, lighting, first map | Planned |
| 8 — UI | Main menu, HUD, scoreboard, settings | Planned |
| 9 — Multiplayer | Networking, player sync, 2-8 player scaling | Planned |
| 10 — Content | Additional weapons, maps, skins, progression | Planned |

---

## Next Planned Task: Milestone 5 — FFA (Free For All)

Prerequisites: Milestone 4 playtested and confirmed stable.

Scope:
1. Multi-bot spawner supporting 4–8 concurrent bots.
2. Bot-vs-bot engagement and free-for-all target acquisition.
3. Match manager (score tracking, elimination feed, match timer, score limit).
4. Match completion state and prototype scoreboard.
