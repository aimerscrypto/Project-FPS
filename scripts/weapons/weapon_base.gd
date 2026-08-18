extends Node3D

# =============================================================================
# Project FPS — WeaponBase
# Milestone 2 — First Weapon
#
# Handles: firing, reload, ammo, hitscan raycast, recoil application.
# Does NOT handle: health, enemies, UI, multiplayer, animations.
#
# Designed to be data-driven via a WeaponData resource.
# All weapon-specific numbers come from the attached WeaponData .tres file.
# Attach any WeaponData resource via the Inspector to change weapon behaviour.
# =============================================================================

signal ammo_changed(current_ammo: int, reserve_ammo: int)

# -----------------------------------------------------------------------------
# EXPORTS
# -----------------------------------------------------------------------------
@export var data : WeaponData   ## Attach the weapon's .tres data resource here.


# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
# RayCast3D for hitscan — must exist as a child node named "RayCast3D".
@onready var _raycast       : RayCast3D    = $RayCast3D

# Muzzle flash Node3D — toggled visible for one frame on fire.
@onready var _muzzle_flash  : Node3D       = find_child("MuzzleFlash", true, false)

# Visual node references & authored base transforms
@onready var _weapon_visual : Node3D       = find_child("WeaponVisual", true, false)
@onready var _right_grip    : Node3D       = find_child("RightHandGrip", true, false)
@onready var _left_grip     : Node3D       = find_child("LeftHandGrip", true, false)
@onready var _optic_point    : Node3D       = find_child("OpticPoint", true, false)

var _base_visual_transform     : Transform3D = Transform3D.IDENTITY
var _base_muzzle_transform     : Transform3D = Transform3D.IDENTITY
var _base_right_grip_transform : Transform3D = Transform3D.IDENTITY
var _base_left_grip_transform  : Transform3D = Transform3D.IDENTITY
var _base_optic_transform      : Transform3D = Transform3D.IDENTITY

# Reference to the Player and Camera3D so recoil can be applied cleanly.
var _player : CharacterBody3D = null
var _camera : Camera3D        = null


# -----------------------------------------------------------------------------
# WEAPON STATE
enum WeaponState { READY, FIRING, RELOADING }

var _state           : WeaponState = WeaponState.READY
var _current_ammo    : int         = 0
var _reserve_ammo    : int         = 0
var _fire_timer      : float       = 0.0   # countdown to next allowed shot
var _reload_timer    : float       = 0.0   # countdown to reload completion
var _equip_timer     : float       = 0.0   # equip lock countdown
const EQUIP_DURATION : float       = 0.20  # seconds to ready weapon upon equip

# Muzzle flash visibility & tuning
var _muzzle_timer    : float       = 0.0
const MUZZLE_FLASH_DURATION : float = 0.038  # seconds (brief ~38ms flash)

# Spray tracking for recoil personality & directional tendency
var _continuous_shots   : int   = 0
var _spray_direction    : float = 1.0    # 1.0 (rightward bias) or -1.0 (leftward bias)
var _time_since_fired   : float = 0.0
const SPRAY_RESET_DELAY : float = 0.25   # seconds after last shot to reset continuous spray count


# -----------------------------------------------------------------------------
# FIRST-PERSON WEAPON MOTION CONSTANTS (AAA FPS Feel)
# -----------------------------------------------------------------------------
# 1. Idle Sway (Natural breathing-like swing)
const IDLE_SWAY_FREQ    : float = 1.2     # rad/s (~0.19 Hz, ~5.2s breathing cycle)
const IDLE_SWAY_POS_X   : float = 0.0035  # 3.5 mm lateral breathing swing
const IDLE_SWAY_POS_Y   : float = 0.0028  # 2.8 mm vertical chest rise/fall
const IDLE_SWAY_POS_Z   : float = 0.0018  # 1.8 mm depth breathing
const IDLE_SWAY_ROT_X   : float = 0.0150  # ~0.86 deg pitch breathing
const IDLE_SWAY_ROT_Y   : float = 0.0180  # ~1.03 deg yaw swing
const IDLE_SWAY_ROT_Z   : float = 0.0140  # ~0.80 deg roll swing

# 2. Walking Bob (Grounded, natural Lissajous gait)
const BOB_FREQ_WALK     : float = 0.65    # stride frequency multiplier (~1.45 steps/sec at walk)
const BOB_POS_X         : float = 0.0055  # 5.5 mm lateral stride sway
const BOB_POS_Y         : float = 0.0045  # 4.5 mm vertical step dip
const BOB_POS_Z         : float = 0.0030  # 3.0 mm forward/back inertia
const BOB_ROT_X         : float = 0.0100  # ~0.57 deg pitch nodding
const BOB_ROT_Y         : float = 0.0120  # ~0.69 deg yaw stride sway
const BOB_ROT_Z         : float = 0.0160  # ~0.92 deg roll counter-balance
const BOB_LERP_SPEED    : float = 7.5     # smooth blend speed in/out of stride

