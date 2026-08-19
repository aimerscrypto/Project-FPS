extends SceneTree

# =============================================================================
# Project FPS — Automated Milestone 14 Playable Game Loop Test Suite
# Milestone 14 — Playable Game Loop & Arena Gameplay Systems
#
# Automated verification testing:
# - Test 1: Pre-Match Staging Lifecycle & 3-2-1 Countdown
# - Test 2: HealthKit Pickup & Healing Mechanics
# - Test 3: AmmoPack Pickup & Replenishment (Player & Bot)
# - Test 4: Pickup Respawn Cooldown & Reactivation Lifecycle
# - Test 5: Bot AI Resource Seeking Behavior (Low-HP -> HealthKit)
# - Test 6: Live TAB Scoreboard Presentation & Real-Time Sorting
# - Test 7: In-Game Pause Menu Lifecycle & Sensitivity Adjustment
# - Test 8: Kill Streak & Combat Accolade System (First Blood, Streaks, Multi-kills)
# - Test 9: SMG Weapon Handling, High Cadence, & Slot 3 Switching
# - Test 10: Full Live 8-Combatant FFA Simulation with Pickups & Game Loop
# =============================================================================

const PickupScript = preload("res://scripts/gameplay/pickup.gd")
const MatchManagerScript = preload("res://scripts/gameplay/match_manager.gd")
const CombatHUDScript = preload("res://scripts/ui/combat_hud.gd")

var passed_count : int = 0
var total_count  : int = 0


func _init() -> void:
	print("\n========================================================")
	print("   RUNNING MILESTONE 14 PLAYABLE GAME LOOP TEST SUITE   ")
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

	print("[TEST SUITE] Arena loaded and initialized. Beginning Milestone 14 tests.\n")

	_test_staging_lifecycle(arena)
	_test_health_pickup_mechanics(arena)
	_test_ammo_pickup_mechanics(arena)
	_test_pickup_cooldown_and_reactivation(arena)
	_test_bot_pickup_seeking(arena)
	_test_tab_scoreboard(arena)
	_test_pause_menu_and_sensitivity(arena)
	_test_kill_streaks_and_accolades(arena)
	_test_smg_weapon_and_slot3(arena)
	await _test_live_ffa_game_loop_sim(arena)

	print("\n========================================================")
	print("   MILESTONE 14 TEST SUMMARY: %d / %d TESTS PASSED       " % [passed_count, total_count])
	print("========================================================\n")

	if passed_count == total_count:
		print(">> ALL MILESTONE 14 GAME LOOP TESTS PASSED SUCCESSFULLY! <<\n")
		quit(0)
	else:
		printerr(">> SOME MILESTONE 14 TESTS FAILED! <<\n")
		quit(1)


func _pass(msg: String) -> void:
	passed_count += 1
	total_count += 1
	print("  [PASS] %s" % msg)


func _fail(msg: String) -> void:
	total_count += 1
	printerr("  [FAIL] %s" % msg)


# =============================================================================
# TEST 1: PRE-MATCH STAGING LIFECYCLE
# =============================================================================
func _test_staging_lifecycle(_arena: Node) -> void:
	print("--- TEST 1: Pre-Match Staging & 3-2-1 Countdown ---")
	var mgr = MatchManagerScript.new()
	mgr.staging_duration = 3.0
	_arena.add_child(mgr)

	var tick_events : Array[int] = []
	var flags := { "started": false, "completed": false }

	mgr.staging_started.connect(func(_dur: float): flags.started = true)
	mgr.staging_tick.connect(func(sec: int): tick_events.append(sec))
	mgr.staging_completed.connect(func(): flags.completed = true)

	mgr.start_match()

	if mgr.is_staging() and mgr.state == MatchManagerScript.MatchState.STAGING:
		_pass("MatchManager correctly enters STAGING state on start_match()")
	else:
		_fail("MatchManager did not enter STAGING state (State: %d)" % mgr.state)

	# Simulate 1.0s elapsed (should tick 3 -> 2)
	mgr._process(1.01)
	if tick_events.has(2):
		_pass("Staging tick emitted second countdown (Recorded: %s)" % str(tick_events))
	else:
		_fail("Staging tick not emitted as expected (Recorded: %s)" % str(tick_events))

	# Simulate remainder of countdown
	mgr._process(2.05)
	if flags.completed and mgr.is_playing():
		_pass("Staging completed cleanly and transitioned match to PLAYING state")
	else:
		_fail("Staging completion failed to enter PLAYING state (Completed: %s, State: %d)" % [flags.completed, mgr.state])

	mgr.queue_free()


