extends SceneTree

# Continuous 20-second live FFA combat simulation test
func _init() -> void:
	call_deferred("_run_simulation")


func _run_simulation() -> void:
	var arena_scene := load("res://scenes/maps/test_arena.tscn") as PackedScene
	var arena := arena_scene.instantiate()
	root.add_child(arena)

	print("\n>>> STARTING 20-SECOND LIVE FFA COMBAT SIMULATION <<<\n")

	# Simulate 1200 physics frames (20.0s at 60fps)
	for i in range(1200):
		arena.get_tree().physics_frame
		await process_frame

	print("\n>>> LIVE FFA COMBAT SIMULATION COMPLETE <<<\n")
	var match_mgr : Node = arena.get_node_or_null("MatchManager")
	if match_mgr:
		print("--- FINAL MATCH STATS (20s Session) ---")
		for c in match_mgr._combatant_stats:
			var s = match_mgr._combatant_stats[c]
			print("  %s: %d Kills / %d Deaths (Score: %d)" % [s["name"], s["kills"], s["deaths"], s["score"]])

	arena.queue_free()
	quit(0)
