extends Marker3D
class_name SpawnPoint

# =============================================================================
# Project FPS — SpawnPoint
# Milestone 5 — Free For All Foundation
#
# Reusable spawn point providing position, orientation, and occupancy checks.
# Belongs to the "spawn_points" group for automatic discovery by MatchManager.
# =============================================================================

@export var is_enabled : bool = true


func _ready() -> void:
	add_to_group("spawn_points")


## Returns the full 3D transform for spawning.
func get_spawn_transform() -> Transform3D:
	return global_transform


## Returns the spawn position in world space.
func get_spawn_position() -> Vector3:
	return global_position


## Returns the spawn facing angle around Y in radians.
func get_spawn_yaw() -> float:
	return rotation.y
