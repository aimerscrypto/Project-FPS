extends Node

# =============================================================================
# Project FPS — AudioManager
# Modular First-Pass Audio System Autoload
#
# Provides:
# - Low-latency 2D (stereo/non-positional) sound playback for player & UI
# - Spatialized 3D sound playback with attenuation for world & bot audio
# - Fixed ring-buffer audio player pooling (zero GC / zero runtime node creation)
# - Subtly randomized pitch variation
# - Preloaded catalog of core FPS sound assets with graceful fallback
# =============================================================================

# Audio bus names
const BUS_MASTER   : StringName = &"Master"
const BUS_SFX      : StringName = &"SFX"
const BUS_UI       : StringName = &"UI"
const BUS_AMBIENCE : StringName = &"Ambience"

# Pool sizes
const POOL_3D_SIZE : int = 12
const POOL_2D_SIZE : int = 8

# Sound library paths
const SOUND_PATHS : Dictionary = {
	# Weapons
	"ar_fire": "res://assets/audio/weapons/ar_fire.wav",
	"ar_dryfire": "res://assets/audio/weapons/ar_dryfire.wav",
	"ar_reload": "res://assets/audio/weapons/ar_reload.wav",
	"pistol_fire": "res://assets/audio/weapons/pistol_fire.wav",
	"pistol_dryfire": "res://assets/audio/weapons/pistol_dryfire.wav",
	"pistol_reload": "res://assets/audio/weapons/pistol_reload.wav",
	"smg_fire": "res://assets/audio/weapons/smg_fire.wav",
	"shotgun_fire": "res://assets/audio/weapons/shotgun_fire.wav",
	"shotgun_pump": "res://assets/audio/weapons/shotgun_pump.wav",
	"shotgun_dryfire": "res://assets/audio/weapons/shotgun_dryfire.wav",
	"shotgun_reload": "res://assets/audio/weapons/shotgun_reload.wav",
	"sniper_fire": "res://assets/audio/weapons/sniper_fire.wav",
	"sniper_bolt": "res://assets/audio/weapons/sniper_bolt.wav",
	"sniper_dryfire": "res://assets/audio/weapons/sniper_dryfire.wav",
	"sniper_reload": "res://assets/audio/weapons/sniper_reload.wav",
	# Player & Movement
	"footstep": "res://assets/audio/player/footstep.wav",
	"footstep_walk": "res://assets/audio/player/footstep_walk.wav",
	"footstep_sprint": "res://assets/audio/player/footstep_sprint.wav",
	"footstep_crouch": "res://assets/audio/player/footstep_crouch.wav",
	"jump": "res://assets/audio/player/jump.wav",
	"jump_launch": "res://assets/audio/player/jump_launch.wav",
	"land": "res://assets/audio/player/land.wav",
	"land_impact": "res://assets/audio/player/land_impact.wav",
	"slide": "res://assets/audio/player/slide.wav",
	"player_damage": "res://assets/audio/player/player_damage.wav",
	"player_death": "res://assets/audio/player/player_death.wav",
	"respawn": "res://assets/audio/player/respawn.wav",
	# Combat & Bots
	"bot_fire": "res://assets/audio/combat/bot_fire.wav",
	"impact": "res://assets/audio/combat/impact.wav",
	"bot_damage": "res://assets/audio/combat/bot_damage.wav",
	"bot_death": "res://assets/audio/combat/bot_death.wav",
	# Pickups & Accolades
	"pickup_health": "res://assets/audio/gameplay/pickup_health.wav",
	"pickup_ammo": "res://assets/audio/gameplay/pickup_ammo.wav",
	"accolade_streak": "res://assets/audio/ui/accolade_streak.wav",
	"accolade_multikill": "res://assets/audio/ui/accolade_multikill.wav",
	"staging_tick": "res://assets/audio/ui/staging_tick.wav",
	"staging_go": "res://assets/audio/ui/staging_go.wav",
	# UI
	"hitmarker": "res://assets/audio/ui/hitmarker.wav",
	"headshot": "res://assets/audio/ui/headshot.wav",
	"kill_confirm": "res://assets/audio/ui/kill_confirm.wav",
	"ui_click": "res://assets/audio/ui/ui_click.wav",
	"ui_pause": "res://assets/audio/ui/ui_pause.wav",
	# Environment
	"arena_ambient": "res://assets/audio/environment/arena_ambient.wav",
}

# Preloaded AudioStream cache
var _streams : Dictionary = {}

# Reusable audio player pools
var _pool_3d : Array[AudioStreamPlayer3D] = []
var _pool_3d_index : int = 0

var _pool_2d : Array[AudioStreamPlayer] = []
var _pool_2d_index : int = 0

