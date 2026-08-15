# Project FPS — Development Status

**Last Updated:** 2026-08-15  
**Current Milestone:** Milestone 5 — Free For All Foundation (COMPLETE & Runtime Verified)

---

## Current Project State

- **Milestone 1 (Movement)** — COMPLETE and playtested.
- **Milestone 2 (First Weapon)** — COMPLETE and playtested.
- **Milestone 3 (Combat Loop)** — COMPLETE and playtested.
- **Milestone 4 (Basic Bot & Combat Feedback Pass)** — COMPLETE & RUNTIME VERIFIED.
- **Milestone 5 (Free For All Foundation):** COMPLETE & RUNTIME VERIFIED:
  - **Combatant Abstraction:** Unified `combatants` group interface implemented across `PlayerController` and `BasicBot` (`combatant_name`, `kills`, `deaths`, `is_alive()`, `get_target_position()`, `take_damage()`).
  - **Dynamic Multi-Targeting AI:** BasicBot dynamically queries all active combatants, prioritising Line of Sight, valid range ($\le 25$m), and nearest distance. Bots engage both the Player and other Bots and immediately retarget upon target elimination.
  - **Bot-to-Bot Combat:** Complete hitscan damage, health reduction, death state triggering, and killer credit functioning seamlessly across Player $\leftrightarrow$ Bot and Bot $\leftrightarrow$ Bot.
  - **MatchManager Foundation:** Modular match controller managing match lifecycle (`WAITING`, `PLAYING`, `ENDED`), countdown timer (5:00 / 300s), kill limit (25 kills), scoreboard tracking (kills, deaths, score), and win-condition determination.
  - **Dynamic Safe Spawn System:** 9 reusable arena spawn points (`SpawnPoint`) distributed strategically across the arena; `MatchManager.get_spawn_point()` dynamically evaluates and picks the spawn point maximizing distance from alive enemies.
  - **8-Combatant Arena Configuration:** `scenes/maps/test_arena.tscn` configured with 1 Human Player + 7 `BasicBot` instances (`Bot 1` through `Bot 7`) and active `MatchManager`.
  - **Non-Spamming Event Logging:** Structured console logging for match lifecycle (`[MATCH]`, `[KILL]`, `[SCORE]`, `[DEATH]`, `[TARGET]`, `[RESPAWN]`, `[WINNER]`).
  - **Automated Verification:** 32/32 headless integration tests passing (`scripts/systems/test_ffa_foundation.gd`) and verified in continuous live FFA simulation (`scripts/systems/test_ffa_sim.gd`).

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
│       └── test_arena.tscn                   [M5: 8-Combatant Arena with 9 SpawnPoints & MatchManager]
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
│   │   ├── test_arena.gd                     [M4: NavMesh runtime baker]
│   │   └── spawn_point.gd                    [M5: Reusable 3D Arena Spawn Point]
│   └── systems/
│       ├── health.gd                         [M3-M5: Health component with MatchManager integration]
│       ├── damage_info.gd                    [M3: Damage payload data container]
│       ├── test_ffa_foundation.gd            [M5: Automated FFA unit & integration test suite]
│       └── test_ffa_sim.gd                   [M5: Live FFA multi-combatant simulation test]
└── data/
    ├── weapons/
    │   └── assault_rifle.tres                [M2]
    └── characters/ maps/ configuration/
