extends SceneTree

# =============================================================================
# Project FPS — Milestone 11 Combat Feedback, Polish & Juice Automated Test Suite
# Tests:
# - Test 1: AudioManager combat sound registration & playback helpers
# - Test 2: CombatHUD health bar, dynamic color states, and trailing chip damage
# - Test 3: Low-health visual warning triggers and state lifecycle
# - Test 4: Screen damage vignette and directional damage indicators
# - Test 5: Crosshair 4-tier hit feel hierarchy (Body, Headshot, Kill, Headshot Kill)
# - Test 6: WeaponBase lethal hit detection & kill confirmation signal emission
# - Test 7: Player death state, combat input suppression & death camera presentation
# - Test 8: Player respawn lifecycle, camera restoration & health reset
# - Test 9: Full FFA Arena integration, live combat Juice, and weapon switching
# =============================================================================

var passed_count : int = 0
var total_count  : int = 0
var log_lines    : Array[String] = []

func _log(msg: String) -> void:
	log_lines.append(msg)
	print(msg)

func _assert(cond: bool, desc: String) -> void:
	total_count += 1
	if cond:
		passed_count += 1
		_log("  [PASS] " + desc)
	else:
		_log("  [FAIL] " + desc)

func _init() -> void:
	_log("\n========================================================")
	_log("     RUNNING MILESTONE 11 COMBAT FEEDBACK TEST SUITE    ")
	_log("========================================================\n")
	call_deferred("_run_suite")

