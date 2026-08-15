extends Node
class_name Health

# =============================================================================
# Project FPS — Health Component
# Milestone 3 — Combat Loop
#
# Reusable health component for players, bots, and targets.
# Handles damage, healing, death state, and respawning.
# Uses signals for loose coupling with other systems.
# =============================================================================

signal damage_received(damage_info: DamageInfo, current_hp: float, max_hp: float)
signal healed(amount: float, current_hp: float, max_hp: float)
signal died(killer: Node)
signal respawned()

@export var max_health : float = 100.0

var current_health : float = 100.0
var is_dead        : bool  = false


func _ready() -> void:
	current_health = max_health
	is_dead = false


## Apply damage using a DamageInfo object.
func take_damage(info: DamageInfo) -> void:
	if is_dead:
		return

	var final_damage : float = info.get_final_damage() if info else 0.0
	current_health = maxf(current_health - final_damage, 0.0)

	damage_received.emit(info, current_health, max_health)

	var entity_name : String = str(get_parent().name) if get_parent() else str(name)
	print("[DAMAGE] %s took %.0f damage. HP: %.0f/%.0f" % [
		entity_name,
		final_damage,
		current_health,
		max_health
	])

	if current_health <= 0.0:
		die(info.attacker if info else null)


## Restore health up to max_health.
func heal(amount: float) -> void:
	if is_dead:
		return
	var previous_hp := current_health
	current_health = minf(current_health + amount, max_health)
	var restored := current_health - previous_hp
	if restored > 0.0:
		healed.emit(restored, current_health, max_health)


## Trigger death state.
func die(killer: Node = null) -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0

	var entity_name : String = str(get_parent().name) if get_parent() else str(name)
	var killer_name : String = str(killer.name) if killer else "World"
	print("[DEATH] %s killed by %s" % [entity_name, killer_name])

	# Notify killer if it supports kill recording
	if killer and killer.has_method("record_kill"):
		killer.record_kill(entity_name)

	# Notify MatchManager if present
	var tree := get_tree()
	if tree:
		var match_mgr = tree.get_first_node_in_group("match_manager")
		if match_mgr and match_mgr.has_method("record_kill"):
			match_mgr.record_kill(killer, get_parent())

	died.emit(killer)


## Reset health to full and revive.
func respawn() -> void:
	is_dead = false
	current_health = max_health
	var entity_name : String = str(get_parent().name) if get_parent() else str(name)
	print("[RESPAWN] %s respawned. HP: %.0f/%.0f" % [entity_name, current_health, max_health])
	respawned.emit()
