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
@onready var _muzzle_flash  : Node3D       = $WeaponMesh/MuzzleFlash

# Debug: temporary Label3D showing ammo (hidden in production).
@onready var _ammo_label    : Label3D      = $AmmoLabel

# Reference to the Player and Camera3D so recoil can be applied cleanly.
var _player : CharacterBody3D = null
var _camera : Camera3D        = null


# -----------------------------------------------------------------------------
# WEAPON STATE
# -----------------------------------------------------------------------------
enum WeaponState { READY, FIRING, RELOADING }

var _state           : WeaponState = WeaponState.READY
var _current_ammo    : int         = 0
var _reserve_ammo    : int         = 0
var _fire_timer      : float       = 0.0   # countdown to next allowed shot
var _reload_timer    : float       = 0.0   # countdown to reload completion

# Muzzle flash visibility timer.
var _muzzle_timer    : float       = 0.0
const MUZZLE_FLASH_DURATION : float = 0.05  # seconds

# Spray tracking for recoil personality & directional tendency
var _continuous_shots   : int   = 0
var _spray_direction    : float = 1.0    # 1.0 (rightward bias) or -1.0 (leftward bias)
var _time_since_fired   : float = 0.0
const SPRAY_RESET_DELAY : float = 0.25   # seconds after last shot to reset continuous spray count


# =============================================================================
# SETUP
# =============================================================================
func _ready() -> void:
	if data == null:
		push_error("WeaponBase: no WeaponData assigned — weapon will not function.")
		return
	_current_ammo = data.magazine_size
	_reserve_ammo = data.reserve_ammo
	# RayCast3D length set from weapon data range.
	_raycast.target_position = Vector3(0.0, 0.0, -data.range_meters)
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false
	_update_ammo_label()


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
	if data == null:
		return

	_tick_fire_timer(delta)
	_tick_reload_timer(delta)
	_tick_muzzle_flash(delta)
	_tick_spray_tracker(delta)


# =============================================================================
# PUBLIC API — called by the player controller
# =============================================================================

## Attempt to fire. Called every frame while fire input is held (automatic).
## For semi-auto, call only on just_pressed.
func try_fire() -> void:
	if data == null:
		return
	if _state == WeaponState.RELOADING:
		return
	if _fire_timer > 0.0:
		return

	if _current_ammo <= 0:
		_dry_fire()
		return

	_fire()


## Attempt to reload. Called when reload input is pressed.
func try_reload() -> void:
	if data == null:
		return
	if _state == WeaponState.RELOADING:
		return
	if _current_ammo == data.magazine_size:
		return  # already full
	if _reserve_ammo <= 0:
		return  # nothing to reload from

	_start_reload()


# =============================================================================
# FIRE
# =============================================================================
func _fire() -> void:
	_state = WeaponState.FIRING
	_current_ammo -= 1
	_fire_timer = 1.0 / data.fire_rate
	_time_since_fired = 0.0

	# Hitscan
	_do_hitscan()

	# Recoil
	_apply_recoil()

	# Muzzle flash
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = true
		_muzzle_timer = MUZZLE_FLASH_DURATION

	_update_ammo_label()
	print("[Weapon] Fired. Ammo: %d / %d" % [_current_ammo, _reserve_ammo])


func _dry_fire() -> void:
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
		var hit_name     : String = hit_collider.name if hit_collider else "unknown"

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

			# Dispatch damage cleanly through damageable interface
			if hit_collider.has_method("take_damage"):
				hit_collider.take_damage(dmg_info)
			elif hit_collider.has_node("Health"):
				var health_node = hit_collider.get_node("Health")
				if health_node and health_node.has_method("take_damage"):
					health_node.take_damage(dmg_info)
			elif hit_collider.get_parent() and hit_collider.get_parent().has_method("take_damage"):
				hit_collider.get_parent().take_damage(dmg_info)

		# Spawn a brief impact marker at the hit point.
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
	print("[Weapon] Reloading... (%.1fs)" % data.reload_time)


func _finish_reload() -> void:
	var needed : int = data.magazine_size - _current_ammo
	var taken  : int = min(needed, _reserve_ammo)
	_current_ammo += taken
	_reserve_ammo -= taken
	_state = WeaponState.READY
	_update_ammo_label()
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
func _update_ammo_label() -> void:
	if is_instance_valid(_ammo_label):
		_ammo_label.text = "%d / %d" % [_current_ammo, _reserve_ammo]


## Returns current ammo info for external display (future HUD).
func get_ammo_info() -> Dictionary:
	return {
		"current": _current_ammo,
		"reserve": _reserve_ammo,
		"state"  : WeaponState.keys()[_state]
	}
