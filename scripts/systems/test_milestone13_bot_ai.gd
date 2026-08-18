extends SceneTree

# =============================================================================
# Project FPS — Automated Milestone 13 Bot AI & Combat Intelligence Test Suite
# Milestone 13 — Bot AI & Combat Intelligence
#
# Automated verification testing:
# - Test 1: Vision Cone & FOV-Based Perception (Cone test & angle gating)
# - Test 2: Close Proximity & Hearing Presence (360° awareness within hearing range)
# - Test 3: Damage Stimulus Alertness (Attacker behind bot alerts bot upon hit)
# - Test 4: Line of Sight (LOS) Occlusion against Arena Geometry
# - Test 5: Last-Known-Position (LKP) Recording & Target Memory
# - Test 6: Investigation State Lifecycle & Memory Decay (LKP -> Search)
# - Test 7: Controlled Reaction Time & Fire Alignment Tolerance
# - Test 8: Dynamic Combat Strafing & Distance Maintenance
# - Test 9: Tactical Cover Seeking under Critical Damage / Reload
# - Test 10: Intelligent Tactical Reload in Safe / Non-Combat States
# - Test 11: Multi-Factor Target Prioritization Scoring & Stickiness
# - Test 12: Data-Driven Difficulty Presets (Easy, Medium, Hard)
# - Test 13: 3D StateLabel & Shield Visual Status Feedback
# - Test 14: Match Lifecycle Suppression & Clean Respawn Loop
# - Test 15: Live Multi-Combatant FFA Arena Simulation & Score Progression
# =============================================================================

var passed_count : int = 0
var total_count  : int = 0


func _init() -> void:
	print("\n========================================================")
	print("   RUNNING MILESTONE 13 BOT AI & COMBAT INTELLIGENCE   ")
	print("========================================================\n")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var arena_scene = load("res://scenes/maps/test_arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Failed to load scenes/maps/test_arena.tscn")
		quit(1)
		return

	var arena = arena_scene.instantiate()
	root.add_child(arena)

	# Allow 2 frames for scene ready & navmesh baking
	await process_frame
	await process_frame

	print("[TEST SUITE] Arena loaded and initialized. Beginning Milestone 13 tests.\n")

	_test_fov_and_cone_perception(arena)
	_test_hearing_and_proximity(arena)
	_test_damage_stimulus_alertness(arena)
	_test_los_geometry_occlusion(arena)
	_test_lkp_and_target_memory(arena)
	_test_investigation_lifecycle(arena)
	_test_reaction_and_fire_tolerance(arena)
	_test_combat_strafing(arena)
	_test_tactical_cover_behavior(arena)
	_test_tactical_reload(arena)
	_test_target_scoring_and_stickiness(arena)
	_test_difficulty_presets(arena)
	_test_state_label_and_shield(arena)
	_test_match_lifecycle_compatibility(arena)
	await _test_live_ffa_simulation(arena)

	print("\n========================================================")
	print("   MILESTONE 13 TEST SUMMARY: %d / %d TESTS PASSED       " % [passed_count, total_count])
	print("========================================================\n")

	arena.queue_free()
	if passed_count == total_count:
		print(">> ALL MILESTONE 13 BOT AI TESTS PASSED SUCCESSFULLY! <<\n")
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
# TEST 1: FOV & VISION CONE PERCEPTION
# -----------------------------------------------------------------------------
func _test_fov_and_cone_perception(arena: Node) -> void:
	print("--- TEST 1: Vision Cone & FOV-Based Perception ---")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")
	_assert(bot1 != null and bot2 != null, "Test bots available for FOV verification")

	if bot1 and bot2:
		bot1.global_position = Vector3(0.0, 0.9, 0.0)
		bot1.rotation.y = 0.0 # Facing -Z (North)
		bot1.fov_degrees = 115.0

		# Position target in front of bot (North at Z = -10)
		var front_target = Vector3(0.0, 0.9, -10.0)
		var in_front = bot1._is_target_in_fov(bot2, front_target)
		_assert(bool(in_front) == true, "Target directly in front (0°) is detected within FOV cone")

		# Position target 45° to the right (well within 115° cone, which is ±57.5°)
		var angle_45_target = Vector3(7.0, 0.9, -7.0)
		var in_45 = bot1._is_target_in_fov(bot2, angle_45_target)
		_assert(bool(in_45) == true, "Target at 45° azimuth is detected within 115° FOV cone")

		# Position target 90° directly to the right (outside 115° cone)
		var right_target = Vector3(12.0, 0.9, 0.0)
		var in_right = bot1._is_target_in_fov(bot2, right_target)
		_assert(bool(in_right) == false, "Target at 90° azimuth (perpendicular) is NOT detected without stimulus")

		# Position target directly behind bot (South at Z = +10, outside hearing range)
		var behind_target = Vector3(0.0, 0.9, 10.0)
		var in_behind = bot1._is_target_in_fov(bot2, behind_target)
		_assert(bool(in_behind) == false, "Target directly behind bot (180°) is NOT detected without stimulus")


