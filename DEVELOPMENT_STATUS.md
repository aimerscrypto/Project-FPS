# Project FPS — Development Status

**Last Updated:** 2026-08-15
**Current Milestone:** Milestone 2 — First Weapon (implementation complete, awaiting playtest)

---

## Current Project State

Milestone 1 (Movement) — COMPLETE and playtested.
Milestone 2 (First Weapon) — Implemented, pending playtest verification.

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
|   |   +-- weapon_base.tscn                  [NEW - Milestone 2]
|   |   +-- assault_rifle.tscn                [NEW - Milestone 2]
|   +-- enemies/ maps/ ui/ gameplay/
|   |   +-- test_arena.tscn                   [Milestone 1, updated M2]
+-- scripts/
|   +-- player/
|   |   +-- player_controller.gd              [Milestone 1, updated M2]
|   +-- weapons/
|   |   +-- weapon_data.gd                    [NEW - Milestone 2]
|   |   +-- weapon_base.gd                    [NEW - Milestone 2]
|   +-- enemies/ gameplay/ systems/ ui/
+-- data/
    +-- weapons/
    |   +-- assault_rifle.tres                [NEW - Milestone 2]
    +-- characters/ maps/ configuration/
```

### Implemented Systems

| System | File | Status |
|---|---|---|
| PlayerController | scripts/player/player_controller.gd | Complete |
| WeaponData (Resource) | scripts/weapons/weapon_data.gd | Complete |
| WeaponBase | scripts/weapons/weapon_base.gd | Complete - needs playtest |
| WeaponBase Scene | scenes/weapons/weapon_base.tscn | Complete |
| AssaultRifle Scene | scenes/weapons/assault_rifle.tscn | Complete |
| AssaultRifle Data | data/weapons/assault_rifle.tres | Complete |
| Test Arena | scenes/maps/test_arena.tscn | Updated with 3 red targets |

---

## Milestone 2 — Weapon Architecture

### Data Flow

```
assault_rifle.tres (WeaponData resource)
    -> assault_rifle.tscn (instances weapon_base.tscn + assigns data)
        -> weapon_base.tscn (placeholder mesh + RayCast3D + AmmoLabel)
            -> weapon_base.gd (all logic)
                <- player_controller.gd (calls try_fire() / try_reload())
```

### Weapon State Machine

States: READY, FIRING, RELOADING

- READY -> FIRING: fire input pressed, ammo > 0, fire_timer == 0
- FIRING -> READY: fire_timer expires
- READY -> RELOADING: R pressed, magazine not full, reserve > 0
- RELOADING -> READY: reload_timer expires

### Assault Rifle Stats (assault_rifle.tres)

| Property | Value |
|---|---|
| damage | 25.0 |
| headshot_multiplier | 2.0 |
| fire_rate | 10 rounds/sec |
| is_automatic | true |
| magazine_size | 30 |
| reserve_ammo | 120 |
| reload_time | 2.0 sec |
| spread_degrees | 0.5 |
| range_meters | 100.0 |
| recoil_vertical | 0.4 deg/shot |
| recoil_horizontal | 0.15 deg max random |
| recoil_recovery | 8.0 deg/sec |

### How Firing Works

1. PlayerController._process detects Input.is_action_pressed("fire_primary")
2. Calls weapon.try_fire() each frame (fire_timer prevents rapid-fire)
3. weapon_base deducts ammo, runs _do_hitscan(), applies recoil, triggers muzzle flash
4. RayCast3D (child of weapon root, points forward -Z) reports collision
5. Hit info printed to debugger, orange sphere spawned at impact point for 2 seconds

### How Reload Works

1. PlayerController._process detects Input.is_action_just_pressed("reload")
2. Calls weapon.try_reload()
3. State becomes RELOADING, firing blocked for reload_time seconds
4. On finish: min(needed, reserve_ammo) rounds transferred to magazine

### Recoil Implementation

- Each shot: camera mount pitched up by recoil_vertical degrees
- Each shot: body rotated horizontally by random [-recoil_horizontal, +recoil_horizontal] degrees
- Per frame: accumulated recoil pitch recovered at recoil_recovery degrees/sec

### Test Targets Added

Three bright red CSGBox3D targets in test_arena.tscn:
- Target_Near: 6m forward
- Target_Mid: 12m forward + 3m right
- Target_Far: 18m forward + 3m left

### Debug Output

- Fire: "[Weapon] Fired. Ammo: X / Y"
- Hit: "[HIT] Object: name | Point: xyz | Normal: xyz"
- Miss: "[HIT] No collision detected."
- Dry fire: "[Weapon] DRY FIRE — magazine empty. Press R to reload."
- Reload: "[Weapon] Reloading... (2.0s)" then "[Weapon] Reload complete. Ammo: X / Y"
- AmmoLabel3D: visible in-world next to weapon (debug only)

---

## Playtest Checklist (Required Before Marking Milestone 2 Complete)

- [ ] Weapon appears correctly in view
- [ ] LMB fires
- [ ] Automatic fire respects fire rate
- [ ] Magazine decreases on each shot
- [ ] Weapon stops at 0 ammo (dry fire message)
- [ ] R reloads, blocked during reload
- [ ] Reserve ammo correctly decreases
- [ ] Hitscan hits targets (orange markers appear)
- [ ] Console prints correct hit/miss info
- [ ] Recoil visible but controllable
- [ ] No movement regressions
- [ ] No console errors

---

## Milestones

| Milestone | Description | Status |
|---|---|---|
| **0 — Foundation** | Project structure, input, git, docs | COMPLETE |
| **1 — Movement** | CharacterBody3D, mouse look, walk, sprint, jump, crouch, slide | COMPLETE |
| **2 — First Weapon** | Weapon data, hitscan, reload, recoil, placeholder geometry | IN PROGRESS |
| 3 — Combat Loop | Health, damage, death, respawn, score | Planned |
| 4 — Bot | Navigation, targeting, combat, death, respawn | Planned |
| 5 — FFA | Multiple bots, score, timer, match end, scoreboard | Planned |
| 6 — Combat Polish | Weapon animation, hit VFX, muzzle flash, audio, camera effects | Planned |
| 7 — First Art Pass | Character, weapon model, environment, materials, lighting, first map | Planned |
| 8 — UI | Main menu, HUD, scoreboard, settings | Planned |
| 9 — Multiplayer | Networking, player sync, 2-8 player scaling | Planned |
| 10 — Content | Additional weapons, maps, skins, progression | Planned |

---

## Next Planned Task: Milestone 3 — Combat Loop

Prerequisites: Milestone 2 playtested and weapon feel approved.

Scope:
1. HealthSystem (Node autoload or CharacterBody3D component)
2. DamageSystem (receive damage, apply headshot multiplier)
3. Player death and respawn
4. Simple kill/score tracking
5. Basic bot or dummy target to shoot

Do not begin until weapon feel is confirmed.
