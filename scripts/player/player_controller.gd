extends CharacterBody3D

# =============================================================================
# Project FPS — PlayerController
# Milestone 1 — Movement | Milestone 2 — Weapon input
#
# Handles: mouse look, walk, sprint, jump, air control, crouch, slide.
# Milestone 2 adds: weapon fire / reload input delegation only.
# All weapon logic lives in weapon_base.gd — not here.
#
# All tuning constants are grouped here for easy iteration during playtesting.
# =============================================================================

# -----------------------------------------------------------------------------
# MOVEMENT CONSTANTS  (tune these during playtesting)
# -----------------------------------------------------------------------------
const WALK_SPEED        : float = 7.0    # m/s — normal movement
const SPRINT_SPEED      : float = 10.0   # m/s — sprinting
const CROUCH_SPEED      : float = 3.5    # m/s — crouching
const SLIDE_SPEED_START : float = 13.0   # m/s — initial slide velocity
const SLIDE_SPEED_MIN   : float = 3.0    # m/s — slide ends below this speed
const SLIDE_FRICTION    : float = 4.0    # deceleration applied during slide (m/s²)

# Acceleration / Deceleration
const ACCEL_GROUND      : float = 30.0   # how quickly we reach target speed on ground
const DECEL_GROUND      : float = 25.0   # how quickly we stop on ground
const ACCEL_AIR         : float = 8.0    # air acceleration (lower = less responsive)
const DECEL_AIR         : float = 4.0    # air friction (lower = floatier)

# Jump / Gravity
const JUMP_VELOCITY     : float = 7.5    # upward velocity applied on jump
const GRAVITY           : float = 20.0   # m/s² downward pull

# Mouse look
const MOUSE_SENSITIVITY : float = 0.002  # radians per pixel — tune to taste
const CAMERA_PITCH_MIN  : float = -88.0  # degrees — max look down
const CAMERA_PITCH_MAX  : float = 88.0   # degrees — max look up

# Aim Down Sights (ADS)
const ADS_FOV           : float = 76.0   # degrees — zoomed FOV while aiming (default 90.0)
const ADS_SENS_MULT     : float = 0.75   # mouse sensitivity multiplier while aiming
const ADS_LERP_SPEED    : float = 14.0   # smooth transition speed into/out of ADS (~0.15s)

# Capsule heights (in metres)
const HEIGHT_STAND      : float = 1.8
const HEIGHT_CROUCH     : float = 1.0
const HEIGHT_LERP_SPEED : float = 12.0   # how fast the capsule shrinks/grows

# Eye heights are defined inside the CAPSULE HEIGHT MANAGEMENT section below.


# -----------------------------------------------------------------------------
# NODE REFERENCES — set via @onready to avoid fragile string paths
# -----------------------------------------------------------------------------
@onready var _camera_mount : Node3D          = $CameraMount
@onready var _camera       : Camera3D        = $CameraMount/Camera3D
@onready var _collision    : CollisionShape3D = $CollisionShape3D
@onready var _health       : Health          = $Health
@onready var _combat_hud   : CanvasLayer     = $CombatHUD

# Weapon references & inventory slots (Slot 0 = Assault Rifle, Slot 1 = Pistol)
@onready var _weapon_primary   : Node3D = find_child("AssaultRifle", true, false)
@onready var _weapon_secondary : Node3D = find_child("Pistol", true, false)

var _weapons           : Array[Node3D] = []
var _active_slot_index : int           = 0
var _active_weapon     : Node3D        = null


# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------
enum MoveState { WALK, SPRINT, CROUCH, SLIDE, AIR }

var _state          : MoveState = MoveState.WALK
var _is_sliding     : bool      = false
var _slide_velocity : Vector3   = Vector3.ZERO
var _is_dead        : bool      = false
var _is_match_ended : bool      = false
var _spawn_position : Vector3   = Vector3.ZERO

