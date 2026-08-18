extends Node3D

# =============================================================================
# Project FPS — TestArena
# Milestone 6 — Arena Graybox & Tactical Map Pass
#
# Generates and bakes the 3D NavigationMesh at runtime from the arena static
# colliders, connecting all vertical levels (Ground, Underpass, High Ground Catwalk).
# =============================================================================

@onready var _nav_region : NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Start ambient audio on Ambience bus
	AudioManager.play_ambient("arena_ambient", -8.0)

	if _nav_region and _nav_region.navigation_mesh:
		var source_data := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(_nav_region.navigation_mesh, source_data, _nav_region)
		NavigationServer3D.bake_from_source_geometry_data(_nav_region.navigation_mesh, source_data)
		var poly_count := _nav_region.navigation_mesh.get_polygon_count()
		print("[NAVMESH] Baked NavMesh. Polygons: %d" % poly_count)