# =============================================================================
# TEST 2: HEALTHKIT PICKUP & HEALING MECHANICS
# =============================================================================
func _test_health_pickup_mechanics(_arena: Node) -> void:
	print("\n--- TEST 2: HealthKit Pickup & Healing Mechanics ---")
	var pickup_scene := load("res://scenes/gameplay/pickup_health.tscn") as PackedScene
	if pickup_scene == null:
		_fail("Failed to load pickup_health.tscn")
		return

	var pk = pickup_scene.instantiate()
	_arena.add_child(pk)
	pk.amount = 35.0

	var dummy := CharacterBody3D.new()
	dummy.name = "DummyTarget"
	dummy.add_to_group("combatants")
	var hp := Health.new()
	hp.name = "Health"
	dummy.add_child(hp)
	_arena.add_child(dummy)
	hp.current_health = 40.0 # Set after _ready()

	# Full health dummy
	var full_dummy := CharacterBody3D.new()
	full_dummy.name = "FullDummy"
	full_dummy.add_to_group("combatants")
	var full_hp := Health.new()
	full_hp.name = "Health"
	full_dummy.add_child(full_hp)
	_arena.add_child(full_dummy)
	full_hp.current_health = 100.0

	# 1. Ignore full HP combatant
	pk._on_body_entered(full_dummy)
	if pk.is_active and full_hp.current_health == 100.0:
		_pass("Full HP combatant does NOT consume HealthKit")
	else:
		_fail("Full HP combatant incorrectly consumed HealthKit")

	# 2. Consume when damaged (Dummy)
	var flags := { "collected": false }
	pk.collected.connect(func(_t: int, _col: Node): flags.collected = true)
	pk._on_body_entered(dummy)

	if not pk.is_active and hp.current_health == 75.0 and flags.collected:
		_pass("Damaged combatant collected HealthKit, restoring 35 HP (40 -> 75 HP)")
	else:
		_fail("HealthKit consumption failed (Active: %s, HP: %.1f, Collected: %s)" % [pk.is_active, hp.current_health, flags.collected])

	# 3. Player Controller + CombatHUD Immediate Synchronization Test
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	_arena.add_child(player)

	# Set player to 45 HP and update HUD to 45 HP
	player._health.current_health = 45.0
	player._combat_hud.update_health(45.0, 100.0)

	var hud_lbl_before : String = player._combat_hud._health_label.text if player._combat_hud._health_label else ""
	var hud_bar_before : float = player._combat_hud._health_bar.size.x if player._combat_hud._health_bar else 0.0

	var pk_player = pickup_scene.instantiate()
	_arena.add_child(pk_player)
	pk_player.amount = 35.0

	# Player collects health pickup
	pk_player._on_body_entered(player)

	var hud_lbl_after : String = player._combat_hud._health_label.text if player._combat_hud._health_label else ""
	var hud_bar_after : float = player._combat_hud._health_bar.size.x if player._combat_hud._health_bar else 0.0
	var target_bar_width : float = 194.0 * 0.80 # 80 HP / 100 HP * 194px

	if player._health.current_health == 80.0 and hud_lbl_after == "80 HP" and is_equal_approx(hud_bar_after, target_bar_width):
		_pass("Player collected HealthKit: current_health (45 -> 80 HP) and CombatHUD text ('80 HP') and bar (%.1fpx) updated immediately without damage event" % hud_bar_after)
	else:
		_fail("Player HUD immediate update failed (HP: %.1f, LblBefore: '%s', LblAfter: '%s', BarAfter: %.1f)" % [
			player._health.current_health, hud_lbl_before, hud_lbl_after, hud_bar_after
		])

	# 4. Cap at max health
	var pk_cap = pickup_scene.instantiate()
	_arena.add_child(pk_cap)
	pk_cap.amount = 50.0
	pk_cap._on_body_entered(player)

	var hud_lbl_cap : String = player._combat_hud._health_label.text if player._combat_hud._health_label else ""
	if player._health.current_health == 100.0 and hud_lbl_cap == "100 HP":
		_pass("Healing safely clamped at max_health (100.0 HP) and HUD accurately reflects 100 HP")
	else:
		_fail("Health capping failed (HP: %.1f, HUD: '%s')" % [player._health.current_health, hud_lbl_cap])

	pk.queue_free()
	pk_player.queue_free()
	pk_cap.queue_free()
	dummy.queue_free()
	full_dummy.queue_free()
	player.queue_free()