# -----------------------------------------------------------------------------
# TEST 2: CLOSE PROXIMITY & HEARING PRESENCE
# -----------------------------------------------------------------------------
func _test_hearing_and_proximity(arena: Node) -> void:
	print("\n--- TEST 2: Close Proximity & Hearing Presence ---")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")

	if bot1 and bot2:
		bot1.global_position = Vector3(0.0, 0.9, 0.0)
		bot1.rotation.y = 0.0 # Facing North (-Z)
		bot1.hearing_range = 3.5

		# Position target directly behind bot at 2.0m distance (within hearing range)
		var close_behind = Vector3(0.0, 0.9, 2.0)
		var heard_behind = bot1._is_target_in_fov(bot2, close_behind)
		_assert(bool(heard_behind) == true, "Close-range target behind bot (< 3.5m) is detected via hearing/proximity")

		# Position target behind bot at 5.0m distance (outside hearing range)
		var far_behind = Vector3(0.0, 0.9, 5.0)
		var heard_far = bot1._is_target_in_fov(bot2, far_behind)
		_assert(bool(heard_far) == false, "Target outside hearing range (> 3.5m) behind bot is not detected")


# -----------------------------------------------------------------------------
# TEST 3: DAMAGE STIMULUS ALERTNESS
# -----------------------------------------------------------------------------
func _test_damage_stimulus_alertness(arena: Node) -> void:
	print("\n--- TEST 3: Damage Stimulus Alertness ---")
	var victim_bot   = arena.get_node_or_null("BasicBot3")
	var attacker_bot = arena.get_node_or_null("BasicBot4")

	if victim_bot and attacker_bot:
		victim_bot.global_position = Vector3(0.0, 0.9, 0.0)
		victim_bot.rotation.y = 0.0 # Facing North
		victim_bot._target = null
		victim_bot._recent_attacker = null

		# Position attacker 10m directly behind victim
		attacker_bot.global_position = Vector3(0.0, 0.9, 10.0)

		# Attacker deals damage to victim
		var dmg = DamageInfo.new()
		dmg.amount = 15.0
		dmg.attacker = attacker_bot
		dmg.hit_position = victim_bot.global_position
		victim_bot.take_damage(dmg)

		_assert(victim_bot._recent_attacker == attacker_bot, "Bot records attacker reference upon taking damage")
		_assert(victim_bot._recent_attacker_timer > 0.0, "Attacker alertness timer is active")
		_assert(victim_bot._target == attacker_bot, "Bot immediately acquires unseen attacker behind it upon being hit")
		_assert(victim_bot._last_known_target_pos == attacker_bot.global_position, "Attacker position saved as LKP")


# -----------------------------------------------------------------------------
# TEST 4: LINE OF SIGHT (LOS) GEOMETRY OCCLUSION
# -----------------------------------------------------------------------------
func _test_los_geometry_occlusion(arena: Node) -> void:
	print("\n--- TEST 4: Line of Sight (LOS) Occlusion ---")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")

	if bot1 and bot2:
		# Place bots on opposite sides of the Center Monument (Center Hub: X: -3.5, Z: 0)
		bot1.global_position = Vector3(-3.5, 0.9, -8.0) # North of monument
		bot2.global_position = Vector3(-3.5, 0.9, 8.0)  # South of monument

		var los_blocked = not bot1._check_line_of_sight(bot2, bot2.get_target_position())
		_assert(bool(los_blocked) == true, "Line of Sight is obstructed through Center Monument hard cover")

		# Move bot2 to open sightline (West of monument: X = -15, Z = -8)
		bot2.global_position = Vector3(-15.0, 0.9, -8.0)
		var los_clear = bot1._check_line_of_sight(bot2, bot2.get_target_position())
		_assert(bool(los_clear) == true, "Line of Sight is clear across unobstructed arena ground")


