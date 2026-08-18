extends Node

# =============================================================================
# Project FPS — CasingManager
# Milestone 10 — Shell / Casing Ejection System
#
# Provides:
# - Pre-allocated 24-slot ring buffer pool of MeshInstance3D nodes
# - Zero runtime node allocations during shooting
# - Distinct slender rifle and compact 9mm pistol brass geometries
# - Realistic ballistic ejection arc, rapid tumbling, and floor bounce damping
# - Deterministic auto-cleanup / recycling
# =============================================================================

const POOL_SIZE : int = 24
const GRAVITY   : float = 16.0  # m/s² downward pull

# Casing state record
class CasingSlot:
	var mesh_node    : MeshInstance3D = null
	var is_active    : bool           = false
	var position     : Vector3        = Vector3.ZERO
	var velocity     : Vector3        = Vector3.ZERO
	var rot_axis     : Vector3        = Vector3.UP
	var rot_speed    : float          = 0.0
	var lifetime     : float          = 0.0
	var max_lifetime : float          = 1.8
	var bounces      : int            = 0

var _slots : Array[CasingSlot] = []
var _pool_index : int = 0

# Shared visual resources
var _mat_brass       : StandardMaterial3D = null
var _mesh_rifle      : CylinderMesh       = null
var _mesh_pistol     : CylinderMesh       = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_resources()
	_initialize_pool()


func _create_resources() -> void:
	_mat_brass = StandardMaterial3D.new()
	_mat_brass.albedo_color = Color(0.88, 0.70, 0.28, 1.0) # Warm metallic brass
	_mat_brass.metallic = 0.90
	_mat_brass.roughness = 0.25

	# Slender rifle casing (5.56 / .223 style)
	_mesh_rifle = CylinderMesh.new()
	_mesh_rifle.top_radius = 0.0042
	_mesh_rifle.bottom_radius = 0.0048
	_mesh_rifle.height = 0.024
	_mesh_rifle.radial_segments = 8
	_mesh_rifle.rings = 1
	_mesh_rifle.material = _mat_brass

	# Compact pistol casing (9mm style)
	_mesh_pistol = CylinderMesh.new()
	_mesh_pistol.top_radius = 0.0045
	_mesh_pistol.bottom_radius = 0.0048
	_mesh_pistol.height = 0.014
	_mesh_pistol.radial_segments = 8
	_mesh_pistol.rings = 1
	_mesh_pistol.material = _mat_brass


func _initialize_pool() -> void:
	_slots.clear()
	for i in range(POOL_SIZE):
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "Casing_%d" % i
		mesh_inst.visible = false
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_inst)

		var slot := CasingSlot.new()
		slot.mesh_node = mesh_inst
		slot.is_active = false
		_slots.append(slot)


## Ejects a shell casing from a world transform with dynamic impulse and tumbling.
## spawn_pos: World origin of weapon ejection port
## spawn_basis: World basis of weapon (for rightward/upward orientation)
## casing_type: "rifle" or "pistol"
## inherited_vel: Movement velocity of shooter
func eject_casing(
	spawn_pos: Vector3,
	spawn_basis: Basis,
	casing_type: String = "rifle",
	inherited_vel: Vector3 = Vector3.ZERO
) -> void:
	if _slots.is_empty():
		return

	# Round-robin selection (recycle oldest if pool is fully active)
	var slot := _slots[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE

	# Set appropriate geometry
	if casing_type == "pistol":
		slot.mesh_node.mesh = _mesh_pistol
	else:
		slot.mesh_node.mesh = _mesh_rifle

	# Ejection direction: Rightward (+X), upward (+Y), slight backward/forward variance (+/-Z)
	var local_eject_dir := Vector3(
		randf_range(1.6, 2.4),
		randf_range(1.1, 1.8),
		randf_range(-0.4, 0.4)
	)
	var world_eject_vel := spawn_basis * local_eject_dir

	# Add shooter momentum damping
	slot.velocity = world_eject_vel + (inherited_vel * 0.4)
	slot.position = spawn_pos
	slot.rot_axis = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	slot.rot_speed = randf_range(18.0, 36.0) # Rapid tumble spin
	slot.lifetime = 0.0
	slot.max_lifetime = randf_range(1.8, 2.2)
	slot.bounces = 0
	slot.is_active = true

	slot.mesh_node.global_position = slot.position
	slot.mesh_node.global_rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	slot.mesh_node.visible = true


func _physics_process(delta: float) -> void:
	var space_state : PhysicsDirectSpaceState3D = null
	var world_3d := get_viewport().find_world_3d() if get_viewport() else null
	if world_3d:
		space_state = world_3d.direct_space_state

	for slot in _slots:
		if not slot.is_active:
			continue

		slot.lifetime += delta
		if slot.lifetime >= slot.max_lifetime:
			slot.is_active = false
			slot.mesh_node.visible = false
			continue

		# Gravity
		slot.velocity.y -= GRAVITY * delta

		var step := slot.velocity * delta
		var next_pos := slot.position + step

		# Light raycast collision with arena geometry
		if space_state and slot.bounces < 3 and slot.velocity.length_squared() > 0.1:
			var query := PhysicsRayQueryParameters3D.create(slot.position, next_pos, 1) # Environment mask 1
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit := space_state.intersect_ray(query)

			if not hit.is_empty():
				var hit_point : Vector3 = hit.position
				var hit_normal : Vector3 = hit.normal

				slot.position = hit_point + hit_normal * 0.006
				# Inelastic bounce with heavy friction
				slot.velocity = slot.velocity.bounce(hit_normal) * 0.38
				slot.rot_speed *= 0.45
				slot.bounces += 1
				if slot.velocity.length_squared() < 0.1:
					slot.velocity = Vector3.ZERO
					slot.rot_speed = 0.0
			else:
				slot.position = next_pos
		else:
			slot.position = next_pos

		# Update mesh transform
		slot.mesh_node.global_position = slot.position
		if slot.rot_speed > 0.01:
			slot.mesh_node.rotate(slot.rot_axis, slot.rot_speed * delta)
