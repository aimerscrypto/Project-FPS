extends Area3D
class_name KillZone

# =============================================================================
# Project FPS — KillZone
# Milestone 6 — Arena Graybox & Tactical Map Pass
#
# Reusable fall/death boundary that detects combatants falling below the playable
# area and triggers fatal environmental elimination, leading to normal safe respawn.
# =============================================================================

@export var fatal_damage : float = 9999.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body == null:
		return

	var entity_name : String = str(body.get("combatant_name")) if body.get("combatant_name") else str(body.name)

	# Check if combatant is already dead
	if body.has_method("is_alive") and not body.is_alive():
		return

	print("[KILLZONE] %s fell out of bounds and was eliminated." % entity_name)

	var dmg := DamageInfo.new()
	dmg.amount = fatal_damage
	dmg.attacker = null
	dmg.hit_type = DamageInfo.HitType.BODY
	dmg.hit_position = body.global_position

	if body.has_method("take_damage"):
		body.take_damage(dmg)
	elif body.has_node("Health"):
		var h = body.get_node("Health")
		if h and h.has_method("take_damage"):
			h.take_damage(dmg)