# -----------------------------------------------------------------------------
# TEST 5: LAST-KNOWN-POSITION (LKP) RECORDING & TARGET MEMORY
# -----------------------------------------------------------------------------
func _test_lkp_and_target_memory(arena: Node) -> void:
	print("\n--- TEST 5: Last-Known-Position (LKP) & Memory ---")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")

	if bot1 and bot2:
		bot1.global_position = Vector3(0.0, 0.9, 0.0)
		bot2.global_position = Vector3(0.0, 0.9, -8.0)
		bot1._target = bot2
		bot1.target_persistence = 3.5

		# Process combat AI frame with clear LOS
		bot1._process_combat_ai(0.016)

		_assert(bot1._last_known_target_pos == bot2.global_position, "LKP coordinate matches active target position: %s" % str(bot1._last_known_target_pos))
		_assert(bot1._target_memory_timer == 3.5, "Target memory timer refreshed to persistence duration (3.5s)")


# -----------------------------------------------------------------------------
# TEST 6: INVESTIGATION LIFECYCLE & MEMORY DECAY
# -----------------------------------------------------------------------------
func _test_investigation_lifecycle(arena: Node) -> void:
	print("\n--- TEST 6: Investigation Lifecycle & Memory Decay ---")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")

	if bot1 and bot2:
		bot1.global_position = Vector3(0.0, 0.9, 0.0)
		bot1._target = bot2
		bot1._last_known_target_pos = Vector3(0.0, 0.9, -10.0)
		bot1._target_memory_timer = 2.0
		bot1._investigate_timer = 0.0

		# Hide bot2 behind monument to break LOS
		bot2.global_position = Vector3(-3.5, 0.9, 12.0)
		bot1.global_position = Vector3(-3.5, 0.9, -12.0)

		# Run combat AI frame
		bot1._process_combat_ai(0.1)

		_assert(bot1._state == bot1.State.INVESTIGATE, "Bot transitions to INVESTIGATE state when LOS is broken with active memory")

		# Simulate reaching LKP and decaying memory
		bot1.global_position = bot1._last_known_target_pos
		bot1._target_memory_timer = 0.05
		bot1._investigate_timer = 0.05
		bot1._process_investigate_state(0.1) # Timer expires

		_assert(bot1._state == bot1.State.SEARCH, "Bot cleanly transitions to SEARCH state after memory decay")
		_assert(bot1._target == null, "Target reference cleared upon investigation completion")


# -----------------------------------------------------------------------------
# TEST 7: REACTION TIME & FIRE ALIGNMENT TOLERANCE
# -----------------------------------------------------------------------------
func _test_reaction_and_fire_tolerance(arena: Node) -> void:
	print("\n--- TEST 7: Reaction Time & Fire Alignment Tolerance ---")
	var bot1 = arena.get_node_or_null("BasicBot1")

	if bot1:
		bot1.global_position = Vector3(0.0, 0.9, 0.0)
		bot1.rotation.y = 0.0 # Facing North (-Z)
		bot1.fire_tolerance_degrees = 12.0
		bot1._reaction_timer = 0.0
		bot1._has_los = true
		bot1._is_reloading = false
		bot1._current_ammo = 15

		# Target directly in front (angle 0°)
		var front_aim = Vector3(0.0, 0.9, -10.0)
		var can_fire_front = bot1._can_pull_trigger(front_aim)
		_assert(bool(can_fire_front) == true, "Trigger is pulled when aim vector is aligned (0° error <= 12° tolerance)")

		# Target at 45° offset (angle 45° > 12° tolerance)
		var offset_aim = Vector3(7.0, 0.9, -7.0)
		var can_fire_offset = bot1._can_pull_trigger(offset_aim)
		_assert(bool(can_fire_offset) == false, "Trigger is withheld when bot is not sufficiently aimed (45° error > 12° tolerance)")

		# Reaction timer check
		bot1._reaction_timer = 0.35
		var can_fire_reacting = bot1._can_pull_trigger(front_aim)
		_assert(bool(can_fire_reacting) == false, "Trigger is withheld while reaction delay timer is active")


# -----------------------------------------------------------------------------
# TEST 8: DYNAMIC COMBAT STRAFING & LATERAL MOVEMENT
# -----------------------------------------------------------------------------
func _test_combat_strafing(arena: Node) -> void:
	print("\n--- TEST 8: Dynamic Combat Strafing ---")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")

	if bot1 and bot2:
		bot1.global_position = Vector3(0.0, 0.9, 0.0)
		bot2.global_position = Vector3(0.0, 0.9, -10.0)
		bot1._target = bot2
		bot1._has_los = true
		bot1._reaction_timer = 0.0
		bot1._strafe_pause_timer = 0.0
		bot1._strafe_dir = 1.0

		# Process combat AI in ideal combat range (10m)
		bot1._process_combat_ai(0.1)

		var lateral_speed : float = abs(bot1.velocity.x)
		_assert(lateral_speed > 0.5, "Bot generates lateral velocity during combat strafe (Speed: %.2f m/s)" % lateral_speed)
		_assert(bot1._state == bot1.State.ATTACK or bot1._state == bot1.State.CHASE, "Bot maintains combat state during strafe")


