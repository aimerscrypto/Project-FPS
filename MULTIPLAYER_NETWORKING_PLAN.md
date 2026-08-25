# Project FPS — Multiplayer Readiness Audit & Networking Architecture Plan

**Document Version:** 1.0  
**Target Engine:** Godot 4.7.1 (GL Compatibility / Jolt Physics)  
**Scope:** Complete Architecture Audit, Authority Modeling, Synchronization Strategy & Phased Implementation Plan  
**Status:** Architectural Plan Only (Zero Production Code Changes Applied)

---

## 1. Executive Summary & Current Architecture Overview

Project FPS is currently built as a high-fidelity single-player / local-client first-person shooter featuring 12 playable weapons, damped harmonic recoil, procedural ADS / bobbing / sway, bot combat AI with Last-Known-Position (LKP) memory, dynamic multi-factor spawn selection, spatial audio, and zero-allocation pooled combat VFX.

The game is structured around three primary pillars:
1. **Kinematic Controller & Viewmodel Presentation:** `scripts/player/player_controller.gd` manages character physics (walk, sprint, crouch, slide, jump), mouse look, camera recoil, and delegates input to weapons mounted under `CameraMount/Camera3D`.
2. **Unified Weapon System:** `scripts/weapons/weapon_base.gd` executes firing rates, ammo tracking, local hitscan raycasts, damage dispatch, and procedural visual animations for all 12 weapons extracted from `assets/models/12_low_poly_guns.glb`.
3. **Gameplay & Combat Infrastructure:** `scripts/gameplay/match_manager.gd`, `scripts/systems/health.gd`, and `scripts/enemies/basic_bot.gd` handle the Free-For-All (FFA) match lifecycle, damage application, health pools, respawning, and scoreboard tracking.

### Readiness Verdict
- **Multiplayer Foundation:** Currently `0%` networked. The codebase contains no existing networking code, RPCs, or synchronizer nodes.
- **Architectural Modularity:** Very high. Combat systems (Health, DamageInfo, MatchManager, WeaponData) are already loosely coupled via signals and structured data classes.
- **Key Refactoring Needed:** Decoupling local input/camera/HUD from the player entity, moving hitscan validation and damage authority to the server, making MatchManager the authoritative match host, and implementing server-authoritative bot simulation.

---

## 2. Player Architecture Audit

### 2.1 File & Node Breakdown
- **Scene:** `scenes/player/player.tscn` (`CharacterBody3D`)
  - `Health` (`scripts/systems/health.gd`)
  - `CollisionShape3D` (Capsule: $r=0.4\text{m}, h=1.8\text{m}$)
  - `CameraMount/Camera3D` (Contains all 12 weapon instances as children)
  - `CrosshairHUD` (`scenes/ui/crosshair.tscn`)
  - `CombatHUD` (`scenes/ui/combat_hud.tscn`)

### 2.2 Local-Only vs. Networked Responsibilities

| Responsibility Category | Sub-System / Feature | Local Player (Authority) | Remote Player Proxy | Server (Dedicated / Host) |
|---|---|:---:|:---:|:---:|
| **Input & Control** | Keyboard/Mouse Capture | Active (`Input.MOUSE_MODE_CAPTURED`) | Disabled | Disabled |
| | Input Polling (`_input`, `_unhandled_input`) | Active | Disabled | Receives Input RPC / State |
| **Optics & View** | `Camera3D` (`current = true`) | Enabled | Disabled (`current = false`) | Disabled (Headless) |
| | First-Person Viewmodel (`CameraMount`) | Visible & Processing | Hidden / Removed | Not Instantiated |
| | Camera Recoil, Shake & Damage Flinch | Local client-side | Disabled | Disabled |
| | ADS Camera FOV Zoom & Scope Overlay | Active | Disabled | Disabled |
| **HUD & UI** | `CombatHUD` (HP bar, ammo counter, death screen) | Active | Disabled / Removed | Disabled |
| | `CrosshairHUD` & Dynamic Hitmarkers | Active | Disabled / Removed | Disabled |
| **Audio** | 2D UI & First-Person Weapon SFX | Played locally | Disabled | Disabled |
| | 3D Spatial Footsteps & Reload Audio | Dispatched locally | Played via 3D audio | Broadcast / Replicated |
| **Kinematics** | Position & Velocity | Predicted locally | Interpolated from server | Authoritative state |
| | Rotation (Yaw & Pitch) | Yaw: Body, Pitch: Camera | Yaw: Body, Pitch: Replicated | Stored for hit validation |
| | State (Crouch / Sprint / Slide / Air) | Predicted locally | Replicated via bitflags | Authoritative validation |
| **Combat State** | Health Pool & Spawn Protection | Client display only | Client display only | Authoritative computation |
| | Weapon Inventory Slot Index | Client predicts switch | Replicated to show 3rd-person gun | Authoritative validation |
| | Death & Respawn Lifecycle | Triggers local death FX | Triggers ragdoll / death FX | Authoritative execution |

