extends Node3D

# =============================================================================
# Project FPS — TestArena
# Milestone 4 — Basic Bot Navigation Setup
#
# Bakes the NavigationRegion3D mesh on ready so navigation agents have
# a fully generated 3D navigation map.
# =============================================================================

@onready var _nav_region : NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	if _nav_region:
		_nav_region.bake_navigation_mesh(false)
		var poly_count := _nav_region.navigation_mesh.get_polygon_count() if _nav_region.navigation_mesh else 0
		print("[NAVMESH] Baked NavMesh. Polygons: %d" % poly_count)
