extends CharacterBody3D

# =============================================================================
# Project FPS — BasicBot
# Milestone 4 — Basic Bot
#
# A reliable combat opponent featuring:
# - Finite state machine (IDLE, SEARCH, CHASE, ATTACK, DEAD)
# - Robust perception with accurate Line-of-Sight raycast
# - NavigationAgent3D pathfinding with seamless direct-chase fallback
# - Smooth rotation aiming with configurable aim error & reaction delay
# - Hitscan weapon firing with reload cycle and damage delivery
# - Health component integration with hit flash, death state, and 2.5s respawn
# - Runtime debug visuals (3D State label & 3D HP label)
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURABLE PARAMETERS (Tune in Inspector)
# -----------------------------------------------------------------------------
@export_group("Bot Stats")
@export var max_health            : float = 100.0
@export var move_speed            : float = 4.5    # m/s
@export var turn_speed            : float = 6.0    # lerp rotation speed (rad/s)
@export var gravity               : float = 20.0   # m/s² downward pull

@export_group("Perception & Combat")
@export var detection_range       : float = 25.0   # meters
@export var combat_range_min      : float = 6.0    # meters (maintain distance / back up)
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
@onready var _state_label : Label3D          = $StateLabel

# -----------------------------------------------------------------------------
# STATE MACHINE
# -----------------------------------------------------------------------------
enum State { IDLE, SEARCH, CHASE, ATTACK, DEAD }

var _state          : State   = State.SEARCH
var _player         : Node3D  = null
var _spawn_position : Vector3 = Vector3.ZERO

# Perception / logging tracking
var _player_detected_logged : bool = false

# Combat / weapon runtime state
var _current_ammo    : int     = 15
var _is_reloading    : bool    = false
var _fire_timer      : float   = 0.0
var _reload_timer    : float   = 0.0
var _reaction_timer  : float   = 0.0
var _has_los         : bool    = false
var _muzzle_timer    : float   = 0.0
var _deflect_timer   : float   = 0.0
var _deflect_dir     : Vector3 = Vector3.ZERO

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
	_update_state_label()


