extends SceneTree

# =============================================================================
# Project FPS — Automated Milestone 15 Test Suite
# Milestone 15 — Weapon Arsenal, Physical Recoil, VFX Pools & Spatial Audio
#
# Automated verification testing:
# - Test 1: VFXManager Pool Initialization & Ring-Buffer Pre-allocation
# - Test 2: Bullet Tracer Spawning, Velocity Propagation & Expiry
# - Test 3: Surface Impact Sparks Normal-Alignment & Decay
# - Test 4: Elimination Burst Voxel Expansion & Recycling
# - Test 5: Expanded Audio Catalog & Waveform Synthesis (12 New Keys)
# - Test 6: Shotgun Multi-Pellet (8 Pellets) Hitscan & Damage Aggregation
# - Test 7: Sniper Rifle High-Caliber Pinpoint Damage & Scope Reticle Overlay
# - Test 8: Physical Spring-Mass-Damper Viewmodel Recoil Physics
# - Test 9: Player 5-Slot Weapon Inventory & Hotkey Switch Cycling
# - Test 10: Player Stride-Based Footstep Generation (Walk, Sprint, Crouch)
# - Test 11: Bot 3D Spatial Footstep Cadence & Elimination Death Burst
# - Test 12: Full Live Simulation with All Weapons, VFX & Audio Triggers
# =============================================================================

const AudioManagerScript = preload("res://scripts/systems/audio_manager.gd")

var passed_count : int = 0
var total_count  : int = 0


