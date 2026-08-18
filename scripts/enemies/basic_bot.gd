extends CharacterBody3D

# =============================================================================
# Project FPS — BasicBot
# Milestone 4 — Basic Bot | Milestone 5 — FFA Foundation | Milestone 13 — Bot AI
#
# An intelligent, believable FFA combat opponent featuring:
# - Combatant interface & group integration
# - Cone-based perception (FOV), hearing range & damage alertness (no omniscience)
# - Prioritized multi-target scoring with strong target stickiness & low-HP focus
# - Finite state machine: IDLE, SEARCH, CHASE, ATTACK, INVESTIGATE, COVER, DEAD
# - Last-Known-Position (LKP) memory & investigation decay cycle
# - Dynamic combat movement: lateral strafing, distance maintenance, obstacle avoidance
# - Tactical cover evaluation under heavy damage or during empty-magazine reloads
# - Human-like aiming interpolation and strict fire alignment tolerance
# - Data-driven difficulty parameters & presets (Easy, Medium, Hard)
# - NavigationAgent3D pathfinding with wall deflection fallback
# - Hitscan weapon firing with reload cycle, 3D audio, and damage delivery
# - Dynamic respawn via MatchManager spawn points & spawn protection feedback
# - Runtime debug visuals (3D State label & 3D HP label)
# =============================================================================

# -----------------------------------------------------------------------------
# DIFFICULTY PRESETS
# -----------------------------------------------------------------------------
enum Difficulty { EASY, MEDIUM, HARD, CUSTOM }

# -----------------------------------------------------------------------------
# CONFIGURABLE PARAMETERS (Tune in Inspector)
# -----------------------------------------------------------------------------
@export_group("Bot Stats")
@export var combatant_name        : String     = "BasicBot"
@export var max_health            : float      = 100.0
@export var move_speed            : float      = 4.5    # m/s
@export var turn_speed            : float      = 6.5    # lerp rotation speed (rad/s)
@export var gravity               : float      = 20.0   # m/s² downward pull

@export_group("Perception & Awareness")
@export var detection_range       : float      = 28.0   # meters max sight distance
@export var fov_degrees           : float      = 115.0  # vision cone angle (degrees)
@export var hearing_range         : float      = 3.5    # 360° close proximity / sound detection (meters)
@export var target_persistence    : float      = 3.5    # seconds to remember last known position
@export var investigate_duration  : float      = 2.0    # seconds to search LKP before giving up

@export_group("Combat & Aiming")
@export var combat_range_min      : float      = 5.5    # meters (back up if closer)
@export var combat_range_max      : float      = 16.0   # meters (chase if farther)
@export var attack_fire_rate      : float      = 5.0    # rounds per second
@export var attack_damage         : float      = 8.0    # damage per shot
@export var attack_spread_degrees : float      = 2.8    # aim inaccuracy cone (degrees)
@export var fire_tolerance_degrees: float      = 14.0   # max angle error allowed to pull trigger
@export var reaction_delay        : float      = 0.32   # seconds to react after acquiring target
@export var magazine_size         : int        = 15     # rounds per mag
@export var reload_time           : float      = 2.0    # seconds to reload
@export var respawn_delay         : float      = 2.5    # seconds to respawn after death

@export_group("Tactics & Movement")
@export var strafe_frequency      : float      = 0.7    # strafe direction changes per second
@export var strafe_speed_mult     : float      = 0.75   # lateral movement speed multiplier
@export var cover_health_threshold: float      = 35.0   # HP threshold to seek cover under fire (%)
@export var tactical_reload_thresh: float      = 0.40   # reload when ammo < threshold if in safe state
@export var aggression            : float      = 0.65   # 0.0 (defensive) to 1.0 (highly aggressive)
@export var difficulty_preset     : Difficulty = Difficulty.MEDIUM

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
enum State { IDLE, SEARCH, CHASE, ATTACK, INVESTIGATE, COVER, DEAD }

var _state          : State   = State.SEARCH
var _target         : Node3D  = null
var _spawn_position : Vector3 = Vector3.ZERO
var _is_match_ended : bool    = false

# Combatant Score tracking
var kills  : int = 0
var deaths : int = 0

# Perception & Retargeting
var _retarget_timer       : float   = 0.0
const RETARGET_INTERVAL   : float   = 0.30
var _last_known_target_pos: Vector3 = Vector3.ZERO
var _target_memory_timer  : float   = 0.0
var _investigate_timer    : float   = 0.0
var _recent_attacker      : Node3D  = null
var _recent_attacker_timer: float   = 0.0

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

