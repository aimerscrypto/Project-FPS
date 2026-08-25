extends Node3D

func _ready() -> void:
	print("=== PLAYER WEAPON SUITE TEST START ===")
	
	var player_scene = load("res://scenes/player/player.tscn")
	if not player_scene:
		push_error("Failed to load player.tscn")
		get_tree().quit(1)
		return
		
	var player = player_scene.instantiate()
	player.position = Vector3(0, 1, 0)
	add_child(player)
	
	# Wait for equip duration and physics settling
	await get_tree().create_timer(0.35).timeout
	
	# Verify active weapon is AssaultRifle
	var ar = player.find_child("AssaultRifle", true, false)
	if not ar:
		push_error("AssaultRifle not found under Player")
		get_tree().quit(1)
		return
		
	var ar_vis = ar.find_child("WeaponVisual", true, false)
	var ar_ap = ar.find_child("AnimationPlayer", true, false)
	print("AR Visual present: ", ar_vis != null)
	print("AR AnimationPlayer present: ", ar_ap != null)
	if ar_ap:
		print("AR animations: ", ar_ap.get_animation_list())
		
	# Test AR firing
	print("\n--- Testing AR Firing ---")
	var initial_ammo = ar.get_ammo_info()["current"]
	ar.try_fire()
	var after_fire_ammo = ar.get_ammo_info()["current"]
	print("Ammo before: %d, after: %d" % [initial_ammo, after_fire_ammo])
	assert(after_fire_ammo == initial_ammo - 1, "Ammo did not decrement on fire")
	
	# Test AR reloading
	print("\n--- Testing AR Reloading ---")
	ar.try_reload()
	print("Reload state: ", ar.get_ammo_info()["state"])
	assert(ar.get_ammo_info()["state"] == "RELOADING", "Weapon should be in RELOADING state")
	
	# Test weapon switching and single-weapon visibility across all 12 slots
	print("\n--- Testing 12-Weapon Inventory & Switching ---")
	var weapons = player.get("_weapons")
	print("Registered weapons count: ", weapons.size() if weapons else 0)
	assert(weapons != null and weapons.size() == 12, "Expected exactly 12 weapons registered in player inventory!")

	var expected_names = [
		"AssaultRifle", "AK47", "SMG", "KrissVector",
		"Shotgun", "SawedOff", "Sniper", "Dragunov",
		"Pistol", "Revolver", "Luger", "DesertEagle"
	]

	for i in range(weapons.size()):
		var w = weapons[i]
		assert(w.name == expected_names[i], "Slot %d mismatch: expected %s, got %s" % [i, expected_names[i], w.name])
		
		player.switch_weapon(i)
		await get_tree().create_timer(0.05).timeout

		# Check visibility isolation: strictly ONLY weapon i should be visible
		var visible_count = 0
		for j in range(weapons.size()):
			if weapons[j].visible:
				visible_count += 1
		assert(visible_count == 1, "Slot %d switch failed: multiple or zero weapons visible (%d)" % [i, visible_count])
		assert(w.visible == true, "Slot %d (%s) should be visible" % [i, w.name])

		# Test firing
		var cur_ammo = w.get_ammo_info()["current"]
		w.try_fire()
		var after_ammo = w.get_ammo_info()["current"]
		assert(after_ammo == cur_ammo - 1, "Slot %d (%s) failed to fire: ammo before=%d, after=%d" % [i, w.name, cur_ammo, after_ammo])

		# Test reloading
		w.try_reload()
		assert(w.get_ammo_info()["state"] == "RELOADING", "Slot %d (%s) failed to enter RELOADING state" % [i, w.name])

		print("  [PASSED] Slot %d: %s | Fire OK (ammo: %d->%d) | Reload OK" % [i, w.name, cur_ammo, after_ammo])

	print("\n=== ALL 12 WEAPONS TESTED AND VALIDATED SUCCESSFULLY ===")
	get_tree().quit(0)
