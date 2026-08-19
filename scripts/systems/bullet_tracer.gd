extends Node3D
class_name BulletTracer

# =============================================================================
# Project FPS — BulletTracer
# Milestone 15 — Combat VFX & Feedback
#
# High-speed 3D visual bullet tracer streak for hitscan weapons.
# Managed via VFXManager ring-buffer object pool.
# =============================================================================

var _start_pos          : Vector3 = Vector3.ZERO
var _target_pos         : Vector3 = Vector3.ZERO
var _current_pos        : Vector3 = Vector3.ZERO
var _direction          : Vector3 = Vector3.FORWARD
var _distance_total     : float   = 0.0
var _distance_traveled  : float   = 0.0
var _speed              : float   = 260.0
var _is_active          : bool    = false
var is_active           : bool:
	get: return _is_active

@onready var _mesh_instance : MeshInstance3D     = get_node_or_null("MeshInstance3D")
var _material               : StandardMaterial3D = null


func _ready() -> void:
	if _mesh_instance:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.3, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mesh_instance.material_override = mat
		_material = mat
	set_physics_process(false)
	visible = false


func activate(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.3), speed: float = 260.0) -> void:
	_start_pos = from
	_target_pos = to
	_current_pos = from
	_speed = max(speed, 50.0)
	var diff := to - from
	_distance_total = diff.length()
	if _distance_total < 0.01:
		deactivate()
		return
	_direction = diff.normalized()
	_distance_traveled = 0.0
	global_position = from

	# Orient along trajectory
	if abs(_direction.y) < 0.99:
		look_at(from + _direction, Vector3.UP)
	else:
		look_at(from + _direction, Vector3.RIGHT)

	if _material:
		_material.albedo_color = color

	_is_active = true
	visible = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _is_active:
		return
	var step : float = _speed * delta
	_distance_traveled += step
	_current_pos += _direction * step
	global_position = _current_pos

	if _distance_traveled >= _distance_total:
		deactivate()


func deactivate() -> void:
	_is_active = false
	visible = false
	set_physics_process(false)
