extends Node3D
class_name SurfaceImpact

# =============================================================================
# Project FPS — SurfaceImpact
# Milestone 15 — Combat VFX & Feedback
#
# 3D surface impact spark and dust puff for bullet hits against world colliders.
# Managed via VFXManager ring-buffer object pool.
# =============================================================================

var _timer     : float = 0.0
const DURATION : float = 0.20
var _is_active : bool  = false
var is_active  : bool:
	get: return _is_active

@onready var _mesh_spark : MeshInstance3D     = get_node_or_null("SparkMesh")
var _material            : StandardMaterial3D = null


func _ready() -> void:
	if _mesh_spark:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.4, 1.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mesh_spark.material_override = mat
		_material = mat
	set_process(false)
	visible = false


func activate(pos: Vector3, normal: Vector3, color: Color = Color(1.0, 0.85, 0.4, 1.0)) -> void:
	global_position = pos
	if normal.length_squared() > 0.01:
		if abs(normal.y) < 0.99:
			look_at(pos + normal, Vector3.UP)
		else:
			look_at(pos + normal, Vector3.RIGHT)

	if _material:
		_material.albedo_color = color

	if _mesh_spark:
		_mesh_spark.scale = Vector3(1.0, 1.0, 1.0)

	_timer = DURATION
	_is_active = true
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if not _is_active:
		return

	_timer -= delta
	var progress : float = clampf(1.0 - (_timer / DURATION), 0.0, 1.0)

	if _mesh_spark:
		var s : float = lerpf(1.3, 0.1, progress)
		_mesh_spark.scale = Vector3(s, s, s)

	if _material:
		_material.albedo_color.a = lerpf(1.0, 0.0, progress)

	if _timer <= 0.0:
		deactivate()


func deactivate() -> void:
	_is_active = false
	visible = false
	set_process(false)
