# Project FPS — Development Status

**Last Updated:** 2026-08-15
**Current Milestone:** Milestone 3 — Combat Loop (implementation complete, awaiting playtest)

---

## Current Project State

- Milestone 1 (Movement) — COMPLETE and playtested.
- Milestone 2 (First Weapon) — COMPLETE and playtested.
- Milestone 3 (Combat Loop) — Implemented (Health system, DamageInfo, DummyTarget, Death & Respawn, Kill tracking).

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
+-- assets/
|   +-- models/ animations/ audio/ materials/ textures/ vfx/
+-- scenes/
|   +-- player/
|   |   +-- player.tscn                       [Milestone 1+2]
|   +-- weapons/
|   |   +-- weapon_base.tscn                  [Milestone 2]
|   |   +-- assault_rifle.tscn                [Milestone 2]
|   +-- enemies/
|   |   +-- dummy_target.tscn                 [NEW - Milestone 3]
|   +-- maps/
|   |   +-- test_arena.tscn                   [Milestone 1+2, updated M3]
+-- scripts/
|   +-- player/
|   |   +-- player_controller.gd              [Milestone 1+2, updated M3 with kill tracking]
|   +-- weapons/
|   |   +-- weapon_data.gd                    [Milestone 2]
|   |   +-- weapon_base.gd                    [Milestone 2, updated M3 with damage routing]
|   +-- enemies/
|   |   +-- dummy_target.gd                   [NEW - Milestone 3]
|   +-- systems/
|   |   +-- health.gd                         [NEW - Milestone 3]
|   |   +-- damage_info.gd                    [NEW - Milestone 3]
+-- data/
    +-- weapons/
    |   +-- assault_rifle.tres                [Milestone 2]
    +-- characters/ maps/ configuration/
```

### Implemented Systems

| System | File | Status |
|---|---|---|
| PlayerController | `scripts/player/player_controller.gd` | Complete (Movement, Recoil absorption, Kill tracking) |
| WeaponData (Resource) | `scripts/weapons/weapon_data.gd` | Complete |
| WeaponBase | `scripts/weapons/weapon_base.gd` | Complete (Hitscan, Damage dispatch, Recoil spray) |
| Health Component | `scripts/systems/health.gd` | Complete |
| DamageInfo Class | `scripts/systems/damage_info.gd` | Complete |
| DummyTarget Entity | `scenes/enemies/dummy_target.tscn` | Complete (100 HP, Damage flash, 3D HP Label, 2s Respawn) |
| AssaultRifle | `scenes/weapons/assault_rifle.tscn` | Complete |
| AssaultRifle Data | `data/weapons/assault_rifle.tres` | Complete |
| Test Arena | `scenes/maps/test_arena.tscn` | Complete (Instanced DummyTargets at 6m, 12m, 18m) |

---

## Milestone 3 — Combat Architecture

### Combat Data Flow

```
WeaponBase (_do_hitscan)
    │
    ▼ (creates DamageInfo payload)
DamageInfo { amount: 25, attacker: Player, hit_point, hit_normal, hit_type }
    │
    ▼ (dispatches via take_damage interface)
DummyTarget.take_damage(DamageInfo)
    │
    ▼ (routes to component)
Health.take_damage(DamageInfo)
    ├── emits damage_received(DamageInfo, current_hp, max_hp)
    │     └── DummyTarget updates 3D HP label and triggers visual hit flash
    └── if current_hp <= 0:
          ├── emits died(killer)
          │     ├── DummyTarget disables collision, hides visuals, starts 2.0s timer
          │     └── PlayerController.record_kill("DummyTarget") increments kill count
          └── on 2.0s timeout:
                └── Health.respawn() -> DummyTarget restores collision, visuals, and HP
```

---

## Playtest Checklist (Milestone 3)

- [ ] Target HP is visible as a 3D label above the dummy (`100 / 100 HP`)
- [ ] Shooting the dummy deals 25 damage per body shot (`100 -> 75 -> 50 -> 25 -> 0`)
- [ ] Console prints `[DAMAGE] DummyTarget took 25 damage. HP: 75/100`
- [ ] Dummy flashes upon receiving hit
- [ ] At 0 HP: `[DEATH] DummyTarget killed by Player` and `[KILL] Player eliminated DummyTarget` / `[KILLS] Player: 1`
- [ ] At death: dummy visuals hide and collision is disabled (subsequent shots do not hit dead target)
- [ ] After 2 seconds: dummy respawns (`[RESPAWN] DummyTarget respawned. HP: 100/100`) and becomes damageable again
- [ ] Shooting environment walls/floor does not trigger damage
- [ ] Movement, jumping, sliding, crouch, and weapon recoil remain completely unchanged

---

## Milestones

| Milestone | Description | Status |
|---|---|---|
| **0 — Foundation** | Project structure, input, git, docs | COMPLETE |
| **1 — Movement** | CharacterBody3D, mouse look, walk, sprint, jump, crouch, slide | COMPLETE |
| **2 — First Weapon** | Weapon data, hitscan, reload, recoil, placeholder geometry | COMPLETE |
| **3 — Combat Loop** | Health, damage, death, respawn, kill tracking | IN PROGRESS (awaiting playtest) |
| 4 — Bot | Navigation, targeting, combat, death, respawn | Planned |
| 5 — FFA | Multiple bots, score, timer, match end, scoreboard | Planned |
| 6 — Combat Polish | Weapon animation, hit VFX, muzzle flash, audio, camera effects | Planned |
| 7 — First Art Pass | Character, weapon model, environment, materials, lighting, first map | Planned |
| 8 — UI | Main menu, HUD, scoreboard, settings | Planned |
| 9 — Multiplayer | Networking, player sync, 2-8 player scaling | Planned |
| 10 — Content | Additional weapons, maps, skins, progression | Planned |

---

## Next Planned Task: Milestone 4 — Bot

Prerequisites: Milestone 3 playtested and combat loop approved.

Scope:
1. Navigation mesh / NavigationAgent3D setup in test arena
2. Bot entity with Health component, movement controller, and weapon
3. State machine (Patrol / Seek / Engage / Death / Respawn)
4. Bot targeting and hitscan shooting