### 2.3 Property Authority Matrix

| Property | Authority Model | Synchronization Method |
|---|---|---|
| Global Position | Predicted Client + Server Validated | Unreliable Delta / Sync |
| Global Yaw (Look Y) | Client Authoritative (Input) | Unreliable Delta / Sync |
| Camera Pitch (Look X) | Client Authoritative (Input) | Unreliable Delta / Sync |
| Stance (Crouch/Sprint) | Predicted Client + Server Validated | Property Synchronizer |
| Velocity | Client Simulated + Server Corrected | Unreliable Delta / Sync |
| Active Weapon Slot | Client Request + Server Validated | Reliable RPC / Sync |
| Current / Reserve Ammo | Server Authoritative | Reliable State RPC/Sync |
| Health / Max Health | Server Authoritative | Reliable State RPC/Sync |
| Is Spawn Protected | Server Authoritative | Reliable State RPC/Sync |
| Is Dead | Server Authoritative | Reliable Event RPC |
| Kill / Death Counts | Server Authoritative | Server Match RPC |

---

## 3. Input Architecture Audit

### 3.1 InputMap & Action Audit

| Action Name | Default Binding | Current Singleplayer Behavior | Multiplayer Handling & Network Flow |
|---|---|---|---|
| `move_forward` | `W` | Calculates target ground velocity in `_physics_process` | Sampled locally each tick; sent to server in UserInput payload. |
| `move_backward` | `S` | Calculates target ground velocity in `_physics_process` | Sampled locally each tick; sent to server in UserInput payload. |
| `move_left` | `A` | Calculates target ground velocity in `_physics_process` | Sampled locally each tick; sent to server in UserInput payload. |
| `move_right` | `D` | Calculates target ground velocity in `_physics_process` | Sampled locally each tick; sent to server in UserInput payload. |
| `jump` | `Space` | Applies `JUMP_VELOCITY = 7.5` if `is_on_floor()` | Predicted locally; button bitflag sent in UserInput payload. |
| `sprint` | `Shift` | Toggles `MoveState.SPRINT` (`10.0 m/s`) | Predicted locally; stance bitflag sent in UserInput payload. |
| `crouch` | `Ctrl` | Shrinks capsule to 1.0m / initiates slide | Predicted locally; stance bitflag sent in UserInput payload. |
| `fire_primary` | `Left Mouse` | Direct call to `_active_weapon.try_fire()` | Local visual/audio prediction; sends `request_fire` RPC to server. |
| `aim` (ADS) | `Right Mouse` | Toggles `_is_aiming`, lerps camera FOV & sightline | Purely local visual/sens state; replicated as aim bitflag for third-person stance. |
| `reload` | `R` | Calls `_active_weapon.try_reload()` | Local reload animation predicted; sends `request_reload` RPC to server. |
| `weapon_next` | `Wheel Down` | Increments slot index `(slot + 1) % 12` | Predicted locally; sends `request_switch_weapon(slot)` RPC to server. |
| `weapon_prev` | `Wheel Up` | Decrements slot index `(slot - 1 + 12) % 12` | Predicted locally; sends `request_switch_weapon(slot)` RPC to server. |
| `weapon_slot_1..12` | Keys `1..9`, `0`, `-`, `=` | Selects specific weapon slot 0..11 | Predicted locally; sends `request_switch_weapon(slot)` RPC to server. |
| `show_scoreboard` | `Tab` | Displays MatchManager scoreboard overlay | Purely local UI query; reads synchronized scoreboard cache. |
| `refill_ammo` | `F3` | Debug refills ammo for all weapons | Disabled in production multiplayer builds (Server-admin command only). |