# Combat Strafing & Tactical Movement
var _strafe_timer        : float   = 0.0
var _strafe_dir          : float   = 1.0    # +1.0 = Right, -1.0 = Left
var _strafe_pause_timer  : float   = 0.0
var _cover_position      : Vector3 = Vector3.ZERO
var _cover_timer         : float   = 0.0
var _patrol_timer        : float   = 0.0
var _patrol_target_pos   : Vector3 = Vector3.ZERO
var _nav_update_timer    : float   = 0.0

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
	_apply_difficulty(difficulty_preset)

	if combatant_name == "BasicBot" and name != "BasicBot":
		combatant_name = name

	# Setup Health component
	if _health:
		_health.max_health = max_health
		_health.current_health = max_health
		_health.damage_received.connect(_on_damage_received)
		_health.died.connect(_on_died)
		_health.respawned.connect(_on_respawned)
		_health.spawn_protection_started.connect(_on_spawn_protection_started)
		_health.spawn_protection_ended.connect(_on_spawn_protection_ended)

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
# DIFFICULTY PRESETS
# =============================================================================

## Applies difficulty parameters dynamically.
func apply_difficulty_preset(preset: Difficulty) -> void:
	difficulty_preset = preset
	_apply_difficulty(preset)


func _apply_difficulty(preset: Difficulty) -> void:
	match preset:
		Difficulty.EASY:
			reaction_delay = 0.50
			attack_spread_degrees = 4.5
			turn_speed = 4.5
			fov_degrees = 90.0
			strafe_frequency = 0.4
			aggression = 0.35
			fire_tolerance_degrees = 16.0
		Difficulty.MEDIUM:
			reaction_delay = 0.32
			attack_spread_degrees = 2.8
			turn_speed = 6.5
			fov_degrees = 115.0
			strafe_frequency = 0.7
			aggression = 0.65
			fire_tolerance_degrees = 14.0
		Difficulty.HARD:
			reaction_delay = 0.20
			attack_spread_degrees = 1.6
			turn_speed = 9.0
			fov_degrees = 130.0
			strafe_frequency = 0.9
			aggression = 0.85
			fire_tolerance_degrees = 10.0
		Difficulty.CUSTOM:
			pass


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
		var shield_tag : String = " [SHIELD]" if (_health and _health.is_spawn_protected) else ""
		_state_label.text = "STATE: " + State.keys()[_state] + shield_tag

		if _health and _health.is_spawn_protected:
			_state_label.modulate = Color(0.25, 0.95, 1.0, 1.0)
			return

		match _state:
			State.IDLE, State.SEARCH:
				_state_label.modulate = Color(0.4, 0.9, 1.0, 1.0)  # Cyan
			State.CHASE:
				_state_label.modulate = Color(1.0, 0.8, 0.2, 1.0)  # Yellow
			State.ATTACK:
				_state_label.modulate = Color(1.0, 0.2, 0.2, 1.0)  # Red
			State.INVESTIGATE:
				_state_label.modulate = Color(0.3, 1.0, 0.5, 1.0)  # Green
			State.COVER:
				_state_label.modulate = Color(0.7, 0.4, 1.0, 1.0)  # Purple
			State.DEAD:
				_state_label.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Gray


func _on_spawn_protection_started(_duration: float) -> void:
	_update_state_label()


func _on_spawn_protection_ended() -> void:
	_update_state_label()


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
		_process_combat_ai(delta)
	elif _target_memory_timer > 0.0 and _last_known_target_pos != Vector3.ZERO:
		_process_investigate_state(delta)
	else:
		_process_search_state(delta)

	move_and_slide()


# =============================================================================
# PERCEPTION & TARGET SELECTION (FFA)
# =============================================================================

func _update_target_selection(delta: float) -> void:
	_retarget_timer -= delta

	var current_invalid : bool = not _is_target_valid(_target)

	if current_invalid or _retarget_timer <= 0.0:
		_retarget_timer = RETARGET_INTERVAL
		var best_candidate := _find_best_target()

		if best_candidate != _target:
			if best_candidate != null:
				var target_display_name : String = _get_entity_name(best_candidate)
				print("[TARGET] %s -> %s" % [combatant_name, target_display_name])
				_last_known_target_pos = best_candidate.global_position
				_target_memory_timer = target_persistence
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
	if dist > detection_range * 1.35:
		return false

	return true