# 3. Sprint Presentation (Tactical Low-Ready Pose + Dynamic Jog Pump)
const SPRINT_POS_BASE   : Vector3 = Vector3(0.012, -0.055, 0.025)  # lowered 5.5cm, tucked 2.5cm back
const SPRINT_ROT_BASE   : Vector3 = Vector3(-0.200, -0.090, -0.160) # -11.5° pitch down, -5.2° yaw in, -9.2° roll tilt
const SPRINT_FREQ_PUMP  : float   = 0.75   # rhythmic sprint jog pump cadence
const SPRINT_PUMP_POS_X : float   = 0.0080 # 8.0 mm lateral jog sway
const SPRINT_PUMP_POS_Y : float   = 0.0065 # 6.5 mm vertical jog pump
const SPRINT_PUMP_POS_Z : float   = 0.0050 # 5.0 mm forward/back jog pump
const SPRINT_PUMP_ROT_X : float   = 0.0350 # ~2.0 deg dynamic jog pitch
const SPRINT_PUMP_ROT_Y : float   = 0.0250 # ~1.4 deg dynamic jog yaw
const SPRINT_PUMP_ROT_Z : float   = 0.0400 # ~2.3 deg dynamic jog roll
const SPRINT_LERP_SPEED : float   = 7.5    # transition speed into/out of sprint (~0.15s)

# 4. Crouch Presentation (Natural camera-matched compression)
const CROUCH_POS_OFFSET : Vector3 = Vector3(0.0, -0.012, 0.006)    # lowered 1.2cm, tucked 0.6cm back
const CROUCH_ROT_OFFSET : Vector3 = Vector3(-0.016, 0.0, -0.012)   # -0.9° pitch, -0.7° roll
const CROUCH_LERP_SPEED : float   = 9.0    # smooth transition matching camera height lerp

# 5. Mouse Look Sway (Viewmodel rotational inertia / lag)
const LOOK_SWAY_ROT_SCALE  : float = 0.50
const LOOK_SWAY_POS_SCALE  : float = 0.015
const LOOK_SWAY_LERP_SPEED : float = 10.0
const MAX_LOOK_SWAY_ROT    : float = 0.045  # ~2.6 deg max look lag
const MAX_LOOK_SWAY_POS    : float = 0.006  # 6 mm max look offset

# 6. Procedural Firing Kick (Viewmodel Physical Recoil Punch)
const KICK_POS_IMPULSE      : Vector3 = Vector3(0.0008, 0.0020, 0.0160)  # per-shot translation kick (16mm backward punch)
const KICK_ROT_IMPULSE      : Vector3 = Vector3(0.0450, 0.0030, 0.0060)  # per-shot rotation kick (~2.58° pitch up)
const KICK_POS_MAX          : Vector3 = Vector3(0.0040, 0.0080, 0.0340)  # max accumulated kick translation in full auto
const KICK_ROT_MAX          : Vector3 = Vector3(0.0850, 0.0120, 0.0200)  # max accumulated kick rotation (~4.87°)
const KICK_LERP_SPEED       : float   = 18.0                              # smooth kick recovery rate toward rest

# 7. Viewmodel Mechanical Firing Vibration (Subtle High-Frequency Buzz)
const VIBRATION_POS_MAG     : Vector3 = Vector3(0.0006, 0.0005, 0.0010)  # 0.6mm X, 0.5mm Y, 1.0mm Z mechanical vibration
const VIBRATION_ROT_MAG     : Vector3 = Vector3(0.0050, 0.0035, 0.0060)  # ~0.28° X, ~0.20° Y, ~0.34° Z vibration
const VIBRATION_DECAY       : float   = 24.0                              # rate of vibration damping
const VIBRATION_FREQ        : float   = 70.0                              # vibration oscillation frequency

# 8. Procedural Reload Animation Keyframes (Arcade Root Transform Motion)
# Keyframe timestamps normalized to data.reload_time (2.0s)
const RELOAD_KEYFRAMES : Array[Dictionary] = [
	{ "t": 0.00, "pos": Vector3(0.000,  0.000,  0.000), "rot": Vector3(0.000,  0.000,  0.000) },
	{ "t": 0.22, "pos": Vector3(0.012, -0.085,  0.025), "rot": Vector3(-0.080, -0.100,  0.200) }, # Lower & roll tilt to expose magwell
	{ "t": 0.46, "pos": Vector3(0.015, -0.090,  0.030), "rot": Vector3(-0.060, -0.110,  0.220) }, # Mid-reload hold in reload stance (mag out)
	{ "t": 0.54, "pos": Vector3(0.006, -0.055,  0.012), "rot": Vector3(0.040, -0.050,  0.140) }, # Mag slap punch (sharp upward & forward impact)
	{ "t": 0.62, "pos": Vector3(0.012, -0.075,  0.025), "rot": Vector3(-0.030, -0.070,  0.160) }, # Rebound from mag slam
	{ "t": 0.72, "pos": Vector3(0.004, -0.045,  0.036), "rot": Vector3(0.025, -0.030,  0.080) }, # Bolt rack pull (backward Z jerk)
	{ "t": 0.80, "pos": Vector3(0.002, -0.030,  0.008), "rot": Vector3(-0.015, -0.015,  0.030) }, # Bolt snap forward release
	{ "t": 0.94, "pos": Vector3(-0.001, 0.002, -0.002), "rot": Vector3(0.004,  0.002, -0.005) }, # Soft ascent ease-out overshoot
	{ "t": 1.00, "pos": Vector3(0.000,  0.000,  0.000), "rot": Vector3(0.000,  0.000,  0.000) }, # Return to rest position
]