# ADS state
var _is_aiming      : bool      = false
var _ads_weight     : float     = 0.0
var _base_fov       : float     = 90.0

# Capsule dimensions tracked for smooth lerp
var _current_height : float = HEIGHT_STAND

# Mouse input accumulated per frame (avoids jitter from Input.get_last_mouse_velocity)
var _mouse_delta    : Vector2  = Vector2.ZERO

# Mouse look & recoil
var _mouse_pitch           : float = 0.0   # Baseline pitch from mouse look (degrees)
var _recoil_pitch          : float = 0.0   # Current upward recoil offset (degrees)
var _recoil_yaw            : float = 0.0   # Current horizontal recoil offset (degrees)
var _recoil_recovery_pitch : float = 4.5   # Rate at which vertical recoil recovers (degrees/second)
var _recoil_recovery_yaw   : float = 2.5   # Rate at which horizontal recoil recovers (degrees/second)

# Damage hit reaction camera kick
var _damage_kick_pitch     : float = 0.0   # Temporary pitch flinch on damage
var _damage_kick_yaw       : float = 0.0   # Temporary yaw flinch on damage
var _damage_kick_roll      : float = 0.0   # Temporary roll flinch on damage
var _damage_kick_recovery  : float = 14.0  # Rate of damage flinch recovery (degrees/second)

# Prevent holding jump to auto-jump — require a fresh press
var _jump_consumed  : bool = false

# Footstep cadence tracking (distance-based, independent of weapon bob)
var _step_distance_accumulator : float = 0.0
const STEP_DISTANCE_WALK       : float = 2.4   # meters per footstep
const STEP_DISTANCE_SPRINT     : float = 2.8   # meters per sprint stride
const STEP_DISTANCE_CROUCH     : float = 1.6   # meters per crouch step


# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("combatants")
	add_to_group("player")
	# Initialise capsule collision shape to standing height.
	# CollisionShape3D stays at local origin (0,0,0) — never repositioned.
	var shape := _collision.shape as CapsuleShape3D
	if shape:
		shape.height = HEIGHT_STAND
	# Initialise camera mount to standing eye height above origin.
	# Origin is capsule centre = floor + HEIGHT_STAND/2, so eye above origin:
	_camera_mount.position.y = EYE_HEIGHT_STAND - (HEIGHT_STAND * 0.5)
	_mouse_pitch = _camera_mount.rotation_degrees.x
	_spawn_position = global_position
	# Cache base camera FOV
	if _camera:
		_base_fov = _camera.fov
	# Connect health signals
	if _health:
		_health.damage_received.connect(_on_damage_received)
		_health.died.connect(_on_died)
		_health.respawned.connect(_on_respawned)

	# Register weapons in inventory slots
	_weapons.clear()
	if is_instance_valid(_weapon_primary):
		_weapons.append(_weapon_primary)
	if is_instance_valid(_weapon_secondary):
		_weapons.append(_weapon_secondary)

	for w in _weapons:
		if w.has_method("set_player"):
			w.set_player(self)
		if w.has_method("set_camera"):
			w.set_camera(_camera)
		if w.has_signal("ammo_changed"):
			w.ammo_changed.connect(_on_weapon_ammo_changed.bind(w))

	# Initialize primary weapon (Slot 0) as equipped, unequip secondary
	_active_slot_index = 0
	if _weapons.size() > 0:
		_active_weapon = _weapons[0]
		for i in range(_weapons.size()):
			if i == _active_slot_index:
				if _weapons[i].has_method("equip"):
					_weapons[i].equip()
				else:
					_weapons[i].visible = true
					_weapons[i].set_process(true)
			else:
				if _weapons[i].has_method("unequip"):
					_weapons[i].unequip()
				else:
					_weapons[i].visible = false
					_weapons[i].set_process(false)

	# Connect MatchManager signals & initialize CombatHUD
	var tree := get_tree()
	if tree:
		var match_mgr = tree.get_first_node_in_group("match_manager")
		if match_mgr:
			if match_mgr.has_signal("match_ended"):
				match_mgr.match_ended.connect(_on_match_ended)
			if _combat_hud and _combat_hud.has_method("setup_match_manager"):
				_combat_hud.setup_match_manager(match_mgr, self)

	# Initial ammo push to HUD
	if is_instance_valid(_active_weapon) and _active_weapon.has_method("get_ammo_info") and _combat_hud and _combat_hud.has_method("update_ammo"):
		var ammo_info : Dictionary = _active_weapon.get_ammo_info()
		_combat_hud.update_ammo(ammo_info.get("current", 30), ammo_info.get("reserve", 120))

	# Ensure refill_ammo action is mapped to F3 as fallback
	if not InputMap.has_action("refill_ammo"):
		InputMap.add_action("refill_ammo")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event("refill_ammo", ev)


