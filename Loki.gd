extends "res://scripts/Hero.gd"

# ============================================================
# Loki.gd — God of Mischief
# SPECIAL: TRICK STEP  (Cooldown: 5s)
# Instantly teleports to the cursor. Enemies lose targeting
# briefly. Brief invincibility on arrival.
# PASSIVE: shots have slight random angle spread.
# ============================================================

func _ready():
	super()
	hero_name            = "Loki"
	max_health           = 80
	current_health       = max_health
	move_speed           = 125.0
	base_damage          = 8
	fire_rate            = 0.30
	special_cooldown_max = 5.0

func _special_ability():
	print("[Loki] TRICK STEP — blink!")
	var target    = get_global_mouse_position()
	var room_rect = Rect2(42, 42, 16 * 40 - 84, 12 * 40 - 84)
	target = Vector2(
		clampf(target.x, room_rect.position.x, room_rect.end.x),
		clampf(target.y, room_rect.position.y, room_rect.end.y)
	)
	if sprite: sprite.modulate.a = 0.0
	global_position     = target
	is_invincible       = true
	invincibility_timer = 0.65
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 1.0, 0.18)

# Passive: ±10° random spread on every shot
func _fire_projectile(direction: Vector2):
	super(direction.rotated(randf_range(-0.175, 0.175)))
