extends CharacterBody3D

# =============================================================================
# Project FPS — BasicBot
# Milestone 4 — Basic Bot
#
# A simple combat opponent featuring:
# - Finite state machine (IDLE, SEARCH, CHASE, ATTACK, DEAD)
# - NavigationAgent3D pathfinding around obstacles
# - Line-of-sight raycast detection
# - Configurable aim error & reaction delay
# - Hitscan weapon firing with reload cycle and damage delivery
# - Health component integration with death, damage flash, and respawn
# =============================================================================

const DamageInfo = preload("res://scripts/systems/damage_info.gd")
const HealthScript = preload("res://scripts/systems/health.gd")

# -----------------------------------------------------------------------------
# CONFIGURABLE PARAMETERS (Tune in Inspector)
# -----------------------------------------------------------------------------
@export_group("Bot Stats")
@export var max_health            : float = 100.0
@export var move_speed            : float = 4.5    # m/s
@export var turn_speed            : float = 6.0    # lerp rotation speed
@export var gravity               : float = 20.0   # m/s² downward pull

@export_group("Perception & Combat")
@export var detection_range       : float = 25.0   # meters
@export var combat_range_min      : float = 6.0    # meters (maintain distance)
@export var combat_range_max      : float = 16.0   # meters (chase if farther)
@export var attack_fire_rate      : float = 5.0    # rounds per second
@export var attack_damage         : float = 8.0    # damage per shot
@export var attack_spread_degrees : float = 3.0    # aim inaccuracy in degrees
@export var reaction_delay        : float = 0.35   # seconds to react after seeing player
@export var magazine_size         : int   = 15     # rounds per mag
@export var reload_time           : float = 2.0    # seconds to reload
@export var respawn_delay         : float = 2.5    # seconds to respawn after death

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var _health      : Health           = $Health
@onready var _collision   : CollisionShape3D = $CollisionShape3D
@onready var _nav_agent   : NavigationAgent3D = $NavigationAgent3D
@onready var _visuals     : Node3D           = $Visuals
@onready var _muzzle      : Node3D           = $Visuals/WeaponMesh/Muzzle
@onready var _muzzle_flash: MeshInstance3D   = $Visuals/WeaponMesh/Muzzle/Flash
@onready var _hp_label    : Label3D          = $HPLabel

# -----------------------------------------------------------------------------
# STATE MACHINE
# -----------------------------------------------------------------------------
enum State { IDLE, SEARCH, CHASE, ATTACK, DEAD }

var _state          : State   = State.IDLE
var _player         : Node3D  = null
var _spawn_position : Vector3 = Vector3.ZERO

# Combat / weapon runtime state
var _current_ammo    : int     = 15
var _is_reloading    : bool    = false
var _fire_timer      : float   = 0.0
var _reload_timer    : float   = 0.0
var _reaction_timer  : float   = 0.0
var _has_los         : bool    = false
var _muzzle_timer    : float   = 0.0

# Damage flash materials
var _mesh_instances : Array[MeshInstance3D] = []
var _orig_materials : Array[Material] = []
var _flash_material : StandardMaterial3D = null


# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	_spawn_position = global_position
	_current_ammo = magazine_size
	_reaction_timer = reaction_delay

	# Setup Health component
	if _health:
		_health.max_health = max_health
		_health.current_health = max_health
		_health.damage_received.connect(_on_damage_received)
		_health.died.connect(_on_died)
		_health.respawned.connect(_on_respawned)

	# Setup hit flash material
	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = Color(1.0, 1.0, 0.4, 1.0)
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_collect_mesh_instances(_visuals)

	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false

	_update_hp_label()


func _collect_mesh_instances(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_instances.append(node)
		_orig_materials.append(node.material_override)
	for child in node.get_children():
		_collect_mesh_instances(child)


# =============================================================================
# PHYSICS PROCESS
# =============================================================================
func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		if not is_on_floor():
			velocity.y -= gravity * delta
			move_and_slide()
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	_acquire_player()
	_tick_timers(delta)

	if _player and is_instance_valid(_player):
		_process_ai(delta)
	else:
		_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)

	move_and_slide()