## Adds recoil impulse to camera pitch and yaw.
## v_kick: degrees upward kick (positive)
## h_kick: degrees horizontal kick
## recovery_rate: degrees/sec recovery toward baseline
func apply_recoil(v_kick: float, h_kick: float, recovery_rate: float) -> void:
	_recoil_pitch += v_kick
	_recoil_yaw += h_kick
	_recoil_recovery_pitch = recovery_rate
	_recoil_recovery_yaw = recovery_rate * 0.55  # Gentle horizontal recovery preserves spray character


# =============================================================================
# COMBATANT INTERFACE, DAMAGE & SCORE TRACKING
# =============================================================================
@export var combatant_name : String = "Player"
var kills  : int = 0
var deaths : int = 0


## Returns true if the player is currently alive.
func is_alive() -> bool:
	return not _is_dead


## Returns true if the player is actively aiming down sights.
func is_aiming() -> bool:
	return _is_aiming


## Returns current ADS transition weight [0.0, 1.0].
func get_ads_weight() -> float:
	return _ads_weight


## Returns target position for aim and LOS checks (torso center).
func get_target_position() -> Vector3:
	return global_position + Vector3(0.0, 0.1, 0.0)


## Called when player eliminates a target
func record_kill(_target_name: String) -> void:
	kills += 1


## Called when player is eliminated
func record_death(_killer_name: String) -> void:
	deaths += 1


## Damageable interface entrypoint
func take_damage(info: DamageInfo) -> void:
	if _is_dead:
		return
	if _health:
		_health.take_damage(info)
	elif has_node("Health"):
		_health = $Health
		_health.take_damage(info)


func _on_damage_received(info: DamageInfo, current_hp: float, max_hp: float) -> void:
	if _combat_hud:
		_combat_hud.show_damage(info, current_hp, max_hp)

	# Audio feedback (2D player damage cue)
	AudioManager.play_2d("player_damage", AudioManager.BUS_SFX, 0.0, 0.05)

	# Subtle camera flinch on hit (layered safely with mouse & recoil)
	_damage_kick_pitch += randf_range(-1.2, -0.6)
	_damage_kick_yaw += randf_range(-1.0, 1.0)
	_damage_kick_roll += randf_range(-1.5, 1.5)

	var attacker_name : String = str(info.attacker.name) if (info and info.attacker) else "Unknown"
	print("[PLAYER DAMAGE] Took %.0f damage from %s. HP: %.0f/%.0f" % [
		info.get_final_damage() if info else 0.0,
		attacker_name,
		current_hp,
		max_hp
	])


func _on_died(killer: Node) -> void:
	if _is_dead:
		return
	_is_dead = true
	deaths += 1
	velocity = Vector3.ZERO
	_is_aiming = false
	_ads_weight = 0.0
	if _camera:
		_camera.fov = _base_fov
	_damage_kick_pitch = 0.0
	_damage_kick_yaw = 0.0
	_damage_kick_roll = 0.0
	_recoil_pitch = 0.0
	_recoil_yaw = 0.0

	# Audio feedback (2D player death cue)
	AudioManager.play_2d("player_death", AudioManager.BUS_SFX, 1.0, 0.0)

	if _combat_hud:
		_combat_hud.show_death(killer, 2.5)

	var killer_name : String = str(killer.get("combatant_name")) if (killer and killer.get("combatant_name")) else (str(killer.name) if killer else "World")
	print("[PLAYER DEATH] Player killed by %s" % killer_name)

	# Prototype respawn after 2.5 seconds
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(_do_respawn)