# 9. Aim Down Sights (ADS) Presentation (Optic Alignment & Stance)
const ADS_POS_OFFSET        : Vector3 = Vector3(-0.1952, 0.0820, 0.0700) # Aligns optic centerline precisely with camera (0,0)
const ADS_ROT_OFFSET        : Vector3 = Vector3(0.0030, -0.0550, 0.0020) # Straightens sightline down center axis
const ADS_LERP_SPEED        : float   = 14.0                              # Fast arcade transition speed (~0.15s)
const ADS_SWAY_DAMP         : float   = 0.35                              # Subtle breathing damping while aiming
const ADS_BOB_DAMP          : float   = 0.25                              # Reduced walk bob while aiming
const ADS_LOOK_DAMP         : float   = 0.20                              # Reduced rotational inertia while aiming

# Motion tracking state
var _idle_timer             : float   = 0.0
var _bob_timer              : float   = 0.0
var _sprint_timer           : float   = 0.0
var _sprint_weight          : float   = 0.0
var _current_bob_pos        : Vector3 = Vector3.ZERO
var _current_bob_rot        : Vector3 = Vector3.ZERO
var _current_sprint_pos     : Vector3 = Vector3.ZERO
var _current_sprint_rot     : Vector3 = Vector3.ZERO
var _current_crouch_pos     : Vector3 = Vector3.ZERO
var _current_crouch_rot     : Vector3 = Vector3.ZERO
var _current_look_sway_pos  : Vector3 = Vector3.ZERO
var _current_look_sway_rot  : Vector3 = Vector3.ZERO
var _last_cam_rot           : Vector3 = Vector3.ZERO
var _has_last_cam_rot       : bool    = false

# Firing presentation tracking state
var _current_kick_pos       : Vector3 = Vector3.ZERO
var _current_kick_rot       : Vector3 = Vector3.ZERO
var _vibration_trauma       : float   = 0.0
var _vibration_timer        : float   = 0.0
var _flash_scale_mod        : float   = 1.0
var _flash_roll_angle       : float   = 0.0

# Reload presentation tracking state
var _current_reload_pos     : Vector3 = Vector3.ZERO
var _current_reload_rot     : Vector3 = Vector3.ZERO

# ADS presentation tracking state
var _is_aiming              : bool    = false
var _ads_weight             : float   = 0.0


# =============================================================================
# SETUP
# =============================================================================
func _ready() -> void:
	if data == null:
		push_error("WeaponBase: no WeaponData assigned — weapon will not function.")
		return
	_current_ammo = data.magazine_size
	_reserve_ammo = data.reserve_ammo
	ammo_changed.emit(_current_ammo, _reserve_ammo)
	# RayCast3D length set from weapon data range.
	_raycast.target_position = Vector3(0.0, 0.0, -data.range_meters)
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false

	# Cache authored base transforms so procedural offsets preserve base placement
	if is_instance_valid(_weapon_visual):
		_base_visual_transform = _weapon_visual.transform
	if is_instance_valid(_muzzle_flash):
		_base_muzzle_transform = _muzzle_flash.transform
	if is_instance_valid(_right_grip):
		_base_right_grip_transform = _right_grip.transform
	if is_instance_valid(_left_grip):
		_base_left_grip_transform = _left_grip.transform
	if is_instance_valid(_optic_point):
		_base_optic_transform = _optic_point.transform


## Called by the player controller to link the player body.
func set_player(player: CharacterBody3D) -> void:
	_player = player


## Called by the player controller to give the weapon a camera reference.
func set_camera(cam: Camera3D) -> void:
	_camera = cam


# =============================================================================
# PROCESS
# =============================================================================
func _process(delta: float) -> void:
	if data == null or not visible:
		return

	if _equip_timer > 0.0:
		_equip_timer = maxf(_equip_timer - delta, 0.0)

	# Fallback/standalone ADS state update if not driven by player
	if _player == null or not _player.has_method("is_aiming"):
		_is_aiming = Input.is_action_pressed("aim") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	_ads_weight = lerpf(_ads_weight, 1.0 if _is_aiming else 0.0, ADS_LERP_SPEED * delta)

	_tick_fire_timer(delta)
	_tick_reload_timer(delta)
	_tick_muzzle_flash(delta)
	_tick_spray_tracker(delta)
	_update_weapon_motion(delta)


# =============================================================================
# PUBLIC API — called by the player controller
# =============================================================================

## Equips this weapon, enabling presentation, processing, and broadcasting current ammo.
func equip() -> void:
	visible = true
	set_process(true)
	_equip_timer = EQUIP_DURATION
	_has_last_cam_rot = false
	_current_kick_pos = Vector3.ZERO
	_current_kick_rot = Vector3.ZERO
	_vibration_trauma = 0.0
	_vibration_timer = 0.0
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false
	ammo_changed.emit(_current_ammo, _reserve_ammo)


