extends SceneTree

var arena : Node = null
var frame_idx : int = 0
var out_dir : String = "C:/Users/NAC/.gemini/antigravity-ide/brain/500be785-4d7f-41f3-b35d-99f85bc31b44"

func _init():
	print("--- CAPTURING IN-GAME SCREENSHOTS ---")
	call_deferred("_start_capture")

func _start_capture():
	var arena_scene := load("res://scenes/maps/test_arena.tscn") as PackedScene
	arena = arena_scene.instantiate()
	root.add_child(arena)
	
	# Wait for scene initialization
	for i in range(20):
		await process_frame
	
	# Capture First Person Idle View
	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png(out_dir + "/gameplay_rifle_first_person.png")
		print("Saved gameplay_rifle_first_person.png")
	
	# Trigger Fire on player weapon
	var player = arena.get_node_or_null("Player")
	if player:
		var weapon = player.find_child("AssaultRifle", true, false)
		if weapon:
			weapon.try_fire()
			await process_frame
			var img_fire = root.get_viewport().get_texture().get_image()
			if img_fire:
				img_fire.save_png(out_dir + "/gameplay_rifle_firing.png")
				print("Saved gameplay_rifle_firing.png")
	
	arena.queue_free()
	print("CAPTURE COMPLETED SUCCESSFULLY!")
	quit(0)
