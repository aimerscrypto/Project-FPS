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

	# Find the specific target weapon node inside the master hierarchy
	var target_node : Node3D = master_instance.find_child(weapon_node_name, true, false) as Node3D
	if not target_node:
		push_error("WeaponVisual: Weapon node '%s' not found in %s" % [weapon_node_name, MASTER_GLB_PATH])
		master_instance.queue_free()
		return

	# Duplicate ONLY this weapon subtree
	var weapon_model : Node3D = target_node.duplicate() as Node3D

	# Zero out matrix translation so the weapon sits perfectly at WeaponVisual's local origin
	weapon_model.transform = Transform3D.IDENTITY
	weapon_model.position = visual_offset
	weapon_model.rotation_degrees = visual_rotation_degrees
	weapon_model.scale = visual_scale
	weapon_model.visible = true

	# Ensure all sub-meshes in this weapon's subtree are visible
	_set_subtree_visible(weapon_model, true)

	add_child(weapon_model)
	_is_built = true

	# Immediately free the temporary master instance containing all other 11 guns
	master_instance.queue_free()


func _set_subtree_visible(node: Node, vis: bool) -> void:
	if node is Node3D:
		node.visible = vis
	for child in node.get_children():
		_set_subtree_visible(child, vis)
