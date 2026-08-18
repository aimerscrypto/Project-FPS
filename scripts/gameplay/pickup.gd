extends Area3D
class_name Pickup

# =============================================================================
# Project FPS — Pickup
# Milestone 14 — Playable Game Loop & Arena Gameplay Systems
#
# Reusable 3D arena pickup component for Health Kits and Ammo Packs:
# - Smooth procedural hover rotation & vertical bobbing
# - Group "pickups" registration for Bot AI perception
# - Health restoration & Ammo replenishment with waste-prevention checks
# - Configurable 15s cooldown respawn lifecycle
# - Visual glowing status indicators and audio dispatch
# =============================================================================

signal collected(pickup_type: PickupType, collector: Node)
signal respawned()

enum PickupType { HEALTH, AMMO }

@export_group("Pickup Configuration")
@export var pickup_type   : PickupType = PickupType.HEALTH
@export var amount        : float      = 35.0   # HP healed or rounds restored
@export var respawn_time  : float      = 15.0   # seconds until reactivation
@export var auto_rotate   : bool       = true
@export var rotation_speed: float      = 1.8    # rad/s

var is_active        : bool  = true
var _cooldown_timer  : float = 0.0
var _base_visual_pos : Vector3 = Vector3.ZERO

@onready var _visual_root : Node3D = find_child("VisualRoot", true, false)
@onready var _glow_ring   : Node3D = find_child("GlowRing", true, false)
@onready var _omni_light  : OmniLight3D = find_child("OmniLight3D", true, false)


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)

	if is_instance_valid(_visual_root):
		_base_visual_pos = _visual_root.position

	respawn_pickup()


func _process(delta: float) -> void:
	if is_active:
		if auto_rotate and is_instance_valid(_visual_root):
			_visual_root.rotate_y(rotation_speed * delta)
			# Sinusoidal vertical hover bob
			var t : float = float(Time.get_ticks_msec()) * 0.003
			_visual_root.position.y = _base_visual_pos.y + sin(t) * 0.08
	else:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			respawn_pickup()


func _on_body_entered(body: Node) -> void:
	if not is_active or body == null or not body.is_in_group("combatants"):
		return

	if pickup_type == PickupType.HEALTH:
		var health : Health = null
		if body.has_node("Health"):
			health = body.get_node("Health") as Health
		elif body.get("health") is Health:
			health = body.get("health") as Health
		elif body.get("_health") is Health:
			health = body.get("_health") as Health
		else:
			for child in body.get_children():
				if child is Health or child.name == "Health":
					health = child as Health
					break

		if health == null or health.current_health >= health.max_health:
			return # Already at full health

		health.heal(amount)
		print("[PICKUP] %s collected HealthKit (+%.0f HP). Current HP: %.0f/%.0f" % [
			body.name, amount, health.current_health, health.max_health
		])

	elif pickup_type == PickupType.AMMO:
		var collected_any : bool = false

		# Player inventory weapons
		var weapons_array = body.get("_weapons")
		if weapons_array is Array and weapons_array.size() > 0:
			for w in weapons_array:
				if is_instance_valid(w) and w.has_method("refill_ammo"):
					w.refill_ammo()
					collected_any = true

		# Bot ammo
		if body.get("_current_ammo") != null and body.get("magazine_size") != null:
			body.set("_current_ammo", body.get("magazine_size"))
			body.set("_is_reloading", false)
			collected_any = true

		if not collected_any:
			return

		print("[PICKUP] %s collected AmmoPack (Full Refill)." % body.name)

	_consume(body)


func _consume(collector: Node) -> void:
	is_active = false
	_cooldown_timer = respawn_time

	if is_instance_valid(_visual_root):
		_visual_root.visible = false
	if is_instance_valid(_glow_ring):
		_glow_ring.visible = false
	if is_instance_valid(_omni_light):
		_omni_light.visible = false

	# Audio feedback
	var type_str := "health" if pickup_type == PickupType.HEALTH else "ammo"
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_pickup"):
		audio_mgr.play_pickup(type_str)

	collected.emit(pickup_type, collector)


## Manually or automatically respawns the pickup.
func respawn_pickup() -> void:
	is_active = true
	_cooldown_timer = 0.0

	if is_instance_valid(_visual_root):
		_visual_root.visible = true
		_visual_root.position = _base_visual_pos
		_visual_root.scale = Vector3.ZERO
		var tween := create_tween()
		if tween:
			tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_visual_root.scale = Vector3.ONE

	if is_instance_valid(_glow_ring):
		_glow_ring.visible = true
	if is_instance_valid(_omni_light):
		_omni_light.visible = true

	respawned.emit()
