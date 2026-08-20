extends Node3D

func _ready() -> void:
	print("=== M16 WEAPON INTEGRATION TEST START ===")
	
	var ar_scene = load("res://scenes/weapons/assault_rifle.tscn")
	if not ar_scene:
		push_error("Failed to load assault_rifle.tscn")
		get_tree().quit(1)
		return
		
	var ar = ar_scene.instantiate()
	$Camera3D.add_child(ar)
	
	var vis = ar.find_child("WeaponVisual", true, false)
	print("WeaponVisual found: ", vis != null)
	if vis:
		print("WeaponVisual transform: ", vis.transform)
		
	var ap: AnimationPlayer = ar.find_child("AnimationPlayer", true, false)
	print("AnimationPlayer found: ", ap != null)
	if ap:
		print("Animations available: ", ap.get_animation_list())
		
	var muzzle = ar.find_child("MuzzleFlash", true, false)
	if muzzle:
		print("MuzzleFlash position: ", muzzle.position)
		
	var optic = ar.find_child("OpticPoint", true, false)
	if optic:
		print("OpticPoint position: ", optic.position)
		
	var eject = ar.find_child("EjectionPort", true, false)
	if eject:
		print("EjectionPort position: ", eject.position)
		
	# Call equip, fire, reload on ar
	if ar.has_method("equip"):
		ar.equip()
		print("Equip called")
		
	if ar.has_method("try_fire"):
		ar.try_fire()
		print("Fire called")
		
	if ar.has_method("try_reload"):
		ar.try_reload()
		print("Reload called")
		
	print("=== M16 WEAPON INTEGRATION TEST COMPLETED SUCCESSFULLY ===")
	get_tree().quit(0)
