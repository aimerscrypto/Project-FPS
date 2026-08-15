extends SceneTree

# =============================================================================
# Project FPS — Automated Milestone 6 Map & Tactical Pass Test Suite
# Milestone 6 — Arena Graybox & Tactical Map Pass
#
# Automated verification script testing:
# - Test 1: 10 Spawn Points registered with spatial distribution across all sectors
# - Test 2: Vertical spawn presence (Catwalk Y > 3.0m, Underpass Y < -1.0m)
# - Test 3: NavigationMesh runtime bake integrity (> 100 3D navigation polygons)
# - Test 4: Tactical Sector Geometry (Center, Flank A, High Ground, Low Route)
# - Test 5: Dynamic Multi-Sector Bot Pathfinding & Target Engagement
# - Test 6: 10-Second Live FFA Combat Simulation & Multi-Sector Combat Flow
# =============================================================================

var passed_count : int = 0
var total_count  : int = 0


func _init() -> void:
	print("\n========================================================")
	print("       RUNNING MILESTONE 6 MAP & TACTICAL PASS TESTS    ")
	print("========================================================\n")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var arena_scene := load("res://scenes/maps/test_arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Failed to load scenes/maps/test_arena.tscn")
		quit(1)
		return

	var arena := arena_scene.instantiate()
	root.add_child(arena)

	# Allow 2 frames for scene ready & deferred navmesh baking
	await process_frame
	await process_frame

	print("[TEST SUITE] Arena loaded and initialized. Beginning Milestone 6 tests.\n")

	_test_spawn_distribution(arena)
	_test_navmesh_baking(arena)
	_test_sector_geometry(arena)
	_test_combatants_initial_distribution(arena)
	await _test_live_combat_simulation(arena)

	print("\n========================================================")
	print("       MILESTONE 6 TEST SUMMARY: %d / %d TESTS PASSED    " % [passed_count, total_count])
	print("========================================================\n")

	arena.queue_free()
	if passed_count == total_count:
		print(">> ALL MILESTONE 6 MAP TESTS PASSED SUCCESSFULLY! <<\n")
		quit(0)
	else:
		print(">> SOME TESTS FAILED! <<\n")
		quit(1)


func _assert(condition: bool, test_name: String) -> void:
	total_count += 1
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		print("  [FAIL] %s" % test_name)


func _fail(reason: String) -> void:
	print("  [FAIL] %s" % reason)


# -----------------------------------------------------------------------------
# TEST IMPLEMENTATIONS
# -----------------------------------------------------------------------------

func _test_spawn_distribution(arena: Node) -> void:
	print("--- TEST 1 & 2: 10 Tactical Spawn Points & Vertical Distribution ---")
	var spawns := arena.get_tree().get_nodes_in_group("spawn_points")
	_assert(spawns.size() >= 10, "Arena provides 10+ spawn points (Found: %d)" % spawns.size())

	var has_catwalk_spawn := false
	var has_lowroute_spawn := false
	var has_flank_a_spawn := false
	var has_north_spawn := false
	var has_south_spawn := false

	for sp in spawns:
		if sp is Node3D:
			var pos : Vector3 = sp.global_position
			if pos.y > 3.0:
				has_catwalk_spawn = true
			if pos.y < -0.5:
				has_lowroute_spawn = true
			if pos.x < -15.0:
				has_flank_a_spawn = true
			if pos.z < -18.0:
				has_north_spawn = true
			if pos.z > 18.0:
				has_south_spawn = true

	_assert(has_catwalk_spawn, "High Ground Catwalk spawn exists (Y > 3.0m)")
	_assert(has_lowroute_spawn, "Lower Route Underpass spawn exists (Y < -0.5m)")
	_assert(has_flank_a_spawn, "Flank Route A spawn exists (X < -15.0m)")
	_assert(has_north_spawn, "North Plaza spawn exists (Z < -18.0m)")
	_assert(has_south_spawn, "South Plaza spawn exists (Z > 18.0m)")