### 3.2 Input Encapsulation Strategy
Currently, `player_controller.gd` polls `Input.is_action_pressed()` directly in `_physics_process` and `_handle_movement`.  
**Required Refactor:**
1. Isolate input sampling into a dedicated `PlayerInput` structure:
   ```gdscript
   struct UserCommand:
       var tick: int
       var move_vec: Vector2
       var look_pitch: float
       var look_yaw: float
       var buttons: int # Bitflags: JUMP, SPRINT, CROUCH, ADS, FIRE
   ```
2. When running on remote proxies or headless server, the character ignores local `Input` and executes movement from the latest verified `UserCommand`.

---

## 4. Weapon Architecture Audit

### 4.1 Hierarchy & System Design
- **Base Class:** `scripts/weapons/weapon_base.gd`
- **Base Scene:** `scenes/weapons/weapon_base.tscn`
- **Data Definition:** `scripts/weapons/weapon_data.gd`
- **Visual Subtree Extractor:** `scripts/weapons/weapon_visual.gd` (isolates meshes directly from `12_low_poly_guns.glb`)

### 4.2 Local Presentation vs. Network Gameplay Separation

1. **Local Presentation (Shooter Client Only):**
   - Damped harmonic spring camera recoil (`scripts/weapons/weapon_base.gd:790-820`)
   - Procedural viewmodel sway, breathing bob, and ADS eye alignment (`scripts/weapons/weapon_base.gd:937-970`)
   - Immediate 2D audio gunshot dispatch (`scripts/weapons/weapon_base.gd:470-495`)
   - Local brass casing ejection (`CasingManager.spawn_casing`)
   - Predictive ammo counter decrement on `CombatHUD`

2. **Network Gameplay (Server Authoritative):**
   - Verification of inter-shot delay ($\Delta t \ge rac{1}{	ext{fire\_rate}} - \epsilon$)
   - Authoritative magazine ammo decrement and reload state machine
   - Execution of hitscan collision queries on authoritative physics space state
   - Hit validation, headshot multiplier application ($2.0	imes$), and damage assignment
   - Spawning of replicated cosmetic events (tracers, impact sparks, elimination bursts)

---

## 5. Hitscan and Damage Flow Audit

### 5.1 Current Singleplayer Code Path
```text
[Input.is_action_pressed("fire_primary")]
  ↳ player_controller.gd:_physics_process()
    ↳ _active_weapon.try_fire()
      ↳ weapon_base.gd:try_fire()
        ↳ weapon_base.gd:_fire()
          ↳ weapon_base.gd:_do_hitscan()
            ↳ _raycast.force_raycast_update()
              ↳ _raycast.get_collider()
                ↳ headshot check (collider.is_in_group("head"))
                ↳ DamageInfo constructed
                ↳ target.take_damage(DamageInfo) / Health.take_damage()
                  ↳ Health.current_health -= final_damage
                  ↳ Health.damage_received.emit()
                  ↳ if current_health <= 0: Health.die(attacker)
                    ↳ MatchManager.record_kill(killer, victim)
```

### 5.2 Required Online Architecture Refactor
In singleplayer, the local camera's `RayCast3D` immediately evaluates collisions and directly mutates the target's `Health` component. In multiplayer:
1. **The Client NEVER directly calls `take_damage()` on another entity.**
2. **The Client sends an authoritative request:**
   ```gdscript
   @rpc("any_peer", "call_local", "reliable")
   func request_fire(origin: Vector3, direction: Vector3, client_timestamp: int) -> void
   ```
3. **The Server performs the physics query:**
   The server constructs a `PhysicsRayQueryParameters3D` starting from the server's authoritative player head/muzzle position along the validated aim vector.
4. **Damage Calculation & Application:**
   The server computes base damage, range falloff, and headshot detection (using collision layer 3 for head hitboxes and layer 2 for torso/limbs).
5. **State Broadcast:**
   The server decrements `Health.current_health`, which automatically replicates down to all clients. If HP $\le 0$, the server invokes `MatchManager.record_kill()` and broadcasts player death.