# Dedicated ambient audio player
var _ambient_player : AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_preload_audio_streams()
	_initialize_player_pools()


# =============================================================================
# BUS VERIFICATION & INITIALIZATION
# =============================================================================
func _ensure_audio_buses() -> void:
	var required_buses : Array[StringName] = [BUS_SFX, BUS_UI, BUS_AMBIENCE]
	for bus_name in required_buses:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)


# =============================================================================
# ASSET PRELOADING
# =============================================================================
func _preload_audio_streams() -> void:
	for sound_key in SOUND_PATHS:
		var path : String = SOUND_PATHS[sound_key]
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream is AudioStream:
				_streams[sound_key] = stream
			else:
				_streams[sound_key] = _generate_synthetic_sound(sound_key)
		else:
			# Automatically synthesize missing sound effect cleanly
			_streams[sound_key] = _generate_synthetic_sound(sound_key)


func _generate_synthetic_sound(key: String) -> AudioStreamWAV:
	var rate := 22050
	var samples := PackedFloat32Array()

	match key:
		"staging_tick":
			var count : int = int(rate * 0.08) # 80ms
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				samples[i] = sin(t * TAU * 880.0) * env * 0.6
		"staging_go":
			var count : int = int(rate * 0.40) # 400ms
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 0.6)
				var s : float = sin(t * TAU * 1760.0) * 0.5 + sin(t * TAU * 880.0) * 0.4
				samples[i] = s * env * 0.7
		"pickup_health":
			var count : int = int(rate * 0.28) # 280ms upward chime
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = sin((float(i) / float(count)) * PI)
				var freq : float = 523.25 + (float(i) / float(count)) * 523.25 # C5 to C6
				samples[i] = (sin(t * TAU * freq) * 0.6 + sin(t * TAU * freq * 2.0) * 0.2) * env * 0.7
		"pickup_ammo":
			var count : int = int(rate * 0.22) # 220ms metallic rack
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				var noise : float = randf_range(-0.3, 0.3)
				var tone : float = sin(t * TAU * 600.0) * 0.4 + sin(t * TAU * 1200.0) * 0.3
				samples[i] = (tone + noise) * env * 0.65
		"smg_fire":
			var count : int = int(rate * 0.10) # 100ms snappy pop
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 3.0)
				var noise : float = randf_range(-0.5, 0.5)
				var punch : float = sin(t * TAU * (220.0 * (1.0 - t * 6.0))) * 0.6
				samples[i] = (punch + noise) * env * 0.8
		"accolade_streak":
			var count : int = int(rate * 0.55) # 550ms triumphant chord
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 0.8)
				var c : float = sin(t * TAU * 523.25) * 0.35 + sin(t * TAU * 659.25) * 0.35 + sin(t * TAU * 783.99) * 0.30
				samples[i] = c * env * 0.75
		"accolade_multikill":
			var count : int = int(rate * 0.45) # 450ms energetic fanfare
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 0.7)
				var c : float = sin(t * TAU * 587.33) * 0.35 + sin(t * TAU * 739.99) * 0.35 + sin(t * TAU * 880.00) * 0.30
				samples[i] = c * env * 0.75
		"footstep_walk", "footstep":
			var count : int = int(rate * 0.06) # 60ms subtle grounded thump
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 2.0)
				var noise : float = randf_range(-0.25, 0.25)
				var thump : float = sin(t * TAU * 120.0) * 0.5
				samples[i] = (thump + noise) * env * 0.45
		"footstep_sprint":
			var count : int = int(rate * 0.05) # 50ms snappier sprint step
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 2.5)
				var noise : float = randf_range(-0.35, 0.35)
				var thump : float = sin(t * TAU * 150.0) * 0.6
				samples[i] = (thump + noise) * env * 0.65
		"footstep_crouch":
			var count : int = int(rate * 0.07) # 70ms very quiet muffled step
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				var thump : float = sin(t * TAU * 90.0) * 0.25
				samples[i] = thump * env * 0.25
		"jump_launch", "jump":
			var count : int = int(rate * 0.09) # 90ms whoosh / rise
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = sin((float(i) / float(count)) * PI)
				var freq : float = 110.0 + (float(i) / float(count)) * 260.0
				samples[i] = sin(t * TAU * freq) * env * 0.5
		"land_impact", "land":
			var count : int = int(rate * 0.12) # 120ms deep impact thud
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 2.0)
				var noise : float = randf_range(-0.3, 0.3)
				var punch : float = sin(t * TAU * (85.0 * (1.0 - t * 4.0))) * 0.7
				samples[i] = (punch + noise) * env * 0.7
		"shotgun_fire":
			var count : int = int(rate * 0.22) # 220ms heavy explosive burst
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 2.5)
				var noise : float = randf_range(-0.7, 0.7)
				var sub : float = sin(t * TAU * (80.0 * (1.0 - t * 3.0))) * 0.8
				samples[i] = (sub + noise) * env * 0.9
		"shotgun_pump":
			var count : int = int(rate * 0.18) # 180ms slide mechanical clack
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				var c1 : float = sin(t * TAU * 950.0) if (t < 0.05) else 0.0
				var c2 : float = sin(t * TAU * 1250.0) if (t > 0.09 and t < 0.15) else 0.0
				samples[i] = (c1 + c2) * env * 0.6
		"shotgun_dryfire", "shotgun_reload":
			var count : int = int(rate * 0.08)
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				samples[i] = sin(t * TAU * 1100.0) * env * 0.5
		"sniper_fire":
			var count : int = int(rate * 0.32) # 320ms powerful high-caliber crack and boom
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = pow(1.0 - (float(i) / float(count)), 2.0)
				var crack : float = randf_range(-0.8, 0.8) if (t < 0.06) else 0.0
				var boom : float = sin(t * TAU * (65.0 * (1.0 - t * 2.0))) * 0.85
				samples[i] = (crack + boom) * env * 0.95
		"sniper_bolt":
			var count : int = int(rate * 0.24) # 240ms bolt open-and-close rack
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				var r1 : float = sin(t * TAU * 800.0) if (t < 0.07) else 0.0
				var r2 : float = sin(t * TAU * 1400.0) if (t > 0.12 and t < 0.20) else 0.0
				samples[i] = (r1 + r2) * env * 0.65
		"sniper_dryfire", "sniper_reload":
			var count : int = int(rate * 0.09)
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				samples[i] = sin(t * TAU * 900.0) * env * 0.55
		"ui_click":
			var count : int = int(rate * 0.03) # 30ms click
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				samples[i] = sin(t * TAU * 1200.0) * env * 0.5
		"ui_pause":
			var count : int = int(rate * 0.16) # 160ms soft descending
			samples.resize(count)
			for i in range(count):
				var t : float = float(i) / float(rate)
				var env : float = 1.0 - (float(i) / float(count))
				var freq : float = 800.0 - (float(i) / float(count)) * 300.0
				samples[i] = sin(t * TAU * freq) * env * 0.4
		_:
			var count : int = int(rate * 0.05)
			samples.resize(count)
			for i in range(count):
				samples[i] = 0.0

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	var byte_array := PackedByteArray()
	byte_array.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val : int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		byte_array.encode_s16(i * 2, val)
	wav.data = byte_array
	return wav