func _do_respawn() -> void:
	if _is_match_ended:
		return
	if _health:
		_health.respawn()


func _on_weapon_ammo_changed(current: int, reserve: int, weapon_source: Node = null) -> void:
	# Only forward ammo updates for the currently active weapon
	if weapon_source != null and weapon_source != _active_weapon:
		return
	if _combat_hud and _combat_hud.has_method("update_ammo"):
		_combat_hud.update_ammo(current, reserve)


func _on_match_ended(_winner: Node) -> void:
	_is_match_ended = true
	_is_aiming = false
	_ads_weight = 0.0
	if _camera:
		_camera.fov = _base_fov


func _on_respawned() -> void:
	_is_dead = false

	# Select dynamic spawn from MatchManager if available
	var tree := get_tree()
	var spawn_pos := _spawn_position
	var spawn_yaw := 0.0
	if tree:
		var match_mgr = tree.get_first_node_in_group("match_manager")
		if match_mgr and match_mgr.has_method("get_spawn_point"):
			var trans : Transform3D = match_mgr.get_spawn_point(self)
			spawn_pos = trans.origin
			spawn_yaw = trans.basis.get_euler().y

	global_position = spawn_pos
	rotation.y = spawn_yaw
	velocity = Vector3.ZERO
	_is_aiming = false
	_ads_weight = 0.0
	if _camera:
		_camera.fov = _base_fov
	_mouse_pitch = 0.0
	_recoil_pitch = 0.0
	_recoil_yaw = 0.0
	_damage_kick_pitch = 0.0
	_damage_kick_yaw = 0.0
	_damage_kick_roll = 0.0
	_camera_mount.rotation_degrees.x = 0.0
	_camera.rotation_degrees.y = 0.0
	_camera.rotation_degrees.z = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if is_instance_valid(_active_weapon) and _active_weapon.has_method("equip"):
		_active_weapon.equip()

	if _combat_hud:
		_combat_hud.hide_death()

	print("[RESPAWN] Player respawned at %s. HP: %.0f/%.0f" % [
		str(global_position.snapped(Vector3(0.1, 0.1, 0.1))),
		_health.current_health if _health else 100.0,
		_health.max_health if _health else 100.0
	])


## Switches active weapon slot (0 = Primary, 1 = Secondary).
func switch_weapon(slot_index: int) -> void:
	if _is_dead or _is_match_ended:
		return
	if slot_index == _active_slot_index:
		return
	if slot_index < 0 or slot_index >= _weapons.size():
		return

	var old_weapon := _active_weapon
	if is_instance_valid(old_weapon) and old_weapon.has_method("unequip"):
		old_weapon.unequip()

	_active_slot_index = slot_index
	_active_weapon = _weapons[_active_slot_index]

	if is_instance_valid(_active_weapon):
		if _active_weapon.has_method("equip"):
			_active_weapon.equip()
		if _active_weapon.has_method("set_aiming"):
			_active_weapon.set_aiming(_is_aiming)


# =============================================================================
# INPUT — collect mouse delta here; handle per-frame in _physics_process
# =============================================================================
func _input(event: InputEvent) -> void:
	if _is_match_ended:
		return

	# Dev/debug: Refill ammo (F3) for all inventory weapons
	if event.is_action_pressed("refill_ammo") and not _is_dead:
		for w in _weapons:
			if is_instance_valid(w) and w.has_method("refill_ammo"):
				w.refill_ammo()

	# Mouse look accumulation (only when alive)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _is_dead:
		_mouse_delta += event.relative

	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# =============================================================================
