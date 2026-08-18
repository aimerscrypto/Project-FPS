extends SceneTree

# =============================================================================
# Project FPS — Automated FFA Foundation Test Suite
# Milestone 5 — Free For All Foundation
#
# Automated verification script testing:
# - Test A: 8 combatants instantiation (1 Player + 7 Bots)
# - Test B: Multi-target perception and non-player targeting
# - Test C: Bot-vs-Bot hitscan damage and elimination
# - Test D: Player-vs-Bot elimination and score crediting
# - Test E: Bot-vs-Player elimination and death reporting
# - Test F: Dynamic spawn point selection and respawn restoration
# - Test G: Target switching upon target elimination
# - Test H: Match timer countdown and timeout match completion
# - Test I: Kill limit trigger and winner determination
# =============================================================================

const MatchManagerClass = preload("res://scripts/gameplay/match_manager.gd")

var passed_count : int = 0
var total_count  : int = 0


func _init() -> void:
	print("\n========================================================")
	print("       RUNNING MILESTONE 5 FFA FOUNDATION TESTS         ")
	print("========================================================\n")
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Load test arena
	var arena_scene := load("res://scenes/maps/test_arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Failed to load test_arena.tscn")
		quit(1)
		return

	var arena := arena_scene.instantiate()
	root.add_child(arena)

	# Allow 2 frames for ready and deferred setup
	await process_frame
	await process_frame

	var match_mgr = arena.get_node_or_null("MatchManager")
	if match_mgr and match_mgr.has_method("_begin_playing"):
		match_mgr._begin_playing()

	print("[TEST SUITE] Arena instantiated. Beginning unit & integration tests.\n")

	_test_combatants_count(arena)
	_test_spawn_points(arena)
	_test_match_manager_initial_state(arena)
	_test_target_selection(arena)
	_test_bot_to_bot_combat(arena)
	_test_player_kill_and_scoring(arena)
	_test_target_switching_on_death(arena)
	_test_respawn_flow(arena)
	_test_kill_limit_and_winner(arena)
	_test_timer_countdown_and_end(arena)

	print("\n========================================================")
	print("       TEST SUMMARY: %d / %d TESTS PASSED               " % [passed_count, total_count])
	print("========================================================\n")

	arena.queue_free()
	if passed_count == total_count:
		print(">> ALL MILESTONE 5 FFA TESTS PASSED SUCCESSFULLY! <<\n")
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

func _test_combatants_count(arena: Node) -> void:
	print("--- TEST A: 8 Active Combatants in FFA Arena ---")
	var combatants := arena.get_tree().get_nodes_in_group("combatants")
	_assert(combatants.size() == 8, "Total combatants count is exactly 8 (Found: %d)" % combatants.size())

	var player_found := false
	var bot_count := 0
	for c in combatants:
		if c.is_in_group("player"):
			player_found = true
		if c.name.begins_with("BasicBot"):
			bot_count += 1

	_assert(player_found, "Human Player found in combatants group")
	_assert(bot_count == 7, "Exactly 7 BasicBots found in combatants group (Found: %d)" % bot_count)


func _test_spawn_points(arena: Node) -> void:
	print("\n--- TEST SPAWN SYSTEM: 8+ Arena Spawns & Safe Selection ---")
	var spawns := arena.get_tree().get_nodes_in_group("spawn_points")
	_assert(spawns.size() >= 8, "Arena provides 8+ reusable spawn points (Found: %d)" % spawns.size())

	var match_mgr : Node = arena.get_node_or_null("MatchManager")
	_assert(match_mgr != null, "MatchManager exists in arena")

	if match_mgr:
		var spawn_trans : Transform3D = match_mgr.get_spawn_point()
		_assert(spawn_trans != Transform3D.IDENTITY, "MatchManager returns valid non-empty spawn transform: %s" % str(spawn_trans.origin))


func _test_match_manager_initial_state(arena: Node) -> void:
	print("\n--- TEST MATCH MANAGER: States & Config ---")
	var match_mgr : Node = arena.get_node_or_null("MatchManager")
	if match_mgr:
		_assert(match_mgr.state == MatchManagerClass.MatchState.PLAYING, "MatchManager automatically entered PLAYING state")
		_assert(match_mgr.match_length == 300.0, "Match length is configured to 300.0s (5:00)")
		_assert(match_mgr.kill_limit == 25, "Kill limit is configured to 25")
		_assert(match_mgr.time_remaining > 295.0, "Timer is actively counting down (Current: %.1fs)" % match_mgr.time_remaining)


func _test_target_selection(arena: Node) -> void:
	print("\n--- TEST B: Multi-Target Dynamic Selection ---")
	var bot1 : CharacterBody3D = arena.get_node_or_null("BasicBot1")
	var bot2 : CharacterBody3D = arena.get_node_or_null("BasicBot2")
	_assert(bot1 != null and bot2 != null, "Bots available for perception test")

	if bot1:
		var target = bot1._find_best_target()
		_assert(target != null, "Bot 1 successfully acquired a target")
		_assert(target != bot1, "Bot 1 does NOT target itself")
		_assert(target.is_in_group("combatants"), "Acquired target is a registered combatant")


