extends "res://scripts/Hero.gd"

# ============================================================
# Freyja.gd — Goddess of Love & War
# SPECIAL: VALKYRIE SURGE  (Cooldown: 8s)
# Fires 8 projectiles in a 360° radial burst AND heals 5 HP.
# ============================================================

func _ready():
	super()
	hero_name            = "Freyja"
	max_health           = 90
	current_health       = max_health
	move_speed           = 120.0
	base_damage          = 9
	fire_rate            = 0.34
	special_cooldown_max = 8.0

func _special_ability():
	print("[Freyja] VALKYRIE SURGE — radial burst!")
	heal(5)
	for i in range(8):
		var angle = (TAU / 8.0) * i
		_fire_projectile(Vector2(cos(angle), sin(angle)))