# PROCESS — weapon switching, weapon input & ADS camera transition
# =============================================================================
func _process(delta: float) -> void:
	if _is_dead or _is_match_ended:
		return

	# Weapon slot switching inputs
	if Input.is_action_just_pressed("weapon_slot_1"):
		switch_weapon(0)
	elif Input.is_action_just_pressed("weapon_slot_2"):
		switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_next"):
		if _weapons.size() > 1:
			switch_weapon((_active_slot_index + 1) % _weapons.size())
	elif Input.is_action_just_pressed("weapon_prev"):
		if _weapons.size() > 1:
			switch_weapon((_active_slot_index - 1 + _weapons.size()) % _weapons.size())

	# ADS input (hold RMB)
	var wants_aim : bool = Input.is_action_pressed("aim") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_is_aiming = wants_aim
	_ads_weight = lerpf(_ads_weight, 1.0 if _is_aiming else 0.0, ADS_LERP_SPEED * delta)

	# Smooth camera FOV zoom while aiming
	if _camera:
		_camera.fov = lerpf(_base_fov, ADS_FOV, _ads_weight)

	if _active_weapon == null or not is_instance_valid(_active_weapon):
		return

	if _active_weapon.has_method("set_aiming"):
		_active_weapon.set_aiming(_is_aiming)

	# Fire input: automatic vs semi-automatic
	var is_auto : bool = _active_weapon.is_automatic() if _active_weapon.has_method("is_automatic") else true
	var wants_fire : bool = Input.is_action_pressed("fire_primary") if is_auto else Input.is_action_just_pressed("fire_primary")
	if wants_fire:
		_active_weapon.try_fire()

	# Reload input
	if Input.is_action_just_pressed("reload"):
		_active_weapon.try_reload()


# =============================================================================
# PHYSICS PROCESS
# =============================================================================
func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _is_match_ended:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, DECEL_GROUND * delta)
			velocity.z = move_toward(velocity.z, 0.0, DECEL_GROUND * delta)
		move_and_slide()
		return

	# Fall / out-of-bounds safety check
	if global_position.y < -7.0:
		var fall_dmg := DamageInfo.new()
		fall_dmg.amount = 9999.0
		fall_dmg.attacker = null
		take_damage(fall_dmg)
		return

	_handle_mouse_look(delta)
	_handle_movement(delta)
	_handle_capsule_lerp(delta)
	move_and_slide()


