extends Resource

# =============================================================================
# Project FPS — WeaponData
# Milestone 2 — First Weapon
#
# A data-only Resource that defines a weapon's properties.
# All tunable stats live here — not in the weapon script.
# Create one .tres file per weapon type.
# =============================================================================

class_name WeaponData

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

# --- Accuracy ---
@export var spread_degrees : float = 0.5   # max cone half-angle in degrees (0 = perfect)
@export var range_meters   : float = 100.0 # hitscan maximum range

# --- Recoil (applied to camera on each shot) ---
@export var recoil_vertical   : float = 0.4   # degrees upward kick per shot
@export var recoil_horizontal : float = 0.15  # max random horizontal degrees per shot
@export var recoil_recovery   : float = 8.0   # degrees/second recovery toward rest
