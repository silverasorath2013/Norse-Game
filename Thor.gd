extends "res://scripts/Hero.gd"

# ============================================================
# Thor.gd — God of Thunder
# SPECIAL: MJOLNIR THROW  (Cooldown: 7s)
# Hurls a giant hammer that bounces off 3 walls, dealing
# double damage each hit.
# ============================================================

func _ready():
	super()
	hero_name            = "Thor"
	max_health           = 120
	current_health       = max_health
	move_speed           = 105.0
	base_damage          = 12
	fire_rate            = 0.42
	special_cooldown_max = 7.0

func _special_ability():
	print("[Thor] MJOLNIR THROW!")
	if not ResourceLoader.exists("res://scenes/Bullet.tscn"):
		print("[Thor] Special: bouncing hammer → ", aim_direction); return

	var hammer             = load("res://scenes/Bullet.tscn").instantiate()
	hammer.global_position = global_position
	hammer.direction       = aim_direction
	hammer.speed           = 190.0
	hammer.damage          = base_damage * 2
	hammer.bounces         = 3
	hammer.lifetime        = 4.0
	hammer.source_node     = self
	hammer.scale           = Vector2(2.2, 2.2)
	if hammer.has_node("Sprite2D"):
		hammer.get_node("Sprite2D").modulate = Color(0.4, 0.7, 1.0)
	get_parent().add_child(hammer)