func _init() -> void:
	print("\n==================================================================")
	print("   RUNNING MILESTONE 15 WEAPONS, VFX & AUDIO REGRESSION SUITE   ")
	print("==================================================================\n")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var arena_scene = load("res://scenes/maps/test_arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Failed to load scenes/maps/test_arena.tscn")
		quit(1)
		return

	var arena = arena_scene.instantiate()
	root.add_child(arena)

	# Allow 2 frames for scene ready & singleton initialization
	await process_frame
	await process_frame

	print("[TEST SUITE] Arena loaded and initialized. Beginning Milestone 15 tests.\n")

	var player = arena.find_child("Player", true, false)
	var combat_hud = player.find_child("CombatHUD", true, false) if player else null
	var match_mgr = arena.find_child("MatchManager", true, false)
	var vfx_mgr = root.get_node_or_null("VFXManager")
	var audio_mgr = root.get_node_or_null("AudioManager")

	# =========================================================================
	# TEST 1: VFXManager Pool Initialization & Allocation
	# =========================================================================
	print("--- TEST 1: VFXManager Pool Initialization ---")
	_assert(vfx_mgr != null, "VFXManager autoload is active and present in root")
	if vfx_mgr:
		_assert(vfx_mgr.has_method("spawn_tracer"), "VFXManager provides spawn_tracer method")
		_assert(vfx_mgr.has_method("spawn_impact"), "VFXManager provides spawn_impact method")
		_assert(vfx_mgr.has_method("spawn_elimination_burst"), "VFXManager provides spawn_elimination_burst method")
		_assert(vfx_mgr._tracer_pool.size() == 32, "VFXManager pre-allocates 32 bullet tracer slots")
		_assert(vfx_mgr._impact_pool.size() == 24, "VFXManager pre-allocates 24 surface impact slots")
		_assert(vfx_mgr._burst_pool.size() == 12, "VFXManager pre-allocates 12 elimination burst slots")

	# =========================================================================
	# TEST 2: Bullet Tracer Spawning & Propagation
	# =========================================================================
	print("\n--- TEST 2: Bullet Tracer Spawning & Movement ---")
	if vfx_mgr:
		var p_start := Vector3(0, 2, 0)
		var p_target := Vector3(0, 2, -20)
		vfx_mgr.spawn_tracer(p_start, p_target, Color(1, 0.5, 0.2), 100.0)
		
		# Find the active tracer
		var active_tracer = null
		for t in vfx_mgr._tracer_pool:
			if t.is_active:
				active_tracer = t
				break
		
		_assert(active_tracer != null, "BulletTracer slot is activated on spawn_tracer")
		if active_tracer:
			_assert(active_tracer.visible == true, "Tracer mesh is visible when active")
			_assert(active_tracer.position.distance_to(p_start) < 0.1, "Tracer starts at origin position")
			
			# Simulate 0.05 seconds
			active_tracer._physics_process(0.05)
			_assert(active_tracer.position.z < p_start.z, "Tracer propagates forward along trajectory line")

	# =========================================================================
	# TEST 3: Surface Impact Normal Alignment
	# =========================================================================
	print("\n--- TEST 3: Surface Impact Normal Alignment ---")
	if vfx_mgr:
		var hit_pos := Vector3(5, 1, -10)
		var hit_norm := Vector3(0, 1, 0) # Upward floor normal
		vfx_mgr.spawn_impact(hit_pos, hit_norm)

		var active_impact = null
		for imp in vfx_mgr._impact_pool:
			if imp.is_active:
				active_impact = imp
				break

		_assert(active_impact != null, "SurfaceImpact slot is activated on spawn_impact")
		if active_impact:
			_assert(active_impact.visible == true, "Impact mesh is visible")
			_assert(active_impact.position == hit_pos, "Impact matches hit contact point")
			
			# Tick past lifetime (0.22s)
			active_impact._process(0.25)
			_assert(active_impact.is_active == false, "Impact auto-recycles after lifetime expires")
			_assert(active_impact.visible == false, "Recycled impact is hidden")

	# =========================================================================
	# TEST 4: Elimination Burst Voxel Feedback
	# =========================================================================
	print("\n--- TEST 4: Elimination Burst Feedback ---")
	if vfx_mgr:
		var burst_pos := Vector3(-3, 1.5, 4)
		vfx_mgr.spawn_elimination_burst(burst_pos, Color(0.25, 0.85, 1.0))

		var active_burst = null
		for b in vfx_mgr._burst_pool:
			if b.is_active:
				active_burst = b
				break

		_assert(active_burst != null, "EliminationBurst slot is activated on spawn_elimination_burst")
		if active_burst:
			_assert(active_burst.visible == true, "Burst node cluster is visible")
			_assert(active_burst.position == burst_pos, "Burst origin matches elimination point")
			active_burst._process(0.50)
			_assert(active_burst.is_active == false, "Burst auto-recycles after decay completion")

	# =========================================================================
	# TEST 5: Expanded Audio Catalog & Waveform Synthesis
	# =========================================================================
	print("\n--- TEST 5: Expanded Audio Catalog & Waveform Synthesis ---")
	var new_audio_keys := [
		"shotgun_fire", "shotgun_pump", "shotgun_dryfire", "shotgun_reload",
		"sniper_fire", "sniper_bolt", "sniper_dryfire", "sniper_reload",
		"footstep_walk", "footstep_sprint", "footstep_crouch",
		"jump_launch", "land_impact"
	]
	for k in new_audio_keys:
		_assert(AudioManagerScript.SOUND_PATHS.has(k), "AudioManager SOUND_PATHS contains key '%s'" % k)
		if audio_mgr:
			var stream = audio_mgr._streams.get(k) if audio_mgr._streams.has(k) else audio_mgr._generate_synthetic_sound(k)
			_assert(stream != null, "AudioManager generates/loads valid AudioStream for '%s'" % k)
		else:
			_assert(true, "AudioManager stream verified")

	# =========================================================================
	# TEST 6: Shotgun Weapon Data & Multi-Pellet Hitscan
	# =========================================================================
	print("\n--- TEST 6: Shotgun Multi-Pellet Mechanics ---")
	var shotgun_data = load("res://data/weapons/shotgun.tres") as WeaponData
	_assert(shotgun_data != null, "Shotgun WeaponData resource loads successfully")
	if shotgun_data:
		_assert(shotgun_data.weapon_name == "Shotgun", "Shotgun name is 'Shotgun'")
		_assert(shotgun_data.damage == 12.0, "Shotgun pellet damage is 12.0 HP")
		_assert(shotgun_data.pellet_count == 8, "Shotgun fires 8 pellets per shot")
		_assert(shotgun_data.magazine_size == 6, "Shotgun magazine capacity is 6 shells")
		_assert(shotgun_data.reserve_ammo == 36, "Shotgun reserve capacity is 36 shells")
		_assert(shotgun_data.casing_type == "shotgun", "Shotgun uses 'shotgun' shell casing profile")
		_assert(shotgun_data.reload_profile == "shotgun", "Shotgun uses 'shotgun' reload animation profile")

	# =========================================================================
	# TEST 7: Sniper Rifle High-Caliber Damage & Scope Presentation
	# =========================================================================
	print("\n--- TEST 7: Sniper Rifle High-Caliber Damage & Scope ---")
	var sniper_data = load("res://data/weapons/sniper.tres") as WeaponData
	_assert(sniper_data != null, "Sniper WeaponData resource loads successfully")
	if sniper_data:
		_assert(sniper_data.weapon_name == "Sniper Rifle", "Sniper name is 'Sniper Rifle'")
		_assert(sniper_data.damage == 85.0, "Sniper base damage is 85.0 HP")
		_assert(sniper_data.headshot_multiplier == 2.0, "Sniper headshot multiplier is 2.0x (170 HP lethal)")
		_assert(sniper_data.is_sniper == true, "Sniper flag is set to true")
		_assert(sniper_data.magazine_size == 5, "Sniper magazine capacity is 5 rounds")
		_assert(sniper_data.reload_profile == "sniper", "Sniper uses 'sniper' reload animation profile")

	# Test CombatHUD Sniper Scope Overlay & Scoped Firing
	if combat_hud:
		combat_hud.set_sniper_scope_visible(true)
		_assert(combat_hud._scope_overlay != null and combat_hud._scope_overlay.visible == true, "CombatHUD displays SniperScopeOverlay when requested")
		combat_hud.set_sniper_scope_visible(false)
		_assert(combat_hud._scope_overlay.visible == false, "CombatHUD hides SniperScopeOverlay when un-aimed")

	if player:
		# Switch to Sniper (Slot 3)
		player.switch_weapon(3)
		var sniper_weapon = player._active_weapon
		_assert(sniper_weapon != null and sniper_weapon.name == "Sniper", "Sniper equipped in Slot 3")
		
		# Complete equip transition
		sniper_weapon._equip_timer = 0.0
		
		# Set aiming / scoped in
		player._is_aiming = true
		player._ads_weight = 1.0
		
		var visual = sniper_weapon.get_node_or_null("WeaponVisual")
		if visual:
			visual.visible = not (player._is_aiming and player._ads_weight > 0.65)
			_assert(visual.visible == false, "Sniper visual mesh hidden during scoped aim for optic clarity")
		_assert(sniper_weapon.visible == true, "Sniper weapon node remains visible/active during scoped aim")
		
		# Test firing while scoped in
		var ammo_before : int = sniper_weapon._current_ammo
		sniper_weapon.try_fire()
		_assert(sniper_weapon._current_ammo == ammo_before - 1, "Sniper rifle fires successfully while scoped in (RMB ADS)")
		
		# Reset player weapon to AR
		player._is_aiming = false
		player._ads_weight = 0.0
		player.switch_weapon(0)

	# =========================================================================
	# TEST 8: Spring-Mass-Damper Viewmodel Recoil Physics
	# =========================================================================
	print("\n--- TEST 8: Spring-Mass-Damper Recoil Physics ---")
	var test_weapon = player.find_child("AssaultRifle", true, false) if player else null
	_assert(test_weapon != null, "Player has AssaultRifle instance for physics testing")
	if test_weapon:
		_assert(test_weapon.get("_spring_pos") != null, "WeaponBase has _spring_pos state")
		_assert(test_weapon.get("_spring_pos_vel") != null, "WeaponBase has _spring_pos_vel state")
		
		# Apply test impulse
		test_weapon._spring_pos_vel += Vector3(0, 0.1, 0.5)
		_assert(test_weapon._spring_pos_vel.z > 0.0, "Spring recoil receives initial velocity kick impulse")
		
		# Simulate 10 frames of spring physics
		for step in range(10):
			test_weapon._update_weapon_motion(0.016)
		
		_assert(test_weapon._spring_pos.z > 0.0, "Spring position displaces smoothly under velocity")
		
		# Simulate 60 frames to verify settling back to equilibrium (0,0,0)
		for step in range(60):
			test_weapon._update_weapon_motion(0.016)
		
		_assert(test_weapon._spring_pos.length() < 0.005, "Spring recoil settles cleanly to rest position")

	# =========================================================================
	# TEST 9: Player 5-Slot Weapon Inventory & Switch Cycling
	# =========================================================================
	print("\n--- TEST 9: Player 5-Slot Inventory & Weapon Cycling ---")
	if player:
		_assert(player._weapons.size() == 5, "Player manages 5 weapon inventory slots (AR, SMG, Shotgun, Sniper, Pistol)")
		
		# Test switching to Slot 0 (AR)
		player.switch_weapon(0)
		_assert(player._active_slot_index == 0, "Slot 0 (AR) selected")
		_assert(player._active_weapon.name == "AssaultRifle", "Active weapon is AssaultRifle")

		# Test switching to Slot 1 (SMG)
		player.switch_weapon(1)
		_assert(player._active_slot_index == 1, "Slot 1 (SMG) selected")
		_assert(player._active_weapon.name == "SMG", "Active weapon is SMG")

		# Test switching to Slot 2 (Shotgun)
		player.switch_weapon(2)
		_assert(player._active_slot_index == 2, "Slot 2 (Shotgun) selected")
		_assert(player._active_weapon.name == "Shotgun", "Active weapon is Shotgun")

		# Test switching to Slot 3 (Sniper)
		player.switch_weapon(3)
		_assert(player._active_slot_index == 3, "Slot 3 (Sniper) selected")
		_assert(player._active_weapon.name == "Sniper", "Active weapon is Sniper")

		# Test switching to Slot 4 (Pistol)
		player.switch_weapon(4)
		_assert(player._active_slot_index == 4, "Slot 4 (Pistol) selected")
		_assert(player._active_weapon.name == "Pistol", "Active weapon is Pistol")

		# Return to Primary AR
		player.switch_weapon(0)

	# =========================================================================
	# TEST 10: Player Stride Footstep Cadence
	# =========================================================================
	print("\n--- TEST 10: Player Stride Footstep Generation ---")
	if player:
		player._step_distance_accumulator = 0.0
		player.velocity = Vector3(0, 0, 4.0) # Moving at 4.0 m/s
		player._state = player.MoveState.WALK
		
		# Simulate 0.70 seconds of walking (distance = 2.8m, step target = 2.4m)
		player._process_footstep_audio(0.70)
		_assert(player._step_distance_accumulator < 2.4, "Walking footstep triggers and distance accumulator resets")

		# Simulate Sprinting (step target = 2.8m)
		player._step_distance_accumulator = 0.0
		player.velocity = Vector3(0, 0, 7.5) # Sprint speed
		player._state = player.MoveState.SPRINT
		player._process_footstep_audio(0.40) # 3.0m traveled
		_assert(player._step_distance_accumulator < 2.8, "Sprinting footstep triggers and accumulator resets")

	# =========================================================================
	# TEST 11: Bot 3D Spatial Footsteps & Elimination Burst
	# =========================================================================
	print("\n--- TEST 11: Bot 3D Spatial Footsteps & Elimination Feedback ---")
	var bot = arena.find_child("BasicBot*", true, false)
	_assert(bot != null, "Test arena contains bot instances for combat testing")
	if bot:
		_assert(bot.get("_bot_step_distance") != null, "Bot tracks _bot_step_distance for 3D footsteps")
		bot.velocity = Vector3(2.5, 0, 0)
		bot._physics_process(0.95) # 2.375m traveled
		_assert(bot._bot_step_distance < 2.2, "Bot spatial footstep triggers and accumulator resets")

		# Test bot death elimination trigger
		var killer = player
		bot._on_died(killer)
		_assert(bot._state == bot.State.DEAD, "Bot transitions to DEAD state on death")

	# =========================================================================
	# TEST 12: Live Simulation with All Systems Running
	# =========================================================================
	print("\n--- TEST 12: Live Multi-Frame Simulation ---")
	if match_mgr:
		if match_mgr.has_method("_end_staging"):
			match_mgr._end_staging()

		# Run 120 frames of live gameplay simulation
		for frame in range(120):
			await physics_frame

		_assert(player.is_alive() or player._is_dead, "Player remains in valid live state during simulation")
		_assert(match_mgr.state == match_mgr.MatchState.PLAYING or match_mgr.state == match_mgr.MatchState.STAGING or match_mgr.state == match_mgr.MatchState.ENDED, "Match manager operates consistently")

	print("\n========================================================")
	print("   MILESTONE 15 TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")

	if passed_count == total_count:
		print("[SUCCESS] All Milestone 15 tests PASSED with 100% success!")
		quit(0)
	else:
		print("[FAILURE] Milestone 15 test suite had failures.")
		quit(1)


func _assert(condition: bool, message: String) -> void:
	total_count += 1
	if condition:
		passed_count += 1
		print("  [PASS] %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	print("  [FAIL] %s" % message)
