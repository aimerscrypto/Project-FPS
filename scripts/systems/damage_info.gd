extends RefCounted
class_name DamageInfo

# =============================================================================
# Project FPS — DamageInfo
# Milestone 3 — Combat Loop
#
# Encapsulates damage data passed between attackers, weapons, and targets.
# =============================================================================

enum HitType {
	BODY,
	HEAD,
	LIMB
}

var amount              : float   = 0.0
var attacker            : Node    = null
var hit_position        : Vector3 = Vector3.ZERO
var hit_normal          : Vector3 = Vector3.ZERO
var hit_direction       : Vector3 = Vector3.ZERO
var hit_type            : HitType = HitType.BODY
var headshot_multiplier : float   = 2.0


## Calculates final damage considering hit type and multipliers.
func get_final_damage() -> float:
	if hit_type == HitType.HEAD:
		return amount * headshot_multiplier
	return amount
