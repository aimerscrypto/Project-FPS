extends Node3D
class_name EliminationBurst

# =============================================================================
# Project FPS — EliminationBurst
# Milestone 15 — Combat VFX & Feedback
#
# Stylized 3D low-poly voxel/energy burst on combatant elimination.
# Managed via VFXManager ring-buffer object pool.
# =============================================================================

var _timer     : float = 0.0
const DURATION : float = 0.40
var _is_active : bool  = false
var is_active  : bool:
	get: return _is_active

@onready var _mesh_root : Node3D = get_node_or_null("MeshRoot")
var _materials          : Array[StandardMaterial3D] = []


func _ready() -> void:
	if _mesh_root:
		for child in _mesh_root.get_children():
			if child is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.albedo_color = Color(0.25, 0.85, 1.0, 1.0)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				child.material_override = mat
				_materials.append(mat)
	set_process(false)
	visible = false


func activate(pos: Vector3, color: Color = Color(0.25, 0.85, 1.0, 1.0)) -> void:
	global_position = pos

	for mat in _materials:
		mat.albedo_color = color

	if _mesh_root:
		_mesh_root.scale = Vector3(0.2, 0.2, 0.2)

	_timer = DURATION
	_is_active = true
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if not _is_active:
		return

	_timer -= delta
	var progress : float = clampf(1.0 - (_timer / DURATION), 0.0, 1.0)

	if _mesh_root:
		var s : float = lerpf(0.2, 2.2, ease(progress, 0.4))
		_mesh_root.scale = Vector3(s, s, s)
		_mesh_root.rotation.y += delta * 4.0
		_mesh_root.rotation.x += delta * 2.5

	for mat in _materials:
		mat.albedo_color.a = lerpf(1.0, 0.0, progress)

	if _timer <= 0.0:
		deactivate()


func deactivate() -> void:
	_is_active = false
	visible = false
	set_process(false)