# =============================================================================
# MOUSE LOOK & RECOIL
# =============================================================================
func _handle_mouse_look(delta: float) -> void:
	# Sensitivity scaling during ADS
	var current_sens : float = MOUSE_SENSITIVITY * lerpf(1.0, ADS_SENS_MULT, _ads_weight)

	# 1. Horizontal mouse look (yaw) — rotate the body, absorbing horizontal recoil if counter-steering
	if _mouse_delta.x != 0.0:
		var yaw_delta : float = rad_to_deg(_mouse_delta.x * current_sens)
		# Counter-steering absorbs active recoil yaw first
		if yaw_delta > 0.0 and _recoil_yaw > 0.0:
			var absorbed : float = min(yaw_delta, _recoil_yaw)
			_recoil_yaw -= absorbed
			yaw_delta -= absorbed
		elif yaw_delta < 0.0 and _recoil_yaw < 0.0:
			var absorbed : float = max(yaw_delta, _recoil_yaw)
			_recoil_yaw -= absorbed
			yaw_delta -= absorbed

		if yaw_delta != 0.0:
			rotate_y(-deg_to_rad(yaw_delta))

	# 2. Vertical mouse look (pitch) — modify _mouse_pitch, absorbing active recoil if pulling down
	if _mouse_delta.y != 0.0:
		var pitch_delta : float = rad_to_deg(_mouse_delta.y * current_sens)
		# When pulling mouse DOWN (pitch_delta > 0), absorb active upward recoil first
		if pitch_delta > 0.0 and _recoil_pitch > 0.0:
			var absorbed : float = min(pitch_delta, _recoil_pitch)
			_recoil_pitch -= absorbed
			pitch_delta -= absorbed
		elif pitch_delta < 0.0 and _recoil_pitch < 0.0:
			var absorbed : float = max(pitch_delta, _recoil_pitch)
			_recoil_pitch -= absorbed
			pitch_delta -= absorbed

		_mouse_pitch = clamp(_mouse_pitch - pitch_delta, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)

	_mouse_delta = Vector2.ZERO

	# 3. Smooth recoil & damage kick recovery over time toward rest (0)
	if _recoil_pitch != 0.0:
		_recoil_pitch = move_toward(_recoil_pitch, 0.0, _recoil_recovery_pitch * delta)
	if _recoil_yaw != 0.0:
		_recoil_yaw = move_toward(_recoil_yaw, 0.0, _recoil_recovery_yaw * delta)
	if _damage_kick_pitch != 0.0:
		_damage_kick_pitch = move_toward(_damage_kick_pitch, 0.0, _damage_kick_recovery * delta)
	if _damage_kick_yaw != 0.0:
		_damage_kick_yaw = move_toward(_damage_kick_yaw, 0.0, _damage_kick_recovery * delta)
	if _damage_kick_roll != 0.0:
		_damage_kick_roll = move_toward(_damage_kick_roll, 0.0, _damage_kick_recovery * delta)

	# 4. Final camera pitch = base mouse pitch + weapon recoil pitch + damage kick pitch (clamped safely)
	_camera_mount.rotation_degrees.x = clamp(_mouse_pitch + _recoil_pitch + _damage_kick_pitch, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)

	# 5. Final camera yaw & roll offsets
	_camera.rotation_degrees.y = _recoil_yaw + _damage_kick_yaw
	_camera.rotation_degrees.z = _damage_kick_roll


# =============================================================================
# MOVEMENT DISPATCH
# =============================================================================
func _handle_movement(delta: float) -> void:
	# Always apply gravity when airborne
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		# Landing — end any air state and trigger audio
		if _state == MoveState.AIR:
			_state = MoveState.WALK
			AudioManager.play_2d("land", AudioManager.BUS_SFX, -2.0, 0.05)
		_jump_consumed = false

	# --- State transitions ---
	_resolve_state()

	# --- Dispatch to state handler ---
	match _state:
		MoveState.WALK:
			_move_grounded(delta, WALK_SPEED)
		MoveState.SPRINT:
			_move_grounded(delta, SPRINT_SPEED)
		MoveState.CROUCH:
			_move_grounded(delta, CROUCH_SPEED)
		MoveState.SLIDE:
			_move_slide(delta)
		MoveState.AIR:
			_move_air(delta)

	# --- Footstep cadence tracking (grounded and moving, independent of weapon bob) ---
	_process_footstep_audio(delta)

	# --- Jump ---
	_handle_jump()


func _process_footstep_audio(delta: float) -> void:
	if not is_on_floor() or _state == MoveState.AIR or _state == MoveState.SLIDE:
		_step_distance_accumulator = 0.0
		return

	var h_vel := Vector2(velocity.x, velocity.z)
	var h_speed := h_vel.length()

	if h_speed > 0.5:
		_step_distance_accumulator += h_speed * delta

		var step_target := STEP_DISTANCE_WALK
		var step_vol := -4.0

		if _state == MoveState.SPRINT:
			step_target = STEP_DISTANCE_SPRINT
			step_vol = -2.0
		elif _state == MoveState.CROUCH:
			step_target = STEP_DISTANCE_CROUCH
			step_vol = -8.0

		if _step_distance_accumulator >= step_target:
			_step_distance_accumulator = 0.0
			AudioManager.play_2d("footstep", AudioManager.BUS_SFX, step_vol, 0.06)
	else:
		_step_distance_accumulator = 0.0


