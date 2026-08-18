extends Node
class_name MatchManager

# =============================================================================
# Project FPS — MatchManager
# Milestone 5 — Free For All Foundation
#
# Manages the Free For All (FFA) match lifecycle:
# - Match states: WAITING, PLAYING, ENDED
# - Match duration timer (counts down from 5:00 / 300s)
# - Kill limit (default: 25 kills)
# - Real-time score & kill/death tracking per combatant
# - Dynamic spawn point selection (chooses safest spawn relative to alive enemies)
# - Winner determination and match termination
# =============================================================================

signal match_started()
signal match_ended(winner: Node)
signal kill_recorded(killer: Node, victim: Node, killer_score: int)
signal score_updated(combatant: Node, kills: int, deaths: int)
signal timer_updated(time_remaining: float)

enum MatchState { WAITING, PLAYING, ENDED }

@export_group("Match Configuration")
@export var match_length  : float = 300.0   # seconds (5:00)
@export var kill_limit    : int   = 25      # kills required to win immediately
@export var auto_start    : bool  = true    # whether to automatically start playing on ready

# Match Runtime State
var state          : MatchState = MatchState.WAITING
var time_remaining : float      = 300.0

# Combatant Scoreboard: Dictionary[Node, Dictionary]
# Key: Combatant Node -> Value: { "name": String, "kills": int, "deaths": int, "score": int }
var _combatant_stats : Dictionary = {}

# Timer announcement milestones to prevent console spam
var _next_milestone_index : int = 0
var _milestones : Array[int] = [240, 180, 120, 60, 30, 10, 5, 3, 2, 1]


func _ready() -> void:
	add_to_group("match_manager")
	time_remaining = match_length
	_register_existing_combatants()

	if auto_start:
		# Defer start by a frame so all combatants and spawn points finish readying
		call_deferred("start_match")


func _process(delta: float) -> void:
	if state != MatchState.PLAYING:
		return

	time_remaining -= delta
	timer_updated.emit(time_remaining)

	# Check milestone announcements
	_check_timer_milestones()

	if time_remaining <= 0.0:
		time_remaining = 0.0
		var winner := _determine_winner()
		end_match(winner)


func _check_timer_milestones() -> void:
	if _next_milestone_index < _milestones.size():
		var milestone := _milestones[_next_milestone_index]
		if time_remaining <= float(milestone):
			print("[MATCH] Time remaining: %d" % milestone)
			_next_milestone_index += 1


# =============================================================================
# COMBATANT REGISTRATION & STATS
# =============================================================================

func _register_existing_combatants() -> void:
	var nodes := get_tree().get_nodes_in_group("combatants")
	for node in nodes:
		register_combatant(node)


## Registers a combatant into the match scoreboard.
func register_combatant(combatant: Node) -> void:
	if combatant == null or _combatant_stats.has(combatant):
		return

	var display_name : String = _get_combatant_name(combatant)
	_combatant_stats[combatant] = {
		"name": display_name,
		"kills": 0,
		"deaths": 0,
		"score": 0
	}


func _get_combatant_name(combatant: Node) -> String:
	if combatant == null:
		return "Unknown"
	if combatant.get("combatant_name"):
		return str(combatant.get("combatant_name"))
	return str(combatant.name)


## Returns stats dictionary for a given combatant.
func get_combatant_stats(combatant: Node) -> Dictionary:
	if _combatant_stats.has(combatant):
		return _combatant_stats[combatant]
	return { "name": _get_combatant_name(combatant), "kills": 0, "deaths": 0, "score": 0 }


## Returns all combatant scoreboard entries sorted by score/kills descending, then deaths ascending.
func get_sorted_scoreboard() -> Array[Dictionary]:
	var list : Array[Dictionary] = []
	for combatant in _combatant_stats:
		var stats : Dictionary = _combatant_stats[combatant]
		list.append({
			"node": combatant,
			"name": stats["name"],
			"kills": stats["kills"],
			"deaths": stats["deaths"],
			"score": stats["score"]
		})

	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		if a["kills"] != b["kills"]:
			return a["kills"] > b["kills"]
		return a["deaths"] < b["deaths"]
	)
	return list


## Returns the current highest score in the match.
func get_leading_score() -> int:
	var highest : int = 0
	for combatant in _combatant_stats:
		var s : int = _combatant_stats[combatant]["score"]
		if s > highest:
			highest = s
	return highest


## Returns true if the match is currently in progress.
func is_playing() -> bool:
	return state == MatchState.PLAYING


## Returns true if the match has finished.
func is_ended() -> bool:
	return state == MatchState.ENDED


# =============================================================================
# MATCH LIFECYCLE
# =============================================================================

