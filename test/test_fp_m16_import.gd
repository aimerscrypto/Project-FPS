extends Node3D

func _ready() -> void:
	print("=== GODOT FP M16 IMPORT AUDIT START ===")
	
	var model_scene = load("res://assets/models/player/fp_m16.glb")
	if not model_scene:
		push_error("FAILED to load res://assets/models/player/fp_m16.glb")
		get_tree().quit(1)
		return
		
	var model_inst = model_scene.instantiate()
	$ModelHolder.add_child(model_inst)
	
	print("\n--- NODE HIERARCHY ---")
	_print_tree(model_inst, 0)
	
	# Check Armature & Skeleton
	var skeleton = _find_node_by_type(model_inst, "Skeleton3D")
	if skeleton:
		print("\n--- SKELETON BONES (count=%d) ---" % skeleton.get_bone_count())
		for i in range(skeleton.get_bone_count()):
			var b_name = skeleton.get_bone_name(i)
			var p_idx = skeleton.get_bone_parent(i)
			var p_name = skeleton.get_bone_name(p_idx) if p_idx >= 0 else "ROOT"
			print("  Bone %d: %s (Parent: %s)" % [i, b_name, p_name])
	else:
		push_warning("Skeleton3D not found directly under model")
		
	# Check Meshes and Materials
	print("\n--- MESH & MATERIAL AUDIT ---")
	var mesh_nodes = _find_all_nodes_by_type(model_inst, "MeshInstance3D")
	for m in mesh_nodes:
		var mat_count = m.get_surface_override_material_count()
		var mesh = m.mesh
		var surf_count = mesh.get_surface_count() if mesh else 0
		print("  Mesh: %s | Surfaces: %d | OverrideMats: %d" % [m.name, surf_count, mat_count])
		for s in range(surf_count):
			var mat = mesh.surface_get_material(s)
			var mat_name = mat.resource_name if mat else "None"
			print("    Surface %d Material: %s" % [s, mat_name])
			
	# Check AnimationPlayer
	var ap: AnimationPlayer = _find_node_by_type(model_inst, "AnimationPlayer")
	if ap:
		var anim_list = ap.get_animation_list()
		print("\n--- ANIMATION PLAYER (count=%d) ---" % anim_list.size())
		for a in anim_list:
			var anim = ap.get_animation(a)
			print("  Animation '%s': length=%.3fs, track_count=%d, loop_mode=%s" % [a, anim.length, anim.get_track_count(), anim.loop_mode])
	else:
		push_error("AnimationPlayer NOT found in imported GLB")
		get_tree().quit(1)
		return
		
	# Test running animations
	print("\n--- PLAYING ANIMATION TESTS ---")
	if ap.has_animation("M16_Idle"):
		ap.play("M16_Idle")
		print("Playing M16_Idle successfully")
		await get_tree().create_timer(0.2).timeout
		
	if ap.has_animation("M16_Fire"):
		ap.play("M16_Fire")
		print("Playing M16_Fire successfully")
		await get_tree().create_timer(0.15).timeout
		
	if ap.has_animation("M16_Reload"):
		ap.play("M16_Reload")
		print("Playing M16_Reload successfully")
		await get_tree().create_timer(0.3).timeout
		
	print("\n=== GODOT FP M16 IMPORT AUDIT FINISHED: SUCCESS ===")
	get_tree().quit(0)

func _print_tree(node: Node, depth: int) -> void:
	var indent = ""
	for i in range(depth):
		indent += "  "
	print("%s- %s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1)

func _find_node_by_type(root: Node, class_name_str: String) -> Node:
	if root.is_class(class_name_str):
		return root
	for child in root.get_children():
		var res = _find_node_by_type(child, class_name_str)
		if res:
			return res
	return null

func _find_all_nodes_by_type(root: Node, class_name_str: String) -> Array:
	var result = []
	if root.is_class(class_name_str):
		result.append(root)
	for child in root.get_children():
		result.append_array(_find_all_nodes_by_type(child, class_name_str))
	return result