# -----------------------------------------------------------------------------
# TEST 9: TACTICAL COVER EVALUATION UNDER DAMAGE
# -----------------------------------------------------------------------------
func _test_tactical_cover_behavior(arena: Node) -> void:
	print("\n--- TEST 9: Tactical Cover Behavior ---")
	var bot1 = arena.get_node_or_null("BasicBot1")

	if bot1:
		# Place bot near center arena monument
		bot1.global_position = Vector3(-3.5, 0.9, -4.5)
		var threat_pos = Vector3(-3.5, 0.9, 8.0)

		# Search for cover against threat
		var cover_pos = bot1._find_cover_position(threat_pos)
		_assert(cover_pos != Vector3.ZERO, "Bot successfully identifies a geometric cover position: %s" % str(cover_pos))

		if cover_pos != Vector3.ZERO:
			# Verify cover breaks LOS to threat
			var space = bot1.get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(cover_pos + Vector3(0, 1.4, 0), threat_pos + Vector3(0, 1.4, 0), 1)
			var hit = space.intersect_ray(query)
			_assert(not hit.is_empty(), "Identified cover position physically obstructs Line of Sight to threat")


# -----------------------------------------------------------------------------
# TEST 10: INTELLIGENT TACTICAL RELOAD
# -----------------------------------------------------------------------------
func _test_tactical_reload(arena: Node) -> void:
	print("\n--- TEST 10: Intelligent Tactical Reload ---")
	var bot1 = arena.get_node_or_null("BasicBot1")

	if bot1:
		bot1._current_ammo = 4 # < 40% of 15 mag
		bot1._is_reloading = false
		bot1._has_los = false

		# In search/patrol state, bot should tactically reload
		bot1._process_search_state(0.05)

		_assert(bot1._is_reloading == true, "Bot initiates tactical reload during quiet search/patrol when ammo is low")
		_assert(bot1._reload_timer > 0.0, "Reload countdown timer is active (%.1fs)" % bot1._reload_timer)


# -----------------------------------------------------------------------------
# TEST 11: MULTI-TARGET PRIORITIZATION SCORING & STICKINESS
# -----------------------------------------------------------------------------
func _test_target_scoring_and_stickiness(arena: Node) -> void:
	print("\n--- TEST 11: Multi-Target Prioritization Scoring ---")
	var bot1 = arena.get_node_or_null("BasicBot1")
	var bot2 = arena.get_node_or_null("BasicBot2")
	var bot3 = arena.get_node_or_null("BasicBot3")

	if bot1 and bot2 and bot3:
		bot1.global_position = Vector3(0.0, 0.9, 0.0)
		bot1.rotation.y = 0.0 # Facing North

		# Bot 2 is in front at 8m (clear LOS & FOV)
		bot2.global_position = Vector3(0.0, 0.9, -8.0)

		# Bot 3 is in front at 22m (farther away)
		bot3.global_position = Vector3(0.0, 0.9, -22.0)

		var target = bot1._find_best_target()
		_assert(target == bot2, "Nearest visible candidate in FOV is prioritized as primary target")

		# Target stickiness check: Set current target to bot3, even if bot2 is slightly closer
		bot1._target = bot3
		bot2.global_position = Vector3(0.0, 0.9, -19.0) # slightly closer than bot3 (22m)
		var sticky_target = bot1._find_best_target()
		_assert(sticky_target == bot3, "Target stickiness bonus prevents flip-flopping between close distance competitors")


# -----------------------------------------------------------------------------
# TEST 12: DATA-DRIVEN DIFFICULTY PRESETS
# -----------------------------------------------------------------------------
func _test_difficulty_presets(arena: Node) -> void:
	print("\n--- TEST 12: Data-Driven Difficulty Presets ---")
	var bot1 = arena.get_node_or_null("BasicBot1")

	if bot1:
		bot1.apply_difficulty_preset(bot1.Difficulty.EASY)
		_assert(bot1.reaction_delay == 0.50 and bot1.attack_spread_degrees == 4.5, "EASY preset applied (Reaction: 0.50s, Spread: 4.5°)")

		bot1.apply_difficulty_preset(bot1.Difficulty.MEDIUM)
		_assert(bot1.reaction_delay == 0.32 and bot1.attack_spread_degrees == 2.8, "MEDIUM preset applied (Reaction: 0.32s, Spread: 2.8°)")

		bot1.apply_difficulty_preset(bot1.Difficulty.HARD)
		_assert(bot1.reaction_delay == 0.20 and bot1.attack_spread_degrees == 1.6 and bot1.turn_speed == 9.0, "HARD preset applied (Reaction: 0.20s, Spread: 1.6°, Turn: 9.0 rad/s)")

		# Restore medium default
		bot1.apply_difficulty_preset(bot1.Difficulty.MEDIUM)


