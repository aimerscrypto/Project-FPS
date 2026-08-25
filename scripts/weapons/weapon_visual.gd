@tool
class_name WeaponVisual
extends Node3D

# =============================================================================
# Project FPS — WeaponVisual
# Dedicated visual extractor for 12_low_poly_guns.glb master asset.
# Extracts ONLY the specified weapon mesh node subtree, centering it at origin.
# Ensures that NO other weapons from the master pack exist in the scene tree.
# =============================================================================

const MASTER_GLB_PATH : String = "res://assets/models/12_low_poly_guns.glb"

## The exact node name of the weapon inside 12_low_poly_guns.glb
## Examples: "M16_8", "Glock Handgun_45", "Pump Action Shotgun_25", "MP5_17", "M40_33"
@export var weapon_node_name : String = "":
	set(value):
		weapon_node_name = value
		if is_inside_tree():
			_build_visual()

## Optional custom scale multiplier (defaults to Vector3.ONE)
@export var visual_scale : Vector3 = Vector3.ONE

## Optional custom rotation offset in degrees (default 180 Y to face forward down -Z)
@export var visual_rotation_degrees : Vector3 = Vector3(0, 180, 0)

## Optional custom position offset
@export var visual_offset : Vector3 = Vector3.ZERO

var _is_built : bool = false


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	# Remove any existing visual children
	for child in get_children():
		child.queue_free()

	_is_built = false

	if weapon_node_name.is_empty():
		return

	var master_scene : PackedScene = load(MASTER_GLB_PATH)
	if not master_scene:
		push_error("WeaponVisual: Failed to load master weapon GLB at '%s'" % MASTER_GLB_PATH)
		return

	var master_instance : Node = master_scene.instantiate()
	if not master_instance:
		push_error("WeaponVisual: Failed to instantiate master weapon scene")
		return

	var node_names : PackedStringArray = weapon_node_name.split(",", false)
	if node_names.is_empty():
		master_instance.queue_free()
		return

	if node_names.size() == 1:
		var target_name : String = node_names[0].strip_edges()
		var target_node : Node3D = _find_node_in_master(master_instance, target_name)
		if not target_node:
			push_error("WeaponVisual: Weapon node '%s' not found in %s" % [target_name, MASTER_GLB_PATH])
			master_instance.queue_free()
			return

		var weapon_model : Node3D = target_node.duplicate() as Node3D
		weapon_model.transform = Transform3D.IDENTITY
		weapon_model.position = visual_offset
		weapon_model.rotation_degrees = visual_rotation_degrees
		weapon_model.scale = visual_scale
		weapon_model.visible = true

		_set_subtree_visible(weapon_model, true)
		add_child(weapon_model)
	else:
		# Multi-node composite weapon extraction (e.g. Luger P08 with detached body parts)
		var model_container := Node3D.new()
		model_container.name = "CompositeWeaponModel"
		
		var primary_name : String = node_names[0].strip_edges()
		var primary_node : Node3D = _find_node_in_master(master_instance, primary_name)
		if not primary_node:
			push_error("WeaponVisual: Primary weapon node '%s' not found in %s" % [primary_name, MASTER_GLB_PATH])
			master_instance.queue_free()
			return

		var ref_origin : Vector3 = primary_node.transform.origin

		for name_entry in node_names:
			var trimmed : String = name_entry.strip_edges()
			var part_node : Node3D = _find_node_in_master(master_instance, trimmed)
			if not part_node:
				push_warning("WeaponVisual: Sub-part '%s' not found in %s" % [trimmed, MASTER_GLB_PATH])
				continue

			var part_dup : Node3D = part_node.duplicate() as Node3D
			part_dup.transform.origin = part_node.transform.origin - ref_origin
			part_dup.visible = true
			_set_subtree_visible(part_dup, true)
			model_container.add_child(part_dup)

		model_container.position = visual_offset
		model_container.rotation_degrees = visual_rotation_degrees
		model_container.scale = visual_scale
		model_container.visible = true
		add_child(model_container)

	_is_built = true

	# Immediately free the temporary master instance containing all other 11 guns
	master_instance.queue_free()


func _find_node_in_master(root: Node, search_name: String) -> Node3D:
	if search_name.is_empty() or root == null:
		return null

	# 1. Direct exact match
	var node := root.find_child(search_name, true, false) as Node3D
	if node:
		return node

	# 2. Try period sanitized to underscore (Godot glTF importer naming convention)
	var with_underscore := search_name.replace(".", "_")
	node = root.find_child(with_underscore, true, false) as Node3D
	if node:
		return node

	# 3. Try underscore sanitized to period
	var with_dot := search_name.replace("_", ".")
	node = root.find_child(with_dot, true, false) as Node3D
	if node:
		return node

	# 4. Recursive normalized search ignoring punctuation and casing
	var norm_target := search_name.to_lower().replace(".", "").replace("_", "").replace(" ", "").replace("-", "")
	return _find_node_recursive(root, norm_target)


func _find_node_recursive(current: Node, norm_target: String) -> Node3D:
	var current_norm := current.name.to_lower().replace(".", "").replace("_", "").replace(" ", "").replace("-", "")
	if current is Node3D and current_norm == norm_target:
		return current as Node3D
	for child in current.get_children():
		var res := _find_node_recursive(child, norm_target)
		if res != null:
			return res
	return null


func _set_subtree_visible(node: Node, vis: bool) -> void:
	if node is Node3D:
		node.visible = vis
	for child in node.get_children():
		_set_subtree_visible(child, vis)
