extends CharacterBody3D

# =============================================================================
# Project FPS — BasicBot
# Milestone 4 — Basic Bot | Milestone 5 — FFA Foundation
#
# A reliable FFA combat opponent featuring:
# - Combatant interface & group integration
# - Multi-target perception (targets Player or other Bots)
# - Prioritized target selection (Alive > In Range > Line of Sight > Nearest)
# - Finite state machine (IDLE, SEARCH, CHASE, ATTACK, DEAD)
# - NavigationAgent3D pathfinding with seamless direct-chase & deflection fallback
# - Hitscan weapon firing with reload cycle and damage delivery
# - Dynamic respawn via MatchManager spawn points
# - Runtime debug visuals (3D State label & 3D HP label)
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURABLE PARAMETERS (Tune in Inspector)
# -----------------------------------------------------------------------------
@export_group("Bot Stats")
@export var combatant_name        : String = "BasicBot"
@export var max_health            : float  = 100.0
@export var move_speed            : float  = 4.5    # m/s
@export var turn_speed            : float  = 6.0    # lerp rotation speed (rad/s)
@export var gravity               : float  = 20.0   # m/s² downward pull

@export_group("Perception & Combat")
@export var detection_range       : float  = 25.0   # meters
@export var combat_range_min      : float  = 6.0    # meters (maintain distance / back up)
@export var combat_range_max      : float  = 16.0   # meters (chase if farther)
@export var attack_fire_rate      : float  = 5.0    # rounds per second
@export var attack_damage         : float  = 8.0    # damage per shot
@export var attack_spread_degrees : float  = 3.0    # aim inaccuracy in degrees
@export var reaction_delay        : float  = 0.35   # seconds to react after seeing target
@export var magazine_size         : int    = 15     # rounds per mag
@export var reload_time           : float  = 2.0    # seconds to reload
@export var respawn_delay         : float  = 2.5    # seconds to respawn after death

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
# STATE MACHINE & COMBATANT DATA
# -----------------------------------------------------------------------------
enum State { IDLE, SEARCH, CHASE, ATTACK, DEAD }

var _state          : State   = State.SEARCH
var _target         : Node3D  = null
var _spawn_position : Vector3 = Vector3.ZERO
var _is_match_ended : bool    = false

# Combatant Score tracking
var kills  : int = 0
var deaths : int = 0

# Perception & Retargeting
var _retarget_timer : float   = 0.0
const RETARGET_INTERVAL : float = 0.35

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
	add_to_group("combatants")
	_spawn_position = global_position
	_current_ammo = magazine_size
	_reaction_timer = reaction_delay

	if combatant_name == "BasicBot" and name != "BasicBot":
		combatant_name = name

	# Setup Health component
	if _health:
		_health.max_health = max_health
		_health.current_health = max_health
		_health.damage_received.connect(_on_damage_received)
		_health.died.connect(_on_died)
		_health.respawned.connect(_on_respawned)

	# Connect MatchManager signals
	var tree := get_tree()
	if tree:
		var match_mgr = tree.get_first_node_in_group("match_manager")
		if match_mgr and match_mgr.has_signal("match_ended"):
			match_mgr.match_ended.connect(_on_match_ended)

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
# COMBATANT INTERFACE
# =============================================================================

## Returns true if bot is alive.
func is_alive() -> bool:
	return _state != State.DEAD


## Returns target position for aiming and LOS checks (torso center).
func get_target_position() -> Vector3:
	return global_position + Vector3(0.0, 0.8, 0.0)


## Record kill attribution
func record_kill(_target_name: String) -> void:
	kills += 1


## Record death attribution
func record_death(_killer_name: String) -> void:
	deaths += 1


# =============================================================================
# STATE MANAGEMENT
# =============================================================================
func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
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


func _on_match_ended(_winner: Node) -> void:
	_is_match_ended = true
	_target = null
	velocity = Vector3.ZERO
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false


# =============================================================================
# PHYSICS PROCESS
# =============================================================================
func _physics_process(delta: float) -> void:
	if _state == State.DEAD or _is_match_ended:
		if not is_on_floor():
			velocity.y -= gravity * delta
			move_and_slide()
		return

	# Fall / out-of-bounds safety check
	if global_position.y < -7.0:
		var fall_dmg := DamageInfo.new()
		fall_dmg.amount = 9999.0
		fall_dmg.attacker = null
		take_damage(fall_dmg)
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	_tick_timers(delta)
	_update_target_selection(delta)

	if _is_target_valid(_target):
		_process_ai(delta)
	else:
		_set_state(State.SEARCH)
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)

	move_and_slide()


# =============================================================================
# DYNAMIC MULTI-TARGET SELECTION (FFA)
# =============================================================================

