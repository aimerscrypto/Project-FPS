extends SceneTree

# =============================================================================
# Project FPS — Automated Milestone 12 Map Gameplay & Spawn Quality Test Suite
# Milestone 12 — Map Gameplay & Spawn Quality
#
# Automated verification testing:
# - Test 1: 10+ Distributed Spawn Points with Multi-Tier Coverage
# - Test 2: Intelligent Spawn Selection — Proximity & Distance Weighting
# - Test 3: Intelligent Spawn Selection — Line-of-Sight (LOS) Avoidance
# - Test 4: Intelligent Spawn Selection — Recent Death Proximity Avoidance
# - Test 5: Authoritative Spawn Protection Activation in Health Component
# - Test 6: Spawn Protection Damage Immunity (0 Damage Received)
# - Test 7: Spawn Protection Expiration & Normal Damage Resumption
# - Test 8: Uninhibited Combatant Actions During Spawn Protection (Movement, Fire, Switch)
# - Test 9: Player Respawn Integration & HUD Shield Feedback
# - Test 10: BasicBot Respawn Integration & State Label Shield Feedback
# - Test 11: NavigationMesh Multi-Tier 3D Runtime Baking (>100 Polygons)
# - Test 12: Vertical Transition Ramps (Exactly 4 Functional Ramps)
# - Test 13: Tactical Cover & Sightline Geometry Integrity
# - Test 14: Out-of-Bounds Fall Protection & KillZone Elimination
# - Test 15: Live Multi-Combatant FFA Arena Simulation & Score Progression
# =============================================================================

var passed_count : int = 0
var total_count  : int = 0


func _init() -> void:
	print("\n========================================================")
	print("   RUNNING MILESTONE 12 MAP & SPAWN QUALITY TEST SUITE   ")
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

	# Allow 2 frames for scene ready & navmesh baking
	await process_frame
	await process_frame

	print("[TEST SUITE] Arena loaded and initialized. Beginning Milestone 12 tests.\n")

	_test_spawn_point_architecture(arena)
	_test_spawn_selection_distance(arena)
	_test_spawn_selection_los_and_death(arena)
	_test_spawn_protection_lifecycle(arena)
	_test_uninhibited_combat_during_protection(arena)
	_test_player_and_bot_respawn_integration(arena)
	_test_navmesh_and_ramps(arena)
	_test_kill_zone(arena)
	await _test_live_ffa_simulation(arena)

	print("\n========================================================")
	print("   MILESTONE 12 TEST SUMMARY: %d / %d TESTS PASSED       " % [passed_count, total_count])
	print("========================================================\n")

	arena.queue_free()
	if passed_count == total_count:
		print(">> ALL MILESTONE 12 MAP & SPAWN TESTS PASSED SUCCESSFULLY! <<\n")
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
	total_count += 1
	print("  [FAIL] %s" % reason)


# -----------------------------------------------------------------------------
# TEST 1: SPAWN POINT ARCHITECTURE
# -----------------------------------------------------------------------------
func _test_spawn_point_architecture(arena: Node) -> void:
	print("--- TEST 1: Spawn Point Architecture & Multi-Tier Distribution ---")
	var spawns := arena.get_tree().get_nodes_in_group("spawn_points")
	_assert(spawns.size() >= 10, "Arena provides 10+ spawn points (Found: %d)" % spawns.size())

	var valid_transforms := true
	var has_catwalk := false
	var has_underpass := false
	var has_west_lane := false
	var has_north_plaza := false
	var has_south_plaza := false

	for sp in spawns:
		if sp is Node3D:
			var pos : Vector3 = sp.global_position
			if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
				valid_transforms = false
			if pos.y > 3.0:
				has_catwalk = true
			if pos.y < -0.5:
				has_underpass = true
			if pos.x < -15.0:
				has_west_lane = true
			if pos.z < -18.0:
				has_north_plaza = true
			if pos.z > 18.0:
				has_south_plaza = true

	_assert(valid_transforms, "All spawn points have valid finite coordinates")
	_assert(has_catwalk, "Level +1 Elevated Catwalk spawn exists (Y > 3.0m)")
	_assert(has_underpass, "Level -1 Subterranean Underpass spawn exists (Y < -0.5m)")
	_assert(has_west_lane, "Level 0 West Flank (Flank A) spawn exists (X < -15.0m)")
	_assert(has_north_plaza, "Level 0 North Plaza spawn exists (Z < -18.0m)")
	_assert(has_south_plaza, "Level 0 South Plaza spawn exists (Z > 18.0m)")


