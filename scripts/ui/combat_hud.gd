extends CanvasLayer
class_name CombatHUD

# =============================================================================
# Project FPS — Combat HUD
# Milestone 8 — Complete FFA Match Loop & Match HUD
# Milestone 11 — Player Feedback, Polish & Gameplay Juice
#
# Complete, lightweight 2D match and combat readability HUD providing:
# - Bottom-left Player Health bar with trailing chip damage and dynamic HP readout
# - Bottom-right Weapon Ammo counter ("30 / 120")
# - Top-center Match Timer ("MM:SS") & Score Tracker ("YOU X  LEADER Y")
# - Top-right Kill Feed (recent eliminations with auto-fade)
# - Retriggerable smooth screen-space damage vignette & perimeter flash
# - Directional damage indicators showing approximate attacker bearing
# - Low-health pulsing visual warning
# - Responsive "YOU DIED" death overlay with killer info and respawn timer
# - End-of-Match Results Screen with Victory/Defeat banner, full 8-player
#   scoreboard, mouse release, and instant replay action.
# =============================================================================

# -----------------------------------------------------------------------------
# NODE REFERENCES
# -----------------------------------------------------------------------------
@onready var _health_label      : Label          = $HealthDisplay/HealthLabel
@onready var _health_bar        : ColorRect      = $HealthDisplay/HealthBar
@onready var _damage_trail_bar  : ColorRect      = $HealthDisplay/DamageTrailBar
@onready var _damage_flash      : ColorRect      = $DamageFlash
@onready var _damage_vignette   : TextureRect    = $DamageVignette
@onready var _low_hp_vignette   : TextureRect    = $LowHealthVignette
@onready var _directional_damage: Control        = $DirectionalDamage
@onready var _ammo_label        : Label          = $AmmoDisplay/AmmoLabel
@onready var _timer_label       : Label          = $MatchHeader/HeaderVBox/TimerLabel
@onready var _score_label       : Label          = $MatchHeader/HeaderVBox/ScoreLabel
@onready var _kill_feed         : VBoxContainer  = $KillFeed

# Death Overlay
@onready var _death_overlay     : Control        = $DeathOverlay
@onready var _death_killer      : Label          = $DeathOverlay/CenterBox/KillerLabel
@onready var _respawn_timer_lbl : Label          = $DeathOverlay/CenterBox/RespawnTimerLabel

# Results Overlay
@onready var _results_overlay   : Control        = $ResultsOverlay
@onready var _result_title      : Label          = $ResultsOverlay/CenterBox/ResultTitle
@onready var _winner_label      : Label          = $ResultsOverlay/CenterBox/WinnerLabel
@onready var _rows_container    : VBoxContainer  = $ResultsOverlay/CenterBox/ScoreboardContainer/RowsContainer
@onready var _play_again_btn    : Button         = $ResultsOverlay/CenterBox/PlayAgainButton

# -----------------------------------------------------------------------------
# CONSTANTS & CONFIGURATION
# -----------------------------------------------------------------------------
const HEALTH_BAR_MAX_WIDTH : float = 194.0
const NUM_DIR_INDICATORS   : int   = 8

# -----------------------------------------------------------------------------
# STATE
# -----------------------------------------------------------------------------
var _flash_tween           : Tween        = null
var _vignette_tween        : Tween        = null
var _low_hp_tween          : Tween        = null
var _trail_tween           : Tween        = null
var _is_low_health_pulsing : bool         = false
var _respawn_time_left     : float        = 0.0
var _is_dead               : bool         = false
var _is_results_shown      : bool         = false
var _match_mgr             : MatchManager = null
var _player_node           : Node         = null
var _player_score          : int          = 0
var _leader_score          : int          = 0

# Directional indicators pool
var _dir_indicators        : Array[Control] = []
var _dir_indicator_index   : int            = 0