func _update_target_selection(delta: float) -> void:
	_retarget_timer -= delta

	# Check if current target is invalid (dead, freed, null, or out of range)
	var current_invalid : bool = not _is_target_valid(_target)

	if current_invalid or _retarget_timer <= 0.0:
		_retarget_timer = RETARGET_INTERVAL
		var best_candidate := _find_best_target()

		if best_candidate != _target:
			if best_candidate != null:
				var target_display_name : String = _get_entity_name(best_candidate)
				print("[TARGET] %s -> %s" % [combatant_name, target_display_name])
			_target = best_candidate
			_reaction_timer = reaction_delay


func _is_target_valid(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or target == self:
		return false

	# Check alive state
	if target.has_method("is_alive"):
		if not target.is_alive():
			return false
	elif target.get("_is_dead") != null and target.get("_is_dead"):
		return false
	elif target.has_node("Health") and target.get_node("Health").is_dead:
		return false

	# Range check with buffer
	var dist := global_position.distance_to(target.global_position)
	if dist > detection_range * 1.3:
		return false

	return true


func _find_best_target() -> Node3D:
	var combatants := get_tree().get_nodes_in_group("combatants")
	var best_with_los : Node3D = null
	var min_dist_los : float = INF

	var best_without_los : Node3D = null
	var min_dist_no_los : float = INF

	for c in combatants:
		if c == self or not (c is Node3D) or not is_instance_valid(c):
			continue

		# Check if candidate is alive
		var alive : bool = true
		if c.has_method("is_alive"):
			alive = c.is_alive()
		elif c.get("_is_dead") != null:
			alive = not c.get("_is_dead")
		elif c.has_node("Health"):
			alive = not c.get_node("Health").is_dead

		if not alive:
			continue

		var dist := global_position.distance_to(c.global_position)
		if dist > detection_range:
			continue

		# Torso-level line of sight check
		var target_pt : Vector3 = c.get_target_position() if c.has_method("get_target_position") else c.global_position + Vector3(0.0, 0.8, 0.0)
		var has_los := _check_line_of_sight(c, target_pt)

		if has_los:
			if dist < min_dist_los:
				min_dist_los = dist
				best_with_los = c
		else:
			if dist < min_dist_no_los:
				min_dist_no_los = dist
				best_without_los = c

	# Prioritize target with Line of Sight, otherwise nearest candidate in range
	if best_with_los != null:
		return best_with_los
	return best_without_los


func _get_entity_name(entity: Node) -> String:
	if entity == null:
		return "None"
	if entity.get("combatant_name"):
		return str(entity.get("combatant_name"))
	return str(entity.name)


# =============================================================================
# AI LOGIC & COMBAT ENGAGEMENT
# =============================================================================
func _process_ai(delta: float) -> void:
	var target_pos : Vector3 = _target.global_position
	var target_torso : Vector3 = _target.get_target_position() if _target.has_method("get_target_position") else target_pos + Vector3(0.0, 0.8, 0.0)
	var dist : float = global_position.distance_to(target_pos)

	# Check Line of Sight
	_has_los = _check_line_of_sight(_target, target_torso)

	if _has_los:
		if _reaction_timer > 0.0:
			_reaction_timer -= delta

		_rotate_toward(target_pos, delta)

		if dist > combat_range_max:
			# Too far: Chase target
			_set_state(State.CHASE)
			_navigate_toward(target_pos, delta)
		elif dist < combat_range_min:
			# Too close: Back up while firing
			_set_state(State.ATTACK)
			var away_dir := (global_position - target_pos).normalized()
			away_dir.y = 0.0
			velocity.x = away_dir.x * (move_speed * 0.5)
			velocity.z = away_dir.z * (move_speed * 0.5)
			if _reaction_timer <= 0.0:
				_try_fire(target_torso)
		else:
			# In ideal combat range: Hold ground & fire
			_set_state(State.ATTACK)
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
			if _reaction_timer <= 0.0:
				_try_fire(target_torso)
	else:
		# Blocked by cover -> Chase toward target position
		_reaction_timer = reaction_delay
		_set_state(State.CHASE)
		_navigate_toward(target_pos, delta)


func _check_line_of_sight(target_node: Node3D, target_pt: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false

	var eye_pos := global_position + Vector3(0.0, 1.4, 0.0)
	var query := PhysicsRayQueryParameters3D.create(eye_pos, target_pt)
	query.exclude = [self]
	var result := space.intersect_ray(query)

	if result.is_empty():
		return false

	var collider = result.collider
	if collider == target_node:
		return true
	if collider is Node and (collider.get_parent() == target_node or collider.is_in_group("combatants")):
		if collider == target_node or collider.get_parent() == target_node:
			return true

	return false


func _navigate_toward(target_pos: Vector3, delta: float) -> void:
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
			move_dir = (target_pos - global_position).normalized()

	move_dir.y = 0.0

	# Wall deflection fallback
	if is_on_wall():
		var wall_n := get_wall_normal()
		var slid := move_dir.slide(wall_n).normalized()
		if slid.length_squared() > 0.05:
			move_dir = slid
			_deflect_dir = slid
			_deflect_timer = 0.4
		else:
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

	if is_instance_valid(_muzzle_flash) and _muzzle_flash.visible:
		_muzzle_timer -= delta
		if _muzzle_timer <= 0.0:
			_muzzle_flash.visible = false


# =============================================================================
# FIRING & DAMAGE DELIVERY
# =============================================================================
func _try_fire(target_aim_pos: Vector3) -> void:
	if _is_match_ended:
		return
	if _is_reloading:
		return
	if _current_ammo <= 0:
		_start_reload()
		return
	if _fire_timer > 0.0:
		return

	_fire(target_aim_pos)


func _start_reload() -> void:
	_is_reloading = true
	_reload_timer = reload_time


func _fire(target_aim_pos: Vector3) -> void:
	_fire_timer = 1.0 / attack_fire_rate
	_current_ammo -= 1

	var muzzle_pos := _muzzle.global_position if is_instance_valid(_muzzle) else global_position + Vector3(0.0, 1.2, 0.0)
	var aim_dir := (target_aim_pos - muzzle_pos).normalized()

	# Audio feedback (3D positional bot gunfire)
	AudioManager.play_3d("bot_fire", muzzle_pos, AudioManager.BUS_SFX, 0.0, 0.06, 50.0, 4.0)

	# Angular aim spread
	var spread_rad := deg_to_rad(attack_spread_degrees)
	var spread_x := randf_range(-spread_rad, spread_rad)
	var spread_y := randf_range(-spread_rad, spread_rad)

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

	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = true
		_muzzle_timer = 0.05

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

		# 3D bullet impact audio in the world
		AudioManager.play_3d("impact", hit_point, AudioManager.BUS_SFX, -3.0, 0.06, 35.0, 3.0)


# =============================================================================
# HEALTH & DAMAGE RECEPTION
# =============================================================================

func take_damage(info: DamageInfo) -> void:
	if _state == State.DEAD or _is_match_ended:
		return
	if _health:
		_health.take_damage(info)
	elif has_node("Health"):
		_health = $Health
		_health.take_damage(info)


func _on_damage_received(info: DamageInfo, _current_hp: float, _max_hp: float) -> void:
	_update_hp_label()
	_flash_hit()

	# Audio feedback (3D positional bot hit/damage)
	var hit_pos : Vector3 = info.hit_position if (info and info.hit_position != Vector3.ZERO) else (global_position + Vector3(0.0, 0.8, 0.0))
	AudioManager.play_3d("bot_damage", hit_pos, AudioManager.BUS_SFX, -1.0, 0.06, 35.0, 3.0)

	# If attacked, react to attacker
	if info and info.attacker and info.attacker != self:
		if _target == null or _state == State.SEARCH or _state == State.IDLE:
			_target = info.attacker as Node3D
			_reaction_timer = 0.0


func _flash_hit() -> void:
	for mesh_inst in _mesh_instances:
		if is_instance_valid(mesh_inst):
			mesh_inst.material_override = _flash_material
	await get_tree().create_timer(0.08).timeout
	for i in range(_mesh_instances.size()):
		if is_instance_valid(_mesh_instances[i]):
			_mesh_instances[i].material_override = _orig_materials[i]


func _on_died(_killer: Node) -> void:
	_set_state(State.DEAD)
	deaths += 1
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	_visuals.visible = false
	_hp_label.visible = false
	_state_label.visible = false
	_target = null

	# Audio feedback (3D positional bot death/destruction)
	AudioManager.play_3d("bot_death", global_position + Vector3(0.0, 0.8, 0.0), AudioManager.BUS_SFX, 1.0, 0.05, 45.0, 4.0)

	var timer := get_tree().create_timer(respawn_delay)
	timer.timeout.connect(_do_respawn)


func _do_respawn() -> void:
	if _is_match_ended:
		return
	if _health:
		_health.respawn()


func _on_respawned() -> void:
	# Query MatchManager for dynamic spawn position
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
	_current_ammo = magazine_size
	_is_reloading = false
	_fire_timer = 0.0
	_reaction_timer = reaction_delay
	_target = null
	_collision.set_deferred("disabled", false)
	_visuals.visible = true
	_hp_label.visible = true
	_state_label.visible = true
	_update_hp_label()
	_set_state(State.SEARCH)

	print("[RESPAWN] %s respawned at %s. HP: %.0f/%.0f" % [
		combatant_name,
		str(global_position.snapped(Vector3(0.1, 0.1, 0.1))),
		_health.current_health if _health else 0.0,
		_health.max_health if _health else 1000.0
	])


func _update_hp_label() -> void:
	if is_instance_valid(_hp_label) and _health:
		_hp_label.text = "%.0f / %.0f HP" % [_health.current_health, _health.max_health]