---

## 6. Bot Architecture Audit

### 6.1 Current Bot Architecture (`scripts/enemies/basic_bot.gd`)
- Features a complete autonomous Finite State Machine (`SEARCH`, `CHASE`, `ATTACK`, `INVESTIGATE`, `COVER`, `DEAD`).
- Computes cone-based visual perception (`FOV = 115°`), hearing checks (`3.5m`), and target stickiness.
- Drives navigation via `NavigationAgent3D` on runtime baked navmesh (`scripts/maps/test_arena.gd`).
- Fires its own hitscan weapon cycle with spread and reload pauses.

### 6.2 Multiplayer Strategy for Bots
1. **Strict Server Authority:**
   - Bots run **100% on the Server / Host**.
   - Clients do **NOT** process bot AI, navigation pathfinding, or target perception.
2. **Client Bot Proxy Representation:**
   - Clients treat bots identically to remote human players: they receive replicated transform, animation stance, health, and firing RPCs.
3. **Audit of Single-Player Assumptions:**
   - **Assumption Found:** `_score_target()` and `_find_best_target()` in `basic_bot.gd:470-520` already iterate across all nodes in group `"combatants"`. This is **already FFA multiplayer compatible**!
   - **Assumption Found:** `respawn()` in `basic_bot.gd:715-745` queries `MatchManager.get_spawn_point()`. In multiplayer, the server executes this query and syncs the new bot position.

---

## 7. MatchManager & Game Loop Audit

### 7.1 Current System State (`scripts/gameplay/match_manager.gd`)
- Tracks match states: `WAITING`, `STAGING` (3-second countdown), `PLAYING`, `ENDED`.
- Manages 5:00 countdown timer, kill limit (25 kills), and live scoreboard dictionary `_combatant_stats`.
- Features dynamic multi-factor spawn point selection: evaluates enemy distance, density, LOS occlusions, and death position history (`match_manager.gd:375-485`).

### 7.2 Multiplayer Authority Design
1. **Match Lifecycle Authority:**
   - Only the server ticks `time_remaining` and changes `state`.
   - The server syncs timer updates at 1 Hz intervals (and every tick during the 3-second staging countdown).
2. **Authoritative Scoreboard:**
   - When a kill occurs on the server, `record_kill()` executes and broadcasts a lightweight RPC:
     ```gdscript
     @rpc("authority", "call_local", "reliable")
     func sync_kill_event(killer_peer_id: int, victim_peer_id: int, killer_score: int, victim_deaths: int)
     ```
3. **Safe Spawning:**
   - When a client connects or respawns, the server computes `get_spawn_point()` using the authoritative positions of all active combatants and sends the assigned spawn transform to the client.

---

## 8. Scene & World Hierarchy Audit

### 8.1 Recommended Multiplayer Scene Architecture
To cleanly support dynamic player joining, host migration readiness, and UI overlays:

```text
GameRoot (Scene Root / Main)
├── NetworkManager (AutoLoad / Core Coordinator)
├── UI_Layer (CanvasLayer)
│   ├── MainMenu / LobbyUI (Host / Join / Server Browser)
│   ├── InGameHUD (Mounted dynamically for local player)
│   └── ScoreboardOverlay
└── World (Node3D)
    ├── MatchManager (Server authoritative match logic)
    ├── Map (Loaded arena, e.g., TestArena)
    │   ├── Geometry & Lighting
    │   ├── Spawns (SpawnPoint_1..10)
    │   ├── Pickups
    │   └── NavigationRegion3D
    ├── PlayersContainer (MultiplayerSpawner targets this path)
    │   ├── Player_1 (Host / Peer 1)
    │   ├── Player_18294812 (Client Peer)
    │   └── ...
    └── BotsContainer (Server spawns and replicates bots)
        ├── Bot_1
        └── ...
```

---

## 9. Existing Networking Code Audit

A full search across all project files for `MultiplayerAPI`, `ENetMultiplayerPeer`, `@rpc`, `set_multiplayer_authority`, `MultiplayerSpawner`, and `MultiplayerSynchronizer` confirms:

