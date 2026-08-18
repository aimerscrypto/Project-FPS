extends SceneTree

# =============================================================================
# Project FPS — Milestone 10 Weapon Polish & Combat Feel Automated Test Suite
# Tests:
# - Test 1: Data-driven audio keys, casing types, and reload profiles
# - Test 2: Audio preloading in AudioManager
# - Test 3: CasingManager pool initialization, ejection, and recycling
# - Test 4: Assault Rifle firing, muzzle flash, dry-fire kick, and reload
# - Test 5: Pistol firing, semi-auto configuration, muzzle flash, and reload
# - Test 6: Crosshair visual hitmarker system
# - Test 7: Weapon equip ready-up transition
# - Test 8: Full FFA Arena integration & combat simulation
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
	_log("     RUNNING MILESTONE 10 WEAPON POLISH TEST SUITE      ")
	_log("========================================================\n")
	call_deferred("_run_suite")

func _run_suite() -> void:
	# -------------------------------------------------------------------------
	# 1. Test Weapon Data & Configuration
	# -------------------------------------------------------------------------
	_log("--- TEST 1: Weapon Data & Audio Keys ---")
	var ar_data = load("res://data/weapons/assault_rifle.tres") as WeaponData
	_assert(ar_data != null, "Assault Rifle WeaponData loaded")
	if ar_data:
		_assert(ar_data.fire_sound == "ar_fire", "AR fire_sound is 'ar_fire'")
		_assert(ar_data.dryfire_sound == "ar_dryfire", "AR dryfire_sound is 'ar_dryfire'")
		_assert(ar_data.reload_sound == "ar_reload", "AR reload_sound is 'ar_reload'")
		_assert(ar_data.casing_type == "rifle", "AR casing_type is 'rifle'")
		_assert(ar_data.reload_profile == "rifle", "AR reload_profile is 'rifle'")
		_assert(ar_data.is_automatic == true, "AR is automatic")

	var pistol_data = load("res://data/weapons/pistol.tres") as WeaponData
	_assert(pistol_data != null, "Pistol WeaponData loaded")
	if pistol_data:
		_assert(pistol_data.fire_sound == "pistol_fire", "Pistol fire_sound is 'pistol_fire'")
		_assert(pistol_data.dryfire_sound == "pistol_dryfire", "Pistol dryfire_sound is 'pistol_dryfire'")
		_assert(pistol_data.reload_sound == "pistol_reload", "Pistol reload_sound is 'pistol_reload'")
		_assert(pistol_data.casing_type == "pistol", "Pistol casing_type is 'pistol'")
		_assert(pistol_data.reload_profile == "pistol", "Pistol reload_profile is 'pistol'")
		_assert(pistol_data.is_automatic == false, "Pistol is semi-automatic")

	# -------------------------------------------------------------------------
	# 2. Test Audio Streams Preloading
	# -------------------------------------------------------------------------
	_log("\n--- TEST 2: Audio Preloading in AudioManager ---")
	var audio_mgr = root.get_node_or_null("AudioManager")
	_assert(audio_mgr != null, "AudioManager autoload exists in root")
	if audio_mgr:
		_assert(audio_mgr.get_stream("ar_fire") != null, "ar_fire stream loaded")
		_assert(audio_mgr.get_stream("ar_dryfire") != null, "ar_dryfire stream loaded")
		_assert(audio_mgr.get_stream("ar_reload") != null, "ar_reload stream loaded")
		_assert(audio_mgr.get_stream("pistol_fire") != null, "pistol_fire stream loaded")
		_assert(audio_mgr.get_stream("pistol_dryfire") != null, "pistol_dryfire stream loaded")
		_assert(audio_mgr.get_stream("pistol_reload") != null, "pistol_reload stream loaded")
		_assert(audio_mgr.get_stream("hitmarker") != null, "hitmarker stream loaded")
		_assert(audio_mgr.get_stream("headshot") != null, "headshot stream loaded")

	# -------------------------------------------------------------------------
	# 3. Test CasingManager
	# -------------------------------------------------------------------------
	_log("\n--- TEST 3: CasingManager Pool & Recycling ---")
	var casing_mgr = root.get_node_or_null("CasingManager")
	_assert(casing_mgr != null, "CasingManager autoload active in scene tree")
	if casing_mgr:
		_assert(casing_mgr.POOL_SIZE == 24, "Casing pool size is 24")
		# Eject rifle casing
		casing_mgr.eject_casing(Vector3(0, 1, 0), Basis.IDENTITY, "rifle", Vector3.ZERO)
		_assert(casing_mgr._slots[0].is_active == true, "Casing slot 0 activated on ejection")
		_assert(casing_mgr._slots[0].mesh_node.visible == true, "Casing mesh node set visible")
		# Eject pistol casing
		casing_mgr.eject_casing(Vector3(0, 1, 0), Basis.IDENTITY, "pistol", Vector3.ZERO)
		_assert(casing_mgr._slots[1].is_active == true, "Casing slot 1 activated for pistol")
		# Test pool wrap-around recycling without errors
		for i in range(30):
			casing_mgr.eject_casing(Vector3(0, 1, 0), Basis.IDENTITY, "rifle")
		_assert(casing_mgr._slots.size() == 24, "Pool size remains strictly fixed at 24")

	# -------------------------------------------------------------------------
	# 4. Test Assault Rifle Node & Behaviors
	# -------------------------------------------------------------------------
	_log("\n--- TEST 4: Assault Rifle Polish & Behaviors ---")
	var ar_scene = load("res://scenes/weapons/assault_rifle.tscn") as PackedScene
	_assert(ar_scene != null, "assault_rifle.tscn packed scene loaded")
	if ar_scene:
		var ar = ar_scene.instantiate()
		root.add_child(ar)
		await process_frame

		_assert(ar.get_node_or_null("EjectionPort") != null, "AR has EjectionPort marker")
		_assert(ar.get_node_or_null("MuzzleFlash") != null, "AR has MuzzleFlash node")
		var mf = ar.get_node_or_null("MuzzleFlash")
		if mf:
			_assert(mf.visible == false, "AR MuzzleFlash initially hidden")

		# Test Firing & Muzzle Flash
		var prev_ammo = ar._current_ammo
		ar.try_fire()
		_assert(ar._current_ammo == prev_ammo - 1, "AR fired and ammo reduced")
		if mf:
			_assert(mf.visible == true, "AR MuzzleFlash visible immediately on fire")
		ar._process(0.15)
		if mf:
			_assert(mf.visible == false, "AR MuzzleFlash auto-hid after duration")

		# Test Dry Fire Kick
		var kick_before = ar._current_kick_pos.z
		ar._current_ammo = 0
		ar._reserve_ammo = 0
		ar.try_fire()
		_assert(ar._current_kick_pos.z > kick_before, "AR dry-fire produced tactile kick feedback")

		# Test Reload
		ar._current_ammo = 0
		ar._reserve_ammo = 60
		ar._fire_timer = 0.0
		ar.try_reload()
		_assert(ar._state == ar.WeaponState.RELOADING, "AR entered RELOADING state")

		ar.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# 5. Test Pistol Node & Behaviors
	# -------------------------------------------------------------------------
	_log("\n--- TEST 5: Pistol Polish & Behaviors ---")
	var pistol_scene = load("res://scenes/weapons/pistol.tscn") as PackedScene
	_assert(pistol_scene != null, "pistol.tscn packed scene loaded")
	if pistol_scene:
		var pistol = pistol_scene.instantiate()
		root.add_child(pistol)
		await process_frame

		_assert(pistol.get_node_or_null("EjectionPort") != null, "Pistol has EjectionPort marker")
		_assert(pistol.get_node_or_null("MuzzleFlash") != null, "Pistol has MuzzleFlash node")
		_assert(pistol.is_automatic() == false, "Pistol reports is_automatic == false")

		var p_mf = pistol.get_node_or_null("MuzzleFlash")
		var p_ammo = pistol._current_ammo
		pistol.try_fire()
		_assert(pistol._current_ammo == p_ammo - 1, "Pistol single shot fired")
		if p_mf:
			_assert(p_mf.visible == true, "Pistol MuzzleFlash visible on fire")
		pistol._process(0.25)
		if p_mf:
			_assert(p_mf.visible == false, "Pistol MuzzleFlash auto-hid")

		# Test Pistol Dry Fire
		var p_kick_before = pistol._current_kick_pos.z
		pistol._current_ammo = 0
		pistol._reserve_ammo = 0
		pistol.try_fire()
		_assert(pistol._current_kick_pos.z > p_kick_before, "Pistol dry-fire produced tactile kick")

		pistol.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# 6. Test Crosshair Hitmarker System
	# -------------------------------------------------------------------------
	_log("\n--- TEST 6: Crosshair Hitmarker System ---")
	var crosshair_scene = load("res://scenes/ui/crosshair.tscn") as PackedScene
	_assert(crosshair_scene != null, "crosshair.tscn loaded")
	if crosshair_scene:
		var ch = crosshair_scene.instantiate()
		root.add_child(ch)
		await process_frame

		var hitmarker_node = ch.get_node_or_null("CrosshairControl/Center/Hitmarker")
		_assert(hitmarker_node != null, "Hitmarker node exists inside CrosshairHUD")
		_assert(ch.has_method("show_hitmarker"), "CrosshairHUD provides show_hitmarker method")

		ch.show_hitmarker(false)
		_assert(hitmarker_node.modulate.r == 1.0 and hitmarker_node.modulate.g == 1.0, "Body hitmarker triggers white tint")

		ch.show_hitmarker(true)
		_assert(hitmarker_node.modulate.r == 1.0 and hitmarker_node.modulate.g < 0.5, "Headshot hitmarker triggers red tint")
		_assert(hitmarker_node.scale.x > 1.2, "Headshot hitmarker triggers enlarged scale punch")

		ch.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# 7. Test Equip Transition
	# -------------------------------------------------------------------------
	_log("\n--- TEST 7: Weapon Equip Transition ---")
	if ar_scene:
		var ar2 = ar_scene.instantiate()
		root.add_child(ar2)
		await process_frame
		ar2.equip()
		_assert(ar2.is_equipping() == true, "AR is_equipping() is true immediately upon equip")
		_assert(ar2._equip_timer > 0.15, "AR _equip_timer initialized to ~0.20s")
		ar2._process(0.25)
		_assert(ar2.is_equipping() == false, "AR is_equipping() is false after 0.20s transition")
		ar2.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# 8. Full FFA Arena Integration
	# -------------------------------------------------------------------------
	_log("\n--- TEST 8: Full FFA Arena Integration ---")
	var arena_scene = load("res://scenes/maps/test_arena.tscn") as PackedScene
	if arena_scene:
		var arena = arena_scene.instantiate()
		root.add_child(arena)
		await process_frame
		await process_frame

		var player = arena.get_node_or_null("Player")
		_assert(player != null, "Player present in Arena")
		if player:
			_assert(player._weapons.size() == 2, "Player has both AR and Pistol registered")
			_assert(player._active_weapon != null, "Player has active weapon equipped")
			_assert(player._crosshair_hud != null, "Player has CrosshairHUD linked")

		arena.queue_free()
		await process_frame

	# -------------------------------------------------------------------------
	# Summary
	# -------------------------------------------------------------------------
	_log("\n========================================================")
	_log("       TEST SUMMARY: %d / %d TESTS PASSED               " % [passed_count, total_count])
	_log("========================================================\n")

	if passed_count == total_count:
		_log(">> ALL MILESTONE 10 WEAPON POLISH TESTS PASSED! <<\n")
		quit(0)
	else:
		_log(">> SOME TESTS FAILED! <<\n")
		quit(1)