# -----------------------------------------------------------------------------
# TEST 13: 3D STATELABEL & SHIELD STATUS FEEDBACK
# -----------------------------------------------------------------------------
func _test_state_label_and_shield(arena: Node) -> void:
	print("\n--- TEST 13: 3D StateLabel & Shield Feedback ---")
	var bot1 = arena.get_node_or_null("BasicBot1")

	if bot1 and is_instance_valid(bot1._state_label):
		bot1._set_state(bot1.State.ATTACK)
		_assert(bot1._state_label.text.begins_with("STATE: ATTACK"), "StateLabel reflects STATE: ATTACK")

		bot1._set_state(bot1.State.INVESTIGATE)
		_assert(bot1._state_label.text.begins_with("STATE: INVESTIGATE"), "StateLabel reflects STATE: INVESTIGATE")

		bot1._set_state(bot1.State.COVER)
		_assert(bot1._state_label.text.begins_with("STATE: COVER"), "StateLabel reflects STATE: COVER")

		# Test shield indicator
		if bot1._health:
			bot1._health.activate_spawn_protection(1.0)
			bot1._update_state_label()
			_assert(bot1._state_label.text.contains("[SHIELD]"), "StateLabel dynamically displays [SHIELD] during spawn protection")
			bot1._health.is_spawn_protected = false
			bot1._update_state_label()


# -----------------------------------------------------------------------------
# TEST 14: MATCH LIFECYCLE SUPPRESSION & CLEAN RESPAWN
# -----------------------------------------------------------------------------
func _test_match_lifecycle_compatibility(arena: Node) -> void:
	print("\n--- TEST 14: Match Lifecycle Compatibility ---")
	var bot1 = arena.get_node_or_null("BasicBot1")

	if bot1:
		bot1._on_match_ended(null)
		_assert(bot1._is_match_ended == true, "Bot records match end state")
		_assert(bot1._target == null, "Target reference safely cleared on match end")
		_assert(bot1.velocity == Vector3.ZERO, "Velocity cleanly zeroed on match end")

		# Restore active match state
		bot1._is_match_ended = false
		bot1._on_respawned()
		_assert(bot1.is_alive() == true, "Bot safely revived through respawn callback")
		_assert(bot1._state == bot1.State.SEARCH, "Bot state resets to SEARCH upon respawn")


# -----------------------------------------------------------------------------
# TEST 15: LIVE MULTI-COMBATANT FFA ARENA SIMULATION
# -----------------------------------------------------------------------------
func _test_live_ffa_simulation(arena: Node) -> void:
	print("\n--- TEST 15: Live Multi-Combatant FFA Arena AI Simulation ---")
	var match_mgr = arena.get_node_or_null("MatchManager")
	_assert(match_mgr != null and (match_mgr.is_playing() or match_mgr.is_staging()), "MatchManager active for live simulation")

	var initial_scoreboard : Array = match_mgr.get_sorted_scoreboard()
	var initial_total_kills : int = 0
	for entry in initial_scoreboard:
		initial_total_kills += int(entry["kills"])

	print("[SIMULATION] Running 1200 physics frames (~20.0s live AI combat with strafing & cover)...")
	for i in range(1200):
		arena.get_tree().physics_frame
		await process_frame

	var end_scoreboard : Array = match_mgr.get_sorted_scoreboard()
	var final_total_kills : int = 0
	for entry in end_scoreboard:
		final_total_kills += int(entry["kills"])

	var eliminations_during_sim : int = final_total_kills - initial_total_kills
	print("[SIMULATION] Live simulation completed. Total kills during session: %d" % eliminations_during_sim)

	_assert(eliminations_during_sim >= 1, "Combatants actively engaged with AI strafing, scoring eliminations (Kills: %d)" % eliminations_during_sim)

	print("\n--- FINAL ARENA SCOREBOARD ---")
	for i in range(end_scoreboard.size()):
		var e : Dictionary = end_scoreboard[i]
		print("  #%d %s: %d Kills / %d Deaths (Score: %d)" % [i + 1, e["name"], e["kills"], e["deaths"], e["score"]])