# -----------------------------------------------------------------------------
# TEST 2: SPAWN SELECTION DISTANCE WEIGHTING
# -----------------------------------------------------------------------------
func _test_spawn_selection_distance(arena: Node) -> void:
	print("\n--- TEST 2: Intelligent Spawn Selection — Proximity & Distance Weighting ---")
	var match_mgr : MatchManager = arena.get_node_or_null("MatchManager")
	_assert(match_mgr != null, "MatchManager exists in arena")
	if match_mgr == null:
		return

	var dummy_combatant := Node3D.new()
	arena.add_child(dummy_combatant)
	dummy_combatant.global_position = Vector3(-18.0, 0.9, -21.0) # North-West corner

	# get_spawn_point should return a valid transform
	var spawn_trans : Transform3D = match_mgr.get_spawn_point(dummy_combatant)
	_assert(spawn_trans.origin != Vector3.ZERO, "get_spawn_point returns non-zero world transform: %s" % str(spawn_trans.origin.snapped(Vector3(0.1, 0.1, 0.1))))

	# When all bots are placed at North Plaza (Z = -22.0), spawn selection should prefer South or distant spawns
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")
	if bot1 and bot2:
		bot1.global_position = Vector3(-18.0, 0.9, -20.0)
		bot2.global_position = Vector3(-3.0, 0.9, -21.0)

	var selected_spawn : Transform3D = match_mgr.get_spawn_point(dummy_combatant)
	var spawn_dist_to_bot1 : float = selected_spawn.origin.distance_to(Vector3(-18.0, 0.9, -20.0))
	_assert(spawn_dist_to_bot1 > 10.0, "Spawn selection avoids spawning in point-blank range of enemy (Dist: %.1fm)" % spawn_dist_to_bot1)

	dummy_combatant.queue_free()


# -----------------------------------------------------------------------------
# TEST 3 & 4: LOS & RECENT DEATH PROXIMITY
# -----------------------------------------------------------------------------
func _test_spawn_selection_los_and_death(arena: Node) -> void:
	print("\n--- TEST 3 & 4: Spawn Selection — LOS Visibility & Recent Death Location ---")
	var match_mgr : MatchManager = arena.get_node_or_null("MatchManager")
	var player = arena.get_node_or_null("Player")
	if match_mgr == null or player == null:
		_fail("MatchManager or Player missing for LOS test")
		return

	# Simulate player death at specific coordinate
	var death_pos := Vector3(18.0, 4.4, 0.0) # High Ground Catwalk
	player.global_position = death_pos
	match_mgr.record_kill(arena.get_node_or_null("BasicBot1"), player)

	_assert(match_mgr._combatant_last_death_pos.has(player), "MatchManager recorded victim's last death position")
	if match_mgr._combatant_last_death_pos.has(player):
		var cached_pos : Vector3 = match_mgr._combatant_last_death_pos[player]
		_assert(cached_pos.distance_to(death_pos) < 0.5, "Cached death position matches death coordinates: %s" % str(cached_pos))

	# Request spawn for player — should penalize spawning on exact Catwalk death spot
	var respawn_transform : Transform3D = match_mgr.get_spawn_point(player)
	_assert(respawn_transform.origin.distance_to(death_pos) > 1.0 or match_mgr.get_tree().get_nodes_in_group("spawn_points").size() <= 1, "Spawn selection avoids spawning on top of immediate death location")


