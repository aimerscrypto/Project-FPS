# Project FPS — Development Status

**Last Updated:** 2026-08-15
**Current Milestone:** Milestone 1 — FPS Movement (IN PROGRESS — implementation complete, awaiting playtest)

---

## Current Project State

Milestone 1 implementation created. Requires playtest verification in Godot editor.
No gameplay systems beyond movement. No weapons, health, bots, or multiplayer.

---

## What Was Inspected (Milestone 0)

### Files found at inspection time

| File / Folder | Notes |
|---|---|
| `project.godot` | Godot 4.7, Compatibility renderer, Jolt Physics, D3D12 on Windows |
| `Project FPS — Game Bible v1.0.md` | Full 46-section game design document — authoritative spec |
| `icon.svg` + `icon.svg.import` | Default Godot project icon |
| `.gitignore` | Correctly ignores `.godot/` and `/android/` |
| `.gitattributes` | LF normalization configured |
| `.editorconfig` | UTF-8 charset configured |
| `.godot/` | Standard Godot editor cache only — no scenes, scripts, or assets |

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
|   +-- models/
|   |   +-- player/
|   |   +-- weapons/
|   |   +-- enemies/
|   |   +-- environment/
|   +-- materials/
|   +-- textures/
|   +-- animations/
|   |   +-- player/
|   |   +-- weapons/
|   +-- audio/
|   |   +-- weapons/
|   |   +-- player/
|   |   +-- combat/
|   |   +-- ui/
|   |   +-- environment/
|   +-- vfx/
+-- scenes/
|   +-- player/
|   |   +-- player.tscn          [NEW - Milestone 1]
|   +-- weapons/
|   +-- enemies/
|   +-- maps/
|   |   +-- test_arena.tscn      [NEW - Milestone 1]
|   +-- ui/
|   +-- gameplay/
+-- scripts/
|   +-- player/
|   |   +-- player_controller.gd [NEW - Milestone 1]
|   +-- weapons/
|   +-- enemies/
|   +-- gameplay/
|   +-- systems/
|   +-- ui/
+-- data/
    +-- weapons/
    +-- characters/
    +-- maps/
    +-- configuration/
