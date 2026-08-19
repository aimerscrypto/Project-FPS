extends Node3D

# =============================================================================
# Project FPS — VFXManager (Autoload Singleton)
# Milestone 15 — Combat VFX, Tracers, Impacts & Feedback
#
# High-performance zero-allocation ring-buffer object pooling for:
# - 3D Bullet Tracers (32 slots)
# - Surface Impact Sparks (24 slots)
# - Elimination Voxel Bursts (12 slots)
# =============================================================================

const TRACER_POOL_SIZE : int = 32
const IMPACT_POOL_SIZE : int = 24
const BURST_POOL_SIZE  : int = 12

var _tracer_pool  : Array[Node3D] = []
var _tracer_index : int           = 0

var _impact_pool  : Array[Node3D] = []
var _impact_index : int           = 0

var _burst_pool   : Array[Node3D] = []
var _burst_index  : int           = 0


func _ready() -> void:
	_init_tracer_pool()
	_init_impact_pool()
	_init_burst_pool()


# -----------------------------------------------------------------------------
# TRACER POOL
# -----------------------------------------------------------------------------
func _init_tracer_pool() -> void:
	var tracer_scene := load("res://scenes/vfx/bullet_tracer.tscn") as PackedScene
	for i in range(TRACER_POOL_SIZE):
		var tracer : Node3D = null
		if tracer_scene:
			tracer = tracer_scene.instantiate() as Node3D
		else:
			tracer = BulletTracer.new()
		add_child(tracer)
		_tracer_pool.append(tracer)


## Spawns a high-speed 3D bullet tracer from muzzle origin to target hitpoint.
func spawn_tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.85, 0.3), speed: float = 260.0) -> void:
	if _tracer_pool.is_empty():
		return

	var tracer := _tracer_pool[_tracer_index]
	_tracer_index = (_tracer_index + 1) % _tracer_pool.size()

	if is_instance_valid(tracer) and tracer.has_method("activate"):
		tracer.activate(from, to, color, speed)


# -----------------------------------------------------------------------------
# SURFACE IMPACT POOL
# -----------------------------------------------------------------------------
func _init_impact_pool() -> void:
	var impact_scene := load("res://scenes/vfx/surface_impact.tscn") as PackedScene
	for i in range(IMPACT_POOL_SIZE):
		var impact : Node3D = null
		if impact_scene:
			impact = impact_scene.instantiate() as Node3D
		else:
			impact = SurfaceImpact.new()
		add_child(impact)
		_impact_pool.append(impact)


## Spawns a surface impact spark puff at collision position oriented along surface normal.
func spawn_impact(pos: Vector3, normal: Vector3, color: Color = Color(1.0, 0.8, 0.4)) -> void:
	if _impact_pool.is_empty():
		return

	var impact := _impact_pool[_impact_index]
	_impact_index = (_impact_index + 1) % _impact_pool.size()

	if is_instance_valid(impact) and impact.has_method("activate"):
		impact.activate(pos, normal, color)


# -----------------------------------------------------------------------------
# ELIMINATION BURST POOL
# -----------------------------------------------------------------------------
func _init_burst_pool() -> void:
	var burst_scene := load("res://scenes/vfx/elimination_burst.tscn") as PackedScene
	for i in range(BURST_POOL_SIZE):
		var burst : Node3D = null
		if burst_scene:
			burst = burst_scene.instantiate() as Node3D
		else:
			burst = EliminationBurst.new()
		add_child(burst)
		_burst_pool.append(burst)


## Spawns a stylized low-poly voxel/energy burst at elimination coordinates.
func spawn_elimination_burst(pos: Vector3, color: Color = Color(0.25, 0.85, 1.0)) -> void:
	if _burst_pool.is_empty():
		return

	var burst := _burst_pool[_burst_index]
	_burst_index = (_burst_index + 1) % _burst_pool.size()

	if is_instance_valid(burst) and burst.has_method("activate"):
		burst.activate(pos, color)