# =============================================================================
# POOL INITIALIZATION
# =============================================================================
func _initialize_player_pools() -> void:
	# 3D Positional Pool
	for i in range(POOL_3D_SIZE):
		var p3d := AudioStreamPlayer3D.new()
		p3d.name = "PoolPlayer3D_%d" % i
		p3d.bus = BUS_SFX
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3d.unit_size = 5.0
		p3d.max_distance = 50.0
		p3d.max_db = 3.0
		p3d.panning_strength = 1.0
		p3d.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p3d)
		_pool_3d.append(p3d)

	# 2D Non-Positional Pool
	for i in range(POOL_2D_SIZE):
		var p2d := AudioStreamPlayer.new()
		p2d.name = "PoolPlayer2D_%d" % i
		p2d.bus = BUS_SFX
		add_child(p2d)
		_pool_2d.append(p2d)


# =============================================================================
# STREAM RESOLVER HELPER
# =============================================================================
func get_stream(sound_key_or_stream: Variant) -> AudioStream:
	if sound_key_or_stream == null:
		return null
	if sound_key_or_stream is AudioStream:
		return sound_key_or_stream
	if sound_key_or_stream is String or sound_key_or_stream is StringName:
		var key := str(sound_key_or_stream)
		if _streams.has(key):
			return _streams[key]
		# Check if direct file path was supplied
		if ResourceLoader.exists(key):
			var loaded = load(key)
			if loaded is AudioStream:
				_streams[key] = loaded
				return loaded
	return null


# =============================================================================
# PUBLIC PLAYBACK APIS
# =============================================================================

