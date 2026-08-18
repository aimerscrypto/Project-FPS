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
	# Player
	"footstep": "res://assets/audio/player/footstep.wav",
	"jump": "res://assets/audio/player/jump.wav",
	"land": "res://assets/audio/player/land.wav",
	"slide": "res://assets/audio/player/slide.wav",
	"player_damage": "res://assets/audio/player/player_damage.wav",
	"player_death": "res://assets/audio/player/player_death.wav",
	"respawn": "res://assets/audio/player/respawn.wav",
	# Combat & Bots
	"bot_fire": "res://assets/audio/combat/bot_fire.wav",
	"impact": "res://assets/audio/combat/impact.wav",
	"bot_damage": "res://assets/audio/combat/bot_damage.wav",
	"bot_death": "res://assets/audio/combat/bot_death.wav",
	# UI
	"hitmarker": "res://assets/audio/ui/hitmarker.wav",
	"headshot": "res://assets/audio/ui/headshot.wav",
	"kill_confirm": "res://assets/audio/ui/kill_confirm.wav",
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
				push_warning("AudioManager: Resource at '%s' is not an AudioStream." % path)
		else:
			push_warning("AudioManager: Audio asset missing at '%s'." % path)


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