## Starts the FFA match.
func start_match() -> void:
	if state == MatchState.PLAYING:
		return

	state = MatchState.PLAYING
	time_remaining = match_length
	_next_milestone_index = 0
	_register_existing_combatants()

	print("[MATCH] Started")
	match_started.emit()


## Ends the FFA match.
func end_match(winner: Node = null) -> void:
	if state == MatchState.ENDED:
		return

	state = MatchState.ENDED
	print("[MATCH] Ended")

	if winner != null:
		var winner_name := _get_combatant_name(winner)
		var score : int = _combatant_stats[winner]["score"] if _combatant_stats.has(winner) else 0
		print("[WINNER] %s (Score: %d)" % [winner_name, score])
	else:
		print("[WINNER] No winner (Draw)")

	match_ended.emit(winner)


func _determine_winner() -> Node:
	var highest_score : int = -1
	var winner : Node = null

	for combatant in _combatant_stats:
		var stats : Dictionary = _combatant_stats[combatant]
		if stats["score"] > highest_score:
			highest_score = stats["score"]
			winner = combatant

	return winner


# =============================================================================
# SCORING & KILL / DEATH EVENTS
# =============================================================================

## Called when a combatant is eliminated.
func record_kill(killer: Node, victim: Node) -> void:
	var victim_name := _get_combatant_name(victim)
	var killer_name := _get_combatant_name(killer)

	# Register if not already tracked
	if victim and not _combatant_stats.has(victim):
		register_combatant(victim)
	if killer and not _combatant_stats.has(killer):
		register_combatant(killer)

	print("[DEATH] %s" % victim_name)

	# If match has ended, do not increment scores
	if state != MatchState.PLAYING:
		return

	# Update victim deaths
	if victim and _combatant_stats.has(victim):
		_combatant_stats[victim]["deaths"] += 1
		score_updated.emit(victim, _combatant_stats[victim]["kills"], _combatant_stats[victim]["deaths"])

	# Update killer kills & score
	if killer and _combatant_stats.has(killer):
		_combatant_stats[killer]["kills"] += 1
		_combatant_stats[killer]["score"] += 1   # 1 kill = 1 point
		var current_score : int = _combatant_stats[killer]["score"]

		print("[KILL] %s -> %s" % [killer_name, victim_name])
		print("[SCORE] %s = %d" % [killer_name, current_score])

		score_updated.emit(killer, _combatant_stats[killer]["kills"], _combatant_stats[killer]["deaths"])
		kill_recorded.emit(killer, victim, current_score)

		# Check win condition (Kill Limit)
		if current_score >= kill_limit:
			end_match(killer)


# =============================================================================
# DYNAMIC SPAWN POINT SELECTION
# =============================================================================

## Selects an optimal spawn point for the respawning combatant.
## Evaluates all registered spawn points and picks the one with the
## greatest distance to the nearest alive enemy combatant.
func get_spawn_point(for_combatant: Node3D = null) -> Transform3D:
	var spawn_nodes := get_tree().get_nodes_in_group("spawn_points")
	if spawn_nodes.is_empty():
		return Transform3D(Basis(), Vector3(0.0, 0.9, 0.0))

	# Gather positions of all alive enemy combatants
	var alive_enemy_positions : Array[Vector3] = []
	var combatants := get_tree().get_nodes_in_group("combatants")
	for c in combatants:
		if c == for_combatant:
			continue
		if c is Node3D:
			# Check if alive
			var is_alive : bool = true
			if c.has_method("is_alive"):
				is_alive = c.is_alive()
			elif c.get("_is_dead") != null:
				is_alive = not c.get("_is_dead")
			elif c.has_node("Health"):
				is_alive = not c.get_node("Health").is_dead

			if is_alive:
				alive_enemy_positions.append(c.global_position)

	# If no enemies alive, pick a random spawn point
	if alive_enemy_positions.is_empty():
		var random_spawn : Node3D = spawn_nodes[randi() % spawn_nodes.size()] as Node3D
		return random_spawn.global_transform

	# Evaluate each spawn point: maximize the minimum distance to any alive enemy
	var best_spawn : Node3D = null
	var max_min_dist : float = -1.0

	for spawn in spawn_nodes:
		if spawn is Node3D:
			var spawn_pos : Vector3 = spawn.global_position
			var min_dist_to_enemy : float = INF

			for enemy_pos in alive_enemy_positions:
				var d : float = spawn_pos.distance_to(enemy_pos)
				if d < min_dist_to_enemy:
					min_dist_to_enemy = d

			if min_dist_to_enemy > max_min_dist:
				max_min_dist = min_dist_to_enemy
				best_spawn = spawn

	if best_spawn != null:
		return best_spawn.global_transform

	var fallback_spawn : Node3D = spawn_nodes[0] as Node3D
	return fallback_spawn.global_transform