```

---

### Implemented Systems

| System | File | Status |
|---|---|---|
| PlayerController | `scripts/player/player_controller.gd` | Complete (Movement, Recoil, Camera flinch, Health, Combatant, Dynamic Respawn) |
| Crosshair HUD | `scenes/ui/crosshair.tscn` | Complete (2D CanvasLayer, 4 centered ticks, fixed screen-center) |
| Combat HUD | `scenes/ui/combat_hud.tscn` & `scripts/ui/combat_hud.gd` | Complete (Bottom-left HP display, Damage screen flash, YOU DIED overlay with countdown) |
| WeaponData (Resource) | `scripts/weapons/weapon_data.gd` | Complete |
| WeaponBase | `scripts/weapons/weapon_base.gd` | Complete (Hitscan, Damage dispatch, Recoil spray) |
| Health Component | `scripts/systems/health.gd` | Complete (damage_received, healed, died, respawned signals, MatchManager dispatch) |
| DamageInfo Class | `scripts/systems/damage_info.gd` | Complete |
| MatchManager | `scripts/gameplay/match_manager.gd` | Complete (FSM States, 5:00 Timer, 25 Kill Limit, Scoreboard, Safe Spawning, Winner check) |
| SpawnPoint | `scripts/maps/spawn_point.gd` | Complete (Reusable 3D Spawn transform in group `spawn_points`) |
| BasicBot AI | `scripts/enemies/basic_bot.gd` | Complete (FFA Multi-target FSM, LOS check, Hitscan fire, Dynamic Retargeting & Safe Respawn) |
| BasicBot Scene | `scenes/enemies/basic_bot.tscn` | Complete (Stylized low-poly mesh, 3D HP/State Labels, in `combatants` group) |
| AssaultRifle | `scenes/weapons/assault_rifle.tscn` | Complete |
| AssaultRifle Data | `data/weapons/assault_rifle.tres` | Complete |
| Test Arena | `scenes/maps/test_arena.tscn` | Complete (1 Player + 7 Bots, 9 SpawnPoints, MatchManager, NavRegion) |
| Test Arena Script | `scripts/maps/test_arena.gd` | Complete (NavMesh runtime baker) |
| FFA Test Suite | `scripts/systems/test_ffa_foundation.gd` | Complete (32/32 automated tests passed) |

---

## FFA Combat Loop & Event Architecture

```
+-----------------------------------------------------------------------------------+
|                           FREE FOR ALL MATCH ARCHITECTURE                         |
+-----------------------------------------------------------------------------------+

                          +----------------------+
                          |     MatchManager     |
                          |  - State: PLAYING    |
                          |  - Timer: 300.0s     |
                          |  - Kill Limit: 25    |
                          +----------+-----------+
                                     │
           ┌─────────────────────────┼─────────────────────────┐
           ▼                         ▼                         ▼
    [1 Human Player]           [BasicBot 1..7]          [9 Spawn Points]
   (Group: combatants)       (Group: combatants)      (Group: spawn_points)
           │                         │                         │
           │ [Hitscan AR]            │ [Multi-Target AI]       │
           │                         │ - Evaluates Candidates  │
           │                         │ - Line of Sight Raycast │
           │                         │ - Targets Player/Bots   │
           │                         │                         │
           ▼                         ▼                         │
   DamageInfo payload        DamageInfo payload                │
   (Attacker: Player)        (Attacker: Bot X)                 │
           │                         │                         │
           └────────────┬────────────┘                         │
                        ▼                                      │
               Target.take_damage()                            │
                        │                                      │
                        ▼ (if target HP <= 0)                  │
               Target enters DEAD state                        │
                        │                                      │
                        ▼                                      │
        MatchManager.record_kill(Killer, Victim)               │
        - Killer Score += 1, Victim Deaths += 1                │
        - If Score >= 25 -> MatchManager.end_match()           │
                        │                                      │
                        ▼ (after 2.5s respawn delay)           │
        Safe Spawn Selection ──────────────────────────────────┘
        - MatchManager.get_spawn_point() picks spawn point
          maximizing distance from alive enemies
        - Target.respawn() -> Restores 100 HP, resets FSM
```

---

## Playtest Checklist (Milestone 5 — FFA Foundation)

- [x] **Test A — 8 Active Combatants:** 1 Human Player + 7 BasicBots active in the arena.
- [x] **Test B — Dynamic Multi-Target Selection:** Bots acquire different targets across the arena (both player and other bots).
- [x] **Test C — Bot-to-Bot Combat:** Bots deal hitscan damage to other bots, reducing HP and eliminating them.
- [x] **Test D — Player Kills Bot:** Player eliminates bot $\to$ kill credited to Player $\to$ MatchManager score increments (+1).
- [x] **Test E — Bot Kills Player:** Bot eliminates Player $\to$ CombatHUD shows killer name $\to$ Player respawns.
- [x] **Test F — Respawn Flow:** Dead combatants respawn after 2.5s at a safe spawn point with 100 HP, collision restored, and state reset to `SEARCH`.
- [x] **Test G — Dynamic Target Switching:** When a bot's current target dies, it immediately retargets another alive combatant.
- [x] **Test H — Match Timer:** Internal timer counts down from 300s (5:00) and cleanly ends match upon reaching 0s.
- [x] **Test I — Kill Limit Win Condition:** Reaching kill limit (25 kills) immediately transitions match to `ENDED` and declares winner.
- [x] **Structured Event Logging:** Verified non-spamming logs for `[MATCH]`, `[KILL]`, `[SCORE]`, `[DEATH]`, `[TARGET]`, `[RESPAWN]`, and `[WINNER]`.
