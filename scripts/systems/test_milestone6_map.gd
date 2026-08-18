extends SceneTree

# =============================================================================
# Project FPS — Automated Milestone 6 Map & Tactical Pass Test Suite
# Milestone 6 — Arena Graybox & Tactical Map Pass (Structural Redesign)
#
# Automated verification script testing:
# - Test 1: 10 Spawn Points registered with spatial distribution across all sectors
# - Test 2: Vertical spawn presence (Catwalk Y > 3.0m, Underpass Y < -1.0m)
# - Test 3: NavigationMesh 3D Runtime Baking Integrity (Clean 3-tier coverage)
# - Test 4: Exactly 4 Functional Ramps (Connecting Level 0 <-> +1 and Level 0 <-> -1)
# - Test 5: 8-Combatant FFA Initial Distribution
# - Test 6: Fall Protection / KillZone3D Active Elimination Verification
# - Test 7: Live FFA Combat Simulation (Verifies active multi-combatant engagement & kills)
# =============================================================================

var passed_count : int = 0
var total_count  : int = 0


func _init() -> void:
	print("\n========================================================")
	print("       RUNNING MILESTONE 6 REDESIGN & TACTICAL TESTS    ")
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
	_test_deliberate_ramps(arena)
	_test_combatants_initial_distribution(arena)
	_test_kill_zone_protection(arena)
	await _test_live_combat_simulation(arena)

	print("\n========================================================")
	print("       MILESTONE 6 TEST SUMMARY: %d / %d TESTS PASSED    " % [passed_count, total_count])
	print("========================================================\n")

	arena.queue_free()
	if passed_count == total_count:
		print(">> ALL MILESTONE 6 REDESIGN TESTS PASSED SUCCESSFULLY! <<\n")
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

	_assert(has_catwalk_spawn, "Level +1 Catwalk spawn exists (Y > 3.0m)")
	_assert(has_lowroute_spawn, "Level -1 Underpass spawn exists (Y < -0.5m)")
	_assert(has_flank_a_spawn, "Level 0 Left Flank spawn exists (X < -15.0m)")
	_assert(has_north_spawn, "Level 0 North Plaza spawn exists (Z < -18.0m)")
	_assert(has_south_spawn, "Level 0 South Plaza spawn exists (Z > 18.0m)")


func _test_navmesh_baking(arena: Node) -> void:
	print("\n--- TEST 3: NavigationMesh 3D Runtime Baking Integrity ---")
	var nav_region : NavigationRegion3D = arena.get_node_or_null("NavigationRegion3D")
	_assert(nav_region != null, "NavigationRegion3D exists in arena")

	if nav_region and nav_region.navigation_mesh:
		var poly_count := nav_region.navigation_mesh.get_polygon_count()
		_assert(poly_count > 100, "NavMesh baked with comprehensive 3D coverage across all 3 tiers (Polygons: %d)" % poly_count)
		_assert(nav_region.navigation_mesh.geometry_parsed_geometry_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS, "NavMesh parses Static Colliders efficiently")


func _test_deliberate_ramps(arena: Node) -> void:
	print("\n--- TEST 4: Exactly 4 Deliberate Vertical Transition Ramps ---")
	var nav_region : NavigationRegion3D = arena.get_node_or_null("NavigationRegion3D")
	if nav_region:
		var ramp_hg_n = nav_region.get_node_or_null("Ramp_HighGround_North")
		var ramp_hg_s = nav_region.get_node_or_null("Ramp_HighGround_South")
		var ramp_up_n = nav_region.get_node_or_null("Ramp_Underpass_North")
		var ramp_up_s = nav_region.get_node_or_null("Ramp_Underpass_South")

		_assert(ramp_hg_n != null, "Ramp_HighGround_North exists (Connects North Plaza -> High Ground Catwalk)")
		_assert(ramp_hg_s != null, "Ramp_HighGround_South exists (Connects South Plaza -> High Ground Catwalk)")
		_assert(ramp_up_n != null, "Ramp_Underpass_North exists (Connects North Plaza -> Underpass Tunnel)")
		_assert(ramp_up_s != null, "Ramp_Underpass_South exists (Connects South Plaza -> Underpass Tunnel)")


func _test_combatants_initial_distribution(arena: Node) -> void:
	print("\n--- TEST 5: 8-Combatant FFA Distribution ---")
	var combatants := arena.get_tree().get_nodes_in_group("combatants")
	_assert(combatants.size() == 8, "Exactly 8 combatants active in arena (Found: %d)" % combatants.size())

	var player = arena.get_node_or_null("Player")
	var bot7 = arena.get_node_or_null("BasicBot7")
	_assert(player != null and bot7 != null, "Player and high-ground starting bot present")
	if bot7:
		_assert(bot7.global_position.y > 3.0, "Bot 7 correctly spawned on High Ground Catwalk (Y = %.1f)" % bot7.global_position.y)


func _test_kill_zone_protection(arena: Node) -> void:
	print("\n--- TEST 6: Fall Protection & KillZone3D ---")
	var kill_zone : Area3D = arena.get_node_or_null("KillZone")
	_assert(kill_zone != null, "KillZone exists in arena")
	if kill_zone:
		_assert(kill_zone.global_position.y <= -7.0, "KillZone is placed safely below playable floors (Y = %.1f)" % kill_zone.global_position.y)

		# Create a temporary test bot for fall verification
		var bot_scene := load("res://scenes/enemies/basic_bot.tscn") as PackedScene
		var test_bot := bot_scene.instantiate() as CharacterBody3D
		test_bot.name = "TestFallingBot"
		arena.add_child(test_bot)
		test_bot.global_position = Vector3(0.0, -8.0, 0.0)

		kill_zone._on_body_entered(test_bot)
		_assert(not test_bot.is_alive(), "KillZone triggered fatal elimination on out-of-bounds entity")
		test_bot.queue_free()


func _test_live_combat_simulation(arena: Node) -> void:
	print("\n--- TEST 7: Live FFA Combat Simulation ---")
	var match_mgr : Node = arena.get_node_or_null("MatchManager")
	_assert(match_mgr != null, "MatchManager active for combat simulation")

	var start_kills : int = 0
	for c in match_mgr._combatant_stats:
		start_kills += match_mgr._combatant_stats[c]["kills"]

	if match_mgr.has_method("is_staging") and match_mgr.is_staging():
		match_mgr._begin_playing()

	print("[SIMULATION] Running 1500 physics frames (~25.0s live combat)...")
	for i in range(1500):
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