## Plays a 2D non-positional stereo sound (Player weapon, movement, damage, UI).
## sound_key_or_stream: key string (e.g. "ar_fire") or AudioStream resource
## bus: Audio bus name ("SFX", "UI", "Ambience", "Master")
## volume_db: Volume adjustment in decibels
## pitch_random: Range of random pitch offset [1.0 - pitch_random, 1.0 + pitch_random]
func play_2d(
	sound_key_or_stream: Variant,
	bus: StringName = BUS_SFX,
	volume_db: float = 0.0,
	pitch_random: float = 0.0
) -> AudioStreamPlayer:
	var stream := get_stream(sound_key_or_stream)
	if stream == null:
		return null

	if _pool_2d.is_empty():
		return null

	# Round-robin selection
	var player := _pool_2d[_pool_2d_index]
	_pool_2d_index = (_pool_2d_index + 1) % _pool_2d.size()

	player.stop()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db

	if pitch_random > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_random, pitch_random)
	else:
		player.pitch_scale = 1.0

	player.play()
	return player


## Plays a 3D spatialized sound at a world position (Bot weapons, impacts, world events).
## sound_key_or_stream: key string (e.g. "bot_fire") or AudioStream resource
## global_pos: 3D world position
## bus: Audio bus name
## volume_db: Volume adjustment in decibels
## pitch_random: Range of random pitch offset
## max_distance: Distance in meters where sound becomes inaudible
## unit_size: Distance in meters for 0dB nominal level
func play_3d(
	sound_key_or_stream: Variant,
	global_pos: Vector3,
	bus: StringName = BUS_SFX,
	volume_db: float = 0.0,
	pitch_random: float = 0.0,
	max_distance: float = 50.0,
	unit_size: float = 5.0
) -> AudioStreamPlayer3D:
	var stream := get_stream(sound_key_or_stream)
	if stream == null:
		return null

	if _pool_3d.is_empty():
		return null

	# Round-robin selection
	var player := _pool_3d[_pool_3d_index]
	_pool_3d_index = (_pool_3d_index + 1) % _pool_3d.size()

	player.stop()
	player.global_position = global_pos
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = unit_size

	if pitch_random > 0.0:
		player.pitch_scale = 1.0 + randf_range(-pitch_random, pitch_random)
	else:
		player.pitch_scale = 1.0

	player.play()
	return player


## Helper to trigger a crisp hitmarker sound (UI bus, zero/subtle pitch randomization).
func play_hitmarker(is_headshot: bool = false) -> void:
	if is_headshot:
		play_2d("headshot", BUS_UI, 1.0, 0.0)
	else:
		play_2d("hitmarker", BUS_UI, 0.0, 0.0)


## Helper to trigger a satisfying kill confirmation sound (UI bus).
func play_kill_confirm(is_headshot: bool = false) -> void:
	if is_headshot:
		play_2d("headshot", BUS_UI, 1.5, 0.0)
		play_2d("kill_confirm", BUS_UI, 2.0, 0.0)
	else:
		play_2d("kill_confirm", BUS_UI, 1.5, 0.0)


## Helper to trigger a tactical respawn sound cue.
func play_respawn() -> void:
	play_2d("respawn", BUS_SFX, 0.0, 0.0)


## Helper to trigger staging countdown tick blip.
func play_staging_tick() -> void:
	play_2d("staging_tick", BUS_UI, 2.0, 0.0)


## Helper to trigger staging fight start horn.
func play_staging_go() -> void:
	play_2d("staging_go", BUS_UI, 3.0, 0.0)


## Helper to trigger pickup collection audio.
func play_pickup(pickup_type: String = "health") -> void:
	if pickup_type == "health":
		play_2d("pickup_health", BUS_SFX, 1.0, 0.02)
	else:
		play_2d("pickup_ammo", BUS_SFX, 1.0, 0.02)


## Helper to trigger accolade stinger audio.
func play_accolade(is_multikill: bool = false) -> void:
	if is_multikill:
		play_2d("accolade_multikill", BUS_UI, 2.5, 0.0)
	else:
		play_2d("accolade_streak", BUS_UI, 2.5, 0.0)


## Helper to trigger UI click sound.
func play_ui_click() -> void:
	play_2d("ui_click", BUS_UI, -1.0, 0.04)


## Helper to trigger UI pause sound.
func play_ui_pause() -> void:
	play_2d("ui_pause", BUS_UI, 0.0, 0.0)


## Starts looping ambient background audio on the Ambience bus.
func play_ambient(sound_key_or_stream: Variant = "arena_ambient", volume_db: float = -8.0) -> AudioStreamPlayer:
	var stream := get_stream(sound_key_or_stream)
	if stream == null:
		return null

	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.name = "AmbientPlayer"
		_ambient_player.bus = BUS_AMBIENCE
		add_child(_ambient_player)

	_ambient_player.stream = stream
	_ambient_player.volume_db = volume_db
	if not _ambient_player.playing:
		_ambient_player.play()

	return _ambient_player


## Stops ambient background audio.
func stop_ambient() -> void:
	if _ambient_player and _ambient_player.playing:
		_ambient_player.stop()