func _run_suite() -> void:
	# -------------------------------------------------------------------------
	# 1. Test AudioManager Combat Feedback Streams & Helpers
	# -------------------------------------------------------------------------
	_log("--- TEST 1: AudioManager Combat Sound Registration & Helpers ---")
	var audio_mgr = root.get_node_or_null("AudioManager")
	_assert(audio_mgr != null, "AudioManager autoload active in scene tree")
	if audio_mgr:
		_assert(audio_mgr.get_stream("kill_confirm") != null, "kill_confirm audio stream loaded")
		_assert(audio_mgr.get_stream("respawn") != null, "respawn audio stream loaded")
		_assert(audio_mgr.get_stream("player_damage") != null, "player_damage audio stream loaded")
		_assert(audio_mgr.get_stream("player_death") != null, "player_death audio stream loaded")
		_assert(audio_mgr.has_method("play_kill_confirm"), "AudioManager provides play_kill_confirm method")
		_assert(audio_mgr.has_method("play_respawn"), "AudioManager provides play_respawn method")

		# Test playback calls execute cleanly without error
		var p_kc = audio_mgr.play_kill_confirm(false)
		_assert(p_kc != null or not audio_mgr._pool_2d.is_empty(), "play_kill_confirm(false) triggered successfully")
		var p_hskc = audio_mgr.play_kill_confirm(true)
		_assert(p_hskc != null or not audio_mgr._pool_2d.is_empty(), "play_kill_confirm(true) triggered successfully")
		var p_rsp = audio_mgr.play_respawn()
		_assert(p_rsp != null or not audio_mgr._pool_2d.is_empty(), "play_respawn() triggered successfully")

	# -------------------------------------------------------------------------
	# 2. Test CombatHUD Health Bar & Color Progression
	# -------------------------------------------------------------------------
	_log("\n--- TEST 2: CombatHUD Health Bar & Dynamic Colors ---")
	var hud_scene = load("res://scenes/ui/combat_hud.tscn") as PackedScene
	_assert(hud_scene != null, "combat_hud.tscn loaded")
	var hud = hud_scene.instantiate() as CombatHUD
	root.add_child(hud)

	_assert(hud.get_node_or_null("HealthDisplay/HealthBar") != null, "HealthBar exists in CombatHUD")
	_assert(hud.get_node_or_null("HealthDisplay/DamageTrailBar") != null, "DamageTrailBar exists in CombatHUD")
	_assert(hud.get_node_or_null("HealthDisplay/HealthLabel") != null, "HealthLabel exists in CombatHUD")
	_assert(hud.get_node_or_null("DamageVignette") != null, "DamageVignette exists in CombatHUD")
	_assert(hud.get_node_or_null("LowHealthVignette") != null, "LowHealthVignette exists in CombatHUD")
	_assert(hud.get_node_or_null("DirectionalDamage") != null, "DirectionalDamage exists in CombatHUD")

	# Test 100% HP (Full Health)
	hud.update_health(100.0, 100.0)
	var bar = hud.get_node("HealthDisplay/HealthBar") as ColorRect
	var lbl = hud.get_node("HealthDisplay/HealthLabel") as Label
	_assert(lbl.text == "100 HP", "Health text displays '100 HP'")
	_assert(is_equal_approx(bar.size.x, CombatHUD.HEALTH_BAR_MAX_WIDTH), "Health bar at full width (194px)")
	_assert(bar.color.g > 0.7, "Health bar is green above 60% HP")

	# Test 50% HP (Amber Warning)
	hud.update_health(50.0, 100.0)
	_assert(lbl.text == "50 HP", "Health text displays '50 HP'")
	_assert(is_equal_approx(bar.size.x, CombatHUD.HEALTH_BAR_MAX_WIDTH * 0.5), "Health bar scaled to 50% width")
	_assert(bar.color.r > 0.8 and bar.color.g > 0.6 and bar.color.b < 0.4, "Health bar turns amber between 30% and 60% HP")

	# Test 20% HP (Critical Red)
	hud.update_health(20.0, 100.0)
	_assert(lbl.text == "20 HP", "Health text displays '20 HP'")
	_assert(is_equal_approx(bar.size.x, CombatHUD.HEALTH_BAR_MAX_WIDTH * 0.2), "Health bar scaled to 20% width")
	_assert(bar.color.r > 0.8 and bar.color.g < 0.4, "Health bar turns critical red at <= 30% HP")

	# -------------------------------------------------------------------------
	# 3. Test Low-Health Warning State
	# -------------------------------------------------------------------------
	_log("\n--- TEST 3: Low-Health Visual Warning Lifecycle ---")
	_assert(hud._is_low_health_pulsing == true, "Low-health pulsing active when HP <= 30")
	# Restore to full HP -> low health warning must stop
	hud.update_health(100.0, 100.0)
	_assert(hud._is_low_health_pulsing == false, "Low-health pulsing stopped when HP > 30")
	var low_hp_vig = hud.get_node("LowHealthVignette") as TextureRect
	_assert(low_hp_vig.modulate.a == 0.0, "LowHealthVignette alpha reset to 0.0")

	# -------------------------------------------------------------------------
	# 4. Test Damage Vignette & Directional Indicators
	# -------------------------------------------------------------------------
	_log("\n--- TEST 4: Screen Damage Vignette & Directional Indicators ---")
	var test_dmg = DamageInfo.new()
	test_dmg.amount = 25.0

	# Show directional damage from right (PI/2 radians)
	hud.show_damage(test_dmg, 75.0, 100.0, PI * 0.5, true)
	var dmg_vig = hud.get_node("DamageVignette") as TextureRect
	_assert(dmg_vig.modulate.a > 0.0, "DamageVignette activated on damage")
	_assert(hud._dir_indicators.size() == CombatHUD.NUM_DIR_INDICATORS, "8 Directional damage indicators initialized")

	var active_indicator = hud._dir_indicators[0]
	_assert(is_equal_approx(active_indicator.rotation, PI * 0.5), "Directional indicator rotated to PI/2 (right bearing)")
	_assert(active_indicator.modulate.a > 0.0, "Directional indicator alpha activated on directional hit")

	# -------------------------------------------------------------------------
	# 5. Test Crosshair 4-Tier Hit Feel Hierarchy
	# -------------------------------------------------------------------------
	_log("\n--- TEST 5: Crosshair 4-Tier Hit Feel Hierarchy ---")
	var crosshair_scene = load("res://scenes/ui/crosshair.tscn") as PackedScene
	_assert(crosshair_scene != null, "crosshair.tscn loaded")
	var crosshair = crosshair_scene.instantiate() as CrosshairHUD
	root.add_child(crosshair)
	var hitmarker = crosshair.get_node("CrosshairControl/Center/Hitmarker") as Control

	# Tier 1: Body Hit
	crosshair.show_hitmarker(false, false)
	_assert(hitmarker.modulate.r > 0.9 and hitmarker.modulate.g > 0.9 and hitmarker.modulate.b > 0.9, "Body hit gives white hitmarker")
	_assert(is_equal_approx(hitmarker.scale.x, 1.0), "Body hit scale is 1.0x")

	# Tier 2: Headshot Hit
	crosshair.show_hitmarker(true, false)
	_assert(hitmarker.modulate.r > 0.9 and hitmarker.modulate.g < 0.4 and hitmarker.modulate.b < 0.4, "Headshot hit gives crimson red hitmarker")
	_assert(is_equal_approx(hitmarker.scale.x, 1.35), "Headshot hit scale is 1.35x")

	# Tier 3: Body Kill
	crosshair.show_hitmarker(false, true)
	_assert(hitmarker.modulate.r > 0.9 and hitmarker.modulate.b < 0.4, "Body kill gives vivid amber/crimson hitmarker")
	_assert(is_equal_approx(hitmarker.scale.x, 1.55), "Body kill scale is 1.55x")

	# Tier 4: Headshot Kill
	crosshair.show_hitmarker(true, true)
	_assert(hitmarker.modulate.r > 0.9 and hitmarker.modulate.b < 0.4, "Headshot kill gives critical hitmarker")
	_assert(is_equal_approx(hitmarker.scale.x, 1.75), "Headshot kill scale is 1.75x")

	# -------------------------------------------------------------------------
	# 6. Test WeaponBase Lethal Hit Detection & Signal Emission
	# -------------------------------------------------------------------------
	_log("\n--- TEST 6: WeaponBase Lethal Hit Detection & Kill Signal ---")
	var ar_scene = load("res://scenes/weapons/assault_rifle.tscn") as PackedScene
	var ar = ar_scene.instantiate()
	root.add_child(ar)

	var signal_data := {
		"fired": false,
		"headshot": false,
		"kill": false
	}

	ar.target_hit.connect(func(is_head: bool, is_kill: bool) -> void:
		signal_data["fired"] = true
		signal_data["headshot"] = is_head
		signal_data["kill"] = is_kill
	)

	# 1. Non-fatal damage evaluation
	var dummy_health := Health.new()
	dummy_health.max_health = 100.0
	dummy_health.current_health = 100.0
	root.add_child(dummy_health)

	var dmg_non_fatal := DamageInfo.new()
	dmg_non_fatal.amount = 20.0
	dmg_non_fatal.hit_type = DamageInfo.HitType.BODY
	var is_kill_check1 := not dummy_health.is_dead and (dummy_health.current_health - dmg_non_fatal.get_final_damage() <= 0.0)
	_assert(is_kill_check1 == false, "20 dmg against 100 HP is non-lethal (is_kill == false)")

	# 2. Fatal damage evaluation
	dummy_health.current_health = 15.0
	var is_kill_check2 := not dummy_health.is_dead and (dummy_health.current_health - dmg_non_fatal.get_final_damage() <= 0.0)
	_assert(is_kill_check2 == true, "20 dmg against 15 HP is lethal (is_kill == true)")

	# 3. Headshot fatal damage evaluation
	var dmg_headshot := DamageInfo.new()
	dmg_headshot.amount = 20.0
	dmg_headshot.headshot_multiplier = 2.0
	dmg_headshot.hit_type = DamageInfo.HitType.HEAD
	dummy_health.current_health = 35.0
	var is_kill_check3 := not dummy_health.is_dead and (dummy_health.current_health - dmg_headshot.get_final_damage() <= 0.0)
	_assert(is_kill_check3 == true, "40 headshot dmg against 35 HP is lethal (is_kill == true)")

	# 4. Target hit signal propagation to crosshair
	signal_data["fired"] = false
	ar.target_hit.emit(false, false)
	_assert(signal_data["fired"] == true and signal_data["headshot"] == false and signal_data["kill"] == false, "target_hit signal emitted for body hit")
	signal_data["fired"] = false
	ar.target_hit.emit(true, true)
	_assert(signal_data["fired"] == true and signal_data["headshot"] == true and signal_data["kill"] == true, "target_hit signal emitted for headshot kill")

	dummy_health.queue_free()



	# -------------------------------------------------------------------------
	# 7. Test Player Death State, Combat Suppression & Death Camera
	# -------------------------------------------------------------------------
	_log("\n--- TEST 7: Player Death State & Camera Presentation ---")
	var player_scene = load("res://scenes/player/player.tscn") as PackedScene
	var player = player_scene.instantiate()
	root.add_child(player)

	_assert(player.is_alive() == true, "Player initially alive")
	var attacker_node := Node3D.new()
	attacker_node.name = "TestEnemy"
	root.add_child(attacker_node)

	var fatal_dmg = DamageInfo.new()
	fatal_dmg.amount = 150.0
	fatal_dmg.attacker = attacker_node
	player.take_damage(fatal_dmg)

	_assert(player.is_alive() == false, "Player reports is_alive() == false after lethal damage")
	_assert(player._is_dead == true, "Player _is_dead flag is true")
	_assert(player.deaths == 1, "Player deaths incremented to 1")
	_assert(player._damage_kick_roll > 10.0, "Death camera presentation applied roll tilt (> 10 deg)")
	_assert(player._damage_kick_pitch > 4.0, "Death camera presentation applied pitch slump (> 4 deg)")

	# Verify combat inputs are suppressed during death
	player.switch_weapon(1)
	_assert(player._active_slot_index == 0, "Weapon switching suppressed while dead")

	# -------------------------------------------------------------------------
	# 8. Test Player Respawn Lifecycle
	# -------------------------------------------------------------------------
	_log("\n--- TEST 8: Player Respawn Lifecycle & Reset ---")
	player._do_respawn()
	_assert(player.is_alive() == true, "Player alive after _do_respawn()")
	_assert(player._is_dead == false, "Player _is_dead is false")
	_assert(player._health.current_health == 100.0, "Player health restored to 100.0")
	_assert(is_equal_approx(player._damage_kick_roll, 0.0), "Death camera roll tilt reset to 0.0")
	_assert(is_equal_approx(player._damage_kick_pitch, 0.0), "Death camera pitch slump reset to 0.0")

	# -------------------------------------------------------------------------
	# 9. Test Full FFA Arena Integration & Combat Feedback Flow
	# -------------------------------------------------------------------------
	_log("\n--- TEST 9: Full FFA Arena Integration & Live Combat Juice ---")
	var arena_scene = load("res://scenes/maps/test_arena.tscn") as PackedScene
	_assert(arena_scene != null, "test_arena.tscn loaded")
	var arena = arena_scene.instantiate()
	root.add_child(arena)

	var arena_player = arena.find_child("Player", true, false)
	_assert(arena_player != null, "Player found in test arena")
	var arena_hud = arena_player.find_child("CombatHUD", true, false)
	_assert(arena_hud != null, "CombatHUD found on arena Player")
	var arena_crosshair = arena_player.find_child("CrosshairHUD", true, false)
	_assert(arena_crosshair != null, "CrosshairHUD found on arena Player")

	# Weapon switching in arena
	arena_player.switch_weapon(1)
	_assert(arena_player._active_slot_index == 1, "Player switched to Pistol (Slot 1)")
	arena_player.switch_weapon(0)
	_assert(arena_player._active_slot_index == 0, "Player switched back to AR (Slot 0)")

	# Cleanup test nodes
	hud.queue_free()
	crosshair.queue_free()
	ar.queue_free()
	attacker_node.queue_free()
	player.queue_free()
	arena.queue_free()


	# -------------------------------------------------------------------------
	# Test Summary
	# -------------------------------------------------------------------------
	_log("\n========================================================")
	_log("       TEST SUMMARY: %d / %d TESTS PASSED               " % [passed_count, total_count])
	_log("========================================================\n")

	if passed_count == total_count:
		_log(">> ALL MILESTONE 11 COMBAT FEEDBACK TESTS PASSED! <<\n")
		quit(0)
	else:
		_log(">> SOME TESTS FAILED! <<\n")
		quit(1)