- **Existing Networking Code:** None (`0` occurrences).
- **Advantage:** Clean slate. There is no legacy or deprecated networking code to refactor, no conflicting multiplayer addons, and no tech debt in network serialization.
- **Compatibility:** The codebase is in a pristine state to adopt Godot 4.7.1 native high-level multiplayer standards (`ENetMultiplayerPeer`, `MultiplayerSpawner`, `MultiplayerSynchronizer`, and typed RPCs).

---

## 10. Comprehensive Architectural Problems & Risk Catalog

| ID | Issue Description | Severity | Impact on Multiplayer | Required Refactoring Solution |
|---|---|:---:|---|---|
| **NET-01** | `player.tscn` contains hardcoded `Camera3D` with `current = true` and UI canvas layers. | `CRITICAL` | Every connected peer instantiating `player.tscn` would activate their own camera and stack HUDs on top of each other. | In `_ready()`, check `is_multiplayer_authority()`. If false, remove/disable `Camera3D`, `AudioListener3D`, `CombatHUD`, and `CrosshairHUD`. |
| **NET-02** | Client-side hitscan and damage application in `weapon_base.gd:507-613`. | `CRITICAL` | Unprotected from client hacking, desyncs, and duplicate damage assignment. | Route weapon fire requests through server-validated RPCs; execute authoritative hitscan on server. |
| **NET-03** | Local `player.tscn` is hardcoded as a static node in `test_arena.tscn`. | `CRITICAL` | Game opens with a hardcoded single player rather than dynamically spawning players on connect. | Remove static Player node from arena scene; utilize `MultiplayerSpawner` to spawn players into `PlayersContainer` upon peer connection. |
| **NET-04** | Input polling running globally in `player_controller.gd:_physics_process()`. | `CRITICAL` | Local keyboard/mouse inputs would control all player instances spawned in the scene. | Wrap all input gathering and processing inside `if not is_multiplayer_authority(): return`. |
| **NET-05** | `MatchManager` auto-starts in `_ready()` and operates client-side (`match_manager.gd:59-67`). | `HIGH` | Each client would run their own timer and declare victory independently. | Restrict match state changes and timer ticking to `multiplayer.is_server()`; sync state to clients via RPC/Synchronizer. |
| **NET-06** | Pickups consume and heal via direct local collision (`pickup.gd:60-109`). | `HIGH` | Multiple clients touching a pickup simultaneously would trigger duplicate heals and desynced cooldowns. | Make pickup trigger server-authoritative; server disables pickup visual and broadcasts collection event. |
| **NET-07** | `AudioManager` 2D UI cues and global triggers. | `MEDIUM` | Sound effects like kill confirms, respawns, and hits could play globally or trigger on wrong peers. | Ensure 2D sound cues (hitmarkers, kill confirm chimes) only play for the authoritative local shooter; use 3D spatial audio for world actions. |
| **NET-08** | Lack of 3rd-person player visual representation. | `MEDIUM` | Remote players would be invisible because weapon models are currently mounted under first-person `CameraMount/Camera3D`. | Add a proxy third-person avatar mesh and weapon mount to `player.tscn` that is visible to remote clients (and hidden from local player). |
| **NET-09** | Deterministic spread calculation using unseeded `randf()`. | `LOW` | Bullet spread pattern on client prediction won't match server raycast. | Server generates authoritative shot direction; client shows cosmetic tracer toward predicted point with visual smoothing. |

---

## 11. Core Networking Architecture Design

### 11.1 Transport Layer & Backend
- **Recommended Backend:** `ENetMultiplayerPeer`
- **Rationale:**
  - Standard, battle-tested UDP transport built natively into Godot 4.7.1.
  - Low latency, lightweight packet framing, and built-in channel support for reliable vs. unreliable messages.
  - Ideal for LAN and direct-IP testing, easily extendable to Steam Datagram Relay (SDR) or WebRTC in later phases.
- **Port:** Default `7777` UDP.

