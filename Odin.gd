extends "res://scripts/Hero.gd"

# ============================================================
# Odin.gd — Allfather, God of Wisdom
# SPECIAL: ALL-SEEING EYE  (Cooldown: 10s)
# Reveals the entire floor minimap + fires a growing
# charged shot (3× damage, grows as it travels).
# ============================================================

func _ready():
	super()
	hero_name            = "Odin"
	max_health           = 100
	current_health       = max_health
	move_speed           = 100.0
	base_damage          = 11
	fire_rate            = 0.40
	special_cooldown_max = 10.0

func _special_ability():
	print("[Odin] ALL-SEEING EYE — map revealed + charged shot!")
	# Reveal minimap
	if has_node("/root/DungeonGenerator") and DungeonGenerator.current_floor:
		for pos in DungeonGenerator.current_floor.rooms:
			DungeonGenerator.current_floor.rooms[pos].visited = true
	# Fire growing shot
	if not ResourceLoader.exists("res://scenes/Bullet.tscn"):
		print("[Odin] Special: growing charged shot → ", aim_direction); return
	var shot             = load("res://scenes/Bullet.tscn").instantiate()
	shot.global_position = global_position
	shot.direction       = aim_direction
	shot.speed           = 195.0
	shot.damage          = base_damage * 3
	shot.scale_over_time = true
	shot.lifetime        = 3.0
	shot.source_node     = self
	if shot.has_node("Sprite2D"):
		shot.get_node("Sprite2D").modulate = Color(0.8, 0.6, 1.0)
	get_parent().add_child(shot)