## Unequips this weapon, disabling background processing and resetting transient visual offsets.
func unequip() -> void:
	# Safely cancel active reload without altering weapon's current or reserve ammo
	if _state == WeaponState.RELOADING:
		_state = WeaponState.READY
		_reload_timer = 0.0
		_current_reload_pos = Vector3.ZERO
		_current_reload_rot = Vector3.ZERO
	elif _state == WeaponState.FIRING:
		_state = WeaponState.READY
		_fire_timer = 0.0

	_is_aiming = false
	_ads_weight = 0.0
	_equip_timer = 0.0
	_has_last_cam_rot = false
	_current_kick_pos = Vector3.ZERO
	_current_kick_rot = Vector3.ZERO
	_vibration_trauma = 0.0
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false
	visible = false
	set_process(false)


## Returns true if the weapon is currently undergoing its equip transition.
func is_equipping() -> bool:
	return _equip_timer > 0.0


## Returns true if the weapon fires automatically when trigger is held.
func is_automatic() -> bool:
	return data.is_automatic if data != null else true


## Sets ADS aim state from player input.
func set_aiming(aiming: bool) -> void:
	_is_aiming = aiming


## Returns true if aiming down sights or transitioning.
func is_aiming() -> bool:
	return _is_aiming or _ads_weight > 0.01


## Returns current ADS blend weight [0.0, 1.0].
func get_ads_weight() -> float:
	return _ads_weight


## Attempt to fire. Called while fire input is active.
func try_fire() -> void:
	if data == null or not visible or is_equipping():
		return
	if _state == WeaponState.RELOADING:
		return
	if _fire_timer > 0.0:
		return

	if _current_ammo <= 0:
		if _reserve_ammo > 0:
			_start_reload()
		else:
			_dry_fire()
		return

	_fire()


## Attempt to reload. Called when reload input is pressed.
func try_reload() -> void:
	if data == null or not visible or is_equipping():
		return
	if _state == WeaponState.RELOADING:
		return
	if _current_ammo == data.magazine_size:
		return  # already full
	if _reserve_ammo <= 0:
		return  # nothing to reload from

	_start_reload()


## Development/debug: Refills magazine and reserve ammo to maximum configured values.
func refill_ammo() -> void:
	if data == null:
		return
	_current_ammo = data.magazine_size
	_reserve_ammo = data.reserve_ammo
	if _state == WeaponState.RELOADING:
		_state = WeaponState.READY
		_reload_timer = 0.0
		_current_reload_pos = Vector3.ZERO
		_current_reload_rot = Vector3.ZERO
	ammo_changed.emit(_current_ammo, _reserve_ammo)
	print("[DEV] Ammo refilled: %d / %d" % [_current_ammo, _reserve_ammo])


# =============================================================================
# FIRE
# =============================================================================
func _fire() -> void:
	_state = WeaponState.FIRING
	_current_ammo -= 1
	ammo_changed.emit(_current_ammo, _reserve_ammo)
	_fire_timer = 1.0 / data.fire_rate
	_time_since_fired = 0.0

	# Audio feedback (2D player weapon fire)
	AudioManager.play_2d("ar_fire", AudioManager.BUS_SFX, 0.0, 0.04)

	# Hitscan
	_do_hitscan()

	# Recoil (Camera recoil)
	_apply_recoil()

	# Procedural weapon kick (Viewmodel recoil punch)
	var kick_x_rnd : float = randf_range(-0.0006, 0.0006)
	var kick_y_rnd : float = randf_range(0.0015, 0.0025)
	var kick_z_rnd : float = randf_range(0.0140, 0.0175)
	var kick_pos_step := Vector3(kick_x_rnd, kick_y_rnd, kick_z_rnd)

	var kick_rot_x_rnd : float = randf_range(0.038, 0.048)
	var kick_rot_y_rnd : float = randf_range(-0.004, 0.004)
	var kick_rot_z_rnd : float = randf_range(-0.007, 0.007)
	var kick_rot_step := Vector3(kick_rot_x_rnd, kick_rot_y_rnd, kick_rot_z_rnd)

	_current_kick_pos.x = clampf(_current_kick_pos.x + kick_pos_step.x, -KICK_POS_MAX.x, KICK_POS_MAX.x)
	_current_kick_pos.y = clampf(_current_kick_pos.y + kick_pos_step.y, -KICK_POS_MAX.y, KICK_POS_MAX.y)
	_current_kick_pos.z = clampf(_current_kick_pos.z + kick_pos_step.z, 0.0, KICK_POS_MAX.z)

	_current_kick_rot.x = clampf(_current_kick_rot.x + kick_rot_step.x, -KICK_ROT_MAX.x, KICK_ROT_MAX.x)
	_current_kick_rot.y = clampf(_current_kick_rot.y + kick_rot_step.y, -KICK_ROT_MAX.y, KICK_ROT_MAX.y)
	_current_kick_rot.z = clampf(_current_kick_rot.z + kick_rot_step.z, -KICK_ROT_MAX.z, KICK_ROT_MAX.z)

	# Trigger viewmodel mechanical firing vibration
	_vibration_trauma = 1.0

	# Muzzle flash presentation (brief flash, randomized scale & roll)
	if is_instance_valid(_muzzle_flash):
		_flash_scale_mod = randf_range(0.85, 1.20)
		_flash_roll_angle = randf_range(-PI, PI)
		_muzzle_flash.visible = true
		_muzzle_timer = MUZZLE_FLASH_DURATION

	print("[Weapon] Fired. Ammo: %d / %d" % [_current_ammo, _reserve_ammo])

	# Auto-reload when magazine reaches 0 and reserve ammo is available
	if _current_ammo <= 0 and _reserve_ammo > 0:
		_start_reload()


