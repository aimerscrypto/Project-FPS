extends StaticBody3D

# =============================================================================
# Project FPS — DummyTarget
# Milestone 3 — Combat Loop
#
# Simple static target for testing hitscan damage, death, and respawn.
# =============================================================================

const DamageInfo = preload("res://scripts/systems/damage_info.gd")
const HealthScript = preload("res://scripts/systems/health.gd")

@onready var _health    : Health           = $Health
@onready var _collision : CollisionShape3D = $CollisionShape3D
@onready var _visuals   : Node3D           = $Visuals
@onready var _hp_label  : Label3D          = $HPLabel

# Material reference for hit flash feedback
var _mesh_instances : Array[MeshInstance3D] = []
var _orig_materials : Array[Material] = []
var _flash_material : StandardMaterial3D = null


func _ready() -> void:
	# Connect health signals
	_health.damage_received.connect(_on_damage_received)
	_health.died.connect(_on_died)
	_health.respawned.connect(_on_respawned)

	# Setup damage flash material (bright yellow/white flash)
	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = Color(1.0, 1.0, 0.4, 1.0)
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Cache mesh instances for hit flash
	_collect_mesh_instances(_visuals)

	_update_hp_label()


func _collect_mesh_instances(node: Node) -> void:
	if node is MeshInstance3D:
		_mesh_instances.append(node)
		_orig_materials.append(node.material_override)
	for child in node.get_children():
		_collect_mesh_instances(child)


## Damageable interface entrypoint
func take_damage(info: DamageInfo) -> void:
	if _health:
		_health.take_damage(info)


func _on_damage_received(_info: DamageInfo, current_hp: float, max_hp: float) -> void:
	_update_hp_label()
	_flash_hit()


func _flash_hit() -> void:
	for mesh_inst in _mesh_instances:
		mesh_inst.material_override = _flash_material
	await get_tree().create_timer(0.08).timeout
	for i in range(_mesh_instances.size()):
		if is_instance_valid(_mesh_instances[i]):
			_mesh_instances[i].material_override = _orig_materials[i]


func _on_died(_killer: Node) -> void:
	# Disable collision and hide visuals upon death
	_collision.set_deferred("disabled", true)
	_visuals.visible = false
	_hp_label.visible = false

	# Respawn after 2.0 seconds
	var respawn_timer := get_tree().create_timer(2.0)
	respawn_timer.timeout.connect(_do_respawn)


func _do_respawn() -> void:
	if _health:
		_health.respawn()


func _on_respawned() -> void:
	_collision.set_deferred("disabled", false)
	_visuals.visible = true
	_hp_label.visible = true
	_update_hp_label()


func _update_hp_label() -> void:
	if is_instance_valid(_hp_label) and _health:
		_hp_label.text = "%.0f / %.0f HP" % [_health.current_health, _health.max_health]
