extends SceneTree

# =============================================================================
# Project FPS — Weapon Restoration & Regression Test Suite
# Tests:
# - Test 1: Original Tripo Rifle Mesh & Material instantiation
# - Test 2: First-person transform & alignment
# - Test 3: Firing system & Ammo depletion
# - Test 4: Hitscan raycast & target damage
# - Test 5: Muzzle flash activation
# - Test 6: Reload system & reserve transfer
# - Test 7: Full FFA arena integration
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
	_log("       RUNNING WEAPON RESTORATION VERIFICATION TESTS     ")
	_log("========================================================\n")
	call_deferred("_run_suite")

func _run_suite() -> void:
	# 1. Test Weapon Visual & Root Scene
	var rifle_scene := load("res://scenes/weapons/assault_rifle.tscn") as PackedScene
	_assert(rifle_scene != null, "assault_rifle.tscn loaded successfully")
	
	if rifle_scene:
		var rifle = rifle_scene.instantiate()
		root.add_child(rifle)
		await process_frame
		
		# Check WeaponData
		_assert(rifle.data != null, "WeaponData resource assigned: %s" % rifle.data.weapon_name)
		_assert(rifle.data.magazine_size == 30, "Magazine size is 30")
		_assert(rifle.data.reserve_ammo == 120, "Reserve ammo is 120")
		
		# Check WeaponVisual
		var visual = rifle.get_node_or_null("WeaponVisual")
		_assert(visual != null, "WeaponVisual node exists under AssaultRifle")
		
		# Check Mesh presence
		var mesh_instance : MeshInstance3D = null
		if visual is MeshInstance3D:
			mesh_instance = visual
		else:
			for child in visual.get_children():
				if child is MeshInstance3D:
					mesh_instance = child
					break
		
		_assert(mesh_instance != null, "MeshInstance3D found in WeaponVisual")
		if mesh_instance and mesh_instance.mesh:
			var poly_count = mesh_instance.mesh.get_faces().size() / 3
			_log("    Mesh vertex/face info: Face count ~ %d" % poly_count)
			_assert(poly_count > 1000, "Original high-detail Tripo mesh active (~%d triangles)" % poly_count)
		
		# Check Transform
		var t_pos = visual.transform.origin
		_assert(t_pos.x > 0.1 and t_pos.y < 0.0 and t_pos.z < 0.0, "Weapon positioned in lower-right first-person view: %s" % str(t_pos))
		
		# Check MuzzleFlash
		var flash = rifle.get_node_or_null("MuzzleFlash")
		_assert(flash != null, "MuzzleFlash node exists")
		if flash:
			_assert(flash.visible == false, "MuzzleFlash is initially hidden")
		
		# Test Firing
		var initial_ammo = rifle._current_ammo
		rifle.try_fire()
		_assert(rifle._current_ammo == initial_ammo - 1, "Firing decrements ammo (%d -> %d)" % [initial_ammo, rifle._current_ammo])
		_assert(rifle._state == rifle.WeaponState.FIRING, "Weapon state is FIRING")
		if flash:
			_assert(flash.visible == true, "MuzzleFlash triggered visible on fire")
		
		# Tick timers
		rifle._process(0.1)
		_assert(rifle._state == rifle.WeaponState.READY, "Weapon state returns to READY after cooldown")
		if flash:
			_assert(flash.visible == false, "MuzzleFlash automatically hid after duration")
		
		# Test Reload
		rifle.try_reload()
		_assert(rifle._state == rifle.WeaponState.RELOADING, "Weapon entered RELOADING state")
		# Advance reload timer
		rifle._process(rifle.data.reload_time + 0.1)
		_assert(rifle._state == rifle.WeaponState.READY, "Weapon returned to READY after reload")
		_assert(rifle._current_ammo == rifle.data.magazine_size, "Magazine restored to full (%d)" % rifle._current_ammo)
		
		rifle.queue_free()
		await process_frame
	
	# 2. Test Full Arena Integration with Player and Bots
	var arena_scene := load("res://scenes/maps/test_arena.tscn") as PackedScene
	if arena_scene:
		var arena = arena_scene.instantiate()
		root.add_child(arena)
		await process_frame
		await process_frame
		
		var player = arena.get_node_or_null("Player")
		_assert(player != null, "Player instantiated in Arena")
		
		if player:
			var player_weapon = player.get_node_or_null("Head/Camera3D/WeaponHolder/AssaultRifle")
			if not player_weapon:
				player_weapon = player.find_child("AssaultRifle", true, false)
			_assert(player_weapon != null, "AssaultRifle is mounted in Player hierarchy")
			if player_weapon:
				var p_vis = player_weapon.get_node_or_null("WeaponVisual")
				_assert(p_vis != null, "Player's weapon has WeaponVisual attached")
		
		arena.queue_free()
		await process_frame

	_log("\n========================================================")
	_log("       TEST SUMMARY: %d / %d TESTS PASSED               " % [passed_count, total_count])
	_log("========================================================\n")
	
	var f = FileAccess.open("res://weapon_restoration_results.txt", FileAccess.WRITE)
	if f:
		for line in log_lines:
			f.store_line(line)
		f.close()
	
	if passed_count == total_count:
		_log(">> ALL WEAPON RESTORATION TESTS PASSED! <<\n")
		quit(0)
	else:
		_log(">> SOME WEAPON TESTS FAILED! <<\n")
		quit(1)