# =============================================================================
# INITIALIZATION & SETUP
# =============================================================================
func _ready() -> void:
	if _damage_flash:
		_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
		_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _damage_vignette:
		_damage_vignette.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _low_hp_vignette:
		_low_hp_vignette.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_low_hp_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _death_overlay:
		_death_overlay.visible = false
		_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _results_overlay:
		_results_overlay.visible = false

	_init_directional_indicators()

	if _play_again_btn:
		_play_again_btn.pressed.connect(restart_match)

	update_health(100.0, 100.0)
	update_ammo(30, 120)
	update_timer(300.0)
	update_score(0, 0)

	# Auto-discover MatchManager if in scene tree
	var tree := get_tree()
	if tree and _match_mgr == null:
		var mgr = tree.get_first_node_in_group("match_manager")
		if mgr is MatchManager:
			setup_match_manager(mgr, _player_node)


func _init_directional_indicators() -> void:
	if _directional_damage == null or not is_instance_valid(_directional_damage):
		return
	_dir_indicators.clear()
	for i in range(NUM_DIR_INDICATORS):
		var pivot := Control.new()
		pivot.name = "DirPivot_%d" % i
		pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot.position = Vector2.ZERO
		pivot.size = Vector2.ZERO
		pivot.modulate.a = 0.0

		# Stylized curved chevron / arrowhead pointing outward at 115px radius
		var wedge := Polygon2D.new()
		wedge.name = "Wedge"
		wedge.polygon = PackedVector2Array([
			Vector2(0, -126),
			Vector2(13, -108),
			Vector2(0, -114),
			Vector2(-13, -108)
		])
		wedge.color = Color(1.0, 0.18, 0.18, 0.95)
		pivot.add_child(wedge)

		_directional_damage.add_child(pivot)
		_dir_indicators.append(pivot)


## Connects the HUD to the MatchManager and identifies the local player node.
func setup_match_manager(match_mgr: MatchManager, player: Node) -> void:
	if match_mgr == null:
		return

	_match_mgr = match_mgr
	if player != null:
		_player_node = player

	# Connect signals safely without duplicating connections
	if not _match_mgr.timer_updated.is_connected(_on_timer_updated):
		_match_mgr.timer_updated.connect(_on_timer_updated)
	if not _match_mgr.score_updated.is_connected(_on_score_updated):
		_match_mgr.score_updated.connect(_on_score_updated)
	if not _match_mgr.kill_recorded.is_connected(_on_kill_recorded):
		_match_mgr.kill_recorded.connect(_on_kill_recorded)
	if not _match_mgr.match_ended.is_connected(_on_match_ended):
		_match_mgr.match_ended.connect(_on_match_ended)

	# Initial values
	_leader_score = _match_mgr.get_leading_score()
	if _player_node:
		var stats := _match_mgr.get_combatant_stats(_player_node)
		_player_score = stats.get("score", 0)
	update_score(_player_score, _leader_score)
	update_timer(_match_mgr.time_remaining)