### 11.2 Authority Architecture
```text
                    [DEDICATED SERVER / HOST]
                    - Match State & Timer
                    - Combatant Scoreboard & Kill Events
                    - Dynamic Spawn Point Allocation
                    - Authoritative Hitscan & Damage
                    - Authoritative Health & Death
                    - Bot Simulation (AI / Navigation)
                    - Pickup Timers & Validation
                               |
            +------------------+------------------+
            |                                     |
    [LOCAL CLIENT 1]                      [LOCAL CLIENT 2]
    - Local Input & Mouse Look            - Local Input & Mouse Look
    - Kinematic Prediction                - Kinematic Prediction
    - Camera & Spring Recoil              - Camera & Spring Recoil
    - Weapon Audio & Viewmodel            - Weapon Audio & Viewmodel
    - Local HUD & Crosshair               - Local HUD & Crosshair
```

### 11.3 RPC & Channel Topology

| RPC Method | Caller | Target | Transfer Mode | Channel | Purpose |
|---|---|---|---|:---:|---|
| `send_input_command(cmd)` | Client | Server | `UNRELIABLE_ORDERED` | `0` | Streams client movement and look vectors every physics tick. |
| `sync_player_state(state)` | Server | Clients | `UNRELIABLE_ORDERED` | `0` | Streams authoritative positions, velocities, and rotation. |
| `request_fire(origin, dir, seed)` | Client | Server | `RELIABLE` | `1` | Requests a weapon discharge. |
| `weapon_fired_broadcast(peer_id, slot, origin, dir)` | Server | Clients | `UNRELIABLE` | `1` | Triggers cosmetic 3D tracers, muzzle flashes, and spatial gunshot sounds on remote proxies. |
| `request_reload()` | Client | Server | `RELIABLE` | `1` | Initiates weapon reload. |
| `request_switch_weapon(slot)` | Client | Server | `RELIABLE` | `1` | Requests weapon slot switch. |
| `hit_confirmed(is_headshot, is_kill)` | Server | Shooter Client | `RELIABLE` | `1` | Triggers 2D hitmarker and kill confirm chime on the shooter's screen. |
| `sync_match_state(state, time, scores)` | Server | Clients | `RELIABLE` | `2` | Synchronizes match timer, staging countdown, and scoreboard. |
| `combatant_killed(killer_id, victim_id)` | Server | Clients | `RELIABLE` | `2` | Broadcasts elimination killfeed event. |
| `respawn_player(peer_id, spawn_trans)` | Server | Clients | `RELIABLE` | `2` | Resets player health, position, and active weapon state. |

---

## 12. Player Synchronization Design

### 12.1 Local Player (Autonomous Proxy)
1. **Immediate Local Physics:** The local player samples keyboard/mouse input and executes `move_and_slide()` immediately in `_physics_process()`. No input delay is introduced.
2. **Input History Buffer:** The client retains a ring buffer of recent inputs and resulting states (last 64 ticks).
3. **Server Reconciliation:** When the server sends an authoritative state packet, if the server position diverges beyond a threshold ($\Delta > 0.08	ext{m}$), the client snaps to the verified position and re-simulates unacknowledged inputs.

### 12.2 Remote Player (Simulated Proxy)
1. **Snapshots & Jitter Buffer:** Remote players receive position/yaw updates at the server tick rate ($30	ext{ Hz}$ or $60	ext{ Hz}$) and store them in an interpolation buffer.
2. **Hermite / Spherical Linear Interpolation:** Remote proxies render $50	ext{ms} - 100	ext{ms}$ in the past, smoothly interpolating position and body yaw between received snapshots.
3. **Stance Animation:** Bitflags for crouch, sprint, and jump trigger corresponding proxy visual height transitions.

---

## 13. Shooting & Hit Validation Synchronization

### 13.1 Step-by-Step Server-Authoritative Firing Pipeline

1. **Client Prediction:**
   - When the user presses `fire_primary`, the client immediately checks its local fire timer and ammo counter.
   - If valid, the client immediately plays local first-person muzzle flash, spring recoil kick, and 2D gunshot audio.
   - The client sends `request_fire(origin, direction, client_timestamp)` to the server via reliable RPC.

2. **Server Rate-of-Fire & Ammo Validation:**
   - Server checks if the player is alive and not spawn-protected.
   - Server checks if $	ext{current\_time} - 	ext{last\_shot\_time} \ge rac{1}{	ext{fire\_rate}} - 0.015	ext{s}$.
   - Server verifies `_current_ammo > 0` and decrements ammo.