func _dry_fire() -> void:
	# Audio feedback (dry fire click)
	AudioManager.play_2d("ar_dryfire", AudioManager.BUS_SFX, -2.0, 0.03)
	# Limit dry-fire spam messaging.
	print("[Weapon] DRY FIRE — magazine empty. Press R to reload.")
	_fire_timer = 0.3  # short delay before re-triggering dry fire message


# =============================================================================
# HITSCAN
# =============================================================================
func _do_hitscan() -> void:
	# Apply spread before casting.
	var spread_rad : float = deg_to_rad(data.spread_degrees)
	var offset_x   : float = randf_range(-spread_rad, spread_rad)
	var offset_y   : float = randf_range(-spread_rad, spread_rad)
	# Target position in local space (forward = -Z for Camera3D).
	var base_target := Vector3(offset_x, offset_y, -data.range_meters)
	_raycast.target_position = base_target

	# Force update so result is available immediately this frame.
	_raycast.force_raycast_update()

	if _raycast.is_colliding():
		var hit_point    := _raycast.get_collision_point()
		var hit_normal   := _raycast.get_collision_normal()
		var hit_collider := _raycast.get_collider()
		var hit_name     : String = str(hit_collider.name) if hit_collider else "unknown"

		print("[HIT] Object: %s | Point: %s | Normal: %s" % [
			hit_name,
			str(hit_point.snapped(Vector3(0.01, 0.01, 0.01))),
			str(hit_normal.snapped(Vector3(0.01, 0.01, 0.01)))
		])

		# Check whether hit object or its parent is damageable
		if hit_collider:
			var dmg_info := DamageInfo.new()
			dmg_info.amount = data.damage
			dmg_info.headshot_multiplier = data.headshot_multiplier
			dmg_info.attacker = _player
			dmg_info.hit_position = hit_point
			dmg_info.hit_normal = hit_normal
			dmg_info.hit_direction = (_raycast.global_transform.basis * _raycast.target_position).normalized()
			dmg_info.hit_type = DamageInfo.HitType.BODY
			if hit_collider.is_in_group("head"):
				dmg_info.hit_type = DamageInfo.HitType.HEAD

			# Dispatch damage cleanly through damageable interface
			var did_damage : bool = false
			if hit_collider.has_method("take_damage"):
				hit_collider.take_damage(dmg_info)
				did_damage = true
			elif hit_collider.has_node("Health"):
				var health_node = hit_collider.get_node("Health")
				if health_node and health_node.has_method("take_damage"):
					health_node.take_damage(dmg_info)
					did_damage = true
			elif hit_collider.get_parent() and hit_collider.get_parent().has_method("take_damage"):
				hit_collider.get_parent().take_damage(dmg_info)
				did_damage = true

			if did_damage:
				AudioManager.play_hitmarker(dmg_info.hit_type == DamageInfo.HitType.HEAD)

		# Spawn 3D impact audio & visual marker at hit point
		AudioManager.play_3d("impact", hit_point, AudioManager.BUS_SFX, -2.0, 0.06, 40.0, 4.0)
		_spawn_impact_marker(hit_point, hit_normal)
	else:
		print("[HIT] No collision detected.")


func _spawn_impact_marker(point: Vector3, normal: Vector3) -> void:
	# Temporary visual: a small orange sphere at the hit point.
	# Automatically removed after 2 seconds.
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius    = 0.05
	sphere.height    = 0.10
	marker.mesh      = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.0)  # orange
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat

	# Add to scene tree first, then set global_position.
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(marker)
		marker.global_position = point + normal * 0.02

		# Auto-remove via timer.
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(marker.queue_free)


# =============================================================================
# RELOAD
# =============================================================================
func _start_reload() -> void:
	_state = WeaponState.RELOADING
	_reload_timer = data.reload_time
	# Audio feedback (2D player weapon reload)
	AudioManager.play_2d("ar_reload", AudioManager.BUS_SFX, -1.0, 0.0)
	print("[Weapon] Reloading... (%.1fs)" % data.reload_time)


func _finish_reload() -> void:
	var needed : int = data.magazine_size - _current_ammo
	var taken  : int = min(needed, _reserve_ammo)
	_current_ammo += taken
	_reserve_ammo -= taken
	_state = WeaponState.READY
	ammo_changed.emit(_current_ammo, _reserve_ammo)
	print("[Weapon] Reload complete. Ammo: %d / %d" % [_current_ammo, _reserve_ammo])


