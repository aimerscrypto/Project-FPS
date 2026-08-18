extends CanvasLayer
class_name CrosshairHUD

# =============================================================================
# Project FPS — CrosshairHUD
# Milestone 10 — Hit Feedback & Hitmarkers
#
# Provides:
# - Standard 2D center reticle
# - Clean body-hit feedback (crisp white diagonal hitmarker, 0.12s decay)
# - High-impact headshot feedback (vivid crimson red enlarged hitmarker, 0.20s decay)
# =============================================================================

@onready var _hitmarker : Control = $CrosshairControl/Center/Hitmarker

var _hit_tween : Tween = null


func _ready() -> void:
	if _hitmarker:
		_hitmarker.modulate.a = 0.0
		_hitmarker.scale = Vector2.ONE
		_hitmarker.pivot_offset = Vector2.ZERO


## Triggers a clean visual hitmarker centered over the reticle.
## is_headshot: true for red critical punch, false for white standard tick
func show_hitmarker(is_headshot: bool = false) -> void:
	if _hitmarker == null or not is_instance_valid(_hitmarker):
		return

	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()

	if is_headshot:
		_hitmarker.modulate = Color(1.0, 0.2, 0.2, 1.0) # Vivid Crimson Red
		_hitmarker.scale = Vector2(1.35, 1.35)
		if is_inside_tree():
			_hit_tween = create_tween()
			_hit_tween.set_parallel(true)
			_hit_tween.tween_property(_hitmarker, "modulate:a", 0.0, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			_hit_tween.tween_property(_hitmarker, "scale", Vector2(1.0, 1.0), 0.20).set_ease(Tween.EASE_OUT)
	else:
		_hitmarker.modulate = Color(1.0, 1.0, 1.0, 0.95) # Crisp White
		_hitmarker.scale = Vector2(1.0, 1.0)
		if is_inside_tree():
			_hit_tween = create_tween()
			_hit_tween.tween_property(_hitmarker, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