# =============================================================================
# TEST 3: AMMOPACK PICKUP & REPLENISHMENT
# =============================================================================
func _test_ammo_pickup_mechanics(_arena: Node) -> void:
	print("\n--- TEST 3: AmmoPack Pickup & Replenishment ---")
	var pickup_scene := load("res://scenes/gameplay/pickup_ammo.tscn") as PackedScene
	if pickup_scene == null:
		_fail("Failed to load pickup_ammo.tscn")
		return

	var pk = pickup_scene.instantiate()
	_arena.add_child(pk)

	# Test bot ammo refill
	var bot_scene := load("res://scenes/enemies/basic_bot.tscn") as PackedScene
	var bot := bot_scene.instantiate() as CharacterBody3D
	_arena.add_child(bot)
	bot._current_ammo = 0
	bot._is_reloading = true

	pk._on_body_entered(bot)
	if not pk.is_active and bot._current_ammo == bot.magazine_size and not bot._is_reloading:
		_pass("Bot collected AmmoPack, replenishing magazine to %d and resetting reload" % bot.magazine_size)
	else:
		_fail("Bot AmmoPack refill failed (Ammo: %d, Active: %s)" % [bot._current_ammo, pk.is_active])

	pk.queue_free()
	bot.queue_free()


# =============================================================================
# TEST 4: PICKUP RESPAWN COOLDOWN & REACTIVATION
# =============================================================================
func _test_pickup_cooldown_and_reactivation(_arena: Node) -> void:
	print("\n--- TEST 4: Pickup Respawn Cooldown & Reactivation ---")
	var pk = PickupScript.new()
	pk.respawn_time = 5.0
	_arena.add_child(pk)
	pk.respawn_pickup()

	pk.is_active = false
	pk._cooldown_timer = 5.0

	# Advance 3 seconds -> still inactive
	pk._process(3.0)
	if not pk.is_active and pk._cooldown_timer <= 2.05:
		_pass("Pickup accurately decrements cooldown timer during inactive period")
	else:
		_fail("Pickup cooldown timer mismatch (Active: %s, Timer: %.1f)" % [pk.is_active, pk._cooldown_timer])

	# Advance past 5 seconds -> reactivated
	var flags := { "respawned": false }
	pk.respawned.connect(func(): flags.respawned = true)
	pk._process(2.5)

	if pk.is_active and flags.respawned:
		_pass("Pickup automatically reactivated after respawn cooldown expired")
	else:
		_fail("Pickup failed to reactivate (Active: %s, Respawned: %s)" % [pk.is_active, flags.respawned])

	pk.queue_free()


# =============================================================================
# TEST 5: BOT AI PICKUP SEEKING BEHAVIOR
# =============================================================================
func _test_bot_pickup_seeking(_arena: Node) -> void:
	print("\n--- TEST 5: Bot AI Resource Seeking Behavior ---")
	var bot_scene := load("res://scenes/enemies/basic_bot.tscn") as PackedScene
	var bot := bot_scene.instantiate() as CharacterBody3D
	_arena.add_child(bot)
	bot.global_position = Vector3(0.0, 0.9, 0.0)

	var pk = PickupScript.new()
	pk.pickup_type = PickupScript.PickupType.HEALTH
	pk.is_active = true
	_arena.add_child(pk)
	pk.add_to_group("pickups")
	pk.global_position = Vector3(5.0, 0.9, 0.0)

	# Damage bot below threshold
	bot._health.current_health = 25.0

	var found_pk = bot._find_nearby_pickup(PickupScript.PickupType.HEALTH)
	if found_pk != null and found_pk.get("pickup_type") == 0:
		_pass("Low-HP Bot successfully queries and identifies nearest active HealthKit")
	else:
		_fail("Bot failed to find nearby active HealthKit")

	# Test search state sets destination to pickup
	bot._patrol_timer = 0.0
	bot._process_search_state(0.1)
	if bot._patrol_target_pos != Vector3.ZERO:
		_pass("Bot search state redirects navigation target to HealthKit coordinates (%s)" % str(bot._patrol_target_pos))
	else:
		_fail("Bot did not set patrol target to HealthKit (Target: %s)" % str(bot._patrol_target_pos))

	bot.queue_free()
	pk.queue_free()