3. **Authoritative Raycast Execution (Phase 1 Baseline):**
   - For Phase 1 & 2, the server performs the hitscan raycast in real-time server physics space (without backward reconciliation).
   - Raycast originates from the authoritative server player head position along the validated direction vector.
   - If collision occurs with a combatant:
     - Check headshot group / collider layer.
     - Calculate damage: $	ext{damage} = 	ext{base\_damage} 	imes 	ext{headshot\_mult}$.
     - Apply damage to target's `Health` component.
     - Send `hit_confirmed.rpc_id(shooter_peer_id, is_headshot, is_kill)` back to the shooter.

4. **Cosmetic Broadcast:**
   - Server broadcasts `weapon_fired_broadcast` to all other clients to spawn 3D visual tracers, remote muzzle flashes, and spatial 3D audio.

---

## 14. Spawn, Death & Respawn Lifecycle Design

1. **Connection & Initial Spawning:**
   - Client connects via `ENetMultiplayerPeer`.
   - Server detects `peer_connected(peer_id)`.
   - Server calls `MatchManager.get_spawn_point(new_player)` to find the safest spawn.
   - Server `MultiplayerSpawner` instantiates `player.tscn` under `PlayersContainer` and calls `set_multiplayer_authority(peer_id)`.
   - The entity is replicated to all peers automatically.

2. **Combat & Death:**
   - When `Health.current_health` reaches 0.0 on the server, the server calls `MatchManager.record_kill(killer_node, victim_node)`.
   - Server broadcasts `combatant_killed` RPC to all peers.
   - Victim client triggers local death camera tilt and displays death banner.
   - Server disables victim collision and hides proxy visual.

3. **Authoritative Respawn Cycle (2.5s):**
   - Server starts a 2.5s timer.
   - On timeout, server computes optimal spawn point via `MatchManager.get_spawn_point(victim_node)`.
   - Server restores 100 HP, enables 1.2s spawn protection, and resets global transform.
   - Server broadcasts `respawn_player` RPC to all peers.
   - Local client resets camera, re-enables HUD, and plays respawn sound.

---

## 15. Phased Implementation Roadmap

### Phase 1: Networking Core & Player Spawning
- `NetworkManager.gd` AutoLoad (Host/Join/Disconnect logic).
- `MultiplayerSpawner` and dynamic `PlayersContainer` setup in Arena.
- Authority separation in `player.tscn` (disable remote cameras, audio listeners, and HUDs).

### Phase 2: Kinematic Replication & Remote Proxies
- Position/Rotation/Velocity replication via `MultiplayerSynchronizer`.
- Proxy interpolation and stance bitflags (Crouch, Sprint, Jump).
- Third-person proxy representation & active weapon mesh mounting.

### Phase 3: Authoritative Weapons & Firing Pipeline
- Weapon fire/reload/switch RPCs.
- Server fire-rate and ammo validation.
- Replicated 3D bullet tracers, muzzle VFX, and 3D spatial gunshot audio.

### Phase 4: Server Combat, Damage & Health
- Server-authoritative hitscan raycasting.
- Health state synchronization and damage event routing.
- 2D Hitmarker and kill confirm RPC dispatch to shooter.

### Phase 5: MatchManager, FFA Gameloop & Server Bots
- Server-authoritative MatchManager (Timer, Staging, Kill limit, Winner).
- Replicated live scoreboard and accolades.
- Server-only execution of BasicBot AI and kinematic synchronization.
- Server-authoritative Pickup items and respawn timers.

### Phase 6: Networking Polish, Jitter Buffering & Stress Testing
- Network snapshot interpolation tuning.
- Graceful peer disconnection and timeout handling.
- Artificial lag/packet loss simulation and test suite validation.

---

## 16. Detailed Phase Breakdown & File Impact Matrix

### 16.1 Files Requiring Modification per Phase