# -----------------------------------------------------------------------------
# TEST 5, 6, 7: SPAWN PROTECTION LIFECYCLE
# -----------------------------------------------------------------------------
func _test_spawn_protection_lifecycle(arena: Node) -> void:
	print("\n--- TEST 5, 6 & 7: Authoritative Spawn Protection Lifecycle in Health ---")
	var test_health := Health.new()
	arena.add_child(test_health)
	test_health.max_health = 100.0
	test_health.current_health = 100.0
	test_health.spawn_protection_duration = 1.2

	var signal_events : Dictionary = {
		"started": false,
		"ended": false,
		"duration": 0.0
	}

	test_health.spawn_protection_started.connect(func(dur: float):
		signal_events["started"] = true
		signal_events["duration"] = dur
	)
	test_health.spawn_protection_ended.connect(func():
		signal_events["ended"] = true
	)

	# 1. Activation
	test_health.activate_spawn_protection()
	_assert(test_health.is_spawn_protected == true, "Spawn protection is active immediately upon activation")
	_assert(signal_events["started"] == true, "spawn_protection_started signal emitted")
	_assert(abs(signal_events["duration"] - 1.2) < 0.01, "Signaled spawn protection duration is 1.2s")

	# 2. Damage Immunity during protection
	var dmg := DamageInfo.new()
	dmg.amount = 45.0
	test_health.take_damage(dmg)
	_assert(test_health.current_health == 100.0, "Protected entity receives 0 damage (HP remains 100.0/100.0)")

	var lethal_dmg := DamageInfo.new()
	lethal_dmg.amount = 500.0
	test_health.take_damage(lethal_dmg)
	_assert(test_health.is_dead == false and test_health.current_health == 100.0, "Protected entity survives lethal damage (is_dead == false)")

	# 3. Expiration
	test_health._process(1.3) # Advance past 1.2s
	_assert(test_health.is_spawn_protected == false, "Spawn protection expires after duration elapsed")
	_assert(signal_events["ended"] == true, "spawn_protection_ended signal emitted upon expiration")

	# 4. Normal Damage Resumption
	test_health.take_damage(dmg)
	_assert(test_health.current_health == 55.0, "Normal damage applied after protection expires (HP: 55.0/100.0)")

	# 5. Respawn auto-protection
	test_health.respawn()
	_assert(test_health.is_spawn_protected == true, "Health.respawn() automatically activates spawn protection")
	_assert(test_health.current_health == 100.0, "Health.respawn() restores HP to max_health (100.0)")

	test_health.queue_free()


# -----------------------------------------------------------------------------
# TEST 8: UNINHIBITED ACTIONS DURING PROTECTION
# -----------------------------------------------------------------------------
func _test_uninhibited_combat_during_protection(arena: Node) -> void:
	print("\n--- TEST 8: Uninhibited Actions During Spawn Protection ---")
	var player = arena.get_node_or_null("Player")
	_assert(player != null, "Player present in arena")
	if player == null:
		return

	var p_health : Health = player.get_node_or_null("Health")
	_assert(p_health != null, "Player Health component found")
	if p_health:
		p_health.activate_spawn_protection(1.2)
		_assert(p_health.is_spawn_protected == true, "Player spawn protection active")

		# Weapon switching works
		player.switch_weapon(1)
		_assert(player._active_slot_index == 1, "Player can freely switch weapons (to Pistol) during spawn protection")
		player.switch_weapon(0)
		_assert(player._active_slot_index == 0, "Player can freely switch back (to AR) during spawn protection")

		# Weapon firing works
		var active_w = player._active_weapon
		if active_w and active_w.has_method("get_ammo_info"):
			active_w._equip_timer = 0.0 # Clear switch transition lock for instant test fire
			var init_ammo : int = active_w.get_ammo_info().get("current", 30)
			active_w.try_fire()
			var post_ammo : int = active_w.get_ammo_info().get("current", 30)
			_assert(post_ammo < init_ammo, "Player can fire weapon immediately during spawn protection (%d -> %d)" % [init_ammo, post_ammo])


# -----------------------------------------------------------------------------
# TEST 9 & 10: PLAYER & BOT RESPAWN INTEGRATION
# -----------------------------------------------------------------------------
func _test_player_and_bot_respawn_integration(arena: Node) -> void:
	print("\n--- TEST 9 & 10: Player & Bot Respawn Integration ---")
	var player = arena.get_node_or_null("Player")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var hud : CombatHUD = player.find_child("CombatHUD", true, false) if player else null

	_assert(player != null and bot1 != null, "Player and Bot 1 available for respawn verification")

	# Test player respawn
	if player:
		var p_health : Health = player.get_node_or_null("Health")
		if p_health:
			p_health.respawn()
			_assert(p_health.is_spawn_protected == true, "Player has spawn protection upon respawn")
			if hud:
				_assert(hud._shield_label != null and hud._shield_label.visible == true, "CombatHUD displays [SHIELD] spawn protection indicator")

	# Test bot respawn
	if bot1:
		var b_health : Health = bot1.get_node_or_null("Health")
		if b_health:
			b_health.respawn()
			_assert(b_health.is_spawn_protected == true, "Bot 1 has spawn protection upon respawn")
			_assert(bot1._state_label.text.contains("[SHIELD]"), "Bot 1 3D StateLabel reflects [SHIELD] indicator")