func _collect_mesh_instances(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_instances.append(node)
		_orig_materials.append(node.material_override)
	for child in node.get_children():
		_collect_mesh_instances(child)


# =============================================================================
# STATE MANAGEMENT
# =============================================================================
func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	print("[BOT STATE] %s -> %s" % [State.keys()[_state], State.keys()[new_state]])
	_state = new_state
	_update_state_label()


func _update_state_label() -> void:
	if is_instance_valid(_state_label):
		_state_label.text = "STATE: " + State.keys()[_state]
		match _state:
			State.IDLE, State.SEARCH:
				_state_label.modulate = Color(0.4, 0.9, 1.0, 1.0)  # Cyan
			State.CHASE:
				_state_label.modulate = Color(1.0, 0.8, 0.2, 1.0)  # Yellow
			State.ATTACK:
				_state_label.modulate = Color(1.0, 0.2, 0.2, 1.0)  # Red
			State.DEAD:
				_state_label.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Gray


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
		_set_state(State.IDLE)
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

	# Detection check & non-spamming logging
	if dist <= detection_range:
		if not _player_detected_logged:
			_player_detected_logged = true
			print("[BOT] Player detected (Distance: %.1fm)" % dist)
	else:
		if _player_detected_logged:
			_player_detected_logged = false
			print("[BOT] Player lost (Distance: %.1fm)" % dist)

	# Check Line of Sight
	_has_los = _check_line_of_sight(player_pos)

	# If target is dead, hold fire and enter Search
	if _player.get("_is_dead") or (_player.has_node("Health") and _player.get_node("Health").is_dead):
		_set_state(State.SEARCH)
		_reaction_timer = reaction_delay
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		return

	# Outside detection range -> Search / Idle
	if dist > detection_range:
		_set_state(State.SEARCH)
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
			_set_state(State.CHASE)
			_navigate_toward(player_pos, delta)
		elif dist < combat_range_min:
			# Too close: Back up slowly while firing
			_set_state(State.ATTACK)
			var away_dir := (global_position - player_pos).normalized()
			away_dir.y = 0.0
			velocity.x = away_dir.x * (move_speed * 0.5)
			velocity.z = away_dir.z * (move_speed * 0.5)
			if _reaction_timer <= 0.0:
				_try_fire()
		else:
			# In ideal combat range: Stand ground & fire
			_set_state(State.ATTACK)
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
			if _reaction_timer <= 0.0:
				_try_fire()
	else:
		# Player in range but blocked by obstacles -> Navigate to player
		_reaction_timer = reaction_delay
		_set_state(State.CHASE)
		_navigate_toward(player_pos, delta)


func _check_line_of_sight(target_pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false

	# Eye position at bot's head (y=1.4m)
	var eye_pos := global_position + Vector3(0.0, 1.4, 0.0)
	# Target position at player's torso center (player origin is at y=0.9m)
	var player_target := target_pos + Vector3(0.0, 0.1, 0.0)

	var query := PhysicsRayQueryParameters3D.create(eye_pos, player_target)
	query.exclude = [self]
	var result := space.intersect_ray(query)

	if result.is_empty():
		return false

	var collider = result.collider
	if collider == _player:
		return true
	if collider is Node and (collider.get_parent() == _player or collider.is_in_group("player") or str(collider.name) == "Player"):
		return true

	return false


func _navigate_toward(target_pos: Vector3, delta: float) -> void:
	# Update navigation agent target
	_nav_agent.target_position = target_pos

	var move_dir := Vector3.ZERO

	if _deflect_timer > 0.0:
		_deflect_timer -= delta
		move_dir = _deflect_dir
	else:
		var next_pos := _nav_agent.get_next_path_position()
		var dist_to_next := global_position.distance_to(next_pos)

		if dist_to_next > 0.2 and not _nav_agent.is_navigation_finished():
			move_dir = (next_pos - global_position).normalized()
		else:
			# Direct fallback toward target
			move_dir = (target_pos - global_position).normalized()

	move_dir.y = 0.0

	# If colliding with a wall/obstacle while moving, deflect along the wall
	if is_on_wall():
		var wall_n := get_wall_normal()
		var slid := move_dir.slide(wall_n).normalized()
		if slid.length_squared() > 0.05:
			move_dir = slid
			_deflect_dir = slid
			_deflect_timer = 0.4
		else:
			# Head-on collision: steer perpendicular along obstacle edge
			var tangent := wall_n.cross(Vector3.UP).normalized()
			var pos_a := global_position + tangent
			var pos_b := global_position - tangent
			if pos_a.distance_squared_to(target_pos) < pos_b.distance_squared_to(target_pos):
				move_dir = tangent
			else:
				move_dir = -tangent
			_deflect_dir = move_dir
			_deflect_timer = 0.5

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	_rotate_toward(target_pos, delta)


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
	var player_target := _player.global_position + Vector3(0.0, 0.1, 0.0)
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
	# If attacked while idle or searching, immediately alert bot to player
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
	_set_state(State.DEAD)
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	_visuals.visible = false
	_hp_label.visible = false
	_state_label.visible = false

	var killer_name : String = str(killer.name) if killer else "World"
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
	_current_ammo = magazine_size
	_is_reloading = false
	_fire_timer = 0.0
	_reaction_timer = reaction_delay
	_player_detected_logged = false
	_collision.set_deferred("disabled", false)
	_visuals.visible = true
	_hp_label.visible = true
	_state_label.visible = true
	_update_hp_label()
	_set_state(State.SEARCH)
	print("[BOT RESPAWN] Bot respawned at %s. HP: %.0f/%.0f" % [
		str(_spawn_position),
		_health.current_health if _health else 100.0,
		_health.max_health if _health else 100.0
	])


func _update_hp_label() -> void:
	if is_instance_valid(_hp_label) and _health:
		_hp_label.text = "%.0f / %.0f HP" % [_health.current_health, _health.max_health]
