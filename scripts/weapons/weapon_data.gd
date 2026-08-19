extends Resource
class_name WeaponData

# =============================================================================
# Project FPS — WeaponData
# Milestone 2 — First Weapon
#
# A data-only Resource that defines a weapon's properties.
# All tunable stats live here — not in the weapon script.
# Create one .tres file per weapon type.
# =============================================================================

# --- Identity ---
@export var weapon_name    : String = "Unnamed Weapon"

# --- Damage ---
@export var damage              : float = 25.0    # body shot damage
@export var headshot_multiplier : float = 2.0     # multiplied when hitting "head" group

# --- Fire ---
@export var fire_rate      : float = 10.0  # rounds per second (10 = 0.1s between shots)
@export var is_automatic   : bool  = true  # hold to fire?

# --- Ammo ---
@export var magazine_size  : int   = 30    # rounds in one magazine
@export var reserve_ammo   : int   = 120   # total spare rounds (not counting current mag)

# --- Reload ---
@export var reload_time    : float = 2.0   # seconds to reload

# --- Accuracy & Pellets ---
@export var spread_degrees     : float = 0.5   # max cone half-angle in degrees (0 = perfect)
@export var ads_spread_degrees : float = 0.1   # spread while aiming down sights
@export var range_meters       : float = 100.0 # hitscan maximum range
@export var pellet_count       : int   = 1     # number of hitscan pellets per shot (e.g. 8 for shotgun)

# --- Recoil (applied to camera on each shot) ---
@export var recoil_vertical   : float = 1.05  # degrees upward kick per shot
@export var recoil_horizontal : float = 0.35  # max random horizontal degrees per shot
@export var recoil_recovery   : float = 4.5   # degrees/second recovery toward rest

# --- Audio Keys (AudioManager lookup) ---
@export var fire_sound    : String = "ar_fire"
@export var dryfire_sound : String = "ar_dryfire"
@export var reload_sound  : String = "ar_reload"

# --- Presentation & FX Profiles ---
@export var casing_type    : String = "rifle"   # "rifle", "pistol", or "shotgun"
@export var reload_profile : String = "rifle"   # "rifle", "pistol", "shotgun", or "sniper"
@export var is_sniper      : bool   = false
@export var tracer_color   : Color  = Color(1.0, 0.85, 0.3, 0.9)
@export var tracer_speed   : float  = 260.0