## Evaluates all candidate combatants using cone-based vision, hearing, LOS, and scoring.
func _find_best_target() -> Node3D:
	var combatants := get_tree().get_nodes_in_group("combatants")
	var best_candidate : Node3D = null
	var highest_score : float = -INF

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

		var target_pt : Vector3 = c.get_target_position() if c.has_method("get_target_position") else c.global_position + Vector3(0.0, 0.8, 0.0)
		var has_los := _check_line_of_sight(c, target_pt)
		if not has_los:
			continue

		var in_fov := _is_target_in_fov(c, target_pt)
		var is_close := (dist <= hearing_range)
		var is_attacker := (c == _recent_attacker and _recent_attacker_timer > 0.0)

		# Multi-factor target prioritization scoring:
		var score : float = 0.0

		# 1. Base visibility & FOV score
		if in_fov:
			score += 60.0
		else:
			score += 10.0

		if is_close:
			score += 40.0

		if is_attacker:
			score += 55.0

		# 2. Distance scoring (closer targets preferred)
		score += (1.0 - clampf(dist / detection_range, 0.0, 1.0)) * 35.0

		# 3. Target stickiness (prevents jittery target switching)
		if c == _target:
			score += 50.0

		# 4. Low-health target opportunism
		var hp_ratio : float = 1.0
		if c.has_node("Health"):
			var h_node = c.get_node("Health") as Health
			if h_node and h_node.max_health > 0.0:
				hp_ratio = h_node.current_health / h_node.max_health
		if hp_ratio < 0.35:
			score += 20.0

		if score > highest_score:
			highest_score = score
			best_candidate = c

	return best_candidate


## Checks if target point falls within the bot's forward vision cone.
func _is_target_in_fov(_target_node: Node3D, target_pt: Vector3) -> bool:
	var eye_pos := global_position + Vector3(0.0, 1.4, 0.0)
	var to_target := (target_pt - eye_pos)
	var dist := to_target.length()

	# Close range sound / presence
	if dist <= hearing_range:
		return true

	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var fwd_norm := fwd.normalized()

	var h_dir := Vector3(to_target.x, 0.0, to_target.z).normalized()
	if h_dir.length_squared() < 0.001 or fwd_norm.length_squared() < 0.001:
		return true

	var dot := clampf(fwd_norm.dot(h_dir), -1.0, 1.0)
	var min_dot := cos(deg_to_rad(fov_degrees * 0.5))

	return dot >= min_dot


