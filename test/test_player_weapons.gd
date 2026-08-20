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
	
	# Test weapon switching
	print("\n--- Testing Weapon Inventory Cycling ---")
	var weapons = player.get("_weapons")
	print("Registered weapons count: ", weapons.size() if weapons else 0)
	
	if weapons and weapons.size() == 5:
		for i in range(weapons.size()):
			var w = weapons[i]
			print("  Slot %d: %s (visible=%s)" % [i, w.name, w.visible])
			
	print("\n=== PLAYER WEAPON SUITE TEST COMPLETED SUCCESSFULLY ===")
	get_tree().quit(0)