```

### Input Actions (configured in project.godot)

| Action | Binding |
|---|---|
| `move_forward` | W |
| `move_backward` | S |
| `move_left` | A |
| `move_right` | D |
| `jump` | Space |
| `sprint` | Left Shift |
| `crouch` | Left Ctrl |
| `fire_primary` | Left Mouse Button |
| `aim` | Right Mouse Button |
| `reload` | R |
| `weapon_next` | Scroll Up |
| `weapon_prev` | Scroll Down |
| `weapon_slot_1` | 1 |
| `weapon_slot_2` | 2 |

### Implemented Systems

| System | File | Status |
|---|---|---|
| PlayerController | `scripts/player/player_controller.gd` | Implemented — needs playtest |
| Test Arena | `scenes/maps/test_arena.tscn` | Implemented — needs playtest |
| Player Scene | `scenes/player/player.tscn` | Implemented — needs playtest |

### Planned Modular Systems (NOT yet implemented)

- MovementSystem (currently embedded in PlayerController — may be separated later)
- CameraSystem
- WeaponSystem
- HealthSystem
- DamageSystem
- BotSystem
- MatchSystem
- SpawnSystem
- UI
- AudioSystem
- VFXSystem

---

## Milestone 1 — Implementation Summary

### player_controller.gd — Movement Constants

| Constant | Value | Description |
|---|---|---|
| `WALK_SPEED` | 7.0 m/s | Normal movement |
| `SPRINT_SPEED` | 10.0 m/s | Sprinting |
| `CROUCH_SPEED` | 3.5 m/s | Crouching |
| `SLIDE_SPEED_START` | 13.0 m/s | Initial slide launch velocity |
| `SLIDE_SPEED_MIN` | 3.0 m/s | Slide ends below this speed |
| `SLIDE_FRICTION` | 4.0 m/s^2 | Slide deceleration |
| `ACCEL_GROUND` | 30.0 m/s^2 | Ground acceleration |
| `DECEL_GROUND` | 25.0 m/s^2 | Ground deceleration |
| `ACCEL_AIR` | 8.0 m/s^2 | Air acceleration |
| `DECEL_AIR` | 4.0 m/s^2 | Air friction |
| `JUMP_VELOCITY` | 7.5 m/s | Jump launch velocity |
| `GRAVITY` | 20.0 m/s^2 | Downward acceleration |
| `MOUSE_SENSITIVITY` | 0.002 rad/px | Mouse look sensitivity |
| `HEIGHT_STAND` | 1.8 m | Standing capsule height |
| `HEIGHT_CROUCH` | 1.0 m | Crouching capsule height |

### Movement State Machine

States: WALK, SPRINT, CROUCH, SLIDE, AIR

Transitions:
- WALK -> SPRINT: shift held + moving
- WALK/SPRINT -> CROUCH: ctrl held (not sliding)
- SPRINT -> SLIDE: shift + ctrl + moving
- SLIDE -> CROUCH: slide speed drops / ctrl still held
- SLIDE -> WALK: slide speed drops / ctrl released
- Any ground -> AIR: jump or fall
- AIR -> WALK: land on floor

### test_arena.tscn — Layout

- 40x40m floor
- 4 boundary walls (height 4m)
- 5 cover blocks (2x1.5x2m, flat-colored)
- 1 ramp (tilted ~15 degrees, for slide/jump testing)
- 1 elevated platform (8x8m at height 3m, jump destination)
- WorldEnvironment with procedural sky
- DirectionalLight3D with shadows

---

## Playtest Checklist (Required Before Marking Milestone 1 Complete)

- [ ] Test arena loads without errors
- [ ] Mouse look works (horizontal body rotation + vertical camera clamp)
- [ ] WASD walk works
- [ ] Sprint works (Shift)
- [ ] Jump works (Space), no double-jump
- [ ] Air control works (directional input in air)
- [ ] Crouch works (Ctrl), camera lowers
- [ ] Slide triggers (Sprint + Ctrl + moving), feels fast
- [ ] Slide ends naturally (speed drops or Ctrl released)
- [ ] Stand-under-ceiling check works (cannot stand through ceiling)
- [ ] Player cannot escape arena
- [ ] Escape key releases mouse cursor
- [ ] No clipping or jitter observed
- [ ] Movement feels arcade-fast per Game Bible section 7

---

## Known Issues / Notes

- test_arena.tscn uses StaticBody3D + BoxShape3D. MeshInstance3D meshes use BoxMesh.new()
  which creates a default 1x1x1 mesh — the collisions are correct but meshes will appear
  as unit cubes in the editor. Visual size mismatch between mesh and collision is expected
  and can be fixed by setting mesh size properties or switching to CSGBox3D in Milestone 7.
- Input actions were written by hand in project.godot. Verify in Editor > Project > Input Map.
- MOUSE_SENSITIVITY default (0.002) may need tuning per individual preference.

---

## Milestones

| Milestone | Description | Status |
|---|---|---|
| **0 — Foundation** | Project structure, input, git, docs | COMPLETE |
| **1 — Movement** | CharacterBody3D, mouse look, walk, sprint, jump, crouch, slide | IN PROGRESS |
| 2 — First Weapon | Weapon view, fire, ammo, reload, recoil, hit detection | Planned |
| 3 — Combat Loop | Health, damage, death, respawn, score | Planned |
| 4 — Bot | Navigation, targeting, combat, death, respawn | Planned |
| 5 — FFA | Multiple bots, score, timer, match end, scoreboard | Planned |
| 6 — Combat Polish | Weapon animation, hit VFX, muzzle flash, audio, camera effects | Planned |
| 7 — First Art Pass | Character, weapon model, environment, materials, lighting, first map | Planned |
| 8 — UI | Main menu, HUD, scoreboard, settings | Planned |
| 9 — Multiplayer | Networking, player sync, 2-8 player scaling | Planned |
| 10 — Content | Additional weapons, maps, skins, progression | Planned |

---

## Next Planned Task: Milestone 2 — First Weapon

### Goal

Implement a basic assault rifle in first-person view.

### Scope

1. Weapon scene attached to camera (`scenes/weapons/assault_rifle.tscn`)
2. WeaponData resource (`data/weapons/assault_rifle.tres`)
3. Hitscan fire with raycast
4. Ammo tracking
5. Reload state
6. Recoil (camera kick)
7. Basic muzzle flash particle or sprite
8. Hit detection against StaticBody3D (placeholder for future enemy health system)

### Prerequisites

Milestone 1 must be playtested and confirmed working first.