## Raycast line of sight verification against geometry.
func _check_line_of_sight(target_node: Node3D, target_pt: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false

	var eye_pos := global_position + Vector3(0.0, 1.4, 0.0)
	var query := PhysicsRayQueryParameters3D.create(eye_pos, target_pt)
	query.exclude = [self]
	var result := space.intersect_ray(query)

	if result.is_empty():
		return true

	var collider = result.collider
	if collider == target_node:
		return true
	if collider is Node and (collider.get_parent() == target_node or collider.is_in_group("combatants")):
		if collider == target_node or collider.get_parent() == target_node:
			return true

	return false


func _get_entity_name(entity: Node) -> String:
	if entity == null:
		return "None"
	if entity.get("combatant_name"):
		return str(entity.get("combatant_name"))
	return str(entity.name)


# =============================================================================
# COMBAT AI & TACTICAL ENGAGEMENT
# =============================================================================
func _process_combat_ai(delta: float) -> void:
	var target_pos : Vector3 = _target.global_position
	var target_torso : Vector3 = _target.get_target_position() if _target.has_method("get_target_position") else target_pos + Vector3(0.0, 0.8, 0.0)
	var dist : float = global_position.distance_to(target_pos)

	# Check Line of Sight & FOV
	_has_los = _check_line_of_sight(_target, target_torso)

	if _has_los:
		# Target is actively visible — refresh LKP and memory timer
		_last_known_target_pos = target_pos
		_target_memory_timer = target_persistence

		if _reaction_timer > 0.0:
			_reaction_timer -= delta

		_rotate_toward(target_pos, delta)

		# Check cover/survival trigger (Low HP or empty reload under fire)
		var hp_ratio : float = (_health.current_health / _health.max_health) if _health else 1.0
		var wants_cover : bool = (hp_ratio * 100.0 <= cover_health_threshold) or (_is_reloading and _current_ammo == 0)

		if wants_cover and randf() < (1.1 - aggression):
			if _cover_timer <= 0.0:
				var found_cover := _find_cover_position(target_pos)
				if found_cover != Vector3.ZERO:
					_cover_position = found_cover
					_cover_timer = 2.5
					_set_state(State.COVER)
					_navigate_toward(_cover_position, delta)
					return

		# Handle Cover State
		if _state == State.COVER and _cover_timer > 0.0:
			_process_cover_state(delta, target_pos)
			return

		# Handle Range & Combat Maneuvers
		if dist > combat_range_max:
			# Too far: Chase target while engaging
			_set_state(State.CHASE)
			_navigate_toward(target_pos, delta)
			if _can_pull_trigger(target_torso):
				_try_fire(target_torso)
		elif dist < combat_range_min:
			# Too close: Backpedal and strafe while firing
			_set_state(State.ATTACK)
			var away_dir := (global_position - target_pos).normalized()
			away_dir.y = 0.0
			var side_dir := away_dir.cross(Vector3.UP).normalized() * _strafe_dir
			var retreat_vec := (away_dir * 0.75 + side_dir * 0.45).normalized()
			velocity.x = retreat_vec.x * (move_speed * strafe_speed_mult)
			velocity.z = retreat_vec.z * (move_speed * strafe_speed_mult)

			if _can_pull_trigger(target_torso):
				_try_fire(target_torso)
		else:
			# Ideal combat range: Lateral combat strafing with micro-pauses
			_set_state(State.ATTACK)
			_process_combat_strafe(delta, target_pos)

			if _can_pull_trigger(target_torso):
				_try_fire(target_torso)
	else:
		# Target broke LOS -> Investigate last known position
		if _target_memory_timer > 0.0:
			_set_state(State.INVESTIGATE)
			_process_investigate_state(delta)
		else:
			_set_state(State.SEARCH)
			_process_search_state(delta)


## Check fire alignment tolerance before shooting.
func _can_pull_trigger(target_aim_pos: Vector3) -> bool:
	if _reaction_timer > 0.0 or not _has_los or _is_reloading or _current_ammo <= 0:
		return false

	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var fwd_norm := fwd.normalized()

	var eye_pos := global_position + Vector3(0.0, 1.4, 0.0)
	var aim_dir := (target_aim_pos - eye_pos).normalized()
	var h_aim := Vector3(aim_dir.x, 0.0, aim_dir.z).normalized()

	if fwd_norm.length_squared() < 0.001 or h_aim.length_squared() < 0.001:
		return true

	var dot := clampf(fwd_norm.dot(h_aim), -1.0, 1.0)
	var angle_deg := rad_to_deg(acos(dot))

	return angle_deg <= fire_tolerance_degrees


## Dynamic combat strafe generator with obstacle probing and cadence.
func _process_combat_strafe(delta: float, target_pos: Vector3) -> void:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_dir *= -1.0
		_strafe_timer = randf_range(1.0 / maxf(strafe_frequency, 0.1), 2.2 / maxf(strafe_frequency, 0.1))
		# 25% chance for a brief micro-pause (human hesitation)
		if randf() < 0.25:
			_strafe_pause_timer = 0.20

	var to_target := (target_pos - global_position).normalized()
	to_target.y = 0.0
	var right_vec := to_target.cross(Vector3.UP).normalized() * _strafe_dir

	# Proactive side-obstacle check
	if _is_obstacle_ahead(right_vec, 1.3):
		_strafe_dir *= -1.0
		right_vec = -right_vec
		_strafe_timer = 1.2

	if _strafe_pause_timer > 0.0:
		_strafe_pause_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, right_vec.x * (move_speed * strafe_speed_mult), move_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, right_vec.z * (move_speed * strafe_speed_mult), move_speed * 8.0 * delta)


## Cover navigation and survival state.
func _process_cover_state(delta: float, _threat_pos: Vector3) -> void:
	_cover_timer -= delta
	var dist_to_cover := global_position.distance_to(_cover_position)

	if dist_to_cover > 1.2:
		_navigate_toward(_cover_position, delta)
	else:
		# Reached cover: Hold position, crouch/wait and reload if needed
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
		if _current_ammo < magazine_size and not _is_reloading:
			_start_reload()

	if _cover_timer <= 0.0 or (not _is_reloading and _current_ammo == magazine_size):
		_set_state(State.CHASE)