# =============================================================================
# AI & PERCEPTION
# =============================================================================
func _acquire_player() -> void:
	if _player == null or not is_instance_valid(_player):
		var tree := get_tree()
		if tree:
			var nodes := tree.get_nodes_in_group("player")
			if nodes.size() > 0:
				_player = nodes[0] as Node3D
		if _player == null:
			if get_tree() and get_tree().current_scene and get_tree().current_scene.has_node("Player"):
				_player = get_tree().current_scene.get_node("Player") as Node3D
			elif get_parent() and get_parent().has_node("Player"):
				_player = get_parent().get_node("Player") as Node3D


func _process_ai(delta: float) -> void:
	var player_pos : Vector3 = _player.global_position
	var dist : float = global_position.distance_to(player_pos)

	# Check Line of Sight
	_has_los = _check_line_of_sight(player_pos)

	# Outside detection range -> Idle / Search
	if dist > detection_range:
		_state = State.SEARCH
		_reaction_timer = reaction_delay
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		return

	# Inside detection range
	if _has_los:
		# Reaction delay countdown before attacking
		if _reaction_timer > 0.0:
			_reaction_timer -= delta

		_rotate_toward(player_pos, delta)

		if dist > combat_range_max:
			# Too far: Chase player
			_state = State.CHASE
			_navigate_toward(player_pos, delta)
		elif dist < combat_range_min:
			# Too close: Back up slowly while firing
			_state = State.ATTACK
			var away_dir := (global_position - player_pos).normalized()
			away_dir.y = 0.0
			velocity.x = away_dir.x * (move_speed * 0.5)
			velocity.z = away_dir.z * (move_speed * 0.5)
			if _reaction_timer <= 0.0:
				_try_fire()
		else:
			# In ideal combat range: Stand ground & fire
			_state = State.ATTACK
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
			if _reaction_timer <= 0.0:
				_try_fire()
	else:
		# Player in range but blocked by obstacles -> Navigate to player
		_reaction_timer = reaction_delay
		_state = State.CHASE
		_navigate_toward(player_pos, delta)


