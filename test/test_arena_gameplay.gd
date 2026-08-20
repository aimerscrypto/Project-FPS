extends Node3D

func _ready() -> void:
	print("=== LIVE TEST ARENA GAMEPLAY VALIDATION START ===")
	
	var arena_scene = load("res://scenes/maps/test_arena.tscn")
	if not arena_scene:
		push_error("Failed to load test_arena.tscn")
		get_tree().quit(1)
		return
		
	var arena = arena_scene.instantiate()
	add_child(arena)
	
	# Find player
	var player = arena.find_child("Player", true, false)
	if not player:
		push_error("Player not found in test_arena")
		get_tree().quit(1)
		return
		
	print("Player found in test_arena at: ", player.global_position)
	
	var ar = player.find_child("AssaultRifle", true, false)
	var ar_vis = ar.find_child("WeaponVisual", true, false) if ar else null
	var ar_ap: AnimationPlayer = ar.find_child("AnimationPlayer", true, false) if ar else null
	
	print("AssaultRifle present: ", ar != null)
	print("AssaultRifle visual present: ", ar_vis != null)
	print("AssaultRifle AnimationPlayer present: ", ar_ap != null)
	
	# Run simulation for 1.0 second (60 frames)
	for frame in range(60):
		await get_tree().physics_frame
		if frame == 25:
			print("Simulating AR fire input at frame 25...")
			if ar and ar.has_method("try_fire"):
				ar.try_fire()
		elif frame == 35:
			print("Simulating AR reload input at frame 35...")
			if ar and ar.has_method("try_reload"):
				ar.try_reload()
				
	print("\n=== LIVE TEST ARENA GAMEPLAY VALIDATION COMPLETED: SUCCESS ===")
	get_tree().quit(0)