# =============================================================================
# STATE RESOLVER
# =============================================================================
func _resolve_state() -> void:
	var on_floor  := is_on_floor()
	var sprinting := Input.is_action_pressed("sprint")
	var crouching := Input.is_action_pressed("crouch")
	var moving    := _get_wish_dir().length_squared() > 0.01

	if not on_floor:
		_state = MoveState.AIR
		return

	# Slide: must be sprinting + moving + press crouch
	if _state != MoveState.SLIDE:
		if sprinting and crouching and moving:
			_start_slide()
			return

	# Already sliding — check end conditions
	if _state == MoveState.SLIDE:
		return   # _move_slide handles its own end condition

	# Crouch (not sliding)
	if crouching:
		_state = MoveState.CROUCH
		return

	# Sprint
	if sprinting and moving:
		_state = MoveState.SPRINT
		return

	# Default walk
	_state = MoveState.WALK


# =============================================================================
# GROUNDED MOVEMENT  (walk / sprint / crouch)
# =============================================================================
func _move_grounded(delta: float, target_speed: float) -> void:
	var wish_dir := _get_wish_dir()

	if wish_dir.length_squared() > 0.01:
		# Accelerate toward wish direction
		var target_vel := wish_dir * target_speed
		velocity.x = move_toward(velocity.x, target_vel.x, ACCEL_GROUND * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, ACCEL_GROUND * delta)
	else:
		# Decelerate to stop
		velocity.x = move_toward(velocity.x, 0.0, DECEL_GROUND * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL_GROUND * delta)


# =============================================================================
# AIR MOVEMENT
# =============================================================================
func _move_air(delta: float) -> void:
	var wish_dir := _get_wish_dir()

	if wish_dir.length_squared() > 0.01:
		velocity.x = move_toward(velocity.x, wish_dir.x * SPRINT_SPEED, ACCEL_AIR * delta)
		velocity.z = move_toward(velocity.z, wish_dir.z * SPRINT_SPEED, ACCEL_AIR * delta)
	else:
		# Light air friction — player retains momentum but drifts slowly toward stop
		velocity.x = move_toward(velocity.x, 0.0, DECEL_AIR * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL_AIR * delta)


# =============================================================================
# SLIDE MOVEMENT
# =============================================================================
func _start_slide() -> void:
	_state = MoveState.SLIDE
	_is_sliding = true
	_step_distance_accumulator = 0.0
	# Audio feedback (2D player slide)
	AudioManager.play_2d("slide", AudioManager.BUS_SFX, -2.0, 0.04)
	# Launch with a boost in the current facing direction
	var dir := _get_wish_dir()
	if dir.length_squared() < 0.01:
		dir = -transform.basis.z  # fall back to facing direction
	_slide_velocity = dir * SLIDE_SPEED_START


func _move_slide(delta: float) -> void:
	# Apply friction to the slide velocity
	var speed := _slide_velocity.length()
	speed = max(speed - SLIDE_FRICTION * delta, 0.0)
	_slide_velocity = _slide_velocity.normalized() * speed if speed > 0.0 else Vector3.ZERO

	velocity.x = _slide_velocity.x
	velocity.z = _slide_velocity.z

	# End slide conditions
	var crouch_held := Input.is_action_pressed("crouch")
	if speed < SLIDE_SPEED_MIN or not crouch_held:
		_end_slide()


func _end_slide() -> void:
	_is_sliding = false
	_slide_velocity = Vector3.ZERO
	# Transition to crouch if still holding crouch, otherwise walk
	if Input.is_action_pressed("crouch"):
		_state = MoveState.CROUCH
	else:
		_state = MoveState.WALK


# =============================================================================
# JUMP
# =============================================================================
func _handle_jump() -> void:
	if is_on_floor() and not _jump_consumed and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		_state = MoveState.AIR
		_jump_consumed = true
		_step_distance_accumulator = 0.0
		# Audio feedback (2D player jump)
		AudioManager.play_2d("jump", AudioManager.BUS_SFX, -3.0, 0.05)
		# End slide on jump
		if _is_sliding:
			_end_slide()