func _check_line_of_sight(target_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var eye_pos := global_position + Vector3(0.0, 1.4, 0.0)
	var player_target := target_pos + Vector3(0.0, 1.2, 0.0)

	var query := PhysicsRayQueryParameters3D.create(eye_pos, player_target)
	query.exclude = [self]
	var result := space.intersect_ray(query)

	if result.is_empty():
		return false

	var collider = result.collider
	if collider == _player or (collider is Node and collider.get_parent() == _player):
		return true

	return false


func _navigate_toward(target_pos: Vector3, delta: float) -> void:
	_nav_agent.target_position = target_pos
	if _nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		return

	var next_pos := _nav_agent.get_next_path_position()
	var move_dir := (next_pos - global_position).normalized()
	move_dir.y = 0.0

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	_rotate_toward(next_pos, delta)


func _rotate_toward(target_pos: Vector3, delta: float) -> void:
	var look_dir := (target_pos - global_position).normalized()
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.001:
		var target_yaw := atan2(-look_dir.x, -look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)


# =============================================================================
# TIMERS
# =============================================================================
func _tick_timers(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta

	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_current_ammo = magazine_size
			_is_reloading = false
			print("[BOT] Reloaded. Ammo: %d/%d" % [_current_ammo, magazine_size])

	if is_instance_valid(_muzzle_flash) and _muzzle_flash.visible:
		_muzzle_timer -= delta
		if _muzzle_timer <= 0.0:
			_muzzle_flash.visible = false


# =============================================================================
# FIRING & DAMAGE DELIVERY
# =============================================================================
func _try_fire() -> void:
	if _is_reloading:
		return
	if _current_ammo <= 0:
		_start_reload()
		return
	if _fire_timer > 0.0:
		return

	_fire()


func _start_reload() -> void:
	_is_reloading = true
	_reload_timer = reload_time
	print("[BOT] Reloading... (%.1fs)" % reload_time)


func _fire() -> void:
	_fire_timer = 1.0 / attack_fire_rate
	_current_ammo -= 1

	# Calculate muzzle origin & direction toward player with aim inaccuracy
	var muzzle_pos := _muzzle.global_position if is_instance_valid(_muzzle) else global_position + Vector3(0.0, 1.2, 0.0)
	var player_target := _player.global_position + Vector3(0.0, 1.1, 0.0)
	var aim_dir := (player_target - muzzle_pos).normalized()

	# Add random angular spread
	var spread_rad := deg_to_rad(attack_spread_degrees)
	var spread_x := randf_range(-spread_rad, spread_rad)
	var spread_y := randf_range(-spread_rad, spread_rad)

	# Transform aim direction by spread angles
	var right := aim_dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var up := right.cross(aim_dir).normalized()
	var final_dir := (aim_dir + right * spread_x + up * spread_y).normalized()

	# Cast hitscan ray
	var space := get_world_3d().direct_space_state
	var ray_end := muzzle_pos + final_dir * 60.0
	var query := PhysicsRayQueryParameters3D.create(muzzle_pos, ray_end)
	query.exclude = [self]
	var result := space.intersect_ray(query)

	# Muzzle flash feedback
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = true
		_muzzle_timer = 0.05

	print("[BOT FIRE] Fired. Ammo: %d/%d" % [_current_ammo, magazine_size])

	if not result.is_empty():
		var hit_collider = result.collider
		var hit_point : Vector3 = result.position
		var hit_normal : Vector3 = result.normal

		if hit_collider:
			var dmg_info := DamageInfo.new()
			dmg_info.amount = attack_damage
			dmg_info.attacker = self
			dmg_info.hit_position = hit_point
			dmg_info.hit_normal = hit_normal
			dmg_info.hit_direction = final_dir
			dmg_info.hit_type = DamageInfo.HitType.BODY

			if hit_collider.has_method("take_damage"):
				hit_collider.take_damage(dmg_info)
			elif hit_collider.has_node("Health"):
				var h_node = hit_collider.get_node("Health")
				if h_node and h_node.has_method("take_damage"):
					h_node.take_damage(dmg_info)
			elif hit_collider.get_parent() and hit_collider.get_parent().has_method("take_damage"):
				hit_collider.get_parent().take_damage(dmg_info)


# =============================================================================
# HEALTH & DAMAGE RECEPTION
# =============================================================================

## Damageable interface entrypoint
func take_damage(info: DamageInfo) -> void:
	if _state == State.DEAD:
		return
	if _health:
		_health.take_damage(info)
	elif has_node("Health"):
		_health = $Health
		_health.take_damage(info)


func _on_damage_received(_info: DamageInfo, _current_hp: float, _max_hp: float) -> void:
	_update_hp_label()
	_flash_hit()
	# If attacked while idle, immediately alert to player
	if _state == State.IDLE or _state == State.SEARCH:
		_reaction_timer = 0.0


func _flash_hit() -> void:
	for mesh_inst in _mesh_instances:
		if is_instance_valid(mesh_inst):
			mesh_inst.material_override = _flash_material
	await get_tree().create_timer(0.08).timeout
	for i in range(_mesh_instances.size()):
		if is_instance_valid(_mesh_instances[i]):
			_mesh_instances[i].material_override = _orig_materials[i]


func _on_died(killer: Node) -> void:
	_state = State.DEAD
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	_visuals.visible = false
	_hp_label.visible = false

	var killer_name : String = killer.name if killer else "World"
	print("[BOT DEATH] Bot killed by %s" % killer_name)

	# Respawn after delay
	var timer := get_tree().create_timer(respawn_delay)
	timer.timeout.connect(_do_respawn)


func _do_respawn() -> void:
	if _health:
		_health.respawn()


func _on_respawned() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_state = State.SEARCH
	_current_ammo = magazine_size
	_is_reloading = false
	_fire_timer = 0.0
	_reaction_timer = reaction_delay
	_collision.set_deferred("disabled", false)
	_visuals.visible = true
	_hp_label.visible = true
	_update_hp_label()
	print("[BOT RESPAWN] Bot respawned at %s. HP: %.0f/%.0f" % [
		str(_spawn_position),
		_health.current_health if _health else 100.0,
		_health.max_health if _health else 100.0
	])


func _update_hp_label() -> void:
	if is_instance_valid(_hp_label) and _health:
		_hp_label.text = "%.0f / %.0f HP" % [_health.current_health, _health.max_health]