# =============================================================================
# INPUT & PROCESS
# =============================================================================
func _process(delta: float) -> void:
	if _is_dead and not _is_results_shown and _respawn_time_left > 0.0:
		_respawn_time_left -= delta
		if _respawn_timer_lbl:
			_respawn_timer_lbl.text = "Respawning in %.1fs..." % max(_respawn_time_left, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _is_results_shown:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
			get_viewport().set_input_as_handled()
			restart_match()


## Reloads current arena scene for a clean instant restart.
func restart_match() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


# =============================================================================
# HEALTH & DAMAGE PRESENTATION
# =============================================================================

## Updates current HP label, health bar width, and dynamic state colors.
func update_health(current_hp: float, max_hp: float) -> void:
	var safe_current : float = max(current_hp, 0.0)
	var ratio : float = clampf(safe_current / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	var target_w : float = HEALTH_BAR_MAX_WIDTH * ratio

	if _health_label and is_instance_valid(_health_label):
		_health_label.text = "%d HP" % int(ceil(safe_current))

	if _health_bar and is_instance_valid(_health_bar):
		_health_bar.size.x = target_w
		if ratio > 0.6:
			_health_bar.color = Color(0.2, 0.85, 0.4, 0.85)     # Crisp Green
			if _health_label: _health_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif ratio > 0.3:
			_health_bar.color = Color(1.0, 0.75, 0.2, 0.85)     # Amber Warning
			if _health_label: _health_label.modulate = Color(1.0, 0.85, 0.3, 1.0)
		else:
			_health_bar.color = Color(1.0, 0.2, 0.2, 0.9)       # Critical Red
			if _health_label: _health_label.modulate = Color(1.0, 0.25, 0.25, 1.0)

	# Damage trailing chip bar animation
	if _damage_trail_bar and is_instance_valid(_damage_trail_bar):
		if _trail_tween and _trail_tween.is_valid():
			_trail_tween.kill()
		if safe_current >= max_hp or safe_current <= 0.0:
			_damage_trail_bar.size.x = target_w
		elif is_inside_tree():
			_trail_tween = create_tween()
			_trail_tween.tween_interval(0.12)
			_trail_tween.tween_property(_damage_trail_bar, "size:x", target_w, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		else:
			_damage_trail_bar.size.x = target_w

	# Low Health Warning state
	if ratio <= 0.3 and not _is_dead and not _is_results_shown and safe_current > 0.0:
		_start_low_health_warning()
	else:
		_stop_low_health_warning()


func _start_low_health_warning() -> void:
	if _is_low_health_pulsing:
		return
	_is_low_health_pulsing = true
	if _low_hp_vignette and is_inside_tree():
		if _low_hp_tween and _low_hp_tween.is_valid():
			_low_hp_tween.kill()
		_low_hp_tween = create_tween().set_loops()
		_low_hp_tween.tween_property(_low_hp_vignette, "modulate:a", 0.60, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_low_hp_tween.tween_property(_low_hp_vignette, "modulate:a", 0.15, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_low_health_warning() -> void:
	_is_low_health_pulsing = false
	if _low_hp_tween and _low_hp_tween.is_valid():
		_low_hp_tween.kill()
	if _low_hp_vignette and is_instance_valid(_low_hp_vignette):
		_low_hp_vignette.modulate.a = 0.0


## Trigger screen damage vignette, perimeter flash, and optional directional indicator.
func show_damage(_info: DamageInfo, current_hp: float, max_hp: float, rel_angle: float = 0.0, has_direction: bool = false) -> void:
	update_health(current_hp, max_hp)

	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()

	if _damage_vignette and is_instance_valid(_damage_vignette):
		_damage_vignette.modulate.a = 0.85
	if _damage_flash and is_instance_valid(_damage_flash):
		_damage_flash.color = Color(0.9, 0.05, 0.05, 0.25)

	if is_inside_tree():
		_vignette_tween = create_tween().set_parallel(true)
		if _damage_vignette and is_instance_valid(_damage_vignette):
			_vignette_tween.tween_property(_damage_vignette, "modulate:a", 0.0, 0.40).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		if _damage_flash and is_instance_valid(_damage_flash):
			_vignette_tween.tween_property(_damage_flash, "color:a", 0.0, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		if _damage_vignette and is_instance_valid(_damage_vignette):
			_damage_vignette.modulate.a = 0.0
		if _damage_flash and is_instance_valid(_damage_flash):
			_damage_flash.color.a = 0.0

	if has_direction:
		show_directional_damage(rel_angle)


## Displays a radial directional damage indicator rotated to rel_angle.
func show_directional_damage(rel_angle: float) -> void:
	if _dir_indicators.is_empty():
		return

	var pivot := _dir_indicators[_dir_indicator_index]
	_dir_indicator_index = (_dir_indicator_index + 1) % _dir_indicators.size()

	pivot.rotation = rel_angle
	pivot.modulate.a = 1.0

	if is_inside_tree():
		var tween := pivot.create_tween()
		tween.tween_property(pivot, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		pivot.modulate.a = 0.0


## Display death overlay with killer name and duration countdown.
func show_death(killer: Node, duration: float = 2.5) -> void:
	if _is_results_shown:
		return

	_is_dead = true
	_respawn_time_left = duration
	_stop_low_health_warning()

	if _health_label:
		_health_label.text = "0 HP"
		_health_label.modulate = Color(0.7, 0.2, 0.2, 1.0)

	if _health_bar:
		_health_bar.size.x = 0.0

	if _damage_trail_bar:
		_damage_trail_bar.size.x = 0.0

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
		var killer_name := _get_combatant_name(killer)
		_death_killer.text = "Killed by %s" % killer_name

	if _respawn_timer_lbl:
		_respawn_timer_lbl.text = "Respawning in %.1fs..." % duration


## Restore HUD after respawn.
func hide_death() -> void:
	_is_dead = false
	_respawn_time_left = 0.0
	_stop_low_health_warning()

	if _death_overlay:
		_death_overlay.visible = false
		_death_overlay.modulate.a = 0.0

	if _damage_flash:
		_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)

	if _damage_vignette:
		_damage_vignette.modulate.a = 0.0

	update_health(100.0, 100.0)


# Spawn Protection Indicator
var _shield_label : Label = null
var _shield_tween : Tween = null


## Displays temporary spawn protection badge near health bar.
func show_spawn_protection(duration: float = 1.2) -> void:
	if _shield_label == null:
		var health_disp := get_node_or_null("HealthDisplay")
		if health_disp:
			_shield_label = Label.new()
			_shield_label.name = "ShieldLabel"
			_shield_label.text = "[SHIELD]"
			_shield_label.add_theme_font_size_override("font_size", 14)
			_shield_label.modulate = Color(0.25, 0.95, 1.0, 1.0)
			_shield_label.position = Vector2(215, 6)
			health_disp.add_child(_shield_label)

	if _shield_label and is_instance_valid(_shield_label):
		_shield_label.visible = true
		_shield_label.modulate.a = 1.0
		if _shield_tween and _shield_tween.is_valid():
			_shield_tween.kill()
		if is_inside_tree():
			_shield_tween = create_tween()
			_shield_tween.tween_interval(maxf(duration - 0.3, 0.1))
			_shield_tween.tween_property(_shield_label, "modulate:a", 0.0, 0.3)
			_shield_tween.tween_callback(func(): if _shield_label: _shield_label.visible = false)


## Hides spawn protection badge immediately.
func hide_spawn_protection() -> void:
	if _shield_tween and _shield_tween.is_valid():
		_shield_tween.kill()
	if _shield_label and is_instance_valid(_shield_label):
		_shield_label.visible = false
		_shield_label.modulate.a = 0.0


# =============================================================================
# AMMO, TIMER & SCORE PRESENTATION
# =============================================================================

## Updates bottom-right ammo display ("Clip / Reserve").
func update_ammo(current_ammo: int, reserve_ammo: int) -> void:
	if _ammo_label == null or not is_instance_valid(_ammo_label):
		return

	_ammo_label.text = "%d / %d" % [current_ammo, reserve_ammo]

	if current_ammo == 0:
		_ammo_label.modulate = Color(1.0, 0.25, 0.25, 1.0) # Critical Red
	elif current_ammo <= 5:
		_ammo_label.modulate = Color(1.0, 0.8, 0.2, 1.0)   # Amber Warning
	else:
		_ammo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)   # Crisp White


## Updates top-center match countdown timer ("MM:SS").
func update_timer(time_remaining: float) -> void:
	if _timer_label == null or not is_instance_valid(_timer_label):
		return

	var total_seconds := int(ceil(max(time_remaining, 0.0)))
	var minutes := int(float(total_seconds) / 60.0)
	var seconds := total_seconds % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]

	if total_seconds <= 30:
		_timer_label.modulate = Color(1.0, 0.3, 0.3, 1.0) # Warning Red
	else:
		_timer_label.modulate = Color(1.0, 1.0, 1.0, 1.0)


## Updates top-center score sub-header ("YOU X  LEADER Y").
func update_score(player_score: int, leader_score: int) -> void:
	if _score_label == null or not is_instance_valid(_score_label):
		return

	_player_score = player_score
	_leader_score = leader_score
	_score_label.text = "YOU %d    LEADER %d" % [_player_score, _leader_score]


func _on_timer_updated(time_remaining: float) -> void:
	update_timer(time_remaining)


func _on_score_updated(combatant: Node, kills: int, _deaths: int) -> void:
	if combatant == _player_node or _get_combatant_name(combatant) == "Player":
		_player_score = kills

	if _match_mgr:
		_leader_score = _match_mgr.get_leading_score()

	update_score(_player_score, _leader_score)


# =============================================================================
# KILL FEED PRESENTATION
# =============================================================================

func _on_kill_recorded(killer: Node, victim: Node, _killer_score: int) -> void:
	var killer_name := _get_combatant_name(killer)
	var victim_name := _get_combatant_name(victim)

	var is_player_killer : bool = (killer == _player_node) or (killer_name == "Player")
	var is_player_victim : bool = (victim == _player_node) or (victim_name == "Player")

	add_kill_feed_entry(killer_name, victim_name, is_player_killer, is_player_victim)


## Adds a compact elimination row to the top-right kill feed with auto-fade.
func add_kill_feed_entry(killer_name: String, victim_name: String, is_player_killer: bool, is_player_victim: bool) -> void:
	if _kill_feed == null or not is_instance_valid(_kill_feed):
		return

	var entry := HBoxContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.alignment = BoxContainer.ALIGNMENT_END
	entry.add_theme_constant_override("separation", 6)

	var killer_lbl := Label.new()
	killer_lbl.text = killer_name
	killer_lbl.add_theme_font_size_override("font_size", 14)
	if is_player_killer:
		killer_lbl.modulate = Color(0.3, 0.9, 1.0, 1.0) # Cyan highlight for player
	else:
		killer_lbl.modulate = Color(0.95, 0.65, 0.65, 1.0)
	entry.add_child(killer_lbl)

	var arrow_lbl := Label.new()
	arrow_lbl.text = "→"
	arrow_lbl.add_theme_font_size_override("font_size", 14)
	arrow_lbl.modulate = Color(0.7, 0.7, 0.75, 1.0)
	entry.add_child(arrow_lbl)

	var victim_lbl := Label.new()
	victim_lbl.text = victim_name
	victim_lbl.add_theme_font_size_override("font_size", 14)
	if is_player_victim:
		victim_lbl.modulate = Color(1.0, 0.25, 0.25, 1.0) # Red for player death
	else:
		victim_lbl.modulate = Color(0.8, 0.8, 0.85, 1.0)
	entry.add_child(victim_lbl)

	# Insert new entries at the top
	_kill_feed.add_child(entry)
	_kill_feed.move_child(entry, 0)

	# Cap at maximum 5 visible entries
	while _kill_feed.get_child_count() > 5:
		var oldest = _kill_feed.get_child(_kill_feed.get_child_count() - 1)
		oldest.queue_free()
		_kill_feed.remove_child(oldest)

	# Fade out after 3.2s, free at 3.8s
	var tween := entry.create_tween()
	tween.tween_interval(3.2)
	tween.tween_property(entry, "modulate:a", 0.0, 0.6)
	tween.tween_callback(entry.queue_free)


# =============================================================================
# RESULTS SCREEN PRESENTATION
# =============================================================================

func _on_match_ended(winner: Node) -> void:
	_is_results_shown = true
	_stop_low_health_warning()

	# Hide death overlay if active
	if _death_overlay:
		_death_overlay.visible = false

	# Release mouse capture for UI interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var winner_name := _get_combatant_name(winner)
	var is_player_winner : bool = (winner == _player_node) or (winner_name == "Player")

	# Title styling
	if _result_title:
		if is_player_winner:
			_result_title.text = "VICTORY"
			_result_title.modulate = Color(0.2, 0.95, 0.4, 1.0)
		else:
			_result_title.text = "DEFEAT"
			_result_title.modulate = Color(0.95, 0.25, 0.25, 1.0)

	# Subtitle
	var winning_score : int = 0
	if _match_mgr and winner:
		var stats := _match_mgr.get_combatant_stats(winner)
		winning_score = stats.get("score", 0)
	elif _match_mgr:
		winning_score = _match_mgr.get_leading_score()

	if _winner_label:
		_winner_label.text = "Winner: %s (Score: %d)" % [winner_name, winning_score]

	# Build Scoreboard Table
	_populate_scoreboard()

	# Display Results Overlay
	if _results_overlay:
		_results_overlay.visible = true
		_results_overlay.modulate.a = 0.0
		if is_inside_tree():
			var tween := create_tween()
			if tween:
				tween.tween_property(_results_overlay, "modulate:a", 1.0, 0.3)
		else:
			_results_overlay.modulate.a = 1.0


func _populate_scoreboard() -> void:
	if _rows_container == null or not is_instance_valid(_rows_container):
		return

	# Clear previous rows
	for child in _rows_container.get_children():
		child.queue_free()

	if _match_mgr == null:
		return

	var sorted_stats := _match_mgr.get_sorted_scoreboard()

	for i in range(sorted_stats.size()):
		var entry : Dictionary = sorted_stats[i]
		var is_player_row : bool = (entry.get("node") == _player_node) or (entry.get("name") == "Player")

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# 1. Rank
		var rank_lbl := Label.new()
		rank_lbl.custom_minimum_size = Vector2(50, 0)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.text = str(i + 1)
		rank_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(rank_lbl)

		# 2. Name
		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = entry.get("name", "Unknown") + (" (YOU)" if is_player_row else "")
		name_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(name_lbl)

		# 3. Kills
		var kills_lbl := Label.new()
		kills_lbl.custom_minimum_size = Vector2(65, 0)
		kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kills_lbl.text = str(entry.get("kills", 0))
		kills_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(kills_lbl)

		# 4. Deaths
		var deaths_lbl := Label.new()
		deaths_lbl.custom_minimum_size = Vector2(65, 0)
		deaths_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deaths_lbl.text = str(entry.get("deaths", 0))
		deaths_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(deaths_lbl)

		# 5. Score
		var score_lbl := Label.new()
		score_lbl.custom_minimum_size = Vector2(65, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_lbl.text = str(entry.get("score", 0))
		score_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(score_lbl)

		# Row highlighting
		if is_player_row:
			rank_lbl.modulate = Color(0.3, 0.9, 1.0, 1.0)
			name_lbl.modulate = Color(0.3, 0.9, 1.0, 1.0)
			kills_lbl.modulate = Color(0.3, 0.9, 1.0, 1.0)
			deaths_lbl.modulate = Color(0.3, 0.9, 1.0, 1.0)
			score_lbl.modulate = Color(0.3, 0.9, 1.0, 1.0)
		else:
			rank_lbl.modulate = Color(0.85, 0.85, 0.9, 1.0)
			name_lbl.modulate = Color(0.85, 0.85, 0.9, 1.0)
			kills_lbl.modulate = Color(0.85, 0.85, 0.9, 1.0)
			deaths_lbl.modulate = Color(0.85, 0.85, 0.9, 1.0)
			score_lbl.modulate = Color(0.85, 0.85, 0.9, 1.0)

		_rows_container.add_child(row)


# =============================================================================
# HELPERS
# =============================================================================
func _get_combatant_name(combatant: Node) -> String:
	if combatant == null:
		return "World"
	if combatant.get("combatant_name"):
		return str(combatant.get("combatant_name"))
	return str(combatant.name)