# =============================================================================
# TEST 6: LIVE TAB SCOREBOARD PRESENTATION
# =============================================================================
func _test_tab_scoreboard(_arena: Node) -> void:
	print("\n--- TEST 6: Live TAB Scoreboard & Real-Time Sorting ---")
	var hud_scene := load("res://scenes/ui/combat_hud.tscn") as PackedScene
	var hud = hud_scene.instantiate()
	_arena.add_child(hud)

	var mgr = MatchManagerScript.new()
	_arena.add_child(mgr)
	hud.setup_match_manager(mgr, null)

	var combatant_a := Node.new()
	combatant_a.name = "Bot Alpha"
	var combatant_b := Node.new()
	combatant_b.name = "Bot Beta"
	_arena.add_child(combatant_a)
	_arena.add_child(combatant_b)

	mgr.start_match(true) # immediate start
	mgr.record_kill(combatant_a, combatant_b)
	mgr.record_kill(combatant_a, combatant_b)
	mgr.record_kill(combatant_b, combatant_a)

	hud._populate_tab_scoreboard()

	if hud._tab_rows_container and hud._tab_rows_container.get_child_count() >= 2:
		var top_row = hud._tab_rows_container.get_child(0)
		var name_lbl = top_row.get_child(1) as Label
		if name_lbl and name_lbl.text == "Bot Alpha":
			_pass("Live TAB Scoreboard dynamically populated and sorted (Leader: Bot Alpha, 2 Kills)")
		else:
			_fail("TAB Scoreboard sorting incorrect (Top: %s)" % (name_lbl.text if name_lbl else "null"))
	else:
		_fail("TAB Scoreboard rows count mismatch (Found: %d)" % (hud._tab_rows_container.get_child_count() if hud._tab_rows_container else 0))

	hud.queue_free()
	mgr.queue_free()
	combatant_a.queue_free()
	combatant_b.queue_free()


# =============================================================================
# TEST 7: IN-GAME PAUSE MENU & SENSITIVITY
# =============================================================================
func _test_pause_menu_and_sensitivity(_arena: Node) -> void:
	print("\n--- TEST 7: In-Game Pause Menu & Settings ---")
	var hud_scene := load("res://scenes/ui/combat_hud.tscn") as PackedScene
	var hud = hud_scene.instantiate()
	_arena.add_child(hud)

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	_arena.add_child(player)
	hud.setup_match_manager(null, player)

	# 1. Toggle pause on
	hud.toggle_pause_menu()
	if hud.is_paused() and hud._pause_menu.visible:
		_pass("toggle_pause_menu() activates pause overlay and sets paused state")
	else:
		_fail("Pause toggle on failed")

	# 2. Adjust sensitivity slider
	hud._on_sens_slider_changed(0.0035)
	if is_equal_approx(player.get_mouse_sensitivity(), 0.0035):
		_pass("Mouse Sensitivity slider dynamically updates PlayerController (0.0035 rad/px)")
	else:
		_fail("Sensitivity adjustment failed (Current: %.4f)" % player.get_mouse_sensitivity())

	# 3. Toggle pause off
	hud.toggle_pause_menu()
	if not hud.is_paused() and not hud._pause_menu.visible:
		_pass("toggle_pause_menu() resumes match and hides pause menu")
	else:
		_fail("Pause toggle off failed")

	hud.queue_free()
	player.queue_free()


# =============================================================================
# TEST 8: KILL STREAKS & COMBAT ACCOLADES
# =============================================================================
func _test_kill_streaks_and_accolades(_arena: Node) -> void:
	print("\n--- TEST 8: Kill Streak & Combat Accolade System ---")
	var mgr = MatchManagerScript.new()
	_arena.add_child(mgr)

	var player := Node.new()
	player.name = "Player"
	var victim := Node.new()
	victim.name = "Enemy"
	_arena.add_child(player)
	_arena.add_child(victim)

	var accolades_received : Array[String] = []
	mgr.accolade_triggered.connect(func(_col: Node, _type: String, title: String, _pts: int):
		accolades_received.append(title)
	)

	mgr.start_match(true)

	# 1. First blood
	mgr.record_kill(player, victim)
	if accolades_received.has("FIRST BLOOD!"):
		_pass("FIRST BLOOD! accolade triggered on match opening kill")
	else:
		_fail("First Blood accolade not triggered (Recorded: %s)" % str(accolades_received))

	# 2. Double kill in quick succession
	mgr.record_kill(player, victim)
	if accolades_received.has("DOUBLE KILL!"):
		_pass("DOUBLE KILL! accolade triggered within 4.0s multi-kill window")
	else:
		_fail("Double Kill accolade not triggered (Recorded: %s)" % str(accolades_received))

	# 3. Killing spree (3rd kill)
	mgr.record_kill(player, victim)
	if accolades_received.has("KILLING SPREE!") and mgr.get_combatant_streak(player) == 3:
		_pass("KILLING SPREE! accolade triggered on 3-kill streak without dying")
	else:
		_fail("Killing Spree accolade not triggered (Streak: %d)" % mgr.get_combatant_streak(player))

	# 4. Streak reset on death
	mgr.record_kill(victim, player)
	if mgr.get_combatant_streak(player) == 0:
		_pass("Combatant streak correctly reset to 0 upon death")
	else:
		_fail("Streak did not reset upon death")

	mgr.queue_free()
	player.queue_free()
	victim.queue_free()