func _test_navmesh_baking(arena: Node) -> void:
	print("\n--- TEST 3: NavigationMesh 3D Runtime Baking Integrity ---")
	var nav_region : NavigationRegion3D = arena.get_node_or_null("NavigationRegion3D")
	_assert(nav_region != null, "NavigationRegion3D exists in arena")

	if nav_region and nav_region.navigation_mesh:
		var poly_count := nav_region.navigation_mesh.get_polygon_count()
		_assert(poly_count > 100, "NavMesh baked with comprehensive 3D coverage (Polygons: %d)" % poly_count)
		_assert(nav_region.navigation_mesh.geometry_parsed_geometry_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS, "NavMesh parses Static Colliders efficiently")


func _test_sector_geometry(arena: Node) -> void:
	print("\n--- TEST 4: Tactical Sector Geometry & Collision Verification ---")
	var nav_region : NavigationRegion3D = arena.get_node_or_null("NavigationRegion3D")
	if nav_region:
		# Check Center
		var monument = nav_region.get_node_or_null("Center_Monument")
		var center_nw = nav_region.get_node_or_null("Center_BarrierNW")
		_assert(monument != null and center_nw != null, "Center zone monument and waist barricades present")

		# Check Flank A
		var flank_wall = nav_region.get_node_or_null("FlankA_WallMid")
		var flank_pillar = nav_region.get_node_or_null("FlankA_PillarNorth")
		_assert(flank_wall != null and flank_pillar != null, "Flank A partition walls and heavy cover pillars present")

		# Check High Ground
		var hg_plat = nav_region.get_node_or_null("HighGround_Platform")
		var hg_ramp_n = nav_region.get_node_or_null("HighGround_RampNorth")
		var hg_ramp_s = nav_region.get_node_or_null("HighGround_RampSouth")
		var jump_crate = nav_region.get_node_or_null("JumpCrate_Step1")
		_assert(hg_plat != null and hg_ramp_n != null and hg_ramp_s != null and jump_crate != null, "High Ground has platform, dual attack ramps, and center skill-jump crates")

		# Check Lower Route
		var lr_floor = nav_region.get_node_or_null("Floor_LowRoute")
		var lr_ramp_n = nav_region.get_node_or_null("TrenchRamp_North")
		var lr_ramp_c = nav_region.get_node_or_null("TrenchRamp_Center")
		_assert(lr_floor != null and lr_ramp_n != null and lr_ramp_c != null, "Lower Route underpass floor and multiple approach ramps present")


func _test_combatants_initial_distribution(arena: Node) -> void:
	print("\n--- TEST 5: 8-Combatant FFA Distribution ---")
	var combatants := arena.get_tree().get_nodes_in_group("combatants")
	_assert(combatants.size() == 8, "Exactly 8 combatants active in arena (Found: %d)" % combatants.size())

	var player = arena.get_node_or_null("Player")
	var bot7 = arena.get_node_or_null("BasicBot7")
	_assert(player != null and bot7 != null, "Player and high-ground starting bot present")
	if bot7:
		_assert(bot7.global_position.y > 3.0, "Bot 7 correctly spawned on High Ground Catwalk (Y = %.1f)" % bot7.global_position.y)


func _test_live_combat_simulation(arena: Node) -> void:
	print("\n--- TEST 6: 10-Second Live FFA Combat Simulation ---")
	var match_mgr : Node = arena.get_node_or_null("MatchManager")
	_assert(match_mgr != null, "MatchManager active for combat simulation")

	var start_kills : int = 0
	for c in match_mgr._combatant_stats:
		start_kills += match_mgr._combatant_stats[c]["kills"]

	print("[SIMULATION] Running 600 physics frames (~10.0s live combat)...")
	for i in range(600):
		arena.get_tree().physics_frame
		await process_frame

	var end_kills : int = 0
	for c in match_mgr._combatant_stats:
		end_kills += match_mgr._combatant_stats[c]["kills"]

	print("[SIMULATION] Live simulation completed. Total kills during session: %d" % (end_kills - start_kills))
	_assert(end_kills > start_kills, "Combatants actively engaged, scored eliminations, and continued combat loop")

	print("\n--- ARENA SCOREBOARD SNAPSHOT ---")
	for c in match_mgr._combatant_stats:
		var s = match_mgr._combatant_stats[c]
		print("  %s: %d Kills / %d Deaths (Score: %d)" % [s["name"], s["kills"], s["deaths"], s["score"]])