## Evaluates 16 radial candidate positions around the bot to find geometric cover breaking LOS.
func _find_cover_position(threat_pos: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return Vector3.ZERO

	var best_pos := Vector3.ZERO
	var best_dist : float = INF
	var angles : Array[float] = [0.0, PI * 0.25, PI * 0.5, PI * 0.75, PI, PI * 1.25, PI * 1.5, PI * 1.75]

	for rad in [4.5, 7.5]:
		for a in angles:
			var offset := Vector3(cos(a) * rad, 0.0, sin(a) * rad)
			var candidate := global_position + offset
			candidate.x = clampf(candidate.x, -23.0, 23.0)
			candidate.z = clampf(candidate.z, -23.0, 23.0)

			# Raycast candidate eye to threat eye
			var eye_cand := candidate + Vector3(0.0, 1.4, 0.0)
			var threat_eye := threat_pos + Vector3(0.0, 1.4, 0.0)
			var query := PhysicsRayQueryParameters3D.create(eye_cand, threat_eye, 1) # Layer 1 geometry
			var hit := space.intersect_ray(query)

			if not hit.is_empty():
				var d := global_position.distance_to(candidate)
				if d < best_dist:
					best_dist = d
					best_pos = candidate

	return best_pos


## Probes short ray ahead of movement direction to avoid walking into walls.
func _is_obstacle_ahead(dir: Vector3, dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var start := global_position + Vector3(0.0, 0.6, 0.0)
	var target := start + dir.normalized() * dist
	var query := PhysicsRayQueryParameters3D.create(start, target, 1)
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	return not hit.is_empty()


# =============================================================================
# INVESTIGATE (LAST KNOWN POSITION) & SEARCH PATROL
# =============================================================================

func _process_investigate_state(delta: float) -> void:
	_target_memory_timer -= delta
	var dist_to_lkp := global_position.distance_to(_last_known_target_pos)

	if dist_to_lkp > 1.8 and _target_memory_timer > 0.0:
		_navigate_toward(_last_known_target_pos, delta)
	else:
		# Reached LKP: Scan area
		if _investigate_timer <= 0.0:
			_investigate_timer = investigate_duration

		_investigate_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)

		# Tactical reload while searching
		if _current_ammo < int(magazine_size * tactical_reload_thresh) and not _is_reloading:
			_start_reload()

		# Sweep look direction
		var sweep_yaw := sin(Time.get_ticks_msec() * 0.003) * 0.8
		rotation.y = lerp_angle(rotation.y, rotation.y + sweep_yaw * delta, turn_speed * 0.5 * delta)

		if _investigate_timer <= 0.0 or _target_memory_timer <= 0.0:
			_target = null
			_target_memory_timer = 0.0
			_set_state(State.SEARCH)


func _process_search_state(delta: float) -> void:
	_set_state(State.SEARCH)
	_patrol_timer -= delta

	# Tactical reload during quiet patrol
	if _current_ammo < magazine_size and not _is_reloading:
		_start_reload()

	if _patrol_timer <= 0.0 or _patrol_target_pos == Vector3.ZERO:
		var offset := Vector3(randf_range(-14.0, 14.0), 0.0, randf_range(-14.0, 14.0))
		_patrol_target_pos = _spawn_position + offset
		_patrol_target_pos.x = clampf(_patrol_target_pos.x, -22.0, 22.0)
		_patrol_target_pos.z = clampf(_patrol_target_pos.z, -22.0, 22.0)
		_patrol_timer = randf_range(3.5, 6.5)

	var dist_to_patrol := global_position.distance_to(_patrol_target_pos)
	if dist_to_patrol > 1.5:
		_navigate_toward(_patrol_target_pos, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)


# =============================================================================
# NAVIGATION & PATHFINDING
# =============================================================================

func _navigate_toward(target_pos: Vector3, delta: float) -> void:
	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = 0.18
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

	if _recent_attacker_timer > 0.0:
		_recent_attacker_timer -= delta
		if _recent_attacker_timer <= 0.0:
			_recent_attacker = null

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
	if _is_match_ended or _is_reloading or _fire_timer > 0.0:
		return
	if _current_ammo <= 0:
		_start_reload()
		return

	_fire(target_aim_pos)


func _start_reload() -> void:
	if _is_reloading:
		return
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

	# Damage reaction stimulus: alert to attacker
	if info and info.attacker and info.attacker != self and info.attacker is Node3D:
		_recent_attacker = info.attacker as Node3D
		_recent_attacker_timer = 3.0
		_last_known_target_pos = _recent_attacker.global_position
		_target_memory_timer = target_persistence

		if _target == null or _state == State.SEARCH or _state == State.IDLE or _state == State.INVESTIGATE:
			_target = _recent_attacker
			_reaction_timer = reaction_delay * 0.4


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
	_recent_attacker = null

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
	_recent_attacker = null
	_target_memory_timer = 0.0
	_last_known_target_pos = Vector3.ZERO
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
		_health.max_health if _health else 100.0
	])


func _update_hp_label() -> void:
	if is_instance_valid(_hp_label) and _health:
		_hp_label.text = "%.0f / %.0f HP" % [_health.current_health, _health.max_health]