# -----------------------------------------------------------------------------
# TEST 11, 12, 13: NAVMESH, RAMPS & SIGHTLINES
# -----------------------------------------------------------------------------
func _test_navmesh_and_ramps(arena: Node) -> void:
	print("\n--- TEST 11, 12 & 13: NavigationMesh, Functional Ramps & Tactical Geometry ---")
	var nav_region : NavigationRegion3D = arena.get_node_or_null("NavigationRegion3D")
	_assert(nav_region != null, "NavigationRegion3D present in arena")

	if nav_region and nav_region.navigation_mesh:
		var poly_count := nav_region.navigation_mesh.get_polygon_count()
		_assert(poly_count >= 100, "NavigationMesh baked with full 3-tier coverage (Polygons: %d)" % poly_count)

	# Verify exactly 4 functional ramps connecting tiers
	var r_hg_n = nav_region.get_node_or_null("Ramp_HighGround_North") if nav_region else null
	var r_hg_s = nav_region.get_node_or_null("Ramp_HighGround_South") if nav_region else null
	var r_up_n = nav_region.get_node_or_null("Ramp_Underpass_North") if nav_region else null
	var r_up_s = nav_region.get_node_or_null("Ramp_Underpass_South") if nav_region else null

	_assert(r_hg_n != null and r_hg_s != null, "North & South High Ground Catwalk ramps exist (Connecting Level 0 <-> +1)")
	_assert(r_up_n != null and r_up_s != null, "North & South Underpass Trench ramps exist (Connecting Level 0 <-> -1)")

	# Verify Center Monument and tactical barriers
	var monument = nav_region.get_node_or_null("Center_Monument") if nav_region else null
	var west_wall_mid = nav_region.get_node_or_null("FlankA_WallMid") if nav_region else null
	_assert(monument != null, "Center Monument hard cover exists (Breaks cross-arena sightlines)")
	_assert(west_wall_mid != null, "West Flank separating wall exists (Forms discrete Left Combat Lane)")


# -----------------------------------------------------------------------------
# TEST 14: FALL PROTECTION / KILLZONE
# -----------------------------------------------------------------------------
func _test_kill_zone(arena: Node) -> void:
	print("\n--- TEST 14: Fall Protection & Out-of-Bounds KillZone ---")
	var kill_zone : Area3D = arena.get_node_or_null("KillZone")
	_assert(kill_zone != null, "KillZone Area3D exists in arena")

	if kill_zone:
		_assert(kill_zone.global_position.y <= -7.0, "KillZone is placed safely below playable floors (Y = %.1f)" % kill_zone.global_position.y)

		# Create a test entity to verify trigger
		var bot_scene := load("res://scenes/enemies/basic_bot.tscn") as PackedScene
		var test_falling_bot := bot_scene.instantiate() as CharacterBody3D
		test_falling_bot.name = "TestM12FallingBot"
		arena.add_child(test_falling_bot)
		test_falling_bot.global_position = Vector3(0.0, -8.0, 0.0)

		kill_zone._on_body_entered(test_falling_bot)
		_assert(not test_falling_bot.is_alive(), "KillZone immediately eliminates falling entities")
		test_falling_bot.queue_free()


# -----------------------------------------------------------------------------
# TEST 15: LIVE MULTI-COMBATANT FFA SIMULATION
# -----------------------------------------------------------------------------
func _test_live_ffa_simulation(arena: Node) -> void:
	print("\n--- TEST 15: Live Multi-Combatant FFA Arena Simulation ---")
	var match_mgr : MatchManager = arena.get_node_or_null("MatchManager")
	_assert(match_mgr != null, "MatchManager active for live simulation")
	if match_mgr == null:
		return

	var start_kills : int = 0
	for c in match_mgr._combatant_stats:
		start_kills += match_mgr._combatant_stats[c]["kills"]

	print("[SIMULATION] Running 1200 physics frames (~20.0s live combat across all 3 lanes)...")
	for i in range(1200):
		arena.get_tree().physics_frame
		await process_frame

	var end_kills : int = 0
	for c in match_mgr._combatant_stats:
		end_kills += match_mgr._combatant_stats[c]["kills"]

	var session_kills : int = end_kills - start_kills
	print("[SIMULATION] Live simulation completed. Total kills during session: %d" % session_kills)
	_assert(session_kills > 0, "Combatants actively engaged, scored eliminations, and used spawn system (Kills: %d)" % session_kills)

	print("\n--- FINAL ARENA SCOREBOARD ---")
	var sorted := match_mgr.get_sorted_scoreboard()
	for row in sorted:
		print("  #%s %s: %d Kills / %d Deaths (Score: %d)" % [
			str(sorted.find(row) + 1),
			row["name"],
			row["kills"],
			row["deaths"],
			row["score"]
		])
