extends "res://scripts/Hero.gd"

# ============================================================
# Hel.gd — Goddess of Death
# SPECIAL: DEATH SHROUD  (Cooldown: 9s)
# Goes intangible for 2s (full invincibility, ghostly flicker,
# enemies lose target). Erupts with 12 radial shots on exit.
# PASSIVE: below 50% HP, 20% chance to dodge any hit.
# ============================================================

var _shroud_active: bool  = false
var _shroud_timer:  float = 0.0
const SHROUD_DURATION := 2.0

func _ready():
	super()
	hero_name            = "Hel"
	max_health           = 75
	current_health       = max_health
	move_speed           = 112.0
	base_damage          = 10
	fire_rate            = 0.36
	special_cooldown_max = 9.0

func _physics_process(delta: float):
	super(delta)
	if _shroud_active:
		_shroud_timer -= delta
		if sprite:
			sprite.modulate.a = 0.28 + sin(Time.get_ticks_msec() * 0.022) * 0.18
		if _shroud_timer <= 0: _end_shroud()

func _special_ability():
	print("[Hel] DEATH SHROUD!")
	_shroud_active      = true
	_shroud_timer       = SHROUD_DURATION
	is_invincible       = true
	invincibility_timer = SHROUD_DURATION + 0.1
	if hitbox:
		hitbox.set_deferred("monitoring",  false)
		hitbox.set_deferred("monitorable", false)

func _end_shroud():
	_shroud_active = false
	if hitbox:
		hitbox.set_deferred("monitoring",  true)
		hitbox.set_deferred("monitorable", true)
	if sprite: sprite.modulate = Color.WHITE
	print("[Hel] Shroud ended — eruption!")
	for i in range(12):
		var angle = (TAU / 12.0) * i
		_fire_projectile(Vector2(cos(angle), sin(angle)))

func take_damage(amount: int):
	if get_health_percent() < 0.5 and randf() < 0.20:
		print("[Hel] Ghostly dodge!")
		return
	super(amount)