# =============================================================================
# RECOIL
# =============================================================================
func _apply_recoil() -> void:
	if _player and _player.has_method("apply_recoil"):
		var h_max : float = data.recoil_horizontal

		# First 3-4 shots have reduced horizontal kick for tight initial burst control
		var h_scale : float = clampf(float(_continuous_shots) / 4.0, 0.35, 1.0)

		# Directional bias + random deviation around that bias
		var trend_step  : float = _spray_direction * h_max * 0.55
		var random_step : float = randf_range(-0.45, 0.45) * h_max
		var h_kick      : float = (trend_step + random_step) * h_scale

		# Reverse directional tendency every 5-7 continuous shots so the spray weaves naturally
		if _continuous_shots > 0 and _continuous_shots % randi_range(5, 7) == 0:
			_spray_direction *= -1.0

		_player.apply_recoil(data.recoil_vertical, h_kick, data.recoil_recovery)
		_continuous_shots += 1


# =============================================================================
# TIMERS
# =============================================================================
func _tick_fire_timer(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = 0.0
			if _state == WeaponState.FIRING:
				_state = WeaponState.READY


func _tick_reload_timer(delta: float) -> void:
	if _state == WeaponState.RELOADING:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reload_timer = 0.0
			_finish_reload()


func _tick_muzzle_flash(delta: float) -> void:
	if is_instance_valid(_muzzle_flash) and _muzzle_flash.visible:
		_muzzle_timer -= delta
		if _muzzle_timer <= 0.0:
			_muzzle_flash.visible = false


func _tick_spray_tracker(delta: float) -> void:
	_time_since_fired += delta
	if _time_since_fired > SPRAY_RESET_DELAY and _continuous_shots > 0:
		_continuous_shots = 0
		_spray_direction = 1.0 if randf() > 0.5 else -1.0


# =============================================================================
# HELPERS
# =============================================================================

## Returns current ammo info for external display (future HUD).
func get_ammo_info() -> Dictionary:
	return {
		"current": _current_ammo,
		"reserve": _reserve_ammo,
		"state"  : WeaponState.keys()[_state]
	}


## Evaluates procedural reload keyframes across normalized progress [0.0, 1.0] using smoothstep blending.
func _sample_reload_pose(p: float) -> Dictionary:
	var clamped_p : float = clampf(p, 0.0, 1.0)
	for i in range(RELOAD_KEYFRAMES.size() - 1):
		var k0 : Dictionary = RELOAD_KEYFRAMES[i]
		var k1 : Dictionary = RELOAD_KEYFRAMES[i + 1]
		var t0 : float = float(k0["t"])
		var t1 : float = float(k1["t"])
		if clamped_p >= t0 and clamped_p <= t1:
			var segment_len : float = maxf(t1 - t0, 0.0001)
			var local_t : float = (clamped_p - t0) / segment_len
			# Cubic smoothstep for fluid arcade acceleration & deceleration between key poses
			var smooth_t : float = local_t * local_t * (3.0 - 2.0 * local_t)
			var p0 : Vector3 = k0["pos"]
			var p1 : Vector3 = k1["pos"]
			var r0 : Vector3 = k0["rot"]
			var r1 : Vector3 = k1["rot"]
			return {
				"pos": p0.lerp(p1, smooth_t),
				"rot": r0.lerp(r1, smooth_t)
			}
	return { "pos": Vector3.ZERO, "rot": Vector3.ZERO }


# =============================================================================
# FIRST-PERSON WEAPON MOTION
# =============================================================================
func _update_weapon_motion(delta: float) -> void:
	if not is_instance_valid(_weapon_visual):
		return

	# 1. Idle Sway (organic breathing swing)
	_idle_timer += delta * IDLE_SWAY_FREQ
	var idle_pos := Vector3(
		sin(_idle_timer) * IDLE_SWAY_POS_X,
		sin(_idle_timer * 2.0) * IDLE_SWAY_POS_Y,
		cos(_idle_timer) * IDLE_SWAY_POS_Z
	)
	var idle_rot := Vector3(
		sin(_idle_timer * 2.0) * IDLE_SWAY_ROT_X,
		cos(_idle_timer) * IDLE_SWAY_ROT_Y,
		sin(_idle_timer) * IDLE_SWAY_ROT_Z
	)

	# 2. Player State & Speed Extraction
	var is_moving := false
	var is_sprinting := false
	var is_crouching := false
	var ground_speed := 0.0
	var speed_ratio := 0.0

	if is_instance_valid(_player) and _player.has_method("is_alive") and _player.is_alive():
		var h_vel := Vector2(_player.velocity.x, _player.velocity.z)
		ground_speed = h_vel.length()
		var on_floor : bool = _player.is_on_floor()

		# Player movement states: 0=WALK, 1=SPRINT, 2=CROUCH, 3=SLIDE, 4=AIR
		var p_state = _player.get("_state")
		if p_state != null:
			is_sprinting = (int(p_state) == 1) and on_floor and ground_speed > 0.5
			is_crouching = (int(p_state) == 2 or int(p_state) == 3) # CROUCH or SLIDE

		if on_floor and ground_speed > 0.1:
			is_moving = true
			var ref_speed : float = float(_player.get("WALK_SPEED")) if _player.get("WALK_SPEED") != null else 7.0
			speed_ratio = clampf(ground_speed / ref_speed, 0.0, 1.6)

	# 3. Walking Bob Calculation (Natural Lissajous Stride Gait)
	var target_bob_pos := Vector3.ZERO
	var target_bob_rot := Vector3.ZERO

	if is_moving and not is_sprinting:
		_bob_timer += delta * ground_speed * BOB_FREQ_WALK
		target_bob_pos = Vector3(
			sin(_bob_timer) * BOB_POS_X * speed_ratio,
			-abs(cos(_bob_timer)) * BOB_POS_Y * speed_ratio,
			cos(_bob_timer) * BOB_POS_Z * speed_ratio
		)
		target_bob_rot = Vector3(
			sin(_bob_timer * 2.0) * BOB_ROT_X * speed_ratio,
			-sin(_bob_timer) * BOB_ROT_Y * speed_ratio,
			cos(_bob_timer) * BOB_ROT_Z * speed_ratio
		)

	_current_bob_pos = _current_bob_pos.lerp(target_bob_pos, BOB_LERP_SPEED * delta)
	_current_bob_rot = _current_bob_rot.lerp(target_bob_rot, BOB_LERP_SPEED * delta)

	# 4. Sprint Presentation (Tactical Low-Ready Pose + Dynamic Jog Pump)
	var target_sprint_weight : float = 1.0 if is_sprinting else 0.0
	_sprint_weight = lerpf(_sprint_weight, target_sprint_weight, SPRINT_LERP_SPEED * delta)

	if is_sprinting:
		_sprint_timer += delta * ground_speed * SPRINT_FREQ_PUMP

	var sprint_jog_pos := Vector3(
		cos(_sprint_timer) * SPRINT_PUMP_POS_X,
		sin(_sprint_timer * 2.0) * SPRINT_PUMP_POS_Y,
		sin(_sprint_timer) * SPRINT_PUMP_POS_Z
	)
	var sprint_jog_rot := Vector3(
		sin(_sprint_timer * 2.0) * SPRINT_PUMP_ROT_X,
		cos(_sprint_timer) * SPRINT_PUMP_ROT_Y,
		cos(_sprint_timer) * SPRINT_PUMP_ROT_Z
	)

	_current_sprint_pos = (SPRINT_POS_BASE + sprint_jog_pos) * _sprint_weight
	_current_sprint_rot = (SPRINT_ROT_BASE + sprint_jog_rot) * _sprint_weight

	# 5. Crouch Presentation (Natural Subtle Compression)
	var target_crouch_pos := CROUCH_POS_OFFSET if is_crouching else Vector3.ZERO
	var target_crouch_rot := CROUCH_ROT_OFFSET if is_crouching else Vector3.ZERO
	_current_crouch_pos = _current_crouch_pos.lerp(target_crouch_pos, CROUCH_LERP_SPEED * delta)
	_current_crouch_rot = _current_crouch_rot.lerp(target_crouch_rot, CROUCH_LERP_SPEED * delta)

	# 6. Mouse Look Sway (Viewmodel Rotational Inertia / Lag)
	var target_look_pos := Vector3.ZERO
	var target_look_rot := Vector3.ZERO

	if is_instance_valid(_camera):
		var cam_rot := _camera.global_rotation
		if _has_last_cam_rot:
			var d_yaw   : float = wrapf(cam_rot.y - _last_cam_rot.y, -PI, PI)
			var d_pitch : float = wrapf(cam_rot.x - _last_cam_rot.x, -PI, PI)

			target_look_rot.y = clampf(-d_yaw * LOOK_SWAY_ROT_SCALE, -MAX_LOOK_SWAY_ROT, MAX_LOOK_SWAY_ROT)
			target_look_rot.x = clampf(-d_pitch * LOOK_SWAY_ROT_SCALE, -MAX_LOOK_SWAY_ROT, MAX_LOOK_SWAY_ROT)
			target_look_rot.z = clampf(-d_yaw * LOOK_SWAY_ROT_SCALE * 0.75, -MAX_LOOK_SWAY_ROT, MAX_LOOK_SWAY_ROT)

			target_look_pos.x = clampf(-d_yaw * LOOK_SWAY_POS_SCALE, -MAX_LOOK_SWAY_POS, MAX_LOOK_SWAY_POS)
			target_look_pos.y = clampf(d_pitch * LOOK_SWAY_POS_SCALE, -MAX_LOOK_SWAY_POS, MAX_LOOK_SWAY_POS)

		_last_cam_rot = cam_rot
		_has_last_cam_rot = true

	_current_look_sway_pos = _current_look_sway_pos.lerp(target_look_pos, LOOK_SWAY_LERP_SPEED * delta)
	_current_look_sway_rot = _current_look_sway_rot.lerp(target_look_rot, LOOK_SWAY_LERP_SPEED * delta)

	# 7. Procedural Firing Kick Decay
	_current_kick_pos = _current_kick_pos.lerp(Vector3.ZERO, KICK_LERP_SPEED * delta)
	_current_kick_rot = _current_kick_rot.lerp(Vector3.ZERO, KICK_LERP_SPEED * delta)

	# 8. Viewmodel Firing Vibration Calculation
	_vibration_trauma = lerpf(_vibration_trauma, 0.0, VIBRATION_DECAY * delta)
	var vib_pos := Vector3.ZERO
	var vib_rot := Vector3.ZERO
	if _vibration_trauma > 0.001:
		_vibration_timer += delta * VIBRATION_FREQ
		vib_pos = Vector3(
			sin(_vibration_timer * 1.1) * cos(_vibration_timer * 0.7) * VIBRATION_POS_MAG.x,
			cos(_vibration_timer * 1.3) * sin(_vibration_timer * 0.8) * VIBRATION_POS_MAG.y,
			sin(_vibration_timer * 1.7) * VIBRATION_POS_MAG.z
		) * _vibration_trauma
		vib_rot = Vector3(
			sin(_vibration_timer * 1.4) * VIBRATION_ROT_MAG.x,
			cos(_vibration_timer * 1.2) * VIBRATION_ROT_MAG.y,
			sin(_vibration_timer * 1.6) * VIBRATION_ROT_MAG.z
		) * _vibration_trauma

	# 9. Procedural Reload Presentation
	var target_reload_pos := Vector3.ZERO
	var target_reload_rot := Vector3.ZERO
	if _state == WeaponState.RELOADING:
		var reload_duration : float = maxf(data.reload_time, 0.001)
		var progress : float = clampf(1.0 - (_reload_timer / reload_duration), 0.0, 1.0)
		var sampled : Dictionary = _sample_reload_pose(progress)
		target_reload_pos = sampled["pos"]
		target_reload_rot = sampled["rot"]
		_current_reload_pos = _current_reload_pos.lerp(target_reload_pos, 28.0 * delta)
		_current_reload_rot = _current_reload_rot.lerp(target_reload_rot, 28.0 * delta)
	else:
		_current_reload_pos = _current_reload_pos.lerp(Vector3.ZERO, 16.0 * delta)
		_current_reload_rot = _current_reload_rot.lerp(Vector3.ZERO, 16.0 * delta)

	# 10. Aim Down Sights (ADS) Alignment Offset & Motion Damping
	# Dampen sway, bob, and look inertia during ADS for steady, precise aim
	var ads_damped_idle_pos := idle_pos * lerpf(1.0, ADS_SWAY_DAMP, _ads_weight)
	var ads_damped_idle_rot := idle_rot * lerpf(1.0, ADS_SWAY_DAMP, _ads_weight)
	var ads_damped_bob_pos := _current_bob_pos * lerpf(1.0, ADS_BOB_DAMP, _ads_weight)
	var ads_damped_bob_rot := _current_bob_rot * lerpf(1.0, ADS_BOB_DAMP, _ads_weight)
	var ads_damped_look_pos := _current_look_sway_pos * lerpf(1.0, ADS_LOOK_DAMP, _ads_weight)
	var ads_damped_look_rot := _current_look_sway_rot * lerpf(1.0, ADS_LOOK_DAMP, _ads_weight)

	var ads_pos_target := ADS_POS_OFFSET
	if is_instance_valid(_optic_point):
		ads_pos_target = Vector3(0.0, 0.0, -0.25) - _base_optic_transform.origin
	var current_ads_pos := ads_pos_target * _ads_weight
	var current_ads_rot := ADS_ROT_OFFSET * _ads_weight

	# 11. Composite Final Transform Offset
	var total_pos := ads_damped_idle_pos + ads_damped_bob_pos + _current_sprint_pos + _current_crouch_pos + ads_damped_look_pos + _current_kick_pos + vib_pos + _current_reload_pos + current_ads_pos
	var total_rot := ads_damped_idle_rot + ads_damped_bob_rot + _current_sprint_rot + _current_crouch_rot + ads_damped_look_rot + _current_kick_rot + vib_rot + _current_reload_rot + current_ads_rot
	var rot_basis := Basis.from_euler(total_rot)

	# Apply smoothly to visual nodes while strictly preserving their authored base transforms
	_weapon_visual.transform.origin = _base_visual_transform.origin + total_pos
	_weapon_visual.transform.basis = rot_basis * _base_visual_transform.basis

	if is_instance_valid(_muzzle_flash):
		var flash_roll_basis := Basis(Vector3(0, 0, 1), _flash_roll_angle)
		var flash_base_basis := rot_basis * _base_muzzle_transform.basis * flash_roll_basis
		_muzzle_flash.transform.origin = _base_muzzle_transform.origin + total_pos
		_muzzle_flash.transform.basis = flash_base_basis.scaled(Vector3.ONE * _flash_scale_mod)

	if is_instance_valid(_right_grip):
		_right_grip.transform.origin = _base_right_grip_transform.origin + total_pos
		_right_grip.transform.basis = rot_basis * _base_right_grip_transform.basis

	if is_instance_valid(_left_grip):
		_left_grip.transform.origin = _base_left_grip_transform.origin + total_pos
		_left_grip.transform.basis = rot_basis * _base_left_grip_transform.basis

	if is_instance_valid(_optic_point):
		_optic_point.transform.origin = _base_optic_transform.origin + total_pos
		_optic_point.transform.basis = rot_basis * _base_optic_transform.basis