| File | Phase | Modification Purpose |
|---|:---:|---|
| `project.godot` | 1 | Register `NetworkManager` as an Autoload singleton. |
| `scripts/player/player_controller.gd` | 1, 2 | Add authority checks (`is_multiplayer_authority()`); disable camera/HUD for proxies; serialize user inputs. |
| `scenes/player/player.tscn` | 1, 2 | Add `MultiplayerSynchronizer` node; separate first-person viewmodel from proxy visuals. |
| `scripts/weapons/weapon_base.gd` | 3, 4 | Convert `_do_hitscan()` into server-authoritative firing RPCs; route damage via server. |
| `scripts/systems/health.gd` | 4 | Enforce server authority on `take_damage()`, `die()`, and `respawn()`; replicate HP. |
| `scripts/gameplay/match_manager.gd` | 5 | Restrict match clock, state transitions, and spawn calculations to server; sync scores via RPC. |
| `scripts/enemies/basic_bot.gd` | 5 | Restrict AI processing and pathfinding to `multiplayer.is_server()`; sync kinematics to clients. |
| `scripts/gameplay/pickup.gd` | 5 | Make pickup trigger and cooldown timer server-authoritative. |
| `scenes/maps/test_arena.tscn` | 1, 5 | Remove hardcoded singleplayer Player node; add `MultiplayerSpawner` and `PlayersContainer`. |

### 16.2 Files That Must NOT Be Modified (Protected Assets)

| File / Directory | Reason for Strict Protection |
|---|---|
| `assets/models/12_low_poly_guns.glb` | Master immutable weapon asset (12-gun source). Must NEVER be edited, overwritten, or re-exported. |
| `scenes/weapons/*_visual.tscn` (All 12) | Verified visual mesh extraction subtrees. Already mathematically calibrated to dead center. |
| `data/weapons/*.tres` (All 12) | Core gameplay weapon data resources (damage, rate of fire, recoil curves, spread angles). |
| `scripts/weapons/weapon_visual.gd` | Dynamic glTF node extraction and isolation engine. |

---

## 17. Comprehensive Testing & Validation Strategy

### 17.1 Single-Machine Multi-Instance Testing
Godot 4 allows launching multiple debug instances simultaneously from CLI or editor debug settings:
1. **Instance 1 (Host / Server):**
   ```bash
   godot -- --server --port=7777
   ```
2. **Instance 2 (Client 1):**
   ```bash
   godot -- --client=127.0.0.1 --port=7777
   ```
3. **Instance 3 (Client 2):**
   ```bash
   godot -- --client=127.0.0.1 --port=7777
   ```

### 17.2 Automated Headless Verification Suite
Create dedicated test scripts under `test/` verifying network synchronization:
- `test/test_multiplayer_connection.gd`: Verifies ENet peer connection, peer ID assignment, and disconnection cleanup.
- `test/test_multiplayer_spawning.gd`: Asserts that `MultiplayerSpawner` instantiates exact player entities per connected peer without duplicates.
- `test/test_authoritative_combat.gd`: Simulates a client `request_fire` RPC and verifies that damage is only applied on the server and accurately broadcasted to targets.
- `test/test_match_sync.gd`: Verifies that client scoreboard and match timer mirror server MatchManager state precisely.

### 17.3 Latency & Packet Loss Stress Testing
Utilize Godot's built-in simulation tools to test network resilience:
- Simulate $50\text{ms}$, $100\text{ms}$, and $200\text{ms}$ artificial round-trip ping.
- Simulate $2\% - 5\%$ packet loss on unreliable movement channels to confirm Hermite interpolation smoothing without rubber-banding.

---

## 18. Final Architectural Summary

| Category | Status / Strategy |
|---|---|
| **What is Already Multiplayer-Ready** | Decoupled health component, DamageInfo data structure, 12 weapon data resources, FFA scoring logic, multi-target bot scoring algorithm, dynamic spawn point selection formula. |
| **What Must Be Refactored** | Node authority gating in `player.tscn` (disable remote cameras/HUDs), converting hitscan raycasting from local client to server-authoritative RPCs, making MatchManager match clock and bot AI server-only. |
| **First Implementation Milestone (Phase 1)** | Create `NetworkManager.gd`, build simple Host/Join lobby UI, add `MultiplayerSpawner` to arena, and achieve two connected clients moving independently in the 3D space with camera authority isolation. |
| **Identified Risks & Mitigations** | **Risk:** High fire-rate weapons (Kriss Vector: 20 RPS) spamming RPCs.  <br>**Mitigation:** Group continuous automatic fire requests into stream ticks or start/stop firing state flags rather than discrete individual RPCs per bullet. |
