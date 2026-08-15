extends CanvasLayer
class_name CombatHUD

# =============================================================================
# Project FPS — Combat HUD
#
# Minimal, lightweight 2D combat readability HUD providing:
# - Bottom-left Player Health display ("100 HP")
# - Retriggerable smooth screen-space damage flash / vignette
# - Responsive "YOU DIED" death overlay with killer info and respawn timer
# =============================================================================

@onready var _health_label     : Label     = $HealthDisplay/HealthLabel
@onready var _damage_flash     : ColorRect = $DamageFlash
@onready var _death_overlay    : Control   = $DeathOverlay
@onready var _death_killer     : Label     = $DeathOverlay/CenterBox/KillerLabel
@onready var _respawn_timer_lbl: Label     = $DeathOverlay/CenterBox/RespawnTimerLabel

var _flash_tween : Tween = null
var _respawn_time_left : float = 0.0
var _is_dead : bool = false


func _ready() -> void:
	if _damage_flash:
		_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
		_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _death_overlay:
		_death_overlay.visible = false
		_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_health(100.0, 100.0)


func _process(delta: float) -> void:
	if _is_dead and _respawn_time_left > 0.0:
		_respawn_time_left -= delta
		if _respawn_timer_lbl:
			_respawn_timer_lbl.text = "Respawning in %.1fs..." % max(_respawn_time_left, 0.0)


## Updates current HP label and color
func update_health(current_hp: float, max_hp: float) -> void:
	if _health_label == null or not is_instance_valid(_health_label):
		return

	_health_label.text = "%d HP" % int(max(current_hp, 0.0))

	# Stylized dynamic HP color
	var ratio := current_hp / max_hp if max_hp > 0.0 else 1.0
	if ratio > 0.6:
		_health_label.modulate = Color(1.0, 1.0, 1.0, 1.0)       # Crisp White
	elif ratio > 0.3:
		_health_label.modulate = Color(1.0, 0.8, 0.2, 1.0)       # Amber
	else:
		_health_label.modulate = Color(1.0, 0.25, 0.25, 1.0)     # Critical Red


## Trigger red screen damage flash
func show_damage(_info: DamageInfo, current_hp: float, max_hp: float) -> void:
	update_health(current_hp, max_hp)

	if _damage_flash == null or not is_instance_valid(_damage_flash):
		return

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_damage_flash.color = Color(0.9, 0.05, 0.05, 0.35)

	if is_inside_tree():
		_flash_tween = create_tween()
		if _flash_tween:
			_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		_damage_flash.color.a = 0.0


## Display death overlay
func show_death(killer: Node, duration: float = 2.5) -> void:
	_is_dead = true
	_respawn_time_left = duration

	if _health_label:
		_health_label.text = "0 HP"
		_health_label.modulate = Color(0.6, 0.2, 0.2, 1.0)

	if _damage_flash:
		_damage_flash.color = Color(0.6, 0.0, 0.0, 0.2)

	if _death_overlay:
		_death_overlay.visible = true
		_death_overlay.modulate.a = 0.0
		if is_inside_tree():
			var tween := create_tween()
			if tween:
				tween.tween_property(_death_overlay, "modulate:a", 1.0, 0.25)
		else:
			_death_overlay.modulate.a = 1.0

	if _death_killer:
		var killer_name : String = str(killer.name) if killer else "World"
		_death_killer.text = "Killed by %s" % killer_name

	if _respawn_timer_lbl:
		_respawn_timer_lbl.text = "Respawning in %.1fs..." % duration


## Restore HUD after respawn
func hide_death() -> void:
	_is_dead = false
	_respawn_time_left = 0.0

	if _death_overlay:
		_death_overlay.visible = false
		_death_overlay.modulate.a = 0.0

	if _damage_flash:
		_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)

	update_health(100.0, 100.0)