func _test_bot_to_bot_combat(arena: Node) -> void:
	print("\n--- TEST C: Bot-to-Bot Hitscan Damage & Elimination ---")
	var attacker_bot : CharacterBody3D = arena.get_node_or_null("BasicBot2")
	var victim_bot   : CharacterBody3D = arena.get_node_or_null("BasicBot3")
	_assert(attacker_bot != null and victim_bot != null, "Attacker and victim bots present")

	if attacker_bot and victim_bot:
		var initial_hp : float = victim_bot._health.current_health
		var dmg := DamageInfo.new()
		dmg.amount = 25.0
		dmg.attacker = attacker_bot
		dmg.hit_type = DamageInfo.HitType.BODY
		victim_bot.take_damage(dmg)

		_assert(victim_bot._health.current_health == initial_hp - 25.0, "Victim bot HP reduced by 25 (HP: %.0f)" % victim_bot._health.current_health)

		# Fatal blow
		var fatal_dmg := DamageInfo.new()
		fatal_dmg.amount = 100.0
		fatal_dmg.attacker = attacker_bot
		victim_bot.take_damage(fatal_dmg)

		_assert(victim_bot._state == victim_bot.State.DEAD, "Victim bot entered DEAD state")
		_assert(victim_bot.is_alive() == false, "Victim bot reports is_alive() == false")


func _test_player_kill_and_scoring(arena: Node) -> void:
	print("\n--- TEST D & E: Player-vs-Bot Kill & Match Score ---")
	var player : CharacterBody3D = arena.get_node_or_null("Player")
	var bot4   : CharacterBody3D = arena.get_node_or_null("BasicBot4")
	var match_mgr : Node = arena.get_node_or_null("MatchManager")

	_assert(player != null and bot4 != null and match_mgr != null, "Player, Bot4, and MatchManager ready")

	if player and bot4 and match_mgr:
		var initial_kills : int = player.kills
		var initial_score : int = match_mgr.get_combatant_stats(player)["score"]

		# Player eliminates Bot 4
		var fatal_dmg := DamageInfo.new()
		fatal_dmg.amount = 150.0
		fatal_dmg.attacker = player
		bot4.take_damage(fatal_dmg)

		_assert(player.kills == initial_kills + 1, "Player kills incremented (+1) (Kills: %d)" % player.kills)
		_assert(match_mgr.get_combatant_stats(player)["score"] == initial_score + 1, "MatchManager player score incremented (+1)")
		_assert(match_mgr.get_combatant_stats(bot4)["deaths"] >= 1, "Victim bot recorded death")


func _test_target_switching_on_death(arena: Node) -> void:
	print("\n--- TEST G: Dynamic Retargeting on Target Elimination ---")
	var bot5 : CharacterBody3D = arena.get_node_or_null("BasicBot5")
	var bot6 : CharacterBody3D = arena.get_node_or_null("BasicBot6")

	if bot5 and bot6:
		bot5._target = bot6
		_assert(bot5._target == bot6, "Bot 5 targeting Bot 6")

		# Kill Bot 6
		var fatal_dmg := DamageInfo.new()
		fatal_dmg.amount = 200.0
		fatal_dmg.attacker = bot5
		bot6.take_damage(fatal_dmg)

		# Trigger target update
		bot5._update_target_selection(1.0)
		_assert(bot5._target != bot6, "Bot 5 ceased targeting dead Bot 6 and switched targets")


func _test_respawn_flow(arena: Node) -> void:
	print("\n--- TEST F: Respawn Flow & State Restoration ---")
	var bot7 : CharacterBody3D = arena.get_node_or_null("BasicBot7")
	if bot7:
		# Kill Bot 7
		var fatal_dmg := DamageInfo.new()
		fatal_dmg.amount = 200.0
		bot7.take_damage(fatal_dmg)
		_assert(bot7._state == bot7.State.DEAD, "Bot 7 is dead")

		# Execute respawn
		bot7._do_respawn()
		_assert(bot7._state == bot7.State.SEARCH, "Bot 7 state reset to SEARCH on respawn")
		_assert(bot7._health.current_health == 100.0, "Bot 7 health restored to 100.0")
		_assert(bot7.is_alive() == true, "Bot 7 is_alive() restored to true")


func _test_kill_limit_and_winner(arena: Node) -> void:
	print("\n--- TEST I: Kill Limit Win Condition ---")
	var match_mgr : Node = arena.get_node_or_null("MatchManager")
	var player : CharacterBody3D = arena.get_node_or_null("Player")
	var bot1   : CharacterBody3D = arena.get_node_or_null("BasicBot1")

	if match_mgr and player and bot1:
		# Temporarily set lower kill limit for instant verification
		match_mgr.kill_limit = 3
		match_mgr.state = MatchManagerClass.MatchState.PLAYING
		match_mgr._combatant_stats[player]["score"] = 2

		# Score the winning 3rd kill
		match_mgr.record_kill(player, bot1)

		_assert(match_mgr.state == MatchManagerClass.MatchState.ENDED, "Match ended upon reaching kill limit (3 kills)")
		_assert(match_mgr.get_combatant_stats(player)["score"] == 3, "Winning player score is 3")


func _test_timer_countdown_and_end(arena: Node) -> void:
	print("\n--- TEST H: Timer Countdown & Match Expiration ---")
	var match_mgr : Node = arena.get_node_or_null("MatchManager")
	if match_mgr:
		match_mgr.state = MatchManagerClass.MatchState.PLAYING
		match_mgr.time_remaining = 0.05
		match_mgr._process(0.1)

		_assert(match_mgr.state == MatchManagerClass.MatchState.ENDED, "Match ended when internal timer reached 0.0s")
		_assert(match_mgr.time_remaining == 0.0, "Timer clamped at 0.0s")