# =============================================================================
# CAPSULE HEIGHT MANAGEMENT
#
# Design:
#   - CharacterBody3D origin sits at the capsule centre.
#   - CollisionShape3D stays at local position (0, 0, 0) — never moved.
#     Moving the child would shift the collision relative to the body and cause
#     the physics engine to issue a floor-correction impulse, producing jitter.
#   - Instead, when the capsule grows (stand up), we shift global_position.y UP
#     by half the height increase so the capsule bottom stays on the floor.
#   - Camera target is a smoothly interpolated eye-height above the floor,
#     not a binary snap between two offsets.
# =============================================================================

# Eye heights above the floor (not above the capsule centre).
const EYE_HEIGHT_STAND  : float = 1.65   # metres above feet when standing
const EYE_HEIGHT_CROUCH : float = 0.75   # metres above feet when crouched

# Separate tracked variable for the camera's current eye height (above floor).
var _current_eye_height : float = EYE_HEIGHT_STAND


func _handle_capsule_lerp(delta: float) -> void:
	var target_height : float = HEIGHT_STAND
	var target_eye    : float = EYE_HEIGHT_STAND

	if _state == MoveState.CROUCH or _state == MoveState.SLIDE:
		target_height = HEIGHT_CROUCH
		target_eye    = EYE_HEIGHT_CROUCH

	# --- Capsule height ---
	var height_diff : float = target_height - _current_height
	if abs(height_diff) > 0.001:
		# If growing (standing up), check for ceiling first.
		if height_diff > 0.0 and _is_ceiling_blocking():
			# Blocked — also pin camera to crouch height so it doesn't drift.
			target_eye = EYE_HEIGHT_CROUCH
		else:
			var new_height : float = lerpf(_current_height, target_height, HEIGHT_LERP_SPEED * delta)
			# Snap to target when close enough to avoid permanent asymptote.
			if abs(new_height - target_height) < 0.002:
				new_height = target_height

			var delta_h : float = new_height - _current_height
			_current_height = new_height

			# Resize the capsule shape in place.
			var shape := _collision.shape as CapsuleShape3D
			if shape:
				shape.height = _current_height
			# DO NOT move _collision — it stays at local origin (0,0,0).
			# Instead, shift the body upward by half the increase so the
			# bottom of the capsule tracks the floor.
			global_position.y += delta_h * 0.5

	# --- Camera eye height (always lerped, independent of capsule) ---
	_current_eye_height = lerpf(_current_eye_height, target_eye, HEIGHT_LERP_SPEED * delta)
	if abs(_current_eye_height - target_eye) < 0.002:
		_current_eye_height = target_eye
	# Camera mount sits at eye height above the body's current origin.
	# Body origin = capsule centre = floor + height/2.
	# Eye height above origin = eye_height_above_floor - height/2.
	_camera_mount.position.y = _current_eye_height - (_current_height * 0.5)


func _is_ceiling_blocking() -> bool:
	# Shape-cast the full standing capsule from the current position to detect
	# any ceiling that would prevent standing. Uses a point check at the
	# height the top of the standing capsule would reach.
	var space  := get_world_3d().direct_space_state
	# Current capsule bottom in world space:
	var feet_y : float = global_position.y - (_current_height * 0.5)
	# Where the top of the standing capsule would be:
	var top_y  : float = feet_y + HEIGHT_STAND
	var origin := global_position
	var target := Vector3(origin.x, top_y + 0.05, origin.z)
	var query  := PhysicsRayQueryParameters3D.create(origin, target, collision_mask)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	return not result.is_empty()


# =============================================================================
# HELPERS
# =============================================================================

## Returns the normalised world-space movement direction based on WASD + camera facing.
func _get_wish_dir() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	# Transform input from camera-relative to world-relative (horizontal only)
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	dir.y = 0.0
	return dir