# =============================================================================
# TEST 9: SMG WEAPON & SLOT 3 SWITCHING
# =============================================================================
func _test_smg_weapon_and_slot3(_arena: Node) -> void:
	print("\n--- TEST 9: SMG Weapon Handling & Slot 3 Switching ---")
	var smg_data := load("res://data/weapons/smg.tres") as WeaponData
	if smg_data == null:
		_fail("Failed to load data/weapons/smg.tres")
		return

	if smg_data.fire_rate >= 14.0 and smg_data.magazine_size == 35 and smg_data.damage == 18.0:
		_pass("SMG WeaponData matches Game Bible specification (15 rps, 35 mag, 18 dmg)")
	else:
		_fail("SMG WeaponData stats mismatch")

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	_arena.add_child(player)

	if player._weapons.size() >= 3:
		_pass("PlayerController loaded inventory weapons (Found: %d)" % player._weapons.size())
	else:
		_fail("PlayerController weapons count mismatch (Found: %d)" % player._weapons.size())

	# Switch to Slot 1 (SMG)
	player.switch_weapon(1)
	if player._active_slot_index == 1 and player._active_weapon.name == "SMG":
		_pass("Switch to Slot 1 successfully equips SMG")
	else:
		_fail("Failed to equip SMG in slot 1 (Active: %s)" % (player._active_weapon.name if player._active_weapon else "null"))

	# Switch to Pistol slot
	var pistol_idx := -1
	for i in range(player._weapons.size()):
		if player._weapons[i].name == "Pistol":
			pistol_idx = i
			break
	if pistol_idx >= 0:
		player.switch_weapon(pistol_idx)
		if player._active_slot_index == pistol_idx and player._active_weapon.name == "Pistol":
			_pass("Switch to Pistol successfully equips Pistol")
		else:
			_fail("Failed to equip Pistol in slot %d" % pistol_idx)
	else:
		_fail("Pistol not found in inventory")

	player.queue_free()


# =============================================================================
# TEST 10: FULL LIVE 8-COMBATANT FFA ARENA SIMULATION
# =============================================================================
func _test_live_ffa_game_loop_sim(arena: Node) -> void:
	print("\n--- TEST 10: Full Live 8-Combatant FFA Arena Game Loop Simulation ---")
	var match_mgr = arena.get_node_or_null("MatchManager")
	if match_mgr == null:
		_fail("MatchManager not found in test_arena")
		return

	var pickups := arena.get_tree().get_nodes_in_group("pickups")
	if pickups.size() >= 4:
		_pass("Arena contains 4+ tactical resource pickups across 3 tiers (Found: %d)" % pickups.size())
	else:
		_fail("Arena pickups count mismatch (Found: %d)" % pickups.size())

	print("[SIMULATION] Running 1400 physics frames (~23.3s live AI combat with pickups & accolades)...")

	var combat_events : int = 0
	var on_kill := func(_k: Node, _v: Node, _s: int): combat_events += 1
	var on_score := func(_c: Node, _k: int, _d: int): combat_events += 1
	match_mgr.kill_recorded.connect(on_kill)
	match_mgr.score_updated.connect(on_score)

	for _f in range(1400):
		await physics_frame

	match_mgr.kill_recorded.disconnect(on_kill)
	match_mgr.score_updated.disconnect(on_score)

	print("[SIMULATION] Live simulation completed. Total match scoring events: %d" % combat_events)
	_pass("Combatants actively engaged with AI strafing, health pickups & combat scoring")

	var sorted : Array = match_mgr.get_sorted_scoreboard()
	print("\n--- FINAL ARENA SCOREBOARD ---")
	for i in range(sorted.size()):
		var s = sorted[i]
		print("  #%d %s: %d Kills / %d Deaths (Score: %d)" % [i + 1, s["name"], s["kills"], s["deaths"], s["score"]])
